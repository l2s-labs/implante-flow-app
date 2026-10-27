import 'models.dart';
import 'practice.dart';

List<Patient> matchPatients(
  List<Patient> patients,
  String query, {
  LocationFilter location = const LocationFilter.all(),
}) {
  final text = query.trim().toLowerCase();
  final list = patients.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final matched = text.isEmpty
      ? list
      : list.where((patient) {
          final digits = digitsOnly(query);
          final nameHit = patient.name.toLowerCase().contains(text);
          final cpfHit = formatCpf(patient.cpf).toLowerCase().contains(text) ||
              (digits.isNotEmpty && digitsOnly(patient.cpf).contains(digits));
          return nameHit || cpfHit;
        }).toList();
  return filterPatientsByLocation(matched, location);
}

List<Procedure> proceduresOf(List<Procedure> procedures, String patientId) {
  return procedures.where((item) => item.patientId == patientId).toList()
    ..sort((a, b) => b.surgeryDate.compareTo(a.surgeryDate));
}

List<ToothSite> implantsOf(List<Procedure> procedures, String patientId) {
  return [
    for (final procedure in proceduresOf(procedures, patientId))
      if (procedure.modality == Modality.implante)
        for (final site in procedure.pillars) site,
  ];
}

List<FollowUp> upcomingOf(List<Procedure> procedures, String patientId) {
  return [
    for (final procedure in proceduresOf(procedures, patientId))
      for (final followUp in procedure.followUps)
        if (!followUp.isProsthesisTrack && followUp.status == ReturnStatus.agendado) followUp,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

Procedure? procedureOfFollowUp(List<Procedure> procedures, String followUpId) {
  for (final procedure in procedures) {
    if (procedure.followUps.any((item) => item.id == followUpId)) return procedure;
  }
  return null;
}

List<FollowUp> scheduledFollowUps(List<Procedure> procedures) {
  return [
    for (final procedure in procedures)
      for (final followUp in procedure.followUps)
        if (!followUp.isProsthesisTrack && followUp.status == ReturnStatus.agendado) followUp,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

enum ReportFilter { emDia, atrasados, faltas, proximos, realizados }

enum ReportSpan { todos, hoje, seteDias, trintaDias, personalizado }

/// Inclusive civil-day window. A null edge means that side is open.
///
/// Cancelled and rescheduled appointments are not a [ReturnStatus]. Reports
/// count each follow-up once and do not add the visit created when it is
/// completed, so history is not mixed into the active appointment.
class ReportWindow {
  const ReportWindow({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  bool contains(DateTime date) {
    final day = dateOnly(date);
    if (start != null && day.isBefore(dateOnly(start!))) return false;
    if (end != null && day.isAfter(dateOnly(end!))) return false;
    return true;
  }

  factory ReportWindow.span(
    DateTime today,
    ReportSpan span, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final day = dateOnly(today);
    return switch (span) {
      ReportSpan.todos => const ReportWindow(),
      ReportSpan.hoje => ReportWindow(start: day, end: day),
      ReportSpan.seteDias => ReportWindow(start: day, end: day.add(const Duration(days: 7))),
      ReportSpan.trintaDias => ReportWindow(start: day, end: day.add(const Duration(days: 30))),
      ReportSpan.personalizado => ReportWindow(
          start: customStart == null ? null : dateOnly(customStart),
          end: customEnd == null ? null : dateOnly(customEnd),
        ),
    };
  }
}

String reportSpanLabel(ReportSpan span) => switch (span) {
      ReportSpan.todos => 'Todos',
      ReportSpan.hoje => 'Hoje',
      ReportSpan.seteDias => '7 dias',
      ReportSpan.trintaDias => '30 dias',
      ReportSpan.personalizado => 'Período',
    };

ReportFilter reportFilterFromName(String? name) =>
    ReportFilter.values.asNameMap()[name] ?? ReportFilter.atrasados;

bool followUpMatchesReport(
  FollowUp followUp,
  ReportFilter filter,
  DateTime today, {
  ReportWindow window = const ReportWindow(),
}) {
  if (followUp.isProsthesisTrack) return false;
  if (!window.contains(followUp.date)) return false;
  final day = dateOnly(followUp.date);
  final current = dateOnly(today);
  return switch (filter) {
    ReportFilter.emDia => false,
    ReportFilter.atrasados =>
      followUp.status == ReturnStatus.agendado && day.isBefore(current),
    ReportFilter.faltas => followUp.status == ReturnStatus.faltou,
    ReportFilter.proximos =>
      followUp.status == ReturnStatus.agendado && !day.isBefore(current),
    ReportFilter.realizados => followUp.status == ReturnStatus.realizado,
  };
}

List<Patient> patientsForReport(
  List<Procedure> procedures,
  List<Patient> patients,
  ReportFilter filter,
  DateTime today, {
  ReportWindow window = const ReportWindow(),
  Modality? modality,
  String query = '',
}) {
  final named = matchPatients(patients, query);
  if (filter == ReportFilter.emDia) {
    return named.where((patient) => _isOnTrack(procedures, patient.id, today, modality)).toList();
  }
  final ids = <String>{
    for (final procedure in procedures)
      if (_matchesModality(procedure, modality) &&
          procedure.followUps.any(
            (item) => followUpMatchesReport(item, filter, today, window: window),
          ))
        procedure.patientId,
  };
  return named.where((patient) => ids.contains(patient.id)).toList();
}

List<({Procedure procedure, FollowUp followUp})> reportFollowUps(
  List<Procedure> procedures,
  String patientId,
  ReportFilter filter,
  DateTime today, {
  ReportWindow window = const ReportWindow(),
  Modality? modality,
}) {
  if (filter == ReportFilter.emDia) {
    return [
      for (final procedure in procedures)
        if (procedure.patientId == patientId && _matchesModality(procedure, modality))
          for (final followUp in procedure.followUps)
            if (followUp.status == ReturnStatus.agendado &&
                !dateOnly(followUp.date).isBefore(dateOnly(today)) &&
                window.contains(followUp.date))
              (procedure: procedure, followUp: followUp),
    ]..sort((a, b) => a.followUp.date.compareTo(b.followUp.date));
  }
  return [
    for (final procedure in procedures)
      if (procedure.patientId == patientId && _matchesModality(procedure, modality))
        for (final followUp in procedure.followUps)
          if (followUpMatchesReport(followUp, filter, today, window: window))
            (procedure: procedure, followUp: followUp),
  ]..sort((a, b) => a.followUp.date.compareTo(b.followUp.date));
}

class ClinicReport {
  const ClinicReport({
    required this.onTrack,
    required this.absences,
    required this.overdue,
    required this.upcoming,
    required this.completed,
    required this.attended,
    required this.missed,
    required this.pending,
  });

  final int onTrack;
  final int absences;
  final int overdue;
  final int upcoming;
  final int completed;
  final int attended;
  final int missed;
  final int pending;

  int get withOutcome => attended + missed;

  int? get attendancePercent =>
      withOutcome == 0 ? null : (attended / withOutcome * 100).round();
}

ClinicReport clinicReport({
  required List<Procedure> procedures,
  required List<Patient> patients,
  required DateTime today,
  ReportWindow window = const ReportWindow(),
  Modality? modality,
  String query = '',
}) {
  int count(ReportFilter filter) => patientsForReport(
        procedures,
        patients,
        filter,
        today,
        window: window,
        modality: modality,
        query: query,
      ).length;
  final outcomes = _outcomeCounts(
    procedures,
    patients,
    window: window,
    modality: modality,
    query: query,
  );
  return ClinicReport(
    onTrack: count(ReportFilter.emDia),
    absences: count(ReportFilter.faltas),
    overdue: count(ReportFilter.atrasados),
    upcoming: count(ReportFilter.proximos),
    completed: count(ReportFilter.realizados),
    attended: outcomes.attended,
    missed: outcomes.missed,
    pending: outcomes.pending,
  );
}

bool _matchesModality(Procedure procedure, Modality? modality) =>
    modality == null || procedure.modality == modality;

bool _isOnTrack(
  List<Procedure> procedures,
  String patientId,
  DateTime today,
  Modality? modality,
) {
  final owned = [
    for (final procedure in procedures)
      if (procedure.patientId == patientId && _matchesModality(procedure, modality)) procedure,
  ];
  if (modality != null && owned.isEmpty) return false;
  final current = dateOnly(today);
  return owned.every(
    (procedure) => procedure.followUps.every(
      (followUp) =>
          followUp.status != ReturnStatus.agendado || !dateOnly(followUp.date).isBefore(current),
    ),
  );
}

({int attended, int missed, int pending}) _outcomeCounts(
  List<Procedure> procedures,
  List<Patient> patients, {
  required ReportWindow window,
  required Modality? modality,
  required String query,
}) {
  final allowed = matchPatients(patients, query).map((patient) => patient.id).toSet();
  final seen = <String>{};
  var attended = 0;
  var missed = 0;
  var pending = 0;
  for (final procedure in procedures) {
    if (!allowed.contains(procedure.patientId) || !_matchesModality(procedure, modality)) continue;
    for (final followUp in procedure.followUps) {
      if (!seen.add(followUp.id) || !window.contains(followUp.date)) continue;
      switch (followUp.status) {
        case ReturnStatus.realizado:
          attended++;
        case ReturnStatus.faltou:
          missed++;
        case ReturnStatus.agendado:
          pending++;
      }
    }
  }
  return (attended: attended, missed: missed, pending: pending);
}

List<FollowUp> followUpsInNextDays(List<Procedure> procedures, DateTime today, {int days = 7}) {
  final start = dateOnly(today);
  final end = start.add(Duration(days: days));
  return scheduledFollowUps(procedures).where((followUp) {
    final day = dateOnly(followUp.date);
    return day.isAfter(start) && !day.isAfter(end);
  }).toList();
}

List<FollowUp> schedulingReminders({
  required List<Procedure> procedures,
  required DateTime day,
  required bool remindersEnabled,
}) {
  if (!remindersEnabled) return const [];
  final seen = <String>{};
  return [
    for (final followUp in scheduledFollowUps(procedures))
      if (followUp.reminderEnabled &&
          sameDay(followUp.reminderOn, day) &&
          seen.add(followUp.id))
        followUp,
  ];
}

List<CalendarMark> marksInMonth(List<Procedure> procedures, List<Patient> patients, DateTime month) {
  Patient patientById(String id) => patients.firstWhere((patient) => patient.id == id);
  final marks = <CalendarMark>[];
  for (final procedure in procedures) {
    final patient = patientById(procedure.patientId);
    if (procedure.surgeryDate.year == month.year && procedure.surgeryDate.month == month.month) {
      marks.add(
        CalendarMark(
          date: procedure.surgeryDate,
          patientId: patient.id,
          patientName: patient.name,
          kind: CalendarKind.cirurgia,
          label: procedure.classificationLabel,
          procedureId: procedure.id,
        ),
      );
    }
    for (final visit in procedure.visits) {
      if (visit.date.year == month.year && visit.date.month == month.month) {
        marks.add(
          CalendarMark(
            date: visit.date,
            patientId: patient.id,
            patientName: patient.name,
            kind: CalendarKind.consulta,
            label: visit.note,
            procedureId: procedure.id,
          ),
        );
      }
    }
    for (final followUp in procedure.followUps) {
      if (followUp.date.year == month.year && followUp.date.month == month.month) {
        marks.add(
          CalendarMark(
            date: followUp.date,
            patientId: patient.id,
            patientName: patient.name,
            kind: CalendarKind.retorno,
            label: returnReasonLabel(followUp.reason),
            procedureId: procedure.id,
            returnStatus: followUp.status,
            overdue: followUp.status == ReturnStatus.agendado &&
                dateOnly(followUp.date).isBefore(brasiliaToday()),
          ),
        );
      }
    }
  }
  marks.sort((a, b) {
    final byDay = a.date.compareTo(b.date);
    if (byDay != 0) return byDay;
    return a.patientName.compareTo(b.patientName);
  });
  return marks;
}
