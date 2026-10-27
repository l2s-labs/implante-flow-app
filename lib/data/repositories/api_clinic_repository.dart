import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../domain/clinic_snapshot.dart';
import '../../domain/models.dart';
import '../services/api_feedback.dart';
import '../services/clinic_api.dart';
import '../services/cep_lookup.dart';
import '../services/clinic_files.dart';
import '../services/clinical_catalog_codec.dart';
import '../services/clinic_snapshot_codec.dart';
import '../services/local_catalog_store.dart';
import 'clinic_repository.dart';
import 'clinic_state_store.dart';

class ApiClinicRepository implements ClinicRepository {
  ApiClinicRepository({
    required this.api,
    required ClinicSnapshot initial,
    ClinicalCatalog? initialCatalog,
    Future<void> Function(ClinicSnapshot snapshot)? persist,
    CatalogStore? catalogStore,
  })  : _catalog = initialCatalog ?? bundledClinicalCatalog,
        _catalogStore = catalogStore ?? LocalCatalogStore(),
        _local = ClinicStateStore.fromSnapshot(
          initial,
          persist: persist,
          ids: newClinicId,
        ) {
    activeClinicalCatalog = _catalog;
  }

  final ClinicApi api;
  final ClinicStateStore _local;
  final CatalogStore _catalogStore;
  final _failures = StreamController<String>.broadcast();
  final _notices = StreamController<ApiFeedback>.broadcast();
  var _token = '';
  var _epoch = 0;
  var _nameBackfilled = false;
  Future<void> _tail = Future<void>.value();
  Future<String?> Function()? _refreshToken;
  Future<String?>? _refreshInFlight;
  ClinicalCatalog _catalog;
  void Function(ClinicalCatalog catalog)? _applyCatalog;

  Future<void> get settled => _tail;

  @override
  ClinicSnapshot get current => _local.current;

  @override
  ClinicalCatalog get catalog => _catalog;

  @override
  List<String> get delayNoticeFollowUpIds => _local.delayNoticeFollowUpIds;

  @override
  Stream<ClinicSnapshot> watch() => _local.watch();

  @override
  Stream<String> get syncErrors => _failures.stream;

  @override
  Stream<ApiFeedback> get feedback => _notices.stream;

  @override
  void bindUnauthorized(Future<String?> Function() refresh) {
    _refreshToken = refresh;
  }

  @override
  void bindCatalog(void Function(ClinicalCatalog catalog) apply) {
    _applyCatalog = apply;
    apply(_catalog);
  }

  @override
  void applyOverdueNotices() => _local.applyOverdueNotices();

  @override
  void signIn({required String name, required String email, String accessToken = ''}) {
    if (accessToken.isNotEmpty) _token = accessToken;
    _local.signIn(name: sanitizePersonName(name), email: email);
  }

  @override
  void signOut() {
    _token = '';
    _local.signOut();
  }

  @override
  Future<void> refresh() {
    return _enqueue(() async {
      if (_token.isEmpty && _refreshToken == null) return;
      final epoch = _epoch;
      final chart = await _authorized(api.fetchChart);
      if (epoch != _epoch) return;
      _applyChart(chart);
      await _mergeProsthesisFollowUps(epoch);
      await _refreshCatalog(epoch);
    });
  }

  @override
  Future<void> refreshCatalog() {
    return _enqueue(() async {
      if (_token.isEmpty && _refreshToken == null) return;
      await _refreshCatalog(_epoch);
    });
  }

  @override
  Future<CepAddress> lookupCep(String cep) {
    return _authorized((token) => api.lookupCep(token, cep));
  }

  Future<void> _refreshCatalog(int epoch) async {
    try {
      final implants = await _authorized(api.fetchImplantCatalog);
      final grafts = await _authorized(api.fetchGraftCatalog);
      if (epoch != _epoch) return;
      final next = clinicalCatalogFromApi(implants: implants, grafts: grafts);
      _setCatalog(next);
      await _catalogStore.save(next);
    } on ClinicApiException {
      // Mantém cache/bundled; chart já sincronizou.
    }
  }

  void _setCatalog(ClinicalCatalog next) {
    _catalog = next;
    activeClinicalCatalog = next;
    _applyCatalog?.call(next);
  }

  @override
  String allocateId(String prefix) => _local.allocateId(prefix);

  @override
  Patient createPatient({
    required String name,
    required String phone,
    String email = '',
    String cpf = '',
    required DateTime birthDate,
    String notes = '',
    String guardian = '',
    List<String> locationIds = const [],
    bool notifyByEmail = false,
    bool notifyByPhone = false,
  }) {
    _epoch++;
    final patient = _local.createPatient(
      name: name,
      phone: phone,
      email: email,
      cpf: cpf,
      birthDate: birthDate,
      notes: notes,
      guardian: guardian,
      locationIds: locationIds,
      notifyByEmail: notifyByEmail,
      notifyByPhone: notifyByPhone,
    );
    _enqueue(
      () => _authorized((token) => api.createPatient(token, patient)),
      success: 'Paciente salvo com sucesso.',
    );
    return patient;
  }

  @override
  void updatePatient(Patient patient) {
    _epoch++;
    _local.updatePatient(patient);
    final saved = _local.current.patients.firstWhere((item) => item.id == patient.id);
    _enqueue(
      () => _authorized((token) => api.updatePatient(token, saved)),
      success: 'Paciente atualizado com sucesso.',
    );
  }

  @override
  void saveProcedures(List<Procedure> created) {
    _epoch++;
    _local.saveProcedures(created);
    for (final procedure in created) {
      _enqueue(
        () => _authorized((token) async {
          await api.createProcedure(token, procedure);
          await _syncProsthesisFollowUps(token, procedure);
        }),
        success: 'Procedimento salvo com sucesso.',
      );
    }
  }

  @override
  void updateProcedure(Procedure procedure) {
    _epoch++;
    _local.updateProcedure(procedure);
    _enqueue(
      () => _authorized((token) => api.updateProcedure(token, procedure)),
      success: 'Procedimento atualizado com sucesso.',
    );
  }

  @override
  Future<void> deleteProcedure(String procedureId) async {
    _epoch++;
    // Some da lista imediatamente; se a API negar, reconcilia o chart.
    await _local.deleteProcedure(procedureId);
    try {
      await _authorized((token) => api.deleteProcedure(token, procedureId));
      _notices.add(ApiFeedback.success('Procedimento excluído.'));
    } on ClinicApiException catch (error) {
      final message = switch (error.statusCode) {
        403 || 404 => 'Este procedimento não está disponível para exclusão.',
        0 => error.message,
        _ => error.message,
      };
      _notices.add(ApiFeedback.error(message));
      await _reconcile();
      throw ClinicApiException(error.statusCode, message, code: error.code);
    } catch (error) {
      final message = error is ClinicApiException
          ? error.message
          : friendlyApiMessage(0);
      _notices.add(ApiFeedback.error(message));
      await _reconcile();
      rethrow;
    }
  }

  @override
  void addPhoto(String procedureId, ClinicPhoto photo) {
    _epoch++;
    _local.addPhoto(procedureId, photo);
    if (photo.path.isEmpty) return;
    _enqueue(() async {
      try {
        await _authorized((token) => api.uploadPhoto(token, procedureId, photo));
      } on ClinicApiException catch (error) {
        // Sem object store a API responde 503; a foto permanece só no aparelho.
        if (error.statusCode == 503) return;
        rethrow;
      }
    });
  }

  @override
  void addVisit({
    required String procedureId,
    required String note,
    required String statusLabel,
  }) {
    _epoch++;
    final before = _visits(procedureId).length;
    _local.addVisit(procedureId: procedureId, note: note, statusLabel: statusLabel);
    final visit = _visits(procedureId).elementAt(before);
    final modality =
        _local.current.procedures.where((item) => item.id == procedureId).firstOrNull?.modality ??
        Modality.implante;
    _enqueue(
      () => _authorized((token) => api.recordVisit(token, procedureId, visit, modality: modality)),
      success: 'Consulta registrada com sucesso.',
    );
  }

  @override
  void completeFollowUp({
    required String followUpId,
    required String note,
    required String statusLabel,
    required ReturnStatus returnStatus,
  }) {
    _epoch++;
    final procedure = _procedureOfFollowUp(followUpId);
    if (procedure == null) return;
    final before = procedure.visits.length;
    _local.completeFollowUp(
      followUpId: followUpId,
      note: note,
      statusLabel: statusLabel,
      returnStatus: returnStatus,
    );
    final updated = _procedureOfFollowUp(followUpId);
    final followUp = updated?.followUps.where((item) => item.id == followUpId).firstOrNull;
    if (followUp != null) {
      _enqueue(() => _authorized((token) => api.updateFollowUp(token, followUp)));
    }
    if (updated != null && updated.visits.length > before) {
      final visit = updated.visits[before];
      _enqueue(
        () => _authorized(
          (token) => api.recordVisit(token, updated.id, visit, modality: updated.modality),
        ),
      );
    }
  }

  @override
  void updateProsthesisFollowUp({
    required String followUpId,
    required ProsthesisFollowUpStatus status,
    DateTime? statusDate,
  }) {
    _local.updateProsthesisFollowUp(
      followUpId: followUpId,
      status: status,
      statusDate: statusDate,
    );
    final procedure = _procedureOfFollowUp(followUpId);
    final followUp = procedure?.followUps.where((item) => item.id == followUpId).firstOrNull;
    if (procedure == null || followUp == null || followUp.phase == null) return;
    final phase = followUp.phase!;
    _enqueue(
      () => _authorized(
        (token) => api.patchProsthesisFollowUpStatus(
          token,
          procedure.id,
          phase,
          status: status,
          statusAt: statusDate,
        ),
      ),
    );
  }

  @override
  void addProsthesisFollowUp({
    required String procedureId,
    required FollowUpPhase phase,
  }) {
    _local.addProsthesisFollowUp(procedureId: procedureId, phase: phase);
    final procedure = current.procedures.where((item) => item.id == procedureId).firstOrNull;
    if (procedure == null) return;
    final followUp = procedure.followUps
        .where((item) => item.isProsthesisTrack && item.phase == phase)
        .lastOrNull;
    _enqueue(
      () => _authorized(
        (token) => api.upsertProsthesisFollowUp(
          token,
          procedureId,
          phase,
          status: followUp?.prosthesisStatus,
          statusAt: followUp?.prosthesisStatus == null
              ? null
              : followUp!.statusDates[followUp.prosthesisStatus!.name],
        ),
      ),
    );
  }


  @override
  Future<Uint8List> issueCertificate(
    String procedureId, {
    int copies = 1,
    String? locationId,
  }) async {
    _epoch++;
    final issued = await _authorized(
      (token) => api.issueCertificate(
        token,
        procedureId,
        copies: copies,
        locationId: locationId,
      ),
    );
    final downloadUrl = issued['downloadUrl'] as String? ?? '';
    if (downloadUrl.isEmpty) {
      throw const ClinicApiException(500, 'A API não devolveu o link do certificado.');
    }
    final bytes = await api.downloadBytes(downloadUrl);
    final path = await ClinicFiles().saveBytes(
      'certificado-$procedureId.pdf',
      bytes,
    );
    _local.recordCertificateEmission(procedureId, pdfPath: path);
    return bytes;
  }

  @override
  void reprocessStageNotice({required String procedureId, required String noticeId}) {
    _local.reprocessStageNotice(procedureId: procedureId, noticeId: noticeId);
  }

  @override
  void failStageNotice({required String procedureId, required String noticeId}) {
    _local.failStageNotice(procedureId: procedureId, noticeId: noticeId);
  }

  @override
  void updateProfile(DentistProfile profile) {
    _epoch++;
    final previous = _local.current.profile;
    _local.updateProfile(profile);
    _enqueue(
      () async {
        await _authorized((token) => api.updateProfile(token, profile));
        await _syncLocations(previous.locations, profile.locations);
      },
      success: 'Perfil atualizado com sucesso.',
    );
  }

  @override
  InstalledImplant createInstalledImplant(InstalledImplant implant) {
    _epoch++;
    final saved = _local.createInstalledImplant(implant);
    _enqueue(
      () => _authorized((token) => api.createImplant(token, saved)),
      success: 'Implante cadastrado com sucesso.',
    );
    return saved;
  }

  @override
  void updateInstalledImplant(InstalledImplant implant) {
    _epoch++;
    _local.updateInstalledImplant(implant);
    _enqueue(
      () => _authorized((token) => api.updateImplant(token, implant)),
      success: 'Implante atualizado com sucesso.',
    );
  }

  List<Visit> _visits(String procedureId) {
    return _local.current.procedures.firstWhere((item) => item.id == procedureId).visits;
  }

  Procedure? _procedureOfFollowUp(String followUpId) {
    for (final procedure in _local.current.procedures) {
      if (procedure.followUps.any((item) => item.id == followUpId)) return procedure;
    }
    return null;
  }

  Future<void> _syncLocations(List<CareLocation> previous, List<CareLocation> next) async {
    final previousById = {for (final location in previous) location.id: location};
    for (final location in next) {
      final prior = previousById[location.id];
      if (prior == null) {
        await _authorized((token) => api.createLocation(token, location));
      } else if (prior.name != location.name || prior.address != location.address) {
        await _authorized((token) => api.updateLocation(token, location));
      }
    }
    final nextDefault = next.where((location) => location.active && location.isDefault).toList();
    final previousDefault = previous.where((location) => location.active && location.isDefault).toList();
    if (nextDefault.length == 1 &&
        (previousDefault.isEmpty || previousDefault.first.id != nextDefault.first.id)) {
      await _authorized((token) => api.setDefaultLocation(token, nextDefault.first.id));
    }
    for (final location in next) {
      final prior = previousById[location.id];
      if (prior == null) continue;
      if (prior.active && !location.active) {
        await _authorized((token) => api.inactivateLocation(token, location.id));
      } else if (!prior.active && location.active) {
        await _authorized((token) => api.reactivateLocation(token, location.id));
      }
    }
  }

  void _applyChart(Map<String, dynamic> chart) {
    final snapshot = snapshotFromJson({
      'signedIn': true,
      'sequence': _local.current.sequence,
      'profile': chart['profile'],
      'patients': chart['patients'],
      'procedures': chart['procedures'],
    });
    final apiName = sanitizePersonName(snapshot.profile.name);
    final localName = sanitizePersonName(_local.current.profile.name);
    final keptName = apiName.isNotEmpty ? apiName : localName;
    final keptEmail = snapshot.profile.email.trim().isEmpty ? _local.current.profile.email : snapshot.profile.email;
    final profile = snapshot.profile.copyWith(name: keptName, email: keptEmail);
    _local.replaceSnapshot(snapshot.copyWith(profile: profile));
    _local.applyOverdueNotices();
    if (!_nameBackfilled && apiName.isEmpty && keptName.isNotEmpty) {
      _nameBackfilled = true;
      _enqueue(() => _authorized((token) => api.updateProfile(token, profile)));
    }
  }

  Future<T> _authorized<T>(Future<T> Function(String token) call) async {
    var token = _token;
    if (token.isEmpty) {
      token = await _refreshAccessToken() ?? '';
      if (token.isEmpty) {
        throw const ClinicApiException(401, 'Entre de novo para sincronizar o prontuário.');
      }
    }
    try {
      return await call(token);
    } on ClinicApiException catch (error) {
      if (error.statusCode != 401 || _refreshToken == null) rethrow;
      final next = await _refreshAccessToken();
      if (next == null || next.isEmpty) rethrow;
      return call(next);
    }
  }

  Future<String?> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _refreshToken;
    if (refresh == null) return null;
    final future = () async {
      try {
        final next = await refresh();
        if (next != null && next.isNotEmpty) {
          _token = next;
        }
        return next;
      } finally {
        _refreshInFlight = null;
      }
    }();
    _refreshInFlight = future;
    return future;
  }

  Future<void> _enqueue(Future<void> Function() job, {String? success}) {
    _tail = _tail.then((_) async {
      try {
        await job();
        if (success != null) {
          _notices.add(ApiFeedback.success(success));
        }
      } catch (error) {
        final message = error is ClinicApiException
            ? error.message
            : friendlyApiMessage(0);
        _failures.add(message);
        _notices.add(ApiFeedback.error(message));
        await _reconcile();
      }
    });
    return _tail;
  }

  Future<void> _reconcile() async {
    if (_token.isEmpty) return;
    try {
      final epoch = _epoch;
      final chart = await _authorized(api.fetchChart);
      if (epoch != _epoch) return;
      _applyChart(chart);
      await _mergeProsthesisFollowUps(epoch);
    } catch (_) {
      // The first failure is already reported.
    }
  }

  Future<void> _syncProsthesisFollowUps(String token, Procedure procedure) async {
    if (procedure.modality != Modality.protese) return;
    for (final followUp in procedure.followUps) {
      if (!followUp.isProsthesisTrack || followUp.phase == null) continue;
      final phase = followUp.phase!;
      final status = phase == FollowUpPhase.definitive ? followUp.prosthesisStatus : null;
      final statusAt = status == null ? null : followUp.statusDates[status.name];
      await api.upsertProsthesisFollowUp(
        token,
        procedure.id,
        phase,
        status: status,
        statusAt: statusAt,
      );
    }
  }

  /// Chart não traz prótese — GET dedicado e mescla no snapshot local.
  Future<void> _mergeProsthesisFollowUps(int epoch) async {
    final proteseIds = [
      for (final procedure in _local.current.procedures)
        if (procedure.modality == Modality.protese) procedure.id,
    ];
    if (proteseIds.isEmpty) return;
    final byProcedure = <String, List<FollowUp>>{};
    for (final procedureId in proteseIds) {
      if (epoch != _epoch) return;
      try {
        final rows = await _authorized(
          (token) => api.listProsthesisFollowUps(token, procedureId),
        );
        byProcedure[procedureId] = [
          for (final row in rows) followUpFromProsthesisWire(row),
        ];
      } catch (_) {
        // Mantém track local se o GET falhar.
      }
    }
    if (epoch != _epoch || byProcedure.isEmpty) return;
    final procedures = [
      for (final procedure in _local.current.procedures)
        if (byProcedure.containsKey(procedure.id))
          procedure.copyWith(
            followUps: chronologicalFollowUps([
              for (final followUp in procedure.followUps)
                if (!followUp.isProsthesisTrack) followUp,
              ...?byProcedure[procedure.id],
            ]),
          )
        else
          procedure,
    ];
    _local.replaceSnapshot(_local.current.copyWith(procedures: procedures));
  }
}

String newClinicId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
