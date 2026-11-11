import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/clinic_repository.dart';
import '../ui/calendar/calendar_screen.dart';
import '../domain/queries.dart';
import '../ui/home/home_screen.dart';
import '../ui/home/next_week_screen.dart';
import '../ui/home/today_reminders_screen.dart';
import '../ui/reports/reports_screen.dart';
import '../ui/login/login_screen.dart';
import '../ui/onboarding/first_steps_screen.dart';
import '../ui/new_procedure/new_procedure_screen.dart';
import '../ui/new_procedure/new_procedure_viewmodel.dart';
import '../ui/patients/patient_screen.dart';
import '../ui/patients/patients_screen.dart';
import '../ui/procedure/certificate_screen.dart';
import '../ui/procedure/procedure_screen.dart';
import '../ui/profile/profile_screen.dart';
import '../ui/shell/app_shell.dart';
import '../ui/view_models.dart';

GoRouter buildRouter(SessionViewModel session) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: session,
    redirect: (context, state) {
      final signedIn = session.signedIn;
      final loggingIn = state.matchedLocation == '/login';
      final onboarding = state.matchedLocation == '/primeiros-passos';
      if (!session.routingReady || session.preparingSignIn) {
        return loggingIn ? null : '/login';
      }
      if (!signedIn) return loggingIn ? null : '/login';
      if (session.firstStepsRequired) {
        return onboarding ? null : '/primeiros-passos';
      }
      if (onboarding) return '/home';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/primeiros-passos',
        builder: (context, state) => const FirstStepsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) =>
                      HomeViewModel(context.read<ClinicRepository>()),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) =>
                      PatientsViewModel(context.read<ClinicRepository>()),
                  child: const PatientsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) =>
                      CalendarViewModel(context.read<ClinicRepository>()),
                  child: const CalendarScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => ReportsViewModel(
                    context.read<ClinicRepository>(),
                    filter: reportFilterFromName(
                      state.uri.queryParameters['filtro'],
                    ),
                  ),
                  child: const ReportsQuerySync(child: ReportsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/patients/:patientId',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => PatientViewModel(
            context.read<ClinicRepository>(),
            patientId: state.pathParameters['patientId']!,
          ),
          child: const PatientScreen(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => NewProcedureViewModel(
                context.read<ClinicRepository>(),
                patientId: state.pathParameters['patientId']!,
              ),
              child: const NewProcedureScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/procedures/:procedureId',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => ProcedureViewModel(
            context.read<ClinicRepository>(),
            procedureId: state.pathParameters['procedureId']!,
          ),
          child: const ProcedureScreen(),
        ),
        routes: [
          GoRoute(
            path: 'certificate',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => CertificateViewModel(
                context.read<ClinicRepository>(),
                procedureId: state.pathParameters['procedureId']!,
              ),
              child: const CertificateScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/week',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              NextWeekViewModel(context.read<ClinicRepository>()),
          child: const NextWeekScreen(),
        ),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              TodayRemindersViewModel(context.read<ClinicRepository>()),
          child: const TodayRemindersScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              ProfileViewModel(context.read<ClinicRepository>()),
          child: ProfileScreen(focusField: state.uri.queryParameters['focus']),
        ),
      ),
    ],
  );
}
