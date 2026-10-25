import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('resumo do enxerto troca origem, apresentação e levantamento de seio', (tester) async {
    final viewModel = await _openGraftSummary(tester);

    expect(find.text('Houve levantamento de seio?'), findsOneWidget);
    expect(find.text('Osso autógeno'), findsOneWidget);
    expect(find.text('Osso liofilizado'), findsOneWidget);
    expect(find.text('Região doadora'), findsNothing);
    expect(find.text('Fabricante'), findsNothing);

    await tester.tap(find.text('Osso liofilizado'));
    await tester.pumpAndSettle();
    expect(find.text('Fabricante'), findsWidgets);
    expect(find.text('Em bloco'), findsOneWidget);
    expect(find.text('Em pó'), findsOneWidget);

    await tester.tap(find.text('Osso autógeno'));
    await tester.pumpAndSettle();
    expect(find.text('Região doadora'), findsOneWidget);
    expect(find.text('Fabricante'), findsNothing);

    await tester.tap(find.text('Houve levantamento de seio?'));
    await tester.pumpAndSettle();
    expect(viewModel.saveError, 'Informe o tipo de levantamento de seio.');
    expect(find.text('Tipo de levantamento de seio'), findsWidgets);
  });
}

Future<NewProcedureViewModel> _openGraftSummary(WidgetTester tester) async {
  final repository = MockClinicRepository(MockClinicService());
  final patient = repository.current.patients.first;
  final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
  viewModel.chooseModality(Modality.enxerto);
  viewModel.toggleTooth(21);
  await viewModel.openSummary();
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<NewProcedureViewModel>.value(
      value: viewModel,
      child: const MaterialApp(home: NewProcedureScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}
