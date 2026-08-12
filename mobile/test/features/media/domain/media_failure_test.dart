import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

void main() {
  group('MediaFailure', () {
    test('shouldCompareFailuresByType', () {
      expect(const MediaUnavailable(), const MediaUnavailable());
      expect(const MediaUnavailable(), isNot(const MediaUnauthorized()));
    });

    test('shouldExposeSafeFailureToString', () {
      final text = const MediaUploadUnavailable().toString();

      expect(text, 'MediaUploadUnavailable');
      expect(text, isNot(contains('media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('MinIO')));
      expect(text, isNot(contains('bucket')));
    });
  });

  group('MediaApplicationException', () {
    test('shouldExposeFailureWithoutRawDetails', () {
      final exception = const MediaApplicationException(MediaUnauthorized());

      expect(exception.failure, const MediaUnauthorized());
      expect(exception.toString(), 'MediaApplicationException');
      expect(exception.toString(), isNot(contains('401')));
      expect(exception.toString(), isNot(contains('accessToken')));
    });
  });
}
