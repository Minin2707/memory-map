import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/delete_media_notifier.dart';
import 'package:memory_map/features/media/application/delete_media_state.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

import '../media_test_fixtures.dart';

void main() {
  group('DeleteMediaNotifier flow', () {
    test('shouldDeleteMediaAndSyncLoadedMemoryMediaAfterSuccess', () async {
      final target = media(id: 'media-a');
      final other = media(id: 'media-b');
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[target, other];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      keepMemoryMediaAlive(container);
      await container.read(memoryMediaProvider(defaultMemoryId).future);
      await container.read(deleteMediaProvider(target.id).future);

      final success = await container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);

      expect(success, isTrue);
      expect(repository.deleteMediaCalls, 1);
      expect(repository.receivedDeleteMediaIds, <String>[target.id]);
      expect(
        container
            .read(memoryMediaProvider(defaultMemoryId))
            .asData!
            .value
            .media,
        <Media>[other],
      );
      expect(
        container.read(deleteMediaProvider(target.id)).asData!.value,
        const DeleteMediaState(),
      );
    });

    test('shouldNotForceLoadMemoryMediaProviderWhenAbsent', () async {
      final target = media(id: 'media-a');
      final repository = FakeMediaRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMediaProvider(target.id).future);

      final success = await container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);

      expect(success, isTrue);
      expect(repository.getMediaCalls, 0);
      expect(repository.deleteMediaCalls, 1);
    });

    test('shouldIgnoreDuplicateDeletesWhilePending', () async {
      final target = media(id: 'media-a');
      final deleteCompleter = Completer<void>();
      final repository = FakeMediaRepository()
        ..deleteMediaCompleter = deleteCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        deleteMediaProvider(target.id),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(deleteMediaProvider(target.id).future);

      final first = container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);
      await pumpEventQueue();
      final second = await container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);

      expect(second, isFalse);
      expect(repository.deleteMediaCalls, 1);

      deleteCompleter.complete();
      expect(await first, isTrue);
    });

    test('shouldRejectProviderAndMediaIdMismatchWithoutNetworkCall', () async {
      final repository = FakeMediaRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMediaProvider('media-a').future);

      final success = await container
          .read(deleteMediaProvider('media-a').notifier)
          .deleteMedia(media(id: 'media-b'));

      expect(success, isFalse);
      expect(repository.deleteMediaCalls, 0);
      expect(
        container.read(deleteMediaProvider('media-a')).asData!.value,
        const DeleteMediaState(deleteFailure: MediaValidationFailure()),
      );
    });

    test('shouldRefreshLoadedMemoryPreviewAfterDeleteSuccess', () async {
      final oldPreview = previewPhoto(mediaId: 'deleted-media-id');
      final mediaRepository = FakeMediaRepository();
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: oldPreview,
        )
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(
        mediaRepository,
        memoryRepository: memoryRepository,
      );
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(defaultMemoryId).future);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(deleteMediaProvider(defaultMediaId).future);
      memoryRepository.memoryReadModelResult = MemoryReadModel(
        memory: memoryA,
      );

      final success = await container
          .read(deleteMediaProvider(defaultMediaId).notifier)
          .deleteMedia(media(id: defaultMediaId));

      expect(success, isTrue);
      expect(memoryRepository.getMemoryCalls, 2);
      expect(
        container
            .read(memoryDetailsProvider(defaultMemoryId))
            .asData!
            .value
            .previewPhoto,
        isNull,
      );
      expect(
        container
            .read(storyMemoriesProvider(defaultStoryId))
            .asData!
            .value
            .memoryReadModels
            .single
            .previewPhoto,
        isNull,
      );
    });

    test('shouldNotFailDeleteWhenPreviewRefreshFails', () async {
      final oldPreview = previewPhoto(mediaId: 'old-media-id');
      final mediaRepository = FakeMediaRepository();
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: oldPreview,
        );
      final container = createContainer(
        mediaRepository,
        memoryRepository: memoryRepository,
      );
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(defaultMemoryId).future);
      await container.read(deleteMediaProvider(defaultMediaId).future);
      memoryRepository.getMemoryFailure = const MemoryApplicationException(
        MemoryNetworkUnavailable(),
      );

      final success = await container
          .read(deleteMediaProvider(defaultMediaId).notifier)
          .deleteMedia(media(id: defaultMediaId));

      expect(success, isTrue);
      expect(
        container
            .read(memoryDetailsProvider(defaultMemoryId))
            .asData!
            .value
            .previewPhoto,
        same(oldPreview),
      );
      expect(
        container.read(deleteMediaProvider(defaultMediaId)).asData!.value,
        const DeleteMediaState(),
      );
    });
  });

  group('DeleteMediaNotifier failures', () {
    test('shouldExposeKnownFailureAndPreserveLoadedMedia', () async {
      final target = media(id: 'media-a');
      final other = media(id: 'media-b');
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[target, other]
        ..deleteMediaFailure =
            const MediaApplicationException(MediaNetworkUnavailable());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      keepMemoryMediaAlive(container);
      await container.read(memoryMediaProvider(defaultMemoryId).future);
      await container.read(deleteMediaProvider(target.id).future);

      final success = await container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);

      expect(success, isFalse);
      expect(
        container
            .read(memoryMediaProvider(defaultMemoryId))
            .asData!
            .value
            .media,
        <Media>[target, other],
      );
      expect(
        container.read(deleteMediaProvider(target.id)).asData!.value,
        const DeleteMediaState(deleteFailure: MediaNetworkUnavailable()),
      );
    });

    test('shouldExposeUnexpectedFailureAsAsyncError', () async {
      final target = media(id: 'media-a');
      final repository = FakeMediaRepository()
        ..deleteMediaFailure = const UnexpectedDeleteException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMediaProvider(target.id).future);

      final success = await container
          .read(deleteMediaProvider(target.id).notifier)
          .deleteMedia(target);

      expect(success, isFalse);
      expect(
        container.read(deleteMediaProvider(target.id)),
        isA<AsyncError<DeleteMediaState>>(),
      );
    });
  });

  group('DeleteMediaNotifier security', () {
    test('shouldKeepIndependentFamilyStateAndSafeToString', () async {
      final repository = FakeMediaRepository()
        ..deleteMediaFailure =
            const MediaApplicationException(MediaUnavailable());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMediaProvider('media-a').future);
      await container.read(deleteMediaProvider('media-b').future);

      await container
          .read(deleteMediaProvider('media-a').notifier)
          .deleteMedia(media(id: 'media-a'));

      expect(
        container.read(deleteMediaProvider('media-a')).asData!.value
            .deleteFailure,
        const MediaUnavailable(),
      );
      expect(
        container.read(deleteMediaProvider('media-b')).asData!.value,
        const DeleteMediaState(),
      );
      expect(
        container
            .read(deleteMediaProvider('media-a'))
            .asData!
            .value
            .toString(),
        isNot(contains('media-a')),
      );
    });
  });
}

ProviderContainer createContainer(
  FakeMediaRepository repository, {
  FakeMemoryRepository? memoryRepository,
}) {
  return ProviderContainer(
    overrides: [
      mediaRepositoryProvider.overrideWithValue(repository),
      memoryRepositoryProvider.overrideWithValue(
        memoryRepository ?? FakeMemoryRepository(),
      ),
    ],
  );
}

void keepMemoryMediaAlive(ProviderContainer container) {
  final subscription = container.listen(
    memoryMediaProvider(defaultMemoryId),
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

final class UnexpectedDeleteException implements Exception {
  const UnexpectedDeleteException();
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoryCalls = 0;
  List<Memory> memoriesResult = <Memory>[];
  MemoryReadModel memoryReadModelResult = MemoryReadModel.fromMemory(memoryA);
  Object? getMemoryFailure;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    return memoriesResult.map(MemoryReadModel.fromMemory).toList();
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;

    final failure = getMemoryFailure;
    if (failure != null) {
      throw failure;
    }

    return memoryReadModelResult;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    return memoryA;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    return memoryA;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {}
}

Memory memory({
  String id = defaultMemoryId,
  String storyId = defaultStoryId,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: 'First picnic',
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

const String defaultStoryId = 'story-id';
final Memory memoryA = memory();
