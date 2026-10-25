import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/procedure/procedure_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  test('remoção de sutura não altera o status clínico', () {
    final repository = _repository();
    const clinicalStatus = 'Em osseointegração';

    repository.completeFollowUp(
      followUpId: 'ret-sutura',
      note: 'Sem intercorrência',
      statusLabel: implantStatusLabel(ImplantStatus.concluido),
      returnStatus: ReturnStatus.realizado,
    );

    final procedure = repository.current.procedures.single;
    final suture = procedure.followUps.singleWhere((item) => item.id == 'ret-sutura');
    expect(procedure.statusLabel, clinicalStatus);
    expect(suture.status, ReturnStatus.realizado);
    expect(procedure.visits.single.note, 'Sem intercorrência');
    expect(procedure.visits.single.statusLabel, clinicalStatus);

    repository.completeFollowUp(
      followUpId: 'ret-controle',
      note: '',
      statusLabel: implantStatusLabel(ImplantStatus.protese),
      returnStatus: ReturnStatus.realizado,
    );

    final updated = repository.current.procedures.single;
    expect(updated.statusLabel, implantStatusLabel(ImplantStatus.protese));
    expect(
      updated.followUps.singleWhere((item) => item.id == 'ret-controle').status,
      ReturnStatus.realizado,
    );
    expect(updated.visits.last.note, 'Retorno de controle');
  });

  testWidgets('o registro de remoção de sutura não pede status', (tester) async {
    final repository = _repository();
    final viewModel = ProcedureViewModel(repository, procedureId: 'pro-1');
    addTearDown(viewModel.dispose);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProcedureViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: ProcedureScreen()),
      ),
    );

    await tester.tap(find.text('Registrar Remoção de sutura'));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Sutura removida');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.current.procedures.single.statusLabel, 'Em osseointegração');
    expect(
      repository.current.procedures.single.followUps.singleWhere((item) => item.id == 'ret-sutura').status,
      ReturnStatus.realizado,
    );
    expect(find.textContaining('Sutura removida'), findsOneWidget);

    await tester.tap(find.text('Registrar Retorno de controle'));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
  });
}

MockClinicRepository _repository() {
  const clinicalStatus = 'Em osseointegração';
  final patient = Patient(id: 'ana', name: 'Ana Costa', phone: '', birthDate: DateTime(1984, 1, 28));
  return MockClinicRepository.fromSnapshot(
    ClinicSnapshot(
      profile: const DentistProfile(name: 'Dra. Helena', email: 'helena@consultorio.exemplo'),
      signedIn: true,
      patients: [patient],
      procedures: [
        Procedure(
          id: 'pro-1',
          patientId: patient.id,
          modality: Modality.implante,
          surgeryDate: DateTime(2026, 9, 1),
          statusLabel: clinicalStatus,
          sites: const [ToothSite(fdi: 11, role: ToothRole.pilar)],
          followUps: [
            FollowUp(
              id: 'ret-sutura',
              date: DateTime(2026, 9, 8),
              reason: ReturnReason.sutura,
              status: ReturnStatus.agendado,
              reminderEnabled: false,
            ),
            FollowUp(
              id: 'ret-controle',
              date: DateTime(2026, 10, 1),
              reason: ReturnReason.controle,
              status: ReturnStatus.agendado,
              reminderEnabled: false,
            ),
          ],
        ),
      ],
      sequence: 3,
    ),
  );
}
