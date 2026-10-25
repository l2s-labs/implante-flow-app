import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/data/repositories/clinic_repository.dart';
import 'helpers/mock_clinic_repository.dart';
import 'helpers/mock_clinic_service.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/main.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login mostra marca e abre AuthKit sem botão Entrar', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final auth = _PendingAuth();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider(create: (_) => SessionViewModel(repository, auth, workOsClientId: 'client_test')),
        ],
        child: const ImplateApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('implante flow'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    expect(auth.signInCalls, 1);
  });

  testWidgets('cancelamento não reabre AuthKit em loop', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final auth = _FailingAuth(const WorkOsAuthException('Login cancelado.'));
    final session = SessionViewModel(repository, auth, workOsClientId: 'client_test');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClinicRepository>.value(value: repository),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: const ImplateApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await session.restored;
    await tester.pump();

    expect(auth.signInCalls, 1);
    expect(find.text('Login cancelado.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(auth.signInCalls, 1);
  });
}

class _PendingAuth implements WorkOsAuth {
  var signInCalls = 0;
  final _hang = Completer<WorkOsIdentity>();

  @override
  Future<WorkOsIdentity> signIn({required String clientId, required String redirectUri}) {
    signInCalls++;
    return _hang.future;
  }

  @override
  Future<WorkOsIdentity?> currentIdentity({required String clientId}) async => null;

  @override
  Future<void> signOut({required String redirectUri}) async {}
}

class _FailingAuth implements WorkOsAuth {
  _FailingAuth(this.error);

  final WorkOsAuthException error;
  var signInCalls = 0;

  @override
  Future<WorkOsIdentity> signIn({required String clientId, required String redirectUri}) async {
    signInCalls++;
    throw error;
  }

  @override
  Future<WorkOsIdentity?> currentIdentity({required String clientId}) async => null;

  @override
  Future<void> signOut({required String redirectUri}) async {}
}
