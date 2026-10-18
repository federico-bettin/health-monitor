import 'package:hive/hive.dart';

part 'farmaco.g.dart';

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
  })  : orariAssunzione = orariAssunzione ?? [],
        updatedAt = updatedAt ?? DateTime.now();

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
      );
}
