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
  String? _error;
  int _currentIndex = 0;

  List<Photo> get photos => _photos;
  List<Photo> get unreviewedPhotos => _unreviewedPhotos;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  int get currentIndex => _currentIndex;
  Photo? get currentPhoto =>
      _unreviewedPhotos.isNotEmpty && _currentIndex < _unreviewedPhotos.length
          ? _unreviewedPhotos[_currentIndex]
          : null;
  int get totalPhotos => _photos.length;
  int get remainingPhotos => _unreviewedPhotos.length - _currentIndex;

  Future<bool> requestPermission() async {
    _hasPermission = await _photoService.requestPermission();
    notifyListeners();
    return _hasPermission;
  }

  Future<void> loadPhotos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _photoService.loadAllPhotos();
      _photos = _photoService.allPhotos;
      _albums = _photoService.albums;
      _filterUnreviewedPhotos();
    } catch (e) {
      _error = 'Error al cargar fotos: $e';
    }

    _isLoading = false;
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
