import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/application/music_catalog_notifier.dart';
import 'package:memory_map/features/music/application/music_catalog_state.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/music_track.dart';

void main() {
  group('MusicCatalogNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<List<MusicTrack>>();
      final repository = FakeMusicRepository()..getCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(musicCatalogProvider.future);

      expect(
        container.read(musicCatalogProvider),
        isA<AsyncLoading<MusicCatalogState>>(),
      );

      completer.complete(<MusicTrack>[trackA]);
      await future;
    });

    test('shouldLoadAvailableTracksInBackendOrder', () async {
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[trackB, trackA];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(musicCatalogProvider.future);

      expect(state.tracks, <MusicTrack>[trackB, trackA]);
      expect(repository.getAvailableTracksCalls, 1);
    });

    test('shouldReuseLoadedCatalogWithinProviderSession', () async {
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[trackA];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      await container.read(musicCatalogProvider.future);
      await container.read(musicCatalogProvider.future);

      expect(repository.getAvailableTracksCalls, 1);
    });

    test('shouldRepresentEmptyCatalogWithoutFailure', () async {
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(musicCatalogProvider.future);

      expect(state.tracks, isEmpty);
      expect(state.loadFailure, isNull);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeMusicRepository()
        ..failures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(musicCatalogProvider.future);

      expect(state.tracks, isEmpty);
      expect(state.loadFailure, const MusicNetworkUnavailable());
    });
  });

  group('MusicCatalogNotifier retry and refresh', () {
    test('shouldRetryAfterKnownFailure', () async {
      final repository = FakeMusicRepository()
        ..failures.add(
          const MusicApplicationException(MusicRequestTimedOut()),
        )
        ..tracksResults.add(<MusicTrack>[trackA]);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(musicCatalogProvider.future);

      await container.read(musicCatalogProvider.notifier).retryLoad();

      final state = readState(container);
      expect(repository.getAvailableTracksCalls, 2);
      expect(state.tracks, <MusicTrack>[trackA]);
      expect(state.loadFailure, isNull);
    });

    test('shouldRefreshWithoutClearingCurrentCatalog', () async {
      final refreshCompleter = Completer<List<MusicTrack>>();
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[trackA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(musicCatalogProvider.future);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(musicCatalogProvider.notifier)
          .refreshCatalog();
      await pumpEventQueue();

      expect(readState(container).tracks, <MusicTrack>[trackA]);
      expect(readState(container).isRefreshing, isTrue);
      expect(repository.getAvailableTracksCalls, 2);

      refreshCompleter.complete(<MusicTrack>[trackB, trackA]);
      await refresh;

      expect(readState(container).tracks, <MusicTrack>[trackB, trackA]);
      expect(readState(container).isRefreshing, isFalse);
    });

    test('shouldKeepCatalogAndExposeRefreshFailure', () async {
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[trackA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(musicCatalogProvider.future);
      repository.failures.add(
        const MusicApplicationException(MusicServerFailure()),
      );

      await container.read(musicCatalogProvider.notifier).refreshCatalog();

      expect(readState(container).tracks, <MusicTrack>[trackA]);
      expect(readState(container).refreshFailure, const MusicServerFailure());
    });

    test('shouldIgnoreRefreshAfterLoadFailure', () async {
      final repository = FakeMusicRepository()
        ..failures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(musicCatalogProvider.future);

      await container.read(musicCatalogProvider.notifier).refreshCatalog();

      expect(repository.getAvailableTracksCalls, 1);
    });
  });

  group('MusicCatalogNotifier security', () {
    test('shouldNotExposeTrackDetailsThroughStateToString', () async {
      final repository = FakeMusicRepository()
        ..tracksResult = <MusicTrack>[
          MusicTrack(
            id: 'private-track-id',
            title: 'Private title',
            artist: 'Private artist',
            durationSeconds: 270,
          ),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(musicCatalogProvider.future);

      final text = container.read(musicCatalogProvider).toString();

      expect(text, isNot(contains('private-track-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private artist')));
      expect(text, isNot(contains('storageKey')));
      expect(text, isNot(contains('token')));
    });
  });
}

ProviderContainer createContainer(FakeMusicRepository repository) {
  return ProviderContainer(
    overrides: [
      musicRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

MusicCatalogState readState(ProviderContainer container) {
  return container.read(musicCatalogProvider).asData!.value;
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

final class FakeMusicRepository implements MusicRepository {
  int getAvailableTracksCalls = 0;
  Completer<List<MusicTrack>>? getCompleter;
  List<MusicTrack> tracksResult = <MusicTrack>[];
  final List<List<MusicTrack>> tracksResults = <List<MusicTrack>>[];
  final List<Object> failures = <Object>[];

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    getAvailableTracksCalls += 1;

    final configuredCompleter = getCompleter;
    if (configuredCompleter != null) {
      getCompleter = null;
      return configuredCompleter.future;
    }

    if (failures.isNotEmpty) {
      throw failures.removeAt(0);
    }

    if (tracksResults.isNotEmpty) {
      return tracksResults.removeAt(0);
    }

    return tracksResult;
  }
}
