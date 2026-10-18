import 'conflict_detector.dart';

class MergeStrategy {
  /// Merge automatico: per conflitti semplici usa last-write-wins.
  /// Marca i conflitti importanti come non risolti automaticamente.
  Map<String, dynamic> mergeAuto(
    Map<String, dynamic> local,
    Map<String, dynamic> drive,
    List<ConflictItem> conflicts,
  ) {
    final localTime = DateTime.tryParse(local['updatedAt'] ?? '') 
        ?? DateTime(2000);
    final driveTime = DateTime.tryParse(drive['updatedAt'] ?? '') 
        ?? DateTime(2000);

    // Base: parte dal più recente
    final merged = Map<String, dynamic>.from(
        driveTime.isAfter(localTime) ? drive : local);

    // Per ogni conflitto, decide automaticamente o segna come manuale
    for (final conflict in conflicts) {
      // Campi semplici → last-write-wins automatico
      final campiAutomatici = ['laboratorio', 'struttura', 'medico', 'ora'];
      if (campiAutomatici.contains(conflict.field)) {
        conflict.resolvedAutomatically = true;
        conflict.resolvedValue = driveTime.isAfter(localTime)
            ? conflict.driveValue
            : conflict.localValue;
      } else {
        // Campi importanti → richiede intervento manuale
        conflict.resolvedAutomatically = false;
      }
    }

    merged['updatedAt'] = DateTime.now().toIso8601String();
    return merged;
  }

  /// Risolve manualmente un conflitto con la scelta dell'utente.
  Map<String, dynamic> resolveManual(
    Map<String, dynamic> local,
    Map<String, dynamic> drive,
    ConflictItem conflict,
    ConflictResolution resolution,
  ) {
    final localTime = DateTime.tryParse(local['updatedAt'] ?? '') 
        ?? DateTime(2000);
    final driveTime = DateTime.tryParse(drive['updatedAt'] ?? '') 
        ?? DateTime(2000);

    final merged = Map<String, dynamic>.from(
        driveTime.isAfter(localTime) ? drive : local);

    final chosenValue = resolution == ConflictResolution.useLocal
        ? conflict.localValue
        : conflict.driveValue;

    // Applica la scelta al record corretto
    if (conflict.entity == 'paziente') {
      if (merged['paziente'] != null) {
        merged['paziente'][conflict.field] = chosenValue;
      }
    } else {
      final listKey = '${conflict.entity}i'; // esami, visite, farmaci
      final list = List<dynamic>.from(merged[listKey] ?? []);
      final idx = list.indexWhere((e) => e['id'] == conflict.id);
      if (idx >= 0) {
        list[idx][conflict.field] = chosenValue;
        merged[listKey] = list;
      }
    }

    conflict.resolvedAutomatically = true;
    conflict.resolvedValue = chosenValue;
    merged['updatedAt'] = DateTime.now().toIso8601String();
    return merged;
  }
}
