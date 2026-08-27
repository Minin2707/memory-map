import 'dart:async';
import 'dart:math' as math;
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

typedef StoryMapMarkerIconComposer = Future<Uint8List> Function({
  required Uint8List? photoBytes,
  required bool selected,
  double pixelRatio,
});

class StoryMapPhotoMarkerMap extends ConsumerStatefulWidget {
  const StoryMapPhotoMarkerMap({
    required this.markerPresentations,
    required this.sourceConfiguration,
    this.cameraCommand,
    this.onMarkerSelected,
    this.selectedMarkerId,
    this.markerIconComposer = composeStoryMapMarkerIcon,
    this.markerIconCompositionLimit =
        storyMapMarkerIconCompositionConcurrencyLimit,
    super.key,
  }) : assert(markerIconCompositionLimit > 0);

  final List<StoryMapMarkerPresentation> markerPresentations;
  final MapSourceConfiguration sourceConfiguration;
  final MapCameraCommand? cameraCommand;
  final ValueChanged<String>? onMarkerSelected;
  final String? selectedMarkerId;
  final StoryMapMarkerIconComposer markerIconComposer;
  final int markerIconCompositionLimit;

  @override
  ConsumerState<StoryMapPhotoMarkerMap> createState() =>
      _StoryMapPhotoMarkerMapState();
}

const int storyMapMarkerIconCompositionConcurrencyLimit = 3;

@visibleForTesting
final class StoryMapMarkerIconCompositionLimiter {
  StoryMapMarkerIconCompositionLimiter({
    required this.maxConcurrent,
  }) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  final List<_PendingStoryMapMarkerIconComposition> _queue =
      <_PendingStoryMapMarkerIconComposition>[];
  final Set<String> _queuedKeys = <String>{};
  int _activeCount = 0;

  int get activeCount => _activeCount;

  int get queuedCount => _queue.length;

  bool get isIdle => _activeCount == 0 && _queue.isEmpty;

  bool hasQueued(String imageKey) => _queuedKeys.contains(imageKey);

  void enqueue({
    required String imageKey,
    required Future<void> Function() runner,
    required bool priority,
  }) {
    if (_queuedKeys.contains(imageKey)) {
      return;
    }

    final pending = _PendingStoryMapMarkerIconComposition(
      imageKey: imageKey,
      runner: runner,
      priority: priority,
    );
    _queuedKeys.add(imageKey);

    if (priority) {
      final index = _queue.indexWhere((item) => !item.priority);
      if (index == -1) {
        _queue.add(pending);
      } else {
        _queue.insert(index, pending);
      }
    } else {
      _queue.add(pending);
    }

    _drain();
  }

  void retainQueuedKeys(Set<String> relevantKeys) {
    _queue.removeWhere((pending) {
      final obsolete = !relevantKeys.contains(pending.imageKey);
      if (obsolete) {
        _queuedKeys.remove(pending.imageKey);
      }
      return obsolete;
    });
  }

  void clear() {
    _queue.clear();
    _queuedKeys.clear();
  }

  void _drain() {
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final pending = _queue.removeAt(0);
      _queuedKeys.remove(pending.imageKey);
      _activeCount += 1;
      unawaited(
        pending.runner().whenComplete(() {
          _activeCount -= 1;
          _drain();
        }),
      );
    }
  }
}

final class _PendingStoryMapMarkerIconComposition {
  const _PendingStoryMapMarkerIconComposition({
    required this.imageKey,
    required this.runner,
    required this.priority,
  });

  final String imageKey;
  final Future<void> Function() runner;
  final bool priority;
}

class _StoryMapPhotoMarkerMapState
    extends ConsumerState<StoryMapPhotoMarkerMap> {
  late final StoryMapMarkerIconCompositionLimiter _iconCompositionLimiter;
  final Map<String, Uint8List> _thumbnailBytesByPath = <String, Uint8List>{};
  final Set<String> _failedThumbnailPaths = <String>{};
  final Set<String> _loadingThumbnailPaths = <String>{};
  final Map<String, Uint8List> _iconBytesByKey = <String, Uint8List>{};
  final Set<String> _pendingIconKeys = <String>{};
  final Set<String> _failedIconKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _iconCompositionLimiter = StoryMapMarkerIconCompositionLimiter(
      maxConcurrent: widget.markerIconCompositionLimit,
    );
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
  void dispose() {
    _iconCompositionLimiter.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _startThumbnailLoads();
    final iconRequests = _iconRequests();
    _trimIconState(iconRequests);
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
    Map<String, StoryMapMarkerIconRequest> requests,
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

  Map<String, StoryMapMarkerIconRequest> _iconRequests() {
    final requests = <String, StoryMapMarkerIconRequest>{};
    final pixelRatio = storyMapMarkerPixelRatio(
      MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    );

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

      requests[presentation.marker.id] = StoryMapMarkerIconRequest(
        imageKey: imageKey,
        compatibleImageKeys: <String>[
          _variantImageKey(baseImageKey, selected: !selected),
          _variantImageKey('story-map-marker.fallback', selected: selected),
          _variantImageKey('story-map-marker.fallback', selected: !selected),
        ],
        selected: selected,
        photoBytes: photoBytes,
        pixelRatio: pixelRatio,
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

  void _startIconComposition(
    Map<String, StoryMapMarkerIconRequest> requests,
  ) {
    _trimIconState(requests);
    for (final request in storyMapMarkerIconCompositionOrderForTesting(
      requests.values,
    )) {
      if (_iconBytesByKey.containsKey(request.imageKey) ||
          _pendingIconKeys.contains(request.imageKey) ||
          _failedIconKeys.contains(request.imageKey) ||
          _iconCompositionLimiter.hasQueued(request.imageKey)) {
        continue;
      }

      _pendingIconKeys.add(request.imageKey);
      _iconCompositionLimiter.enqueue(
        imageKey: request.imageKey,
        runner: () => _composeIcon(request),
        priority: request.selected,
      );
    }
  }

  Future<void> _composeIcon(StoryMapMarkerIconRequest request) async {
    try {
      if (!_isRelevantIconKey(request.imageKey)) {
        _pendingIconKeys.remove(request.imageKey);
        return;
      }

      final bytes = await widget.markerIconComposer(
        photoBytes: request.photoBytes,
        selected: request.selected,
        pixelRatio: request.pixelRatio,
      );
      if (!mounted) {
        return;
      }
      if (!_isRelevantIconKey(request.imageKey)) {
        setState(() {
          _pendingIconKeys.remove(request.imageKey);
        });
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
        if (_isRelevantIconKey(request.imageKey)) {
          _failedIconKeys.add(request.imageKey);
        }
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

  void _trimIconState(Map<String, StoryMapMarkerIconRequest> requests) {
    final relevantKeys = storyMapRelevantMarkerIconKeysForTesting(requests);
    _iconBytesByKey.removeWhere((key, _) => !relevantKeys.contains(key));
    _failedIconKeys.removeWhere((key) => !relevantKeys.contains(key));
    _pendingIconKeys.removeWhere((key) => !relevantKeys.contains(key));
    _iconCompositionLimiter.retainQueuedKeys(relevantKeys);
  }

  bool _isRelevantIconKey(String imageKey) {
    return storyMapRelevantMarkerIconKeysForTesting(_iconRequests())
        .contains(imageKey);
  }
}

@visibleForTesting
final class StoryMapMarkerIconRequest {
  const StoryMapMarkerIconRequest({
    required this.imageKey,
    required this.compatibleImageKeys,
    required this.selected,
    required this.photoBytes,
    required this.pixelRatio,
  });

  final String imageKey;
  final List<String> compatibleImageKeys;
  final bool selected;
  final Uint8List? photoBytes;
  final double pixelRatio;
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

@visibleForTesting
List<StoryMapMarkerIconRequest> storyMapMarkerIconCompositionOrderForTesting(
  Iterable<StoryMapMarkerIconRequest> requests,
) {
  final ordered = requests.toList(growable: false);
  ordered.sort((a, b) {
    if (a.selected == b.selected) {
      return 0;
    }
    return a.selected ? -1 : 1;
  });
  return ordered;
}

@visibleForTesting
Set<String> storyMapRelevantMarkerIconKeysForTesting(
  Map<String, StoryMapMarkerIconRequest> requests,
) {
  return <String>{
    for (final request in requests.values) ...<String>[
      request.imageKey,
      ...request.compatibleImageKeys,
    ],
  };
}

Future<Uint8List> composeStoryMapMarkerIcon({
  required Uint8List? photoBytes,
  required bool selected,
  double pixelRatio = 1.0,
}) async {
  final metrics = storyMapMarkerIconMetricsForTesting(selected: selected);
  final normalizedPixelRatio = storyMapMarkerPixelRatio(pixelRatio);
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
    final photoImage = await _decodePhoto(
      photoBytes,
      targetLongSide: storyMapMarkerPhotoDecodeTargetSizeForTesting(
        selected: selected,
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

  canvas.drawCircle(
    Offset(metrics.width / 2, metrics.bottomDotY),
    metrics.bottomDotRadius,
    Paint()
      ..color =
          selected ? const Color(0xFF2F3A4A) : const Color(0xFFFF5D72),
  );

  final picture = recorder.endRecording();
  try {
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
  } finally {
    picture.dispose();
  }
}

double storyMapMarkerPixelRatio(double devicePixelRatio) {
  if (!devicePixelRatio.isFinite || devicePixelRatio < 1) {
    return 1;
  }

  final capped = devicePixelRatio > 3 ? 3.0 : devicePixelRatio;
  return (capped * 100).round() / 100;
}

@visibleForTesting
int storyMapMarkerPhotoDecodeTargetSizeForTesting({
  required bool selected,
  required double pixelRatio,
}) {
  final metrics = storyMapMarkerIconMetricsForTesting(selected: selected);
  final normalizedPixelRatio = storyMapMarkerPixelRatio(pixelRatio);
  final target = (math.max(metrics.width, metrics.height) * normalizedPixelRatio)
      .round();
  return target.clamp(1, 360).toInt();
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
