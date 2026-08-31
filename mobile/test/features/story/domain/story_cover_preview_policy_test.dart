import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_cover_preview_policy.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';

void main() {
  group('isExplicitStoryCoverPreview', () {
    test('shouldReturnFalseForNullPreview', () {
      expect(
        isExplicitStoryCoverPreview(storyId: 'story-1', preview: null),
        isFalse,
      );
    });

    test('shouldReturnFalseForAutomaticMemoryPreview', () {
      expect(
        isExplicitStoryCoverPreview(
          storyId: 'story-1',
          preview: StoryPhotoPreview(
            thumbnailPath: '/api/v1/media/media-a/thumbnail',
            displayPath: '/api/v1/media/media-a/display',
          ),
        ),
        isFalse,
      );
    });

    test('shouldReturnTrueForMatchingStoryCoverPreview', () {
      expect(
        isExplicitStoryCoverPreview(
          storyId: 'story-1',
          preview: StoryPhotoPreview(
            thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/123',
            displayPath: '/api/v1/stories/story-1/cover/display/123',
          ),
        ),
        isTrue,
      );
    });

    test('shouldReturnFalseForMalformedStoryCoverPreview', () {
      final previews = <StoryPhotoPreview>[
        StoryPhotoPreview(
          thumbnailPath: '/api/v1/stories/other-story/cover/thumbnail/123',
          displayPath: '/api/v1/stories/story-1/cover/display/123',
        ),
        StoryPhotoPreview(
          thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/latest',
          displayPath: '/api/v1/stories/story-1/cover/display/123',
        ),
        StoryPhotoPreview(
          thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/123/extra',
          displayPath: '/api/v1/stories/story-1/cover/display/123/extra',
        ),
        StoryPhotoPreview(
          thumbnailPath: '/api/v1/stories/story-1/not-cover/thumbnail/123',
          displayPath: '/api/v1/stories/story-1/not-cover/display/123',
        ),
      ];

      for (final preview in previews) {
        expect(
          isExplicitStoryCoverPreview(
            storyId: 'story-1',
            preview: preview,
          ),
          isFalse,
        );
      }
    });
  });
}
