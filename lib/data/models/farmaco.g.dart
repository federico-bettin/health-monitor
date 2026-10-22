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
      frequenzaTipoIdx: fields[12] == null ? 0 : fields[12] as int,
      giorniSettimana: (fields[13] as List?)?.cast<int>(),
      ogniNGiorni: fields[14] as int?,
      promemoriaAttivo: fields[15] == null ? false : fields[15] as bool,
      istruzioni: fields[16] as String?,
      archiviato: fields[17] == null ? false : fields[17] as bool,
      scorte: fields[18] as double?,
      unitaPerDose: fields[19] as double?,
      sogliaScorteGiorni: fields[20] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Farmaco obj) {
    writer
      ..writeByte(21)
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
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.frequenzaTipoIdx)
      ..writeByte(13)
      ..write(obj.giorniSettimana)
      ..writeByte(14)
      ..write(obj.ogniNGiorni)
      ..writeByte(15)
      ..write(obj.promemoriaAttivo)
      ..writeByte(16)
      ..write(obj.istruzioni)
      ..writeByte(17)
      ..write(obj.archiviato)
      ..writeByte(18)
      ..write(obj.scorte)
      ..writeByte(19)
      ..write(obj.unitaPerDose)
      ..writeByte(20)
      ..write(obj.sogliaScorteGiorni);
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
