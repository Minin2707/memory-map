import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/data/dto/media_dto.dart';
import 'package:memory_map/features/media/domain/media_type.dart';

import '../../media_test_fixtures.dart';

void main() {
  group('MediaDto', () {
    test('shouldParseBackendMediaJson', () {
      final dto = MediaDto.fromJson(mediaJson());

      expect(dto.id, 'media-id');
      expect(dto.memoryId, defaultMemoryId);
      expect(dto.type, MediaType.photo);
      expect(dto.displayFileSize, 1234);
      expect(dto.thumbnailFileSize, 321);
      expect(dto.mimeType, 'image/jpeg');
      expect(dto.createdAt, DateTime.parse('2026-08-09T10:00:00Z'));
      expect(dto.thumbnailPath, '/api/v1/media/media-id/thumbnail');
      expect(dto.displayPath, '/api/v1/media/media-id/display');
      expect(dto.toDomain(), media());
    });

    test('shouldRejectMalformedJson', () {
      expect(() => MediaDto.fromJson(null), throwsFormatException);
      expect(
        () => MediaDto.fromJson(<String, Object?>{
          ...mediaJson(),
          'id': null,
        }),
        throwsFormatException,
      );
      expect(
        () => MediaDto.fromJson(mediaJson(mediaType: 'VOICE')),
        throwsFormatException,
      );
      expect(
        () => MediaDto.fromJson(mediaJson(displayFileSize: 0)),
        throwsFormatException,
      );
      expect(
        () => MediaDto.fromJson(mediaJson(thumbnailFileSize: 1.5)),
        throwsFormatException,
      );
      expect(
        () => MediaDto.fromJson(mediaJson(createdAt: 'not-a-date')),
        throwsFormatException,
      );
      expect(
        () => MediaDto.fromJson(
          mediaJson(thumbnailUrl: 'https://storage.example/bucket/key'),
        ),
        throwsFormatException,
      );
    });

    test('shouldExposeSafeToString', () {
      final text = MediaDto.fromJson(
        mediaJson(
          id: 'private-media-id',
          thumbnailUrl: '/api/v1/media/private-media-id/thumbnail',
          displayUrl: '/api/v1/media/private-media-id/display',
        ),
      ).toString();

      expect(text, 'MediaDto');
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('storage')));
    });
  });
}
