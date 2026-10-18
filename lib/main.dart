import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

final linguaProvider = StateProvider<String>((ref) {
  return SettingsService.instance.languageCode;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forza orientamento portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar trasparente su dark
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Hive.initFlutter();
  Hive.registerAdapter(PazienteAdapter());
  Hive.registerAdapter(EsameAdapter());
  Hive.registerAdapter(ValoreEsameAdapter());
  Hive.registerAdapter(VisitaAdapter());
  Hive.registerAdapter(FarmacoAdapter());
  Hive.registerAdapter(AppuntamentoAdapter());
  Hive.registerAdapter(TipoAppuntamentoAdapter());
  Hive.registerAdapter(TokenUsageAdapter());

  await SettingsService.init();

  // Notifiche promemoria: init e riprogrammazione (non blocca l'avvio se fallisce)
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.rischedulaTutti();
  } catch (_) {}

  runApp(const ProviderScope(child: SaluteBettinApp()));
}

class SaluteBettinApp extends ConsumerWidget {
  const SaluteBettinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lingua = ref.watch(linguaProvider);

    return MaterialApp.router(
      title: 'SaluteBettin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // ← dark di default
      routerConfig: appRouter,
      locale: Locale(lingua),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
