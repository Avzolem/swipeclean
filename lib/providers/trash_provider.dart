import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/trash_item.dart';
import '../services/storage_service.dart';
import '../services/photo_service.dart';
import '../utils/formatters.dart' as utils;

class TrashProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final PhotoService _photoService = PhotoService();

  List<TrashItem> _trashItems = [];
  Set<String> _selectedItems = {};
  bool _isDeleting = false;
  int _estimatedSpaceBytes = 0;
  bool _isCalculatingSpace = false;

  List<TrashItem> get trashItems => _trashItems;
  Set<String> get selectedItems => _selectedItems;
  bool get isDeleting => _isDeleting;
  int get trashCount => _trashItems.length;
  int get selectedCount => _selectedItems.length;
  bool get hasSelection => _selectedItems.isNotEmpty;
  int get estimatedSpaceBytes => _estimatedSpaceBytes;
  bool get isCalculatingSpace => _isCalculatingSpace;

  /// Formatea bytes a string legible (KB, MB, GB)
  static String formatBytes(int bytes) => utils.formatBytes(bytes);

  /// Calcula el espacio aproximado a liberar
  Future<void> calculateSpace() async {
    if (_trashItems.isEmpty) {
      _estimatedSpaceBytes = 0;
      notifyListeners();
      return;
    }

    _isCalculatingSpace = true;
    notifyListeners();

    int totalBytes = 0;
    final itemsWithoutSize = <TrashItem>[];

    // Primero usar los tamaños almacenados (instantáneo)
    for (final item in _trashItems) {
      if (item.width != null && item.height != null) {
        totalBytes += item.estimatedSizeBytes;
      } else {
        itemsWithoutSize.add(item);
      }
    }

    // Solo para items antiguos sin tamaño, hacer lookup (migración gradual)
    for (final item in itemsWithoutSize) {
      try {
        final asset = await AssetEntity.fromId(item.photoId);
        if (asset != null) {
          totalBytes += (asset.width * asset.height * 0.5).toInt();
        }
      } catch (e) {
        // Ignorar errores
      }
    }

    _estimatedSpaceBytes = totalBytes;
    _isCalculatingSpace = false;
    notifyListeners();
  }

  /// Calcula espacio para items seleccionados
  /// Usa los datos almacenados directamente para evitar problemas de sincronización
  int calculateSelectedSpace() {
    if (_selectedItems.isEmpty) return 0;

    int totalBytes = 0;
    for (final item in _trashItems) {
      if (_selectedItems.contains(item.photoId)) {
        totalBytes += item.estimatedSizeBytes;
      }
    }
    return totalBytes;
  }

  void loadTrash() {
    _trashItems = _storageService.getTrashItems();
    _trashItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    notifyListeners();
    // Calcular espacio en background
    calculateSpace();
  }

  /// Agrega una foto a la papelera
  /// NOTA: Este método tiene coupling intencional con markAsReviewed() porque
  /// toda foto en papelera debe marcarse como revisada para evitar que aparezca
  /// de nuevo en el flujo de swipe. Si se necesita agregar a papelera sin marcar
  /// como revisada, crear un método separado.
  Future<void> addToTrash(
    String photoId, {
    String? thumbnailPath,
    int? width,
    int? height,
  }) async {
    await _storageService.addToTrash(
      photoId,
      thumbnailPath: thumbnailPath,
      width: width,
      height: height,
    );
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
  /// Usa notificación retrasada para evitar race conditions sin afectar la UI del CardSwiper
  Future<void> undoAddToTrash(String photoId) async {
    await _storageService.removeFromTrash(photoId);
    await _storageService.unmarkAsReviewed(photoId);
    // Actualizar lista local
    _trashItems = _storageService.getTrashItems();
    _trashItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    // Notificar con delay mínimo para evitar conflicto con CardSwiper pero mantener consistencia
    Future.microtask(() => notifyListeners());
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

  /// Reinicia solo las fotos conservadas (NO afecta la papelera ni su conteo)
  Future<void> resetKeptPhotosOnly() async {
    await _storageService.clearKeptPhotosOnly();
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

  /// Reinicia solo las fotos de un álbum específico
  Future<void> resetAlbum(List<String> photoIds) async {
    await _storageService.resetAlbumPhotos(photoIds);
    // Recargar papelera porque algunas fotos pueden haber sido quitadas
    loadTrash();
  }
}
