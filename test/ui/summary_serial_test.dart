import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('o resumo não pede número de série', (tester) async {
    for (final modality in Modality.values) {
      await _openSummary(tester, modality, modality == Modality.implante ? [11] : [14, 16]);
      expect(find.text('Série'), findsNothing);
    }
  });
}

Future<void> _openSummary(WidgetTester tester, Modality modality, List<int> teeth) async {
  final repository = MockClinicRepository(MockClinicService());
  final patient = repository.current.patients.first;
  final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
  viewModel.chooseModality(modality);
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
}
