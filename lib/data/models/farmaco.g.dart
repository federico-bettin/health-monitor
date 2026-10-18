// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmaco.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FarmacoAdapter extends TypeAdapter<Farmaco> {
  @override
  final int typeId = 3;

  @override
  Farmaco read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Farmaco(
      id: fields[0] as String,
      nome: fields[1] as String,
      principioAttivo: fields[2] as String?,
      dosaggio: fields[3] as String,
      frequenza: fields[4] as String,
      dataInizio: fields[5] as DateTime?,
      dataFine: fields[6] as DateTime?,
      attivo: fields[7] as bool,
      medico: fields[8] as String?,
      note: fields[9] as String?,
      orariAssunzione: (fields[10] as List?)?.cast<String>(),
      updatedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Farmaco obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.principioAttivo)
      ..writeByte(3)
      ..write(obj.dosaggio)
      ..writeByte(4)
      ..write(obj.frequenza)
      ..writeByte(5)
      ..write(obj.dataInizio)
      ..writeByte(6)
      ..write(obj.dataFine)
      ..writeByte(7)
      ..write(obj.attivo)
      ..writeByte(8)
      ..write(obj.medico)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.orariAssunzione)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FarmacoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
