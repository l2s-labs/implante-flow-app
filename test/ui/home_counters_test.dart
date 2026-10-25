import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/data/repositories/clinic_repository.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/routing/router.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home troca listas por contadores e abre o destino filtrado', (tester) async {
    final today = brasiliaToday();
    final ana = Patient(id: 'ana', name: 'Ana Costa', phone: '', birthDate: DateTime(1984, 1, 28));
    final bruno = Patient(id: 'bruno', name: 'Bruno Dias', phone: '', birthDate: DateTime(1970, 2, 2));
    final clara = Patient(id: 'clara', name: 'Clara Nunes', phone: '', birthDate: DateTime(1990, 5, 5));
    final repository = MockClinicRepository.fromSnapshot(
      ClinicSnapshot(
        profile: const DentistProfile(name: 'Dra. Helena', email: 'helena@consultorio.exemplo'),
        signedIn: true,
        sequence: 1,
        patients: [ana, bruno, clara],
        procedures: [
          Procedure(
            id: 'pro-ana',
            patientId: ana.id,
            modality: Modality.implante,
            surgeryDate: today.subtract(const Duration(days: 40)),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 36, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'ret-1',
                date: today.subtract(const Duration(days: 1)),
                reason: ReturnReason.osseointegracao,
                status: ReturnStatus.agendado,
                reminderEnabled: false,
              ),
              FollowUp(
                id: 'ret-2',
                date: today.subtract(const Duration(days: 4)),
                reason: ReturnReason.sutura,
                status: ReturnStatus.agendado,
                reminderEnabled: false,
              ),
            ],
          ),
          Procedure(
            id: 'pro-bruno',
            patientId: bruno.id,
            modality: Modality.implante,
            surgeryDate: today.subtract(const Duration(days: 20)),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 11, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'ret-3',
                date: today.subtract(const Duration(days: 2)),
                reason: ReturnReason.osseointegracao,
                status: ReturnStatus.faltou,
                reminderEnabled: false,
              ),
            ],
          ),
          Procedure(
            id: 'pro-clara',
            patientId: clara.id,
            modality: Modality.protese,
            surgeryDate: today,
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 14, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'ret-4',
                date: today.add(const Duration(days: 15)),
                reason: ReturnReason.instalarPonte,
                status: ReturnStatus.agendado,
                reminderEnabled: true,
              ),
            ],
          ),
        ],
      ),
    );
    final session = SessionViewModel(repository, NativeWorkOsAuth());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp.router(routerConfig: buildRouter(session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atrasados'), findsNothing);
    expect(find.text('Lembretes de hoje'), findsNothing);
    expect(find.bySemanticsLabel('Atraso, 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Lembretes, 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Próximos 7 dias, 0'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Lembretes, 1'));
    await tester.pumpAndSettle();
    expect(find.text('Clara Nunes'), findsOneWidget);
    expect(find.text('${formatDay(today.add(const Duration(days: 15)))} · Instalar a ponte'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Atraso, 1'));
    await tester.pumpAndSettle();
    expect(find.text('Relatórios'), findsWidgets);
    final reportsScroll = find.descendant(
      of: find.byKey(const ValueKey('reports-scroll')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-count-atrasados')),
      200,
      scrollable: reportsScroll,
    );
    expect(
      tester.widget<Semantics>(find.byKey(const ValueKey('report-count-atrasados'))).properties.selected,
      isTrue,
    );
    await tester.scrollUntilVisible(find.text('Ana Costa'), 300, scrollable: reportsScroll);
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('2 compromissos'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-count-faltas')),
      -300,
      scrollable: reportsScroll,
    );
    await tester.tap(find.byKey(const ValueKey('report-count-faltas')));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.text('Ana Costa'), findsNothing);

    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    repository.completeFollowUp(
      followUpId: 'ret-1',
      note: 'Compareceu',
      statusLabel: 'Realizado',
      returnStatus: ReturnStatus.realizado,
    );
    repository.completeFollowUp(
      followUpId: 'ret-2',
      note: 'Compareceu',
      statusLabel: 'Realizado',
      returnStatus: ReturnStatus.realizado,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Atraso, 0'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Atraso, 0'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nenhum paciente em atraso.'),
      300,
      scrollable: reportsScroll,
    );
    expect(find.text('Nenhum paciente em atraso.'), findsOneWidget);
  });
}
