import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/invite/application/accept_invite_notifier.dart';
import 'package:memory_map/features/invite/application/create_invite_notifier.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/story_details_memory_projection.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_year_projection.dart';
import 'package:memory_map/features/memory/application/story_timeline_projection.dart';
import 'package:memory_map/features/music/application/music_catalog_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/notification/application/notification_inbox_notifier.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/story/application/edit_story_notifier.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_cover_notifier.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';

final authSessionCleanupCoordinatorProvider =
    Provider<AuthSessionCleanupCoordinator>((ref) {
  return AuthSessionCleanupCoordinator(ref);
});

final class AuthSessionCleanupCoordinator {
  AuthSessionCleanupCoordinator(this._ref);

  final Ref _ref;

  void handleAuthStateChange(
    AsyncValue<AuthState>? previous,
    AsyncValue<AuthState> next,
  ) {
    final previousUserId = _authScopedUserId(previous);
    if (previousUserId == null) {
      return;
    }

    final nextUserId = _authScopedUserId(next);
    if (nextUserId == previousUserId) {
      return;
    }

    clearAuthenticatedFeatureState();
  }

  void clearAuthenticatedFeatureState() {
    _ref.invalidate(storiesNotifierProvider);
    _ref.invalidate(storyDetailsProvider);
    _ref.invalidate(editStoryProvider);
    _ref.invalidate(storyCoverProvider);

    _ref.invalidate(storyMemoriesProvider);
    _ref.invalidate(memoryDetailsProvider);
    _ref.invalidate(storyDetailsRecentMemoriesProvider);
    _ref.invalidate(storyDetailsMemoryPeriodProvider);
    _ref.invalidate(storyMemoriesYearSectionsProvider);
    _ref.invalidate(storyTimelineSectionsProvider);
    _ref.invalidate(storyMapProvider);
    _ref.invalidate(storyMapSelectionProvider);

    _ref.invalidate(storyParticipantsProvider);
    _ref.invalidate(storySoundtrackProvider);
    _ref.invalidate(notificationInboxProvider);
    _ref.invalidate(unreadNotificationCountProvider);
    _ref.invalidate(memoryMediaProvider);
    _ref.invalidate(createInviteProvider);
    _ref.invalidate(acceptInviteProvider);
    _ref.invalidate(musicCatalogProvider);
  }
}

String? _authScopedUserId(AsyncValue<AuthState>? state) {
  final value = state?.asData?.value;
  return switch (value) {
    AuthAuthenticated(:final session) => session.user.id,
    AuthLoggingOut(:final session) => session.user.id,
    AuthLogoutFailure(:final session) => session.user.id,
    _ => null,
  };
}
