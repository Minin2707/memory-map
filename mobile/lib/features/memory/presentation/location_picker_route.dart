import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';
import 'package:memory_map/features/memory/presentation/location_picker_screen.dart';
import 'package:memory_map/features/memory/presentation/widgets/location_picker_map.dart';

final locationPickerMapBuilderProvider =
    Provider<LocationPickerMapBuilder>((ref) {
  return (
    BuildContext context,
    LocationPickerMapConfiguration configuration,
    MemoryLocation? selectedLocation,
    ValueChanged<MemoryLocation> onPointSelected,
  ) {
    return LocationPickerMap(
      configuration: configuration,
      selectedLocation: selectedLocation,
      onPointSelected: onPointSelected,
    );
  };
});

class LocationPickerRoute extends ConsumerWidget {
  const LocationPickerRoute({
    this.initialLocation,
    this.fallbackRouteName,
    super.key,
  });

  final MemoryLocation? initialLocation;
  final String? fallbackRouteName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LocationPickerScreen(
      initialLocation: initialLocation,
      mapBuilder: ref.watch(locationPickerMapBuilderProvider),
      onBack: () {
        _popLocationResult(context, null);
      },
      onLocationSelected: (location) {
        _popLocationResult(context, location);
      },
    );
  }

  void _popLocationResult(
    BuildContext context,
    MemoryLocation? location,
  ) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop<MemoryLocation>(location);
      return;
    }

    final routeName = fallbackRouteName;
    if (routeName != null) {
      context.goNamed(routeName);
    }
  }
}
