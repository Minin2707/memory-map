import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';

void main() {
  group('MemoryPhotoPreview', () {
    test('shouldExposeValidPreview', () {
      final preview = MemoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );

      expect(preview.mediaId, 'media-id');
      expect(preview.thumbnailPath, '/api/v1/media/media-id/thumbnail');
    });

    test('shouldRejectBlankMediaId', () {
      expect(
        () => MemoryPhotoPreview(
          mediaId: '   ',
          thumbnailPath: '/api/v1/media/media-id/thumbnail',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldRejectNonBackendThumbnailPath', () {
      expect(
        () => MemoryPhotoPreview(
          mediaId: 'media-id',
          thumbnailPath: 'https://cdn.example.test/media-id',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldCompareByValue', () {
      final first = MemoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );
      final second = MemoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final preview = MemoryPhotoPreview(
        mediaId: 'private-media-id',
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
      );

      expect(preview.toString(), 'MemoryPhotoPreview(hasThumbnailPath: true)');
      expect(preview.toString(), isNot(contains('private-media-id')));
      expect(preview.toString(), isNot(contains('/api/v1/media')));
    });
  });
}
