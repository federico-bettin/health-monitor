import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';
import 'package:timezone/timezone.dart' as tz;

/// Stato dei permessi Android per i promemoria. `null` = non determinabile.
class PermessiPromemoria {
  final bool? notifiche;
  final bool? allarmiEsatti;
  const PermessiPromemoria(this.notifiche, this.allarmiEsatti);
}

/// Pianifica le notifiche dei promemoria farmaci (solo Android; su Windows e
/// altre piattaforme non fa nulla).
///
/// Finestra mobile di [kFinestraGiorni] giorni, tetto [kTettoNotifiche],
/// ricostruzione completa a ogni modifica. Le notifiche dei farmaci usano ID
/// da [kIdBaseFarmaci] in su, separati da quelli di visite ed esami.
class FarmaciReminderService {
  FarmaciReminderService._();
  static final FarmaciReminderService instance = FarmaciReminderService._();

  static const _channelId = 'promemoria_farmaci';
  static const _channelName = 'Promemoria farmaci';

  Timer? _timer;
  Future<void>? _inCorso;
  bool _ripeti = false;

  bool get supportato => NotificationService.instance.pronto;

  AndroidFlutterLocalNotificationsPlugin? get _android => NotificationService
      .instance.plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Richiede una ricostruzione tra poco: più modifiche ravvicinate
  /// (es. un ripristino di backup) ne producono una sola.
  void richiediRicostruzione() {
    if (!supportato) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 800), () {
      ricostruisci();
    });
  }

  /// Cancella e rigenera tutte le notifiche dei farmaci.
  /// Chiamate sovrapposte vengono unite: al massimo una ripetizione.
  Future<void> ricostruisci() {
    if (_inCorso != null) {
      _ripeti = true;
      return _inCorso!;
    }
    final lavoro = () async {
      do {
        _ripeti = false;
        await _esegui();
      } while (_ripeti);
    }();
    _inCorso = lavoro.whenComplete(() => _inCorso = null);
    return _inCorso!;
  }

  Future<void> _esegui() async {
    final ns = NotificationService.instance;
    if (!ns.pronto) return;
    final s = SettingsService.instance;
    try {
      final plugin = ns.plugin;
      for (final p in await plugin.pendingNotificationRequests()) {
        if (p.id >= kIdBaseFarmaci) await plugin.cancel(p.id);
      }
      if (!s.farmaciNotifAttive) {
        await _salvaStato(0, null);
        return;
      }

      final repo = LocalRepository();
      await repo.init();
      final farmaci = (await repo.getFarmaci())
          .where((f) => f.promemoriaAttivo && !f.archiviato)
          .toList();

      final adesso = DateTime.now();
      final fine =
          DateTime(adesso.year, adesso.month, adesso.day + kFinestraGiorni);
      final gruppi = limitaAlTetto(raggruppaPerOrario(farmaci, adesso, fine));

      final esatti = await _android?.canScheduleExactNotifications() ?? false;
      final mostraNome = s.farmaciMostraNome;
      final ora = tz.TZDateTime.now(tz.local);

      var pianificate = 0;
      DateTime? ultima;
      for (final g in gruppi) {
        final quando = aIstante(g.quando, tz.local);
        if (!quando.isAfter(ora)) continue;
        final t = _testi(g, mostraNome);
        final dettagli = _dettagli(t.espanso);
        final id = kIdBaseFarmaci + pianificate;
        try {
          await _schedula(plugin, id, t, quando, dettagli,
              esatti ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle);
        } on PlatformException {
          // Allarmi esatti revocati: ripiego su allarme non esatto
          await _schedula(plugin, id, t, quando, dettagli,
              AndroidScheduleMode.inexactAllowWhileIdle);
        }
        pianificate++;
        ultima = g.quando;
      }
      await _salvaStato(pianificate, ultima);
    } catch (e) {
      debugPrint('Ricostruzione promemoria farmaci fallita: $e');
    }
  }

  Future<void> _schedula(
    FlutterLocalNotificationsPlugin plugin,
    int id,
    _Testi t,
    tz.TZDateTime quando,
    NotificationDetails dettagli,
    AndroidScheduleMode modo,
  ) =>
      plugin.zonedSchedule(
        id,
        t.titolo,
        t.corpo,
        quando,
        dettagli,
        androidScheduleMode: modo,
        payload: kPayloadFarmaci,
      );

  Future<void> _salvaStato(int n, DateTime? fino) async {
    final s = SettingsService.instance;
    await s.setFarmaciPianificati(n);
    await s.setFarmaciPianificatiFino(fino?.toIso8601String());
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  _Testi _testi(GruppoPromemoria g, bool mostraNome) {
    final ora = _hhmm(g.quando);
    if (!mostraNome) {
      return _Testi(tr('Promemoria farmaci'), tr('Ore {0}', [ora]), null);
    }
    String dettaglio(Farmaco f) {
      final parti = <String>[
        if (f.dosaggio.trim().isNotEmpty) f.dosaggio.trim(),
        if ((f.istruzioni ?? '').trim().isNotEmpty) f.istruzioni!.trim(),
      ];
      return parti.join(' · ');
    }

    if (g.farmaci.length == 1) {
      final f = g.farmaci.first;
      final d = dettaglio(f);
      return _Testi('$ora – ${f.nome}',
          d.isEmpty ? tr('È ora di prendere il farmaco') : d, null);
    }
    final righe = g.farmaci.map((f) {
      final d = dettaglio(f);
      return d.isEmpty ? f.nome : '${f.nome} – $d';
    }).join('\n');
    return _Testi(tr('{0} – {1} farmaci', [ora, g.farmaci.length]),
        g.farmaci.map((f) => f.nome).join(', '), righe);
  }

  NotificationDetails _dettagli(String? espanso) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Promemoria per l\'assunzione dei farmaci',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          styleInformation:
              espanso == null ? null : BigTextStyleInformation(espanso),
        ),
      );

  // ─── Permessi ─────────────────────────────────────────────

  Future<PermessiPromemoria> statoPermessi() async {
    if (!supportato) return const PermessiPromemoria(null, null);
    try {
      final a = _android;
      return PermessiPromemoria(await a?.areNotificationsEnabled(),
          await a?.canScheduleExactNotifications());
    } catch (_) {
      return const PermessiPromemoria(null, null);
    }
  }

  /// Chiede POST_NOTIFICATIONS (Android 13+). Mostrare prima una spiegazione.
  Future<bool> richiediNotifiche() => NotificationService.instance.richiediPermesso();

  /// Apre la schermata di sistema per consentire gli allarmi esatti.
  Future<void> richiediAllarmiEsatti() async {
    if (!supportato) return;
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// Notifica immediata per verificare che arrivino (anche con schermo bloccato).
  Future<void> inviaTest() async {
    final ns = NotificationService.instance;
    if (!ns.pronto) return;
    await ns.plugin.show(
      kIdBaseFarmaci - 1,
      tr('Notifica di test'),
      tr('Se vedi questo messaggio, i promemoria dei farmaci funzionano'),
      _dettagli(null),
      payload: kPayloadFarmaci,
    );
  }
}

class _Testi {
  final String titolo;
  final String corpo;
  final String? espanso;
  const _Testi(this.titolo, this.corpo, this.espanso);
}
