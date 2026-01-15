import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// Solicita permisos de galería con soporte especial para MIUI/Xiaomi
  Future<bool> requestPermission() async {
    // Primero intentar con photo_manager
    final PermissionState pmPermission = await PhotoManager.requestPermissionExtend();

    // Verificar todos los estados válidos de photo_manager
    if (pmPermission.isAuth || pmPermission.hasAccess) {
      return true;
    }

    // Si photo_manager falla, intentar con permission_handler
    // Esto es especialmente útil para MIUI/Xiaomi
    PermissionStatus status;

    // En Android 13+ se usa READ_MEDIA_IMAGES
    if (await Permission.photos.status.isDenied) {
      status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        // Dar tiempo a MIUI para procesar el permiso
        await Future.delayed(const Duration(milliseconds: 500));
        // Verificar de nuevo con photo_manager
        final recheckPermission = await PhotoManager.requestPermissionExtend();
        return recheckPermission.isAuth || recheckPermission.hasAccess;
      }
    }

    // Intentar con storage para Android < 13
    if (await Permission.storage.status.isDenied) {
      status = await Permission.storage.request();
      if (status.isGranted) {
        await Future.delayed(const Duration(milliseconds: 500));
        final recheckPermission = await PhotoManager.requestPermissionExtend();
        return recheckPermission.isAuth || recheckPermission.hasAccess;
      }
    }

    // Último intento: verificar si ya tenemos acceso aunque el estado diga lo contrario
    // Esto es común en MIUI donde el estado puede no actualizarse correctamente
    try {
      final testAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      if (testAlbums.isNotEmpty) {
        return true;
      }
    } catch (e) {
      // Ignorar error, significa que realmente no tenemos permiso
    }

    return false;
  }

  /// Verifica si tenemos permiso sin solicitarlo
  Future<bool> checkPermission() async {
    final PermissionState pmPermission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );

    if (pmPermission.isAuth || pmPermission.hasAccess) {
      return true;
    }

    // Verificación adicional intentando acceder a los álbumes
    try {
      final testAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      return testAlbums.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Abre la configuración de la app para que el usuario otorgue permisos manualmente
  Future<bool> openSettings() async {
    return await openAppSettings();
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

  /// Obtiene solo el conteo total de fotos (muy rápido)
  Future<int> getPhotoCount() async {
    if (_albums.isEmpty) {
      await loadAlbums();
    }
    if (_albums.isEmpty) return 0;

    final allAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );
    return await allAlbum.assetCountAsync;
  }

  /// Carga fotos de forma paginada
  Future<List<Photo>> loadPhotosPaginated({
    required int start,
    required int end,
  }) async {
    if (_albums.isEmpty) {
      await loadAlbums();
    }
    if (_albums.isEmpty) return [];

    final allAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );

    final assets = await allAlbum.getAssetListRange(start: start, end: end);
    return assets.map((a) => Photo.fromAsset(a)).toList();
  }

  /// Carga solo los IDs de todas las fotos (más rápido que cargar metadata completa)
  Future<List<String>> loadAllPhotoIds() async {
    if (_albums.isEmpty) {
      await loadAlbums();
    }
    if (_albums.isEmpty) return [];

    final allAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );

    final count = await allAlbum.assetCountAsync;
    final assets = await allAlbum.getAssetListRange(start: 0, end: count);
    return assets.map((a) => a.id).toList();
  }

  /// Carga fotos por sus IDs
  Future<List<Photo>> loadPhotosByIds(List<String> ids) async {
    final photos = <Photo>[];
    for (final id in ids) {
      final asset = await AssetEntity.fromId(id);
      if (asset != null) {
        photos.add(Photo.fromAsset(asset));
      }
    }
    return photos;
  }

  /// Actualiza la lista interna de fotos
  void setPhotos(List<Photo> photos) {
    _allPhotos = photos;
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
