import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/music/presentation/soundtrack_selection_screen.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('SoundtrackSelectionScreen rendering', () {
    testWidgets('shouldRenderNoMusicAndCatalogInBackendOrder', (tester) async {
      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackB, trackA],
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack.noMusic(),
      );

      expect(find.text('Choose soundtrack'), findsOneWidget);
      expect(find.text('No music'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Ikson · 3:00'), findsOneWidget);
      expect(find.text('Autumn Leaves'), findsOneWidget);
      expect(find.text('LofCosmos · 4:30'), findsOneWidget);

      final walkTop = tester.getTopLeft(find.text('Walk')).dy;
      final autumnTop = tester.getTopLeft(find.text('Autumn Leaves')).dy;
      expect(walkTop, lessThan(autumnTop));
    });

    testWidgets('shouldRenderSelectedActiveTrack', (tester) async {
      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
      );

      expect(find.text('Autumn Leaves'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shouldRenderSelectedUnavailableSeparateFromCatalog', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackB],
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack(selectedSoundtrack: trackA),
      );

      expect(
        find.byKey(
          const ValueKey('soundtrack-selection.selected-unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.text('Autumn Leaves'), findsOneWidget);
      expect(find.text('Currently unavailable. Choose another track or No music.'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
    });

    testWidgets('shouldRenderEmptyCatalogAsValidState', (tester) async {
      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack.noMusic(),
      );

      expect(find.text('No music'), findsWidgets);
      expect(find.text('No soundtracks are available right now.'), findsOneWidget);
    });

    testWidgets('shouldRenderCatalogFailureWithRetry', (tester) async {
      final musicRepository = FakeMusicRepository()
        ..getFailures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        )
        ..tracksResults.add(<MusicTrack>[trackA]);

      await pumpScreen(
        tester,
        musicRepository: musicRepository,
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack.noMusic(),
      );

      expect(find.textContaining('Could not load soundtracks'), findsOneWidget);

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.catalog.retry')),
      );

      expect(musicRepository.getAvailableTracksCalls, 2);
      expect(find.text('Autumn Leaves'), findsOneWidget);
    });

    testWidgets('shouldRenderSoundtrackFailureWithoutHidingCatalog', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getFailures.add(
            const MusicApplicationException(MusicUnavailable()),
          ),
      );

      expect(find.textContaining('Could not load soundtrack'), findsOneWidget);
      expect(find.text('Autumn Leaves'), findsOneWidget);
    });

    testWidgets('shouldRenderEditorReadOnly', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic();

      await pumpScreen(
        tester,
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(role: StoryRole.editor),
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: soundtrackRepository,
      );

      expect(find.text('Read-only'), findsOneWidget);
      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-a')),
      );

      expect(soundtrackRepository.operations, <String>['get:story-1']);
    });

    testWidgets('shouldRenderViewerReadOnly', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic();

      await pumpScreen(
        tester,
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(role: StoryRole.viewer),
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: soundtrackRepository,
      );

      expect(find.text('Read-only'), findsOneWidget);
      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.no-music-row')),
      );

      expect(soundtrackRepository.operations, <String>['get:story-1']);
    });
  });

  group('SoundtrackSelectionScreen mutations', () {
    testWidgets('shouldSetTrackAndRemainOnScreen', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setResult = StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        );

      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: soundtrackRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-a')),
      );

      expect(soundtrackRepository.operations, <String>[
        'get:story-1',
        'set:story-1:track-a',
      ]);
      expect(find.text('Choose soundtrack'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('shouldRemoveSoundtrackThroughNoMusicRow', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        )
        ..removeResult = StorySoundtrack.noMusic();

      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA],
        soundtrackRepository: soundtrackRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.no-music-row')),
      );

      expect(soundtrackRepository.operations, <String>[
        'get:story-1',
        'remove:story-1',
      ]);
      expect(find.text('No music'), findsWidgets);
    });

    testWidgets('shouldDisableChoicesWhileMutationIsPending', (tester) async {
      final completer = Completer<StorySoundtrack>();
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setCompleter = completer;

      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA, trackB],
        soundtrackRepository: soundtrackRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-a')),
        settle: false,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-b')),
        settle: false,
      );

      expect(soundtrackRepository.operations, <String>[
        'get:story-1',
        'set:story-1:track-a',
      ]);

      completer.complete(
        StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shouldPreserveSelectionOnMutationFailure', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        )
        ..setFailures.add(
          const MusicApplicationException(MusicServerFailure()),
        );

      await pumpScreen(
        tester,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackA, trackB],
        soundtrackRepository: soundtrackRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-b')),
      );

      expect(
        find.text('Could not update soundtrack. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Autumn Leaves'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('shouldAllowCoOwnerToMutate', (tester) async {
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setResult = StorySoundtrack(
          selectedSoundtrack: trackB,
          effectiveSoundtrack: trackB,
        );

      await pumpScreen(
        tester,
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(role: StoryRole.coOwner),
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[trackB],
        soundtrackRepository: soundtrackRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-b')),
      );

      expect(soundtrackRepository.operations, <String>[
        'get:story-1',
        'set:story-1:track-b',
      ]);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  FakeStoryRepository? storyRepository,
  required FakeMusicRepository musicRepository,
  required FakeStorySoundtrackRepository soundtrackRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
      musicRepositoryProvider.overrideWithValue(musicRepository),
      storySoundtrackRepositoryProvider.overrideWithValue(soundtrackRepository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SoundtrackSelectionScreen(
          storyId: 'story-1',
          onBack: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

Future<void> tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.tap(finder);

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

UserStory userStory({
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: 'story-1',
      title: 'Our story',
      description: 'Together since 2021',
      createdAt: DateTime.utc(2026, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
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

final class FakeStoryRepository implements StoryRepository {
  UserStory storyResult = userStory();

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    return storyResult;
  }

  @override
  Future<List<UserStory>> getStories() async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    throw UnimplementedError();
  }
}

final class FakeMusicRepository implements MusicRepository {
  int getAvailableTracksCalls = 0;
  List<MusicTrack> tracksResult = const <MusicTrack>[];
  final List<List<MusicTrack>> tracksResults = <List<MusicTrack>>[];
  final List<Object> getFailures = <Object>[];

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    getAvailableTracksCalls += 1;
    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }
    if (tracksResults.isNotEmpty) {
      return tracksResults.removeAt(0);
    }

    return tracksResult;
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  final List<String> operations = <String>[];
  final List<Object> getFailures = <Object>[];
  final List<Object> setFailures = <Object>[];
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

    return getResult;
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) async {
    operations.add('set:$storyId:$musicTrackId');
    final completer = setCompleter;
    if (completer != null) {
      setCompleter = null;
      return completer.future;
    }
    if (setFailures.isNotEmpty) {
      throw setFailures.removeAt(0);
    }

    return setResult;
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    operations.add('remove:$storyId');
    return removeResult;
  }
}
