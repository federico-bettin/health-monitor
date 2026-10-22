import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';

/// Avviso quando le scorte bastano per meno di questi giorni (se non indicato).
const int kSogliaScorteGiorniDefault = 7;

/// Quanto in avanti si simulano le dosi per stimare la fine delle scorte.
const int kOrizzonteScorteGiorni = 120;

/// Unità consumate a ogni assunzione (almeno > 0, altrimenti 1).
double unitaPerDoseDi(Farmaco f) {
  final u = f.unitaPerDose;
  return (u != null && u > 0) ? u : 1.0;
}

int sogliaScorteDi(Farmaco f) {
  final s = f.sogliaScorteGiorni;
  return (s != null && s >= 0) ? s : kSogliaScorteGiorniDefault;
}

/// Numero senza decimali inutili: 30, 2.5.
String formattaUnita(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Situazione delle scorte di un farmaco.
class StatoScorte {
  final double unita;
  final double unitaDose;
  final int soglia;

  /// True se il farmaco ha un piano con promemoria: allora si stimano i giorni.
  final bool conPiano;

  /// Giorni da oggi alla prima dose che le scorte non coprono (0 = oggi).
  /// Null: le scorte bastano fino a fine terapia o oltre l'orizzonte.
  final int? giorni;

  const StatoScorte(
      this.unita, this.unitaDose, this.soglia, this.conPiano, this.giorni);

  /// Da segnalare. Con piano: scorte per meno di [soglia] giorni.
  /// Senza piano (al bisogno): non basta più per una dose.
  bool get inAvviso => conPiano
      ? (giorni != null && giorni! <= soglia)
      : unita + 1e-9 < unitaDose;
}

/// Stato delle scorte di [f] a [adesso]. Null se non sono tracciate.
///
/// Conta le dosi previste dal piano da [adesso] in poi. Una dose di oggi
/// presa in anticipo resta contata: la stima può sbagliare di una dose.
StatoScorte? statoScorte(Farmaco f, DateTime adesso) {
  final scorte = f.scorte;
  if (scorte == null || f.archiviato) return null;
  final u = unitaPerDoseDi(f);
  final conPiano =
      f.promemoriaAttivo && f.frequenzaTipo != FrequenzaFarmaco.alBisogno;

  int? giorni;
  if (conPiano) {
    final fine =
        DateTime(adesso.year, adesso.month, adesso.day + kOrizzonteScorteGiorni);
    final oggi = DateTime.utc(adesso.year, adesso.month, adesso.day);
    var rimaste = scorte;
    for (final t in generaOccorrenze(f, adesso, fine)) {
      if (rimaste + 1e-9 < u) {
        giorni = DateTime.utc(t.year, t.month, t.day).difference(oggi).inDays;
        break;
      }
      rimaste -= u;
    }
  }
  return StatoScorte(scorte, u, sogliaScorteDi(f), conPiano, giorni);
}
