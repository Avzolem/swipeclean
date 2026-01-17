// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrashItemAdapter extends TypeAdapter<TrashItem> {
  @override
  final int typeId = 0;

  @override
  TrashItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrashItem(
      photoId: fields[0] as String,
      addedAt: fields[1] as DateTime,
      thumbnailPath: fields[2] as String?,
      width: fields[3] as int?,
      height: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TrashItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.photoId)
      ..writeByte(1)
      ..write(obj.addedAt)
      ..writeByte(2)
      ..write(obj.thumbnailPath)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrashItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
