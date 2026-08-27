import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef PlaybackMarkerIconComposer = Future<Uint8List> Function({
  required Uint8List? photoBytes,
  required int sequenceNumber,
  required bool current,
  double pixelRatio,
});

enum PlaybackMarkerVisualSource {
  photo,
  fallback,
}

final class PlaybackMarkerVisualIdentity {
  factory PlaybackMarkerVisualIdentity({
    required int sequenceNumber,
    required bool current,
    required PlaybackMarkerVisualSource source,
    double pixelRatio = 1.0,
    String? thumbnailPath,
  }) {
    if (sequenceNumber < 1) {
      throw ArgumentError('sequenceNumber must be positive');
    }
    if (source == PlaybackMarkerVisualSource.photo &&
        (thumbnailPath == null || thumbnailPath.trim().isEmpty)) {
      throw ArgumentError('thumbnailPath must not be blank for photo markers');
    }

    final normalizedPixelRatio = playbackMarkerPixelRatio(pixelRatio);
    final photoKey = source == PlaybackMarkerVisualSource.photo
        ? '.${_stableHash(thumbnailPath!)}'
        : '';
    final scaleKey =
        normalizedPixelRatio == 1.0 ? '' : '.x${_scaleKey(normalizedPixelRatio)}';
    return PlaybackMarkerVisualIdentity._(
      sequenceNumber: sequenceNumber,
      current: current,
      source: source,
      imageKey: 'playback-marker.${source.name}$photoKey.'
          '$sequenceNumber.${current ? 'current' : 'normal'}$scaleKey',
    );
  }

  const PlaybackMarkerVisualIdentity._({
    required this.sequenceNumber,
    required this.current,
    required this.source,
    required this.imageKey,
  });

  final int sequenceNumber;
  final bool current;
  final PlaybackMarkerVisualSource source;
  final String imageKey;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackMarkerVisualIdentity &&
            sequenceNumber == other.sequenceNumber &&
            current == other.current &&
            source == other.source &&
            imageKey == other.imageKey;
  }

  @override
  int get hashCode => Object.hash(
        sequenceNumber,
        current,
        source,
        imageKey,
      );

  @override
  String toString() {
    return 'PlaybackMarkerVisualIdentity(sequenceNumber: $sequenceNumber, '
        'current: $current, source: $source)';
  }
}

final class PlaybackMarkerIconRequest {
  const PlaybackMarkerIconRequest({
    required this.identity,
    required this.compatibleImageKeys,
    required this.photoBytes,
    required this.pixelRatio,
  });

  final PlaybackMarkerVisualIdentity identity;
  final List<String> compatibleImageKeys;
  final Uint8List? photoBytes;
  final double pixelRatio;

  String get imageKey => identity.imageKey;

  bool get current => identity.current;

  int get sequenceNumber => identity.sequenceNumber;
}

PlaybackMarkerIconRequest playbackMarkerIconRequest({
  required int sequenceNumber,
  required bool current,
  required String? thumbnailPath,
  required Uint8List? thumbnailBytes,
  double pixelRatio = 1.0,
}) {
  final hasPhoto = thumbnailPath != null && thumbnailBytes != null;
  final normalizedPixelRatio = playbackMarkerPixelRatio(pixelRatio);
  final identity = PlaybackMarkerVisualIdentity(
    sequenceNumber: sequenceNumber,
    current: current,
    source: hasPhoto
        ? PlaybackMarkerVisualSource.photo
        : PlaybackMarkerVisualSource.fallback,
    pixelRatio: normalizedPixelRatio,
    thumbnailPath: hasPhoto ? thumbnailPath : null,
  );

  final compatible = <String>[
    PlaybackMarkerVisualIdentity(
      sequenceNumber: sequenceNumber,
      current: !current,
      source: identity.source,
      pixelRatio: normalizedPixelRatio,
      thumbnailPath: hasPhoto ? thumbnailPath : null,
    ).imageKey,
    PlaybackMarkerVisualIdentity(
      sequenceNumber: sequenceNumber,
      current: current,
      source: PlaybackMarkerVisualSource.fallback,
      pixelRatio: normalizedPixelRatio,
    ).imageKey,
    PlaybackMarkerVisualIdentity(
      sequenceNumber: sequenceNumber,
      current: !current,
      source: PlaybackMarkerVisualSource.fallback,
      pixelRatio: normalizedPixelRatio,
    ).imageKey,
  ];

  return PlaybackMarkerIconRequest(
    identity: identity,
    compatibleImageKeys: compatible,
    photoBytes: hasPhoto ? thumbnailBytes : null,
    pixelRatio: normalizedPixelRatio,
  );
}

Future<Uint8List> composePlaybackMarkerIcon({
  required Uint8List? photoBytes,
  required int sequenceNumber,
  required bool current,
  double pixelRatio = 1.0,
}) async {
  final metrics = playbackMarkerIconMetricsForTesting(current: current);
  final normalizedPixelRatio = playbackMarkerPixelRatio(pixelRatio);
  final center = Offset(metrics.centerX, metrics.centerY);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(normalizedPixelRatio);

  final shadowPaint = Paint()
    ..color = const Color(0x33101820)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
  canvas.drawCircle(
    center.translate(0, 2),
    metrics.shadowRadius,
    shadowPaint,
  );

  if (current) {
    final haloPaint = Paint()..color = const Color(0x24FF5D72);
    canvas.drawCircle(center, metrics.haloRadius, haloPaint);
  }

  canvas.drawCircle(
    center,
    metrics.outerRingRadius,
    Paint()..color = current ? const Color(0xFFFF5D72) : Colors.white,
  );
  canvas.drawCircle(
    center,
    metrics.innerBorderRadius,
    Paint()..color = Colors.white,
  );

  if (photoBytes == null) {
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF364354),
          Color(0xFF1F2937),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: metrics.gradientRadius),
      );
    canvas.drawCircle(center, metrics.fallbackFillRadius, fillPaint);
    _drawFallbackGlyph(canvas, center, metrics);
  } else {
    final photoImage = await _decodePhoto(
      photoBytes,
      targetLongSide: playbackMarkerPhotoDecodeTargetSizeForTesting(
        current: current,
        pixelRatio: normalizedPixelRatio,
      ),
    );
    try {
      final photoRect = Rect.fromCircle(
        center: center,
        radius: metrics.photoDiameter / 2,
      );
      canvas
        ..save()
        ..clipPath(Path()..addOval(photoRect))
        ..drawImageRect(
          photoImage,
          _coverSourceRect(photoImage),
          photoRect,
          Paint()..filterQuality = FilterQuality.high,
        )
        ..restore();
    } finally {
      photoImage.dispose();
    }
  }

  final badgeCenter = Offset(metrics.badgeCenterX, metrics.badgeCenterY);
  canvas.drawCircle(
    badgeCenter.translate(0, 1),
    metrics.badgeRadius,
    Paint()
      ..color = const Color(0x26101820)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
  );
  canvas.drawCircle(
    badgeCenter,
    metrics.badgeRadius,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    badgeCenter,
    metrics.badgeRadius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = current ? 2.0 : 1.3
      ..color = current ? const Color(0xFFFF5D72) : const Color(0xFFE6EAF0),
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: sequenceNumber.toString(),
      style: TextStyle(
        color: current ? const Color(0xFFFF5D72) : const Color(0xFF2F3A4A),
        fontSize: metrics.badgeFontSize,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    badgeCenter - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
      (metrics.width * normalizedPixelRatio).round(),
      (metrics.height * normalizedPixelRatio).round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('playback marker image encoding failed');
      }

      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

double playbackMarkerPixelRatio(double devicePixelRatio) {
  if (!devicePixelRatio.isFinite || devicePixelRatio < 1) {
    return 1;
  }

  final capped = devicePixelRatio > 3 ? 3.0 : devicePixelRatio;
  return (capped * 100).round() / 100;
}

@visibleForTesting
int playbackMarkerPhotoDecodeTargetSizeForTesting({
  required bool current,
  required double pixelRatio,
}) {
  final metrics = playbackMarkerIconMetricsForTesting(current: current);
  final normalizedPixelRatio = playbackMarkerPixelRatio(pixelRatio);
  final target = (math.max(metrics.width, metrics.height) * normalizedPixelRatio)
      .round();
  return target.clamp(1, 360).toInt();
}

@visibleForTesting
PlaybackMarkerIconMetrics playbackMarkerIconMetricsForTesting({
  required bool current,
}) {
  if (!current) {
    return const PlaybackMarkerIconMetrics(
      width: 66.0,
      height: 66.0,
      centerX: 30.0,
      centerY: 30.0,
      photoDiameter: 48.0,
      shadowRadius: 27.0,
      haloRadius: 0.0,
      outerRingRadius: 28.0,
      innerBorderRadius: 24.5,
      gradientRadius: 23.5,
      fallbackFillRadius: 22.0,
      fallbackDotRadius: 7.0,
      badgeCenterX: 49.0,
      badgeCenterY: 47.0,
      badgeRadius: 13.5,
      badgeFontSize: 15.0,
    );
  }

  return const PlaybackMarkerIconMetrics(
    width: 80.0,
    height: 80.0,
    centerX: 37.0,
    centerY: 37.0,
    photoDiameter: 58.0,
    shadowRadius: 35.0,
    haloRadius: 36.0,
    outerRingRadius: 34.0,
    innerBorderRadius: 29.5,
    gradientRadius: 28.5,
    fallbackFillRadius: 27.0,
    fallbackDotRadius: 8.5,
    badgeCenterX: 59.0,
    badgeCenterY: 57.0,
    badgeRadius: 15.5,
    badgeFontSize: 16.0,
  );
}

@visibleForTesting
final class PlaybackMarkerIconMetrics {
  const PlaybackMarkerIconMetrics({
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
    required this.photoDiameter,
    required this.shadowRadius,
    required this.haloRadius,
    required this.outerRingRadius,
    required this.innerBorderRadius,
    required this.gradientRadius,
    required this.fallbackFillRadius,
    required this.fallbackDotRadius,
    required this.badgeCenterX,
    required this.badgeCenterY,
    required this.badgeRadius,
    required this.badgeFontSize,
  });

  final double width;
  final double height;
  final double centerX;
  final double centerY;
  final double photoDiameter;
  final double shadowRadius;
  final double haloRadius;
  final double outerRingRadius;
  final double innerBorderRadius;
  final double gradientRadius;
  final double fallbackFillRadius;
  final double fallbackDotRadius;
  final double badgeCenterX;
  final double badgeCenterY;
  final double badgeRadius;
  final double badgeFontSize;
}

Future<ui.Image> _decodePhoto(
  Uint8List bytes, {
  required int targetLongSide,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final intrinsicLongSide = math.max(descriptor.width, descriptor.height);
    final shouldDownscale = intrinsicLongSide > targetLongSide;
    final isLandscape = descriptor.width >= descriptor.height;
    final targetWidth = shouldDownscale && isLandscape ? targetLongSide : null;
    final targetHeight =
        shouldDownscale && !isLandscape ? targetLongSide : null;
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

Rect _coverSourceRect(ui.Image image) {
  final width = image.width.toDouble();
  final height = image.height.toDouble();
  if (width == height) {
    return Rect.fromLTWH(0, 0, width, height);
  }

  if (width > height) {
    final cropWidth = height;
    return Rect.fromLTWH((width - cropWidth) / 2, 0, cropWidth, height);
  }

  final cropHeight = width;
  return Rect.fromLTWH(0, (height - cropHeight) / 2, width, cropHeight);
}

void _drawFallbackGlyph(
  Canvas canvas,
  Offset center,
  PlaybackMarkerIconMetrics metrics,
) {
  final glyphWidth = metrics.photoDiameter * 0.42;
  final glyphHeight = glyphWidth * 0.72;
  final rect = Rect.fromCenter(
    center: center,
    width: glyphWidth,
    height: glyphHeight,
  );
  final stroke = Paint()
    ..color = const Color(0xD9FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = metrics.photoDiameter > 50 ? 2.0 : 1.7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..color = const Color(0x1FFFFFFF);

  final roundedRect = RRect.fromRectAndRadius(
    rect,
    Radius.circular(metrics.photoDiameter * 0.06),
  );
  canvas.drawRRect(roundedRect, fill);
  canvas.drawRRect(roundedRect, stroke);

  final sunCenter = Offset(
    rect.left + glyphWidth * 0.72,
    rect.top + glyphHeight * 0.30,
  );
  canvas.drawCircle(sunCenter, glyphWidth * 0.075, Paint()..color = stroke.color);

  final mountainPath = Path()
    ..moveTo(rect.left + glyphWidth * 0.14, rect.bottom - glyphHeight * 0.18)
    ..lineTo(rect.left + glyphWidth * 0.38, rect.top + glyphHeight * 0.58)
    ..lineTo(rect.left + glyphWidth * 0.53, rect.bottom - glyphHeight * 0.36)
    ..lineTo(rect.left + glyphWidth * 0.68, rect.top + glyphHeight * 0.52)
    ..lineTo(rect.right - glyphWidth * 0.12, rect.bottom - glyphHeight * 0.18);
  canvas.drawPath(mountainPath, stroke);
}

String _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return hash.toRadixString(16).padLeft(8, '0');
}

String _scaleKey(double pixelRatio) {
  final text = pixelRatio.toStringAsFixed(2);
  return text.endsWith('00')
      ? text.substring(0, text.length - 3)
      : text.replaceAll('.', '_');
}
