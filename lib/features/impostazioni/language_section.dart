import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/claude_service.dart';
import 'package:salute_bettin/data/services/dati_translation_service.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/dashboard/dashboard_page.dart'
    show saluteAnalysisProvider;
import 'package:salute_bettin/main.dart' show linguaProvider;

/// Scelta della lingua dell'interfaccia (🇮🇹 Italiano / 🇬🇧 English).
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  Future<void> _scegli(
      BuildContext context, WidgetRef ref, String code) async {
    if (code == ref.read(linguaProvider)) return;
    final messenger = ScaffoldMessenger.of(context);
    await SettingsService.instance.setLanguageCode(code);
    ref.read(linguaProvider.notifier).state = code;

    // Le notifiche già programmate vanno rifatte nella nuova lingua
    try {
      await NotificationService.instance.rischedulaTutti();
    } catch (_) {}

    await _traduciScore(messenger, ref, code);
    if (code == 'en' && ClaudeService.chiaveConfigurata) {
      await _traduciDati(messenger, ref);
    }
  }

  /// Traduce (solo per la visualizzazione) esami e visite già salvati.
  Future<void> _traduciDati(
      ScaffoldMessengerState messenger, WidgetRef ref) async {
    try {
      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 30),
          content: Text(tr('Traduzione di esami e visite in corso...'))));
      final n = await DatiTranslationService.instance.traduciTutto();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$n')));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
          SnackBar(content: Text(tr('Esami e visite tradotti'))));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: AppTheme.error,
          content: Text('${tr('Traduzione di esami e visite non riuscita: riprova con il pulsante nelle Impostazioni')}\n$e')));
    }
  }

  /// Traduce l'Health Score già calcolato (NON lo ricalcola).
  Future<void> _traduciScore(
      ScaffoldMessengerState messenger, WidgetRef ref, String code) async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final paz = await repo.getPaziente();
      if (paz == null) return;
      // Senza chiave AI la spiegazione è costruita dal codice (già traducibile)
      if (!ClaudeService.chiaveConfigurata) return;
      final s = SettingsService.instance;
      final key = BackupService.slotKey(paz.nome, paz.cognome);
      final dati = s.cachedScoreData(key);
      final score = s.cachedScore(key);
      if (dati == null || score == null) return;

      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 20),
          content: Text(tr('Traduzione dell\'Health Score in corso...'))));

      final r = await ClaudeService().traduciAnalisi(dati, code);
      jsonDecode(r.json); // controlla che sia JSON valido prima di salvare
      await s.saveScoreCache(
          score, r.json, s.cachedScoreHash(key) ?? '', key);
      try {
        await repo.saveTokenUsage(
            r.risposta.toTokenUsage('Traduzione Health Score'));
      } catch (_) {}

      ref.invalidate(saluteAnalysisProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
          SnackBar(content: Text(tr('Health Score tradotto'))));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(tr(
              'Traduzione dell\'Health Score non riuscita: resta nella lingua precedente'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attuale = ref.watch(linguaProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Lingua / Language',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary, letterSpacing: 0.5)),
        ),
      ),
      RadioListTile<String>(
        title: const Text('🇮🇹  Italiano'),
        value: 'it',
        groupValue: attuale,
        activeColor: AppTheme.primary,
        onChanged: (v) {
          if (v != null) _scegli(context, ref, v);
        },
      ),
      RadioListTile<String>(
        title: const Text('🇬🇧  English'),
        value: 'en',
        groupValue: attuale,
        activeColor: AppTheme.primary,
        onChanged: (v) {
          if (v != null) _scegli(context, ref, v);
        },
      ),
      if (attuale == 'en')
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Traduci esami e visite'),
          subtitle: const Text(
              'Traduce i dati salvati (nuovi inclusi); gli originali restano invariati'),
          onTap: () => _traduciDati(ScaffoldMessenger.of(context), ref),
        ),
    ]);
  }
}
