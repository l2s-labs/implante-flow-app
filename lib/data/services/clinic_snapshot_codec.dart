import 'dart:convert';

import '../../domain/clinic_snapshot.dart';
import '../../domain/models.dart';

String encodeClinicSnapshot(ClinicSnapshot snapshot) {
  return const JsonEncoder.withIndent('  ').convert(snapshotToJson(snapshot));
}

ClinicSnapshot decodeClinicSnapshot(String source) {
  return snapshotFromJson(jsonDecode(source) as Map<String, dynamic>);
}

Map<String, dynamic> snapshotToJson(ClinicSnapshot snapshot) {
  return {
    'version': 1,
    'signedIn': snapshot.signedIn,
    'sequence': snapshot.sequence,
    'profile': {
      'name': snapshot.profile.name,
      'email': snapshot.profile.email,
      'phone': snapshot.profile.phone,
      'cro': snapshot.profile.cro,
      'reminderEnabled': snapshot.profile.reminderEnabled,
      'reminderDaysBefore': snapshot.profile.reminderDaysBefore,
      'emailChannel': snapshot.profile.emailChannel,
      'pushChannel': snapshot.profile.pushChannel,
      'locations': [
        for (final location in snapshot.profile.locations)
          {
            'id': location.id,
            'name': location.name,
            'address': location.address,
            'active': location.active,
            'isDefault': location.isDefault,
          },
      ],
    },
    'patients': [
      for (final patient in snapshot.patients)
        {
          'id': patient.id,
          'name': patient.name,
          'phone': patient.phone,
          'email': patient.email,
          'cpf': patient.cpf,
          'locationIds': patient.locationIds,
          'notifyByEmail': patient.notifyByEmail,
          'notifyByPhone': patient.notifyByPhone,
          'birthDate': _date(patient.birthDate),
          'notes': patient.notes,
          'guardian': patient.guardian,
        },
    ],
    'procedures': [
      for (final procedure in snapshot.procedures) _procedureToJson(procedure),
    ],
    'implants': [
      for (final implant in snapshot.implants) _implantToJson(implant),
    ],
  };
}

ClinicSnapshot snapshotFromJson(Map<String, dynamic> json) {
  return ClinicSnapshot(
    signedIn: json['signedIn'] as bool? ?? false,
    sequence: json['sequence'] as int? ?? 0,
    profile: DentistProfile(
      name: sanitizePersonName(json['profile']?['name'] as String?),
      email: json['profile']?['email'] as String? ?? '',
      phone: json['profile']?['phone'] as String? ?? '',
      cro: json['profile']?['cro'] as String? ?? '',
      reminderEnabled: json['profile']?['reminderEnabled'] as bool? ?? true,
      reminderDaysBefore: _reminderDays(json['profile']),
      emailChannel: json['profile']?['emailChannel'] as bool? ?? true,
      pushChannel: json['profile']?['pushChannel'] as bool? ?? true,
      locations: [
        for (final location in json['profile']?['locations'] as List<dynamic>? ?? const [])
          CareLocation(
            id: location['id'] as String,
            name: location['name'] as String? ?? '',
            address: location['address'] as String? ?? '',
            active: location['active'] as bool? ?? true,
            isDefault: location['isDefault'] as bool? ?? false,
          ),
      ],
    ),
    patients: [
      for (final item in json['patients'] as List<dynamic>? ?? const [])
        Patient(
          id: item['id'] as String,
          name: item['name'] as String,
          phone: item['phone'] as String? ?? '',
          email: item['email'] as String? ?? '',
          cpf: item['cpf'] as String? ?? '',
          locationIds: [
            for (final id in item['locationIds'] as List<dynamic>? ?? const []) id as String,
          ],
          notifyByEmail: item['notifyByEmail'] as bool? ?? false,
          notifyByPhone: item['notifyByPhone'] as bool? ?? false,
          birthDate: _parseDate(item['birthDate'] as String),
          notes: item['notes'] as String? ?? '',
          guardian: item['guardian'] as String? ?? '',
        ),
    ],
    procedures: [
      for (final item in json['procedures'] as List<dynamic>? ?? const [])
        _procedureFromJson(item as Map<String, dynamic>),
    ],
    implants: _implantsFromJson(json),
  );
}

List<InstalledImplant> _implantsFromJson(Map<String, dynamic> json) {
  final collected = <InstalledImplant>[];
  final seen = <String>{};
  void add(InstalledImplant implant) {
    if (!seen.add(implant.id)) return;
    collected.add(implant);
  }

  for (final item in json['implants'] as List<dynamic>? ?? const []) {
    add(_implantFromJson(item as Map<String, dynamic>));
  }
  for (final patient in json['patients'] as List<dynamic>? ?? const []) {
    final patientId = patient['id'] as String?;
    for (final item in patient['implants'] as List<dynamic>? ?? const []) {
      final map = Map<String, dynamic>.from(item as Map);
      map.putIfAbsent('patientId', () => patientId);
      add(_implantFromJson(map));
    }
  }
  return collected;
}

Map<String, dynamic> _implantToJson(InstalledImplant implant) => {
      'id': implant.id,
      'patientId': implant.patientId,
      'fdi': implant.fdi,
      'origin': implantOriginWire(implant.origin),
      'sourceProcedureId': implant.sourceProcedureId,
      'manufacturer': implant.manufacturer,
      'model': implant.model,
      'size': implant.size,
      'lot': implant.lot,
      'installedOn': _dateOrNull(implant.installedOn),
      'originClinic': implant.originClinic,
      'notes': implant.notes,
      'active': implant.active,
    };

InstalledImplant _implantFromJson(Map<String, dynamic> json) => InstalledImplant(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      fdi: json['fdi'] as int,
      origin: implantOriginFromWire(json['origin'] as String?),
      sourceProcedureId: json['sourceProcedureId'] as String?,
      manufacturer: json['manufacturer'] as String? ?? '',
      model: json['model'] as String? ?? '',
      size: json['size'] as String? ?? '',
      lot: json['lot'] as String? ?? '',
      installedOn: _parseDateOrNull(json['installedOn'] as String?),
      originClinic: json['originClinic'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );

Map<String, dynamic> _procedureToJson(Procedure procedure) {
  return {
    'id': procedure.id,
    'patientId': procedure.patientId,
    'modality': procedure.modality.name,
    'subtype': procedure.subtype?.name,
    'associatedGraft': procedure.associatedGraft,
    'sinusLift': procedure.sinusLift,
    'sinusLiftTechnique': procedure.sinusLiftTechnique?.name,
    'sinusLiftNote': procedure.sinusLiftNote,
    'linkedProcedureIds': procedure.linkedProcedureIds,
    'linkedImplantIds': procedure.linkedImplantIds,
    'arch': procedure.arch?.name,
    'surgeryDate': _date(procedure.surgeryDate),
    'statusLabel': procedure.statusLabel,
    'notes': procedure.notes,
    'certificateIssuedAt': _dateOrNull(procedure.certificateIssuedAt),
    'certificatePdfPath': procedure.certificatePdfPath,
    'sites': [
      for (final site in procedure.sites)
        {
          'fdi': site.fdi,
          'role': site.role.name,
          'piece': site.piece == null ? null : _pieceToJson(site.piece!),
          'grafts': [for (final graft in site.grafts) _graftToJson(graft)],
        },
    ],
    'visits': [
      for (final visit in procedure.visits)
        {
          'id': visit.id,
          'date': _date(visit.date),
          'note': visit.note,
          'statusLabel': visit.statusLabel,
        },
    ],
    'followUps': [
      for (final followUp in procedure.followUps)
        {
          'id': followUp.id,
          'date': _date(followUp.date),
          'reason': followUp.reason.name,
          'status': followUp.status.name,
          'reminderEnabled': followUp.reminderEnabled,
          'reminderDaysBefore': followUp.reminderDaysBefore,
          'overdueNotified': followUp.overdueNotified,
          if (followUp.phase != null) 'phase': followUp.phase!.name,
          if (followUp.prosthesisStatus != null) 'prosthesisStatus': followUp.prosthesisStatus!.name,
          if (followUp.statusDates.isNotEmpty)
            'statusDates': {
              for (final entry in followUp.statusDates.entries)
                entry.key: entry.value == null ? null : _date(entry.value!),
            },
        },
    ],
    'photos': [
      for (final photo in procedure.photos)
        {
          'id': photo.id,
          'caption': photo.caption,
          'path': photo.path,
          'visitId': photo.visitId,
        },
    ],
    'stageNotices': [
      for (final notice in procedure.stageNotices)
        {
          'id': notice.id,
          'stageLabel': notice.stageLabel,
          'channels': notice.channels,
          'delivery': notice.delivery.name,
          'createdAt': _date(notice.createdAt),
        },
    ],
  };
}

Procedure _procedureFromJson(Map<String, dynamic> json) {
  final modality = Modality.values.byName(json['modality'] as String);
  return Procedure(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    modality: modality,
    subtype: json['subtype'] == null
        ? null
        : ProcedureSubtype.values.byName(json['subtype'] as String),
    associatedGraft: json['associatedGraft'] as bool? ?? false,
    sinusLift: json['sinusLift'] as bool? ?? false,
    sinusLiftTechnique: json['sinusLiftTechnique'] == null
        ? null
        : SinusLiftTechnique.values.byName(json['sinusLiftTechnique'] as String),
    sinusLiftNote: json['sinusLiftNote'] as String? ?? '',
    linkedProcedureIds: [
      for (final id in json['linkedProcedureIds'] as List<dynamic>? ?? const []) id as String,
    ],
    linkedImplantIds: [
      for (final id in json['linkedImplantIds'] as List<dynamic>? ?? const []) id as String,
    ],
    arch: json['arch'] == null ? null : Arch.values.byName(json['arch'] as String),
    surgeryDate: _parseDate(json['surgeryDate'] as String),
    statusLabel: clinicalStatusDisplay(json['statusLabel'] as String? ?? '', modality),
    notes: json['notes'] as String? ?? '',
    certificateIssuedAt: _parseDateOrNull(json['certificateIssuedAt'] as String?),
    certificatePdfPath: json['certificatePdfPath'] as String?,
    sites: [
      for (final site in json['sites'] as List<dynamic>? ?? const [])
        ToothSite(
          fdi: site['fdi'] as int,
          role: ToothRole.values.byName(site['role'] as String),
          piece: site['piece'] == null
              ? null
              : _pieceFromJson(site['piece'] as Map<String, dynamic>),
          grafts: [
            for (final graft in site['grafts'] as List<dynamic>? ?? const [])
              _graftFromJson(graft as Map<String, dynamic>),
          ],
        ),
    ],
    visits: [
      for (final visit in json['visits'] as List<dynamic>? ?? const [])
        Visit(
          id: visit['id'] as String,
          date: _parseDate(visit['date'] as String),
          note: visit['note'] as String? ?? '',
          statusLabel: clinicalStatusDisplay(visit['statusLabel'] as String? ?? '', modality),
        ),
    ],
    followUps: [
      for (final item in json['followUps'] as List<dynamic>? ?? const [])
        FollowUp(
          id: item['id'] as String,
          date: _parseDate(item['date'] as String),
          reason: ReturnReason.values.byName(item['reason'] as String),
          status: ReturnStatus.values.byName(item['status'] as String),
          reminderEnabled: item['reminderEnabled'] as bool? ?? true,
          reminderDaysBefore: _reminderDays(item),
          overdueNotified: item['overdueNotified'] as bool? ?? false,
          phase: parseFollowUpPhase(item['phase'] as String?),
          prosthesisStatus: () {
            final raw = item['prosthesisStatus'] ?? (item['phase'] == null ? null : item['status']);
            if (raw is! String || raw.isEmpty) return null;
            if (ReturnStatus.values.any((value) => value.name == raw)) return null;
            return parseProsthesisFollowUpStatus(raw);
          }(),
          statusDates: {
            for (final entry
                in (item['statusDates'] as Map? ?? item['status_dates'] as Map? ?? const {}).entries)
              if (entry.key is String)
                normalizeProsthesisStatusDateKey(entry.key as String):
                    entry.value == null ? null : _parseDate(entry.value as String),
          },
        ),
    ],
    photos: [
      for (final photo in json['photos'] as List<dynamic>? ?? const [])
        ClinicPhoto(
          id: photo['id'] as String,
          caption: photo['caption'] as String? ?? '',
          path: photo['path'] as String? ?? '',
          visitId: photo['visitId'] as String?,
        ),
    ],
    stageNotices: [
      for (final notice in json['stageNotices'] as List<dynamic>? ?? const [])
        StageNotice(
          id: notice['id'] as String,
          stageLabel: notice['stageLabel'] as String? ?? '',
          channels: [
            for (final channel in notice['channels'] as List<dynamic>? ?? const []) channel as String,
          ],
          delivery: NoticeDelivery.values.byName(notice['delivery'] as String? ?? 'aguardando'),
          createdAt: _parseDate(notice['createdAt'] as String),
        ),
    ],
  );
}

Map<String, dynamic> _pieceToJson(ImplantPiece piece) {
  return {
    'manufacturer': piece.manufacturer,
    'model': piece.model,
    'reference': piece.reference,
    'size': piece.size,
    'lot': piece.lot,
    'manufacturedOn': _dateOrNull(piece.manufacturedOn),
    'expiresOn': _dateOrNull(piece.expiresOn),
    'anvisa': piece.anvisa,
  };
}

ImplantPiece _pieceFromJson(Map<String, dynamic> json) {
  return ImplantPiece(
    manufacturer: json['manufacturer'] as String? ?? '',
    model: json['model'] as String? ?? '',
    reference: json['reference'] as String? ?? '',
    size: json['size'] as String? ?? '',
    lot: json['lot'] as String? ?? '',
    manufacturedOn: _parseDateOrNull(json['manufacturedOn'] as String?),
    expiresOn: _parseDateOrNull(json['expiresOn'] as String?),
    anvisa: json['anvisa'] as String? ?? '',
  );
}

Map<String, dynamic> _graftToJson(GraftMaterial graft) {
  return {
    'origin': graft.origin.name,
    'processing': graft.processing?.name,
    'presentation': graft.presentation?.name,
    'manufacturer': graft.manufacturer,
    'model': graft.model,
    'productType': graft.productType,
    'granulometry': graft.granulometry,
    'size': graft.size,
    'lot': graft.lot,
    'manufacturedOn': _dateOrNull(graft.manufacturedOn),
    'expiresOn': _dateOrNull(graft.expiresOn),
    'anvisa': graft.anvisa,
    'donorSite': graft.donorSite,
  };
}

GraftMaterial _graftFromJson(Map<String, dynamic> json) {
  return GraftMaterial(
    origin: GraftOrigin.values.byName(json['origin'] as String),
    processing: json['processing'] == null
        ? null
        : GraftProcessing.values.byName(json['processing'] as String),
    presentation: json['presentation'] == null
        ? null
        : GraftPresentation.values.byName(json['presentation'] as String),
    manufacturer: json['manufacturer'] as String? ?? '',
    model: json['model'] as String? ?? '',
    productType: json['productType'] as String? ?? '',
    granulometry: json['granulometry'] as String? ?? '',
    size: json['size'] as String? ?? '',
    lot: json['lot'] as String? ?? '',
    manufacturedOn: _parseDateOrNull(json['manufacturedOn'] as String?),
    expiresOn: _parseDateOrNull(json['expiresOn'] as String?),
    anvisa: json['anvisa'] as String? ?? '',
    donorSite: json['donorSite'] as String? ?? '',
  );
}

String _date(DateTime date) => date.toIso8601String();

String? _dateOrNull(DateTime? date) => date?.toIso8601String();

DateTime _parseDate(String value) => DateTime.parse(value);

DateTime? _parseDateOrNull(String? value) =>
    value == null || value.isEmpty ? null : DateTime.parse(value);

int _reminderDays(Object? json) {
  if (json is! Map) return defaultReminderDaysBefore;
  final raw = json['reminderDaysBefore'];
  if (raw is! int) return defaultReminderDaysBefore;
  return normalizeReminderDaysBefore(raw);
}
