import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/media_type.dart';

void main() {
  group('MediaType', () {
    test('shouldParseBackendPhotoValue', () {
      expect(MediaType.parse('PHOTO'), MediaType.photo);
    });

    test('shouldRejectUnsupportedValues', () {
      expect(() => MediaType.parse('VOICE'), throwsFormatException);
      expect(() => MediaType.parse('photo'), throwsFormatException);
      expect(() => MediaType.parse(''), throwsFormatException);
    });

  });
}
