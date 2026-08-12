import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/media_type.dart';
import 'package:memory_map/features/media/domain/photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/photo_selection_gateway.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';

Media media({
  String id = 'media-id',
  String memoryId = defaultMemoryId,
  MediaType type = MediaType.photo,
  int displayFileSize = 1234,
  int thumbnailFileSize = 321,
  String mimeType = 'image/jpeg',
  DateTime? createdAt,
  String thumbnailPath = '/api/v1/media/media-id/thumbnail',
  String displayPath = '/api/v1/media/media-id/display',
}) {
  return Media(
    id: id,
    memoryId: memoryId,
    type: type,
    displayFileSize: displayFileSize,
    thumbnailFileSize: thumbnailFileSize,
    mimeType: mimeType,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 9, 10),
    thumbnailPath: thumbnailPath,
    displayPath: displayPath,
  );
}

Map<String, Object?> mediaJson({
  String id = 'media-id',
  String memoryId = defaultMemoryId,
  String mediaType = 'PHOTO',
  Object? displayFileSize = 1234,
  Object? thumbnailFileSize = 321,
  String mimeType = 'image/jpeg',
  String createdAt = '2026-08-09T10:00:00Z',
  String thumbnailUrl = '/api/v1/media/media-id/thumbnail',
  String displayUrl = '/api/v1/media/media-id/display',
}) {
  return <String, Object?>{
    'id': id,
    'memoryId': memoryId,
    'mediaType': mediaType,
    'displayFileSize': displayFileSize,
    'thumbnailFileSize': thumbnailFileSize,
    'mimeType': mimeType,
    'createdAt': createdAt,
    'thumbnailUrl': thumbnailUrl,
    'displayUrl': displayUrl,
  };
}

SelectedPhoto selectedPhoto({
  List<int> bytes = const <int>[0xFF, 0xD8, 0xFF, 0xD9],
  String? declaredContentType = 'image/jpeg',
}) {
  return SelectedPhoto(
    readBytes: () async => Uint8List.fromList(bytes),
    declaredContentType: declaredContentType,
  );
}

PreparedPhotoUpload preparedPhotoUpload({
  List<int> bytes = const <int>[1, 2, 3],
  String contentType = 'image/jpeg',
}) {
  return PreparedPhotoUpload(
    bytes: Uint8List.fromList(bytes),
    contentType: contentType,
  );
}

final class FakeMediaRepository implements MediaRepository {
  int getMediaCalls = 0;
  int uploadPhotoCalls = 0;
  int deleteMediaCalls = 0;
  int getThumbnailCalls = 0;
  int getDisplayCalls = 0;

  List<Media> mediaResult = <Media>[media()];
  Media uploadResult = media(id: 'uploaded-media-id');
  Uint8List thumbnailResult = validPngBytes;
  Uint8List displayResult = validPngBytes;
  Completer<List<Media>>? getMediaCompleter;
  Completer<Media>? uploadPhotoCompleter;
  Completer<void>? deleteMediaCompleter;
  Object? getMediaFailure;
  Object? uploadPhotoFailure;
  Object? deleteMediaFailure;
  Object? thumbnailFailure;
  Object? displayFailure;
  final List<String> receivedMemoryIds = <String>[];
  final List<String> receivedDeleteMediaIds = <String>[];
  final List<PreparedPhotoUpload> receivedUploads = <PreparedPhotoUpload>[];
  final List<Media> receivedBinaryMedia = <Media>[];

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    getMediaCalls += 1;
    receivedMemoryIds.add(memoryId);

    final completer = getMediaCompleter;
    if (completer != null) {
      getMediaCompleter = null;
      return completer.future;
    }

    final failure = getMediaFailure;
    if (failure != null) {
      throw failure;
    }

    return mediaResult;
  }

  @override
  Future<Media> uploadPhoto(
    String memoryId,
    PreparedPhotoUpload photo,
  ) async {
    uploadPhotoCalls += 1;
    receivedMemoryIds.add(memoryId);
    receivedUploads.add(photo);

    final completer = uploadPhotoCompleter;
    if (completer != null) {
      uploadPhotoCompleter = null;
      return completer.future;
    }

    final failure = uploadPhotoFailure;
    if (failure != null) {
      throw failure;
    }

    return uploadResult;
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    deleteMediaCalls += 1;
    receivedDeleteMediaIds.add(mediaId);

    final completer = deleteMediaCompleter;
    if (completer != null) {
      deleteMediaCompleter = null;
      return completer.future;
    }

    final failure = deleteMediaFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<Uint8List> getThumbnail(Media media) async {
    getThumbnailCalls += 1;
    receivedBinaryMedia.add(media);

    final failure = thumbnailFailure;
    if (failure != null) {
      throw failure;
    }

    return thumbnailResult;
  }

  @override
  Future<Uint8List> getDisplay(Media media) async {
    getDisplayCalls += 1;
    receivedBinaryMedia.add(media);

    final failure = displayFailure;
    if (failure != null) {
      throw failure;
    }

    return displayResult;
  }
}

final class FakePhotoSelectionGateway implements PhotoSelectionGateway {
  int selectPhotoCalls = 0;
  SelectedPhoto? selectedPhotoResult = selectedPhoto();
  Completer<SelectedPhoto?>? selectCompleter;
  Object? failure;

  @override
  Future<SelectedPhoto?> selectPhoto() async {
    selectPhotoCalls += 1;

    final completer = selectCompleter;
    if (completer != null) {
      selectCompleter = null;
      return completer.future;
    }

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return selectedPhotoResult;
  }
}

final class FakePhotoPreprocessor implements PhotoPreprocessor {
  int processCalls = 0;
  PreparedPhotoUpload result = preparedPhotoUpload(bytes: <int>[4, 5, 6]);
  Completer<PreparedPhotoUpload>? processCompleter;
  Object? failure;
  SelectedPhoto? receivedPhoto;

  @override
  Future<PreparedPhotoUpload> process(SelectedPhoto photo) async {
    processCalls += 1;
    receivedPhoto = photo;

    final completer = processCompleter;
    if (completer != null) {
      processCompleter = null;
      return completer.future;
    }

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return result;
  }
}

const String defaultMemoryId = 'memory-id';
const String defaultMediaId = 'media-id';

const MediaApplicationException mediaUnavailableException =
    MediaApplicationException(MediaUnavailable());

final Uint8List validPngBytes = Uint8List.fromList(_validPngBytes());

List<int> _validPngBytes() {
  final source = image.Image(width: 1, height: 1);
  image.fill(source, color: image.ColorRgb8(240, 80, 90));
  return image.encodePng(source);
}
