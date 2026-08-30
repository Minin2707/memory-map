import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';

void main() {
  group('StoryPhotoPreview', () {
    test('shouldCreatePreview', () {
      final preview = StoryPhotoPreview(
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
        displayPath: '/api/v1/media/media-id/display',
      );

      expect(preview.thumbnailPath, '/api/v1/media/media-id/thumbnail');
      expect(preview.displayPath, '/api/v1/media/media-id/display');
    });

    test('shouldRejectBlankThumbnailPath', () {
      expect(
        () => StoryPhotoPreview(
          thumbnailPath: '   ',
          displayPath: '/api/v1/media/media-id/display',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectBlankDisplayPath', () {
      expect(
        () => StoryPhotoPreview(
          thumbnailPath: '/api/v1/media/media-id/thumbnail',
          displayPath: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectExternalThumbnailUrl', () {
      expect(
        () => StoryPhotoPreview(
          thumbnailPath: 'https://cdn.example/media-id',
          displayPath: '/api/v1/media/media-id/display',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectMalformedBackendPath', () {
      expect(
        () => StoryPhotoPreview(
          thumbnailPath: '/api/v1/media/media-id/display',
          displayPath: '/api/v1/media/media-id/display',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldAllowStoryCoverPaths', () {
      final preview = StoryPhotoPreview(
        thumbnailPath: '/api/v1/stories/story-id/cover/thumbnail/1760000000000',
        displayPath: '/api/v1/stories/story-id/cover/display/1760000000000',
      );

      expect(
        preview.thumbnailPath,
        '/api/v1/stories/story-id/cover/thumbnail/1760000000000',
      );
      expect(
        preview.displayPath,
        '/api/v1/stories/story-id/cover/display/1760000000000',
      );
    });

    test('shouldCompareByValue', () {
      final first = StoryPhotoPreview(
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
        displayPath: '/api/v1/media/media-id/display',
      );
      final second = StoryPhotoPreview(
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
        displayPath: '/api/v1/media/media-id/display',
      );
      final different = StoryPhotoPreview(
        thumbnailPath: '/api/v1/media/other-media-id/thumbnail',
        displayPath: '/api/v1/media/other-media-id/display',
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final preview = StoryPhotoPreview(
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
        displayPath: '/api/v1/media/private-media-id/display',
      );

      expect(
        preview.toString(),
        'StoryPhotoPreview(hasThumbnailPath: true, hasDisplayPath: true)',
      );
      expect(preview.toString(), isNot(contains('private-media-id')));
      expect(preview.toString(), isNot(contains('/api/v1/media')));
      expect(preview.toString(), isNot(contains('token')));
    });
  });
}
