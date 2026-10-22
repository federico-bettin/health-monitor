import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';

/// Giorni su cui si calcola la percentuale di aderenza.
const int kGiorniAderenza = 30;

/// Giorni di storico caricati: servono alla striscia, che può essere più
/// lunga della finestra della percentuale.
const int kGiorniStoricoAderenza = 90;

/// Esito di una dose prevista.
/// [inAttesa]: non ancora registrata ma ancora nei tempi (non conta).
enum EsitoDose { presa, saltata, nonRegistrata, inAttesa }

/// Una dose prevista del piano, con il suo esito.
class DoseValutata {
  final Farmaco farmaco;
  final DateTime prevista;
  final EsitoDose esito;
  const DoseValutata(this.farmaco, this.prevista, this.esito);
}

DateTime _giorno(DateTime d) => DateTime(d.year, d.month, d.day);

/// Confronta le dosi previste dal piano con quelle registrate.
///
/// Considera le dosi in [da, a). Per ogni farmaco il conteggio parte dal
/// giorno della sua prima dose registrata: prima di allora non si sa se
/// l'app veniva usata, e non si può parlare di dosi "dimenticate". Un farmaco
/// senza nessuna dose registrata non produce dati.
///
/// Una dose non registrata diventa [EsitoDose.nonRegistrata] dopo [soglia]
/// dall'orario previsto; fino ad allora è [EsitoDose.inAttesa].
///
/// Limite noto: se si cambiano gli orari di un farmaco, le dosi passate
/// vengono ricalcolate con gli orari nuovi.
List<DoseValutata> valutaDosi({
  required Iterable<Farmaco> farmaci,
  required Iterable<AssunzioneFarmaco> assunzioni,
  required DateTime da,
  required DateTime a,
  required DateTime adesso,
  Duration soglia = kSogliaNonRegistrata,
}) {
  final registro = <String, Map<int, AssunzioneFarmaco>>{};
  final primo = <String, DateTime>{};
  for (final x in assunzioni) {
    final p = x.dataOraPrevista;
    if (p == null) continue; // le dosi "al bisogno" non hanno un piano
    (registro[x.farmacoId] ??= {})[p.millisecondsSinceEpoch] = x;
    final g = _giorno(p);
    final attuale = primo[x.farmacoId];
    if (attuale == null || g.isBefore(attuale)) primo[x.farmacoId] = g;
  }

  final out = <DoseValutata>[];
  for (final f in farmaci) {
    final inizio = primo[f.id];
    if (inizio == null) continue;
    final dal = inizio.isAfter(da) ? inizio : da;
    for (final t in generaOccorrenze(f, dal, a)) {
      final r = registro[f.id]?[t.millisecondsSinceEpoch];
      final EsitoDose esito;
      if (r != null && r.stato == StatoAssunzione.presa) {
        esito = EsitoDose.presa;
      } else if (r != null && r.stato == StatoAssunzione.saltata) {
        esito = EsitoDose.saltata;
      } else if (adesso.isAfter(t.add(soglia))) {
        esito = EsitoDose.nonRegistrata;
      } else {
        esito = EsitoDose.inAttesa;
      }
      out.add(DoseValutata(f, t, esito));
    }
  }
  out.sort((x, y) {
    final c = x.prevista.compareTo(y.prevista);
    return c != 0 ? c : x.farmaco.nome.compareTo(y.farmaco.nome);
  });
  return out;
}

/// Conteggi di aderenza. Le dosi in attesa non entrano.
class Aderenza {
  final int prese;
  final int saltate;
  final int nonRegistrate;
  const Aderenza(this.prese, this.saltate, this.nonRegistrate);

  int get valutate => prese + saltate + nonRegistrate;

  /// 0-100, oppure null se non c'è ancora nessuna dose valutabile.
  double? get percentuale => valutate == 0 ? null : prese * 100 / valutate;
}

/// Aderenza sulle [dosi] con orario non precedente a [dal] (se indicato).
Aderenza calcolaAderenza(Iterable<DoseValutata> dosi, {DateTime? dal}) {
  var prese = 0, saltate = 0, nonReg = 0;
  for (final d in dosi) {
    if (dal != null && d.prevista.isBefore(dal)) continue;
    switch (d.esito) {
      case EsitoDose.presa:
        prese++;
      case EsitoDose.saltata:
        saltate++;
      case EsitoDose.nonRegistrata:
        nonReg++;
      case EsitoDose.inAttesa:
        break;
    }
  }
  return Aderenza(prese, saltate, nonReg);
}

/// Giorni consecutivi, fino a oggi, in cui tutte le dosi previste sono state
/// prese.
///
/// - un giorno senza dosi non spezza né allunga la striscia;
/// - oggi, finché ci sono dosi ancora in attesa, non spezza e non conta;
/// - una dose saltata o non registrata spezza la striscia.
int calcolaStriscia(Iterable<DoseValutata> dosi) {
  final perGiorno = <DateTime, List<EsitoDose>>{};
  for (final d in dosi) {
    (perGiorno[_giorno(d.prevista)] ??= []).add(d.esito);
  }
  final giorni = perGiorno.keys.toList()..sort((a, b) => b.compareTo(a));

  var striscia = 0;
  for (final g in giorni) {
    final esiti = perGiorno[g]!;
    if (esiti.any((e) => e == EsitoDose.saltata || e == EsitoDose.nonRegistrata)) {
      break;
    }
    if (esiti.any((e) => e == EsitoDose.inAttesa)) continue;
    striscia++;
  }
  return striscia;
}
