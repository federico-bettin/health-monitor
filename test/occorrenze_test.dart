import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Farmaco _f(
  String nome, {
  List<String> orari = const ['08:00'],
  FrequenzaFarmaco tipo = FrequenzaFarmaco.giornaliera,
  List<int> giorni = const [],
  int? ogniN,
  DateTime? inizio,
  DateTime? fine,
  bool promemoria = true,
  bool archiviato = false,
}) =>
    Farmaco(
      id: nome,
      nome: nome,
      dosaggio: '1',
      frequenza: '',
      orariAssunzione: orari,
      dataInizio: inizio,
      dataFine: fine,
      frequenzaTipoIdx: tipo.index,
      giorniSettimana: giorni,
      ogniNGiorni: ogniN,
      promemoriaAttivo: promemoria,
      archiviato: archiviato,
    );

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // Lunedì 19/10/2026 … (21/10/2026 è mercoledì)
  final da = DateTime(2026, 10, 19);
  final a14 = DateTime(2026, 11, 2);

  group('generaOccorrenze', () {
    test('giornaliera: 2 orari x 3 giorni, in ordine', () {
      final r = generaOccorrenze(
          _f('A', orari: ['20:00', '08:00']), da, DateTime(2026, 10, 22));
      expect(r.length, 6);
      expect(r.first, DateTime(2026, 10, 19, 8, 0));
      expect(r[1], DateTime(2026, 10, 19, 20, 0));
      expect(r.last, DateTime(2026, 10, 21, 20, 0));
      for (var i = 1; i < r.length; i++) {
        expect(r[i].isAfter(r[i - 1]), isTrue);
      }
    });

    test('giorni della settimana: lunedì e giovedì su 14 giorni', () {
      final r = generaOccorrenze(
          _f('A', tipo: FrequenzaFarmaco.giorniSettimana, giorni: [1, 4]),
          da,
          a14);
      expect(r.map(_ymd).toList(),
          ['2026-10-19', '2026-10-22', '2026-10-26', '2026-10-29']);
    });

    test('giorni della settimana senza giorni: nessuna occorrenza', () {
      expect(
          generaOccorrenze(
              _f('A', tipo: FrequenzaFarmaco.giorniSettimana), da, a14),
          isEmpty);
    });

    test('ogni N giorni: calcolato da dataInizio', () {
      final r = generaOccorrenze(
          _f('A',
              tipo: FrequenzaFarmaco.ogniNGiorni,
              ogniN: 3,
              inizio: DateTime(2026, 10, 20)),
          da,
          DateTime(2026, 11, 1));
      expect(r.map(_ymd).toList(),
          ['2026-10-20', '2026-10-23', '2026-10-26', '2026-10-29']);
    });

    test('ogni N giorni: la finestra non sposta la cadenza', () {
      final f = _f('A',
          tipo: FrequenzaFarmaco.ogniNGiorni,
          ogniN: 3,
          inizio: DateTime(2026, 10, 20));
      // Stessa cadenza anche partendo da un altro giorno
      final r = generaOccorrenze(f, DateTime(2026, 10, 22), DateTime(2026, 11, 1));
      expect(r.map(_ymd).toList(), ['2026-10-23', '2026-10-26', '2026-10-29']);
    });

    test('ogni N giorni senza dataInizio o con N non valido: nessuna', () {
      expect(
          generaOccorrenze(
              _f('A', tipo: FrequenzaFarmaco.ogniNGiorni, ogniN: 3), da, a14),
          isEmpty);
      expect(
          generaOccorrenze(
              _f('A',
                  tipo: FrequenzaFarmaco.ogniNGiorni,
                  ogniN: 0,
                  inizio: DateTime(2026, 10, 20)),
              da,
              a14),
          isEmpty);
    });

    test('dataInizio e dataFine (inclusive)', () {
      final r = generaOccorrenze(
          _f('A', inizio: DateTime(2026, 10, 21), fine: DateTime(2026, 10, 23)),
          da,
          DateTime(2026, 10, 30));
      expect(r.map(_ymd).toList(), ['2026-10-21', '2026-10-22', '2026-10-23']);
    });

    test('dataFine null = terapia cronica, continua', () {
      final r = generaOccorrenze(
          _f('A', inizio: DateTime(2026, 10, 1)), da, DateTime(2026, 11, 19));
      expect(r.length, 31);
    });

    test('rispetta l\'ora di partenza nel primo giorno', () {
      final r = generaOccorrenze(_f('A', orari: ['08:00', '20:00']),
          DateTime(2026, 10, 21, 9), DateTime(2026, 10, 22));
      expect(r, [DateTime(2026, 10, 21, 20, 0)]);
    });

    test('al bisogno, promemoria spento, archiviato, senza orari: nessuna', () {
      expect(
          generaOccorrenze(
              _f('A', tipo: FrequenzaFarmaco.alBisogno), da, a14),
          isEmpty);
      expect(generaOccorrenze(_f('A', promemoria: false), da, a14), isEmpty);
      expect(generaOccorrenze(_f('A', archiviato: true), da, a14), isEmpty);
      expect(generaOccorrenze(_f('A', orari: []), da, a14), isEmpty);
    });

    test('orari non validi ignorati, duplicati uniti', () {
      final r = generaOccorrenze(
          _f('A', orari: ['08:00', '8:00', '25:00', 'abc', '12:61', '20:30']),
          da,
          DateTime(2026, 10, 20));
      expect(r, [DateTime(2026, 10, 19, 8, 0), DateTime(2026, 10, 19, 20, 30)]);
    });

    test('cambio ora legale di primavera (28/03/2027): 08:00 resta 08:00', () {
      final r = generaOccorrenze(
          _f('A'), DateTime(2027, 3, 26), DateTime(2027, 3, 31));
      expect(r.map(_ymd).toList(),
          ['2027-03-26', '2027-03-27', '2027-03-28', '2027-03-29', '2027-03-30']);
      expect(r.every((t) => t.hour == 8 && t.minute == 0), isTrue);
    });

    test('cambio ora legale d\'autunno (25/10/2026): 08:00 resta 08:00', () {
      final r = generaOccorrenze(
          _f('A'), DateTime(2026, 10, 23), DateTime(2026, 10, 28));
      expect(r.map(_ymd).toList(),
          ['2026-10-23', '2026-10-24', '2026-10-25', '2026-10-26', '2026-10-27']);
      expect(r.every((t) => t.hour == 8 && t.minute == 0), isTrue);
    });

    test('ogni N giorni a cavallo dell\'ora legale non perde un giorno', () {
      final r = generaOccorrenze(
          _f('A',
              tipo: FrequenzaFarmaco.ogniNGiorni,
              ogniN: 2,
              inizio: DateTime(2027, 3, 24)),
          DateTime(2027, 3, 24),
          DateTime(2027, 4, 3));
      expect(r.map(_ymd).toList(), [
        '2027-03-24',
        '2027-03-26',
        '2027-03-28',
        '2027-03-30',
        '2027-04-01'
      ]);
    });
  });

  group('aIstante (Europe/Zurich)', () {
    final zurigo = () => tz.getLocation('Europe/Zurich');

    test('stessa ora del muro, offset diverso prima/dopo la primavera', () {
      final prima = aIstante(DateTime(2027, 3, 27, 8), zurigo());
      final dopo = aIstante(DateTime(2027, 3, 29, 8), zurigo());
      expect(prima.hour, 8);
      expect(dopo.hour, 8);
      expect(prima.timeZoneOffset, const Duration(hours: 1)); // CET
      expect(dopo.timeZoneOffset, const Duration(hours: 2)); // CEST
    });

    test('stessa ora del muro, offset diverso prima/dopo l\'autunno', () {
      final prima = aIstante(DateTime(2026, 10, 24, 8), zurigo());
      final dopo = aIstante(DateTime(2026, 10, 26, 8), zurigo());
      expect(prima.hour, 8);
      expect(dopo.hour, 8);
      expect(prima.timeZoneOffset, const Duration(hours: 2));
      expect(dopo.timeZoneOffset, const Duration(hours: 1));
    });

    test('orario inesistente (02:30 del 28/03/2027) non è scartato né anticipato',
        () {
      final r = aIstante(DateTime(2027, 3, 28, 2, 30), zurigo());
      expect(r.day, 28);
      expect(r.isAfter(tz.TZDateTime(zurigo(), 2027, 3, 28, 1, 59)), isTrue);
    });
  });

  group('raggruppaPerOrario', () {
    test('una notifica per istante, farmaci ordinati per nome', () {
      final g = raggruppaPerOrario([
        _f('Carvedilolo', orari: ['20:00']),
        _f('Aspirina', orari: ['08:00']),
        _f('Bisoprololo', orari: ['08:00', '20:00']),
      ], DateTime(2026, 10, 21), DateTime(2026, 10, 22));
      expect(g.length, 2);
      expect(g[0].quando, DateTime(2026, 10, 21, 8));
      expect(g[0].farmaci.map((f) => f.nome).toList(), ['Aspirina', 'Bisoprololo']);
      expect(g[1].quando, DateTime(2026, 10, 21, 20));
      expect(
          g[1].farmaci.map((f) => f.nome).toList(), ['Bisoprololo', 'Carvedilolo']);
    });

    test('tipico: 5 farmaci x 3 orari uguali x 30 giorni = 90 notifiche', () {
      final farmaci = [
        for (var i = 0; i < 5; i++) _f('F$i', orari: ['08:00', '14:00', '20:00'])
      ];
      final inizio = DateTime(2026, 10, 21);
      final g = raggruppaPerOrario(farmaci, inizio, DateTime(2026, 11, 20));
      expect(g.length, 90);
      expect(g.every((x) => x.farmaci.length == 5), isTrue);
      expect(limitaAlTetto(g).length, 90); // sotto il tetto: invariato
    });

    test('scenario pesante: 10 farmaci x 4 orari distinti x 30 giorni con tetto',
        () {
      String hhmm(int h, int m) =>
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      final farmaci = [
        for (var i = 0; i < 10; i++)
          _f('F$i', orari: [
            hhmm(6, i * 5),
            hhmm(10, i * 5),
            hhmm(14, i * 5),
            hhmm(20, i * 5),
          ])
      ];
      final inizio = DateTime(2026, 10, 21);
      final g = raggruppaPerOrario(farmaci, inizio, DateTime(2026, 11, 20));
      expect(g.length, 1200); // 40 orari distinti x 30 giorni

      final tagliati = limitaAlTetto(g);
      expect(tagliati.length, kTettoNotifiche);
      // Ordine cronologico e prime 400 in assoluto: 10 giorni x 40
      for (var i = 1; i < tagliati.length; i++) {
        expect(tagliati[i].quando.isAfter(tagliati[i - 1].quando), isTrue);
      }
      expect(_ymd(tagliati.first.quando), '2026-10-21');
      expect(_ymd(tagliati.last.quando), '2026-10-30');
      expect(tagliati.last.quando, g[399].quando);
    });
  });
}
