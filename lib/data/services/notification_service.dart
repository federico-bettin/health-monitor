import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salute_bettin/core/format.dart';
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Promemoria per visite ed esami.
/// Comportamento unico per tutti, impostabile in Impostazioni:
/// N giorni prima (default 3) all'ora scelta (default 9:00).
/// Solo Android; su altre piattaforme non fa nulla.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'promemoria_appuntamenti';
  static const _channelName = 'Promemoria visite ed esami';

  bool get _supportato =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_ready || !_supportato) return;
    tzdata.initializeTimeZones();
    // Fuso orario fisso: Svizzera/Italia (CET/CEST)
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Chiede il permesso notifiche (Android 13+). Ritorna true se concesso.
  Future<bool> richiediPermesso() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// ID numerico stabile (FNV-1a) a partire dall'id dell'appuntamento.
  int _idPer(String id) {
    var h = 0x811C9DC5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  Future<void> annulla(String idAppuntamento) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_idPer(idAppuntamento));
    } catch (_) {}
  }

  /// (Ri)programma la notifica di un appuntamento secondo le impostazioni.
  Future<void> pianifica(Appuntamento a) async {
    if (!_ready) return;
    try {
      final id = _idPer(a.id);
      await _plugin.cancel(id);

      final s = SettingsService.instance;
      if (!s.notifAttive || !a.promemoria) return;
      if (a.tipo != TipoAppuntamento.esame &&
          a.tipo != TipoAppuntamento.visita) {
        return;
      }

      final n = s.notifGiorniPrima;
      final ora = s.notifOraMinuti ~/ 60;
      final min = s.notifOraMinuti % 60;
      final giorno = DateTime(a.data.year, a.data.month, a.data.day - n);
      final quando = tz.TZDateTime(
          tz.local, giorno.year, giorno.month, giorno.day, ora, min);
      if (!quando.isAfter(tz.TZDateTime.now(tz.local))) return; // già passata

      final quanto = n == 0
          ? tr('oggi')
          : n == 1
              ? tr('domani')
              : tr('tra {0} giorni', [n]);
      final tipo = a.tipo == TipoAppuntamento.esame ? tr('Esame') : tr('Visita');
      final dettagli = StringBuffer('${a.titolo} · ${formatData(a.data)}');
      if (a.ora != null && a.ora!.isNotEmpty) dettagli.write(tr(' alle {0}', [a.ora]));
      if (a.struttura != null && a.struttura!.isNotEmpty) {
        dettagli.write(' · ${a.struttura}');
      }

      await _plugin.zonedSchedule(
        id,
        '$tipo $quanto',
        dettagli.toString(),
        quando,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Promemoria prima di visite ed esami',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        // Inesatto: non richiede il permesso "sveglie esatte"; può ritardare di qualche minuto
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notifica non programmata: $e');
    }
  }

  /// Rimuove tutto e riprogramma da zero (avvio app, cambio impostazioni).
  Future<void> rischedulaTutti() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final repo = LocalRepository();
      await repo.init();
      for (final a in await repo.getAppuntamenti()) {
        await pianifica(a);
      }
    } catch (e) {
      debugPrint('Riprogrammazione notifiche fallita: $e');
    }
  }
}
