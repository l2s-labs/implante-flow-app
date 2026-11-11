import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:implate_flow/data/services/clinic_api.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/ui/profile/profile_screen.dart';
import 'package:implate_flow/ui/view_models.dart';

import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';

class _Repository extends MockClinicRepository {
  _Repository() : super(MockClinicService());
  int saves = 0;
  bool fail = false;
  @override
  Future<void> saveProfileIdentity({
    required String name,
    required String phone,
    required String cro,
  }) async {
    saves++;
    if (fail) throw const ClinicApiException(500, 'Erro ao salvar.');
    await super.saveProfileIdentity(name: name, phone: phone, cro: cro);
  }
}

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
  testWidgets(
    'edição só grava ao salvar, preserva rascunho no erro e confirma descarte',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final viewModel = ProfileViewModel(repository);
      final session = SessionViewModel(repository, _Auth(), workOsClientId: '');
      await session.restored;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider.value(value: session),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.tap(find.text('Editar').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Ana Lima',
      );
      expect(repository.saves, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      repository.fail = true;
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Erro ao salvar.'), findsOneWidget);
      expect(find.text('Ana Lima'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(repository.saves, 2);
      expect(repository.current.profile.name, 'Ana Lima');
      expect(find.text('Editar dados profissionais'), findsNothing);
    },
  );
}
