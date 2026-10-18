import 'package:hive/hive.dart';

part 'visita.g.dart';

@HiveType(typeId: 2)
class Visita extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String specialita;

  @HiveField(2)
  DateTime data;

  @HiveField(3)
  String? medico;

  @HiveField(4)
  String? struttura;

  @HiveField(5)
  String? diagnosi;

  @HiveField(6)
  String? terapia;

  @HiveField(7)
  List<String> farmaciPrescritti;

  @HiveField(8)
  String? note;

  @HiveField(9)
  String? allegato;

  @HiveField(10)
  DateTime updatedAt;

  Visita({
    required this.id,
    required this.specialita,
    required this.data,
    this.medico,
    this.struttura,
    this.diagnosi,
    this.terapia,
    List<String>? farmaciPrescritti,
    this.note,
    this.allegato,
    DateTime? updatedAt,
  })  : farmaciPrescritti = farmaciPrescritti ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'specialita': specialita,
        'data': data.toIso8601String(),
        'medico': medico,
        'struttura': struttura,
        'diagnosi': diagnosi,
        'terapia': terapia,
        'farmaciPrescritti': farmaciPrescritti,
        'note': note,
        'allegato': allegato,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Visita.fromJson(Map<String, dynamic> json) => Visita(
        id: json['id'],
        specialita: json['specialita'],
        data: DateTime.parse(json['data']),
        medico: json['medico'],
        struttura: json['struttura'],
        diagnosi: json['diagnosi'],
        terapia: json['terapia'],
        farmaciPrescritti: List<String>.from(json['farmaciPrescritti'] ?? []),
        note: json['note'],
        allegato: json['allegato'],
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );
}
