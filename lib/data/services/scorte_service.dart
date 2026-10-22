import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/farmaci/scheduling/scorte.dart';

/// Le notifiche di scorte in esaurimento usano ID da qui in poi
/// (sopra i posticipi, sotto il promemoria di rinnovo).
const int kIdBaseScorte = 1250000000;

/// Testo dell'avviso scorte per [f]; usato dalla notifica e dalla schermata Oggi.
String testoAvvisoScorte(Farmaco f, StatoScorte s) {
  if (!s.conPiano || s.giorni == 0) {
    return tr('{0}: scorte finite', [f.nome]);
  }
  return tr('{0}: scorte per circa {1} giorni ({2} rimaste)',
      [f.nome, s.giorni, formattaUnita(s.unita)]);
}

/// ID stabile (FNV-1a) a partire dall'id del farmaco.
int _idStabile(String id) {
  var h = 0x811C9DC5;
  for (final c in id.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7FFFFFFF;
  }
  return h & 0xFFFFF; // 0 .. 1.048.575
}

/// Aggiorna le scorte quando una dose viene presa o annullata.
class ScorteService {
  ScorteService._();

  /// [dosi] > 0: dosi prese (le scorte scendono); [dosi] < 0: dosi annullate
  /// (le scorte tornano su). Non fa nulla se le scorte non sono tracciate.
  /// Se le scorte scendono sotto la soglia di avviso, mostra una notifica.
  static Future<void> applica(String farmacoId, double dosi) async {
    if (dosi == 0) return;
    try {
      final repo = LocalRepository();
      await repo.init();
      final f = await repo.getFarmaco(farmacoId);
      if (f == null || f.scorte == null) return;

      final adesso = DateTime.now();
      final prima = statoScorte(f, adesso)?.inAvviso ?? false;

      f.scorte = math.max(0.0, f.scorte! - dosi * unitaPerDoseDi(f));
      f.updatedAt = adesso;
      // Il piano delle notifiche non cambia: niente ricostruzione
      await repo.saveFarmaco(f, ricostruisciPromemoria: false);

      final dopo = statoScorte(f, adesso);
      if (dosi > 0 && !prima && dopo != null && dopo.inAvviso) {
        await _notifica(f, dopo);
      }
    } catch (e) {
      debugPrint('Aggiornamento scorte fallito: $e');
    }
  }

  static Future<void> _notifica(Farmaco f, StatoScorte s) async {
    final ns = NotificationService.instance;
    if (!ns.pronto || !SettingsService.instance.farmaciNotifAttive) return;
    await ns.plugin.show(
      kIdBaseScorte + _idStabile(f.id),
      tr('Scorte in esaurimento'),
      testoAvvisoScorte(f, s),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          // Stesso canale dei promemoria farmaci
          'promemoria_farmaci',
          'Promemoria farmaci',
          channelDescription: 'Promemoria per l\'assunzione dei farmaci',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: kPayloadFarmaci,
    );
  }
}
