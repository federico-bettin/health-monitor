import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/models/visita.dart';

/// Interfaccia astratta — tutti i repository devono implementarla.
/// L'app usa sempre questa interfaccia, mai le implementazioni dirette.
abstract class IDataRepository {
  // ─── Inizializzazione ─────────────────────────────────────
  Future<void> init();
  Future<void> dispose();

  // ─── Paziente ─────────────────────────────────────────────
  Future<Paziente?> getPaziente();
  Future<void> savePaziente(Paziente paziente);

  // ─── Esami ────────────────────────────────────────────────
  Future<List<Esame>> getEsami();
  Future<Esame?> getEsame(String id);
  Future<void> saveEsame(Esame esame);
  Future<void> deleteEsame(String id);

  // ─── Visite ───────────────────────────────────────────────
  Future<List<Visita>> getVisite();
  Future<Visita?> getVisita(String id);
  Future<void> saveVisita(Visita visita);
  Future<void> deleteVisita(String id);

  // ─── Farmaci ──────────────────────────────────────────────
  Future<List<Farmaco>> getFarmaci();
  Future<Farmaco?> getFarmaco(String id);
  Future<void> saveFarmaco(Farmaco farmaco);
  Future<void> deleteFarmaco(String id);

  // ─── Registro assunzioni ──────────────────────────────────
  /// Assunzioni con riferimento (prevista, altrimenti registrata) in [da, a).
  Future<List<AssunzioneFarmaco>> getAssunzioni(DateTime da, DateTime a);
  Future<List<AssunzioneFarmaco>> getAssunzioniFarmaco(String farmacoId);
  Future<void> saveAssunzione(AssunzioneFarmaco assunzione);
  Future<void> deleteAssunzione(String id);

  // ─── Appuntamenti ─────────────────────────────────────────
  Future<List<Appuntamento>> getAppuntamenti();
  Future<Appuntamento?> getAppuntamento(String id);
  Future<void> saveAppuntamento(Appuntamento appuntamento);
  Future<void> deleteAppuntamento(String id);

  // ─── Token Usage ──────────────────────────────────────────
  Future<List<TokenUsage>> getTokenUsage();
  Future<void> saveTokenUsage(TokenUsage usage);

  // ─── Utilità ──────────────────────────────────────────────
  Future<void> clear(); // cancella tutti i dati
  Future<Map<String, dynamic>> exportAll(); // export completo come JSON
  Future<void> importAll(Map<String, dynamic> data); // import da JSON
}
