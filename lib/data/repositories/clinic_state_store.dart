import 'dart:async';
import 'dart:typed_data';

import '../../domain/clinic_snapshot.dart';
import '../../domain/models.dart';
import '../../domain/practice.dart';
import '../services/api_feedback.dart';
import '../services/cep_lookup.dart';
import '../services/clinic_api.dart';
import 'clinic_repository.dart';

/// Estado mutável do prontuário em memória (cache local + persistência opcional).
class ClinicStateStore implements ClinicRepository {
  ClinicStateStore.fromSnapshot(
    this._snapshot, {
    this._persist,
    this.ids,
  });

  ClinicSnapshot _snapshot;
  final Future<void> Function(ClinicSnapshot snapshot)? _persist;
  final String Function()? ids;
  final _updates = StreamController<ClinicSnapshot>.broadcast();
  final List<String> _delayNoticeFollowUpIds = [];

  @override
  ClinicSnapshot get current => _snapshot;

  @override
  ClinicalCatalog get catalog => activeClinicalCatalog;

  @override
  List<String> get delayNoticeFollowUpIds =>
      List.unmodifiable(_delayNoticeFollowUpIds);

  @override
  Stream<ClinicSnapshot> watch() async* {
    yield _snapshot;
    yield* _updates.stream;
  }

  void _emit(ClinicSnapshot next) {
    _snapshot = next;
    _updates.add(next);
    _persist?.call(next);
  }

  @override
  Stream<String> get syncErrors => const Stream<String>.empty();

  @override
  Stream<ApiFeedback> get feedback => const Stream<ApiFeedback>.empty();

  @override
  void bindUnauthorized(Future<String?> Function() refresh) {}

  @override
  void bindCatalog(void Function(ClinicalCatalog catalog) apply) {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshCatalog() async {}

  @override
  Future<CepAddress> lookupCep(String cep) async {
    throw const ClinicApiException(
      0,
      'Consulta de CEP disponível apenas com a API.',
      code: 'viacep_unavailable',
    );
  }

  @override
  void applyOverdueNotices() {
    _delayNoticeFollowUpIds.clear();
    final today = brasiliaToday();
    var changed = false;
    final procedures = <Procedure>[];
    for (final procedure in _snapshot.procedures) {
      final followUps = <FollowUp>[];
      for (final followUp in procedure.followUps) {
        final shouldNotify = followUp.status == ReturnStatus.agendado &&
            dateOnly(followUp.date).isBefore(today) &&
            !followUp.overdueNotified;
        if (shouldNotify) {
          changed = true;
          _delayNoticeFollowUpIds.add(followUp.id);
          followUps.add(followUp.copyWith(overdueNotified: true));
        } else {
          followUps.add(followUp);
        }
      }
      procedures.add(procedure.copyWith(followUps: followUps));
    }
    if (changed) {
      _emit(_snapshot.copyWith(procedures: procedures));
    }
  }

  void replaceSnapshot(ClinicSnapshot snapshot) => _emit(snapshot);

  @override
  void signIn({required String name, required String email, String accessToken = ''}) {
    final cleaned = sanitizePersonName(name);
    final kept = sanitizePersonName(_snapshot.profile.name);
    _emit(
      _snapshot.copyWith(
        signedIn: true,
        profile: _snapshot.profile.copyWith(
          name: cleaned.isNotEmpty ? cleaned : kept,
          email: email,
        ),
      ),
    );
  }

  @override
  void signOut() {
    _emit(_snapshot.copyWith(signedIn: false));
  }

  @override
  String allocateId(String prefix) {
    final next = _snapshot.sequence + 1;
    _snapshot = _snapshot.copyWith(sequence: next);
    return ids?.call() ?? '$prefix-$next';
  }

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
    final patient = normalizePatientContacts(
      Patient(
        id: allocateId('pac'),
        name: name.trim(),
        phone: phone,
        email: email,
        cpf: cpf,
        birthDate: birthDate,
        notes: notes.trim(),
        guardian: guardian.trim(),
        locationIds: locationIds,
        notifyByEmail: notifyByEmail,
        notifyByPhone: notifyByPhone,
      ),
    );
    _emit(_snapshot.copyWith(patients: [..._snapshot.patients, patient]));
    return patient;
  }

  @override
  void updatePatient(Patient patient) {
    final normalized = normalizePatientContacts(patient);
    _emit(
      _snapshot.copyWith(
        patients: [
          for (final item in _snapshot.patients)
            if (item.id == normalized.id) normalized else item,
        ],
        procedures: [
          for (final procedure in _snapshot.procedures)
            if (procedure.patientId == normalized.id)
              procedure.copyWith(
                stageNotices: revokePendingNotices(procedure.stageNotices, normalized),
              )
            else
              procedure,
        ],
      ),
    );
  }

  @override
  void saveProcedures(List<Procedure> created) {
    final provisioned = <InstalledImplant>[
      for (final procedure in created)
        if (procedure.modality == Modality.implante)
          for (final site in procedure.sites)
            if (site.role == ToothRole.pilar)
              InstalledImplant(
                id: allocateId('imp'),
                patientId: procedure.patientId,
                fdi: site.fdi,
                origin: ImplantOrigin.procedureRecorded,
                sourceProcedureId: procedure.id,
                manufacturer: site.piece?.manufacturer ?? '',
                model: site.piece?.model ?? '',
                size: site.piece?.size ?? '',
                lot: site.piece?.lot ?? '',
                installedOn: procedure.surgeryDate,
              ),
    ];
    _emit(
      _snapshot.copyWith(
        procedures: [..._snapshot.procedures, ...created],
        implants: [..._snapshot.implants, ...provisioned],
      ),
    );
  }

  @override
  InstalledImplant createInstalledImplant(InstalledImplant implant) {
    final saved = implant.origin == ImplantOrigin.preexisting
        ? implant
        : implant.copyWith();
    _emit(_snapshot.copyWith(implants: [..._snapshot.implants, saved]));
    return saved;
  }

  @override
  void updateInstalledImplant(InstalledImplant implant) {
    _emit(
      _snapshot.copyWith(
        implants: [
          for (final item in _snapshot.implants)
            if (item.id == implant.id) implant else item,
        ],
      ),
    );
  }

  @override
  void updateProcedure(Procedure procedure) {
    _replace(procedure.id, (_) => procedure);
  }

  @override
  void addPhoto(String procedureId, ClinicPhoto photo) {
    _replace(procedureId, (procedure) {
      return procedure.copyWith(photos: [...procedure.photos, photo]);
    });
  }

  @override
  void addVisit({
    required String procedureId,
    required String note,
    required String statusLabel,
  }) {
    _replace(procedureId, (procedure) {
      return procedure.copyWith(
        statusLabel: statusLabel,
        visits: [
          ...procedure.visits,
          Visit(
            id: allocateId('con'),
            date: DateTime.now(),
            note: note.trim().isEmpty ? 'Consulta' : note.trim(),
            statusLabel: statusLabel,
          ),
        ],
        stageNotices: _withNotice(
          procedure,
          previousStatus: procedure.statusLabel,
          nextStatus: statusLabel,
          clinicalChange: true,
        ),
      );
    });
  }

  @override
  void completeFollowUp({
    required String followUpId,
    required String note,
    required String statusLabel,
    required ReturnStatus returnStatus,
  }) {
    final procedure = _procedureOfFollowUp(followUpId);
    if (procedure == null) return;
    final followUp = procedure.followUps.where((item) => item.id == followUpId).first;
    final updatesClinicalStatus =
        returnStatus == ReturnStatus.realizado && followUp.reason != ReturnReason.sutura;
    final visits = [...procedure.visits];
    if (returnStatus == ReturnStatus.realizado) {
      visits.add(
        Visit(
          id: allocateId('con'),
          date: DateTime.now(),
          note: note.trim().isEmpty ? returnReasonLabel(followUp.reason) : note.trim(),
          statusLabel: updatesClinicalStatus ? statusLabel : procedure.statusLabel,
        ),
      );
    }
    _replace(procedure.id, (current) {
      final nextStatus = updatesClinicalStatus ? statusLabel : current.statusLabel;
      return current.copyWith(
        statusLabel: nextStatus,
        followUps: [
          for (final item in current.followUps)
            if (item.id == followUpId) item.copyWith(status: returnStatus) else item,
        ],
        visits: visits,
        stageNotices: _withNotice(
          current,
          previousStatus: current.statusLabel,
          nextStatus: nextStatus,
          clinicalChange: updatesClinicalStatus,
        ),
      );
    });
  }

  @override
  void updateProsthesisFollowUp({
    required String followUpId,
    required ProsthesisFollowUpStatus status,
    DateTime? statusDate,
  }) {
    final procedure = _procedureOfFollowUp(followUpId);
    if (procedure == null) return;
    final current = procedure.followUps.where((item) => item.id == followUpId).first;
    if (!current.isProsthesisTrack || current.phase != FollowUpPhase.definitive) return;
    final dates = Map<String, DateTime?>.from(current.statusDates);
    if (statusDate != null) {
      dates[status.name] = dateOnly(statusDate);
    }
    final updated = current.copyWith(
      prosthesisStatus: status,
      statusDates: dates,
      status: status == ProsthesisFollowUpStatus.installed
          ? ReturnStatus.realizado
          : ReturnStatus.agendado,
    );
    _emit(
      _snapshot.copyWith(
        procedures: [
          for (final item in _snapshot.procedures)
            if (item.id == procedure.id)
              item.copyWith(
                followUps: [
                  for (final followUp in item.followUps)
                    if (followUp.id == followUpId) updated else followUp,
                ],
              )
            else
              item,
        ],
      ),
    );
  }

  @override
  void addProsthesisFollowUp({
    required String procedureId,
    required FollowUpPhase phase,
  }) {
    final procedure = _snapshot.procedures.where((item) => item.id == procedureId).firstOrNull;
    if (procedure == null || procedure.modality != Modality.protese) return;
    final followUp = FollowUp(
      id: allocateId('ret'),
      date: dateOnly(brasiliaToday()),
      reason: ReturnReason.controle,
      status: ReturnStatus.agendado,
      reminderEnabled: false,
      phase: phase,
      prosthesisStatus: phase == FollowUpPhase.definitive ? ProsthesisFollowUpStatus.molded : null,
    );
    _emit(
      _snapshot.copyWith(
        procedures: [
          for (final item in _snapshot.procedures)
            if (item.id == procedureId)
              item.copyWith(followUps: chronologicalFollowUps([...item.followUps, followUp]))
            else
              item,
        ],
      ),
    );
  }


  List<StageNotice> _withNotice(
    Procedure procedure, {
    required String previousStatus,
    required String nextStatus,
    required bool clinicalChange,
  }) {
    final patient = _snapshot.patients.where((item) => item.id == procedure.patientId);
    if (patient.isEmpty) return procedure.stageNotices;
    final plan = stageNoticePlan(
      previousStatus: previousStatus,
      nextStatus: nextStatus,
      clinicalChange: clinicalChange,
      patient: patient.first,
    );
    if (plan == null) return procedure.stageNotices;
    return [
      ...procedure.stageNotices,
      StageNotice(
        id: allocateId('avi'),
        stageLabel: plan.stageLabel,
        channels: plan.channels,
        delivery: NoticeDelivery.aguardando,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  void reprocessStageNotice({required String procedureId, required String noticeId}) {
    _replace(procedureId, (procedure) {
      return procedure.copyWith(stageNotices: reprocessNotice(procedure.stageNotices, noticeId));
    });
  }

  @override
  void failStageNotice({required String procedureId, required String noticeId}) {
    _replace(procedureId, (procedure) {
      return procedure.copyWith(
        stageNotices: [
          for (final notice in procedure.stageNotices)
            if (notice.id == noticeId && notice.delivery == NoticeDelivery.aguardando)
              notice.copyWith(delivery: NoticeDelivery.falha)
            else
              notice,
        ],
      );
    });
  }

  void recordCertificateEmission(String procedureId, {String? pdfPath}) {
    _replace(procedureId, (procedure) {
      return procedure.copyWith(
        certificateIssuedAt: DateTime.now(),
        certificatePdfPath: pdfPath,
      );
    });
  }

  @override
  Future<Uint8List> issueCertificate(
    String procedureId, {
    int copies = 1,
    String? locationId,
  }) async {
    recordCertificateEmission(procedureId);
    return Uint8List(0);
  }

  @override
  void updateProfile(DentistProfile profile) {
    _emit(_snapshot.copyWith(profile: profile));
  }

  void _replace(String procedureId, Procedure Function(Procedure procedure) update) {
    _emit(
      _snapshot.copyWith(
        procedures: [
          for (final procedure in _snapshot.procedures)
            if (procedure.id == procedureId) update(procedure) else procedure,
        ],
      ),
    );
  }

  Procedure? _procedureOfFollowUp(String followUpId) {
    for (final procedure in _snapshot.procedures) {
      if (procedure.followUps.any((item) => item.id == followUpId)) return procedure;
    }
    return null;
  }
}
