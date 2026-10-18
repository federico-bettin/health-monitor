import 'package:hive/hive.dart';

part 'appuntamento.g.dart';

@HiveType(typeId: 4)
class Appuntamento extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String titolo;

  @HiveField(2)
  DateTime data;

  @HiveField(3)
  String? ora;

  @HiveField(4)
  TipoAppuntamento tipo;

  @HiveField(5)
  String? medico;

  @HiveField(6)
  String? struttura;

  @HiveField(7)
  String? indirizzo;

  @HiveField(8)
  String? note;

  @HiveField(9)
  bool completato;

  @HiveField(10)
  bool promemoria;

  @HiveField(11)
  DateTime updatedAt;

  /// Costo della visita/esame (€). null = non indicato.
  @HiveField(12)
  double? costo;

  Appuntamento({
    required this.id,
    required this.titolo,
    required this.data,
    this.ora,
    this.tipo = TipoAppuntamento.visita,
    this.medico,
    this.struttura,
    this.indirizzo,
    this.note,
    this.completato = false,
    this.promemoria = true,
    DateTime? updatedAt,
    this.costo,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isPassato => data.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'titolo': titolo,
        'data': data.toIso8601String(),
        'ora': ora,
        'tipo': tipo.name,
        'medico': medico,
        'struttura': struttura,
        'indirizzo': indirizzo,
        'note': note,
        'completato': completato,
        'promemoria': promemoria,
        'updatedAt': updatedAt.toIso8601String(),
        'costo': costo,
      };

  factory Appuntamento.fromJson(Map<String, dynamic> json) => Appuntamento(
        id: json['id'],
        titolo: json['titolo'],
        data: DateTime.parse(json['data']),
        ora: json['ora'],
        tipo: TipoAppuntamento.values.firstWhere(
          (e) => e.name == json['tipo'],
          orElse: () => TipoAppuntamento.visita,
        ),
        medico: json['medico'],
        struttura: json['struttura'],
        indirizzo: json['indirizzo'],
        note: json['note'],
        completato: json['completato'] ?? false,
        promemoria: json['promemoria'] ?? true,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
        costo: (json['costo'] as num?)?.toDouble(),
      );
}

@HiveType(typeId: 8)
enum TipoAppuntamento {
  @HiveField(0)
  visita,
  @HiveField(1)
  esame,
  @HiveField(2)
  farmaco,
  @HiveField(3)
  altro,
}
