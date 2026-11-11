import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:implate_flow/data/repositories/clinic_repository.dart';
import 'package:implate_flow/data/repositories/clinic_state_store.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/routing/router.dart';
import 'package:implate_flow/ui/core/layout.dart';
import 'package:implate_flow/ui/view_models.dart';

class TestAuth implements WorkOsAuth {
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('primeiro acesso: validação, teclado e conclusão', (
    tester,
  ) async {
    final repository = ClinicStateStore.fromSnapshot(
      const ClinicSnapshot(
        profile: DentistProfile(name: 'Teste', email: 'teste@example.com'),
        signedIn: true,
        patients: [],
        procedures: [],
        sequence: 0,
      ),
      ids: () => 'local-teste',
    );
    final session = SessionViewModel(
      repository,
      TestAuth(),
      workOsClientId: '',
    );
    await session.restored;
    final router = buildRouter(session);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vamos preparar seu consultório'), findsOneWidget);
    debugPrint('VISUAL: tela inicial');
    await tester.ensureVisible(find.text('Concluir cadastro'));
    await tester.tap(find.text('Concluir cadastro'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um telefone válido com DDD.'), findsOneWidget);
    debugPrint('VISUAL: validações obrigatórias');
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Telefone com DDD'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefone com DDD'),
      '11999999999',
    );
    await tester.pumpAndSettle();
    debugPrint('VISUAL: telefone e teclado');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CRO'),
      'rj44731',
    );
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Nome da clínica ou consultório'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da clínica ou consultório'),
      'Clínica de teste',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Concluir cadastro'));
    debugPrint('VISUAL: formulário preenchido');
    await tester.tap(find.text('Concluir cadastro'));
    await tester.pumpAndSettle();
    expect(repository.current.profile.locations.single.isDefault, isTrue);
    expect(find.text('Início'), findsWidgets);
    debugPrint('VISUAL: conclusão e início');
  });
}
