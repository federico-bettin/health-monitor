import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/core/health_score.dart';

Map<String, dynamic> _base({
  double? bmi = 22,
  bool fumo = false,
  int? sigarette,
  bool alcool = false,
  int? bicchieri,
  int? passi,
  double? sonno,
  List<Map<String, dynamic>> valori = const [],
  List<String> patologie = const [],
}) =>
    {
      'eta': 45,
      'bmi': bmi,
      'patologie_croniche': patologie,
      'stile_vita': {
        'fumo': fumo,
        'sigarette_giorno': sigarette,
        'alcool': alcool,
        'bicchieri_vino_giorno': bicchieri,
        'passi_giorno': passi,
      },
      if (sonno != null) 'sonno_ore_notte': sonno,
      'ultimi_esami_per_tipo': [
        {'tipo': 'Test', 'valori': valori}
      ],
    };

Map<String, dynamic> _v(String nome, String valore,
        {String? min, String? max}) =>
    {
      'nome': nome,
      'valore': valore,
      'unita': 'u',
      'riferimentoMin': min,
      'riferimentoMax': max,
      'fuoriRange': false,
    };

void main() {
  test('persona sana e attiva: 10 (bonus passi, massimo 10)', () {
    final r = calcolaScore(_base(passi: 9000));
    expect(r.score, 10);
  });

  test('stessi dati = stesso punteggio', () {
    final d = _base(bmi: 31, fumo: true, sigarette: 15, passi: 2000);
    expect(calcolaScore(d).score, calcolaScore(d).score);
    expect(calcolaScore(d).grezzo, calcolaScore(d).grezzo);
  });

  test('penalità combinate: BMI 31, 15 sigarette, 2000 passi, sonno 4.5h', () {
    // 10 -1.5 -1.5 -1.0 -1.5 = 4.5 -> arrotondato a 5
    final r = calcolaScore(
        _base(bmi: 31, fumo: true, sigarette: 15, passi: 2000, sonno: 4.5));
    expect(r.grezzo, 4.5);
    expect(r.score, 5);
  });

  test('valore lievemente fuori range (≤10%) + sovrappeso', () {
    // LDL 142 vs max 130 = +9.2% -> -0.5 ; BMI 26 -> -0.5 ; totale 9
    final r = calcolaScore(
        _base(bmi: 26, valori: [_v('LDL', '142', max: '130')]));
    expect(r.grezzo, 9.0);
    expect(r.score, 9);
  });

  test('penalità esami limitata a -3', () {
    final valori = [for (var i = 0; i < 5; i++) _v('V$i', '200', max: '100')];
    final r = calcolaScore(_base(valori: valori));
    expect(r.grezzo, 7.0);
  });

  test('patologie serie: -1 ciascuna, ipertensione lieve non conta', () {
    final r = calcolaScore(
        _base(patologie: ['Diabete tipo 2', 'Ipertensione lieve']));
    expect(r.grezzo, 9.0);
  });

  test('punteggio minimo 1', () {
    final valori = [for (var i = 0; i < 10; i++) _v('V$i', '500', max: '100')];
    final r = calcolaScore(_base(
        bmi: 40,
        fumo: true,
        sigarette: 30,
        alcool: true,
        bicchieri: 4,
        passi: 1000,
        sonno: 4,
        valori: valori,
        patologie: ['Diabete', 'BPCO', 'Insufficienza renale', 'HIV']));
    expect(r.score, 1);
  });

  test('analisi locale: 3 miglioramenti e punti coerenti', () {
    final r = calcolaScore(_base(bmi: 31, fumo: true, sigarette: 15));
    final a = analisiLocale(r, conChiave: false);
    expect(a.miglioramenti.length, 3);
    expect(a.score, r.score);
    expect(a.areeAttenzione, isNotEmpty);
  });
}
