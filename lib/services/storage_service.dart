import 'package:hive_flutter/hive_flutter.dart';
import '../models/trash_item.dart';
import '../models/photo_hash.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _trashBoxName = 'trash';
  static const String _reviewedBoxName = 'reviewed';
  static const String _hashBoxName = 'photo_hashes';
  static const String _duplicateBoxName = 'duplicate_results';
  static const String _photoCacheBoxName = 'photo_cache';
  static const String _settingsBoxName = 'settings';

  Box<TrashItem>? _trashBox;
  Box<String>? _reviewedBox;
  Box<PhotoHash>? _hashBox;
  Box<DuplicateResult>? _duplicateBox;
  Box<dynamic>? _photoCacheBox;
  Box<dynamic>? _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TrashItemAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PhotoHashAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DuplicateResultAdapter());
    }

    _trashBox = await Hive.openBox<TrashItem>(_trashBoxName);
    _reviewedBox = await Hive.openBox<String>(_reviewedBoxName);
    _hashBox = await Hive.openBox<PhotoHash>(_hashBoxName);
    _duplicateBox = await Hive.openBox<DuplicateResult>(_duplicateBoxName);
    _photoCacheBox = await Hive.openBox<dynamic>(_photoCacheBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
  }

  // Trash operations
  Future<void> addToTrash(
    String photoId, {
    String? thumbnailPath,
    int? width,
    int? height,
  }) async {
    final item = TrashItem(
      photoId: photoId,
      addedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      width: width,
      height: height,
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

  Future<void> unmarkAsReviewed(String photoId) async {
    await _reviewedBox?.delete(photoId);
  }

  bool isReviewed(String photoId) {
    return _reviewedBox?.containsKey(photoId) ?? false;
  }

  int get reviewedCount => _reviewedBox?.length ?? 0;

  Future<void> clearReviewed() async {
    await _reviewedBox?.clear();
  }

  /// Borra solo las fotos conservadas (reviewed pero NO en trash)
  Future<void> clearKeptPhotosOnly() async {
    final reviewedIds = _reviewedBox?.keys.toList() ?? [];
    for (final photoId in reviewedIds) {
      // Solo borrar si NO está en la papelera
      if (!(_trashBox?.containsKey(photoId) ?? false)) {
        await _reviewedBox?.delete(photoId);
      }
    }
  }

  // Get unreviewed photos
  List<String> getReviewedPhotoIds() {
    return _reviewedBox?.values.toList() ?? [];
  }

  // Hash operations
  Future<void> saveHash(String photoId, int hash, int size) async {
    final item = PhotoHash(
      photoId: photoId,
      hash: hash,
      size: size,
      calculatedAt: DateTime.now(),
    );
    await _hashBox?.put(photoId, item);
  }

  PhotoHash? getHash(String photoId) {
    return _hashBox?.get(photoId);
  }

  Map<String, PhotoHash> getAllHashes() {
    final map = <String, PhotoHash>{};
    _hashBox?.toMap().forEach((key, value) {
      map[key.toString()] = value;
    });
    return map;
  }

  int get hashCount => _hashBox?.length ?? 0;

  Future<void> clearHashes() async {
    await _hashBox?.clear();
  }

  // Duplicate results operations
  Future<void> saveDuplicateResult(List<List<String>> groups, int totalPhotos) async {
    final result = DuplicateResult(
      groups: groups,
      scannedAt: DateTime.now(),
      totalPhotosAnalyzed: totalPhotos,
    );
    await _duplicateBox?.put('latest', result);
  }

  DuplicateResult? getLastDuplicateResult() {
    return _duplicateBox?.get('latest');
  }

  Future<void> clearDuplicateResults() async {
    await _duplicateBox?.clear();
  }

  // Photo cache operations - para carga rápida
  Future<void> savePhotoCache(List<String> photoIds, int totalCount) async {
    await _photoCacheBox?.put('photo_ids', photoIds);
    await _photoCacheBox?.put('total_count', totalCount);
    await _photoCacheBox?.put('cached_at', DateTime.now().millisecondsSinceEpoch);
  }

  List<String>? getCachedPhotoIds() {
    final ids = _photoCacheBox?.get('photo_ids');
    if (ids == null) return null;
    return List<String>.from(ids);
  }

  int? getCachedPhotoCount() {
    return _photoCacheBox?.get('total_count');
  }

  int? getCacheTimestamp() {
    return _photoCacheBox?.get('cached_at');
  }

  bool hasValidCache() {
    final ids = _photoCacheBox?.get('photo_ids');
    final count = _photoCacheBox?.get('total_count');
    return ids != null && count != null;
  }

  Future<void> clearPhotoCache() async {
    await _photoCacheBox?.clear();
  }

  // Settings operations - Tema
  Future<void> saveTheme(String theme) async {
    await _settingsBox?.put('theme', theme);
  }

  String? getTheme() {
    return _settingsBox?.get('theme');
  }

  // Settings operations - Tutorial
  Future<void> setTutorialShown() async {
    await _settingsBox?.put('tutorial_shown', true);
  }

  bool isTutorialShown() {
    return _settingsBox?.get('tutorial_shown', defaultValue: false) ?? false;
  }

  // Settings operations - Duplicates notification
  Future<void> setDuplicatesNotificationShown(bool shown) async {
    await _settingsBox?.put('duplicates_notification_shown', shown);
  }

  bool isDuplicatesNotificationShown() {
    return _settingsBox?.get('duplicates_notification_shown', defaultValue: false) ?? false;
  }

  /// Resetea el flag de notificación de duplicados
  /// (se llama cuando el usuario agrega nuevas fotos a papelera desde duplicados)
  Future<void> resetDuplicatesNotification() async {
    await _settingsBox?.put('duplicates_notification_shown', false);
  }

  /// Reinicia solo las fotos de un álbum específico
  Future<void> resetAlbumPhotos(List<String> photoIds) async {
    for (final photoId in photoIds) {
      // Quitar de revisadas
      await _reviewedBox?.delete(photoId);
      // Quitar de papelera si está ahí
      await _trashBox?.delete(photoId);
    }
  }
}
