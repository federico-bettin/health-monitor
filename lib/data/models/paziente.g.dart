// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paziente.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PazienteAdapter extends TypeAdapter<Paziente> {
  @override
  final int typeId = 0;

  @override
  Paziente read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Paziente(
      nome: fields[0] as String,
      cognome: fields[1] as String,
      dataNascita: fields[2] as DateTime?,
      gruppaSanguigno: fields[3] as String?,
      codiceFiscale: fields[4] as String?,
      medico: fields[5] as String?,
      telefono: fields[6] as String?,
      email: fields[7] as String?,
      allergie: (fields[8] as List?)?.cast<String>(),
      patologieCroniche: (fields[9] as List?)?.cast<String>(),
      note: fields[10] as String?,
      updatedAt: fields[11] as DateTime?,
      peso: fields[12] as double?,
      altezza: fields[13] as double?,
      anamnesi: fields[14] as String?,
      fumo: fields[15] as bool?,
      sigaretteGiorno: fields[16] as int?,
      alcool: fields[17] as bool?,
      bicchieriGiorno: fields[18] as int?,
      passiGiornoManuale: fields[19] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Paziente obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.nome)
      ..writeByte(1)
      ..write(obj.cognome)
      ..writeByte(2)
      ..write(obj.dataNascita)
      ..writeByte(3)
      ..write(obj.gruppaSanguigno)
      ..writeByte(4)
      ..write(obj.codiceFiscale)
      ..writeByte(5)
      ..write(obj.medico)
      ..writeByte(6)
      ..write(obj.telefono)
      ..writeByte(7)
      ..write(obj.email)
      ..writeByte(8)
      ..write(obj.allergie)
      ..writeByte(9)
      ..write(obj.patologieCroniche)
      ..writeByte(10)
      ..write(obj.note)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.peso)
      ..writeByte(13)
      ..write(obj.altezza)
      ..writeByte(14)
      ..write(obj.anamnesi)
      ..writeByte(15)
      ..write(obj.fumo)
      ..writeByte(16)
      ..write(obj.sigaretteGiorno)
      ..writeByte(17)
      ..write(obj.alcool)
      ..writeByte(18)
      ..write(obj.bicchieriGiorno)
      ..writeByte(19)
      ..write(obj.passiGiornoManuale);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PazienteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
