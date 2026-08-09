import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';
import 'package:memory_map/features/memory/presentation/location_picker_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('LocationPickerScreen selection', () {
    testWidgets('shouldStartWithoutSelectionWhenInitialLocationIsAbsent', (
      tester,
    ) async {
      final mapSpy = FakeLocationPickerMapSpy();
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        mapSpy: mapSpy,
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      expect(mapSpy.selectedLocations, <MemoryLocation?>[null]);
      expect(find.text('No location selected'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(selectedLocation, isNull);
    });

    testWidgets('shouldStartWithInitialLocationAndConfirmIt', (tester) async {
      final initialLocation = memoryLocationA;
      final mapSpy = FakeLocationPickerMapSpy();
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        initialLocation: initialLocation,
        mapSpy: mapSpy,
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      expect(mapSpy.selectedLocations, <MemoryLocation?>[initialLocation]);
      expect(find.text('Location selected'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNotNull);

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(selectedLocation, same(initialLocation));
    });

    testWidgets('shouldSelectMapPointAndReturnExactMemoryLocation', (
      tester,
    ) async {
      final mapSpy = FakeLocationPickerMapSpy();
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        mapSpy: mapSpy,
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-a')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(selectedLocation, memoryLocationA);
      expect(selectedLocation!.latitude, 41.7151);
      expect(selectedLocation!.longitude, 44.8271);
      expect(mapSpy.selectedLocations.last, memoryLocationA);
    });

    testWidgets('shouldReturnOnlyMostRecentSelection', (tester) async {
      final mapSpy = FakeLocationPickerMapSpy();
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        mapSpy: mapSpy,
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-a')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-b')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(selectedLocation, memoryLocationB);
      expect(mapSpy.selectedLocations, <MemoryLocation?>[
        null,
        memoryLocationA,
        memoryLocationB,
      ]);
    });

    testWidgets('shouldDisableConfirmWhenCallbackIsNull', (tester) async {
      await pumpScreen(
        tester,
        initialLocation: memoryLocationA,
        mapSpy: FakeLocationPickerMapSpy(),
      );

      expect(confirmButton(tester).onPressed, isNull);
    });
  });

  group('LocationPickerScreen callbacks', () {
    testWidgets('shouldCallBackWithoutSelectingLocation', (tester) async {
      var backCalls = 0;
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        mapSpy: FakeLocationPickerMapSpy(),
        onBack: () {
          backCalls += 1;
        },
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backCalls, 2);
      expect(selectedLocation, isNull);
    });

    testWidgets('shouldCallConfirmExactlyOncePerTap', (tester) async {
      var confirmCalls = 0;

      await pumpScreen(
        tester,
        initialLocation: memoryLocationA,
        mapSpy: FakeLocationPickerMapSpy(),
        onLocationSelected: (location) {
          confirmCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(confirmCalls, 2);
    });
  });

  group('LocationPickerScreen localization and layout', () {
    testWidgets('shouldRenderEnglishCopy', (tester) async {
      await pumpScreen(
        tester,
        mapSpy: FakeLocationPickerMapSpy(),
      );

      expect(find.text('Choose a place'), findsOneWidget);
      expect(
        find.text('Tap the map to choose the exact point for this memory.'),
        findsOneWidget,
      );
      expect(find.text('Confirm location'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianCopy', (tester) async {
      await pumpScreen(
        tester,
        locale: const Locale('ru'),
        mapSpy: FakeLocationPickerMapSpy(),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LocationPickerScreen)),
      );

      expect(find.text(l10n.locationPickerTitle), findsOneWidget);
      expect(find.text(l10n.locationPickerInstruction), findsOneWidget);
      expect(find.text(l10n.locationPickerConfirmAction), findsOneWidget);
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        textScaler: const TextScaler.linear(1.25),
        mapSpy: FakeLocationPickerMapSpy(),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('LocationPickerScreen configuration boundary', () {
    testWidgets('shouldPassDefaultConfigurationToMapBoundary', (tester) async {
      final mapSpy = FakeLocationPickerMapSpy();

      await pumpScreen(tester, mapSpy: mapSpy);

      expect(
        mapSpy.configurations,
        <LocationPickerMapConfiguration>[
          openFreeMapLocationPickerMapConfiguration,
        ],
      );
    });

    testWidgets('shouldAcceptAlternateConfigurationWithoutChangingSelection', (
      tester,
    ) async {
      final mapSpy = FakeLocationPickerMapSpy();
      final alternateConfiguration = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/style.json',
        defaultLatitude: 10,
        defaultLongitude: 20,
        defaultZoom: 2,
        selectedZoom: 14,
      );
      MemoryLocation? selectedLocation;

      await pumpScreen(
        tester,
        mapConfiguration: alternateConfiguration,
        mapSpy: mapSpy,
        onLocationSelected: (location) {
          selectedLocation = location;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-b')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(mapSpy.configurations.first, same(alternateConfiguration));
      expect(selectedLocation, memoryLocationB);
    });

    testWidgets('shouldNotRenderOpenFreeMapStyleUrlOrCoordinates', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: MemoryLocation(
          latitude: 41.715123,
          longitude: 44.827456,
        ),
        mapSpy: FakeLocationPickerMapSpy(),
        onLocationSelected: (_) {},
      );

      expect(find.textContaining('OpenFreeMap'), findsNothing);
      expect(find.textContaining('tiles.openfreemap.org'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(find.textContaining('latitude'), findsNothing);
      expect(find.textContaining('longitude'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
    });
  });
}

Future<void> pumpScreen(
  WidgetTester tester, {
  MemoryLocation? initialLocation,
  VoidCallback? onBack,
  ValueChanged<MemoryLocation>? onLocationSelected,
  LocationPickerMapConfiguration mapConfiguration =
      openFreeMapLocationPickerMapConfiguration,
  required FakeLocationPickerMapSpy mapSpy,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LocationPickerScreen(
        initialLocation: initialLocation,
        onBack: onBack,
        onLocationSelected: onLocationSelected,
        mapConfiguration: mapConfiguration,
        mapBuilder: mapSpy.build,
      ),
    ),
  );
}

FilledButton confirmButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('location-picker.confirm-action')),
  );
}

Future<void> pressButton(WidgetTester tester, Finder finder) async {
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();
  await tester.pump();
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

final MemoryLocation memoryLocationA = MemoryLocation(
  latitude: 41.7151,
  longitude: 44.8271,
);

final MemoryLocation memoryLocationB = MemoryLocation(
  latitude: -12.0464,
  longitude: -77.0428,
);

final class FakeLocationPickerMapSpy {
  final List<LocationPickerMapConfiguration> configurations =
      <LocationPickerMapConfiguration>[];
  final List<MemoryLocation?> selectedLocations = <MemoryLocation?>[];

  Widget build(
    BuildContext context,
    LocationPickerMapConfiguration configuration,
    MemoryLocation? selectedLocation,
    ValueChanged<MemoryLocation> onPointSelected,
  ) {
    configurations.add(configuration);
    selectedLocations.add(selectedLocation);

    return Column(
      key: const ValueKey('location-picker.fake-map'),
      children: [
        Expanded(
          child: Center(
            child: Text(
              selectedLocation == null ? 'Fake map idle' : 'Fake map selected',
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('location-picker.fake-map.select-a'),
          onPressed: () {
            onPointSelected(memoryLocationA);
          },
          child: const Text('Select point A'),
        ),
        TextButton(
          key: const ValueKey('location-picker.fake-map.select-b'),
          onPressed: () {
            onPointSelected(memoryLocationB);
          },
          child: const Text('Select point B'),
        ),
      ],
    );
  }
}
