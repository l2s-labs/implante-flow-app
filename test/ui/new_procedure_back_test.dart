import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:implate_flow/domain/models.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_screen.dart';
import 'package:implate_flow/ui/new_procedure/new_procedure_viewmodel.dart';
import 'package:provider/provider.dart';

import '../helpers/mock_clinic_repository.dart';
import '../helpers/mock_clinic_service.dart';

void main() {
  testWidgets('Voltar recua uma etapa e só sai após confirmar o descarte', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.first;
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.push('/novo'), child: const Text('Abrir')),
          ),
        ),
        GoRoute(
          path: '/novo',
          builder: (_, _) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const NewProcedureScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Implante'));
    await tester.pump();
    await tester.tap(find.text('Unitário'));
    await tester.pumpAndSettle();
    expect(find.text('Boca'), findsOneWidget);
    viewModel.toggleTooth(11);
    await tester.pump();

    // Etapa 1 -> 0: volta sem sair do assistente.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modalidade'), findsWidgets);
    expect(viewModel.step, 0);
    expect(find.text('Abrir'), findsNothing);

    // Etapa 0 com dentes marcados: pede confirmação.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Descartar procedimento?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('sem nada preenchido, Voltar na primeira etapa sai direto', (tester) async {
    final repository = MockClinicRepository(MockClinicService());
    final patient = repository.current.patients.first;
    final viewModel = NewProcedureViewModel(repository, patientId: patient.id);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.push('/novo'), child: const Text('Abrir')),
          ),
        ),
        GoRoute(
          path: '/novo',
          builder: (_, _) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const NewProcedureScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(viewModel.hasDraftProgress, isFalse);
    expect(viewModel.modality, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text('Descartar procedimento?'), findsNothing);
    expect(Modality.values, isNotEmpty);
  });
}
