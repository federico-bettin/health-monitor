import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:go_router/go_router.dart';
import 'package:salute_bettin/features/auth/splash_page.dart';
import 'package:salute_bettin/features/calendario/calendario_page.dart';
import 'package:salute_bettin/features/dashboard/dashboard_page.dart';
import 'package:salute_bettin/features/esami/esami_page.dart';
import 'package:salute_bettin/features/farmaci/farmaci_page.dart';
import 'package:salute_bettin/features/impostazioni/impostazioni_page.dart';
import 'package:salute_bettin/features/import_documento/import_documento_page.dart';
import 'package:salute_bettin/features/onboarding/onboarding_page.dart';
import 'package:salute_bettin/features/profilo/profilo_page.dart';
import 'package:salute_bettin/features/visite/visite_page.dart';
import 'package:salute_bettin/features/wearable/wearable_page.dart';

class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String esami = '/esami';
  static const String visite = '/visite';
  static const String farmaci = '/farmaci';
  static const String calendario = '/calendario';
  static const String importDocumento = '/import-documento';
  static const String impostazioni = '/impostazioni';
  static const String profilo = '/profilo';
  static const String wearable = '/wearable'; // ← nuovo
  static const String conflitti = '/conflitti';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashPage()),
    GoRoute(path: AppRoutes.onboarding, builder: (c, s) => const OnboardingPage()),

    // Fuori dalla shell — con back button
    GoRoute(
      path: AppRoutes.profilo,
      builder: (c, s) => const ProfiloPage(),
    ),
    GoRoute(
      path: AppRoutes.importDocumento,
      builder: (c, s) => const ImportDocumentoPage(),
    ),
    GoRoute(
      path: AppRoutes.wearable,
      builder: (c, s) => const WearablePage(),
    ),

    // Shell con bottom nav
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: AppRoutes.dashboard, builder: (c, s) => const DashboardPage()),
        GoRoute(path: AppRoutes.esami, builder: (c, s) => const EsamiPage()),
        GoRoute(path: AppRoutes.visite, builder: (c, s) => const VisitePage()),
        GoRoute(path: AppRoutes.farmaci, builder: (c, s) => const FarmaciPage()),
        GoRoute(path: AppRoutes.calendario, builder: (c, s) => const CalendarioPage()),
        GoRoute(path: AppRoutes.impostazioni, builder: (c, s) => const ImpostazioniPage()),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: Colors.red),
      const SizedBox(height: 16),
      Text('Pagina non trovata', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () => context.go(AppRoutes.dashboard),
          child: const Text('Torna alla dashboard')),
    ])),
  ),
);

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/esami')) return 1;
    if (location.startsWith('/visite')) return 2;
    if (location.startsWith('/farmaci')) return 3;
    if (location.startsWith('/calendario')) return 4;
    if (location.startsWith('/impostazioni')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    Localizations.localeOf(context); // si ricostruisce al cambio lingua
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0: context.go(AppRoutes.dashboard);
            case 1: context.go(AppRoutes.esami);
            case 2: context.go(AppRoutes.visite);
            case 3: context.go(AppRoutes.farmaci);
            case 4: context.go(AppRoutes.calendario);
            case 5: context.go(AppRoutes.impostazioni);
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard), label: tr('Home')),
          BottomNavigationBarItem(icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science), label: tr('Esami')),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined),
              activeIcon: Icon(Icons.local_hospital), label: tr('Visite')),
          BottomNavigationBarItem(icon: Icon(Icons.medication_outlined),
              activeIcon: Icon(Icons.medication), label: tr('Farmaci')),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month), label: tr('Calendario')),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings), label: tr('Impostazioni')),
        ],
      ),
    );
  }
}
