import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/domain/playback_phase.dart';
import 'package:memory_map/features/playback/domain/playback_status.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

void main() {
  group('StoryPlaybackState snapshot', () {
    test('shouldRepresentIdleInitialState', () {
      final state = StoryPlaybackState.idle();

      expect(state.status, PlaybackStatus.idle);
      expect(state.phase, isNull);
      expect(state.currentIndex, isNull);
      expect(state.currentMemory, isNull);
      expect(state.snapshot, isEmpty);
      expect(state.cameraCommand, isNull);
      expect(state.progress.currentPosition, 0);
      expect(state.progress.total, 0);
    });

    test('shouldStartWithCanonicalSnapshotWithoutMutatingSourceList', () {
      final source = <MemoryReadModel>[
        readModel(memory(id: 'memory-c', day: 20)),
        readModel(memory(id: 'memory-a', day: 10)),
        readModel(memory(id: 'memory-b', day: 15)),
      ];

      final state = StoryPlaybackState.start(source);

      expect(
        source.map((item) => item.memory.id),
        <String>['memory-c', 'memory-a', 'memory-b'],
      );
      expect(
        state.snapshot.map((item) => item.memory.id),
        <String>['memory-a', 'memory-b', 'memory-c'],
      );
      expect(
        () => state.snapshot.add(readModel(memory(id: 'memory-d'))),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldKeepSnapshotStableWhenSourceListChangesLater', () {
      final source = <MemoryReadModel>[readModel(memory(id: 'memory-a'))];
      final state = StoryPlaybackState.start(source);

      source
        ..clear()
        ..add(readModel(memory(id: 'memory-b')));

      expect(
        state.snapshot.map((item) => item.memory.id),
        <String>['memory-a'],
      );
      expect(state.currentMemory?.memory.id, 'memory-a');
    });

    test('shouldOrderSameDateByCreatedAtThenId', () {
      final state = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memory(id: 'memory-c', createdHour: 12)),
        readModel(memory(id: 'memory-a', createdHour: 10)),
        readModel(memory(id: 'memory-b', createdHour: 11)),
      ]);

      expect(
        state.snapshot.map((item) => item.memory.id),
        <String>['memory-a', 'memory-b', 'memory-c'],
      );
    });

    test('shouldPreservePreviewMetadataInSnapshot', () {
      final preview = previewPhoto(mediaId: 'media-a');
      final state = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memory(id: 'memory-a'), previewPhoto: preview),
      ]);

      expect(state.currentMemory?.previewPhoto, same(preview));
    });

    test('shouldStartEmptyInputAsSafeIdleEmptyState', () {
      final state = StoryPlaybackState.start(const <MemoryReadModel>[]);

      expect(state.status, PlaybackStatus.idle);
      expect(state.snapshot, isEmpty);
      expect(state.progress.currentPosition, 0);
      expect(state.progress.total, 0);
      expect(state.cameraCommand, isNull);
    });
  });

  group('StoryPlaybackState start and camera arrival', () {
    test('shouldStartNonEmptySessionMovingToOldestMemory', () {
      final state = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memory(id: 'memory-b', day: 20, latitude: 1, longitude: 2)),
        readModel(memory(id: 'memory-a', day: 10, latitude: 3, longitude: 4)),
      ]);

      expect(state.status, PlaybackStatus.playing);
      expect(state.phase, PlaybackPhase.moving);
      expect(state.currentIndex, 0);
      expect(state.currentMemory?.memory.id, 'memory-a');
      expect(state.cameraRevision, 1);
      expect(state.cameraCommand?.revision, 1);
      expect(state.cameraCommand?.memoryIndex, 0);
      expect(state.cameraCommand?.target.latitude, 3);
      expect(state.cameraCommand?.target.longitude, 4);
      expect(state.cameraCommand?.duration, const Duration(seconds: 2));
      expect(state.progress.currentPosition, 1);
      expect(state.progress.total, 2);
    });

    test('shouldEnterPresentingOnlyForCurrentCameraRevision', () {
      final moving = started();

      final stale = moving.cameraArrived(moving.cameraRevision - 1);
      final presenting = moving.cameraArrived(moving.cameraRevision);

      expect(stale, moving);
      expect(presenting.status, PlaybackStatus.playing);
      expect(presenting.phase, PlaybackPhase.presenting);
      expect(presenting.presentationRevision, moving.presentationRevision + 1);
      expect(presenting.cameraCommand, isNull);
    });

    test('shouldIgnoreCameraArrivalWhilePausedOrFinishedOrStopped', () {
      final moving = started();
      final paused = moving.pause();
      final finished = moving
          .cameraArrived(moving.cameraRevision)
          .presentationElapsed(1)
          .cameraArrived(2)
          .presentationElapsed(2);
      final stopped = moving.stop();

      expect(paused.cameraArrived(moving.cameraRevision), paused);
      expect(finished.cameraArrived(finished.cameraRevision), finished);
      expect(stopped.cameraArrived(moving.cameraRevision), stopped);
    });
  });

  group('StoryPlaybackState autoplay and progress', () {
    test('shouldAdvanceFromPresentingToNextMoving', () {
      final presenting = started().cameraArrived(1);
      final next = presenting.presentationElapsed(
        presenting.presentationRevision,
      );

      expect(next.status, PlaybackStatus.playing);
      expect(next.phase, PlaybackPhase.moving);
      expect(next.currentMemory?.memory.id, 'memory-b');
      expect(next.cameraRevision, 2);
      expect(next.cameraCommand?.revision, 2);
      expect(next.progress.currentPosition, 2);
      expect(next.progress.total, 2);
    });

    test('shouldFinishAfterLastPresentationElapsed', () {
      final firstPresenting = started().cameraArrived(1);
      final secondMoving = firstPresenting.presentationElapsed(
        firstPresenting.presentationRevision,
      );
      final secondPresenting = secondMoving.cameraArrived(2);
      final finished = secondPresenting.presentationElapsed(
        secondPresenting.presentationRevision,
      );

      expect(finished.status, PlaybackStatus.finished);
      expect(finished.phase, isNull);
      expect(finished.currentMemory?.memory.id, 'memory-b');
      expect(finished.cameraCommand, isNull);
      expect(finished.progress.currentPosition, 2);
      expect(finished.progress.total, 2);
      expect(finished.progress.fraction, 1);
    });

    test('shouldIgnoreStalePresentationElapsedEvents', () {
      final presenting = started().cameraArrived(1);

      final stale = presenting.presentationElapsed(
        presenting.presentationRevision - 1,
      );

      expect(stale, presenting);
    });
  });

  group('StoryPlaybackState pause and resume', () {
    test('shouldPauseAndResumePresentingWithFreshPresentationRevision', () {
      final presenting = started().cameraArrived(1);
      final paused = presenting.pause();
      final staleElapsed = paused.presentationElapsed(
        presenting.presentationRevision,
      );
      final resumed = paused.resume();

      expect(paused.status, PlaybackStatus.paused);
      expect(paused.phase, PlaybackPhase.presenting);
      expect(paused.presentationRevision, presenting.presentationRevision + 1);
      expect(staleElapsed, paused);
      expect(resumed.status, PlaybackStatus.playing);
      expect(resumed.phase, PlaybackPhase.presenting);
      expect(resumed.cameraCommand, isNull);
      expect(resumed.presentationRevision, paused.presentationRevision + 1);
    });

    test('shouldPauseMovingAndResumeWithFreshCameraRevisionToSameMemory', () {
      final moving = started();
      final paused = moving.pause();
      final staleArrival = paused.cameraArrived(moving.cameraRevision);
      final resumed = paused.resume();

      expect(paused.status, PlaybackStatus.paused);
      expect(paused.phase, PlaybackPhase.moving);
      expect(staleArrival, paused);
      expect(resumed.status, PlaybackStatus.playing);
      expect(resumed.phase, PlaybackPhase.moving);
      expect(resumed.currentMemory?.memory.id, moving.currentMemory?.memory.id);
      expect(resumed.cameraRevision, moving.cameraRevision + 1);
      expect(resumed.cameraCommand?.revision, resumed.cameraRevision);
    });
  });

  group('StoryPlaybackState camera retry', () {
    test('shouldRetryMovingCameraWithFreshRevisionToSameMemory', () {
      final moving = started();

      final retried = moving.retryCamera();

      expect(retried.status, PlaybackStatus.playing);
      expect(retried.phase, PlaybackPhase.moving);
      expect(retried.currentMemory?.memory.id, moving.currentMemory?.memory.id);
      expect(retried.cameraRevision, moving.cameraRevision + 1);
      expect(retried.cameraCommand?.revision, retried.cameraRevision);
      expect(retried.cameraCommand?.target, moving.cameraCommand?.target);
    });

    test('shouldNoopRetryWhenNotMoving', () {
      final presenting = started().cameraArrived(1);
      final idle = StoryPlaybackState.idle();

      expect(presenting.retryCamera(), presenting);
      expect(idle.retryCamera(), idle);
    });
  });

  group('StoryPlaybackState next and previous', () {
    test('shouldMoveNextFromPresentingAndInvalidateCurrentPresentation', () {
      final presenting = started().cameraArrived(1);

      final next = presenting.next();
      final staleElapsed = next.presentationElapsed(
        presenting.presentationRevision,
      );

      expect(next.currentMemory?.memory.id, 'memory-b');
      expect(next.phase, PlaybackPhase.moving);
      expect(next.cameraRevision, 2);
      expect(next.presentationRevision, presenting.presentationRevision + 1);
      expect(staleElapsed, next);
    });

    test('shouldMoveNextFromMovingWithLatestWinsCameraRevision', () {
      final moving = threeItemStarted();

      final next = moving.next();
      final staleArrival = next.cameraArrived(moving.cameraRevision);

      expect(next.currentMemory?.memory.id, 'memory-b');
      expect(next.phase, PlaybackPhase.moving);
      expect(next.cameraRevision, moving.cameraRevision + 1);
      expect(staleArrival, next);
    });

    test('shouldMovePreviousFromPresentingAndMoving', () {
      final secondMoving = threeItemStarted().next();
      final secondPresenting = secondMoving.cameraArrived(
        secondMoving.cameraRevision,
      );
      final previousFromPresenting = secondPresenting.previous();
      final previousFromMoving = secondMoving.previous();

      expect(previousFromPresenting.currentMemory?.memory.id, 'memory-a');
      expect(previousFromPresenting.phase, PlaybackPhase.moving);
      expect(previousFromMoving.currentMemory?.memory.id, 'memory-a');
      expect(previousFromMoving.phase, PlaybackPhase.moving);
    });

    test('shouldKeepPausedStatusWhenNavigatingWhilePaused', () {
      final paused = threeItemStarted().pause();

      final next = paused.next();
      final resumed = next.resume();

      expect(next.status, PlaybackStatus.paused);
      expect(next.phase, PlaybackPhase.moving);
      expect(next.currentMemory?.memory.id, 'memory-b');
      expect(next.cameraCommand, isNull);
      expect(resumed.status, PlaybackStatus.playing);
      expect(resumed.cameraCommand?.revision, resumed.cameraRevision);
      expect(resumed.currentMemory?.memory.id, 'memory-b');
    });

    test('shouldNoopPreviousAtFirstAndFinishNextAtLastPresenting', () {
      final first = started();
      final lastPresenting = first
          .cameraArrived(1)
          .presentationElapsed(1)
          .cameraArrived(2);

      expect(first.previous(), first);

      final finished = lastPresenting.next();

      expect(finished.status, PlaybackStatus.finished);
      expect(finished.currentMemory?.memory.id, 'memory-b');
      expect(finished.cameraCommand, isNull);
    });

    test('shouldNoopNextAtLastMoving', () {
      final lastMoving = started().next();

      expect(lastMoving.next(), lastMoving);
    });
  });

  group('StoryPlaybackState finish replay and stop', () {
    test('shouldFinishOneMemoryAndReplaySameSnapshot', () {
      final initial = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memory(id: 'memory-a')),
      ]);
      final finished = initial
          .cameraArrived(initial.cameraRevision)
          .presentationElapsed(1);
      final replayed = finished.replay();

      expect(finished.status, PlaybackStatus.finished);
      expect(finished.progress.currentPosition, 1);
      expect(finished.progress.total, 1);
      expect(replayed.status, PlaybackStatus.playing);
      expect(replayed.phase, PlaybackPhase.moving);
      expect(replayed.currentMemory?.memory.id, 'memory-a');
      expect(replayed.snapshot, same(finished.snapshot));
      expect(replayed.cameraRevision, finished.cameraRevision + 1);
    });

    test('shouldStopAndIgnoreStaleEvents', () {
      final presenting = started().cameraArrived(1);
      final stopped = presenting.stop();

      expect(stopped.status, PlaybackStatus.idle);
      expect(stopped.snapshot, isEmpty);
      expect(stopped.currentMemory, isNull);
      expect(stopped.cameraCommand, isNull);
      expect(
        stopped.cameraArrived(presenting.cameraRevision),
        stopped,
      );
      expect(
        stopped.presentationElapsed(presenting.presentationRevision),
        stopped,
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = started();
      final second = started();

      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final text = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(
          memory(
            id: 'private-memory-id',
            storyId: 'private-story-id',
            title: 'Private title',
            description: 'Private description',
            placeName: 'Private place',
            latitude: 41.715123,
            longitude: 44.827456,
          ),
          previewPhoto: previewPhoto(mediaId: 'private-media-id'),
        ),
      ]).toString();

      expect(text, contains('count: 1'));
      expect(text, contains('cameraRevision: 1'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
    });
  });
}

StoryPlaybackState started() {
  return StoryPlaybackState.start(<MemoryReadModel>[
    readModel(memory(id: 'memory-a', day: 10)),
    readModel(memory(id: 'memory-b', day: 20)),
  ]);
}

StoryPlaybackState threeItemStarted() {
  return StoryPlaybackState.start(<MemoryReadModel>[
    readModel(memory(id: 'memory-a', day: 10)),
    readModel(memory(id: 'memory-b', day: 20)),
    readModel(memory(id: 'memory-c', day: 30)),
  ]);
}

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  required String id,
  String storyId = 'story-id',
  String title = 'Memory title',
  String? description = 'Memory description',
  String? placeName = 'Memory place',
  double latitude = 41.7151,
  double longitude = 44.8271,
  int day = 9,
  int createdHour = 10,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: latitude, longitude: longitude),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}
