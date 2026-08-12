import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

void main() {
  group('PreparedPhotoUpload', () {
    test('shouldExposePreparedBytesAndContentType', () {
      final upload = PreparedPhotoUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: 'image/jpeg',
      );

      expect(upload.bytes, <int>[1, 2, 3]);
      expect(upload.contentType, 'image/jpeg');
      expect(upload.byteLength, 3);
    });

    test('shouldDefensivelyCopyInputAndOutputBytes', () {
      final input = Uint8List.fromList(<int>[1, 2, 3]);
      final upload = PreparedPhotoUpload(
        bytes: input,
        contentType: 'image/jpeg',
      );

      input[0] = 9;
      final output = upload.bytes;
      output[1] = 9;

      expect(upload.bytes, <int>[1, 2, 3]);
    });

    test('shouldRejectInvalidValues', () {
      expect(
        () => PreparedPhotoUpload(
          bytes: Uint8List(0),
          contentType: 'image/jpeg',
        ),
        throwsArgumentError,
      );
      expect(
        () => PreparedPhotoUpload(
          bytes: Uint8List.fromList(<int>[1]),
          contentType: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('shouldCompareByValue', () {
      expect(
        PreparedPhotoUpload(
          bytes: Uint8List.fromList(<int>[1, 2]),
          contentType: 'image/jpeg',
        ),
        PreparedPhotoUpload(
          bytes: Uint8List.fromList(<int>[1, 2]),
          contentType: 'image/jpeg',
        ),
      );
    });

    test('shouldExposeSafeToString', () {
      final text = PreparedPhotoUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: 'image/jpeg',
      ).toString();

      expect(text, contains('byteLength: 3'));
      expect(text, isNot(contains('[1, 2, 3]')));
      expect(text, isNot(contains('image/jpeg')));
      expect(text, isNot(contains('C:\\')));
      expect(text, isNot(contains('/Users/')));
    });
  });
}
