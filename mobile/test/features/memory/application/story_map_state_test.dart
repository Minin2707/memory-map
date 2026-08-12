import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/application/story_map_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('StoryMapState', () {
    test('shouldCreateEmptyUnselectedState', () {
      final state = StoryMapState();

      expect(state.markers, isEmpty);
      expect(state.selectedMarkerId, isNull);
      expect(state.hasMarkers, isFalse);
      expect(state.hasSelection, isFalse);
      expect(state.loadFailure, isNull);
      expect(state.refreshFailure, isNull);
      expect(state.isRefreshing, isFalse);
    });

    test('shouldCreateSelectedState', () {
      final state = StoryMapState(
        markers: <MapMarker>[markerA],
        selectedMarkerId: markerA.id,
      );

      expect(state.markers, <MapMarker>[markerA]);
      expect(state.selectedMarkerId, markerA.id);
      expect(state.hasMarkers, isTrue);
      expect(state.hasSelection, isTrue);
    });

    test('shouldRejectBlankSelectedMarkerId', () {
      expect(
        () => StoryMapState(selectedMarkerId: ''),
        throwsA(argumentErrorWithMessage('selectedMarkerId must not be blank')),
      );
      expect(
        () => StoryMapState(selectedMarkerId: '   '),
        throwsA(argumentErrorWithMessage('selectedMarkerId must not be blank')),
      );
    });

    test('shouldExposeImmutableMarkerList', () {
      final state = StoryMapState(markers: <MapMarker>[markerA]);

      expect(
        () => state.markers.add(markerB),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = StoryMapState(
        markers: <MapMarker>[markerA],
        selectedMarkerId: markerA.id,
        refreshFailure: const MemoryNetworkUnavailable(),
        isRefreshing: true,
      );
      final second = StoryMapState(
        markers: <MapMarker>[markerA],
        selectedMarkerId: markerA.id,
        refreshFailure: const MemoryNetworkUnavailable(),
        isRefreshing: true,
      );
      final different = StoryMapState(
        markers: <MapMarker>[markerB],
        selectedMarkerId: markerB.id,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final state = StoryMapState(
        markers: <MapMarker>[
          MapMarker(
            id: 'memory-secret',
            coordinate: MapCoordinate(
              latitude: 41.715123,
              longitude: 44.827456,
            ),
          ),
        ],
        selectedMarkerId: 'memory-secret',
        loadFailure: const MemoryStoryUnavailable(),
        isRefreshing: true,
        refreshFailure: const MemoryNetworkUnavailable(),
      );

      final text = state.toString();

      expect(text, contains('markerCount: 1'));
      expect(text, contains('hasSelection: true'));
      expect(text, contains('isRefreshing: true'));
      expect(text, contains('hasLoadFailure: true'));
      expect(text, contains('hasRefreshFailure: true'));
      expect(text, isNot(contains('memory-secret')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('MemoryStoryUnavailable')));
      expect(text, isNot(contains('MemoryNetworkUnavailable')));
    });
  });

  group('StoryMapSelectionState', () {
    test('shouldCreateEmptySelection', () {
      final state = StoryMapSelectionState();

      expect(state.selectedMarkerId, isNull);
      expect(state.hasSelection, isFalse);
    });

    test('shouldCreateSelectedState', () {
      final state = StoryMapSelectionState(selectedMarkerId: 'memory-secret');

      expect(state.selectedMarkerId, 'memory-secret');
      expect(state.hasSelection, isTrue);
    });

    test('shouldRejectBlankSelectedMarkerId', () {
      expect(
        () => StoryMapSelectionState(selectedMarkerId: ''),
        throwsA(argumentErrorWithMessage('selectedMarkerId must not be blank')),
      );
      expect(
        () => StoryMapSelectionState(selectedMarkerId: '   '),
        throwsA(argumentErrorWithMessage('selectedMarkerId must not be blank')),
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = StoryMapSelectionState(selectedMarkerId: 'memory-1');
      final second = StoryMapSelectionState(selectedMarkerId: 'memory-1');
      final different = StoryMapSelectionState(selectedMarkerId: 'memory-2');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final state = StoryMapSelectionState(selectedMarkerId: 'memory-secret');

      final text = state.toString();

      expect(text, 'StoryMapSelectionState(hasSelection: true)');
      expect(text, isNot(contains('memory-secret')));
    });
  });
}

final MapMarker markerA = MapMarker(
  id: 'memory-1',
  coordinate: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
);

final MapMarker markerB = MapMarker(
  id: 'memory-2',
  coordinate: MapCoordinate(latitude: -12.0464, longitude: -77.0428),
);

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
