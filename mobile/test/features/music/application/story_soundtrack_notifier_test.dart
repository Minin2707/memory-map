import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';

void main() {
  group('StorySoundtrackNotifier startup', () {
    test('shouldLoadNoMusic', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storySoundtrackProvider('story-1').future,
      );

      expect(state.soundtrack, StorySoundtrack.noMusic());
      expect(state.loadFailure, isNull);
      expect(repository.operations, <String>['get:story-1']);
    });

    test('shouldLoadSelectedAndEffectiveSoundtrack', () async {
      final soundtrack = StorySoundtrack(
        selectedSoundtrack: trackA,
        effectiveSoundtrack: trackA,
      );
      final repository = FakeStorySoundtrackRepository()
        ..getResult = soundtrack;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storySoundtrackProvider('story-1').future,
      );

      expect(state.soundtrack, soundtrack);
      expect(state.soundtrack?.isEffective, isTrue);
    });

    test('shouldPreserveSelectedUnavailable', () async {
      final soundtrack = StorySoundtrack(selectedSoundtrack: trackA);
      final repository = FakeStorySoundtrackRepository()
        ..getResult = soundtrack;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storySoundtrackProvider('story-1').future,
      );

      expect(state.soundtrack?.selectedSoundtrack, trackA);
      expect(state.soundtrack?.effectiveSoundtrack, isNull);
      expect(state.soundtrack?.isSelectedUnavailable, isTrue);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getFailures.add(
          const MusicApplicationException(MusicUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storySoundtrackProvider('story-1').future,
      );

      expect(state.soundtrack, isNull);
      expect(state.loadFailure, const MusicUnavailable());
    });

    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStorySoundtrackRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storySoundtrackProvider('   ').future);

      expect(state.loadFailure, const MusicValidationFailure());
      expect(repository.operations, isEmpty);
    });
  });

  group('StorySoundtrackNotifier retry and refresh', () {
    test('shouldRetryAfterKnownLoadFailure', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getFailures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        )
        ..getResults.add(StorySoundtrack.noMusic());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      await container
          .read(storySoundtrackProvider('story-1').notifier)
          .retryLoad();

      final state = readState(container, 'story-1');
      expect(state.soundtrack, StorySoundtrack.noMusic());
      expect(state.loadFailure, isNull);
      expect(repository.operations, <String>['get:story-1', 'get:story-1']);
    });

    test('shouldRefreshWithAuthoritativeState', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);
      repository.getResult = StorySoundtrack(
        selectedSoundtrack: trackB,
        effectiveSoundtrack: trackB,
      );

      await container
          .read(storySoundtrackProvider('story-1').notifier)
          .refreshSoundtrack();

      final state = readState(container, 'story-1');
      expect(state.soundtrack?.selectedSoundtrack, trackB);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepCurrentStateAndExposeRefreshFailure', () async {
      final selectedUnavailable = StorySoundtrack(selectedSoundtrack: trackA);
      final repository = FakeStorySoundtrackRepository()
        ..getResult = selectedUnavailable;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);
      repository.getFailures.add(
        const MusicApplicationException(MusicRequestTimedOut()),
      );

      await container
          .read(storySoundtrackProvider('story-1').notifier)
          .refreshSoundtrack();

      final state = readState(container, 'story-1');
      expect(state.soundtrack, selectedUnavailable);
      expect(state.refreshFailure, const MusicRequestTimedOut());
    });
  });

  group('StorySoundtrackNotifier mutations', () {
    test('shouldSetUsingAuthoritativeServerResponse', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setResult = StorySoundtrack(
          selectedSoundtrack: trackB,
          effectiveSoundtrack: trackB,
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      final success = await container
          .read(storySoundtrackProvider('story-1').notifier)
          .setSoundtrack(trackA.id);

      final state = readState(container, 'story-1');
      expect(success, isTrue);
      expect(state.soundtrack?.selectedSoundtrack, trackB);
      expect(repository.operations, <String>[
        'get:story-1',
        'set:story-1:track-a',
      ]);
    });

    test('shouldRemoveUsingAuthoritativeServerResponse', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        )
        ..removeResult = StorySoundtrack.noMusic();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      final success = await container
          .read(storySoundtrackProvider('story-1').notifier)
          .removeSoundtrack();

      expect(success, isTrue);
      expect(readState(container, 'story-1').soundtrack?.isNoMusic, isTrue);
      expect(repository.operations, <String>[
        'get:story-1',
        'remove:story-1',
      ]);
    });

    test('shouldPreservePreviousStateOnSetFailure', () async {
      final original = StorySoundtrack(selectedSoundtrack: trackA);
      final repository = FakeStorySoundtrackRepository()
        ..getResult = original
        ..setFailures.add(
          const MusicApplicationException(MusicServerFailure()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      final success = await container
          .read(storySoundtrackProvider('story-1').notifier)
          .setSoundtrack(trackB.id);

      final state = readState(container, 'story-1');
      expect(success, isFalse);
      expect(state.soundtrack, original);
      expect(state.mutationFailure, const MusicServerFailure());
      expect(state.isMutating, isFalse);
    });

    test('shouldPreservePreviousStateOnRemoveFailure', () async {
      final original = StorySoundtrack(
        selectedSoundtrack: trackA,
        effectiveSoundtrack: trackA,
      );
      final repository = FakeStorySoundtrackRepository()
        ..getResult = original
        ..removeFailures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      final success = await container
          .read(storySoundtrackProvider('story-1').notifier)
          .removeSoundtrack();

      final state = readState(container, 'story-1');
      expect(success, isFalse);
      expect(state.soundtrack, original);
      expect(state.mutationFailure, const MusicNetworkUnavailable());
      expect(state.isMutating, isFalse);
    });

    test('shouldPreventOverlappingMutation', () async {
      final setCompleter = Completer<StorySoundtrack>();
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setCompleter = setCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);
      final notifier = container.read(
        storySoundtrackProvider('story-1').notifier,
      );

      final first = notifier.setSoundtrack(trackA.id);
      await pumpEventQueue();
      final second = await notifier.removeSoundtrack();

      expect(second, isFalse);
      expect(readState(container, 'story-1').isMutating, isTrue);
      expect(repository.operations, <String>[
        'get:story-1',
        'set:story-1:track-a',
      ]);

      setCompleter.complete(
        StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        ),
      );
      expect(await first, isTrue);
    });

    test('shouldRejectBlankMusicTrackIdWithoutRepositoryCall', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('story-1').future);

      final success = await container
          .read(storySoundtrackProvider('story-1').notifier)
          .setSoundtrack('   ');

      expect(success, isFalse);
      expect(
        readState(container, 'story-1').mutationFailure,
        const MusicValidationFailure(),
      );
      expect(repository.operations, <String>['get:story-1']);
    });
  });

  group('StorySoundtrackNotifier provider lifecycle', () {
    test('shouldKeepIndependentStatePerStoryId', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResults.add(StorySoundtrack.noMusic())
        ..getResults.add(StorySoundtrack(selectedSoundtrack: trackA));
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final first = await container.read(
        storySoundtrackProvider('story-1').future,
      );
      final second = await container.read(
        storySoundtrackProvider('story-2').future,
      );

      expect(first.soundtrack?.isNoMusic, isTrue);
      expect(second.soundtrack?.selectedSoundtrack, trackA);
      expect(repository.operations, <String>[
        'get:story-1',
        'get:story-2',
      ]);
    });
  });

  group('StorySoundtrackNotifier security', () {
    test('shouldNotExposeTrackDetailsThroughStateToString', () async {
      final repository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack(
          selectedSoundtrack: MusicTrack(
            id: 'private-track-id',
            title: 'Private title',
            artist: 'Private artist',
            durationSeconds: 270,
          ),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storySoundtrackProvider('private-story').future);

      final text = container
          .read(storySoundtrackProvider('private-story'))
          .toString();

      expect(text, isNot(contains('private-story')));
      expect(text, isNot(contains('private-track-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private artist')));
      expect(text, isNot(contains('storageKey')));
      expect(text, isNot(contains('token')));
    });
  });
}

ProviderContainer createContainer(FakeStorySoundtrackRepository repository) {
  return ProviderContainer(
    overrides: [
      storySoundtrackRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

StorySoundtrackState readState(
  ProviderContainer container,
  String storyId,
) {
  return container.read(storySoundtrackProvider(storyId)).asData!.value;
}

final MusicTrack trackA = MusicTrack(
  id: 'track-a',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

final MusicTrack trackB = MusicTrack(
  id: 'track-b',
  title: 'Walk',
  artist: 'Ikson',
  durationSeconds: 180,
);

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  final List<String> operations = <String>[];
  final List<Object> getFailures = <Object>[];
  final List<Object> setFailures = <Object>[];
  final List<Object> removeFailures = <Object>[];
  final List<StorySoundtrack> getResults = <StorySoundtrack>[];
  StorySoundtrack getResult = StorySoundtrack.noMusic();
  StorySoundtrack setResult = StorySoundtrack.noMusic();
  StorySoundtrack removeResult = StorySoundtrack.noMusic();
  Completer<StorySoundtrack>? setCompleter;

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    operations.add('get:$storyId');
    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    if (getResults.isNotEmpty) {
      return getResults.removeAt(0);
    }

    return getResult;
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) async {
    operations.add('set:$storyId:$musicTrackId');

    final configuredCompleter = setCompleter;
    if (configuredCompleter != null) {
      setCompleter = null;
      return configuredCompleter.future;
    }

    if (setFailures.isNotEmpty) {
      throw setFailures.removeAt(0);
    }

    return setResult;
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    operations.add('remove:$storyId');
    if (removeFailures.isNotEmpty) {
      throw removeFailures.removeAt(0);
    }

    return removeResult;
  }
}
