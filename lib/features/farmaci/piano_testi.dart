import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';

String hhmm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Orari validi normalizzati "HH:mm", senza duplicati, in ordine.
List<String> orariValidi(Iterable<String> orari) {
  final set = <String>{};
  for (final s in orari) {
    final o = parseOrario(s);
    if (o != null) set.add(hhmm(o.h, o.m));
  }
  return set.toList()..sort();
}

const _giorniIt = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

/// Sigla del giorno (1 = lunedì … 7 = domenica).
String nomeGiorno(int d, {bool localizzato = true}) {
  final s = _giorniIt[(d - 1).clamp(0, 6)];
  return localizzato ? tr(s) : s;
}

String _t(String it, List<Object?> args, bool localizzato) {
  if (localizzato) return tr(it, args);
  var r = it;
  for (var i = 0; i < args.length; i++) {
    r = r.replaceAll('{$i}', '${args[i]}');
  }
  return r;
}

/// Descrizione della frequenza, ricavata dal piano (es. "2 volte al giorno ·
/// 08:00, 20:00", "Lun, Gio · 08:00", "Ogni 3 giorni · 09:00", "Al bisogno").
///
/// [localizzato] = true: nella lingua dell'app (per la UI).
/// [localizzato] = false: sempre in italiano (per il testo salvato nel campo
/// `frequenza`, che resta leggibile nei backup e su Drive).
/// Se il piano non ha orari validi, usa il testo libero già salvato.
String etichettaFrequenza(Farmaco f, {bool localizzato = true}) {
  final orari = orariValidi(f.orariAssunzione);
  var base = '';
  switch (f.frequenzaTipo) {
    case FrequenzaFarmaco.alBisogno:
      return _t('Al bisogno', const [], localizzato);
    case FrequenzaFarmaco.giorniSettimana:
      if (f.giorniSettimana.isEmpty) return f.frequenza;
      final g = (f.giorniSettimana.toList()..sort())
          .map((d) => nomeGiorno(d, localizzato: localizzato))
          .join(', ');
      base = g;
      break;
    case FrequenzaFarmaco.ogniNGiorni:
      base = _t('Ogni {0} giorni', [f.ogniNGiorni ?? 1], localizzato);
      break;
    case FrequenzaFarmaco.giornaliera:
      if (orari.isEmpty) {
        return f.frequenza.trim().isNotEmpty
            ? f.frequenza
            : _t('Ogni giorno', const [], localizzato);
      }
      base = orari.length == 1
          ? _t('1 volta al giorno', const [], localizzato)
          : _t('{0} volte al giorno', [orari.length], localizzato);
      break;
  }
  return orari.isEmpty ? base : '$base · ${orari.join(', ')}';
}
