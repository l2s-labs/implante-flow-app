import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';

void main() {
  test('prótese salva nos três subtipos sem vínculo e com preexistente', () async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.firstWhere((item) => item.name == 'Maria Souza');

    for (final subtype in [
      ProcedureSubtype.unitario,
      ProcedureSubtype.ponte,
      ProcedureSubtype.protocolo,
    ]) {
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
      expect(viewModel.saveError, isNull);
      final created = viewModel.save().single;
      expect(created.linkedImplantIds, isEmpty);
      expect(created.modality, Modality.protese);
    }

    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    viewModel.chooseModality(Modality.protese, subtype: ProcedureSubtype.unitario);
    viewModel.toggleTooth(24);
    final implant = viewModel.addPreexistingImplant(fdi: 24, manufacturer: 'Neodent');
    expect(implant.origin, ImplantOrigin.preexisting);
    expect(viewModel.linkedImplantIds, contains(implant.id));
    final created = viewModel.save().single;
    expect(created.linkedImplantIds, [implant.id]);
    expect(
      repository.current.implants.where((item) => item.id == implant.id),
      isNotEmpty,
    );
    expect(
      repository.current.procedures.where((item) => item.id == implant.sourceProcedureId),
      isEmpty,
    );
  });
}
