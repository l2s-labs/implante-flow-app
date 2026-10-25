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
  testWidgets('filtros abrem no ícone, recortam a lista e limpam', (tester) async {
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
                id: 'hoje',
                date: today,
                reason: ReturnReason.controle,
                status: ReturnStatus.agendado,
                reminderEnabled: false,
              ),
            ],
          ),
          Procedure(
            id: 'pro-bruno',
            patientId: bruno.id,
            modality: Modality.protese,
            surgeryDate: DateTime(2026, 9, 1),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 21, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'depois',
                date: DateTime(2026, 10, 30),
                reason: ReturnReason.controle,
                status: ReturnStatus.agendado,
                reminderEnabled: false,
              ),
            ],
          ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReportsViewModel(repository, filter: ReportFilter.proximos),
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.text('Modalidade'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Modalidade'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);

    await tester.tapAt(const Offset(24, 700));
    await tester.pumpAndSettle();
    expect(find.text('Limpar filtros'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 dias'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsNothing);
    expect(find.descendant(of: find.byTooltip('Filtros'), matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Prótese sobre implante'));
    await tester.tap(find.text('Prótese sobre implante'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum retorno próximo.'), findsOneWidget);
    expect(find.descendant(of: find.byTooltip('Filtros'), matching: find.text('2')), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsOneWidget);

    await tester.tap(find.text('Compromissos'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Ana Costa')).dy, lessThan(tester.getTopLeft(find.text('Bruno Dias')).dy));
  });
}
