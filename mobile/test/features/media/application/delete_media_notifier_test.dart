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

ProviderContainer createContainer(FakeMediaRepository repository) {
  return ProviderContainer(
    overrides: [
      mediaRepositoryProvider.overrideWithValue(repository),
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
