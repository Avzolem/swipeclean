import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';

class PhotoService {
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  List<AssetPathEntity> _albums = [];
  List<Photo> _allPhotos = [];
  bool _isInitialized = false;

  List<AssetPathEntity> get albums => _albums;
  List<Photo> get allPhotos => _allPhotos;
  bool get isInitialized => _isInitialized;

  Future<bool> requestPermission() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    return permission.isAuth;
  }

  Future<void> loadAlbums() async {
    _albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );
  }

  Future<List<Photo>> loadPhotos({AssetPathEntity? album, int page = 0, int pageSize = 50}) async {
    if (album != null) {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      return assets.map((a) => Photo.fromAsset(a, albumName: album.name)).toList();
    }

    // Cargar de todos los álbumes si no se especifica uno
    if (_albums.isEmpty) {
      await loadAlbums();
    }

    // Buscar el álbum "Recientes" o "All"
    final allAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );

    final assets = await allAlbum.getAssetListPaged(page: page, size: pageSize);
    return assets.map((a) => Photo.fromAsset(a)).toList();
  }

  Future<void> loadAllPhotos() async {
    if (_isInitialized) return;

    await loadAlbums();

    if (_albums.isEmpty) return;

    final allAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );

    final count = await allAlbum.assetCountAsync;
    final assets = await allAlbum.getAssetListRange(start: 0, end: count);
    _allPhotos = assets.map((a) => Photo.fromAsset(a)).toList();
    _isInitialized = true;
  }

  Future<List<Photo>> getPhotosFromAlbum(AssetPathEntity album) async {
    final count = await album.assetCountAsync;
    final assets = await album.getAssetListRange(start: 0, end: count);
    return assets.map((a) => Photo.fromAsset(a, albumName: album.name)).toList();
  }

  Future<bool> deletePhoto(String photoId) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([photoId]);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePhotos(List<String> photoIds) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds(photoIds);
      return result.length == photoIds.length;
    } catch (e) {
      return false;
    }
  }

  void reset() {
    _allPhotos = [];
    _albums = [];
    _isInitialized = false;
  }
}
