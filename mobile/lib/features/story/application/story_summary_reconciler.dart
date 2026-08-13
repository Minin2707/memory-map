import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';

final storySummaryReconcilerProvider = Provider<StorySummaryReconciler>((ref) {
  return StorySummaryReconciler(ref);
});

final class StorySummaryReconciler {
  const StorySummaryReconciler(this._ref);

  final Ref _ref;

  Future<void> reconcileAuthoritativeStory(String storyId) async {
    if (storyId.trim().isEmpty || !_hasLoadedTarget(storyId)) {
      return;
    }

    try {
      final userStory = await _ref.read(storyRepositoryProvider).getStory(
            storyId,
          );
      if (!_ref.mounted) {
        return;
      }

      final stories = storiesNotifierProvider;
      if (_ref.exists(stories)) {
        _ref.read(stories.notifier).applyAuthoritativeRead(userStory);
      }

      final details = storyDetailsProvider(storyId);
      if (_ref.exists(details)) {
        _ref.read(details.notifier).applyAuthoritativeRead(userStory);
      }
    } on Object {
      return;
    }
  }

  void removeStory(String storyId) {
    if (storyId.trim().isEmpty) {
      return;
    }

    final stories = storiesNotifierProvider;
    if (_ref.exists(stories)) {
      _ref.read(stories.notifier).removeStoryById(storyId);
    }
  }

  bool _hasLoadedTarget(String storyId) {
    if (_ref.exists(storiesNotifierProvider)) {
      final storiesState = _ref.read(storiesNotifierProvider).asData?.value;
      if (storiesState != null && storiesState.isLoaded) {
        return true;
      }
    }

    final details = storyDetailsProvider(storyId);
    if (_ref.exists(details)) {
      final detailsState = _ref.read(details).asData?.value;
      if (detailsState != null && detailsState.isLoaded) {
        return true;
      }
    }

    return false;
  }
}
