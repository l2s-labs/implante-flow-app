import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/calendar/calendar_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('calendário filtra retorno pelo ícone e limpa', (tester) async {
    final today = brasiliaToday();
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
            surgeryDate: DateTime(2020, 1, 1),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 11, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'falta',
                date: today,
                reason: ReturnReason.controle,
                status: ReturnStatus.faltou,
                reminderEnabled: false,
              ),
            ],
          ),
          Procedure(
            id: 'pro-bruno',
            patientId: bruno.id,
            modality: Modality.implante,
            surgeryDate: DateTime(2020, 1, 1),
            statusLabel: 'Instalado',
            sites: const [ToothSite(fdi: 21, role: ToothRole.pilar)],
            followUps: [
              FollowUp(
                id: 'marcado',
                date: today,
                reason: ReturnReason.controle,
                status: ReturnStatus.agendado,
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
        create: (_) => CalendarViewModel(repository),
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.text('Agendados'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Agendados'), findsOneWidget);
    await tester.tap(find.text('Faltou'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsNothing);
    expect(find.descendant(of: find.byTooltip('Filtros'), matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.descendant(of: find.byTooltip('Filtros'), matching: find.text('1')), findsNothing);
  });
}
