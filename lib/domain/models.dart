part 'clinical_catalog.dart';

enum Modality { implante, enxerto, protese }

enum ProcedureSubtype { unitario, protocolo, ponte }

enum ToothRole { pilar, pontico }

enum Arch { superior, inferior }

enum ImplantStatus {
  planejado,
  instalado,
  osseointegracao,
  reabertura,
  protese,
  concluido,
  manutencao,
  intercorrencia,
}

enum GraftStatus {
  planejado,
  realizado,
  maturacao,
  prontoParaImplante,
  intercorrencia,
}

enum GraftOrigin { biomaterial, autogeno }

/// Processamento do material. Liofilizado não é origem biológica.
enum GraftProcessing { liofilizado }

enum GraftPresentation { bloco, po }

/// Opções da interface. A origem biológica fica em [GraftOrigin].
enum GraftMaterialChoice { autogeno, liofilizado }

/// Catálogo clínico do levantamento de seio: janela lateral, acesso
/// transalveolar (Summers) e uma descrição livre em Outro.
enum SinusLiftTechnique { janelaLateral, transalveolar, outro }

enum ReturnReason {
  sutura,
  osseointegracao,
  instalarImplante,
  instalarPonte,
  instalarProtocolo,
  controle,
  reabertura,
}

enum ReturnStatus { agendado, realizado, faltou }

/// Fase do follow-up de prótese (ADR-003 / L2S-71).
enum FollowUpPhase { provisional, definitive }

/// Cadeia de status do follow-up definitivo de prótese (L2S-74 wire EN camelCase).
enum ProsthesisFollowUpStatus { molded, sentToLab, returnedFromLab, installed }

const prosthesisFollowUpStatusOrder = <ProsthesisFollowUpStatus>[
  ProsthesisFollowUpStatus.molded,
  ProsthesisFollowUpStatus.sentToLab,
  ProsthesisFollowUpStatus.returnedFromLab,
  ProsthesisFollowUpStatus.installed,
];

enum CalendarKind { cirurgia, consulta, retorno }

const upperArch = <int>[
  18, 17, 16, 15, 14, 13, 12, 11,
  21, 22, 23, 24, 25, 26, 27, 28,
];

const lowerArch = <int>[
  48, 47, 46, 45, 44, 43, 42, 41,
  31, 32, 33, 34, 35, 36, 37, 38,
];

const chipOrder = <int>[
  18, 17, 16, 15, 14, 13, 12, 11,
  21, 22, 23, 24, 25, 26, 27, 28,
  48, 47, 46, 45, 44, 43, 42, 41,
  31, 32, 33, 34, 35, 36, 37, 38,
];

class ImplantCatalogEntry {
  const ImplantCatalogEntry({
    required this.manufacturer,
    required this.model,
    required this.reference,
    required this.size,
    this.anvisa = '',
  });

  final String manufacturer;
  final String model;
  final String reference;
  final String size;
  final String anvisa;
}

enum ImplantCatalogLookup {
  filled,
  modelOnly,
  notFound,
  cleared,
}

List<String> withCurrentOption(List<String> options, String current) {
  if (current.isNotEmpty && !options.contains(current)) {
    return [current, ...options];
  }
  return options;
}

class GraftProduct {
  const GraftProduct({
    required this.model,
    required this.type,
    required this.presentations,
    this.granulometries = const [],
  });

  final String model;
  final String type;
  final List<GraftPresentation> presentations;
  final List<String> granulometries;
}

GraftMaterialChoice? graftMaterialChoice(GraftOrigin origin, GraftProcessing? processing) {
  if (origin == GraftOrigin.autogeno) return GraftMaterialChoice.autogeno;
  if (processing == GraftProcessing.liofilizado) return GraftMaterialChoice.liofilizado;
  return null;
}

String? sinusLiftIssue({
  required bool applies,
  required bool sinusLift,
  SinusLiftTechnique? technique,
  String note = '',
}) {
  if (!applies || !sinusLift) return null;
  if (technique == null) return 'Informe o tipo de levantamento de seio.';
  if (technique == SinusLiftTechnique.outro && note.trim().isEmpty) {
    return 'Descreva o tipo de levantamento de seio.';
  }
  return null;
}

List<int> archOf(int tooth) =>
    upperArch.contains(tooth) ? upperArch : lowerArch;

Arch sideOf(int tooth) =>
    upperArch.contains(tooth) ? Arch.superior : Arch.inferior;

int compareTeeth(int a, int b) => chipOrder.indexOf(a).compareTo(chipOrder.indexOf(b));

bool isContiguousSpan(Iterable<int> teeth) {
  final list = teeth.toList();
  if (list.length < 2) return true;
  final arch = archOf(list.first);
  if (list.any((tooth) => !arch.contains(tooth))) return false;
  final indexes = list.map(arch.indexOf).toList()..sort();
  for (var i = 1; i < indexes.length; i++) {
    if (indexes[i] != indexes[i - 1] + 1) return false;
  }
  return true;
}

String modalityLabel(Modality modality) => switch (modality) {
      Modality.implante => 'Implante',
      Modality.enxerto => 'Cirurgia de Enxerto',
      Modality.protese => 'Prótese sobre implante',
    };

List<ProcedureSubtype> subtypesOf(Modality modality) => switch (modality) {
      Modality.implante => const [ProcedureSubtype.unitario, ProcedureSubtype.protocolo],
      Modality.protese => const [
          ProcedureSubtype.unitario,
          ProcedureSubtype.ponte,
          ProcedureSubtype.protocolo,
        ],
      Modality.enxerto => const [],
    };

String subtypeLabel(Modality modality, ProcedureSubtype subtype) => switch ((modality, subtype)) {
      (Modality.implante, ProcedureSubtype.unitario) => 'Unitário',
      (Modality.implante, ProcedureSubtype.protocolo) => 'Protocolo',
      (Modality.protese, ProcedureSubtype.unitario) => 'Unitária',
      (Modality.protese, ProcedureSubtype.ponte) => 'Ponte fixa',
      (Modality.protese, ProcedureSubtype.protocolo) => 'Protocolo',
      _ => '',
    };

String classificationLabelFor({
  required Modality modality,
  ProcedureSubtype? subtype,
  bool associatedGraft = false,
}) {
  final sub = subtype;
  final base = sub == null
      ? modalityLabel(modality)
      : '${modalityLabel(modality)} · ${subtypeLabel(modality, sub)}';
  if (associatedGraft) return '$base · com enxerto';
  return base;
}

String archLabel(Arch arch) =>
    arch == Arch.superior ? 'Arcada superior' : 'Arcada inferior';

String roleLabel(ToothRole role) => role == ToothRole.pilar ? 'Pilar' : 'Pôntico';

String implantStatusLabel(ImplantStatus status) => switch (status) {
      ImplantStatus.planejado => 'Planejado',
      ImplantStatus.instalado => 'Instalado',
      ImplantStatus.osseointegracao => 'Em osseointegração',
      ImplantStatus.reabertura => 'Reabertura',
      ImplantStatus.protese => 'Prótese',
      ImplantStatus.concluido => 'Concluído',
      ImplantStatus.manutencao => 'Manutenção',
      ImplantStatus.intercorrencia => 'Intercorrência',
    };

String graftStatusLabel(GraftStatus status) => switch (status) {
      GraftStatus.planejado => 'Planejado',
      GraftStatus.realizado => 'Realizado',
      GraftStatus.maturacao => 'Em maturação',
      GraftStatus.prontoParaImplante => 'Pronto para implante',
      GraftStatus.intercorrencia => 'Intercorrência',
    };

/// Forma usada pela API (`planejado`). Aceita o nome do enum ou o rótulo da UI.
String clinicalStatusWire(String statusLabel, Modality modality) {
  if (modality == Modality.enxerto) {
    for (final status in GraftStatus.values) {
      if (status.name == statusLabel || graftStatusLabel(status) == statusLabel) {
        return status.name;
      }
    }
  } else {
    for (final status in ImplantStatus.values) {
      if (status.name == statusLabel || implantStatusLabel(status) == statusLabel) {
        return status.name;
      }
    }
  }
  return statusLabel;
}

/// Rótulo da UI a partir do valor da API ou do rótulo já local.
String clinicalStatusDisplay(String statusLabel, Modality modality) {
  if (modality == Modality.enxerto) {
    for (final status in GraftStatus.values) {
      if (status.name == statusLabel) return graftStatusLabel(status);
      if (graftStatusLabel(status) == statusLabel) return statusLabel;
    }
  } else {
    for (final status in ImplantStatus.values) {
      if (status.name == statusLabel) return implantStatusLabel(status);
      if (implantStatusLabel(status) == statusLabel) return statusLabel;
    }
  }
  return statusLabel;
}

String graftMaterialChoiceLabel(GraftMaterialChoice choice) => switch (choice) {
      GraftMaterialChoice.autogeno => 'Osso autógeno',
      GraftMaterialChoice.liofilizado => 'Osso liofilizado',
    };

String graftPresentationLabel(GraftPresentation presentation) => switch (presentation) {
      GraftPresentation.bloco => 'Em bloco',
      GraftPresentation.po => 'Em pó',
    };

String sinusLiftTechniqueLabel(SinusLiftTechnique technique) => switch (technique) {
      SinusLiftTechnique.janelaLateral => 'Janela lateral',
      SinusLiftTechnique.transalveolar => 'Transalveolar',
      SinusLiftTechnique.outro => 'Outro',
    };

String graftTraceLabel(GraftMaterial graft) {
  final choice = graftMaterialChoice(graft.origin, graft.processing);
  if (choice == GraftMaterialChoice.autogeno) {
    return [
      graftMaterialChoiceLabel(choice!),
      if (graft.presentation != null) graftPresentationLabel(graft.presentation!),
      if (graft.donorSite.isNotEmpty) 'região doadora ${graft.donorSite}',
    ].join(' · ');
  }
  if (choice == GraftMaterialChoice.liofilizado) {
    return [
      graftMaterialChoiceLabel(choice!),
      if (graft.presentation != null) graftPresentationLabel(graft.presentation!),
      if (graft.manufacturer.isNotEmpty) graft.manufacturer,
      if (graft.model.isNotEmpty) graft.model,
      if (graft.productType.isNotEmpty) graft.productType,
      if (graft.granulometry.isNotEmpty) graft.granulometry,
    ].join(' · ');
  }
  final legacy = [
    'Enxerto',
    if (graft.manufacturer.isNotEmpty) graft.manufacturer,
    if (graft.model.isNotEmpty) graft.model,
  ].join(' ');
  if (graft.size.isEmpty) return legacy;
  return '$legacy · ${graft.size}';
}

String? sinusLiftSummary({
  required bool sinusLift,
  SinusLiftTechnique? technique,
  String note = '',
}) {
  if (!sinusLift) return null;
  if (technique == null) return 'Levantamento de seio';
  if (technique == SinusLiftTechnique.outro) {
    final described = note.trim();
    return described.isEmpty ? 'Levantamento de seio · Outro' : 'Levantamento de seio · $described';
  }
  return 'Levantamento de seio · ${sinusLiftTechniqueLabel(technique)}';
}

String returnReasonLabel(ReturnReason reason) => switch (reason) {
      ReturnReason.sutura => 'Remoção de sutura',
      ReturnReason.osseointegracao => 'Osseointegração',
      ReturnReason.instalarImplante => 'Instalar o implante',
      ReturnReason.instalarPonte => 'Instalar a ponte',
      ReturnReason.instalarProtocolo => 'Instalar o protocolo',
      ReturnReason.controle => 'Retorno de controle',
      ReturnReason.reabertura => 'Retorno para reabertura',
    };

int returnReasonOrder(ReturnReason reason) => switch (reason) {
      ReturnReason.sutura => 0,
      ReturnReason.controle => 1,
      ReturnReason.reabertura => 2,
      ReturnReason.osseointegracao => 3,
      ReturnReason.instalarImplante => 3,
      ReturnReason.instalarPonte => 3,
      ReturnReason.instalarProtocolo => 3,
    };

List<FollowUp> chronologicalFollowUps(List<FollowUp> followUps) {
  return [...followUps]..sort((a, b) {
      final byDate = dateOnly(a.date).compareTo(dateOnly(b.date));
      if (byDate != 0) return byDate;
      return returnReasonOrder(a.reason).compareTo(returnReasonOrder(b.reason));
    });
}

String returnStatusLabel(ReturnStatus status) => switch (status) {
      ReturnStatus.agendado => 'Agendado',
      ReturnStatus.realizado => 'Realizado',
      ReturnStatus.faltou => 'Faltou',
    };

String followUpPhaseLabel(FollowUpPhase phase) => switch (phase) {
      FollowUpPhase.provisional => 'Provisório',
      FollowUpPhase.definitive => 'Definitivo',
    };

String prosthesisFollowUpStatusLabel(ProsthesisFollowUpStatus status) => switch (status) {
      ProsthesisFollowUpStatus.molded => 'Moldado',
      ProsthesisFollowUpStatus.sentToLab => 'Enviado ao laboratório',
      ProsthesisFollowUpStatus.returnedFromLab => 'Retorno do laboratório',
      ProsthesisFollowUpStatus.installed => 'Instalada',
    };

/// Wire L2S-74 (+ legado snake_case local).
ProsthesisFollowUpStatus? parseProsthesisFollowUpStatus(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case 'molded':
    case 'moldado':
      return ProsthesisFollowUpStatus.molded;
    case 'sentToLab':
    case 'sent_to_lab':
    case 'enviadoLaboratorio':
      return ProsthesisFollowUpStatus.sentToLab;
    case 'returnedFromLab':
    case 'returned_from_lab':
    case 'retornoLaboratorio':
      return ProsthesisFollowUpStatus.returnedFromLab;
    case 'installed':
    case 'instalada':
      return ProsthesisFollowUpStatus.installed;
    default:
      return null;
  }
}

FollowUpPhase? parseFollowUpPhase(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case 'provisional':
    case 'provisorio':
      return FollowUpPhase.provisional;
    case 'definitive':
    case 'definitivo':
      return FollowUpPhase.definitive;
    default:
      return null;
  }
}

/// Chave de statusDates: aceita wire atual e legado snake_case.
String normalizeProsthesisStatusDateKey(String key) {
  return parseProsthesisFollowUpStatus(key)?.name ?? key;
}

const defaultReminderDaysBefore = 15;

const reminderLeadDayOptions = <int>[7, 15, 30];

int normalizeReminderDaysBefore(int days) =>
    days < 1 ? defaultReminderDaysBefore : days;

class CareLocation {
  const CareLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.active = true,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String address;
  final bool active;
  final bool isDefault;

  CareLocation copyWith({
    String? name,
    String? address,
    bool? active,
    bool? isDefault,
  }) {
    return CareLocation(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      active: active ?? this.active,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// WorkOS/Android às vezes entregam a literal `"null"`; trata como ausente.
String sanitizePersonName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower == 'null' || lower == 'undefined') return '';
  return trimmed;
}

String displayDentistName(String? value) {
  final cleaned = sanitizePersonName(value);
  return cleaned.isEmpty ? 'Nome não informado' : cleaned;
}

class DentistProfile {
  const DentistProfile({
    required this.name,
    required this.email,
    this.phone = '',
    this.cro = '',
    this.reminderEnabled = true,
    this.reminderDaysBefore = defaultReminderDaysBefore,
    this.emailChannel = true,
    this.pushChannel = true,
    this.locations = const [],
  });

  final String name;
  final String email;
  final String phone;
  final String cro;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final bool emailChannel;
  final bool pushChannel;
  final List<CareLocation> locations;

  DentistProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? cro,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    bool? emailChannel,
    bool? pushChannel,
    List<CareLocation>? locations,
  }) {
    return DentistProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cro: cro ?? this.cro,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      emailChannel: emailChannel ?? this.emailChannel,
      pushChannel: pushChannel ?? this.pushChannel,
      locations: locations ?? this.locations,
    );
  }
}

enum ImplantOrigin { preexisting, procedureRecorded }

String implantOriginLabel(ImplantOrigin origin) => switch (origin) {
      ImplantOrigin.preexisting => 'Preexistente / histórico informado',
      ImplantOrigin.procedureRecorded => 'Cirurgia no sistema',
    };

ImplantOrigin implantOriginFromWire(String? value) => switch (value) {
      'procedure_recorded' => ImplantOrigin.procedureRecorded,
      _ => ImplantOrigin.preexisting,
    };

String implantOriginWire(ImplantOrigin origin) => switch (origin) {
      ImplantOrigin.preexisting => 'preexisting',
      ImplantOrigin.procedureRecorded => 'procedure_recorded',
    };

class InstalledImplant {
  const InstalledImplant({
    required this.id,
    required this.patientId,
    required this.fdi,
    required this.origin,
    this.sourceProcedureId,
    this.manufacturer = '',
    this.model = '',
    this.size = '',
    this.lot = '',
    this.installedOn,
    this.originClinic = '',
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String patientId;
  final int fdi;
  final ImplantOrigin origin;
  final String? sourceProcedureId;
  final String manufacturer;
  final String model;
  final String size;
  final String lot;
  final DateTime? installedOn;
  final String originClinic;
  final String notes;
  final bool active;

  String get title => 'Dente $fdi';

  String get subtitle {
    final piece = [manufacturer, model].where((part) => part.isNotEmpty).join(' ');
    return [
      implantOriginLabel(origin),
      if (piece.isNotEmpty) piece,
      if (!active) 'Inativo',
    ].join(' · ');
  }

  InstalledImplant copyWith({
    int? fdi,
    String? manufacturer,
    String? model,
    String? size,
    String? lot,
    DateTime? installedOn,
    String? originClinic,
    String? notes,
    bool? active,
    bool clearInstalledOn = false,
  }) {
    return InstalledImplant(
      id: id,
      patientId: patientId,
      fdi: fdi ?? this.fdi,
      origin: origin,
      sourceProcedureId: sourceProcedureId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      size: size ?? this.size,
      lot: lot ?? this.lot,
      installedOn: clearInstalledOn ? null : installedOn ?? this.installedOn,
      originClinic: originClinic ?? this.originClinic,
      notes: notes ?? this.notes,
      active: active ?? this.active,
    );
  }
}

class PreexistingImplantDraft {
  const PreexistingImplantDraft({
    required this.fdi,
    this.manufacturer = '',
    this.model = '',
    this.size = '',
    this.lot = '',
    this.installedOn,
    this.originClinic = '',
    this.notes = '',
    this.active = true,
  });

  final int fdi;
  final String manufacturer;
  final String model;
  final String size;
  final String lot;
  final DateTime? installedOn;
  final String originClinic;
  final String notes;
  final bool active;
}

class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
    this.email = '',
    this.cpf = '',
    this.notes = '',
    this.guardian = '',
    this.locationIds = const [],
    this.notifyByEmail = false,
    this.notifyByPhone = false,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String cpf;
  final DateTime birthDate;
  final String notes;
  final String guardian;
  final List<String> locationIds;
  final bool notifyByEmail;
  final bool notifyByPhone;

  bool get isMinor {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final birthday = DateTime(today.year, birthDate.month, birthDate.day);
    if (birthday.isAfter(DateTime(today.year, today.month, today.day))) age--;
    return age < 18;
  }

  Patient copyWith({
    String? name,
    String? phone,
    String? email,
    String? cpf,
    DateTime? birthDate,
    String? notes,
    String? guardian,
    List<String>? locationIds,
    bool? notifyByEmail,
    bool? notifyByPhone,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      cpf: cpf ?? this.cpf,
      birthDate: birthDate ?? this.birthDate,
      notes: notes ?? this.notes,
      guardian: guardian ?? this.guardian,
      locationIds: locationIds ?? this.locationIds,
      notifyByEmail: notifyByEmail ?? this.notifyByEmail,
      notifyByPhone: notifyByPhone ?? this.notifyByPhone,
    );
  }
}

enum NoticeDelivery { aguardando, falha, revogada, enviado }

class StageNotice {
  const StageNotice({
    required this.id,
    required this.stageLabel,
    required this.channels,
    required this.delivery,
    required this.createdAt,
  });

  final String id;
  final String stageLabel;
  final List<String> channels;
  final NoticeDelivery delivery;
  final DateTime createdAt;

  StageNotice copyWith({NoticeDelivery? delivery, List<String>? channels}) {
    return StageNotice(
      id: id,
      stageLabel: stageLabel,
      channels: channels ?? this.channels,
      delivery: delivery ?? this.delivery,
      createdAt: createdAt,
    );
  }
}

class ImplantPiece {
  const ImplantPiece({
    this.manufacturer = '',
    this.model = '',
    this.reference = '',
    this.size = '',
    this.lot = '',
    this.manufacturedOn,
    this.expiresOn,
    this.anvisa = '',
  });

  final String manufacturer;
  final String model;
  final String reference;
  final String size;
  final String lot;
  final DateTime? manufacturedOn;
  final DateTime? expiresOn;
  final String anvisa;

  bool get certificateReady =>
      manufacturer.isNotEmpty && model.isNotEmpty && size.isNotEmpty;
}

class GraftMaterial {
  const GraftMaterial({
    required this.origin,
    this.processing,
    this.presentation,
    this.manufacturer = '',
    this.model = '',
    this.productType = '',
    this.granulometry = '',
    this.size = '',
    this.lot = '',
    this.manufacturedOn,
    this.expiresOn,
    this.anvisa = '',
    this.donorSite = '',
  });

  final GraftOrigin origin;
  final GraftProcessing? processing;
  final GraftPresentation? presentation;
  final String manufacturer;
  final String model;
  final String productType;
  final String granulometry;
  final String size;
  final String lot;
  final DateTime? manufacturedOn;
  final DateTime? expiresOn;
  final String anvisa;
  final String donorSite;

  bool get certificateReady => switch (origin) {
        GraftOrigin.biomaterial when processing == GraftProcessing.liofilizado =>
          manufacturer.isNotEmpty &&
              model.isNotEmpty &&
              productType.isNotEmpty &&
              presentation != null &&
              (presentation != GraftPresentation.po || granulometry.isNotEmpty) &&
              (presentation != GraftPresentation.bloco || granulometry.isEmpty),
        GraftOrigin.biomaterial =>
          manufacturer.isNotEmpty && model.isNotEmpty,
        GraftOrigin.autogeno => donorSite.isNotEmpty,
      };
}

class ToothSite {
  const ToothSite({
    required this.fdi,
    required this.role,
    this.piece,
    this.grafts = const [],
  });

  final int fdi;
  final ToothRole role;
  final ImplantPiece? piece;
  final List<GraftMaterial> grafts;
}

class Visit {
  Visit({
    required this.id,
    required this.date,
    required this.note,
    required this.statusLabel,
  });

  final String id;
  final DateTime date;
  final String note;
  final String statusLabel;
}

class ClinicPhoto {
  const ClinicPhoto({
    required this.id,
    required this.caption,
    this.path = '',
    this.visitId,
  });

  final String id;
  final String caption;
  final String path;
  final String? visitId;
}

class FollowUp {
  const FollowUp({
    required this.id,
    required this.date,
    required this.reason,
    required this.status,
    required this.reminderEnabled,
    this.reminderDaysBefore = defaultReminderDaysBefore,
    this.overdueNotified = false,
    this.phase,
    this.prosthesisStatus,
    this.statusDates = const {},
  });

  final String id;
  final DateTime date;
  final ReturnReason reason;
  final ReturnStatus status;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final bool overdueNotified;

  /// Follow-up de prótese (ADR-003). `null` = retorno clínico clássico.
  final FollowUpPhase? phase;
  final ProsthesisFollowUpStatus? prosthesisStatus;

  /// Datas opcionais por status do definitivo (chave = wire EN, ex. `sentToLab`).
  final Map<String, DateTime?> statusDates;

  bool get isProsthesisTrack => phase != null;

  DateTime get reminderOn => dateOnly(date).subtract(Duration(days: reminderDaysBefore));

  FollowUp copyWith({
    DateTime? date,
    ReturnReason? reason,
    ReturnStatus? status,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    bool? overdueNotified,
    FollowUpPhase? phase,
    ProsthesisFollowUpStatus? prosthesisStatus,
    Map<String, DateTime?>? statusDates,
    bool clearPhase = false,
    bool clearProsthesisStatus = false,
  }) {
    return FollowUp(
      id: id,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      overdueNotified: overdueNotified ?? this.overdueNotified,
      phase: clearPhase ? null : (phase ?? this.phase),
      prosthesisStatus: clearProsthesisStatus ? null : (prosthesisStatus ?? this.prosthesisStatus),
      statusDates: statusDates ?? this.statusDates,
    );
  }
}

class Procedure {
  Procedure({
    required this.id,
    required this.patientId,
    required this.modality,
    required this.surgeryDate,
    required this.sites,
    required this.statusLabel,
    this.subtype,
    this.associatedGraft = false,
    this.sinusLift = false,
    this.sinusLiftTechnique,
    this.sinusLiftNote = '',
    List<String>? linkedProcedureIds,
    List<String>? linkedImplantIds,
    this.arch,
    this.notes = '',
    List<Visit>? visits,
    List<FollowUp>? followUps,
    List<ClinicPhoto>? photos,
    List<StageNotice>? stageNotices,
    this.certificateIssuedAt,
    this.certificatePdfPath,
  })  : visits = visits ?? [],
        followUps = followUps ?? [],
        photos = photos ?? [],
        stageNotices = stageNotices ?? [],
        linkedProcedureIds = linkedProcedureIds ?? const [],
        linkedImplantIds = linkedImplantIds ?? const [];

  final String id;
  final String patientId;
  final Modality modality;
  final ProcedureSubtype? subtype;
  final bool associatedGraft;
  final bool sinusLift;
  final SinusLiftTechnique? sinusLiftTechnique;
  final String sinusLiftNote;
  final List<String> linkedProcedureIds;
  final List<String> linkedImplantIds;
  final Arch? arch;
  final DateTime surgeryDate;
  final String statusLabel;
  final String notes;
  final List<ToothSite> sites;
  final List<Visit> visits;
  final List<FollowUp> followUps;
  final List<ClinicPhoto> photos;
  final List<StageNotice> stageNotices;
  final DateTime? certificateIssuedAt;
  final String? certificatePdfPath;

  Procedure copyWith({
    String? statusLabel,
    String? notes,
    List<ToothSite>? sites,
    List<Visit>? visits,
    List<FollowUp>? followUps,
    List<ClinicPhoto>? photos,
    DateTime? certificateIssuedAt,
    String? certificatePdfPath,
    bool? sinusLift,
    SinusLiftTechnique? sinusLiftTechnique,
    String? sinusLiftNote,
    List<StageNotice>? stageNotices,
  }) {
    final lift = sinusLift ?? this.sinusLift;
    return Procedure(
      id: id,
      patientId: patientId,
      modality: modality,
      subtype: subtype,
      associatedGraft: associatedGraft,
      sinusLift: lift,
      sinusLiftTechnique: lift ? sinusLiftTechnique ?? this.sinusLiftTechnique : null,
      sinusLiftNote: lift ? sinusLiftNote ?? this.sinusLiftNote : '',
      linkedProcedureIds: linkedProcedureIds,
      linkedImplantIds: linkedImplantIds,
      surgeryDate: surgeryDate,
      sites: sites ?? this.sites,
      statusLabel: statusLabel ?? this.statusLabel,
      arch: arch,
      notes: notes ?? this.notes,
      visits: visits ?? this.visits,
      followUps: followUps ?? this.followUps,
      photos: photos ?? this.photos,
      stageNotices: stageNotices ?? this.stageNotices,
      certificateIssuedAt: certificateIssuedAt ?? this.certificateIssuedAt,
      certificatePdfPath: certificatePdfPath ?? this.certificatePdfPath,
    );
  }

  String? get sinusLiftLabel => sinusLiftSummary(
        sinusLift: sinusLift,
        technique: sinusLiftTechnique,
        note: sinusLiftNote,
      );

  List<ToothSite> get pillars =>
      sites.where((site) => site.role == ToothRole.pilar).toList();

  List<ToothSite> get pontics =>
      sites.where((site) => site.role == ToothRole.pontico).toList();

  String get teethLabel {
    final numbers = sites.map((site) => site.fdi).toList()..sort(compareTeeth);
    if (subtype == ProcedureSubtype.protocolo && arch != null) {
      return '${archLabel(arch!)} · ${numbers.join(', ')}';
    }
    return numbers.join(', ');
  }

  bool get isProtocol => subtype == ProcedureSubtype.protocolo;

  String get classificationLabel => classificationLabelFor(
        modality: modality,
        subtype: subtype,
        associatedGraft: associatedGraft,
      );
}

class CalendarMark {
  CalendarMark({
    required this.date,
    required this.patientId,
    required this.patientName,
    required this.kind,
    required this.label,
    required this.procedureId,
    this.returnStatus,
    this.overdue = false,
  });

  final DateTime date;
  final String patientId;
  final String patientName;
  final CalendarKind kind;
  final String label;
  final String procedureId;
  final ReturnStatus? returnStatus;
  final bool overdue;
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

const validBrazilianAreaCodes = {
  '11', '12', '13', '14', '15', '16', '17', '18', '19',
  '21', '22', '24', '27', '28',
  '31', '32', '33', '34', '35', '37', '38',
  '41', '42', '43', '44', '45', '46', '47', '48', '49',
  '51', '53', '54', '55',
  '61', '62', '63', '64', '65', '66', '67', '68', '69',
  '71', '73', '74', '75', '77', '79',
  '81', '82', '83', '84', '85', '86', '87', '88', '89',
  '91', '92', '93', '94', '95', '96', '97', '98', '99',
};

String brazilianPhoneDigits(String value) {
  var digits = digitsOnly(value);
  if (digits.startsWith('55') && (digits.length == 12 || digits.length == 13)) {
    digits = digits.substring(2);
  }
  if (digits.length > 11) digits = digits.substring(0, 11);
  return digits;
}

String formatBrazilianPhone(String value) {
  final digits = brazilianPhoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';
  final area = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (digits.length <= 6) return '($area) $rest';
  if (digits.length <= 10) {
    return '($area) ${rest.substring(0, 4)}-${rest.substring(4)}';
  }
  return '($area) ${rest.substring(0, 5)}-${rest.substring(5)}';
}

bool isValidBrazilianPhone(String value) {
  final digits = brazilianPhoneDigits(value);
  if (digits.length != 10 && digits.length != 11) return false;
  return validBrazilianAreaCodes.contains(digits.substring(0, 2));
}

bool isValidEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

String? brazilianPhoneIssue(String value) {
  final digits = brazilianPhoneDigits(value);
  if (digits.isEmpty) return null;
  if (digits.length != 10 && digits.length != 11) {
    return 'Informe DDD e número, com 10 ou 11 dígitos.';
  }
  if (!validBrazilianAreaCodes.contains(digits.substring(0, 2))) {
    return 'Informe um DDD válido.';
  }
  return null;
}

String? emailIssue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || isValidEmail(trimmed)) return null;
  return 'Informe um e-mail válido.';
}

String formatCpf(String value) {
  final raw = digitsOnly(value);
  final digits = raw.length > 11 ? raw.substring(0, 11) : raw;
  if (digits.isEmpty) return '';
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) return '${digits.substring(0, 3)}.${digits.substring(3)}';
  if (digits.length <= 9) return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
}

bool isValidCpf(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
  int verifier(int length) {
    var sum = 0;
    for (var index = 0; index < length; index++) {
      sum += int.parse(digits[index]) * (length + 1 - index);
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  return verifier(9) == int.parse(digits[9]) && verifier(10) == int.parse(digits[10]);
}

String? cpfIssue(String value) {
  final digits = digitsOnly(value);
  if (digits.isEmpty) return null;
  if (!isValidCpf(digits)) return 'Informe um CPF válido.';
  return null;
}

class MaskedDigits {
  const MaskedDigits(this.text, this.offset);

  final String text;
  final int offset;
}

MaskedDigits applyDigitMask({
  required String previous,
  required String incoming,
  required int cursor,
  required String Function(String value) format,
}) {
  final bounded = cursor.clamp(0, incoming.length);
  var digits = digitsOnly(incoming);
  var digitsBefore = digitsOnly(incoming.substring(0, bounded)).length;
  if (digits == digitsOnly(previous) && incoming.length < previous.length && digitsBefore > 0) {
    digits = digits.substring(0, digitsBefore - 1) + digits.substring(digitsBefore);
    digitsBefore -= 1;
  }
  final text = format(digits);
  return MaskedDigits(text, offsetAfterDigits(text, digitsBefore));
}

int offsetAfterDigits(String text, int count) {
  if (count <= 0) return 0;
  var seen = 0;
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    if (unit >= 48 && unit <= 57) {
      seen++;
      if (seen == count) return index + 1;
    }
  }
  return text.length;
}

String cpfLabel(String value) {
  final formatted = formatCpf(value);
  return formatted.isEmpty ? 'CPF não informado' : formatted;
}

String formatDay(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Monta o texto único de endereço do local a partir dos campos estruturados (L2S-68).
String formatStructuredAddress({
  String street = '',
  String number = '',
  String neighborhood = '',
  String city = '',
  String state = '',
  String cep = '',
  String complement = '',
}) {
  final parts = <String>[];
  final line1 = [
    street.trim(),
    if (number.trim().isNotEmpty) number.trim(),
  ].where((part) => part.isNotEmpty).join(', ');
  if (line1.isNotEmpty) parts.add(line1);
  if (neighborhood.trim().isNotEmpty) parts.add(neighborhood.trim());
  final cityState = [
    city.trim(),
    if (state.trim().isNotEmpty) state.trim().toUpperCase(),
  ].where((part) => part.isNotEmpty).join('/');
  if (cityState.isNotEmpty) parts.add(cityState);
  final digits = digitsOnly(cep);
  if (digits.isNotEmpty) {
    final label = digits.length == 8 ? '${digits.substring(0, 5)}-${digits.substring(5)}' : digits;
    parts.add('CEP $label');
  }
  if (complement.trim().isNotEmpty) parts.add(complement.trim());
  return parts.join(' · ');
}

String formatCepInput(String raw) {
  final digits = digitsOnly(raw);
  if (digits.length <= 5) return digits;
  final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
  return '${clipped.substring(0, 5)}-${clipped.substring(5)}';
}


DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Civil day in America/Sao_Paulo. Brasília stays at UTC−3, without daylight saving.
DateTime brasiliaToday([DateTime? instant]) {
  final utc = (instant ?? DateTime.now()).toUtc();
  final civil = utc.subtract(const Duration(hours: 3));
  return DateTime(civil.year, civil.month, civil.day);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addCalendarMonths(DateTime date, int months) {
  final total = date.month + months;
  final year = date.year + ((total - 1) ~/ 12);
  final month = ((total - 1) % 12) + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(year, month, day);
}

String reminderLine({
  required Patient patient,
  required Procedure procedure,
  required FollowUp followUp,
}) {
  return '${patient.name}, ${procedure.teethLabel}, ${returnReasonLabel(followUp.reason)}';
}

String reminderLeadChipLabel(int days) => days == 1 ? '1 dia' : '$days dias';

String reminderLeadLabel(int days) => '${reminderLeadChipLabel(days)} antes';
