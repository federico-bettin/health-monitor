import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/aderenza.dart';

Farmaco _f(
  String nome, {
  List<String> orari = const ['08:00'],
  FrequenzaFarmaco tipo = FrequenzaFarmaco.giornaliera,
  List<int> giorni = const [],
}) =>
    Farmaco(
      id: nome,
      nome: nome,
      dosaggio: '1',
      frequenza: '',
      orariAssunzione: orari,
      frequenzaTipoIdx: tipo.index,
      giorniSettimana: giorni,
      promemoriaAttivo: true,
    );

AssunzioneFarmaco _a(Farmaco f, DateTime prevista,
        [StatoAssunzione s = StatoAssunzione.presa]) =>
    AssunzioneFarmaco(
      id: '${f.id}_${prevista.millisecondsSinceEpoch}',
      farmacoId: f.id,
      dataOraPrevista: prevista,
      dataOraRegistrata: prevista,
      statoIdx: s.index,
    );

DateTime _t(int giorno, int h, [int m = 0]) => DateTime(2026, 10, giorno, h, m);

void main() {
  // Mercoledì 21/10/2026, mezzogiorno
  final adesso = _t(21, 12);
  final da = _t(1, 0);
  final a = _t(22, 0); // fine di oggi

  List<DoseValutata> valuta(List<Farmaco> fs, List<AssunzioneFarmaco> as,
          {DateTime? ora}) =>
      valutaDosi(
          farmaci: fs, assunzioni: as, da: da, a: a, adesso: ora ?? adesso);

  group('valutaDosi', () {
    test('senza nessuna dose registrata non produce dati', () {
      expect(valuta([_f('A')], []), isEmpty);
    });

    test('parte dal giorno della prima dose registrata', () {
      final f = _f('A');
      final r = valuta([f], [_a(f, _t(18, 8))]);
      // 18, 19, 20, 21 → il 21 alle 8 è passato da più di 2 ore
      expect(r.length, 4);
      expect(r.first.prevista, _t(18, 8));
      expect(r.first.esito, EsitoDose.presa);
      expect(r[1].esito, EsitoDose.nonRegistrata);
    });

    test('dose di oggi non ancora scaduta è in attesa', () {
      final f = _f('A', orari: ['08:00', '20:00']);
      final r = valuta([f], [_a(f, _t(20, 8))]);
      final oggiSera = r.firstWhere((d) => d.prevista == _t(21, 20));
      expect(oggiSera.esito, EsitoDose.inAttesa);
    });

    test('dose entro la soglia di 2 ore è ancora in attesa', () {
      final f = _f('A');
      final r = valuta([f], [_a(f, _t(20, 8))], ora: _t(21, 9, 30));
      expect(r.last.prevista, _t(21, 8));
      expect(r.last.esito, EsitoDose.inAttesa);
    });

    test('saltata è saltata, anche se registrata', () {
      final f = _f('A');
      final r = valuta([f], [_a(f, _t(20, 8), StatoAssunzione.saltata)]);
      expect(r.first.esito, EsitoDose.saltata);
    });

    test('ignora le dosi al bisogno (senza dose prevista)', () {
      final f = _f('A');
      final senzaPiano = AssunzioneFarmaco(
          id: 'x', farmacoId: 'A', dataOraRegistrata: _t(20, 9));
      expect(valuta([f], [senzaPiano]), isEmpty);
    });
  });

  group('calcolaAderenza', () {
    test('conta prese, saltate, non registrate; esclude le in attesa', () {
      final f = _f('A', orari: ['08:00', '20:00']);
      final r = valuta([
        f
      ], [
        _a(f, _t(19, 8)),
        _a(f, _t(19, 20)),
        _a(f, _t(20, 8), StatoAssunzione.saltata),
        // 20/10 20:00 e 21/10 08:00 mancano; 21/10 20:00 è in attesa
      ]);
      final ad = calcolaAderenza(r);
      expect(ad.prese, 2);
      expect(ad.saltate, 1);
      expect(ad.nonRegistrate, 2);
      expect(ad.valutate, 5);
      expect(ad.percentuale, closeTo(40, 0.001));
    });

    test('nessuna dose valutabile: percentuale nulla', () {
      expect(calcolaAderenza(const []).percentuale, isNull);
    });

    test('il parametro dal limita il conteggio', () {
      final f = _f('A');
      final r = valuta([f], [for (final g in [15, 16, 17, 18, 19, 20]) _a(f, _t(g, 8))]);
      expect(calcolaAderenza(r).prese, 6);
      expect(calcolaAderenza(r, dal: _t(18, 0)).prese, 3);
    });
  });

  group('calcolaStriscia', () {
    test('tutte prese fino a ieri, oggi in attesa: striscia di ieri e prima', () {
      final f = _f('A');
      final r = valuta([f], [for (final g in [17, 18, 19, 20]) _a(f, _t(g, 8))],
          ora: _t(21, 7));
      expect(calcolaStriscia(r), 4); // oggi in attesa: non spezza e non conta
    });

    test('oggi presa: conta anche oggi', () {
      final f = _f('A');
      final r = valuta([f], [for (final g in [18, 19, 20, 21]) _a(f, _t(g, 8))]);
      expect(calcolaStriscia(r), 4);
    });

    test('una dose saltata spezza la striscia', () {
      final f = _f('A');
      final r = valuta([
        f
      ], [
        _a(f, _t(17, 8)),
        _a(f, _t(18, 8)),
        _a(f, _t(19, 8), StatoAssunzione.saltata),
        _a(f, _t(20, 8)),
        _a(f, _t(21, 8)),
      ]);
      expect(calcolaStriscia(r), 2); // 20 e 21
    });

    test('oggi non registrata dopo la soglia: striscia a zero', () {
      final f = _f('A');
      final r = valuta([f], [for (final g in [18, 19, 20]) _a(f, _t(g, 8))]);
      expect(calcolaStriscia(r), 0); // 21/10 08:00 scaduta alle 10:00
    });

    test('giorni senza dosi sono neutri (piano a giorni della settimana)', () {
      // Lun, mer, ven
      final f = _f('A',
          tipo: FrequenzaFarmaco.giorniSettimana, giorni: [1, 3, 5]);
      final r = valuta([
        f
      ], [
        _a(f, _t(16, 8)), // ven
        _a(f, _t(19, 8)), // lun
        _a(f, _t(21, 8)), // mer
      ]);
      expect(calcolaStriscia(r), 3);
    });

    test('più farmaci: il giorno conta solo se sono presi tutti', () {
      final x = _f('X');
      final y = _f('Y', orari: ['20:00']);
      final r = valuta([
        x,
        y
      ], [
        _a(x, _t(19, 8)),
        _a(y, _t(19, 20)),
        _a(x, _t(20, 8)),
        // Y del 20 sera: non registrata
        _a(x, _t(21, 8)),
      ]);
      // 21: X presa, Y in attesa → neutro; 20: Y mancante → spezza
      expect(calcolaStriscia(r), 0);
    });

    test('nessuna dose: striscia zero', () {
      expect(calcolaStriscia(const []), 0);
    });
  });
}
