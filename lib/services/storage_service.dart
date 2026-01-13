import 'package:hive_flutter/hive_flutter.dart';
import '../models/trash_item.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _trashBoxName = 'trash';
  static const String _reviewedBoxName = 'reviewed';

  Box<TrashItem>? _trashBox;
  Box<String>? _reviewedBox;

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TrashItemAdapter());
    }

    _trashBox = await Hive.openBox<TrashItem>(_trashBoxName);
    _reviewedBox = await Hive.openBox<String>(_reviewedBoxName);
  }

  // Trash operations
  Future<void> addToTrash(String photoId, {String? thumbnailPath}) async {
    final item = TrashItem(
      photoId: photoId,
      addedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
    await _trashBox?.put(photoId, item);
  }

  Future<void> removeFromTrash(String photoId) async {
    await _trashBox?.delete(photoId);
  }

  Future<void> clearTrash() async {
    await _trashBox?.clear();
  }

  List<TrashItem> getTrashItems() {
    return _trashBox?.values.toList() ?? [];
  }

  bool isInTrash(String photoId) {
    return _trashBox?.containsKey(photoId) ?? false;
  }

  int get trashCount => _trashBox?.length ?? 0;

  // Reviewed photos operations
  Future<void> markAsReviewed(String photoId) async {
    await _reviewedBox?.put(photoId, photoId);
  }

  bool isReviewed(String photoId) {
    return _reviewedBox?.containsKey(photoId) ?? false;
  }

  int get reviewedCount => _reviewedBox?.length ?? 0;

  Future<void> clearReviewed() async {
    await _reviewedBox?.clear();
  }

  // Get unreviewed photos
  List<String> getReviewedPhotoIds() {
    return _reviewedBox?.values.toList() ?? [];
  }
}
