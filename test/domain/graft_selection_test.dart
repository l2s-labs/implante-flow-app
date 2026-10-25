import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/data/services/clinic_snapshot_codec.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';

void main() {
  test('osso autógeno descarta campos industriais e liofilizado descarta a região doadora', () {
    final draft = GraftDraft()
      ..selectMaterial(GraftMaterialChoice.liofilizado)
      ..selectManufacturer('Geistlich')
      ..selectModel('Bio-Oss')
      ..selectPresentation(GraftPresentation.po)
      ..selectGranulometry('0,25–1 mm');

    expect(draft.productType, 'Osso bovino desproteinizado');
    expect(draft.toMaterial(), predicate<GraftMaterial>(graftCombinationValid));

    draft.selectPresentation(GraftPresentation.bloco);
    expect(draft.presentation, GraftPresentation.po);
    expect(draft.granulometry, '0,25–1 mm');

    draft.selectMaterial(GraftMaterialChoice.autogeno);
    draft.donorSite = 'Ramo mandibular';
    final autogenous = draft.toMaterial();
    expect(autogenous.origin, GraftOrigin.autogeno);
    expect(autogenous.processing, isNull);
    expect(autogenous.manufacturer, isEmpty);
    expect(autogenous.granulometry, isEmpty);
    expect(graftCombinationValid(autogenous), isTrue);

    draft.selectMaterial(GraftMaterialChoice.liofilizado);
    expect(draft.donorSite, isEmpty);
    expect(draft.origin, GraftOrigin.biomaterial);
    expect(draft.processing, GraftProcessing.liofilizado);
  });

  test('tipo de levantamento só é exigido quando o seio foi levantado', () {
    expect(
      sinusLiftIssue(applies: true, sinusLift: false),
      isNull,
    );
    expect(
      sinusLiftIssue(applies: true, sinusLift: true),
      'Informe o tipo de levantamento de seio.',
    );
    expect(
      sinusLiftIssue(
        applies: true,
        sinusLift: true,
        technique: SinusLiftTechnique.outro,
      ),
      'Descreva o tipo de levantamento de seio.',
    );
    expect(
      sinusLiftIssue(
        applies: false,
        sinusLift: true,
      ),
      isNull,
    );
  });

  test('enxerto em vários dentes permanece um procedimento e o JSON antigo continua válido', () async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.first;
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    viewModel.chooseModality(Modality.enxerto);
    viewModel.toggleTooth(16);
    viewModel.toggleTooth(17);
    await viewModel.openSummary();
    viewModel.updateDraft(16, (draft) {
      draft.grafts.first
        ..selectMaterial(GraftMaterialChoice.autogeno)
        ..donorSite = 'Túber';
    });
    viewModel.setSinusLift(true);
    expect(viewModel.saveError, isNotNull);
    viewModel.setSinusLiftTechnique(SinusLiftTechnique.transalveolar);
    expect(viewModel.saveError, isNull);

    final created = viewModel.save().single;
    expect(created.sites.map((site) => site.fdi), [17, 16]);
    expect(created.sinusLiftLabel, 'Levantamento de seio · Transalveolar');
    expect(created.sites.singleWhere((site) => site.fdi == 16).grafts.single.donorSite, 'Túber');
    expect(created.visits, isEmpty);

    final restored = decodeClinicSnapshot(encodeClinicSnapshot(repository.current));
    final stored = restored.procedures.singleWhere((item) => item.id == created.id);
    expect(stored.sites.map((site) => site.fdi), [17, 16]);
    expect(stored.sinusLiftTechnique, SinusLiftTechnique.transalveolar);
    expect(stored.sites.first.grafts.single.processing, isNull);

    final legacy = stored.copyWith(sites: stored.sites);
    expect(legacy.visits, isEmpty);
    final withHistory = stored.copyWith(
      visits: [
        Visit(id: 'vis-1', date: DateTime(2026, 1, 2), note: 'Controle', statusLabel: 'Realizado'),
      ],
    );
    final edited = withHistory.copyWith(sinusLift: false, sites: withHistory.sites);
    expect(edited.sinusLift, isFalse);
    expect(edited.visits.single.note, 'Controle');
  });

  test('biomaterial antigo sem processamento continua no snapshot', () {
    final original = MockClinicService().load();
    final restored = decodeClinicSnapshot(encodeClinicSnapshot(original));
    final graft = restored.procedures
        .expand((procedure) => procedure.sites)
        .expand((site) => site.grafts)
        .firstWhere((item) => item.manufacturer == 'Geistlich');
    expect(graft.processing, isNull);
    expect(graft.model, 'Bio-Oss');
    expect(graft.size, '0.5 g');
    expect(graftTraceLabel(graft), 'Enxerto Geistlich Bio-Oss · 0.5 g');
    expect(graftCombinationValid(graft), isTrue);
  });
}
