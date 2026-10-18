import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/sync/conflict_detector.dart';
import 'package:salute_bettin/data/sync/merge_strategy.dart';
import 'drive_repository.dart';
import 'i_data_repository.dart';
import 'local_repository.dart';

/// Repository che combina locale + Drive con sync e merge.
/// Legge sempre dal locale (veloce), scrive su entrambi.
/// Sincronizza periodicamente con Drive.
class SyncRepository implements IDataRepository {
  final LocalRepository _local;
  final DriveRepository _drive;
  final ConflictDetector _detector;
  final MergeStrategy _merger;

  // Callback chiamato quando ci sono conflitti da risolvere
  final void Function(List<ConflictItem>)? onConflicts;

  SyncRepository({this.onConflicts})
      : _local = LocalRepository(),
        _drive = DriveRepository(),
        _detector = ConflictDetector(),
        _merger = MergeStrategy();

  @override
  Future<void> init() async {
    await _local.init();
    await _drive.init();
    await _sync();
  }

  @override
  Future<void> dispose() async {
    await _local.dispose();
    await _drive.dispose();
  }

  // ─── Sync ─────────────────────────────────────────────────
  Future<void> _sync() async {
    try {
      final localData = await _local.exportAll();
      final driveData = await _drive.exportAll();

      final conflicts = _detector.detect(localData, driveData);

      if (conflicts.isEmpty) {
        // Nessun conflitto — usa il più recente
        final localTime = DateTime.tryParse(localData['updatedAt'] ?? '') 
            ?? DateTime(2000);
        final driveTime = DateTime.tryParse(driveData['updatedAt'] ?? '') 
            ?? DateTime(2000);

        if (driveTime.isAfter(localTime)) {
          await _local.importAll(driveData);
        } else if (localTime.isAfter(driveTime)) {
          await _drive.importAll(localData);
        }
      } else {
        // Merge automatico dove possibile
        final merged = _merger.mergeAuto(localData, driveData, conflicts);
        final manualConflicts = conflicts
            .where((c) => !c.resolvedAutomatically)
            .toList();

        // Salva il merge automatico
        await _local.importAll(merged);
        await _drive.importAll(merged);

        // Notifica i conflitti manuali all'UI
        if (manualConflicts.isNotEmpty && onConflicts != null) {
          onConflicts!(manualConflicts);
        }
      }
    } catch (e) {
      // Se il sync fallisce, continua con i dati locali
      // ignore: avoid_print
      print('Sync error: $e');
    }
  }

  /// Forza una sincronizzazione manuale
  Future<void> syncNow() async {
    await _sync();
  }

  /// Risolve un conflitto manuale con la versione scelta
  Future<void> resolveConflict(
      ConflictItem conflict, ConflictResolution resolution) async {
    final localData = await _local.exportAll();
    final driveData = await _drive.exportAll();
    final merged = _merger.resolveManual(
        localData, driveData, conflict, resolution);
    await _local.importAll(merged);
    await _drive.importAll(merged);
  }

  // ─── Paziente ─────────────────────────────────────────────
  @override
  Future<Paziente?> getPaziente() => _local.getPaziente();

  @override
  Future<void> savePaziente(Paziente paziente) async {
    await _local.savePaziente(paziente);
    await _drive.savePaziente(paziente);
  }

  // ─── Esami ────────────────────────────────────────────────
  @override
  Future<List<Esame>> getEsami() => _local.getEsami();

  @override
  Future<Esame?> getEsame(String id) => _local.getEsame(id);

  @override
  Future<void> saveEsame(Esame esame) async {
    await _local.saveEsame(esame);
    await _drive.saveEsame(esame);
  }

  @override
  Future<void> deleteEsame(String id) async {
    await _local.deleteEsame(id);
    await _drive.deleteEsame(id);
  }

  // ─── Visite ───────────────────────────────────────────────
  @override
  Future<List<Visita>> getVisite() => _local.getVisite();

  @override
  Future<Visita?> getVisita(String id) => _local.getVisita(id);

  @override
  Future<void> saveVisita(Visita visita) async {
    await _local.saveVisita(visita);
    await _drive.saveVisita(visita);
  }

  @override
  Future<void> deleteVisita(String id) async {
    await _local.deleteVisita(id);
    await _drive.deleteVisita(id);
  }

  // ─── Farmaci ──────────────────────────────────────────────
  @override
  Future<List<Farmaco>> getFarmaci() => _local.getFarmaci();

  @override
  Future<Farmaco?> getFarmaco(String id) => _local.getFarmaco(id);

  @override
  Future<void> saveFarmaco(Farmaco farmaco) async {
    await _local.saveFarmaco(farmaco);
    await _drive.saveFarmaco(farmaco);
  }

  @override
  Future<void> deleteFarmaco(String id) async {
    await _local.deleteFarmaco(id);
    await _drive.deleteFarmaco(id);
  }

  // ─── Appuntamenti ─────────────────────────────────────────
  @override
  Future<List<Appuntamento>> getAppuntamenti() => _local.getAppuntamenti();

  @override
  Future<Appuntamento?> getAppuntamento(String id) =>
      _local.getAppuntamento(id);

  @override
  Future<void> saveAppuntamento(Appuntamento appuntamento) async {
    await _local.saveAppuntamento(appuntamento);
    await _drive.saveAppuntamento(appuntamento);
  }

  @override
  Future<void> deleteAppuntamento(String id) async {
    await _local.deleteAppuntamento(id);
    await _drive.deleteAppuntamento(id);
  }

  // ─── Token Usage ──────────────────────────────────────────
  @override
  Future<List<TokenUsage>> getTokenUsage() => _local.getTokenUsage();

  @override
  Future<void> saveTokenUsage(TokenUsage usage) async {
    await _local.saveTokenUsage(usage);
  }

  // ─── Utilità ──────────────────────────────────────────────
  @override
  Future<void> clear() async {
    await _local.clear();
    await _drive.clear();
  }

  @override
  Future<Map<String, dynamic>> exportAll() => _local.exportAll();

  @override
  Future<void> importAll(Map<String, dynamic> data) async {
    await _local.importAll(data);
    await _drive.importAll(data);
  }
}
