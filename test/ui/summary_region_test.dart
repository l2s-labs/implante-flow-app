import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('protocolo mostra Região e conserva o FDI', (tester) async {
    final viewModel = await _openSummary(
      tester,
      Modality.implante,
      [16, 14],
      subtype: ProcedureSubtype.protocolo,
    );

    expect(find.text('Região 14'), findsOneWidget);
    expect(find.text('Região 16'), findsOneWidget);
    expect(find.text('Dente 14'), findsNothing);
    expect(find.text('Dente 16'), findsNothing);
    expect(viewModel.pillars, [16, 14]);
  });

  testWidgets('unitário, ponte e enxerto continuam com Dente', (tester) async {
    await _openSummary(tester, Modality.implante, [11]);
    expect(find.text('Dente 11'), findsOneWidget);
    expect(find.text('Região 11'), findsNothing);

    await _openSummary(tester, Modality.protese, [14, 15, 16], subtype: ProcedureSubtype.ponte);
    expect(find.text('Dente 14'), findsOneWidget);
    expect(find.text('Dente 16'), findsOneWidget);
    expect(find.text('Região 14'), findsNothing);

    await _openSummary(tester, Modality.enxerto, [21]);
    expect(find.text('Dente 21'), findsOneWidget);
    expect(find.text('Região 21'), findsNothing);
  });
}

Future<NewProcedureViewModel> _openSummary(
  WidgetTester tester,
  Modality modality,
  List<int> teeth, {
  ProcedureSubtype? subtype,
}) async {
  final repository = MockClinicRepository(MockClinicService());
  final patient = repository.current.patients.first;
  final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
  viewModel.chooseModality(modality, subtype: subtype);
  for (final tooth in teeth) {
    viewModel.toggleTooth(tooth);
  }
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
  return viewModel;
}
