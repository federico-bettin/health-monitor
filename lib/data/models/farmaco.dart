import 'package:hive/hive.dart';

part 'farmaco.g.dart';

/// Tipo di ricorrenza del piano terapeutico.
/// Salvato come indice (int) con fallback sicuro su [giornaliera].
enum FrequenzaFarmaco { giornaliera, giorniSettimana, ogniNGiorni, alBisogno }

@HiveType(typeId: 3)
class Farmaco extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nome;

  @HiveField(2)
  String? principioAttivo;

  @HiveField(3)
  String dosaggio;

  @HiveField(4)
  String frequenza; // es. "1 volta al giorno", "2 volte al giorno"

  @HiveField(5)
  DateTime? dataInizio;

  @HiveField(6)
  DateTime? dataFine;

  @HiveField(7)
  bool attivo;

  @HiveField(8)
  String? medico;

  @HiveField(9)
  String? note;

  @HiveField(10)
  List<String> orariAssunzione; // es. ["08:00", "20:00"]

  @HiveField(11)
  DateTime updatedAt;

  // ─── Piano terapeutico (promemoria) ───────────────────────
  // Riusa: dosaggio (dose), dataInizio, dataFine (null = cronica),
  // orariAssunzione (orari "HH:mm"), note.

  /// Indice di [FrequenzaFarmaco]; usare il getter [frequenzaTipo].
  @HiveField(12, defaultValue: 0)
  int frequenzaTipoIdx;

  /// Giorni della settimana 1-7 (1 = lunedì, 7 = domenica, come DateTime.weekday).
  @HiveField(13)
  List<int> giorniSettimana;

  /// Per [FrequenzaFarmaco.ogniNGiorni]: intervallo, contato da [dataInizio].
  @HiveField(14)
  int? ogniNGiorni;

  @HiveField(15, defaultValue: false)
  bool promemoriaAttivo;

  @HiveField(16)
  String? istruzioni; // es. "a stomaco pieno"

  /// Farmaco con registro assunzioni "eliminato": sparisce dalla lista attiva
  /// ma resta nello storico.
  @HiveField(17, defaultValue: false)
  bool archiviato;

  // ─── Scorte ───────────────────────────────────────────────

  /// Unità rimaste (compresse, fiale...). Null = scorte non tracciate.
  /// Scendono a ogni dose segnata come presa.
  @HiveField(18)
  double? scorte;

  /// Unità consumate a ogni assunzione. Null = 1.
  @HiveField(19)
  double? unitaPerDose;

  /// Avviso quando le scorte bastano per meno di questi giorni. Null = 7.
  @HiveField(20)
  int? sogliaScorteGiorni;

  Farmaco({
    required this.id,
    required this.nome,
    this.principioAttivo,
    required this.dosaggio,
    required this.frequenza,
    this.dataInizio,
    this.dataFine,
    this.attivo = true,
    this.medico,
    this.note,
    List<String>? orariAssunzione,
    DateTime? updatedAt,
    this.frequenzaTipoIdx = 0,
    List<int>? giorniSettimana,
    this.ogniNGiorni,
    this.promemoriaAttivo = false,
    this.istruzioni,
    this.archiviato = false,
    this.scorte,
    this.unitaPerDose,
    this.sogliaScorteGiorni,
  })  : orariAssunzione = orariAssunzione ?? [],
        giorniSettimana = giorniSettimana ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  FrequenzaFarmaco get frequenzaTipo =>
      (frequenzaTipoIdx >= 0 && frequenzaTipoIdx < FrequenzaFarmaco.values.length)
          ? FrequenzaFarmaco.values[frequenzaTipoIdx]
          : FrequenzaFarmaco.giornaliera;

  set frequenzaTipo(FrequenzaFarmaco v) => frequenzaTipoIdx = v.index;

  bool get isScaduto => dataFine != null && dataFine!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'principioAttivo': principioAttivo,
        'dosaggio': dosaggio,
        'frequenza': frequenza,
        'dataInizio': dataInizio?.toIso8601String(),
        'dataFine': dataFine?.toIso8601String(),
        'attivo': attivo,
        'medico': medico,
        'note': note,
        'orariAssunzione': orariAssunzione,
        'updatedAt': updatedAt.toIso8601String(),
        'frequenzaTipo': frequenzaTipoIdx,
        'giorniSettimana': giorniSettimana,
        'ogniNGiorni': ogniNGiorni,
        'promemoriaAttivo': promemoriaAttivo,
        'istruzioni': istruzioni,
        'archiviato': archiviato,
        'scorte': scorte,
        'unitaPerDose': unitaPerDose,
        'sogliaScorteGiorni': sogliaScorteGiorni,
      };

  factory Farmaco.fromJson(Map<String, dynamic> json) => Farmaco(
        id: json['id'],
        nome: json['nome'],
        principioAttivo: json['principioAttivo'],
        dosaggio: json['dosaggio'],
        frequenza: json['frequenza'],
        dataInizio: json['dataInizio'] != null
            ? DateTime.parse(json['dataInizio'])
            : null,
        dataFine:
            json['dataFine'] != null ? DateTime.parse(json['dataFine']) : null,
        attivo: json['attivo'] ?? true,
        medico: json['medico'],
        note: json['note'],
        orariAssunzione: List<String>.from(json['orariAssunzione'] ?? []),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
        // Campi del piano terapeutico: assenti nei backup/Drive precedenti.
        frequenzaTipoIdx: (json['frequenzaTipo'] as num?)?.toInt() ?? 0,
        giorniSettimana: ((json['giorniSettimana'] as List?) ?? [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        ogniNGiorni: (json['ogniNGiorni'] as num?)?.toInt(),
        promemoriaAttivo: json['promemoriaAttivo'] as bool? ?? false,
        istruzioni: json['istruzioni'] as String?,
        archiviato: json['archiviato'] as bool? ?? false,
        scorte: (json['scorte'] as num?)?.toDouble(),
        unitaPerDose: (json['unitaPerDose'] as num?)?.toDouble(),
        sogliaScorteGiorni: (json['sogliaScorteGiorni'] as num?)?.toInt(),
      );
}
