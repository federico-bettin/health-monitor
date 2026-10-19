import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/claude_service.dart';

/// Traduce in inglese i testi salvati dall'utente (nomi e valori degli esami,
/// note, specialità, diagnosi, terapie). I dati originali NON vengono toccati:
/// la traduzione è solo per la visualizzazione (vedi core/i18n.dart).
class DatiTranslationService {
  DatiTranslationService._();
  static final DatiTranslationService instance = DatiTranslationService._();

  /// Ritorna il numero di testi nuovi tradotti. Lancia eccezione se fallisce.
  Future<int> traduciTutto() async {
    // Come le pagine Esami/Visite: sempre il repository locale
    final repo = LocalRepository();
    await repo.init();
    final testi = <String>{};

    void add(String? s) {
      final t = s?.trim() ?? '';
      if (t.isEmpty || !RegExp(r'[A-Za-zÀ-ÿ]{2}').hasMatch(t)) return;
      if (haTraduzioneEn(t)) return;
      testi.add(t);
    }

    for (final e in await repo.getEsami()) {
      add(e.tipo);
      add(e.note);
      for (final v in e.valori) {
        add(v.nome);
      }
    }
    for (final v in await repo.getVisite()) {
      add(v.specialita);
      add(v.diagnosi);
      add(v.terapia);
      add(v.note);
    }
    if (testi.isEmpty) {
      throw Exception(
          'Nessun testo da tradurre (esami: ${(await repo.getEsami()).length}, visite: ${(await repo.getVisite()).length})');
    }

    // Blocchi limitati per numero di testi e per lunghezza totale (le note
    // lunghe farebbero troncare la risposta).
    final blocchi = <List<String>>[];
    var corrente = <String>[];
    var len = 0;
    for (final t in testi) {
      if (corrente.isNotEmpty && (corrente.length >= 15 || len + t.length > 1500)) {
        blocchi.add(corrente);
        corrente = <String>[];
        len = 0;
      }
      corrente.add(t);
      len += t.length;
    }
    if (corrente.isNotEmpty) blocchi.add(corrente);

    final nuove = <String, String>{};
    Object? ultimoErrore;

    Future<void> prova(List<String> parte) async {
      final r = await ClaudeService().traduciTesti(parte);
      nuove.addAll(r.testi);
      try {
        final repo2 = repo;
        await repo2.saveTokenUsage(
            r.risposta.toTokenUsage('Traduzione dati esami/visite'));
      } catch (_) {}
      await aggiungiTraduzioniDati(Map.of(nuove)); // progresso salvato
    }

    for (final parte in blocchi) {
      try {
        await prova(parte);
        // Testi rimasti fuori dalla risposta: un tentativo singolo
        for (final t in parte.where((x) => !nuove.containsKey(x))) {
          try {
            await prova([t]);
          } catch (e) {
            ultimoErrore = e;
          }
        }
      } catch (e) {
        ultimoErrore = e;
        if (parte.length > 1) {
          for (final t in parte) {
            try {
              await prova([t]);
            } catch (e2) {
              ultimoErrore = e2;
            }
          }
        }
      }
    }
    if (nuove.isEmpty && ultimoErrore != null) {
      throw Exception('$ultimoErrore');
    }
    if (nuove.length < testi.length) {
      throw Exception(
          'Tradotti ${nuove.length} su ${testi.length} testi. Riprova col pulsante. $ultimoErrore');
    }
    return nuove.length;
  }
}
