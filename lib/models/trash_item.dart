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

  TrashItem({
    required this.photoId,
    required this.addedAt,
    this.thumbnailPath,
  });
}
