import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';

void main() {
  group('StoryPhotoPreview', () {
    test('shouldCreatePreview', () {
      final preview = StoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );

      expect(preview.mediaId, 'media-id');
      expect(preview.thumbnailPath, '/api/v1/media/media-id/thumbnail');
    });

    test('shouldRejectBlankMediaId', () {
      expect(
        () => StoryPhotoPreview(
          mediaId: '   ',
          thumbnailPath: '/api/v1/media/media-id/thumbnail',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectExternalThumbnailUrl', () {
      expect(
        () => StoryPhotoPreview(
          mediaId: 'media-id',
          thumbnailPath: 'https://cdn.example/media-id',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectMalformedBackendPath', () {
      expect(
        () => StoryPhotoPreview(
          mediaId: 'media-id',
          thumbnailPath: '/api/v1/media/media-id/display',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldCompareByValue', () {
      final first = StoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );
      final second = StoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );
      final different = StoryPhotoPreview(
        mediaId: 'other-media-id',
        thumbnailPath: '/api/v1/media/other-media-id/thumbnail',
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final preview = StoryPhotoPreview(
        mediaId: 'private-media-id',
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
      );

      expect(preview.toString(), 'StoryPhotoPreview(hasThumbnailPath: true)');
      expect(preview.toString(), isNot(contains('private-media-id')));
      expect(preview.toString(), isNot(contains('/api/v1/media')));
      expect(preview.toString(), isNot(contains('token')));
    });
  });
}
