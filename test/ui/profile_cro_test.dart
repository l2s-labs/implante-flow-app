import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/ui/profile/profile_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';

void main() {
  testWidgets('CRO fora do formato UF 00000 mostra aviso no campo', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfileViewModel(repository)),
          ChangeNotifierProvider(create: (_) => SessionViewModel(repository, _IdleAuth())),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    final field = find.widgetWithText(TextFormField, 'SP 12345').evaluate().isEmpty
        ? find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'CRO/UF')
        : find.widgetWithText(TextFormField, 'SP 12345');
    expect(field, findsOneWidget);

    final before = repository.current.profile.cro;
    await tester.enterText(field, '123');
    await tester.pump();
    expect(repository.current.profile.cro, before);
    expect(find.text('Use o formato UF 00000, por exemplo SP 12345.'), findsOneWidget);

    await tester.enterText(field, 'SP 12345');
    await tester.pump();
    expect(find.text('Use o formato UF 00000, por exemplo SP 12345.'), findsNothing);

    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('Use o formato UF 00000, por exemplo SP 12345.'), findsNothing);
  });
}

class _IdleAuth implements WorkOsAuth {
  @override
  Future<WorkOsIdentity> signIn({required String clientId, required String redirectUri}) {
    throw UnimplementedError();
  }

  @override
  Future<WorkOsIdentity?> currentIdentity({required String clientId}) async => null;

  @override
  Future<void> signOut({required String redirectUri}) async {}
}
