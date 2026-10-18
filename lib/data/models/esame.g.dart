// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esame.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EsameAdapter extends TypeAdapter<Esame> {
  @override
  final int typeId = 1;

  @override
  Esame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Esame(
      id: fields[0] as String,
      tipo: fields[1] as String,
      data: fields[2] as DateTime,
      valori: (fields[3] as List?)?.cast<ValoreEsame>(),
      laboratorio: fields[4] as String?,
      medico: fields[5] as String?,
      note: fields[6] as String?,
      allegato: fields[7] as String?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Esame obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipo)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.valori)
      ..writeByte(4)
      ..write(obj.laboratorio)
      ..writeByte(5)
      ..write(obj.medico)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.allegato)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EsameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ValoreEsameAdapter extends TypeAdapter<ValoreEsame> {
  @override
  final int typeId = 7;

  @override
  ValoreEsame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ValoreEsame(
      nome: fields[0] as String,
      valore: fields[1] as String,
      unita: fields[2] as String?,
      riferimentoMin: fields[3] as String?,
      riferimentoMax: fields[4] as String?,
      fuoriRange: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ValoreEsame obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.nome)
      ..writeByte(1)
      ..write(obj.valore)
      ..writeByte(2)
      ..write(obj.unita)
      ..writeByte(3)
      ..write(obj.riferimentoMin)
      ..writeByte(4)
      ..write(obj.riferimentoMax)
      ..writeByte(5)
      ..write(obj.fuoriRange);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValoreEsameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
