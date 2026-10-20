import 'dart:math';

import 'package:salute_bettin/data/services/claude_service.dart' show SaluteAnalysis;

/// Calcolo DETERMINISTICO dell'Health Score (1–10).
///
/// Stessi dati in ingresso → stesso punteggio, sempre. Non usa l'AI né la rete.
/// L'AI (se disponibile) serve solo a spiegare il punteggio a parole.
///
/// Rubrica (si parte da 10):
///   BMI 25–29.9: -0.5 | 30–34.9: -1.5 | ≥35: -2.5
///   Esami (ogni valore fuori range, ultimo esame per tipo):
///     scostamento ≤10%: -0.5 (max -2) | 11–30%: -1.0 (max -2) | >30%: -1.5 (max -3)
///     totale esami limitato a -3
///   Fumo 1–10: -1.0 | 11–20: -1.5 | >20: -2.0
///   Alcool 1–2 bicchieri: -0.5 | >2: -1.5
///   Passi <3000: -1.0 | 3000–5999: -0.5 | ≥8000: +0.5
///   Sonno <5h: -1.5 | 5–5.9h: -0.5 | >9h (adulti <65): -0.5
///   Patologie croniche serie: -1.0 ciascuna (max -2.5)
///   Risultato arrotondato all'intero, minimo 1, massimo 10.
class ScoreT {
  ScoreT._();
  static const bmiSovrappeso = 'BMI {0}: sovrappeso';
  static const bmiObesita1 = 'BMI {0}: obesità di grado I';
  static const bmiObesita2 = 'BMI {0}: obesità di grado II-III';
  static const bmiNorma = 'BMI {0}: nella norma';
  static const fuoriRange =
      'Fuori range: {0} = {1} (riferimento {2}, scostamento {3}%)';
  static const esamiOk = 'Tutti i valori degli ultimi esami sono nel range';
  static const fuma = 'Fuma {0} sigarette al giorno';
  static const nonFuma = 'Non fuma';
  static const alcool = 'Alcool: {0} bicchieri di vino al giorno';
  static const passiPochi = 'Pochi passi: {0} al giorno';
  static const passiNorma = 'Attività nella norma: {0} passi al giorno';
  static const passiBuoni = 'Molto attivo: {0} passi al giorno';
  static const sonnoPoco = 'Sonno insufficiente: {0} ore a notte';
  static const sonnoTanto = 'Sonno eccessivo: {0} ore a notte';
  static const sonnoOk = 'Sonno regolare: {0} ore a notte';
  static const patologia = 'Patologia cronica rilevante: {0}';

  static const titolo10 = 'Salute eccellente';
  static const titolo8 = 'Buona salute';
  static const titolo6 = 'Salute discreta';
  static const titolo4 = 'Da migliorare';
  static const titolo2 = 'Attenzione';

  static const sommarioSenzaChiave =
      "Punteggio calcolato dall'app in base a BMI, stile di vita, ultimi esami e patologie croniche. "
      "Per il confronto con la media italiana e i consigli personalizzati inserisci la chiave API Claude in Impostazioni.";
  static const sommarioErroreAi =
      "Punteggio calcolato dall'app in base a BMI, stile di vita, ultimi esami e patologie croniche. "
      "L'analisi AI non è disponibile al momento: riprova più tardi con il pulsante di aggiornamento.";

  static const migEsami =
      'Parla con il medico dei valori fuori range e ripeti gli esami come indicato';
  static const migFumo =
      'Smetti di fumare o riduci le sigarette: è il fattore che pesa di più sulla salute';
  static const migAlcool = 'Riduci il consumo di alcolici';
  static const migPassi =
      'Aumenta gradualmente i passi giornalieri fino a circa 8.000';
  static const migSonno = 'Cura il sonno: punta a 7-8 ore regolari per notte';
  static const migBmi =
      'Mantieni un peso sano con alimentazione equilibrata e movimento regolare';
  static const migPatologie =
      'Segui con regolarità le cure e i controlli specialistici per le patologie croniche';
  static const migGen1 = 'Fai i controlli periodici consigliati dal tuo medico';
  static const migGen2 = 'Mantieni uno stile di vita attivo ed equilibrato';
  static const migGen3 = 'Dormi a sufficienza e gestisci lo stress';
}

String _t(String tpl, List<Object?> args) {
  var s = tpl;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '.');
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!);
}

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class FattoreScore {
  /// bmi, esami, fumo, alcool, passi, sonno, patologie
  final String categoria;

  /// Punti nominali: negativo = penalità, positivo = bonus.
  final double punti;
  final String testo;

  /// True = da mostrare tra i punti di forza.
  final bool positivo;

  /// Scostamento % (solo per i valori degli esami), per ordinare.
  final double scostamento;

  const FattoreScore(this.categoria, this.punti, this.testo,
      {this.positivo = false, this.scostamento = 0});

  Map<String, dynamic> toJson() =>
      {'categoria': categoria, 'punti': punti, 'testo': testo};
}

class RisultatoScore {
  /// Valore prima dell'arrotondamento (es. 8.5).
  final double grezzo;

  /// Punteggio finale 1–10.
  final int score;
  final List<FattoreScore> fattori;
  const RisultatoScore(this.grezzo, this.score, this.fattori);
}

final _patologieSerie = RegExp(
    r'diabet|ischemic|infarto|insufficienza renale|bpco|neoplasi|tumor|cancro|\bhiv\b',
    caseSensitive: false);

/// [dati] = la stessa mappa che l'app prepara per l'analisi (vedi dashboard).
RisultatoScore calcolaScore(Map<String, dynamic> dati) {
  final fattori = <FattoreScore>[];
  var totale = 10.0;

  // ── BMI ────────────────────────────────────────────────
  final bmi = _num(dati['bmi']);
  if (bmi != null) {
    if (bmi >= 35) {
      totale -= 2.5;
      fattori.add(FattoreScore(
          'bmi', -2.5, _t(ScoreT.bmiObesita2, [_n(bmi)])));
    } else if (bmi >= 30) {
      totale -= 1.5;
      fattori.add(FattoreScore(
          'bmi', -1.5, _t(ScoreT.bmiObesita1, [_n(bmi)])));
    } else if (bmi >= 25) {
      totale -= 0.5;
      fattori.add(FattoreScore(
          'bmi', -0.5, _t(ScoreT.bmiSovrappeso, [_n(bmi)])));
    } else if (bmi >= 18.5) {
      fattori.add(FattoreScore('bmi', 0, _t(ScoreT.bmiNorma, [_n(bmi)]),
          positivo: true));
    }
  }

  // ── Esami (ultimo per tipo) ────────────────────────────
  var nA = 0, nB = 0, nC = 0, valoriTotali = 0;
  final fuoriRange = <FattoreScore>[];
  final esami = dati['ultimi_esami_per_tipo'];
  if (esami is List) {
    for (final e in esami) {
      if (e is! Map) continue;
      final valori = e['valori'];
      if (valori is! List) continue;
      for (final v in valori) {
        if (v is! Map) continue;
        final val = _num(v['valore']);
        if (val == null) continue;
        valoriTotali++;
        final mn = _num(v['riferimentoMin']);
        final mx = _num(v['riferimentoMax']);
        double? dev;
        if (mn != null && val < mn) {
          dev = (mn - val).abs() / (mn == 0 ? 1 : mn.abs()) * 100;
        } else if (mx != null && val > mx) {
          dev = (val - mx).abs() / (mx == 0 ? 1 : mx.abs()) * 100;
        } else if (mn == null && mx == null && v['fuoriRange'] == true) {
          dev = 10; // segnalato fuori range ma senza intervallo di riferimento
        }
        if (dev == null) continue;

        double p;
        if (dev <= 10) {
          nA++;
          p = -0.5;
        } else if (dev <= 30) {
          nB++;
          p = -1.0;
        } else {
          nC++;
          p = -1.5;
        }
        final rMin = v['riferimentoMin'];
        final rMax = v['riferimentoMax'];
        final rif = (rMin != null && rMax != null)
            ? '$rMin–$rMax'
            : rMax != null
                ? '<$rMax'
                : rMin != null
                    ? '>$rMin'
                    : '-';
        fuoriRange.add(FattoreScore(
            'esami',
            p,
            _t(ScoreT.fuoriRange, [
              v['nome'] ?? '',
              '${v['valore'] ?? ''} ${v['unita'] ?? ''}'.trim(),
              rif,
              dev.round(),
            ]),
            scostamento: dev));
      }
    }
  }
  final penEsami =
      min(3.0, min(2.0, nA * 0.5) + min(2.0, nB * 1.0) + min(3.0, nC * 1.5));
  totale -= penEsami;
  fuoriRange.sort((a, b) => b.scostamento.compareTo(a.scostamento));
  fattori.addAll(fuoriRange);
  if (valoriTotali > 0 && fuoriRange.isEmpty) {
    fattori.add(const FattoreScore('esami', 0, ScoreT.esamiOk, positivo: true));
  }

  // ── Stile di vita ──────────────────────────────────────
  final stile = dati['stile_vita'];
  if (stile is Map) {
    // Fumo
    if (stile['fumo'] == true) {
      final sig = (_num(stile['sigarette_giorno']) ?? 10).round();
      final p = sig > 20 ? -2.0 : (sig > 10 ? -1.5 : -1.0);
      totale += p;
      fattori.add(FattoreScore('fumo', p, _t(ScoreT.fuma, [sig])));
    } else {
      fattori.add(const FattoreScore('fumo', 0, ScoreT.nonFuma, positivo: true));
    }
    // Alcool
    if (stile['alcool'] == true) {
      final b = (_num(stile['bicchieri_vino_giorno']) ?? 1).round();
      if (b >= 1) {
        final p = b > 2 ? -1.5 : -0.5;
        totale += p;
        fattori.add(FattoreScore('alcool', p, _t(ScoreT.alcool, [b])));
      }
    }
    // Passi
    final passi = _num(stile['passi_giorno']);
    if (passi != null && passi > 0) {
      final pr = passi.round();
      if (passi < 3000) {
        totale -= 1.0;
        fattori.add(FattoreScore('passi', -1.0, _t(ScoreT.passiPochi, [pr])));
      } else if (passi < 6000) {
        totale -= 0.5;
        fattori.add(FattoreScore('passi', -0.5, _t(ScoreT.passiPochi, [pr])));
      } else if (passi >= 8000) {
        totale += 0.5;
        fattori.add(FattoreScore('passi', 0.5, _t(ScoreT.passiBuoni, [pr]),
            positivo: true));
      } else {
        fattori.add(FattoreScore('passi', 0, _t(ScoreT.passiNorma, [pr]),
            positivo: true));
      }
    }
  }

  // ── Sonno (solo se disponibile) ────────────────────────
  final sonno = _num(dati['sonno_ore_notte']);
  if (sonno != null && sonno > 0) {
    final eta = _num(dati['eta']);
    final adultoUnder65 = eta == null || eta < 65;
    if (sonno < 5.0) {
      totale -= 1.5;
      fattori.add(FattoreScore('sonno', -1.5, _t(ScoreT.sonnoPoco, [_n(sonno)])));
    } else if (sonno < 6.0) {
      totale -= 0.5;
      fattori.add(FattoreScore('sonno', -0.5, _t(ScoreT.sonnoPoco, [_n(sonno)])));
    } else if (sonno > 9.0 && adultoUnder65) {
      totale -= 0.5;
      fattori.add(FattoreScore('sonno', -0.5, _t(ScoreT.sonnoTanto, [_n(sonno)])));
    } else {
      fattori.add(FattoreScore('sonno', 0, _t(ScoreT.sonnoOk, [_n(sonno)]),
          positivo: true));
    }
  }

  // ── Patologie croniche serie ───────────────────────────
  var penPat = 0.0;
  final pat = dati['patologie_croniche'];
  if (pat is List) {
    for (final p in pat) {
      final nome = '$p';
      if (_patologieSerie.hasMatch(nome) && penPat < 2.5) {
        penPat = min(2.5, penPat + 1.0);
        fattori.add(FattoreScore('patologie', -1.0, _t(ScoreT.patologia, [nome])));
      }
    }
  }
  totale -= penPat;

  final score = max(1, min(10, totale.round()));
  return RisultatoScore(totale, score, fattori);
}

String _titolo(int s) => s >= 9
    ? ScoreT.titolo10
    : s >= 7
        ? ScoreT.titolo8
        : s >= 5
            ? ScoreT.titolo6
            : s >= 3
                ? ScoreT.titolo4
                : ScoreT.titolo2;

/// Spiegazione "a parole" costruita dal codice, senza AI (testi in italiano:
/// l'interfaccia li traduce in inglese da sola).
SaluteAnalysis analisiLocale(RisultatoScore r, {required bool conChiave}) {
  final forza = r.fattori.where((f) => f.positivo).map((f) => f.testo).take(3).toList();

  final negativi = r.fattori.where((f) => f.punti < 0).toList()
    ..sort((a, b) => a.punti.compareTo(b.punti));
  final aree = negativi.map((f) => f.testo).take(3).toList();

  // Miglioramenti: una voce per categoria, dalla penalità più pesante
  final perCat = <String, double>{};
  for (final f in negativi) {
    perCat[f.categoria] = (perCat[f.categoria] ?? 0) + f.punti;
  }
  final ordine = perCat.keys.toList()
    ..sort((a, b) => perCat[a]!.compareTo(perCat[b]!));
  const mappa = {
    'esami': ScoreT.migEsami,
    'fumo': ScoreT.migFumo,
    'alcool': ScoreT.migAlcool,
    'passi': ScoreT.migPassi,
    'sonno': ScoreT.migSonno,
    'bmi': ScoreT.migBmi,
    'patologie': ScoreT.migPatologie,
  };
  final mig = <String>[for (final c in ordine) mappa[c]!];
  for (final g in const [ScoreT.migGen1, ScoreT.migGen2, ScoreT.migGen3]) {
    if (mig.length >= 3) break;
    mig.add(g);
  }

  return SaluteAnalysis(
    score: r.score,
    titolo: _titolo(r.score),
    sommario:
        conChiave ? ScoreT.sommarioErroreAi : ScoreT.sommarioSenzaChiave,
    benchmark: '',
    puntiForza: forza,
    areeAttenzione: aree,
    miglioramenti: mig.take(3).toList(),
    esamiDaFare: const [],
  );
}
