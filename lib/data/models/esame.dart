import 'package:hive/hive.dart';

part 'esame.g.dart';

@HiveType(typeId: 1)
class Esame extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String tipo; // es. "Emocromo", "Glicemia", "Colesterolo"

  @HiveField(2)
  DateTime data;

  @HiveField(3)
  List<ValoreEsame> valori;

  @HiveField(4)
  String? laboratorio;

  @HiveField(5)
  String? medico;

  @HiveField(6)
  String? note;

  @HiveField(7)
  String? allegato; // path locale o ID Drive del PDF

  @HiveField(8)
  DateTime updatedAt;

  Esame({
    required this.id,
    required this.tipo,
    required this.data,
    List<ValoreEsame>? valori,
    this.laboratorio,
    this.medico,
    this.note,
    this.allegato,
    DateTime? updatedAt,
  })  : valori = valori ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'data': data.toIso8601String(),
        'valori': valori.map((v) => v.toJson()).toList(),
        'laboratorio': laboratorio,
        'medico': medico,
        'note': note,
        'allegato': allegato,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Esame.fromJson(Map<String, dynamic> json) => Esame(
        id: json['id'],
        tipo: json['tipo'],
        data: DateTime.parse(json['data']),
        valori: (json['valori'] as List? ?? [])
            .map((v) => ValoreEsame.fromJson(v))
            .toList(),
        laboratorio: json['laboratorio'],
        medico: json['medico'],
        note: json['note'],
        allegato: json['allegato'],
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );
}

@HiveType(typeId: 7)
class ValoreEsame extends HiveObject {
  @HiveField(0)
  String nome;

  @HiveField(1)
  String valore;

  @HiveField(2)
  String? unita;

  @HiveField(3)
  String? riferimentoMin;

  @HiveField(4)
  String? riferimentoMax;

  @HiveField(5)
  bool fuoriRange;

  ValoreEsame({
    required this.nome,
    required this.valore,
    this.unita,
    this.riferimentoMin,
    this.riferimentoMax,
    this.fuoriRange = false,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'valore': valore,
        'unita': unita,
        'riferimentoMin': riferimentoMin,
        'riferimentoMax': riferimentoMax,
        'fuoriRange': fuoriRange,
      };

  factory ValoreEsame.fromJson(Map<String, dynamic> json) => ValoreEsame(
        nome: json['nome'],
        valore: json['valore'],
        unita: json['unita'],
        riferimentoMin: json['riferimentoMin'],
        riferimentoMax: json['riferimentoMax'],
        fuoriRange: json['fuoriRange'] ?? false,
      );
}
