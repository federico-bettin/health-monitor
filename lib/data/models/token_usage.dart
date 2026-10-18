import 'package:hive/hive.dart';

part 'token_usage.g.dart';

@HiveType(typeId: 6)
class TokenUsage extends HiveObject {
  @HiveField(0)
  DateTime data;

  @HiveField(1)
  int tokensInput;

  @HiveField(2)
  int tokensOutput;

  @HiveField(3)
  String operazione; // es. "import_documento", "analisi_esame"

  TokenUsage({
    required this.data,
    required this.tokensInput,
    required this.tokensOutput,
    required this.operazione,
  });

  int get tokensTotal => tokensInput + tokensOutput;

  // Costo approssimativo in USD (claude-sonnet-4)
  double get costoUsd => (tokensInput * 0.000003) + (tokensOutput * 0.000015);

  Map<String, dynamic> toJson() => {
        'data': data.toIso8601String(),
        'tokensInput': tokensInput,
        'tokensOutput': tokensOutput,
        'operazione': operazione,
      };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        data: DateTime.parse(json['data']),
        tokensInput: json['tokensInput'] ?? 0,
        tokensOutput: json['tokensOutput'] ?? 0,
        operazione: json['operazione'] ?? '',
      );
}
