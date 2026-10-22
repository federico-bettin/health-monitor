import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/data/services/farmaci_azioni_notifica.dart';

void main() {
  const p = PayloadFarmaci(
    previstaMs: 1792600200000,
    farmacoIds: ['a1', 'b2'],
    titolo: '08:00 – 2 farmaci',
    corpo: 'Aspirina, Vitamina D',
    espanso: 'Aspirina – 100mg\nVitamina D',
    lPreso: 'Presi tutti',
    lPosticipa: 'Posticipa 10 min',
  );

  group('PayloadFarmaci', () {
    test('codifica e decodifica danno gli stessi dati', () {
      final d = PayloadFarmaci.decodifica(p.codifica());
      expect(d, isNotNull);
      expect(d!.previstaMs, p.previstaMs);
      expect(d.farmacoIds, ['a1', 'b2']);
      expect(d.titolo, p.titolo);
      expect(d.corpo, p.corpo);
      expect(d.espanso, p.espanso);
      expect(d.lPreso, 'Presi tutti');
      expect(d.lPosticipa, 'Posticipa 10 min');
    });

    test('espanso assente resta null', () {
      const senza = PayloadFarmaci(
        previstaMs: 1,
        farmacoIds: ['x'],
        titolo: 't',
        corpo: 'c',
        lPreso: 'Preso',
        lPosticipa: 'Posticipa',
      );
      expect(PayloadFarmaci.decodifica(senza.codifica())!.espanso, isNull);
    });

    test('payload vecchio, vuoto o rotto: nessun dato, nessun crash', () {
      expect(PayloadFarmaci.decodifica('farmaci'), isNull);
      expect(PayloadFarmaci.decodifica(null), isNull);
      expect(PayloadFarmaci.decodifica(''), isNull);
      expect(PayloadFarmaci.decodifica('farmaci:{non json'), isNull);
      expect(PayloadFarmaci.decodifica('farmaci:{"p":1}'), isNull);
    });

    test('ePayloadFarmaci riconosce vecchio e nuovo formato', () {
      expect(ePayloadFarmaci('farmaci'), isTrue);
      expect(ePayloadFarmaci(p.codifica()), isTrue);
      expect(ePayloadFarmaci('altro'), isFalse);
      expect(ePayloadFarmaci(null), isFalse);
    });
  });

  group('ID', () {
    test('idSnooze sta nel suo intervallo e fuori da quello del piano', () {
      for (final ms in [0, 1792600200000, 4102444800000, 9999999999999]) {
        final id = idSnooze(ms);
        expect(id, greaterThanOrEqualTo(kIdBaseSnooze));
        expect(id, lessThan(kIdBaseSnooze + 1000000));
        expect(id, lessThan(2147483647)); // intero a 32 bit di Android
      }
    });

    test('stesso istante, stesso ID; minuti diversi, ID diversi', () {
      expect(idSnooze(1792600200000), idSnooze(1792600200000));
      expect(idSnooze(1792600200000), isNot(idSnooze(1792600260000)));
    });

    test('idDosePrevista è stabile', () {
      final t = DateTime.fromMillisecondsSinceEpoch(1792600200000);
      expect(idDosePrevista('f1', t), 'f1_1792600200000');
    });
  });
}
