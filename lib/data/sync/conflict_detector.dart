/// Rappresenta un singolo conflitto tra versione locale e Drive
class ConflictItem {
  final String entity; // 'paziente', 'esame', 'visita', ecc.
  final String? id; // null per paziente
  final String field; // campo in conflitto
  final dynamic localValue;
  final dynamic driveValue;
  final DateTime localTime;
  final DateTime driveTime;
  bool resolvedAutomatically;
  dynamic resolvedValue;

  ConflictItem({
    required this.entity,
    this.id,
    required this.field,
    required this.localValue,
    required this.driveValue,
    required this.localTime,
    required this.driveTime,
    this.resolvedAutomatically = false,
    this.resolvedValue,
  });
}

enum ConflictResolution { useLocal, useDrive }

class ConflictDetector {
  /// Rileva conflitti tra dati locali e dati Drive.
  /// Un conflitto esiste quando lo stesso campo ha valori diversi
  /// e non è chiaro quale sia più recente.
  List<ConflictItem> detect(
    Map<String, dynamic> local,
    Map<String, dynamic> drive,
  ) {
    final conflicts = <ConflictItem>[];

    final localTime = DateTime.tryParse(local['updatedAt'] ?? '') 
        ?? DateTime(2000);
    final driveTime = DateTime.tryParse(drive['updatedAt'] ?? '') 
        ?? DateTime(2000);

    // Se uno dei due è molto più vecchio (>1 ora), non è un conflitto
    final diff = localTime.difference(driveTime).abs();
    if (diff.inHours >= 1) return conflicts;

    // Controlla paziente
    if (local['paziente'] != null && drive['paziente'] != null) {
      final pazConflicts = _compareObjects(
        'paziente',
        null,
        local['paziente'],
        drive['paziente'],
        localTime,
        driveTime,
        campiImportanti: ['diagnosi', 'terapia', 'note', 'allergie'],
      );
      conflicts.addAll(pazConflicts);
    }

    // Controlla esami
    conflicts.addAll(_compareLists(
      'esame',
      local['esami'] ?? [],
      drive['esami'] ?? [],
      localTime,
      driveTime,
      campiImportanti: ['valori', 'note', 'diagnosi'],
    ));

    // Controlla visite
    conflicts.addAll(_compareLists(
      'visita',
      local['visite'] ?? [],
      drive['visite'] ?? [],
      localTime,
      driveTime,
      campiImportanti: ['diagnosi', 'terapia', 'note'],
    ));

    // Controlla farmaci
    conflicts.addAll(_compareLists(
      'farmaco',
      local['farmaci'] ?? [],
      drive['farmaci'] ?? [],
      localTime,
      driveTime,
      campiImportanti: ['dosaggio', 'frequenza', 'attivo'],
    ));

    return conflicts;
  }

  List<ConflictItem> _compareLists(
    String entity,
    List<dynamic> localList,
    List<dynamic> driveList,
    DateTime localTime,
    DateTime driveTime, {
    required List<String> campiImportanti,
  }) {
    final conflicts = <ConflictItem>[];
    for (final localItem in localList) {
      final id = localItem['id'];
      final driveItem = driveList.firstWhere(
        (d) => d['id'] == id,
        orElse: () => null,
      );
      if (driveItem == null) continue;
      conflicts.addAll(_compareObjects(
        entity,
        id,
        localItem,
        driveItem,
        localTime,
        driveTime,
        campiImportanti: campiImportanti,
      ));
    }
    return conflicts;
  }

  List<ConflictItem> _compareObjects(
    String entity,
    String? id,
    Map<String, dynamic> local,
    Map<String, dynamic> drive,
    DateTime localTime,
    DateTime driveTime, {
    required List<String> campiImportanti,
  }) {
    final conflicts = <ConflictItem>[];
    for (final field in campiImportanti) {
      final localVal = local[field];
      final driveVal = drive[field];
      if (localVal?.toString() != driveVal?.toString()) {
        conflicts.add(ConflictItem(
          entity: entity,
          id: id,
          field: field,
          localValue: localVal,
          driveValue: driveVal,
          localTime: localTime,
          driveTime: driveTime,
        ));
      }
    }
    return conflicts;
  }
}
