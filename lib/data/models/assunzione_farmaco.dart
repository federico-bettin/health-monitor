import 'package:hive/hive.dart';

part 'assunzione_farmaco.g.dart';

/// Nome del box Hive del registro assunzioni.
/// (Definito qui e non in AppConstants per non toccare constants.dart.)
const String kBoxAssunzioni = 'assunzioni_farmaco';

/// Esito di una dose. Salvato come indice con fallback su [nonRegistrata].
enum StatoAssunzione { presa, saltata, nonRegistrata }

/// Da dove arriva la registrazione. Salvato come indice con fallback su [app].
enum OrigineAssunzione { notifica, app, manuale }

/// Una dose registrata (o prevista e non registrata) di un farmaco.
/// Le dosi "al bisogno" hanno solo [dataOraRegistrata].
@HiveType(typeId: 9)
class AssunzioneFarmaco extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String farmacoId;

  @HiveField(2)
  DateTime? dataOraPrevista;

  @HiveField(3)
  DateTime? dataOraRegistrata;

  /// Indice di [StatoAssunzione]; usare il getter [stato].
  @HiveField(4, defaultValue: 2)
  int statoIdx;

  /// Indice di [OrigineAssunzione]; usare il getter [origine].
  @HiveField(5, defaultValue: 1)
  int origineIdx;

  @HiveField(6)
  DateTime updatedAt;

  AssunzioneFarmaco({
    required this.id,
    required this.farmacoId,
    this.dataOraPrevista,
    this.dataOraRegistrata,
    this.statoIdx = 0,
    this.origineIdx = 1,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  StatoAssunzione get stato =>
      (statoIdx >= 0 && statoIdx < StatoAssunzione.values.length)
          ? StatoAssunzione.values[statoIdx]
          : StatoAssunzione.nonRegistrata;

  set stato(StatoAssunzione v) => statoIdx = v.index;

  OrigineAssunzione get origine =>
      (origineIdx >= 0 && origineIdx < OrigineAssunzione.values.length)
          ? OrigineAssunzione.values[origineIdx]
          : OrigineAssunzione.app;

  set origine(OrigineAssunzione v) => origineIdx = v.index;

  /// Istante di riferimento per ordinamento e filtri per intervallo:
  /// la dose prevista se c'è, altrimenti quella registrata.
  DateTime? get riferimento => dataOraPrevista ?? dataOraRegistrata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmacoId': farmacoId,
        'dataOraPrevista': dataOraPrevista?.toIso8601String(),
        'dataOraRegistrata': dataOraRegistrata?.toIso8601String(),
        'stato': statoIdx,
        'origine': origineIdx,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Tollerante ai campi mancanti o di tipo inatteso.
  factory AssunzioneFarmaco.fromJson(Map<String, dynamic> json) =>
      AssunzioneFarmaco(
        id: json['id'] as String,
        farmacoId: (json['farmacoId'] as String?) ?? '',
        dataOraPrevista: DateTime.tryParse(json['dataOraPrevista'] as String? ?? ''),
        dataOraRegistrata:
            DateTime.tryParse(json['dataOraRegistrata'] as String? ?? ''),
        statoIdx: (json['stato'] as num?)?.toInt() ?? 2,
        origineIdx: (json['origine'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
