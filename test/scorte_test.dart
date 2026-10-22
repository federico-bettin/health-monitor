import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/features/farmaci/scheduling/scorte.dart';

Farmaco _f({
  double? scorte,
  double? unita,
  int? soglia,
  List<String> orari = const ['08:00'],
  FrequenzaFarmaco tipo = FrequenzaFarmaco.giornaliera,
  bool promemoria = true,
  bool archiviato = false,
  DateTime? fine,
}) =>
    Farmaco(
      id: 'A',
      nome: 'A',
      dosaggio: '1',
      frequenza: '',
      orariAssunzione: orari,
      frequenzaTipoIdx: tipo.index,
      promemoriaAttivo: promemoria,
      archiviato: archiviato,
      dataFine: fine,
      scorte: scorte,
      unitaPerDose: unita,
      sogliaScorteGiorni: soglia,
    );

void main() {
  // Mercoledì 21/10/2026, mezzogiorno (la dose delle 08:00 di oggi è passata)
  final adesso = DateTime(2026, 10, 21, 12);

  group('statoScorte', () {
    test('scorte non tracciate: nessuno stato', () {
      expect(statoScorte(_f(), adesso), isNull);
    });

    test('farmaco archiviato: nessuno stato', () {
      expect(statoScorte(_f(scorte: 5, archiviato: true), adesso), isNull);
    });

    test('1 dose al giorno, 10 unità: la prima non coperta è l\'11ª (1/11)', () {
      final s = statoScorte(_f(scorte: 10), adesso)!;
      expect(s.conPiano, isTrue);
      expect(s.giorni, 11); // 22..31/10 coperti, 1/11 no (attraversa il cambio ora)
      expect(s.inAvviso, isFalse);
    });

    test('5 unità: finiscono a 6 giorni, sotto la soglia di 7', () {
      final s = statoScorte(_f(scorte: 5), adesso)!;
      expect(s.giorni, 6);
      expect(s.inAvviso, isTrue);
    });

    test('la dose di oggi già passata non si conta', () {
      // 08:00 di oggi è passata: con 1 unità resta coperta la dose di domani
      final s = statoScorte(_f(scorte: 1), adesso)!;
      expect(s.giorni, 2); // 22/10 coperta, 23/10 no
    });

    test('scorte a zero con una dose ancora oggi: giorni = 0', () {
      final s = statoScorte(_f(scorte: 0, orari: ['08:00', '20:00']), adesso)!;
      expect(s.giorni, 0);
      expect(s.inAvviso, isTrue);
    });

    test('due unità per dose', () {
      final s = statoScorte(_f(scorte: 5, unita: 2), adesso)!;
      expect(s.unitaDose, 2);
      expect(s.giorni, 3); // 22 e 23 coperte (4 unità), il 24 no
    });

    test('la terapia finisce prima delle scorte: nessun problema', () {
      final s = statoScorte(_f(scorte: 10, fine: DateTime(2026, 10, 25)), adesso)!;
      expect(s.giorni, isNull); // dosi fino al 25 incluso: 4, ne bastano 10
      expect(s.inAvviso, isFalse);
    });

    test('scorte molto abbondanti: oltre l\'orizzonte, nessun avviso', () {
      final s = statoScorte(_f(scorte: 1000), adesso)!;
      expect(s.giorni, isNull);
      expect(s.inAvviso, isFalse);
    });

    test('soglia personalizzata', () {
      expect(statoScorte(_f(scorte: 5, soglia: 3), adesso)!.inAvviso, isFalse);
      expect(statoScorte(_f(scorte: 5, soglia: 10), adesso)!.inAvviso, isTrue);
    });

    test('al bisogno: niente giorni, avviso solo se non basta una dose', () {
      final tipo = FrequenzaFarmaco.alBisogno;
      final ok = statoScorte(_f(scorte: 3, tipo: tipo), adesso)!;
      expect(ok.conPiano, isFalse);
      expect(ok.giorni, isNull);
      expect(ok.inAvviso, isFalse);
      expect(statoScorte(_f(scorte: 0.5, tipo: tipo), adesso)!.inAvviso, isTrue);
      expect(statoScorte(_f(scorte: 0, tipo: tipo), adesso)!.inAvviso, isTrue);
    });

    test('promemoria spento: si trattano come senza piano', () {
      final s = statoScorte(_f(scorte: 3, promemoria: false), adesso)!;
      expect(s.conPiano, isFalse);
      expect(s.inAvviso, isFalse);
    });
  });

  group('valori di default e formato', () {
    test('unitaPerDoseDi: mancante, zero o negativo valgono 1', () {
      expect(unitaPerDoseDi(_f()), 1);
      expect(unitaPerDoseDi(_f(unita: 0)), 1);
      expect(unitaPerDoseDi(_f(unita: -2)), 1);
      expect(unitaPerDoseDi(_f(unita: 2.5)), 2.5);
    });

    test('sogliaScorteDi: mancante o negativa vale 7', () {
      expect(sogliaScorteDi(_f()), kSogliaScorteGiorniDefault);
      expect(sogliaScorteDi(_f(soglia: -1)), kSogliaScorteGiorniDefault);
      expect(sogliaScorteDi(_f(soglia: 0)), 0);
      expect(sogliaScorteDi(_f(soglia: 14)), 14);
    });

    test('formattaUnita', () {
      expect(formattaUnita(30), '30');
      expect(formattaUnita(2.5), '2.5');
      expect(formattaUnita(0.333), '0.3');
    });
  });

  group('JSON', () {
    test('le scorte fanno il giro di backup e ripristino', () {
      final f = _f(scorte: 12.5, unita: 0.5, soglia: 5);
      final r = Farmaco.fromJson(f.toJson());
      expect(r.scorte, 12.5);
      expect(r.unitaPerDose, 0.5);
      expect(r.sogliaScorteGiorni, 5);
    });

    test('un backup vecchio, senza campi scorte, si legge senza errori', () {
      final json = _f().toJson()
        ..remove('scorte')
        ..remove('unitaPerDose')
        ..remove('sogliaScorteGiorni');
      final r = Farmaco.fromJson(json);
      expect(r.scorte, isNull);
      expect(r.unitaPerDose, isNull);
      expect(r.sogliaScorteGiorni, isNull);
    });

    test('scorte intere nel JSON (es. 30) diventano double', () {
      final json = _f().toJson()..['scorte'] = 30;
      expect(Farmaco.fromJson(json).scorte, 30.0);
    });
  });
}
