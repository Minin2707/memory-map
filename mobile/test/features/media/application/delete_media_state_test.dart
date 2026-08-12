import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/delete_media_state.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

void main() {
  group('DeleteMediaState', () {
    test('shouldExposeDefaultsAndCopyWith', () {
      const state = DeleteMediaState();

      expect(state.isDeleting, isFalse);
      expect(state.deleteFailure, isNull);
      expect(state.hasDeleteFailure, isFalse);
      expect(
        state.copyWith(
          isDeleting: true,
          deleteFailure: const MediaUnavailable(),
        ),
        const DeleteMediaState(
          isDeleting: true,
          deleteFailure: MediaUnavailable(),
        ),
      );
      expect(
        const DeleteMediaState(deleteFailure: MediaUnavailable()).copyWith(
          clearDeleteFailure: true,
        ),
        const DeleteMediaState(),
      );
    });

    test('shouldSupportEqualityHashCodeAndSafeToString', () {
      const first = DeleteMediaState(
        isDeleting: true,
        deleteFailure: MediaUnavailable(),
      );
      const second = DeleteMediaState(
        isDeleting: true,
        deleteFailure: MediaUnavailable(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'DeleteMediaState(isDeleting: true, hasDeleteFailure: true)',
      );
      expect(first.toString(), isNot(contains('media-id')));
      expect(first.toString(), isNot(contains('/api/v1/media')));
      expect(first.toString(), isNot(contains('accessToken')));
    });
  });
}
