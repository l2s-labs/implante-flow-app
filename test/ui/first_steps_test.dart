import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:implate_flow/data/repositories/clinic_repository.dart';
import 'package:implate_flow/data/repositories/clinic_state_store.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/onboarding/first_steps_screen.dart';
import 'package:implate_flow/routing/router.dart';
import 'package:implate_flow/ui/view_models.dart';

class _Auth implements WorkOsAuth {
  @override
  Future<WorkOsIdentity?> currentIdentity({required String clientId}) async =>
      null;
  @override
  Future<WorkOsIdentity> signIn({
    required String clientId,
    required String redirectUri,
  }) => throw UnimplementedError();
  @override
  Future<void> signOut({required String redirectUri}) async {}
}

void main() {
  testWidgets('rota mostra primeiros passos e permite adiar', (tester) async {
    final repository = ClinicStateStore.fromSnapshot(
      const ClinicSnapshot(
        profile: DentistProfile(name: 'Ana', email: 'ana@example.com'),
        signedIn: true,
        patients: [],
        procedures: [],
        sequence: 0,
      ),
    );
    final session = SessionViewModel(repository, _Auth(), workOsClientId: '');
    await session.restored;
    final router = buildRouter(session);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vamos preparar seu consultório'), findsOneWidget);
    await tester.tap(find.text('Fazer depois'));
    await tester.pumpAndSettle();
    expect(find.text('Vamos preparar seu consultório'), findsNothing);
    expect(find.text('Início'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    session.dispose();
  });

  testWidgets('valida campos e salva o local padrão', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = ClinicStateStore.fromSnapshot(
      const ClinicSnapshot(
        profile: DentistProfile(name: 'Ana', email: 'ana@example.com'),
        signedIn: true,
        patients: [],
        procedures: [],
        sequence: 0,
      ),
      ids: () => 'location-1',
    );
    final session = SessionViewModel(repository, _Auth(), workOsClientId: '');
    await session.restored;
    expect(session.firstStepsRequired, isTrue);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: const MaterialApp(home: FirstStepsScreen()),
      ),
    );
    await tester.ensureVisible(find.text('Concluir cadastro'));
    await tester.tap(find.text('Concluir cadastro'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um telefone válido com DDD.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefone com DDD'),
      '11999999999',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CRO'),
      'SP 12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da clínica ou consultório'),
      'Clínica Central',
    );
    await tester.ensureVisible(find.text('Concluir cadastro'));
    await tester.tap(find.text('Concluir cadastro'));
    await tester.pumpAndSettle();
    expect(repository.current.profile.phone, '11999999999');
    expect(repository.current.profile.cro, 'SP 12345');
    expect(repository.current.profile.locations.single.isDefault, isTrue);
    expect(session.firstStepsRequired, isFalse);
    repository.updateProfile(repository.current.profile.copyWith(cro: ''));
    await tester.pump();
    expect(session.firstStepsRequired, isFalse);
    session.dispose();
  });
}
