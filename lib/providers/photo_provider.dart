import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import '../services/photo_service.dart';
import '../services/storage_service.dart';

class PhotoProvider extends ChangeNotifier {
  final PhotoService _photoService = PhotoService();
  final StorageService _storageService = StorageService();

  List<Photo> _photos = [];
  List<Photo> _unreviewedPhotos = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  String? _error;
  int _currentIndex = 0;

  // Para carga optimizada
  bool _isLoadingMore = false;
  int _totalPhotoCount = 0;

  List<Photo> get photos => _photos;
  List<Photo> get unreviewedPhotos => _unreviewedPhotos;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  int get currentIndex => _currentIndex;
  Photo? get currentPhoto =>
      _unreviewedPhotos.isNotEmpty && _currentIndex < _unreviewedPhotos.length
          ? _unreviewedPhotos[_currentIndex]
          : null;
  int get totalPhotos => _totalPhotoCount > 0 ? _totalPhotoCount : _photos.length;
  int get remainingPhotos {
    final total = totalPhotos;
    final reviewed = _storageService.reviewedCount;
    final inTrash = _storageService.trashCount;
    final pending = total - reviewed - inTrash;
    return pending > 0 ? pending : 0;
  }

  /// Verifica permisos rápidamente sin mostrar diálogo
  Future<bool> quickCheckPermission() async {
    // Si ya verificamos y tenemos permiso, no volver a verificar
    if (_permissionChecked && _hasPermission) {
      return true;
    }

    // Si ya tenemos fotos cargadas, asumimos que tenemos permiso
    if (_photoService.isInitialized && _photos.isNotEmpty) {
      _hasPermission = true;
      _permissionChecked = true;
      return true;
    }

    // Verificar sin solicitar (rápido)
    _hasPermission = await _photoService.checkPermission();
    _permissionChecked = true;
    notifyListeners();
    return _hasPermission;
  }

  Future<bool> requestPermission() async {
    _hasPermission = await _photoService.requestPermission();
    _permissionChecked = true;
    notifyListeners();
    return _hasPermission;
  }

  Future<bool> checkAndRequestPermission() async {
    // Primero verificar sin solicitar
    _hasPermission = await _photoService.checkPermission();

    if (!_hasPermission) {
      // Solo solicitar si realmente no tenemos permiso
      _hasPermission = await _photoService.requestPermission();
    }

    _permissionChecked = true;

    if (_hasPermission && _photos.isEmpty) {
      await loadPhotos();
    }
    notifyListeners();
    return _hasPermission;
  }

  Future<void> loadPhotos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Obtener conteo actual (muy rápido: ~100ms)
      final currentCount = await _photoService.getPhotoCount();
      _totalPhotoCount = currentCount;
      _albums = _photoService.albums;

      // 2. Verificar si el caché es válido
      final cachedCount = _storageService.getCachedPhotoCount();
      final cachedIds = _storageService.getCachedPhotoIds();

      if (cachedCount != null && cachedIds != null && cachedCount == currentCount) {
        // Caché válido - cargar primeras 100 fotos para mostrar UI rápido
        _isLoading = false;
        notifyListeners();

        // Cargar primeras fotos para UI inmediata
        final firstBatch = await _photoService.loadPhotosPaginated(start: 0, end: 100);
        _photos = firstBatch;
        _filterUnreviewedPhotos();
        notifyListeners();

        // Cargar resto en background
        if (currentCount > 100) {
          _loadRemainingPhotos(100, currentCount);
        }
      } else {
        // Caché inválido o inexistente - carga inicial
        // Cargar primeras 100 fotos primero
        final firstBatch = await _photoService.loadPhotosPaginated(start: 0, end: 100);
        _photos = firstBatch;
        _isLoading = false;
        _filterUnreviewedPhotos();
        notifyListeners();

        // Cargar resto y actualizar caché en background
        if (currentCount > 100) {
          _loadRemainingPhotosAndCache(100, currentCount);
        } else {
          // Pocas fotos, guardar caché directamente
          final ids = _photos.map((p) => p.id).toList();
          await _storageService.savePhotoCache(ids, currentCount);
          _photoService.setPhotos(_photos);
        }
      }
    } catch (e) {
      _error = 'Error al cargar fotos: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga fotos restantes en background (cuando caché es válido)
  Future<void> _loadRemainingPhotos(int start, int total) async {
    _isLoadingMore = true;

    try {
      const batchSize = 500;
      int current = start;

      while (current < total) {
        final end = (current + batchSize > total) ? total : current + batchSize;
        final batch = await _photoService.loadPhotosPaginated(start: current, end: end);

        _photos = [..._photos, ...batch];
        _filterUnreviewedPhotos();
        notifyListeners();

        current = end;
      }

      _photoService.setPhotos(_photos);
    } catch (e) {
      debugPrint('Error cargando fotos restantes: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Carga fotos restantes y actualiza caché (cuando caché es inválido)
  Future<void> _loadRemainingPhotosAndCache(int start, int total) async {
    _isLoadingMore = true;

    try {
      const batchSize = 500;
      int current = start;

      while (current < total) {
        final end = (current + batchSize > total) ? total : current + batchSize;
        final batch = await _photoService.loadPhotosPaginated(start: current, end: end);

        _photos = [..._photos, ...batch];
        _filterUnreviewedPhotos();
        notifyListeners();

        current = end;
      }

      // Guardar caché actualizado
      final ids = _photos.map((p) => p.id).toList();
      await _storageService.savePhotoCache(ids, total);
      _photoService.setPhotos(_photos);
    } catch (e) {
      debugPrint('Error cargando fotos: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadPhotosFromAlbum(AssetPathEntity album) async {
    _isLoading = true;
    _selectedAlbum = album;
    _error = null;
    notifyListeners();

    try {
      _photos = await _photoService.getPhotosFromAlbum(album);
      _filterUnreviewedPhotos();
    } catch (e) {
      _error = 'Error al cargar álbum: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void _filterUnreviewedPhotos() {
    _unreviewedPhotos = _photos.where((photo) {
      return !_storageService.isReviewed(photo.id) &&
          !_storageService.isInTrash(photo.id);
    }).toList();
    _currentIndex = 0;
  }

  void clearAlbumFilter() {
    _selectedAlbum = null;
    _photos = _photoService.allPhotos;
    _filterUnreviewedPhotos();
    notifyListeners();
  }

  void nextPhoto() {
    if (_currentIndex < _unreviewedPhotos.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void resetIndex() {
    _currentIndex = 0;
    notifyListeners();
  }

  void refresh() {
    _filterUnreviewedPhotos();
    notifyListeners();
  }
}
