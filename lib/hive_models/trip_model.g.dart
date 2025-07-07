// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripLogAdapter extends TypeAdapter<TripLog> {
  @override
  final int typeId = 1;

  @override
  TripLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripLog(
      tripId: fields[0] as String,
      startTime: fields[1] as DateTime,
      startLat: fields[2] as double,
      startLong: fields[3] as double,
      destinationsBefore: (fields[4] as List).cast<String>(),
      destinationsDuring: (fields[5] as List).cast<String>(),
      turnLogs: (fields[6] as List).cast<TurnLog>(),
      endLat: fields[7] as double?,
      endLong: fields[8] as double?,
      endTime: fields[9] as DateTime?,
      endReason: fields[10] as String?,
      isTripCompleted: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TripLog obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.startLat)
      ..writeByte(3)
      ..write(obj.startLong)
      ..writeByte(4)
      ..write(obj.destinationsBefore)
      ..writeByte(5)
      ..write(obj.destinationsDuring)
      ..writeByte(6)
      ..write(obj.turnLogs)
      ..writeByte(7)
      ..write(obj.endLat)
      ..writeByte(8)
      ..write(obj.endLong)
      ..writeByte(9)
      ..write(obj.endTime)
      ..writeByte(10)
      ..write(obj.endReason)
      ..writeByte(11)
      ..write(obj.isTripCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
