import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/data/services/clinic_snapshot_codec.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:implate_flow/ui/profile/profile_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  test('lembrete sai 15 dias antes do retorno', () {
    final followUp = FollowUp(
      id: 'ret',
      date: DateTime(2026, 10, 25),
      reason: ReturnReason.sutura,
      status: ReturnStatus.agendado,
      reminderEnabled: true,
    );

    expect(followUp.reminderDaysBefore, 15);
    expect(followUp.reminderOn, DateTime(2026, 10, 10));
  });

  test('snapshot antigo sem antecedência usa 15 dias', () {
    final restored = decodeClinicSnapshot('''
{
  "profile": {
    "name": "Dra. Helena",
    "email": "helena@consultorio.exemplo",
    "reminderEnabled": true,
    "reminderHour": 8
  },
  "procedures": [
    {
      "id": "pro-1",
      "patientId": "pac-1",
      "modality": "implante",
      "subtype": "unitario",
      "surgeryDate": "2026-10-01T00:00:00.000",
      "statusLabel": "Instalado",
      "sites": [],
      "followUps": [
        {
          "id": "ret-1",
          "date": "2026-10-25T00:00:00.000",
          "reason": "sutura",
          "status": "agendado",
          "reminderEnabled": true,
          "reminderHour": 8
        }
      ]
    }
  ]
}
''');

    expect(restored.profile.reminderDaysBefore, 15);
    expect(restored.procedures.single.followUps.single.reminderOn, DateTime(2026, 10, 10));
  });

  testWidgets('resumo pede a data de retorno e a antecedência, padrão 15 dias', (tester) async {
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

    expect(find.text('Data de retorno'), findsNWidgets(2));
    expect(find.text('Lembrete'), findsOneWidget);
    expect(find.text('15 dias'), findsOneWidget);
    final chipTop = tester.getRect(find.widgetWithText(ChoiceChip, '15 dias')).top;
    expect(tester.getRect(find.widgetWithText(ChoiceChip, '7 dias')).top, chipTop);
    expect(tester.getRect(find.widgetWithText(ChoiceChip, '30 dias')).top, chipTop);
    expect(find.text('Avisar no dia'), findsNothing);
    expect(find.text('8h'), findsNothing);

    final sevenDays = find.text('7 dias');
    await tester.ensureVisible(sevenDays);
    await tester.tap(sevenDays);
    await tester.pump();
    final aviso = dateOnly(viewModel.longReturn).subtract(const Duration(days: 7));
    expect(find.text('Avisa em ${formatDay(aviso)}', skipOffstage: false), findsOneWidget);
    expect(viewModel.longLead, 7);
  });

  testWidgets('perfil lembra antes do retorno, com 15 dias selecionados', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfileViewModel(repository)),
          ChangeNotifierProvider(create: (_) => SessionViewModel(repository, NativeWorkOsAuth())),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Lembrar antes do retorno'), findsOneWidget);
    expect(find.text('Avisar no dia'), findsNothing);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '15 dias'));
    expect(chip.selected, isTrue);
  });
}
