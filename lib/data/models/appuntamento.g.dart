// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appuntamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppuntamentoAdapter extends TypeAdapter<Appuntamento> {
  @override
  final int typeId = 4;

  @override
  Appuntamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Appuntamento(
      id: fields[0] as String,
      titolo: fields[1] as String,
      data: fields[2] as DateTime,
      ora: fields[3] as String?,
      tipo: fields[4] as TipoAppuntamento,
      medico: fields[5] as String?,
      struttura: fields[6] as String?,
      indirizzo: fields[7] as String?,
      note: fields[8] as String?,
      completato: fields[9] as bool,
      promemoria: fields[10] as bool,
      updatedAt: fields[11] as DateTime?,
      costo: fields[12] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Appuntamento obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.titolo)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.ora)
      ..writeByte(4)
      ..write(obj.tipo)
      ..writeByte(5)
      ..write(obj.medico)
      ..writeByte(6)
      ..write(obj.struttura)
      ..writeByte(7)
      ..write(obj.indirizzo)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.completato)
      ..writeByte(10)
      ..write(obj.promemoria)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.costo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppuntamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TipoAppuntamentoAdapter extends TypeAdapter<TipoAppuntamento> {
  @override
  final int typeId = 8;

  @override
  TipoAppuntamento read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TipoAppuntamento.visita;
      case 1:
        return TipoAppuntamento.esame;
      case 2:
        return TipoAppuntamento.farmaco;
      case 3:
        return TipoAppuntamento.altro;
      default:
        return TipoAppuntamento.visita;
    }
  }

  @override
  void write(BinaryWriter writer, TipoAppuntamento obj) {
    switch (obj) {
      case TipoAppuntamento.visita:
        writer.writeByte(0);
        break;
      case TipoAppuntamento.esame:
        writer.writeByte(1);
        break;
      case TipoAppuntamento.farmaco:
        writer.writeByte(2);
        break;
      case TipoAppuntamento.altro:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TipoAppuntamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
