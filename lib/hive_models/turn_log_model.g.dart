// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'turn_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TurnLogAdapter extends TypeAdapter<TurnLog> {
  @override
  final int typeId = 2;

  @override
  TurnLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TurnLog(
      lat: fields[0] as double,
      long: fields[1] as double,
      timestamp: fields[2] as DateTime,
      direction: fields[3] as TurnDirection,
    );
  }

  @override
  void write(BinaryWriter writer, TurnLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.lat)
      ..writeByte(1)
      ..write(obj.long)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.direction);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
