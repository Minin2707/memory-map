import 'dart:typed_data';

import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

abstract interface class MediaRepository {
  Future<List<Media>> getMedia(String memoryId);

  Future<Media> uploadPhoto(String memoryId, PreparedPhotoUpload photo);

  Future<void> deleteMedia(String mediaId);

  Future<Uint8List> getThumbnail(Media media);

  Future<Uint8List> getDisplay(Media media);
}
