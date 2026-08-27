import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/presentation/story_map_photo_marker_map.dart';

void main() {
  group('StoryMapPhotoMarkerMap icon sizing', () {
    test('shouldKeepUnselectedMarkerBaselineDimensions', () {
      final metrics = storyMapMarkerIconMetricsForTesting(selected: false);

      expect(metrics.width, 60.0);
      expect(metrics.height, 72.0);
      expect(metrics.photoDiameter, 46.0);
      expect(metrics.outerRingRadius, 27.0);
      expect(metrics.fallbackFillRadius, 21.0);
      expect(metrics.bottomDotY, 66.0);
    });

    test('shouldMakeSelectedPhotoMarkerAboutFifteenPercentLarger', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(selected.width / normal.width, closeTo(1.15, 0.01));
      expect(selected.height / normal.height, closeTo(1.15, 0.01));
      expect(
        selected.photoDiameter / normal.photoDiameter,
        closeTo(1.15, 0.01),
      );
      expect(selected.outerRingRadius, greaterThan(normal.outerRingRadius));
      expect(selected.stemWidth, greaterThan(normal.stemWidth));
      expect(selected.bottomDotRadius, greaterThan(normal.bottomDotRadius));
    });

    test('shouldMakeSelectedFallbackMarkerProportionallyLarger', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(
        selected.fallbackFillRadius / normal.fallbackFillRadius,
        closeTo(1.14, 0.02),
      );
      expect(
        selected.fallbackDotRadius / normal.fallbackDotRadius,
        closeTo(1.14, 0.02),
      );
      expect(selected.gradientRadius, greaterThan(normal.gradientRadius));
    });

    test('shouldKeepGeographicAnchorCenteredAtBitmapBottom', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(normal.bottomDotY, lessThan(normal.height));
      expect(selected.bottomDotY, lessThan(selected.height));
      expect(normal.width / 2, 30.0);
      expect(selected.width / 2, 34.5);
      expect(
        selected.bottomDotY / selected.height,
        closeTo(normal.bottomDotY / normal.height, 0.01),
      );
    });

    test('shouldDerivePhotoDecodeTargetFromMarkerSizeAndDpr', () {
      expect(
        storyMapMarkerPhotoDecodeTargetSizeForTesting(
          selected: false,
          pixelRatio: 1,
        ),
        72,
      );
      expect(
        storyMapMarkerPhotoDecodeTargetSizeForTesting(
          selected: false,
          pixelRatio: 2.5,
        ),
        180,
      );
      expect(
        storyMapMarkerPhotoDecodeTargetSizeForTesting(
          selected: true,
          pixelRatio: 3,
        ),
        249,
      );
    });

    test('shouldCapDecodeTargetWithPlaybackCompatibleDprPolicy', () {
      expect(storyMapMarkerPixelRatio(0), 1);
      expect(storyMapMarkerPixelRatio(double.nan), 1);
      expect(storyMapMarkerPixelRatio(3.75), 3);
      expect(
        storyMapMarkerPhotoDecodeTargetSizeForTesting(
          selected: true,
          pixelRatio: 12,
        ),
        249,
      );
    });

    test('shouldKeepSelectedDecodeTargetLargerThanNormalTarget', () {
      final normal = storyMapMarkerPhotoDecodeTargetSizeForTesting(
        selected: false,
        pixelRatio: 2,
      );
      final selected = storyMapMarkerPhotoDecodeTargetSizeForTesting(
        selected: true,
        pixelRatio: 2,
      );

      expect(selected, greaterThan(normal));
    });
  });

  group('StoryMapPhotoMarkerMap icon resolution', () {
    test('shouldPreferDesiredSelectedIconWhenReady', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.a.selected',
        compatibleImageKeys: const <String>['marker.photo.a.normal'],
        hasIconBytes: const <String>{
          'marker.photo.a.selected',
          'marker.photo.a.normal',
        }.contains,
      );

      expect(key, 'marker.photo.a.selected');
    });

    test('shouldKeepPhotoMarkerVisibleWhileSelectedIconIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.a.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.a.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{'marker.photo.a.normal'}.contains,
      );

      expect(key, 'marker.photo.a.normal');
    });

    test('shouldKeepNoPhotoMarkerVisibleWhileSelectedFallbackIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.fallback.selected',
        compatibleImageKeys: const <String>['marker.fallback.normal'],
        hasIconBytes: const <String>{'marker.fallback.normal'}.contains,
      );

      expect(key, 'marker.fallback.normal');
    });

    test('shouldUseFallbackIconWhenPhotoPreviewIconIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.b.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.b.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{'marker.fallback.normal'}.contains,
      );

      expect(key, 'marker.fallback.normal');
    });

    test('shouldReturnNullOnlyWhenNoCompatibleIconExistsYet', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.b.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.b.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{}.contains,
      );

      expect(key, isNull);
    });
  });

  group('StoryMapPhotoMarkerMap icon composition queue', () {
    test('shouldLimitConcurrentIconCompositions', () async {
      final limiter = StoryMapMarkerIconCompositionLimiter(maxConcurrent: 3);
      final completers = <Completer<void>>[];
      var active = 0;
      var maxActive = 0;

      for (var index = 0; index < 30; index += 1) {
        final completer = Completer<void>();
        completers.add(completer);
        limiter.enqueue(
          imageKey: 'marker-$index',
          priority: false,
          runner: () async {
            active += 1;
            if (active > maxActive) {
              maxActive = active;
            }

            await completer.future;
            active -= 1;
          },
        );
      }
      await flushMicrotasks();

      expect(limiter.activeCount, 3);
      expect(limiter.queuedCount, 27);
      expect(maxActive, 3);

      for (final completer in completers) {
        completer.complete();
        await flushMicrotasks();
      }

      expect(limiter.isIdle, isTrue);
      expect(maxActive, 3);
    });

    test('shouldDropQueuedObsoleteIconWork', () async {
      final limiter = StoryMapMarkerIconCompositionLimiter(maxConcurrent: 1);
      final activeCompleter = Completer<void>();

      limiter.enqueue(
        imageKey: 'active',
        priority: false,
        runner: () => activeCompleter.future,
      );
      limiter.enqueue(
        imageKey: 'obsolete',
        priority: false,
        runner: () async {},
      );
      limiter.enqueue(
        imageKey: 'current',
        priority: false,
        runner: () async {},
      );
      await flushMicrotasks();

      limiter.retainQueuedKeys(<String>{'active', 'current'});

      expect(limiter.hasQueued('obsolete'), isFalse);
      expect(limiter.hasQueued('current'), isTrue);
      expect(limiter.queuedCount, 1);

      activeCompleter.complete();
      await flushMicrotasks();

      expect(limiter.isIdle, isTrue);
    });

    test('shouldPreferSelectedIconWorkInQueue', () {
      final ordered = storyMapMarkerIconCompositionOrderForTesting(
        <StoryMapMarkerIconRequest>[
          request('normal-a', selected: false),
          request('selected-b', selected: true),
          request('normal-c', selected: false),
        ],
      );

      expect(
        ordered.map((item) => item.imageKey),
        <String>['selected-b', 'normal-a', 'normal-c'],
      );
    });
  });

  group('StoryMapPhotoMarkerMap icon retention keys', () {
    test('shouldRetainDesiredAndCompatibleCurrentVariants', () {
      final keys = storyMapRelevantMarkerIconKeysForTesting(
        <String, StoryMapMarkerIconRequest>{
          'memory-a': request(
            'photo-a.selected',
            compatibleImageKeys: const <String>[
              'photo-a.normal',
              'fallback.selected',
              'fallback.normal',
            ],
          ),
        },
      );

      expect(keys, <String>{
        'photo-a.selected',
        'photo-a.normal',
        'fallback.selected',
        'fallback.normal',
      });
    });

    test('shouldExcludeRemovedOrReplacedPreviewIconVariants', () {
      final keys = storyMapRelevantMarkerIconKeysForTesting(
        <String, StoryMapMarkerIconRequest>{
          'memory-a': request(
            'photo-new.normal',
            compatibleImageKeys: const <String>[
              'photo-new.selected',
              'fallback.normal',
              'fallback.selected',
            ],
          ),
        },
      );

      expect(keys, contains('photo-new.normal'));
      expect(keys, contains('photo-new.selected'));
      expect(keys, isNot(contains('photo-old.normal')));
      expect(keys, isNot(contains('photo-old.selected')));
    });

    test('shouldAllowObsoleteFailedIconKeysToBeTrimmedByRelevance', () {
      final failedKeys = <String>{
        'photo-old.normal',
        'photo-new.normal',
      };
      final relevantKeys = storyMapRelevantMarkerIconKeysForTesting(
        <String, StoryMapMarkerIconRequest>{
          'memory-a': request('photo-new.normal'),
        },
      );

      failedKeys.removeWhere((key) => !relevantKeys.contains(key));

      expect(failedKeys, <String>{'photo-new.normal'});
    });
  });
}

StoryMapMarkerIconRequest request(
  String imageKey, {
  bool selected = false,
  List<String> compatibleImageKeys = const <String>[],
}) {
  return StoryMapMarkerIconRequest(
    imageKey: imageKey,
    compatibleImageKeys: compatibleImageKeys,
    selected: selected,
    photoBytes: Uint8List.fromList(<int>[1, 2, 3]),
    pixelRatio: 1,
  );
}

Future<void> flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
