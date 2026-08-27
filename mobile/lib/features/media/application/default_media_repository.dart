import 'dart:typed_data';

import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/data/remote/media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';
import 'package:memory_map/features/media/domain/authenticated_media_cache.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

final class DefaultMediaRepository implements MediaRepository {
  const DefaultMediaRepository({
    required MediaRemoteDataSource mediaRemoteDataSource,
    AuthenticatedMediaCache authenticatedMediaCache =
        const PassthroughAuthenticatedMediaCache(),
  })  : _mediaRemoteDataSource = mediaRemoteDataSource,
        _authenticatedMediaCache = authenticatedMediaCache;

  final MediaRemoteDataSource _mediaRemoteDataSource;
  final AuthenticatedMediaCache _authenticatedMediaCache;

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
    return _getRepresentation(media.thumbnailPath);
  }

  @override
  Future<Uint8List> getThumbnailByPath(String thumbnailPath) async {
    return _getRepresentation(thumbnailPath);
  }

  @override
  Future<Uint8List> getDisplay(Media media) async {
    return _getRepresentation(media.displayPath);
  }

  @override
  Future<Uint8List> getDisplayByPath(String displayPath) async {
    return _getRepresentation(displayPath);
  }

  Future<Uint8List> _getRepresentation(String backendPath) async {
    try {
      return await _authenticatedMediaCache.getOrFetch(
        backendPath,
        () => _mediaRemoteDataSource.getRepresentation(backendPath),
      );
    } on MediaRemoteException catch (exception) {
      throw MediaApplicationException(_mapFailure(exception));
    } on Object {
      try {
        return await _mediaRemoteDataSource.getRepresentation(backendPath);
      } on MediaRemoteException catch (exception) {
        throw MediaApplicationException(_mapFailure(exception));
      }
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
