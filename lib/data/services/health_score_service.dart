import 'package:salute_bettin/core/health_score.dart';
import 'package:salute_bettin/data/services/claude_service.dart';

/// Costruisce l'analisi della salute:
///  - il PUNTEGGIO è sempre calcolato dal codice (deterministico, offline);
///  - la spiegazione a parole la scrive Claude se c'è la chiave API,
///    altrimenti (o se la chiamata fallisce) la costruisce il codice.
///
/// [salva] = true se il risultato va messo in cache (analisi AI completa o
/// analisi locale senza chiave); false se l'AI ha fallito e conviene riprovare.
Future<({SaluteAnalysis analisi, bool salva, bool aiFallita})> costruisciAnalisi(
    Map<String, dynamic> dati) async {
  final calc = calcolaScore(dati);

  if (!ClaudeService.chiaveConfigurata) {
    return (
      analisi: analisiLocale(calc, conChiave: false),
      salva: true,
      aiFallita: false
    );
  }
  try {
    final a = await ClaudeService().analizzaSalute(
      datiSalute: dati,
      scoreCalcolato: calc.score,
      fattoriScore: calc.fattori.map((f) => f.toJson()).toList(),
    );
    return (analisi: a, salva: true, aiFallita: false);
  } catch (_) {
    return (
      analisi: analisiLocale(calc, conChiave: true),
      salva: false,
      aiFallita: true
    );
  }
}
