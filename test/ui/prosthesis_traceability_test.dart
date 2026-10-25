import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  for (final subtype in [
    ProcedureSubtype.unitario,
    ProcedureSubtype.ponte,
    ProcedureSubtype.protocolo,
  ]) {
    testWidgets('prótese ${subtype.name} mostra estado vazio sem vínculo', (tester) async {
      final repository = MockClinicRepository(MockClinicService());
      final patient = repository.current.patients.firstWhere((item) => item.name == 'Maria Souza');
      final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
      viewModel.chooseModality(Modality.protese, subtype: subtype);
      if (subtype == ProcedureSubtype.protocolo) {
        viewModel.toggleTooth(11);
        viewModel.toggleTooth(21);
      } else if (subtype == ProcedureSubtype.ponte) {
        viewModel.toggleTooth(14);
        viewModel.toggleTooth(15);
        viewModel.toggleTooth(16);
      } else {
        viewModel.toggleTooth(14);
      }
      await viewModel.openSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: const NewProcedureScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rastreabilidade'), findsOneWidget);
      expect(find.text('Adicionar implante preexistente'), findsOneWidget);
      expect(find.textContaining('Nenhum implante'), findsWidgets);
      expect(viewModel.saveError, isNull);
    });
  }

  testWidgets('prótese com vínculo lista o implante na região', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.firstWhere((item) => item.name == 'João Lima');
    final implant = repository.current.implantsFor(patient.id, activeOnly: true).first;
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    viewModel.chooseModality(Modality.protese, subtype: ProcedureSubtype.unitario);
    viewModel.toggleTooth(implant.fdi);
    viewModel.toggleLinkedImplant(implant.id);
    await viewModel.openSummary();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: viewModel,
          child: const NewProcedureScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem implante vinculado'), findsNothing);
    expect(find.text(implant.title), findsWidgets);
    expect(find.text('Adicionar implante preexistente'), findsOneWidget);
  });
}
