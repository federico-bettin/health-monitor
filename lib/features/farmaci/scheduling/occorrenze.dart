import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:timezone/timezone.dart' as tz;

/// Finestra mobile di pianificazione (giorni di occorrenze esplicite).
const int kFinestraGiorni = 30;

/// Tetto di sicurezza di notifiche pianificate (Android/Samsung ~500 allarmi).
const int kTettoNotifiche = 400;

/// Una dose prevista e non registrata entro questo tempo è "non registrata".
const Duration kSogliaNonRegistrata = Duration(hours: 2);

/// Una notifica: un istante e i farmaci da prendere in quell'istante.
class GruppoPromemoria {
  /// Orario "del muro" (wall clock) in orario locale.
  final DateTime quando;
  final List<Farmaco> farmaci;
  const GruppoPromemoria(this.quando, this.farmaci);
}

/// Interpreta "HH:mm" (anche "H:mm"). Ritorna (ore, minuti) oppure null.
({int h, int m})? parseOrario(String s) {
  final mt = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(s);
  if (mt == null) return null;
  final h = int.parse(mt.group(1)!);
  final m = int.parse(mt.group(2)!);
  if (h > 23 || m > 59) return null;
  return (h: h, m: m);
}

/// Solo la data (UTC, senza ora): confronti tra giorni sicuri al cambio ora legale.
DateTime _giorno(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Occorrenze di [f] nell'intervallo [da, a), come orari "del muro" locali.
///
/// I giorni si scorrono per data di calendario (mai sommando 24 ore), quindi
/// l'orario 08:00 resta 08:00 anche a cavallo del cambio ora legale. La
/// conversione in un istante reale (Europe/Zurich) è in [aIstante].
///
/// Nessuna occorrenza se: archiviato, promemoria spento, "al bisogno",
/// nessun orario valido, o parametri della frequenza mancanti.
List<DateTime> generaOccorrenze(Farmaco f, DateTime da, DateTime a) {
  if (f.archiviato || !f.promemoriaAttivo) return const [];
  final tipo = f.frequenzaTipo;
  if (tipo == FrequenzaFarmaco.alBisogno) return const [];

  // Orari validi, senza duplicati, in ordine
  final orari = <int>{};
  for (final s in f.orariAssunzione) {
    final o = parseOrario(s);
    if (o != null) orari.add(o.h * 60 + o.m);
  }
  if (orari.isEmpty) return const [];
  final orariOrdinati = orari.toList()..sort();

  // Parametri della frequenza
  final giorniOk = f.giorniSettimana.toSet();
  if (tipo == FrequenzaFarmaco.giorniSettimana && giorniOk.isEmpty) {
    return const [];
  }
  final n = f.ogniNGiorni ?? 0;
  if (tipo == FrequenzaFarmaco.ogniNGiorni && (n < 1 || f.dataInizio == null)) {
    return const [];
  }

  final inizio = f.dataInizio == null ? null : _giorno(f.dataInizio!);
  final fine = f.dataFine == null ? null : _giorno(f.dataFine!);

  final risultato = <DateTime>[];
  var d = DateTime(da.year, da.month, da.day);
  while (d.isBefore(a)) {
    final g = _giorno(d);
    final dentroPeriodo =
        (inizio == null || !g.isBefore(inizio)) && (fine == null || !g.isAfter(fine));
    if (dentroPeriodo && _giornoAttivo(tipo, d, g, giorniOk, n, inizio)) {
      for (final minuti in orariOrdinati) {
        final t = DateTime(d.year, d.month, d.day, minuti ~/ 60, minuti % 60);
        if (!t.isBefore(da) && t.isBefore(a)) risultato.add(t);
      }
    }
    d = DateTime(d.year, d.month, d.day + 1); // giorno di calendario successivo
  }
  return risultato;
}

bool _giornoAttivo(FrequenzaFarmaco tipo, DateTime d, DateTime g,
    Set<int> giorniOk, int n, DateTime? inizio) {
  switch (tipo) {
    case FrequenzaFarmaco.giornaliera:
      return true;
    case FrequenzaFarmaco.giorniSettimana:
      return giorniOk.contains(d.weekday);
    case FrequenzaFarmaco.ogniNGiorni:
      return g.difference(inizio!).inDays % n == 0;
    case FrequenzaFarmaco.alBisogno:
      return false;
  }
}

/// Una notifica per ogni istante distinto, con i farmaci da prendere.
/// Ordinata per orario; i farmaci di un gruppo sono ordinati per nome.
List<GruppoPromemoria> raggruppaPerOrario(
    Iterable<Farmaco> farmaci, DateTime da, DateTime a) {
  final mappa = <DateTime, List<Farmaco>>{};
  for (final f in farmaci) {
    for (final t in generaOccorrenze(f, da, a)) {
      mappa.putIfAbsent(t, () => []).add(f);
    }
  }
  final orari = mappa.keys.toList()..sort();
  return [
    for (final t in orari)
      GruppoPromemoria(
        t,
        (mappa[t]!..sort((x, y) => x.nome.toLowerCase().compareTo(y.nome.toLowerCase()))),
      ),
  ];
}

/// Applica il tetto di sicurezza: tiene le prime [tetto] notifiche in ordine
/// cronologico (la lista in ingresso deve essere già ordinata).
List<GruppoPromemoria> limitaAlTetto(List<GruppoPromemoria> gruppi,
    [int tetto = kTettoNotifiche]) {
  if (gruppi.length <= tetto) return gruppi;
  return gruppi.sublist(0, tetto);
}

/// Converte un orario "del muro" in un istante reale nel fuso [loc]
/// (es. Europe/Zurich), mantenendo ora e minuti. Un orario inesistente
/// (salto dell'ora legale) viene spostato in avanti, non scartato.
tz.TZDateTime aIstante(DateTime muro, tz.Location loc) => tz.TZDateTime(
    loc, muro.year, muro.month, muro.day, muro.hour, muro.minute);
