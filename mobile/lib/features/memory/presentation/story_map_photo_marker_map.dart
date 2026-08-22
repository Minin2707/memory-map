import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/memory/application/story_map_projection.dart';

class StoryMapPhotoMarkerMap extends ConsumerStatefulWidget {
  const StoryMapPhotoMarkerMap({
    required this.markerPresentations,
    required this.sourceConfiguration,
    this.cameraCommand,
    this.onMarkerSelected,
    this.selectedMarkerId,
    super.key,
  });

  final List<StoryMapMarkerPresentation> markerPresentations;
  final MapSourceConfiguration sourceConfiguration;
  final MapCameraCommand? cameraCommand;
  final ValueChanged<String>? onMarkerSelected;
  final String? selectedMarkerId;

  @override
  ConsumerState<StoryMapPhotoMarkerMap> createState() =>
      _StoryMapPhotoMarkerMapState();
}

class _StoryMapPhotoMarkerMapState
    extends ConsumerState<StoryMapPhotoMarkerMap> {
  final Map<String, Uint8List> _thumbnailBytesByPath = <String, Uint8List>{};
  final Set<String> _failedThumbnailPaths = <String>{};
  final Set<String> _loadingThumbnailPaths = <String>{};
  final Map<String, Uint8List> _iconBytesByKey = <String, Uint8List>{};
  final Set<String> _pendingIconKeys = <String>{};
  final Set<String> _failedIconKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _startThumbnailLoads();
  }

  @override
  void didUpdateWidget(StoryMapPhotoMarkerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markerPresentations != widget.markerPresentations) {
      _trimThumbnailState();
      _startThumbnailLoads();
    }
  }

  @override
  Widget build(BuildContext context) {
    _startThumbnailLoads();
    final iconRequests = _iconRequests();
    _startIconComposition(iconRequests);

    return MapLibreImageMarkerMap(
      markers: _markers(),
      markerIcons: _markerIcons(iconRequests),
      sourceConfiguration: widget.sourceConfiguration,
      selectedMarkerId: widget.selectedMarkerId,
      onMarkerSelected: widget.onMarkerSelected,
      cameraCommand: widget.cameraCommand,
    );
  }

  List<MapMarker> _markers() {
    return widget.markerPresentations
        .map((presentation) => presentation.marker)
        .toList(growable: false);
  }

  Map<String, MapMarkerIcon> _markerIcons(
    Map<String, _MarkerIconRequest> requests,
  ) {
    final icons = <String, MapMarkerIcon>{};

    for (final presentation in widget.markerPresentations) {
      final request = requests[presentation.marker.id];
      if (request == null) {
        continue;
      }

      final imageKey = resolveStoryMapMarkerIconKey(
        desiredImageKey: request.imageKey,
        compatibleImageKeys: request.compatibleImageKeys,
        hasIconBytes: _iconBytesByKey.containsKey,
      );
      if (imageKey == null) {
        continue;
      }

      final bytes = _iconBytesByKey[imageKey];
      if (bytes == null) {
        continue;
      }

      icons[presentation.marker.id] = MapMarkerIcon(
        imageKey: imageKey,
        bytes: bytes,
      );
    }

    return icons;
  }

  Map<String, _MarkerIconRequest> _iconRequests() {
    final requests = <String, _MarkerIconRequest>{};

    for (final presentation in widget.markerPresentations) {
      final selected = presentation.marker.id == widget.selectedMarkerId;
      final preview = presentation.previewPhoto;
      final thumbnailPath = preview?.thumbnailPath;
      final photoBytes = thumbnailPath == null
          ? null
          : _thumbnailBytesByPath[thumbnailPath];
      final baseImageKey = photoBytes == null
          ? 'story-map-marker.fallback'
          : 'story-map-marker.photo.'
              '${_stableHash('${preview!.mediaId}|$thumbnailPath')}';
      final imageKey = _variantImageKey(baseImageKey, selected: selected);

      requests[presentation.marker.id] = _MarkerIconRequest(
        imageKey: imageKey,
        compatibleImageKeys: <String>[
          _variantImageKey(baseImageKey, selected: !selected),
          _variantImageKey('story-map-marker.fallback', selected: selected),
          _variantImageKey('story-map-marker.fallback', selected: !selected),
        ],
        selected: selected,
        photoBytes: photoBytes,
      );
    }

    return requests;
  }

  void _startThumbnailLoads() {
    final paths = _currentThumbnailPaths();
    for (final path in paths) {
      if (_thumbnailBytesByPath.containsKey(path) ||
          _failedThumbnailPaths.contains(path) ||
          _loadingThumbnailPaths.contains(path)) {
        continue;
      }

      _loadingThumbnailPaths.add(path);
      unawaited(_loadThumbnail(path));
    }
  }

  Future<void> _loadThumbnail(String thumbnailPath) async {
    try {
      final bytes = await ref
          .read(mediaRepositoryProvider)
          .getThumbnailByPath(thumbnailPath);
      if (!mounted || !_currentThumbnailPaths().contains(thumbnailPath)) {
        return;
      }

      setState(() {
        _loadingThumbnailPaths.remove(thumbnailPath);
        _thumbnailBytesByPath[thumbnailPath] = bytes;
      });
    } catch (_) {
      if (!mounted || !_currentThumbnailPaths().contains(thumbnailPath)) {
        return;
      }

      setState(() {
        _loadingThumbnailPaths.remove(thumbnailPath);
        _failedThumbnailPaths.add(thumbnailPath);
      });
    }
  }

  void _startIconComposition(Map<String, _MarkerIconRequest> requests) {
    for (final request in requests.values) {
      if (_iconBytesByKey.containsKey(request.imageKey) ||
          _pendingIconKeys.contains(request.imageKey) ||
          _failedIconKeys.contains(request.imageKey)) {
        continue;
      }

      _pendingIconKeys.add(request.imageKey);
      unawaited(_composeIcon(request));
    }
  }

  Future<void> _composeIcon(_MarkerIconRequest request) async {
    try {
      final bytes = await _composeMarkerIcon(
        photoBytes: request.photoBytes,
        selected: request.selected,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingIconKeys.remove(request.imageKey);
        _iconBytesByKey[request.imageKey] = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingIconKeys.remove(request.imageKey);
        _failedIconKeys.add(request.imageKey);
      });
    }
  }

  Set<String> _currentThumbnailPaths() {
    return widget.markerPresentations
        .map((presentation) => presentation.previewPhoto?.thumbnailPath)
        .whereType<String>()
        .toSet();
  }

  void _trimThumbnailState() {
    final currentPaths = _currentThumbnailPaths();
    _thumbnailBytesByPath.removeWhere((path, _) => !currentPaths.contains(path));
    _failedThumbnailPaths.removeWhere((path) => !currentPaths.contains(path));
    _loadingThumbnailPaths.removeWhere((path) => !currentPaths.contains(path));
  }
}

final class _MarkerIconRequest {
  const _MarkerIconRequest({
    required this.imageKey,
    required this.compatibleImageKeys,
    required this.selected,
    required this.photoBytes,
  });

  final String imageKey;
  final List<String> compatibleImageKeys;
  final bool selected;
  final Uint8List? photoBytes;
}

@visibleForTesting
String? resolveStoryMapMarkerIconKey({
  required String desiredImageKey,
  required Iterable<String> compatibleImageKeys,
  required bool Function(String imageKey) hasIconBytes,
}) {
  return resolveCompatibleMarkerIconKey(
    desiredImageKey: desiredImageKey,
    compatibleImageKeys: compatibleImageKeys,
    hasIconBytes: hasIconBytes,
  );
}

Future<Uint8List> _composeMarkerIcon({
  required Uint8List? photoBytes,
  required bool selected,
}) async {
  final metrics = storyMapMarkerIconMetricsForTesting(selected: selected);
  final center = Offset(metrics.width / 2, metrics.centerY);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final shadowPaint = Paint()
    ..color = const Color(0x330F172A)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
  canvas.drawCircle(
    center.translate(0, 2),
    metrics.shadowRadius,
    shadowPaint,
  );

  final stemPaint = Paint()
    ..color = selected ? const Color(0xFF2F3A4A) : const Color(0xFFFF5D72)
    ..strokeWidth = metrics.stemWidth
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    Offset(metrics.width / 2, metrics.stemStartY),
    Offset(metrics.width / 2, metrics.stemEndY),
    stemPaint,
  );

  final ringPaint = Paint()
    ..color = selected ? const Color(0xFFFF5D72) : Colors.white;
  canvas.drawCircle(center, metrics.outerRingRadius, ringPaint);
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
          Color(0xFFFF5D72),
          Color(0xFFFFB46B),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: metrics.gradientRadius),
      );
    canvas.drawCircle(center, metrics.fallbackFillRadius, fillPaint);
    canvas.drawCircle(
      center,
      metrics.fallbackDotRadius,
      Paint()..color = Colors.white,
    );
  } else {
    final photoImage = await _decodePhoto(photoBytes);
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

  canvas.drawCircle(
    Offset(metrics.width / 2, metrics.bottomDotY),
    metrics.bottomDotRadius,
    Paint()
      ..color =
          selected ? const Color(0xFF2F3A4A) : const Color(0xFFFF5D72),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    metrics.width.toInt(),
    metrics.height.toInt(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('marker image encoding failed');
    }

    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

@visibleForTesting
StoryMapMarkerIconMetrics storyMapMarkerIconMetricsForTesting({
  required bool selected,
}) {
  if (!selected) {
    return const StoryMapMarkerIconMetrics(
      width: 60.0,
      height: 72.0,
      photoDiameter: 46.0,
      centerY: 26.0,
      shadowRadius: 27.0,
      outerRingRadius: 27.0,
      innerBorderRadius: 24.0,
      gradientRadius: 23.0,
      fallbackFillRadius: 21.0,
      fallbackDotRadius: 7.0,
      stemWidth: 3.5,
      stemStartY: 49.0,
      stemEndY: 63.0,
      bottomDotY: 66.0,
      bottomDotRadius: 3.5,
    );
  }

  return const StoryMapMarkerIconMetrics(
    width: 69.0,
    height: 83.0,
    photoDiameter: 53.0,
    centerY: 30.0,
    shadowRadius: 31.0,
    outerRingRadius: 31.0,
    innerBorderRadius: 27.5,
    gradientRadius: 26.5,
    fallbackFillRadius: 24.0,
    fallbackDotRadius: 8.0,
    stemWidth: 4.0,
    stemStartY: 56.5,
    stemEndY: 72.5,
    bottomDotY: 76.0,
    bottomDotRadius: 4.0,
  );
}

@visibleForTesting
final class StoryMapMarkerIconMetrics {
  const StoryMapMarkerIconMetrics({
    required this.width,
    required this.height,
    required this.photoDiameter,
    required this.centerY,
    required this.shadowRadius,
    required this.outerRingRadius,
    required this.innerBorderRadius,
    required this.gradientRadius,
    required this.fallbackFillRadius,
    required this.fallbackDotRadius,
    required this.stemWidth,
    required this.stemStartY,
    required this.stemEndY,
    required this.bottomDotY,
    required this.bottomDotRadius,
  });

  final double width;
  final double height;
  final double photoDiameter;
  final double centerY;
  final double shadowRadius;
  final double outerRingRadius;
  final double innerBorderRadius;
  final double gradientRadius;
  final double fallbackFillRadius;
  final double fallbackDotRadius;
  final double stemWidth;
  final double stemStartY;
  final double stemEndY;
  final double bottomDotY;
  final double bottomDotRadius;
}

Future<ui.Image> _decodePhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
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

String _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return hash.toRadixString(16).padLeft(8, '0');
}

String _variantImageKey(String baseImageKey, {required bool selected}) {
  return '$baseImageKey.${selected ? 'selected' : 'normal'}';
}
