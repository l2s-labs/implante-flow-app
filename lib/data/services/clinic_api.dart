import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/certificate.dart';
import '../../domain/models.dart';
import 'api_feedback.dart';
import 'cep_lookup.dart';

class ClinicApiException implements Exception {
  const ClinicApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ClinicHttpResponse {
  const ClinicHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;
}

abstract class ClinicTransport {
  Future<ClinicHttpResponse> send({
    required String method,
    required String path,
    Object? body,
    String? token,
  });
}

class ClinicApi {
  ClinicApi({required String baseUrl, ClinicTransport? transport})
      : _transport = transport ?? IoClinicTransport(_trim(baseUrl));

  final ClinicTransport _transport;

  static String _trim(String baseUrl) =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Future<Map<String, dynamic>> fetchChart(String token) async {
    return _object(await _send('GET', '/v1/chart', token: token));
  }

  Future<Map<String, dynamic>> fetchImplantCatalog(String token) async {
    return _object(await _send('GET', '/v1/catalog/implants', token: token));
  }

  Future<Map<String, dynamic>> fetchGraftCatalog(String token) async {
    return _object(await _send('GET', '/v1/catalog/grafts', token: token));
  }

  /// `GET /v1/ceps/:cep` — app nunca chama ViaCEP. Erros: `{ error: { code, message, requestId } }`.
  Future<CepAddress> lookupCep(String token, String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/ceps/$digits',
      token: token,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return CepAddress.fromJson(_object(response.body));
    }
    final code = apiErrorCode(response.body);
    final message = friendlyApiMessage(response.statusCode, body: response.body);
    throw ClinicApiException(
      response.statusCode,
      cepErrorMessage(statusCode: response.statusCode, code: code, fallback: message),
      code: code,
    );
  }

  Future<void> createPatient(String token, Patient patient) async {
    await _send('POST', '/v1/patients', token: token, body: _patientBody(patient));
    await _send(
      'PUT',
      '/v1/patients/${patient.id}/locations',
      token: token,
      body: {'locationIds': patient.locationIds},
    );
  }

  Future<void> updatePatient(String token, Patient patient) async {
    await _send('PATCH', '/v1/patients/${patient.id}', token: token, body: _patientBody(patient)..remove('id'));
    await _send(
      'PUT',
      '/v1/patients/${patient.id}/locations',
      token: token,
      body: {'locationIds': patient.locationIds},
    );
  }

  Future<void> createProcedure(String token, Procedure procedure) async {
    await _send(
      'POST',
      '/v1/patients/${procedure.patientId}/procedures',
      token: token,
      body: _procedureBody(procedure, includeIdentity: true),
    );
  }

  Future<void> updateProcedure(String token, Procedure procedure) async {
    await _send(
      'PATCH',
      '/v1/procedures/${procedure.id}',
      token: token,
      body: _procedureBody(procedure, includeIdentity: false),
    );
  }

  /// L2S-70 / L2S-73: soft delete. 204 = ok; 403/404 = indisponível.
  Future<void> deleteProcedure(String token, String procedureId) async {
    await _send('DELETE', '/v1/procedures/$procedureId', token: token);
  }

  Future<void> recordVisit(
    String token,
    String procedureId,
    Visit visit, {
    required Modality modality,
  }) async {
    await _send(
      'POST',
      '/v1/procedures/$procedureId/visits',
      token: token,
      body: {
        'id': visit.id,
        'date': _isoDate(visit.date),
        'note': visit.note,
        'statusLabel': clinicalStatusWire(visit.statusLabel, modality),
      },
    );
  }

  Future<void> updateFollowUp(String token, FollowUp followUp) async {
    await _send(
      'PATCH',
      '/v1/follow-ups/${followUp.id}',
      token: token,
      body: followUp.isProsthesisTrack
          ? {
              if (followUp.phase != null) 'phase': followUp.phase!.name,
              if (followUp.phase == FollowUpPhase.definitive) ...{
                'status': followUp.prosthesisStatus?.name,
                'status_dates': {
                  for (final entry in followUp.statusDates.entries)
                    entry.key: entry.value == null ? null : _isoDate(entry.value!),
                },
              },
            }
          : {'status': followUp.status.name},
    );
  }

  Future<void> updateProfile(String token, DentistProfile profile) async {
    await _send(
      'PATCH',
      '/v1/profile',
      token: token,
      body: {
        'name': profile.name,
        'phone': profile.phone,
        'cro': normalizeCro(profile.cro) ?? profile.cro,
        'reminderEnabled': profile.reminderEnabled,
        'reminderDaysBefore': profile.reminderDaysBefore,
        'emailChannel': profile.emailChannel,
        'pushChannel': profile.pushChannel,
      },
    );
  }

  Future<void> createImplant(String token, InstalledImplant implant) async {
    await _send(
      'POST',
      '/v1/patients/${implant.patientId}/implants',
      token: token,
      body: {
        'id': implant.id,
        'fdi': implant.fdi,
        'manufacturer': implant.manufacturer,
        'model': implant.model,
        'size': implant.size,
        'lot': implant.lot,
        'installedOn': implant.installedOn == null ? null : _isoDate(implant.installedOn!),
        'originClinic': implant.originClinic,
        'notes': implant.notes,
      },
    );
  }

  Future<void> updateImplant(String token, InstalledImplant implant) async {
    await _send(
      'PATCH',
      '/v1/implants/${implant.id}',
      token: token,
      body: {
        'fdi': implant.fdi,
        'manufacturer': implant.manufacturer,
        'model': implant.model,
        'size': implant.size,
        'lot': implant.lot,
        'installedOn': implant.installedOn == null ? null : _isoDate(implant.installedOn!),
        'originClinic': implant.originClinic,
        'notes': implant.notes,
        'active': implant.active,
      },
    );
  }

  Future<void> createLocation(String token, CareLocation location) async {
    await _send(
      'POST',
      '/v1/locations',
      token: token,
      body: {'id': location.id, 'name': location.name, 'address': location.address},
    );
  }

  Future<void> updateLocation(String token, CareLocation location) async {
    await _send(
      'PATCH',
      '/v1/locations/${location.id}',
      token: token,
      body: {'name': location.name, 'address': location.address},
    );
  }

  Future<void> setDefaultLocation(String token, String locationId) async {
    await _send('POST', '/v1/locations/$locationId/default', token: token);
  }

  Future<void> inactivateLocation(String token, String locationId, {String? replacementId}) async {
    await _send(
      'POST',
      '/v1/locations/$locationId/inactivate',
      token: token,
      body: {'replacementId': ?replacementId},
    );
  }

  Future<void> reactivateLocation(String token, String locationId) async {
    await _send('POST', '/v1/locations/$locationId/reactivate', token: token);
  }

  Future<Map<String, dynamic>> issueCertificate(
    String token,
    String procedureId, {
    int copies = 1,
    String? locationId,
  }) async {
    return _object(
      await _send(
        'POST',
        '/v1/procedures/$procedureId/certificates',
        token: token,
        body: {
          'copies': copies == 2 ? 2 : 1,
          if (locationId != null && locationId.isNotEmpty) 'locationId': locationId,
        },
      ),
    );
  }

  Future<Uint8List> downloadBytes(String url) async {
    if (_transport is IoClinicTransport) {
      return _transport.getBytes(url);
    }
    throw const ClinicApiException(500, 'Download de arquivo indisponível neste ambiente.');
  }

  Future<void> uploadPhoto(String token, String procedureId, ClinicPhoto photo) async {
    final file = File(photo.path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final contentType = _contentType(photo.path);
    if (contentType == null) {
      throw const ClinicApiException(400, 'A foto precisa ser JPEG, PNG ou WebP.');
    }
    final created = _object(
      await _send(
        'POST',
        '/v1/procedures/$procedureId/photos',
        token: token,
        body: {
          'contentType': contentType,
          'byteSize': bytes.length,
          'caption': photo.caption,
          if (photo.visitId != null) 'visitId': photo.visitId,
        },
      ),
    );
    final uploadUrl = created['uploadUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) return;
    if (_transport is IoClinicTransport) {
      await _transport.putBytes(uploadUrl, bytes, contentType);
    }
  }

  Future<Object?> _send(String method, String path, {required String token, Object? body}) async {
    final response = await _transport.send(method: method, path: path, body: body, token: token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClinicApiException(
        response.statusCode,
        friendlyApiMessage(response.statusCode, body: response.body),
        code: apiErrorCode(response.body),
      );
    }
    return response.body;
  }

  Map<String, dynamic> _object(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const ClinicApiException(500, 'A API devolveu uma resposta inesperada.');
  }
}

class IoClinicTransport implements ClinicTransport {
  IoClinicTransport(this.baseUrl);

  final String baseUrl;
  final HttpClient _client = HttpClient();

  @override
  Future<ClinicHttpResponse> send({
    required String method,
    required String path,
    Object? body,
    String? token,
  }) async {
    try {
      final request = await _client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(const Duration(seconds: 20));
      final text = await response.transform(utf8.decoder).join();
      return ClinicHttpResponse(statusCode: response.statusCode, body: text.isEmpty ? null : jsonDecode(text));
    } on SocketException {
      throw const ClinicApiException(0, 'Não foi possível falar com a API.');
    }
  }

  Future<void> putBytes(String url, List<int> bytes, String contentType) async {
    final request = await _client.putUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClinicApiException(response.statusCode, 'Não foi possível enviar a foto.');
    }
  }

  Future<Uint8List> getBytes(String url) async {
    try {
      final request = await _client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClinicApiException(response.statusCode, 'Não foi possível baixar o certificado.');
      }
      return builder.takeBytes();
    } on SocketException {
      throw const ClinicApiException(0, 'Não foi possível baixar o certificado.');
    }
  }
}

Map<String, Object?> _patientBody(Patient patient) => {
      'id': patient.id,
      'name': patient.name,
      'birthDate': _isoDate(patient.birthDate),
      'phone': patient.phone,
      'email': patient.email,
      'cpf': patient.cpf,
      'notes': patient.notes,
      'guardian': patient.guardian,
      'notifyByEmail': patient.notifyByEmail,
      'notifyByPhone': patient.notifyByPhone,
    };

Map<String, Object?> _procedureBody(Procedure procedure, {required bool includeIdentity}) => {
      if (includeIdentity) 'id': procedure.id,
      if (includeIdentity) 'modality': procedure.modality.name,
      if (includeIdentity) 'subtype': procedure.subtype?.name,
      if (includeIdentity) 'arch': procedure.arch?.name,
      if (includeIdentity) 'surgeryDate': _isoDate(procedure.surgeryDate),
      if (includeIdentity) 'linkedProcedureIds': procedure.linkedProcedureIds,
      if (includeIdentity) 'linkedImplantIds': procedure.linkedImplantIds,
      if (includeIdentity)
        'followUps': [
          for (final followUp in procedure.followUps)
            {
              'id': followUp.id,
              'scheduledOn': _isoDate(followUp.date),
              'reason': followUp.reason.name,
              'reminderEnabled': followUp.reminderEnabled,
              'reminderDaysBefore': followUp.reminderDaysBefore,
              if (followUp.phase != null) 'phase': followUp.phase!.name,
              if (followUp.phase == FollowUpPhase.definitive) ...{
                'status': followUp.prosthesisStatus?.name,
                'status_dates': {
                  for (final entry in followUp.statusDates.entries)
                    entry.key: entry.value == null ? null : _isoDate(entry.value!),
                },
              },
            },
        ],
      'statusLabel': clinicalStatusWire(procedure.statusLabel, procedure.modality),
      'notes': procedure.notes,
      'associatedGraft': procedure.associatedGraft,
      'sinusLift': procedure.sinusLift,
      'sinusLiftTechnique': procedure.sinusLiftTechnique?.name,
      'sinusLiftNote': procedure.sinusLiftNote,
      'sites': [
        for (final site in procedure.sites)
          {
            'fdi': site.fdi,
            'role': site.role.name,
            'piece': site.piece == null ? null : _pieceBody(site.piece!),
            'grafts': [for (final graft in site.grafts) _graftBody(graft)],
          },
      ],
    };

Map<String, Object?> _pieceBody(ImplantPiece piece) => {
      'manufacturer': piece.manufacturer,
      'model': piece.model,
      'reference': piece.reference,
      'size': piece.size,
      'lot': piece.lot,
      'manufacturedOn': piece.manufacturedOn == null ? null : _isoDate(piece.manufacturedOn!),
      'expiresOn': piece.expiresOn == null ? null : _isoDate(piece.expiresOn!),
      'anvisa': piece.anvisa,
    };

Map<String, Object?> _graftBody(GraftMaterial graft) => {
      'origin': graft.origin.name,
      'processing': graft.processing?.name,
      'presentation': graft.presentation?.name,
      'manufacturer': graft.manufacturer,
      'model': graft.model,
      'productType': graft.productType,
      'granulometry': graft.granulometry,
      'size': graft.size,
      'lot': graft.lot,
      'manufacturedOn': graft.manufacturedOn == null ? null : _isoDate(graft.manufacturedOn!),
      'expiresOn': graft.expiresOn == null ? null : _isoDate(graft.expiresOn!),
      'anvisa': graft.anvisa,
      'donorSite': graft.donorSite,
    };

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

String? _contentType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return null;
}

