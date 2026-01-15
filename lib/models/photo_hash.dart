import 'package:hive/hive.dart';

part 'photo_hash.g.dart';

@HiveType(typeId: 1)
class PhotoHash extends HiveObject {
  @HiveField(0)
  final String photoId;

  @HiveField(1)
  final int hash;

  @HiveField(2)
  final int size;

  @HiveField(3)
  final DateTime calculatedAt;

  PhotoHash({
    required this.photoId,
    required this.hash,
    required this.size,
    required this.calculatedAt,
  });
}

@HiveType(typeId: 2)
class DuplicateResult extends HiveObject {
  @HiveField(0)
  final List<List<String>> groups; // Lista de grupos de IDs de fotos

  @HiveField(1)
  final DateTime scannedAt;

  @HiveField(2)
  final int totalPhotosAnalyzed;

  DuplicateResult({
    required this.groups,
    required this.scannedAt,
    required this.totalPhotosAnalyzed,
  });
}
