import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/data/preprocessing/image_photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

import '../../media_test_fixtures.dart';

void main() {
  group('ImagePhotoPreprocessor', () {
    test('shouldResizeWithinMaxLongSideAndEncodeJpeg', () async {
      final preprocessor = ImagePhotoPreprocessor(maxLongSide: 100);
      final source = encodePng(width: 400, height: 200);

      final prepared = await preprocessor.process(
        selectedPhoto(bytes: source, declaredContentType: 'image/png'),
      );
      final decoded = image.decodeJpg(prepared.bytes);

      expect(prepared.contentType, 'image/jpeg');
      expect(prepared.byteLength, lessThan(5 * 1024 * 1024));
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 50);
      expect(prepared.bytes, isNot(source));
    });

    test('shouldNeverUpscaleSmallImages', () async {
      final preprocessor = ImagePhotoPreprocessor(maxLongSide: 100);
      final source = encodeJpeg(width: 40, height: 20);

      final prepared = await preprocessor.process(
        selectedPhoto(bytes: source, declaredContentType: 'image/jpeg'),
      );
      final decoded = image.decodeJpg(prepared.bytes);

      expect(decoded!.width, 40);
      expect(decoded.height, 20);
    });

    test('shouldApplyExifOrientationBeforeEncoding', () async {
      final preprocessor = ImagePhotoPreprocessor(maxLongSide: 100);
      final sourceImage = solidImage(width: 20, height: 10);
      sourceImage.exif.imageIfd.orientation = 6;
      final source = image.encodeJpg(sourceImage);

      final prepared = await preprocessor.process(
        selectedPhoto(bytes: source, declaredContentType: 'image/jpeg'),
      );
      final decoded = image.decodeJpg(prepared.bytes);

      expect(decoded!.width, 10);
      expect(decoded.height, 20);
    });

    test('shouldFlattenPngAlphaToJpeg', () async {
      final preprocessor = ImagePhotoPreprocessor(maxLongSide: 100);
      final source = encodeTransparentPng(width: 24, height: 24);

      final prepared = await preprocessor.process(
        selectedPhoto(bytes: source, declaredContentType: 'image/png'),
      );
      final decoded = image.decodeJpg(prepared.bytes);

      expect(prepared.contentType, 'image/jpeg');
      expect(decoded, isNotNull);
      expect(decoded!.numChannels, lessThanOrEqualTo(3));
    });

    test('shouldRejectUnsupportedDeclaredOrDetectedSourceType', () async {
      final preprocessor = ImagePhotoPreprocessor();

      await expectPreprocessingFailure(
        preprocessor.process(
          selectedPhoto(
            bytes: encodeJpeg(width: 10, height: 10),
            declaredContentType: 'image/gif',
          ),
        ),
      );
      await expectPreprocessingFailure(
        preprocessor.process(
          selectedPhoto(
            bytes: <int>[1, 2, 3, 4],
            declaredContentType: 'image/jpeg',
          ),
        ),
      );
    });

    test('shouldRejectEmptyOrOversizedPreparedOutputBeforeNetwork', () async {
      final preprocessor = ImagePhotoPreprocessor(maxUploadBytes: 10);

      await expectPreprocessingFailure(
        preprocessor.process(
          selectedPhoto(
            bytes: encodeJpeg(width: 100, height: 100),
            declaredContentType: 'image/jpeg',
          ),
        ),
      );
      await expectPreprocessingFailure(
        preprocessor.process(
          selectedPhoto(bytes: <int>[], declaredContentType: 'image/jpeg'),
        ),
      );
    });
  });
}

Future<void> expectPreprocessingFailure(Future<Object?> operation) async {
  await expectLater(
    operation,
    throwsA(
      isA<MediaApplicationException>().having(
        (error) => error.failure,
        'failure',
        const MediaPreprocessingFailure(),
      ),
    ),
  );
}

List<int> encodeJpeg({required int width, required int height}) {
  return image.encodeJpg(solidImage(width: width, height: height));
}

List<int> encodePng({required int width, required int height}) {
  return image.encodePng(solidImage(width: width, height: height));
}

image.Image solidImage({required int width, required int height}) {
  final source = image.Image(width: width, height: height);
  image.fill(source, color: image.ColorRgb8(230, 80, 90));
  return source;
}

List<int> encodeTransparentPng({required int width, required int height}) {
  final source = image.Image(width: width, height: height, numChannels: 4);
  image.fill(source, color: image.ColorRgba8(120, 20, 200, 96));
  return image.encodePng(source);
}
