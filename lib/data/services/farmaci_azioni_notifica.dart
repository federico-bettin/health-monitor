import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Azioni sulla notifica dei promemoria farmaci: "Preso" e "Posticipa".
///
/// Perché una coda: il tocco su un'azione, con l'app chiusa, gira in un
/// isolate separato, e Hive non si può aprire da due isolate insieme.
/// L'azione "Preso" quindi si limita a scrivere una voce in SharedPreferences
/// (una chiave per voce, nessuna lettura-modifica-scrittura condivisa);
/// l'app la trasforma in assunzione al successivo avvio o ritorno in primo
/// piano ([FarmaciAzioni.applicaCoda]).

const String kAzionePreso = 'preso';
const String kAzionePosticipa = 'posticipa';

/// Minuti di posticipo.
const int kPosticipaMinuti = 10;

/// Le notifiche posticipate usano ID da qui in poi, così la ricostruzione del
/// piano (che cancella gli ID tra [kIdBaseFarmaci] e questo) non le tocca.
const int kIdBaseSnooze = 1200000000;

const String kCanaleFarmaciId = 'promemoria_farmaci';
const String kCanaleFarmaciNome = 'Promemoria farmaci';

const String _kPrefissoPayload = 'farmaci:';
const String _kPrefissoCoda = 'farmaci_coda_';

/// True se il payload è di una notifica dei promemoria farmaci
/// (anche del formato vecchio, senza dati).
bool ePayloadFarmaci(String? p) =>
    p != null && (p == 'farmaci' || p.startsWith(_kPrefissoPayload));

/// ID stabile di una dose prevista (farmaco + istante). Evita doppioni.
String idDosePrevista(String farmacoId, DateTime prevista) =>
    '${farmacoId}_${prevista.millisecondsSinceEpoch}';

/// ID della notifica posticipata per l'istante previsto [previstaMs].
int idSnooze(int previstaMs) => kIdBaseSnooze + (previstaMs ~/ 60000) % 1000000;

/// Dati che la notifica porta con sé. Contiene anche i testi: serve per
/// ricreare la notifica quando si posticipa, anche ad app chiusa.
class PayloadFarmaci {
  final int previstaMs;
  final List<String> farmacoIds;
  final String titolo;
  final String corpo;
  final String? espanso;
  final String lPreso;
  final String lPosticipa;

  const PayloadFarmaci({
    required this.previstaMs,
    required this.farmacoIds,
    required this.titolo,
    required this.corpo,
    this.espanso,
    required this.lPreso,
    required this.lPosticipa,
  });

  String codifica() => _kPrefissoPayload +
      jsonEncode({
        'p': previstaMs,
        'f': farmacoIds,
        't': titolo,
        'c': corpo,
        if (espanso != null) 'e': espanso,
        'l1': lPreso,
        'l2': lPosticipa,
      });

  /// Null se il payload è vecchio, assente o non valido.
  static PayloadFarmaci? decodifica(String? payload) {
    if (payload == null || !payload.startsWith(_kPrefissoPayload)) return null;
    try {
      final m = jsonDecode(payload.substring(_kPrefissoPayload.length))
          as Map<String, dynamic>;
      return PayloadFarmaci(
        previstaMs: (m['p'] as num).toInt(),
        farmacoIds: (m['f'] as List).cast<String>(),
        titolo: m['t'] as String,
        corpo: m['c'] as String,
        espanso: m['e'] as String?,
        lPreso: (m['l1'] as String?) ?? 'Preso',
        lPosticipa: (m['l2'] as String?) ?? 'Posticipa',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Aspetto delle notifiche dei farmaci. Con [payload] aggiunge i pulsanti.
NotificationDetails dettagliFarmaci({String? espanso, PayloadFarmaci? payload}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        kCanaleFarmaciId,
        kCanaleFarmaciNome,
        channelDescription: 'Promemoria per l\'assunzione dei farmaci',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation:
            espanso == null ? null : BigTextStyleInformation(espanso),
        actions: payload == null
            ? null
            : [
                AndroidNotificationAction(kAzionePreso, payload.lPreso),
                AndroidNotificationAction(kAzionePosticipa, payload.lPosticipa),
              ],
      ),
    );

/// Entry point per i tocchi sui pulsanti con l'app chiusa (isolate separato).
@pragma('vm:entry-point')
Future<void> farmaciNotificaInBackground(NotificationResponse r) async {
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));
    await gestisciAzioneFarmaci(r, plugin);
  } catch (e) {
    debugPrint('Azione notifica farmaci fallita: $e');
  }
}

/// Esegue "Preso" o "Posticipa". Con l'app aperta [plugin] è quello
/// dell'app; in background è quello creato dall'entry point.
Future<void> gestisciAzioneFarmaci(
    NotificationResponse r, FlutterLocalNotificationsPlugin plugin) async {
  final p = PayloadFarmaci.decodifica(r.payload);
  if (p == null) return;
  switch (r.actionId) {
    case kAzionePreso:
      final prefs = await SharedPreferences.getInstance();
      final adesso = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(
        '$_kPrefissoCoda${p.previstaMs}_$adesso',
        jsonEncode({'p': p.previstaMs, 'f': p.farmacoIds, 'r': adesso}),
      );
      // Se c'era un posticipo in attesa per questa dose, non serve più
      await plugin.cancel(idSnooze(p.previstaMs));
    case kAzionePosticipa:
      await _posticipa(plugin, p);
  }
}

Future<void> _posticipa(
    FlutterLocalNotificationsPlugin plugin, PayloadFarmaci p) async {
  final quando = tz.TZDateTime.now(tz.local)
      .add(const Duration(minutes: kPosticipaMinuti));
  var esatti = false;
  try {
    esatti = await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
  } catch (_) {}

  Future<void> prog(AndroidScheduleMode modo) => plugin.zonedSchedule(
        idSnooze(p.previstaMs),
        p.titolo,
        p.corpo,
        quando,
        dettagliFarmaci(espanso: p.espanso, payload: p),
        androidScheduleMode: modo,
        payload: p.codifica(),
      );

  try {
    await prog(esatti
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle);
  } on PlatformException {
    await prog(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}

/// Applica le azioni "Preso" arrivate dalle notifiche.
class FarmaciAzioni {
  FarmaciAzioni._();

  /// Aumenta quando la coda ha registrato qualcosa: le schermate si aggiornano.
  static final ValueNotifier<int> versione = ValueNotifier<int>(0);

  static bool _inCorso = false;

  /// Chiamata per ogni dose registrata dalla coda (la imposta main per
  /// aggiornare le scorte). Un'eccezione qui non ferma la coda.
  static Future<void> Function(String farmacoId)? perOgniDosePresa;

  /// Trasforma le voci in coda in assunzioni (stato "presa", origine
  /// "notifica"). Sicura da richiamare più volte: non crea doppioni e
  /// ignora i farmaci nel frattempo eliminati o archiviati.
  /// Ritorna quante assunzioni ha registrato.
  static Future<int> applicaCoda() async {
    if (_inCorso) return 0;
    _inCorso = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Le scritture dell'isolate in background non sono nella cache
      await prefs.reload();
      final chiavi =
          prefs.getKeys().where((k) => k.startsWith(_kPrefissoCoda)).toList();
      if (chiavi.isEmpty) return 0;

      final repo = LocalRepository();
      await repo.init();
      final attivi = (await repo.getFarmaci())
          .where((f) => !f.archiviato)
          .map((f) => f.id)
          .toSet();

      var registrate = 0;
      for (final k in chiavi) {
        try {
          final m = jsonDecode(prefs.getString(k) ?? '{}') as Map<String, dynamic>;
          final prevista =
              DateTime.fromMillisecondsSinceEpoch((m['p'] as num).toInt());
          final reg =
              DateTime.fromMillisecondsSinceEpoch((m['r'] as num).toInt());
          final esistenti = await repo.getAssunzioni(
              prevista, prevista.add(const Duration(minutes: 1)));
          for (final fid in (m['f'] as List).cast<String>()) {
            if (!attivi.contains(fid)) continue;
            final id = idDosePrevista(fid, prevista);
            // Già registrata (a mano nell'app, o da un altro tocco): non toccare
            if (esistenti.any((a) => a.id == id)) continue;
            await repo.saveAssunzione(AssunzioneFarmaco(
              id: id,
              farmacoId: fid,
              dataOraPrevista: prevista,
              dataOraRegistrata: reg,
              statoIdx: StatoAssunzione.presa.index,
              origineIdx: OrigineAssunzione.notifica.index,
            ));
            registrate++;
            try {
              await perOgniDosePresa?.call(fid);
            } catch (e) {
              debugPrint('Aggiornamento dopo dose presa fallito: $e');
            }
          }
        } catch (e) {
          debugPrint('Voce della coda farmaci non valida: $e');
        }
        await prefs.remove(k);
      }
      if (registrate > 0) versione.value++;
      return registrate;
    } catch (e) {
      debugPrint('Coda azioni farmaci fallita: $e');
      return 0;
    } finally {
      _inCorso = false;
    }
  }
}

/// Applica la coda ogni volta che l'app torna in primo piano.
class OsservatoreCodaFarmaci with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) FarmaciAzioni.applicaCoda();
  }
}
