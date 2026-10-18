// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visita.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisitaAdapter extends TypeAdapter<Visita> {
  @override
  final int typeId = 2;

  @override
  Visita read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Visita(
      id: fields[0] as String,
      specialita: fields[1] as String,
      data: fields[2] as DateTime,
      medico: fields[3] as String?,
      struttura: fields[4] as String?,
      diagnosi: fields[5] as String?,
      terapia: fields[6] as String?,
      farmaciPrescritti: (fields[7] as List?)?.cast<String>(),
      note: fields[8] as String?,
      allegato: fields[9] as String?,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Visita obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.specialita)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.medico)
      ..writeByte(4)
      ..write(obj.struttura)
      ..writeByte(5)
      ..write(obj.diagnosi)
      ..writeByte(6)
      ..write(obj.terapia)
      ..writeByte(7)
      ..write(obj.farmaciPrescritti)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.allegato)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
