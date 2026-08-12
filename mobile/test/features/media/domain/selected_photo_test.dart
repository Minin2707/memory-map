import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';

void main() {
  group('SelectedPhoto', () {
    test('shouldExposeReadBytesCallbackAndDeclaredContentType', () async {
      final photo = SelectedPhoto(
        readBytes: () async => Uint8List.fromList(<int>[1, 2, 3]),
        declaredContentType: 'image/png',
      );

      expect(await photo.readBytes(), <int>[1, 2, 3]);
      expect(photo.declaredContentType, 'image/png');
    });

    test('shouldAllowMissingDeclaredContentType', () {
      final photo = SelectedPhoto(
        readBytes: () async => Uint8List.fromList(<int>[1]),
      );

      expect(photo.declaredContentType, isNull);
    });

    test('shouldRejectBlankDeclaredContentType', () {
      expect(
        () => SelectedPhoto(
          readBytes: () async => Uint8List.fromList(<int>[1]),
          declaredContentType: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('shouldExposeSafeToString', () {
      final text = SelectedPhoto(
        readBytes: () async => Uint8List.fromList(<int>[1]),
        declaredContentType: 'image/jpeg',
      ).toString();

      expect(text, contains('SelectedPhoto'));
      expect(text, isNot(contains('image/jpeg')));
      expect(text, isNot(contains('C:\\')));
      expect(text, isNot(contains('/private/photo.jpg')));
    });
  });
}
