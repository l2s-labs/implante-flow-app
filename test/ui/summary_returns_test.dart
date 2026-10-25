import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/data/services/clinic_snapshot_codec.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/domain/queries.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('resumo acrescenta controle e reabertura sem substituir o retorno longo', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.first;
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    viewModel.chooseModality(Modality.implante);
    viewModel.toggleTooth(11);
    await viewModel.openSummary();
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<NewProcedureViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: NewProcedureScreen()),
      ),
    );

    expect(find.text('Retorno longo'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retorno de controle'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retorno para reabertura'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retorno de controle'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retorno de controle'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retorno para reabertura'));
    await tester.pump();

    expect(find.text('Retorno longo'), findsOneWidget);
    expect(find.text('Retorno de controle'), findsNWidgets(3));
    expect(find.text('Retorno para reabertura'), findsNWidgets(2));
    expect(viewModel.extraReturns.map((item) => item.reason), [
      ReturnReason.controle,
      ReturnReason.controle,
      ReturnReason.reabertura,
    ]);
    expect(viewModel.extraReturns[0].date, isNot(viewModel.extraReturns[1].date));
    expect(viewModel.longReason, ReturnReason.osseointegracao);

    final shared = viewModel.surgery.add(const Duration(days: 40));
    viewModel.setExtraDate(viewModel.extraReturns[1].id, shared);
    viewModel.setExtraDate(viewModel.extraReturns[0].id, shared);
    await tester.pump();
    final controls = viewModel.extraReturns.where((item) => item.reason == ReturnReason.controle).toList();
    expect(controls, hasLength(2));
    expect(dateOnly(controls[0].date), dateOnly(shared));
    expect(dateOnly(controls[1].date), dateOnly(shared));

    viewModel.setExtraDate(controls.first.id, viewModel.surgery.subtract(const Duration(days: 1)));
    viewModel.setExtraReminder(controls.first.id, false);
    await tester.pump();
    expect(
      _returnTitles(tester),
      [
        'Sutura',
        'Retorno longo',
        'Retorno de controle',
        'Retorno de controle',
        'Retorno para reabertura',
        'Retorno de controle',
        'Retorno para reabertura',
      ],
    );

    await tester.tap(find.byTooltip('Remover retorno').first);
    await tester.pump();
    final remainingControls = viewModel.extraReturns.where((item) => item.reason == ReturnReason.controle).toList();
    expect(remainingControls, hasLength(1));
    viewModel.setExtraReminder(remainingControls.single.id, false);
    await tester.pump();

    final created = viewModel.save().single;
    final reasons = created.followUps.map((item) => item.reason).toList();
    expect(reasons, containsAll([ReturnReason.sutura, ReturnReason.controle, ReturnReason.reabertura, ReturnReason.osseointegracao]));
    expect(reasons.where((reason) => reason == ReturnReason.osseointegracao), hasLength(1));
    expect(created.followUps, chronologicalFollowUps(created.followUps));
    expect(created.followUps.every((item) => item.status == ReturnStatus.agendado), isTrue);
    final kept = created.followUps.singleWhere((item) => item.reason == ReturnReason.controle);
    expect(kept.reminderEnabled, isFalse);

    final restored = decodeClinicSnapshot(encodeClinicSnapshot(repository.current));
    final stored = restored.procedures.singleWhere((item) => item.id == created.id);
    expect(stored.followUps.map((item) => item.reason.name), created.followUps.map((item) => item.reason.name));
  });

  test('controle e reabertura seguem calendário, relatório, atraso e lembrete', () {
    final today = DateTime(2026, 10, 19);
    final patient = Patient(id: 'ana', name: 'Ana Costa', phone: '', birthDate: DateTime(1984, 1, 28));
    final controle = FollowUp(
      id: 'ret-controle',
      date: today.subtract(const Duration(days: 2)),
      reason: ReturnReason.controle,
      status: ReturnStatus.agendado,
      reminderEnabled: true,
      reminderDaysBefore: 7,
    );
    final reabertura = FollowUp(
      id: 'ret-reabertura',
      date: DateTime(2026, 11, 2),
      reason: ReturnReason.reabertura,
      status: ReturnStatus.agendado,
      reminderEnabled: true,
      reminderDaysBefore: 15,
    );
    final procedure = Procedure(
      id: 'pro-1',
      patientId: patient.id,
      modality: Modality.implante,
      surgeryDate: DateTime(2026, 9, 1),
      statusLabel: 'Instalado',
      sites: const [ToothSite(fdi: 11, role: ToothRole.pilar)],
      followUps: [reabertura, controle],
    );
    final repository = MockClinicRepository.fromSnapshot(
      ClinicSnapshot(
        profile: const DentistProfile(name: 'Dra. Helena', email: 'helena@consultorio.exemplo'),
        signedIn: true,
        patients: [patient],
        procedures: [procedure],
        sequence: 3,
      ),
    );

    expect(upcomingOf(repository.current.procedures, patient.id).map((item) => item.reason), [
      ReturnReason.controle,
      ReturnReason.reabertura,
    ]);
    expect(
      marksInMonth(repository.current.procedures, repository.current.patients, DateTime(2026, 10)).single.label,
      'Retorno de controle',
    );
    expect(
      reportFollowUps(repository.current.procedures, patient.id, ReportFilter.atrasados, today).single.followUp.id,
      controle.id,
    );
    expect(
      schedulingReminders(
        procedures: repository.current.procedures,
        day: controle.reminderOn,
        remindersEnabled: true,
      ).single.reason,
      ReturnReason.controle,
    );

    repository.completeFollowUp(
      followUpId: controle.id,
      note: '',
      statusLabel: implantStatusLabel(ImplantStatus.instalado),
      returnStatus: ReturnStatus.realizado,
    );
    final completed = repository.current.procedures.single.followUps.singleWhere((item) => item.id == controle.id);
    expect(completed.reason, ReturnReason.controle);
    expect(completed.status, ReturnStatus.realizado);
    expect(repository.current.procedures.single.visits.single.note, 'Retorno de controle');
    expect(
      reportFollowUps(repository.current.procedures, patient.id, ReportFilter.atrasados, today),
      isEmpty,
    );
  });
}

List<String> _returnTitles(WidgetTester tester) {
  const titles = {
    'Sutura',
    'Retorno longo',
    'Retorno de controle',
    'Retorno para reabertura',
  };
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .where(titles.contains)
      .toList();
}
