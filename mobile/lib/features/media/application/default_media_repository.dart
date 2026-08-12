import 'dart:typed_data';

import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/data/remote/media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

final class DefaultMediaRepository implements MediaRepository {
  const DefaultMediaRepository({
    required MediaRemoteDataSource mediaRemoteDataSource,
  }) : _mediaRemoteDataSource = mediaRemoteDataSource;

  final MediaRemoteDataSource _mediaRemoteDataSource;

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    try {
      return await _mediaRemoteDataSource.getMedia(memoryId);
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Media> uploadPhoto(
    String memoryId,
    PreparedPhotoUpload photo,
  ) async {
    try {
      return await _mediaRemoteDataSource.uploadPhoto(memoryId, photo);
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    try {
      await _mediaRemoteDataSource.deleteMedia(mediaId);
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Uint8List> getThumbnail(Media media) async {
    try {
      return await _mediaRemoteDataSource.getRepresentation(
        media.thumbnailPath,
      );
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Uint8List> getDisplay(Media media) async {
    try {
      return await _mediaRemoteDataSource.getRepresentation(media.displayPath);
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    }
  }

  MediaFailure _mapFailure(MediaRemoteException exception) {
    return switch (exception) {
      MediaRemoteValidationException() => const MediaValidationFailure(),
      MediaRemoteUnauthorizedException() => const MediaUnauthorized(),
      MediaRemoteUnavailableException() => const MediaUnavailable(),
      MediaRemoteUploadUnavailableException() =>
        const MediaUploadUnavailable(),
      MediaRemoteNetworkException() => const MediaNetworkUnavailable(),
      MediaRemoteTimeoutException() => const MediaRequestTimedOut(),
      MediaRemoteServerException() => const MediaServerFailure(),
      MediaRemoteMalformedResponseException() =>
        const UnknownMediaFailure(),
      MediaRemoteUnknownException() => const UnknownMediaFailure(),
    };
  }
}
