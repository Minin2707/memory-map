import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/edit_story_screen.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/stories_error_view.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class EditStoryRoute extends ConsumerWidget {
  const EditStoryRoute({
    required this.storyId,
    required this.onCancel,
    required this.onUpdated,
    this.initialUserStory,
    super.key,
  });

  final String storyId;
  final UserStory? initialUserStory;
  final VoidCallback? onCancel;
  final ValueChanged<UserStory>? onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsValue = ref.watch(storyDetailsProvider(storyId));
    final detailsState = detailsValue.asData?.value;
    final loadedStory = detailsState?.userStory;
    final initial = initialUserStory;
    final fallbackStory = initial != null && initial.story.id == storyId
        ? initial
        : null;
    final userStory = loadedStory ?? fallbackStory;
    if (userStory != null) {
      return EditStoryScreen(
        userStory: userStory,
        onCancel: onCancel,
        onUpdated: onUpdated,
      );
    }

    if (detailsValue.isLoading) {
      return const _EditStoryRouteScaffold(child: _LoadingView());
    }

    if (detailsValue.hasError) {
      final l10n = AppLocalizations.of(context);
      return _EditStoryRouteScaffold(
        child: StoriesErrorView(
          title: l10n.unexpectedErrorTitle,
          message: l10n.storyFailureUnknown,
          onRetry: () {
            ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    if (detailsState == null) {
      return const _EditStoryRouteScaffold(child: _LoadingView());
    }

    final loadFailure = detailsState.loadFailure;
    if (loadFailure != null) {
      final l10n = AppLocalizations.of(context);
      return _EditStoryRouteScaffold(
        child: StoriesErrorView(
          title: l10n.storyDetailsLoadFailureTitle,
          message: storyFailureMessage(l10n, loadFailure),
          onRetry: () {
            ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    return const _EditStoryRouteScaffold(child: _LoadingView());
  }
}

class _EditStoryRouteScaffold extends StatelessWidget {
  const _EditStoryRouteScaffold({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey('edit-story.route-loading'),
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: Color(0xFFFF5D72),
      ),
    );
  }
}
