import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/data/services/workos_auth.dart';
import 'package:implate_flow/ui/profile/profile_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('perfil adiciona local e mantém um único padrão', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final viewModel = ProfileViewModel(repository);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: viewModel),
          ChangeNotifierProvider(create: (_) => SessionViewModel(repository, _IdleAuth())),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Consultório Centro'), findsOneWidget);
    expect(find.textContaining('Padrão'), findsOneWidget);

    await tester.tap(find.text('Adicionar local'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first,
      'Consultório Sul',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Consultório Sul'), findsOneWidget);
    expect(find.textContaining('Padrão'), findsOneWidget);
    final sul = viewModel.profile.locations.singleWhere((location) => location.name == 'Consultório Sul');
    viewModel.makeDefaultLocation(sul.id);
    await tester.pump();
    expect(find.textContaining('Padrão'), findsOneWidget);
    expect(viewModel.profile.locations.where((location) => location.isDefault), hasLength(1));
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
