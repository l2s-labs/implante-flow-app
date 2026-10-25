import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/procedure/procedure_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('mudança de etapa avisa sem marcar entrega e a falha pode ser reprocessada', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final maria = repository.current.patients.firstWhere((patient) => patient.name == 'Maria Souza');
    final procedure = repository.current.procedures.firstWhere(
      (item) => item.patientId == maria.id && item.modality == Modality.implante,
    );
    repository.addVisit(
      procedureId: procedure.id,
      note: 'Controle',
      statusLabel: implantStatusLabel(ImplantStatus.reabertura),
    );
    final notice = repository.current.procedures
        .firstWhere((item) => item.id == procedure.id)
        .stageNotices
        .single;

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProcedureViewModel(repository, procedureId: procedure.id),
        child: const MaterialApp(home: ProcedureScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Aguardando confirmação do envio'), findsOneWidget);
    expect(find.textContaining('Enviado'), findsNothing);

    repository.failStageNotice(procedureId: procedure.id, noticeId: notice.id);
    expect(
      repository.current.procedures
          .firstWhere((item) => item.id == procedure.id)
          .stageNotices
          .single
          .delivery,
      NoticeDelivery.falha,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Falha no envio'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.textContaining('Aguardando confirmação do envio'), findsOneWidget);
    expect(find.textContaining('Enviado'), findsNothing);
  });
}
