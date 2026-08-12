import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/media_type.dart';

import '../media_test_fixtures.dart';

void main() {
  group('Media', () {
    test('shouldCreatePhotoMediaWithBackendRepresentationPaths', () {
      final item = media();

      expect(item.id, 'media-id');
      expect(item.memoryId, defaultMemoryId);
      expect(item.type, MediaType.photo);
      expect(item.isPhoto, isTrue);
      expect(item.displayFileSize, 1234);
      expect(item.thumbnailFileSize, 321);
      expect(item.mimeType, 'image/jpeg');
      expect(item.createdAt, DateTime.utc(2026, 8, 9, 10));
      expect(item.thumbnailPath, '/api/v1/media/media-id/thumbnail');
      expect(item.displayPath, '/api/v1/media/media-id/display');
    });

    test('shouldNormalizeCreatedAtToUtc', () {
      final item = media(
        createdAt: DateTime.parse('2026-08-09T14:00:00+04:00'),
      );

      expect(item.createdAt, DateTime.utc(2026, 8, 9, 10));
    });

    test('shouldRejectInvalidValues', () {
      expect(() => media(id: '   '), throwsArgumentError);
      expect(() => media(memoryId: '   '), throwsArgumentError);
      expect(() => media(displayFileSize: 0), throwsArgumentError);
      expect(() => media(thumbnailFileSize: 0), throwsArgumentError);
      expect(() => media(mimeType: '   '), throwsArgumentError);
      expect(
        () => media(thumbnailPath: 'https://storage.example/object'),
        throwsArgumentError,
      );
      expect(() => media(displayPath: '/minio/bucket/key'), throwsArgumentError);
    });

    test('shouldCompareByValue', () {
      expect(media(), media());
      expect(media(), isNot(media(id: 'other-media-id')));
    });

    test('shouldExposeSafeToString', () {
      final text = media(
        id: 'private-media-id',
        memoryId: 'private-memory-id',
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
        displayPath: '/api/v1/media/private-media-id/display',
      ).toString();

      expect(text, contains('Media'));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('MinIO')));
      expect(text, isNot(contains('bucket')));
    });
  });
}
