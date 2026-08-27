import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/application/playback_media_prefetcher.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

void main() {
  group('PlaybackMediaPrefetcher', () {
    test('shouldPrefetchNextMemoryDisplayPathThroughMediaRepository', () async {
      final repository = FakeMediaRepository();
      final prefetcher = DefaultPlaybackMediaPrefetcher(
        mediaRepository: repository,
      );
      final playback = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memoryA),
        readModel(memoryB, previewPhoto: previewPhoto('media-b')),
      ]);

      await prefetcher.prefetchNext(playback);

      expect(repository.displayPaths, <String>[
        '/api/v1/media/media-b/display',
      ]);
      expect(repository.thumbnailPaths, isEmpty);
    });

    test('shouldNoopWhenThereIsNoNextMemory', () async {
      final repository = FakeMediaRepository();
      final prefetcher = DefaultPlaybackMediaPrefetcher(
        mediaRepository: repository,
      );

      await prefetcher.prefetchNext(
        StoryPlaybackState.start(<MemoryReadModel>[
          readModel(memoryA, previewPhoto: previewPhoto('media-a')),
        ]),
      );

      expect(repository.displayPaths, isEmpty);
    });

    test('shouldNoopWhenNextMemoryHasNoPreviewPhoto', () async {
      final repository = FakeMediaRepository();
      final prefetcher = DefaultPlaybackMediaPrefetcher(
        mediaRepository: repository,
      );

      await prefetcher.prefetchNext(
        StoryPlaybackState.start(<MemoryReadModel>[
          readModel(memoryA, previewPhoto: previewPhoto('media-a')),
          readModel(memoryB),
        ]),
      );

      expect(repository.displayPaths, isEmpty);
    });

    test('shouldTreatFailureAsNonfatal', () async {
      final repository = FakeMediaRepository()..displayFailure = Object();
      final prefetcher = DefaultPlaybackMediaPrefetcher(
        mediaRepository: repository,
      );

      await expectLater(
        prefetcher.prefetchNext(
          StoryPlaybackState.start(<MemoryReadModel>[
            readModel(memoryA),
            readModel(memoryB, previewPhoto: previewPhoto('media-b')),
          ]),
        ),
        completes,
      );
    });

    test('shouldDeriveOnlyTheNextPlaybackDisplayPath', () {
      final playback = StoryPlaybackState.start(<MemoryReadModel>[
        readModel(memoryA, previewPhoto: previewPhoto('media-a')),
        readModel(memoryB, previewPhoto: previewPhoto('media-b')),
        readModel(memoryC, previewPhoto: previewPhoto('media-c')),
      ]);

      expect(
        nextPlaybackDisplayPath(playback),
        '/api/v1/media/media-b/display',
      );
    });
  });
}

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

MemoryPhotoPreview previewPhoto(String mediaId) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  required String id,
  required int day,
}) {
  return Memory(
    id: id,
    storyId: 'story-1',
    createdBy: 'author-id',
    title: id,
    description: null,
    placeName: null,
    location: MemoryLocation(latitude: 41.7151 + day, longitude: 44.8271),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, day, 10),
    updatedAt: DateTime.utc(2026, 8, day, 11),
  );
}

final Memory memoryA = memory(id: 'memory-a', day: 1);
final Memory memoryB = memory(id: 'memory-b', day: 2);
final Memory memoryC = memory(id: 'memory-c', day: 3);

final class FakeMediaRepository implements MediaRepository {
  final List<String> displayPaths = <String>[];
  final List<String> thumbnailPaths = <String>[];
  Object? displayFailure;

  @override
  Future<void> deleteMedia(String mediaId) async {}

  @override
  Future<Uint8List> getDisplay(Media media) async {
    return getDisplayByPath(media.displayPath);
  }

  @override
  Future<Uint8List> getDisplayByPath(String displayPath) async {
    displayPaths.add(displayPath);
    final failure = displayFailure;
    if (failure != null) {
      throw failure;
    }
    return Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0x01]);
  }

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    return <Media>[];
  }

  @override
  Future<Uint8List> getThumbnail(Media media) async {
    return getThumbnailByPath(media.thumbnailPath);
  }

  @override
  Future<Uint8List> getThumbnailByPath(String thumbnailPath) async {
    thumbnailPaths.add(thumbnailPath);
    return Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0x02]);
  }

  @override
  Future<Media> uploadPhoto(
    String memoryId,
    PreparedPhotoUpload photo,
  ) {
    throw UnimplementedError();
  }
}
