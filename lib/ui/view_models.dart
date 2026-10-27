import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import '../data/repositories/clinic_repository.dart';
import '../data/services/api_feedback.dart';
import '../data/services/clinic_pdfs.dart';
import '../data/services/workos_auth.dart';
import '../domain/certificate.dart';
import '../domain/clinic_snapshot.dart';
import '../data/services/cep_lookup.dart';
import '../domain/models.dart';
import '../domain/practice.dart';
import '../domain/queries.dart';

class RepositoryViewModel extends ChangeNotifier {
  RepositoryViewModel(this.repository) {
    _subscription = repository.watch().listen((next) {
      snapshot = next;
      loadError = null;
      notifyListeners();
    }, onError: (Object _) {
      loadError = 'Não foi possível atualizar os relatórios.';
      notifyListeners();
    });
    _syncErrors = repository.syncErrors.listen((message) {
      loadError = message;
      notifyListeners();
    });
    _feedback = repository.feedback.listen((notice) {
      feedback = notice;
      notifyListeners();
    });
  }

  final ClinicRepository repository;
  late ClinicSnapshot snapshot = repository.current;
  String? loadError;
  ApiFeedback? feedback;
  late final StreamSubscription<ClinicSnapshot> _subscription;
  late final StreamSubscription<String> _syncErrors;
  late final StreamSubscription<ApiFeedback> _feedback;

  void clearFeedback() {
    if (feedback == null) return;
    feedback = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _syncErrors.cancel();
    _feedback.cancel();
    super.dispose();
  }
}

class SessionViewModel extends RepositoryViewModel {
  SessionViewModel(
    super.repository,
    this.auth, {
    this.workOsClientId = AppConfig.workOsClientId,
    this.workOsRedirectUri = AppConfig.workOsRedirectUri,
  }) {
    repository.bindUnauthorized(() async {
      final identity = await auth.currentIdentity(clientId: workOsClientId);
      return identity?.accessToken;
    });
    restored = syncWorkOsName();
  }

  final WorkOsAuth auth;
  final String workOsClientId;
  final String workOsRedirectUri;
  late final Future<void> restored;
  bool busy = false;
  String? error;

  /// Evita reabrir o AuthKit em loop após cancelamento/erro (F3S-517).
  bool _authKitPresented = false;

  bool get signedIn => snapshot.signedIn;

  /// Abre o AuthKit uma vez após restaurar a sessão, se ainda não houver login.
  Future<void> presentAuthKitIfNeeded() async {
    await restored;
    if (signedIn || busy || _authKitPresented) return;
    _authKitPresented = true;
    await signIn();
  }

  /// Nova tentativa explícita após cancelamento ou falha.
  Future<void> retryAuthKit() => signIn();

  Future<void> signIn() async {
    if (busy) return;
    if (workOsClientId.isEmpty) {
      error = 'Preencha WORKOS_CLIENT_ID em config/local.json.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final identity = await auth.signIn(
        clientId: workOsClientId,
        redirectUri: workOsRedirectUri,
      );
      repository.signIn(
        name: identity.name,
        email: identity.email,
        accessToken: identity.accessToken,
      );
      await repository.refresh();
    } on WorkOsAuthException catch (error) {
      this.error = error.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> syncWorkOsName() async {
    if (!snapshot.signedIn || workOsClientId.isEmpty) return;
    try {
      final identity = await auth.currentIdentity(clientId: workOsClientId);
      if (identity == null) {
        // Refresh token ausente/inválido: sem access token a API nunca é chamada.
        // Força login de novo (AuthKit na tela /login) em vez de sessão fantasma.
        repository.signOut();
        return;
      }
      repository.signIn(
        name: identity.name,
        email: identity.email,
        accessToken: identity.accessToken,
      );
      await repository.refresh();
    } on WorkOsAuthException {
      // Rede/indisponibilidade: mantém o prontuário local até o próximo refresh.
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await auth.signOut(redirectUri: workOsRedirectUri);
    } on WorkOsAuthException {
      // The local session still ends so the dentist returns to login.
    } finally {
      repository.signOut();
      busy = false;
      notifyListeners();
    }
  }
}

class HomeViewModel extends RepositoryViewModel {
  HomeViewModel(super.repository) {
    repository.applyOverdueNotices();
  }

  DentistProfile get profile => snapshot.profile;

  DateTime get agendaToday => brasiliaToday();

  List<FollowUp> _scheduledOn(bool Function(DateTime day) test) {
    return scheduledFollowUps(snapshot.procedures).where((item) => test(dateOnly(item.date))).toList();
  }

  List<FollowUp> get today => _scheduledOn((day) => sameDay(day, agendaToday));

  List<FollowUp> get nextWeek => followUpsInNextDays(snapshot.procedures, agendaToday);

  int get nextWeekCount => nextWeek.length;

  int get overduePatientCount => patientsForReport(
        snapshot.procedures,
        snapshot.patients,
        ReportFilter.atrasados,
        agendaToday,
      ).length;

  List<FollowUp> get todayReminders => schedulingReminders(
        procedures: snapshot.procedures,
        day: agendaToday,
        remindersEnabled: profile.reminderEnabled,
      );

  int get todayReminderCount => todayReminders.length;

  Procedure? procedureOf(String followUpId) =>
      procedureOfFollowUp(snapshot.procedures, followUpId);

  Patient patientOf(String patientId) =>
      snapshot.patients.firstWhere((patient) => patient.id == patientId);

  List<Patient> patientsMatching(String query, {LocationFilter location = const LocationFilter.all()}) =>
      matchPatients(snapshot.patients, query, location: location);
}

class PatientsViewModel extends RepositoryViewModel {
  PatientsViewModel(super.repository);

  String query = '';
  LocationFilter locationFilter = const LocationFilter.all();

  List<Patient> get patients =>
      matchPatients(snapshot.patients, query, location: locationFilter);

  int implantCount(String patientId) => implantsOf(snapshot.procedures, patientId).length;

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setLocationFilter(LocationFilter value) {
    locationFilter = value;
    notifyListeners();
  }

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
    return repository.createPatient(
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
  }
}

class PatientViewModel extends RepositoryViewModel {
  PatientViewModel(super.repository, {required this.patientId});

  final String patientId;

  Patient? get patient =>
      snapshot.patients.where((item) => item.id == patientId).firstOrNull;

  List<Procedure> get history => proceduresOf(snapshot.procedures, patientId);

  List<InstalledImplant> get implants => snapshot.implantsFor(patientId);

  List<FollowUp> get upcoming => upcomingOf(snapshot.procedures, patientId);

  InstalledImplant addPreexistingImplant(PreexistingImplantDraft draft) {
    return repository.createInstalledImplant(
      InstalledImplant(
        id: repository.allocateId('imp'),
        patientId: patientId,
        fdi: draft.fdi,
        origin: ImplantOrigin.preexisting,
        manufacturer: draft.manufacturer,
        model: draft.model,
        size: draft.size,
        lot: draft.lot,
        installedOn: draft.installedOn,
        originClinic: draft.originClinic,
        notes: draft.notes,
      ),
    );
  }

  void updateInstalledImplant(InstalledImplant current, PreexistingImplantDraft draft) {
    repository.updateInstalledImplant(
      current.copyWith(
        fdi: draft.fdi,
        manufacturer: draft.manufacturer,
        model: draft.model,
        size: draft.size,
        lot: draft.lot,
        installedOn: draft.installedOn,
        clearInstalledOn: draft.installedOn == null,
        originClinic: draft.originClinic,
        notes: draft.notes,
        active: draft.active,
      ),
    );
  }

  Procedure? procedureOf(String followUpId) =>
      procedureOfFollowUp(snapshot.procedures, followUpId);

  List<({DateTime date, String title, String detail, String? procedureId})> get timeline {
    return [
      for (final procedure in history) ...[
        (
          date: procedure.surgeryDate,
          title: 'Cirurgia',
          detail: [
            procedure.classificationLabel,
            procedure.teethLabel,
            if (procedure.sinusLiftLabel != null) procedure.sinusLiftLabel!,
          ].join(' · '),
          procedureId: procedure.id,
        ),
        for (final visit in procedure.visits)
          (
            date: visit.date,
            title: 'Consulta',
            detail: visit.note,
            procedureId: procedure.id,
          ),
      ],
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  void updatePatient(Patient patient) => repository.updatePatient(patient);

  Future<void> exportChart() async {
    final current = patient;
    if (current == null) return;
    final bytes = await buildPatientChartPdf(
      profile: snapshot.profile,
      patient: current,
      history: history,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'prontuario-${current.id}.pdf');
  }
}

class ReportsViewModel extends RepositoryViewModel {
  ReportsViewModel(super.repository, {this.filter = ReportFilter.atrasados});

  static const pageSize = 20;

  ReportFilter filter;
  ReportSpan span = ReportSpan.todos;
  DateTime? customStart;
  DateTime? customEnd;
  Modality? modality;
  String query = '';
  bool byAppointment = false;
  int visibleLimit = pageSize;

  DateTime get today => brasiliaToday();

  ReportWindow get window => ReportWindow.span(
        today,
        span,
        customStart: customStart,
        customEnd: customEnd,
      );

  ClinicReport get totals => clinicReport(
        procedures: snapshot.procedures,
        patients: snapshot.patients,
        today: today,
        window: window,
        modality: modality,
        query: query,
      );

  String get attendanceLabel {
    final percent = totals.attendancePercent;
    final rate = percent == null ? 'Comparecimento indisponível' : 'Comparecimento $percent%';
    return '$rate · ${totals.withOutcome} com desfecho · ${totals.pending} sem desfecho';
  }

  List<Patient> get patients => patientsForReport(
        snapshot.procedures,
        snapshot.patients,
        filter,
        today,
        window: window,
        modality: modality,
        query: query,
      );

  List<({Procedure procedure, FollowUp followUp})> rowsFor(String patientId) => reportFollowUps(
        snapshot.procedures,
        patientId,
        filter,
        today,
        window: window,
        modality: modality,
      );

  List<({Patient patient, Procedure procedure, FollowUp followUp})> get appointments {
    final rows = [
      for (final patient in patients)
        for (final row in rowsFor(patient.id))
          (patient: patient, procedure: row.procedure, followUp: row.followUp),
    ]..sort((a, b) {
        final byDate = a.followUp.date.compareTo(b.followUp.date);
        if (byDate != 0) return byDate;
        return a.patient.name.toLowerCase().compareTo(b.patient.name.toLowerCase());
      });
    return rows;
  }

  List<Patient> get visiblePatients => patients.take(visibleLimit).toList();

  List<({Patient patient, Procedure procedure, FollowUp followUp})> get visibleAppointments =>
      appointments.take(visibleLimit).toList();

  bool get hasMore =>
      (byAppointment ? appointments.length : patients.length) > visibleLimit;

  int get activeFilterCount {
    var count = span == ReportSpan.todos ? 0 : 1;
    if (modality != null) count++;
    return count;
  }

  void showMore() {
    visibleLimit += pageSize;
    notifyListeners();
  }

  void clearFilters() {
    span = ReportSpan.todos;
    customStart = null;
    customEnd = null;
    modality = null;
    _publish();
  }

  void _publish() {
    visibleLimit = pageSize;
    notifyListeners();
  }

  void setFilter(ReportFilter value) {
    filter = value;
    _publish();
  }

  void setSpan(ReportSpan value) {
    span = value;
    if (value == ReportSpan.personalizado) {
      customStart ??= today;
      customEnd ??= today;
      if (dateOnly(customEnd!).isBefore(dateOnly(customStart!))) {
        final start = customStart;
        customStart = customEnd;
        customEnd = start;
      }
    }
    _publish();
  }

  void setCustomStart(DateTime value) {
    customStart = dateOnly(value);
    span = ReportSpan.personalizado;
    setSpan(ReportSpan.personalizado);
  }

  void setCustomEnd(DateTime value) {
    customEnd = dateOnly(value);
    setSpan(ReportSpan.personalizado);
  }

  void setModality(Modality? value) {
    modality = value;
    _publish();
  }

  void setQuery(String value) {
    query = value;
    _publish();
  }

  void setByAppointment(bool value) {
    byAppointment = value;
    _publish();
  }
}

class NextWeekViewModel extends RepositoryViewModel {
  NextWeekViewModel(super.repository);

  List<FollowUp> get followUps => followUpsInNextDays(snapshot.procedures, brasiliaToday());

  Procedure? procedureOf(String followUpId) =>
      procedureOfFollowUp(snapshot.procedures, followUpId);

  Patient patientOf(String patientId) =>
      snapshot.patients.firstWhere((patient) => patient.id == patientId);
}

class TodayRemindersViewModel extends RepositoryViewModel {
  TodayRemindersViewModel(super.repository);

  List<FollowUp> get reminders => schedulingReminders(
        procedures: snapshot.procedures,
        day: brasiliaToday(),
        remindersEnabled: snapshot.profile.reminderEnabled,
      );

  Procedure? procedureOf(String followUpId) =>
      procedureOfFollowUp(snapshot.procedures, followUpId);

  Patient patientOf(String patientId) =>
      snapshot.patients.firstWhere((patient) => patient.id == patientId);
}

class CalendarViewModel extends RepositoryViewModel {
  CalendarViewModel(super.repository) {
    final today = brasiliaToday();
    month = DateTime(today.year, today.month);
    selected = today;
  }

  late DateTime month;
  DateTime? selected;
  ReturnStatus? returnFilter;

  List<CalendarMark> get marks {
    final all = marksInMonth(snapshot.procedures, snapshot.patients, month);
    if (returnFilter == null) return all;
    return all.where((mark) {
      if (mark.kind != CalendarKind.retorno) return true;
      return mark.returnStatus == returnFilter;
    }).toList();
  }

  void previousMonth() {
    month = DateTime(month.year, month.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    month = DateTime(month.year, month.month + 1);
    notifyListeners();
  }

  void selectDay(DateTime day) {
    selected = day;
    notifyListeners();
  }

  void setReturnFilter(ReturnStatus? status) {
    returnFilter = status;
    notifyListeners();
  }
}

class ProcedureViewModel extends RepositoryViewModel {
  ProcedureViewModel(super.repository, {required this.procedureId});

  final String procedureId;

  Procedure? get procedure =>
      snapshot.procedures.where((item) => item.id == procedureId).firstOrNull;

  Patient? get patient {
    final current = procedure;
    if (current == null) return null;
    return snapshot.patients.where((item) => item.id == current.patientId).firstOrNull;
  }

  void addPhoto(ClinicPhoto photo) => repository.addPhoto(procedureId, photo);

  void addVisit({required String note, required String statusLabel}) {
    repository.addVisit(procedureId: procedureId, note: note, statusLabel: statusLabel);
  }

  void completeFollowUp({
    required String followUpId,
    required String note,
    required String statusLabel,
    required ReturnStatus returnStatus,
  }) {
    repository.completeFollowUp(
      followUpId: followUpId,
      note: note,
      statusLabel: statusLabel,
      returnStatus: returnStatus,
    );
  }

  void updateProsthesisFollowUp({
    required String followUpId,
    required ProsthesisFollowUpStatus status,
    DateTime? statusDate,
  }) {
    repository.updateProsthesisFollowUp(
      followUpId: followUpId,
      status: status,
      statusDate: statusDate,
    );
  }

  void addProsthesisFollowUp({required FollowUpPhase phase}) {
    repository.addProsthesisFollowUp(procedureId: procedureId, phase: phase);
  }


  void saveNotes(String notes) {
    final current = procedure;
    if (current == null) return;
    repository.updateProcedure(current.copyWith(notes: notes));
  }

  Future<void> deleteProcedure() {
    return repository.deleteProcedure(procedureId);
  }

  void reprocessNotice(String noticeId) =>
      repository.reprocessStageNotice(procedureId: procedureId, noticeId: noticeId);

  void saveTraceability({
    required List<ToothSite> sites,
    required bool sinusLift,
    SinusLiftTechnique? sinusLiftTechnique,
    String sinusLiftNote = '',
  }) {
    final current = procedure;
    if (current == null) return;
    repository.updateProcedure(
      current.copyWith(
        sites: sites,
        sinusLift: sinusLift,
        sinusLiftTechnique: sinusLiftTechnique,
        sinusLiftNote: sinusLiftNote,
      ),
    );
  }
}

class CertificateViewModel extends RepositoryViewModel {
  CertificateViewModel(super.repository, {required this.procedureId});

  final String procedureId;
  bool emitTwoCopies = false;
  String? selectedLocationId;

  Procedure? get procedure =>
      snapshot.procedures.where((item) => item.id == procedureId).firstOrNull;

  Patient? get patient {
    final current = procedure;
    if (current == null) return null;
    return snapshot.patients.where((item) => item.id == current.patientId).firstOrNull;
  }

  DentistProfile get profile => snapshot.profile;

  List<CareLocation> get careLocations {
    final currentPatient = patient;
    if (currentPatient == null) return const [];
    return certificateCareLocations(profile: profile, patient: currentPatient);
  }

  CareLocation? get selectedLocation => resolveCertificateLocation(
        candidates: careLocations,
        selectedLocationId: selectedLocationId,
      );

  void setEmitTwoCopies(bool value) {
    emitTwoCopies = value;
    notifyListeners();
  }

  void selectLocation(String? locationId) {
    selectedLocationId = locationId;
    notifyListeners();
  }

  Future<void> issue() async {
    final currentProcedure = procedure;
    final location = selectedLocation;
    if (currentProcedure == null || location == null) return;
    final copies = emitTwoCopies ? 2 : 1;
    final bytes = await repository.issueCertificate(
      procedureId,
      copies: copies,
      locationId: location.id,
    );
    if (bytes.isEmpty) return;
    await Printing.sharePdf(bytes: bytes, filename: 'certificado-${currentProcedure.id}.pdf');
  }
}

class ProfileViewModel extends RepositoryViewModel {
  ProfileViewModel(super.repository);

  DentistProfile get profile => snapshot.profile;

  Future<CepAddress> lookupCep(String cep) => repository.lookupCep(cep);


  void setName(String value) {
    final cleaned = sanitizePersonName(value);
    if (cleaned.isEmpty || cleaned == sanitizePersonName(profile.name)) return;
    repository.updateProfile(profile.copyWith(name: cleaned));
  }

  void setPhone(String value) {
    if (brazilianPhoneIssue(value) != null) return;
    final digits = digitsOnly(value);
    if (digits == digitsOnly(profile.phone)) return;
    repository.updateProfile(profile.copyWith(phone: digits));
  }

  void setCro(String value) => repository.updateProfile(profile.copyWith(cro: value));

  void addLocation({required String name, String address = ''}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    repository.updateProfile(
      profile.copyWith(
        locations: addCareLocation(
          profile.locations,
          CareLocation(id: repository.allocateId('loc'), name: trimmed, address: address.trim()),
        ),
      ),
    );
  }

  void editLocation({required String id, required String name, String address = ''}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = profile.locations.where((location) => location.id == id);
    if (current.isEmpty) return;
    repository.updateProfile(
      profile.copyWith(
        locations: updateCareLocation(
          profile.locations,
          current.first.copyWith(name: trimmed, address: address.trim()),
        ),
      ),
    );
  }

  void makeDefaultLocation(String id) {
    repository.updateProfile(
      profile.copyWith(locations: setDefaultCareLocation(profile.locations, id)),
    );
  }

  void inactivateLocation(String id, {String? replacementId}) {
    repository.updateProfile(
      profile.copyWith(
        locations: inactivateCareLocation(profile.locations, id, replacementId: replacementId),
      ),
    );
  }

  void reactivateLocation(String id) {
    repository.updateProfile(
      profile.copyWith(locations: reactivateCareLocation(profile.locations, id)),
    );
  }

  void setReminderEnabled(bool value) =>
      repository.updateProfile(profile.copyWith(reminderEnabled: value));

  void setReminderDaysBefore(int value) => repository.updateProfile(
        profile.copyWith(reminderDaysBefore: normalizeReminderDaysBefore(value)),
      );

  void setEmailChannel(bool value) => repository.updateProfile(profile.copyWith(emailChannel: value));

  void setPushChannel(bool value) => repository.updateProfile(profile.copyWith(pushChannel: value));
}
