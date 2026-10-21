// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assunzione_farmaco.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AssunzioneFarmacoAdapter extends TypeAdapter<AssunzioneFarmaco> {
  @override
  final int typeId = 9;

  @override
  AssunzioneFarmaco read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssunzioneFarmaco(
      id: fields[0] as String,
      farmacoId: fields[1] as String,
      dataOraPrevista: fields[2] as DateTime?,
      dataOraRegistrata: fields[3] as DateTime?,
      statoIdx: fields[4] == null ? 2 : fields[4] as int,
      origineIdx: fields[5] == null ? 1 : fields[5] as int,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AssunzioneFarmaco obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.farmacoId)
      ..writeByte(2)
      ..write(obj.dataOraPrevista)
      ..writeByte(3)
      ..write(obj.dataOraRegistrata)
      ..writeByte(4)
      ..write(obj.statoIdx)
      ..writeByte(5)
      ..write(obj.origineIdx)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssunzioneFarmacoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
