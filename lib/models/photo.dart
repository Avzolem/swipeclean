import 'package:photo_manager/photo_manager.dart';

class Photo {
  final String id;
  final AssetEntity asset;
  final DateTime createdAt;
  final String? albumName;

  Photo({
    required this.id,
    required this.asset,
    required this.createdAt,
    this.albumName,
  });

  factory Photo.fromAsset(AssetEntity asset, {String? albumName}) {
    return Photo(
      id: asset.id,
      asset: asset,
      createdAt: asset.createDateTime,
      albumName: albumName,
    );
  }

  Future<String?> get filePath async => await asset.file.then((f) => f?.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Photo && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
