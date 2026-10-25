import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/patients/patient_editor.dart';
import 'package:implate_flow/ui/patients/patients_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('lista filtra por local sem duplicar o paciente', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final viewModel = PatientsViewModel(repository);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: const MaterialApp(home: PatientsScreen()),
      ),
    );

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Pedro Alves'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultório Centro'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Pedro Alves'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem local'));
    await tester.pumpAndSettle();
    expect(find.text('Maria Souza'), findsNothing);
    expect(find.text('Pedro Alves'), findsOneWidget);
  });

  testWidgets('cadastro sugere o local padrão e não liga aviso sem contato', (tester) async {
    final locations = const [
      CareLocation(id: 'centro', name: 'Consultório Centro', isDefault: true),
    ];
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientEditorPage(title: 'Novo paciente', locations: locations),
      ),
    );
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.selected, isTrue);
    final emailSwitch = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Notificar por e-mail'));
    final phoneSwitch = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Notificar por telefone'));
    expect(emailSwitch.onChanged, isNull);
    expect(phoneSwitch.onChanged, isNull);
  });
}
