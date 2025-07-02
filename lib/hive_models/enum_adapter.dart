import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TurnDirectionAdapter extends TypeAdapter<TurnDirection> {
  @override
  final int typeId = 3;

  @override
  TurnDirection read(BinaryReader reader) {
    return TurnDirection.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, TurnDirection obj) {
    writer.writeInt(obj.index);
  }
}
