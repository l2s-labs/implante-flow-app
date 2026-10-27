import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/clinical_catalog_controller.dart';
import 'data/repositories/api_clinic_repository.dart';
import 'data/repositories/clinic_repository.dart';
import 'data/services/clinic_api.dart';
import 'data/services/local_catalog_store.dart';
import 'data/services/local_clinic_store.dart';
import 'data/services/workos_auth.dart';
import 'domain/clinic_snapshot.dart';
import 'domain/models.dart';
import 'routing/router.dart';
import 'ui/core/api_feedback_host.dart';
import 'ui/core/date_picker.dart';
import 'ui/core/app_safe_area.dart';
import 'ui/core/layout.dart';
import 'ui/view_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalClinicStore();
  final catalogStore = LocalCatalogStore();
  final loaded = await store.load();
  final cachedCatalog = await catalogStore.load() ?? bundledClinicalCatalog;
  final catalogController = ClinicalCatalogController(cachedCatalog);
  final repository = ApiClinicRepository(
    api: ClinicApi(baseUrl: AppConfig.apiBaseUrl),
    initial: _cachedChart(loaded),
    initialCatalog: cachedCatalog,
    persist: store.save,
    catalogStore: catalogStore,
  );
  repository.bindCatalog(catalogController.replace);
  runApp(
    MultiProvider(
      providers: [
        Provider<ClinicRepository>.value(value: repository),
        ChangeNotifierProvider.value(value: catalogController),
        ChangeNotifierProvider(create: (_) => SessionViewModel(repository, NativeWorkOsAuth())),
      ],
      child: const ImplateApp(),
    ),
  );
}

final _serverId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

ClinicSnapshot _cachedChart(ClinicSnapshot? loaded) {
  const empty = ClinicSnapshot(
    profile: DentistProfile(name: '', email: ''),
    signedIn: false,
    patients: [],
    procedures: [],
    sequence: 0,
  );
  if (loaded == null) return empty;
  final ids = [
    for (final patient in loaded.patients) patient.id,
    for (final procedure in loaded.procedures) procedure.id,
    for (final implant in loaded.implants) implant.id,
    for (final location in loaded.profile.locations) location.id,
  ];
  if (ids.any((id) => !_serverId.hasMatch(id))) return empty;
  return loaded;
}

class ImplateApp extends StatefulWidget {
  const ImplateApp({super.key});

  @override
  State<ImplateApp> createState() => _ImplateAppState();
}

class _ImplateAppState extends State<ImplateApp> {
  late final _router = buildRouter(context.read<SessionViewModel>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'implante flow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // L2S-69: app e DatePickers em PT-BR (mesmo se o aparelho estiver em outro idioma).
      locale: kAppLocalePtBr,
      supportedLocales: const [kAppLocalePtBr],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ApiFeedbackHost(
          child: AppSafeArea(child: child ?? const SizedBox.shrink()),
        );
      },
      routerConfig: _router,
    );
  }
}
