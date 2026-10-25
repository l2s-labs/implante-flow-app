import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/domain/queries.dart';
import 'package:implate_flow/ui/reports/reports_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('painel separa atraso de falta e alterna a visão por compromisso', (tester) async {
    final today = DateTime(2026, 10, 19);
    final ana = Patient(id: 'ana', name: 'Ana Costa', phone: '', birthDate: DateTime(1984, 1, 28));
    final bruno = Patient(id: 'bruno', name: 'Bruno Dias', phone: '', birthDate: DateTime(1970, 2, 2));
    final repository = MockClinicRepository.fromSnapshot(
      ClinicSnapshot(
        profile: const DentistProfile(name: 'Dra. Helena', email: 'helena@consultorio.exemplo'),
        signedIn: true,
        sequence: 1,
        patients: [ana, bruno],
        procedures: [
          Procedure(
            id: 'pro-ana',
            patientId: ana.id,
            modality: Modality.implante,
            surgeryDate: DateTime(2026, 9, 1),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 11, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'vencido',
                date: today.subtract(const Duration(days: 1)),
                reason: ReturnReason.controle,
                status: ReturnStatus.agendado,
                reminderEnabled: false,
              ),
            ],
          ),
          Procedure(
            id: 'pro-bruno',
            patientId: bruno.id,
            modality: Modality.implante,
            surgeryDate: DateTime(2026, 9, 1),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 21, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'falta',
                date: DateTime(2026, 10, 1),
                reason: ReturnReason.reabertura,
                status: ReturnStatus.faltou,
                reminderEnabled: false,
              ),
            ],
          ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReportsViewModel(repository, filter: ReportFilter.atrasados),
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Comparecimento'), findsOneWidget);
    expect(
      find.text('Em dia significa sem retorno vencido ainda agendado. Atraso não é falta.'),
      findsOneWidget,
    );
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsNothing);
    expect(find.textContaining('Agendado'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-count-faltas')));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.text('1 falta'), findsOneWidget);
    expect(find.textContaining('Retorno para reabertura'), findsOneWidget);
    expect(find.text('Ana Costa'), findsNothing);

    await tester.tap(find.text('Compromissos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Prontuário'), findsOneWidget);
  });
}
