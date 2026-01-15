// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_hash.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoHashAdapter extends TypeAdapter<PhotoHash> {
  @override
  final int typeId = 1;

  @override
  PhotoHash read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoHash(
      photoId: fields[0] as String,
      hash: fields[1] as int,
      size: fields[2] as int,
      calculatedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoHash obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.photoId)
      ..writeByte(1)
      ..write(obj.hash)
      ..writeByte(2)
      ..write(obj.size)
      ..writeByte(3)
      ..write(obj.calculatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoHashAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DuplicateResultAdapter extends TypeAdapter<DuplicateResult> {
  @override
  final int typeId = 2;

  @override
  DuplicateResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DuplicateResult(
      groups: (fields[0] as List)
          .map((dynamic e) => (e as List).cast<String>())
          .toList(),
      scannedAt: fields[1] as DateTime,
      totalPhotosAnalyzed: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DuplicateResult obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.groups)
      ..writeByte(1)
      ..write(obj.scannedAt)
      ..writeByte(2)
      ..write(obj.totalPhotosAnalyzed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicateResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
