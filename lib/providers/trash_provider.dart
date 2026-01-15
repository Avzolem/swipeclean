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

  Future<void> undoKeepPhoto(String photoId) async {
    await _storageService.unmarkAsReviewed(photoId);
    notifyListeners();
  }

  Future<void> restoreFromTrash(String photoId) async {
    await _storageService.removeFromTrash(photoId);
    await _storageService.unmarkAsReviewed(photoId);
    loadTrash();
  }

  /// Método específico para deshacer la acción de agregar a papelera
  /// No dispara notifyListeners para evitar rebuilds prematuros del CardSwiper
  Future<void> undoAddToTrash(String photoId) async {
    await _storageService.removeFromTrash(photoId);
    await _storageService.unmarkAsReviewed(photoId);
    // Actualizar lista local sin notificar
    _trashItems = _storageService.getTrashItems();
    _trashItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    // NO llamar notifyListeners aquí - el CardSwiper manejará el estado
  }

  Future<int> restoreSelected() async {
    if (_selectedItems.isEmpty) return 0;

    int restoredCount = 0;
    for (final photoId in _selectedItems.toList()) {
      await _storageService.removeFromTrash(photoId);
      await _storageService.unmarkAsReviewed(photoId);
      restoredCount++;
    }
    _selectedItems.clear();
    loadTrash();
    return restoredCount;
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

  /// Reinicia el proceso de limpieza (borra historial de revisadas, NO la papelera)
  Future<void> resetReviewProgress() async {
    await _storageService.clearReviewed();
    notifyListeners();
  }

  /// Reinicia todo (revisadas + papelera)
  Future<void> resetAll() async {
    await _storageService.clearReviewed();
    await _storageService.clearTrash();
    _trashItems = [];
    _selectedItems.clear();
    notifyListeners();
  }
}
