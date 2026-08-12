import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/application/memory_media_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

import '../media_test_fixtures.dart';

void main() {
  group('MemoryMediaNotifier startup', () {
    test('shouldLoadMediaFromRepository', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a'), media(id: 'media-b')];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await loadMemoryMedia(container);

      expect(state.media, repository.mediaResult);
      expect(repository.receivedMemoryIds, <String>[defaultMemoryId]);
      expect(repository.getMediaCalls, 1);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeMediaRepository()
        ..getMediaFailure =
            const MediaApplicationException(MediaUnauthorized());
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await loadMemoryMedia(container);

      expect(state.media, isEmpty);
      expect(state.loadFailure, const MediaUnauthorized());
    });

    test('shouldRejectBlankMemoryIdWithoutRepositoryCall', () async {
      final repository = FakeMediaRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await loadMemoryMedia(container, '   ');

      expect(state.loadFailure, const MediaUnavailable());
      expect(repository.getMediaCalls, 0);
    });
  });

  group('MemoryMediaNotifier refresh', () {
    test('shouldKeepMediaVisibleWhileRefreshingAndReplaceFromBackend', () async {
      final refreshCompleter = Completer<List<Media>>();
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);
      repository.getMediaCompleter = refreshCompleter;

      final refresh = container
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .refreshMedia();
      await pumpEventQueue();

      expect(readState(container).media, <Media>[media(id: 'media-a')]);
      expect(readState(container).isRefreshing, isTrue);

      refreshCompleter.complete(<Media>[]);
      await refresh;

      expect(readState(container).media, isEmpty);
      expect(readState(container).isRefreshing, isFalse);
    });

    test('shouldExposeRefreshFailureWithoutDroppingLoadedMedia', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);
      repository.getMediaFailure =
          const MediaApplicationException(MediaRequestTimedOut());

      await container
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .refreshMedia();

      final state = readState(container);
      expect(state.media, <Media>[media(id: 'media-a')]);
      expect(state.refreshFailure, const MediaRequestTimedOut());
      expect(state.isRefreshing, isFalse);
    });
  });

  group('MemoryMediaNotifier upsert', () {
    test('shouldUpsertAuthoritativeMediaAndSortCanonically', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[
          media(id: 'media-b', createdAt: DateTime.utc(2026, 8, 9, 12)),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);

      container.read(memoryMediaProvider(defaultMemoryId).notifier).upsertMedia(
            media(id: 'media-a', createdAt: DateTime.utc(2026, 8, 9, 11)),
          );
      container.read(memoryMediaProvider(defaultMemoryId).notifier).upsertMedia(
            media(id: 'media-b', displayFileSize: 999),
          );

      expect(
        readState(container).media.map((item) => item.id),
        <String>['media-b', 'media-a'],
      );
      expect(readState(container).media.first.displayFileSize, 999);
    });

    test('shouldIgnoreMismatchedMemoryIdAndFailedLoads', () async {
      final repository = FakeMediaRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);

      container.read(memoryMediaProvider(defaultMemoryId).notifier).upsertMedia(
            media(memoryId: 'other-memory-id'),
          );

      expect(readState(container).media, repository.mediaResult);

      final failedRepository = FakeMediaRepository()
        ..getMediaFailure = const MediaApplicationException(MediaUnavailable());
      final failedContainer = createContainer(failedRepository);
      addTearDown(failedContainer.dispose);
      await loadMemoryMedia(failedContainer);

      failedContainer
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .upsertMedia(media());

      expect(readState(failedContainer).media, isEmpty);
    });
  });

  group('MemoryMediaNotifier remove', () {
    test('shouldRemoveMediaByIdAndPreserveRemainingOrder', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[
          media(id: 'media-a'),
          media(id: 'media-b'),
          media(id: 'media-c'),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);

      container
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .removeMediaById('media-b');

      expect(
        readState(container).media.map((item) => item.id),
        <String>['media-a', 'media-c'],
      );
    });

    test('shouldIgnoreUnknownIdAndFailedLoads', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadMemoryMedia(container);

      container
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .removeMediaById('unknown-media-id');

      expect(readState(container).media, repository.mediaResult);

      final failedRepository = FakeMediaRepository()
        ..getMediaFailure = const MediaApplicationException(MediaUnavailable());
      final failedContainer = createContainer(failedRepository);
      addTearDown(failedContainer.dispose);
      await loadMemoryMedia(failedContainer);

      failedContainer
          .read(memoryMediaProvider(defaultMemoryId).notifier)
          .removeMediaById(defaultMediaId);

      expect(readState(failedContainer).media, isEmpty);
    });
  });

  group('MemoryMediaNotifier security', () {
    test('shouldKeepIndependentFamilyStateAndSafeToString', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'private-media-id')];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      await loadMemoryMedia(container, 'memory-a');
      repository.mediaResult = <Media>[media(id: 'other-media-id')];
      await loadMemoryMedia(container, 'memory-b');

      expect(readState(container, 'memory-a').media.first.id, 'private-media-id');
      expect(readState(container, 'memory-b').media.first.id, 'other-media-id');

      final text = readState(container, 'memory-a').toString();
      expect(text, contains('mediaCount: 1'));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('accessToken')));
    });

    test('shouldDisposePrivateMediaMetadataWhenNoScreenListens', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'private-media-id')];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final provider = memoryMediaProvider(defaultMemoryId);
      final subscription = container.listen(
        provider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(provider.future);

      expect(container.exists(provider), isTrue);

      subscription.close();
      await pumpEventQueue();

      expect(container.exists(provider), isFalse);
    });
  });
}

ProviderContainer createContainer(FakeMediaRepository repository) {
  return ProviderContainer(
    overrides: [
      mediaRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Future<MemoryMediaState> loadMemoryMedia(
  ProviderContainer container, [
  String memoryId = defaultMemoryId,
]) async {
  final provider = memoryMediaProvider(memoryId);
  final subscription = container.listen(
    provider,
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return container.read(provider.future);
}

MemoryMediaState readState(
  ProviderContainer container, [
  String memoryId = defaultMemoryId,
]) {
  return container.read(memoryMediaProvider(memoryId)).asData!.value;
}
