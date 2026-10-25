import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/data/services/clinic_snapshot_codec.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a modalidade mostra três grupos e os subtipos de cada um', (tester) async {
    final viewModel = await _pump(tester);
    expect(find.text('Implante'), findsOneWidget);
    expect(find.text('Cirurgia de Enxerto'), findsOneWidget);
    expect(find.text('Prótese sobre implante'), findsOneWidget);
    expect(find.text('Ponte fixa'), findsNothing);

    await tester.tap(find.text('Implante'));
    await tester.pump();
    expect(find.text('Unitário'), findsOneWidget);
    expect(find.text('Protocolo'), findsOneWidget);
    expect(find.text('Ponte fixa'), findsNothing);

    await tester.tap(find.text('Prótese sobre implante'));
    await tester.pump();
    expect(find.text('Unitária'), findsOneWidget);
    expect(find.text('Ponte fixa'), findsOneWidget);
    expect(find.text('Protocolo'), findsOneWidget);
    expect(viewModel.modality, Modality.protese);
  });

  testWidgets('implante unitário guarda enxerto associado sem outro procedimento', (tester) async {
    final viewModel = await _pump(tester);
    await tester.tap(find.text('Implante'));
    await tester.pump();
    await tester.tap(find.text('Unitário'));
    await tester.pumpAndSettle();
    viewModel.toggleTooth(11);
    await viewModel.openSummary();
    await tester.pumpAndSettle();

    expect(find.text('Foi realizado enxerto?'), findsOneWidget);
    expect(find.text('Osso autógeno'), findsNothing);
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();
    expect(find.text('Osso autógeno'), findsOneWidget);

    viewModel.updateDraft(11, (draft) {
      draft.grafts.first
        ..origin = GraftOrigin.autogeno
        ..donorSite = 'Ramo';
    });
    final created = viewModel.save();
    expect(created, hasLength(1));
    expect(created.single.modality, Modality.implante);
    expect(created.single.subtype, ProcedureSubtype.unitario);
    expect(created.single.associatedGraft, isTrue);
    expect(created.single.sites.single.grafts.single.donorSite, 'Ramo');
    expect(created.single.followUps.map((item) => item.reason), contains(ReturnReason.sutura));
    expect(
      viewModel.repository.current.procedures.where(
        (item) => item.patientId == viewModel.patientId && item.modality == Modality.enxerto,
      ),
      isEmpty,
    );

    final restored = decodeClinicSnapshot(encodeClinicSnapshot(viewModel.repository.current));
    final stored = restored.procedures.singleWhere((item) => item.id == created.single.id);
    expect(stored.subtype, ProcedureSubtype.unitario);
    expect(stored.associatedGraft, isTrue);
    expect(stored.sites.single.grafts.single.donorSite, 'Ramo');
  });

  test('prótese vincula implante existente e não cria sutura', () async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.firstWhere((item) => item.name == 'João Lima');
    final inventory = repository.current.implantsFor(patient.id, activeOnly: true);
    final first = inventory.firstWhere((item) => item.fdi == 14);
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    viewModel.chooseModality(Modality.protese, subtype: ProcedureSubtype.ponte);
    viewModel.toggleTooth(14);
    viewModel.toggleTooth(15);
    viewModel.toggleTooth(16);
    await viewModel.openSummary();
    expect(viewModel.saveError, isNull);
    expect(viewModel.linkedImplantsForTooth(14), isEmpty);

    viewModel.toggleLinkedImplant(first.id);
    expect(viewModel.saveError, isNull);
    expect(viewModel.linkedImplantsForTooth(14), isNotEmpty);
    final created = viewModel.save().single;
    expect(created.modality, Modality.protese);
    expect(created.subtype, ProcedureSubtype.ponte);
    expect(created.linkedImplantIds, [first.id]);
    expect(created.sites.every((site) => site.piece == null), isTrue);
    expect(created.followUps.map((item) => item.reason), isNot(contains(ReturnReason.sutura)));
    expect(created.followUps.map((item) => item.reason), isNot(contains(ReturnReason.osseointegracao)));
  });
}

Future<NewProcedureViewModel> _pump(WidgetTester tester) async {
  final repository = MockClinicRepository(MockClinicService());
  final patient = repository.current.patients.first;
  final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
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
