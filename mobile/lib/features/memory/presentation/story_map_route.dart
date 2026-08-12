import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/story_map_screen.dart';

final storyMapBuilderProvider = Provider<StoryMapBuilder>((_) {
  return _defaultStoryMapRouteBuilder;
});

class StoryMapRoute extends ConsumerWidget {
  const StoryMapRoute({
    required this.storyId,
    this.onBack,
    this.onMemorySelected,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StoryMapScreen(
      storyId: storyId,
      onBack: onBack,
      onMemorySelected: onMemorySelected,
      mapBuilder: ref.watch(storyMapBuilderProvider),
    );
  }
}

Widget _defaultStoryMapRouteBuilder(
  BuildContext context,
  StoryMapViewConfiguration configuration,
) {
  return MapLibreMarkerMap(
    markers: configuration.markers,
    sourceConfiguration: configuration.sourceConfiguration,
    selectedMarkerId: configuration.selectedMarkerId,
    onMarkerSelected: configuration.onMarkerSelected,
    cameraCommand: configuration.cameraCommand,
  );
}
