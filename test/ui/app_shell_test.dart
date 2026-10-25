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
  testWidgets('a aba inicial do menu inferior se chama Início', (tester) async {
    final repository = MockClinicRepository.fromSnapshot(
      const ClinicSnapshot(
        profile: DentistProfile(name: 'Dra. Helena', email: 'helena@consultorio.exemplo'),
        signedIn: true,
        patients: [],
        procedures: [],
        sequence: 1,
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

    final home = tester.widget<NavigationDestination>(find.widgetWithText(NavigationDestination, 'Início'));
    expect((home.icon as Icon).icon, Icons.home_outlined);
    expect(find.widgetWithText(NavigationDestination, 'Agenda'), findsNothing);
    expect(find.widgetWithText(NavigationDestination, 'Pacientes'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Calendário'), findsOneWidget);
    final reports = tester.widget<NavigationDestination>(find.widgetWithText(NavigationDestination, 'Relatórios'));
    expect((reports.icon as Icon).icon, Icons.bar_chart_outlined);

    await tester.tap(find.text('Pacientes'));
    await tester.pumpAndSettle();
    expect(find.text('Pacientes'), findsWidgets);

    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(NavigationDestination, 'Início'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Comparecimento indisponível'), findsOneWidget);
  });
}
