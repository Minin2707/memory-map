import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/default_media_repository.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/data/remote/media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

import '../media_test_fixtures.dart';

void main() {
  group('DefaultMediaRepository', () {
    test('shouldDelegateMetadataListUploadAndBinaryLoads', () async {
      final remote = FakeMediaRemoteDataSource();
      final repository = DefaultMediaRepository(mediaRemoteDataSource: remote);

      expect(await repository.getMedia(defaultMemoryId), remote.mediaResult);
      expect(
        await repository.uploadPhoto(defaultMemoryId, remote.upload),
        remote.uploadResult,
      );
      await repository.deleteMedia(defaultMediaId);
      expect(await repository.getThumbnail(media()), <int>[7, 8, 9]);
      expect(
        await repository.getThumbnailByPath('/api/v1/media/media-id/thumbnail'),
        <int>[7, 8, 9],
      );
      expect(await repository.getDisplay(media()), <int>[10, 11, 12]);

      expect(remote.receivedMemoryIds, <String>[
        defaultMemoryId,
        defaultMemoryId,
      ]);
      expect(remote.receivedDeleteMediaIds, <String>[defaultMediaId]);
      expect(remote.receivedUploads, <PreparedPhotoUpload>[remote.upload]);
      expect(remote.receivedRepresentationPaths, <String>[
        '/api/v1/media/media-id/thumbnail',
        '/api/v1/media/media-id/thumbnail',
        '/api/v1/media/media-id/display',
      ]);
    });

    test('shouldMapRemoteFailuresToSafeApplicationFailures', () async {
      await expectMappedFailure(
        const MediaRemoteValidationException(),
        const MediaValidationFailure(),
      );
      await expectMappedFailure(
        const MediaRemoteUnauthorizedException(),
        const MediaUnauthorized(),
      );
      await expectMappedFailure(
        const MediaRemoteUnavailableException(),
        const MediaUnavailable(),
      );
      await expectMappedFailure(
        const MediaRemoteUploadUnavailableException(),
        const MediaUploadUnavailable(),
      );
      await expectMappedFailure(
        const MediaRemoteNetworkException(),
        const MediaNetworkUnavailable(),
      );
      await expectMappedFailure(
        const MediaRemoteTimeoutException(),
        const MediaRequestTimedOut(),
      );
      await expectMappedFailure(
        const MediaRemoteServerException(),
        const MediaServerFailure(),
      );
      await expectMappedFailure(
        const MediaRemoteMalformedResponseException(),
        const UnknownMediaFailure(),
      );
      await expectMappedFailure(
        const MediaRemoteUnknownException(),
        const UnknownMediaFailure(),
      );
    });

    test('shouldMapDeleteRemoteFailureToSafeApplicationFailure', () async {
      final remote = FakeMediaRemoteDataSource()
        ..failure = const MediaRemoteUnavailableException();
      final repository = DefaultMediaRepository(mediaRemoteDataSource: remote);

      await expectLater(
        repository.deleteMedia(defaultMediaId),
        throwsA(
          isA<MediaApplicationException>().having(
            (error) => error.failure,
            'failure',
            const MediaUnavailable(),
          ),
        ),
      );
      expect(remote.receivedDeleteMediaIds, <String>[defaultMediaId]);
    });
  });
}

Future<void> expectMappedFailure(
  MediaRemoteException remoteFailure,
  MediaFailure expectedFailure,
) async {
  final remote = FakeMediaRemoteDataSource()..failure = remoteFailure;
  final repository = DefaultMediaRepository(mediaRemoteDataSource: remote);

  await expectLater(
    repository.getMedia(defaultMemoryId),
    throwsA(
      isA<MediaApplicationException>().having(
        (error) => error.failure,
        'failure',
        expectedFailure,
      ),
    ),
  );
}

final class FakeMediaRemoteDataSource implements MediaRemoteDataSource {
  final List<Media> mediaResult = <Media>[media()];
  final Media uploadResult = media(id: 'uploaded-media-id');
  final PreparedPhotoUpload upload = preparedPhotoUpload();
  final List<String> receivedMemoryIds = <String>[];
  final List<String> receivedDeleteMediaIds = <String>[];
  final List<PreparedPhotoUpload> receivedUploads = <PreparedPhotoUpload>[];
  final List<String> receivedRepresentationPaths = <String>[];
  MediaRemoteException? failure;

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    receivedMemoryIds.add(memoryId);
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
    return mediaResult;
  }

  @override
  Future<Media> uploadPhoto(
    String memoryId,
    PreparedPhotoUpload photo,
  ) async {
    receivedMemoryIds.add(memoryId);
    receivedUploads.add(photo);
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
    return uploadResult;
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    receivedDeleteMediaIds.add(mediaId);
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }

  @override
  Future<Uint8List> getRepresentation(String backendPath) async {
    receivedRepresentationPaths.add(backendPath);
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
    return backendPath.endsWith('/thumbnail')
        ? Uint8List.fromList(<int>[7, 8, 9])
        : Uint8List.fromList(<int>[10, 11, 12]);
  }
}
