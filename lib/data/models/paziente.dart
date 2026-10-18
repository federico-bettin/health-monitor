import 'package:hive/hive.dart';

part 'paziente.g.dart';

@HiveType(typeId: 0)
class Paziente extends HiveObject {
  @HiveField(0)
  String nome;

  @HiveField(1)
  String cognome;

  @HiveField(2)
  DateTime? dataNascita;

  @HiveField(3)
  String? gruppaSanguigno;

  @HiveField(4)
  String? codiceFiscale;

  @HiveField(5)
  String? medico;

  @HiveField(6)
  String? telefono;

  @HiveField(7)
  String? email;

  @HiveField(8)
  List<String> allergie;

  @HiveField(9)
  List<String> patologieCroniche;

  @HiveField(10)
  String? note;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  double? peso; // kg

  @HiveField(13)
  double? altezza; // cm

  @HiveField(14)
  String? anamnesi; // storia clinica libera

  // ─── Stile di vita ────────────────────────────────────────
  @HiveField(15)
  bool? fumo;

  @HiveField(16)
  int? sigaretteGiorno;

  @HiveField(17)
  bool? alcool;

  @HiveField(18)
  int? bicchieriGiorno;

  /// Passi giornalieri stimati — usato solo se ring non connesso.
  /// Se ring connesso, si usa passiMedi da WearableData.
  @HiveField(19)
  int? passiGiornoManuale;

  Paziente({
    required this.nome,
    required this.cognome,
    this.dataNascita,
    this.gruppaSanguigno,
    this.codiceFiscale,
    this.medico,
    this.telefono,
    this.email,
    List<String>? allergie,
    List<String>? patologieCroniche,
    this.note,
    DateTime? updatedAt,
    this.peso,
    this.altezza,
    this.anamnesi,
    this.fumo,
    this.sigaretteGiorno,
    this.alcool,
    this.bicchieriGiorno,
    this.passiGiornoManuale,
  })  : allergie = allergie ?? [],
        patologieCroniche = patologieCroniche ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String get nomeCompleto => '$nome $cognome';

  int? get eta {
    if (dataNascita == null) return null;
    final oggi = DateTime.now();
    int anni = oggi.year - dataNascita!.year;
    if (oggi.month < dataNascita!.month ||
        (oggi.month == dataNascita!.month && oggi.day < dataNascita!.day)) {
      anni--;
    }
    return anni;
  }

  double? get bmi {
    if (peso == null || altezza == null || altezza! <= 0) return null;
    final altezzaM = altezza! / 100;
    return peso! / (altezzaM * altezzaM);
  }

  String get bmiCategoria {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return 'Sottopeso';
    if (b < 25) return 'Normopeso';
    if (b < 30) return 'Sovrappeso';
    return 'Obesità';
  }

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'cognome': cognome,
        'dataNascita': dataNascita?.toIso8601String(),
        'gruppaSanguigno': gruppaSanguigno,
        'codiceFiscale': codiceFiscale,
        'medico': medico,
        'telefono': telefono,
        'email': email,
        'allergie': allergie,
        'patologieCroniche': patologieCroniche,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
        'peso': peso,
        'altezza': altezza,
        'bmi': bmi,
        'bmiCategoria': bmiCategoria,
        'anamnesi': anamnesi,
        'fumo': fumo ?? false,
        'sigarette_giorno': sigaretteGiorno,
        'alcool': alcool ?? false,
        'bicchieri_giorno': bicchieriGiorno,
        'passi_giorno_manuale': passiGiornoManuale,
      };

  factory Paziente.fromJson(Map<String, dynamic> json) => Paziente(
        nome: json['nome'] ?? '',
        cognome: json['cognome'] ?? '',
        dataNascita: json['dataNascita'] != null
            ? DateTime.parse(json['dataNascita'])
            : null,
        gruppaSanguigno: json['gruppaSanguigno'],
        codiceFiscale: json['codiceFiscale'],
        medico: json['medico'],
        telefono: json['telefono'],
        email: json['email'],
        allergie: List<String>.from(json['allergie'] ?? []),
        patologieCroniche: List<String>.from(json['patologieCroniche'] ?? []),
        note: json['note'],
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
        peso: (json['peso'] as num?)?.toDouble(),
        altezza: (json['altezza'] as num?)?.toDouble(),
        anamnesi: json['anamnesi'],
        fumo: json['fumo'] as bool? ?? false,
        sigaretteGiorno: json['sigarette_giorno'] as int?,
        alcool: json['alcool'] as bool? ?? false,
        bicchieriGiorno: json['bicchieri_giorno'] as int?,
        passiGiornoManuale: json['passi_giorno_manuale'] as int?,
      );
}
