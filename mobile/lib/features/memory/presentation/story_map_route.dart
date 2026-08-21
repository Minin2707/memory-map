import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/story_map_photo_marker_map.dart';
import 'package:memory_map/features/memory/presentation/story_map_screen.dart';

final storyMapBuilderProvider = Provider<StoryMapBuilder>((_) {
  return _defaultStoryMapRouteBuilder;
});

class StoryMapRoute extends ConsumerWidget {
  const StoryMapRoute({
    required this.storyId,
    this.onBack,
    this.onMemorySelected,
    this.initialSelectedMemoryId,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onMemorySelected;
  final String? initialSelectedMemoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StoryMapScreen(
      storyId: storyId,
      onBack: onBack,
      onMemorySelected: onMemorySelected,
      mapBuilder: ref.watch(storyMapBuilderProvider),
      initialSelectedMemoryId: initialSelectedMemoryId,
    );
  }
}

Widget _defaultStoryMapRouteBuilder(
  BuildContext context,
  StoryMapViewConfiguration configuration,
) {
  return StoryMapPhotoMarkerMap(
    markerPresentations: configuration.markerPresentations,
    sourceConfiguration: configuration.sourceConfiguration,
    selectedMarkerId: configuration.selectedMarkerId,
    onMarkerSelected: configuration.onMarkerSelected,
    cameraCommand: configuration.cameraCommand,
  );
}
