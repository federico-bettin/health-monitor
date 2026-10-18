// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_usage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenUsageAdapter extends TypeAdapter<TokenUsage> {
  @override
  final int typeId = 6;

  @override
  TokenUsage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenUsage(
      data: fields[0] as DateTime,
      tokensInput: fields[1] as int,
      tokensOutput: fields[2] as int,
      operazione: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TokenUsage obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.data)
      ..writeByte(1)
      ..write(obj.tokensInput)
      ..writeByte(2)
      ..write(obj.tokensOutput)
      ..writeByte(3)
      ..write(obj.operazione);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenUsageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
