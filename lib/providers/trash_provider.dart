import 'package:flutter/foundation.dart';
import '../models/trash_item.dart';
import '../services/storage_service.dart';
import '../services/photo_service.dart';

class TrashProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final PhotoService _photoService = PhotoService();

  List<TrashItem> _trashItems = [];
  Set<String> _selectedItems = {};
  bool _isDeleting = false;

  List<TrashItem> get trashItems => _trashItems;
  Set<String> get selectedItems => _selectedItems;
  bool get isDeleting => _isDeleting;
  int get trashCount => _trashItems.length;
  int get selectedCount => _selectedItems.length;
  bool get hasSelection => _selectedItems.isNotEmpty;

  void loadTrash() {
    _trashItems = _storageService.getTrashItems();
    _trashItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    notifyListeners();
  }

  Future<void> addToTrash(String photoId, {String? thumbnailPath}) async {
    await _storageService.addToTrash(photoId, thumbnailPath: thumbnailPath);
    await _storageService.markAsReviewed(photoId);
    loadTrash();
  }

  Future<void> keepPhoto(String photoId) async {
    await _storageService.markAsReviewed(photoId);
    notifyListeners();
  }

  Future<void> restoreFromTrash(String photoId) async {
    await _storageService.removeFromTrash(photoId);
    loadTrash();
  }

  void toggleSelection(String photoId) {
    if (_selectedItems.contains(photoId)) {
      _selectedItems.remove(photoId);
    } else {
      _selectedItems.add(photoId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedItems = _trashItems.map((item) => item.photoId).toSet();
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  Future<bool> deleteSelected() async {
    if (_selectedItems.isEmpty) return false;

    _isDeleting = true;
    notifyListeners();

    try {
      final success = await _photoService.deletePhotos(_selectedItems.toList());

      if (success) {
        for (final photoId in _selectedItems) {
          await _storageService.removeFromTrash(photoId);
        }
        _selectedItems.clear();
        loadTrash();
      }

      _isDeleting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAll() async {
    selectAll();
    return deleteSelected();
  }

  int get reviewedCount => _storageService.reviewedCount;
}
