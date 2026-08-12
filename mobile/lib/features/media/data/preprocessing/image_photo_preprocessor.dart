import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';

final class ImagePhotoPreprocessor implements PhotoPreprocessor {
  const ImagePhotoPreprocessor({
    this.maxLongSide = 2048,
    this.jpegQuality = 85,
    this.maxUploadBytes = 5 * 1024 * 1024,
  });

  static const String outputContentType = 'image/jpeg';

  final int maxLongSide;
  final int jpegQuality;
  final int maxUploadBytes;

  @override
  Future<PreparedPhotoUpload> process(SelectedPhoto photo) async {
    final sourceBytes = await photo.readBytes();
    if (sourceBytes.isEmpty ||
        !_hasSupportedDeclaredType(photo.declaredContentType) ||
        !_isSupportedSource(sourceBytes)) {
      throw const MediaApplicationException(MediaPreprocessingFailure());
    }

    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const MediaApplicationException(MediaPreprocessingFailure());
    }

    final oriented = image.bakeOrientation(decoded);
    final flattened = _flattenAlphaOnWhite(oriented);
    final resized = _resizeWithin(flattened, maxLongSide);
    final preparedBytes = Uint8List.fromList(
      image.encodeJpg(resized, quality: jpegQuality),
    );

    if (preparedBytes.isEmpty ||
        preparedBytes.lengthInBytes > maxUploadBytes) {
      throw const MediaApplicationException(MediaPreprocessingFailure());
    }

    return PreparedPhotoUpload(
      bytes: preparedBytes,
      contentType: outputContentType,
    );
  }

  image.Image _resizeWithin(image.Image source, int maxLongSide) {
    final longSide = math.max(source.width, source.height);
    if (longSide <= maxLongSide) {
      return source;
    }

    final scale = maxLongSide / longSide;
    return image.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: image.Interpolation.cubic,
    );
  }

  image.Image _flattenAlphaOnWhite(image.Image source) {
    final canvas = image.Image(width: source.width, height: source.height);
    image.fill(canvas, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(canvas, source);
    return canvas;
  }

  bool _hasSupportedDeclaredType(String? contentType) {
    if (contentType == null) {
      return true;
    }

    final normalized = contentType.toLowerCase();
    return normalized == 'image/jpeg' ||
        normalized == 'image/jpg' ||
        normalized == 'image/png';
  }

  bool _isSupportedSource(Uint8List bytes) {
    return _isJpeg(bytes) || _isPng(bytes);
  }

  bool _isJpeg(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  bool _isPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }
}
