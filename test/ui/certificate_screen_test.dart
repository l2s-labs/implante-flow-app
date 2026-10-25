import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';
import 'package:implate_flow/domain/certificate.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/procedure/certificate_screen.dart';
import 'package:implate_flow/ui/view_models.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('CRO ausente mostra CTA Completar cadastro', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final procedure = repository.current.procedures.first;
    repository.updateProfile(repository.current.profile.copyWith(cro: ''));
    final viewModel = CertificateViewModel(repository, procedureId: procedure.id);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const CertificateScreen()),
              GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('Perfil'))),
            ],
          ),
        ),
      ),
    );

    expect(find.text(certificateCroRequiredMessage), findsOneWidget);
    expect(find.text('Completar cadastro'), findsOneWidget);
    expect(find.text('Gerar PDF'), findsNothing);
  });

  testWidgets('CRO ausente oculta os demais impedimentos', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final procedure = repository.current.procedures.first;
    final patient = repository.current.patients.firstWhere((p) => p.id == procedure.patientId);
    repository.updateProfile(repository.current.profile.copyWith(cro: ''));
    repository.updatePatient(patient.copyWith(name: ''));
    final viewModel = CertificateViewModel(repository, procedureId: procedure.id);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: const MaterialApp(home: CertificateScreen()),
      ),
    );

    expect(find.text(certificateCroRequiredMessage), findsOneWidget);
    expect(find.text('Completar cadastro'), findsOneWidget);
    expect(find.text('Rastreio incompleto'), findsNothing);
    expect(find.text('• Paciente'), findsNothing);
  });

  testWidgets('emissão pronta oferece duas vias e local de atendimento', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final ready = repository.current.procedures.firstWhere(
      (procedure) =>
          procedure.modality == Modality.implante &&
          procedure.pillars.every((site) => site.piece?.certificateReady == true),
    );
    final viewModel = CertificateViewModel(repository, procedureId: ready.id);
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: const MaterialApp(home: CertificateScreen()),
      ),
    );

    expect(find.text('Emitir em 2 vias'), findsOneWidget);
    expect(find.textContaining('Consultório Centro'), findsWidgets);
    expect(find.text('Gerar PDF'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(viewModel.emitTwoCopies, isTrue);
  });
}
