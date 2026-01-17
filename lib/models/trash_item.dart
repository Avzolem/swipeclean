import 'package:hive/hive.dart';

part 'trash_item.g.dart';

@HiveType(typeId: 0)
class TrashItem extends HiveObject {
  @HiveField(0)
  final String photoId;

  @HiveField(1)
  final DateTime addedAt;

  @HiveField(2)
  final String? thumbnailPath;

  @HiveField(3)
  final int? width;

  @HiveField(4)
  final int? height;

  TrashItem({
    required this.photoId,
    required this.addedAt,
    this.thumbnailPath,
    this.width,
    this.height,
  });

  /// Calcula el tamaño aproximado del archivo en bytes
  int get estimatedSizeBytes {
    if (width == null || height == null) return 0;
    return (width! * height! * 0.5).toInt();
  }
}
