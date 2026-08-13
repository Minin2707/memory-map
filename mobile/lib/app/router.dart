import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/app/router_refresh_notifier.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/presentation/auth_checking_screen.dart';
import 'package:memory_map/features/auth/presentation/auth_restore_failure_screen.dart';
import 'package:memory_map/features/auth/presentation/auth_unexpected_error_screen.dart';
import 'package:memory_map/features/auth/presentation/login_screen.dart';
import 'package:memory_map/features/invite/application/invite_deep_link_parser.dart';
import 'package:memory_map/features/invite/application/pending_invite_notifier.dart';
import 'package:memory_map/features/invite/application/pending_invite_state.dart';
import 'package:memory_map/features/invite/presentation/accept_invite_screen.dart';
import 'package:memory_map/features/invite/presentation/invite_screen.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/create_memory_screen.dart';
import 'package:memory_map/features/memory/presentation/location_picker_route.dart';
import 'package:memory_map/features/memory/presentation/memory_details_route.dart';
import 'package:memory_map/features/memory/presentation/memory_edit_route.dart';
import 'package:memory_map/features/memory/presentation/story_map_route.dart';
import 'package:memory_map/features/memory/presentation/story_memories_route.dart';
import 'package:memory_map/features/memory/presentation/story_timeline_route.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/presentation/participants_screen.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/create_story_screen.dart';
import 'package:memory_map/features/story/presentation/edit_story_route.dart';
import 'package:memory_map/features/story/presentation/story_details_screen.dart';
import 'package:memory_map/features/story/presentation/stories_screen.dart';

const authCheckingRoute = '/auth/checking';
const authLoginRoute = '/auth/login';
const authRestoreErrorRoute = '/auth/restore-error';
const authUnexpectedErrorRoute = '/auth/unexpected-error';
const homeRoute = '/home';
const storiesRoute = '/stories';
const createStoryRoute = '/stories/create';
const storyDetailsRoute = '/stories/:storyId';
const editStoryRoute = '/stories/:storyId/edit';
const inviteStoryRoute = '/stories/:storyId/invite';
const storyParticipantsRoute = '/stories/:storyId/participants';
const storyMemoriesRoute = '/stories/:storyId/memories';
const storyMapRoute = '/stories/:storyId/map';
const storyTimelineRoute = '/stories/:storyId/timeline';
const createMemoryRoute = '/stories/:storyId/memories/create';
const memoryDetailsRoute = '/memories/:memoryId';
const editMemoryRoute = '/memories/:memoryId/edit';
const memoryLocationPickerRoute = '/memory-location-picker';
const acceptInviteRoute = '/invite/:token';

const storiesRouteName = 'stories';
const createStoryRouteName = 'createStory';
const storyDetailsRouteName = 'storyDetails';
const editStoryRouteName = 'editStory';
const inviteStoryRouteName = 'inviteStory';
const storyParticipantsRouteName = 'storyParticipants';
const storyMemoriesRouteName = 'storyMemories';
const storyMapRouteName = 'storyMap';
const storyTimelineRouteName = 'storyTimeline';
const createMemoryRouteName = 'createMemory';
const memoryDetailsRouteName = 'memoryDetails';
const editMemoryRouteName = 'editMemory';
const memoryLocationPickerRouteName = 'memoryLocationPicker';
const acceptInviteRouteName = 'acceptInvite';

const _storyIdPathParameter = 'storyId';
const _memoryIdPathParameter = 'memoryId';
const _inviteTokenPathParameter = 'token';
const _memoryDetailsOriginQueryParameter = 'origin';
const _memoryDetailsMapOrigin = 'map';
const _memoryDetailsTimelineOrigin = 'timeline';
const _inviteDeepLinkParser = InviteDeepLinkParser();

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  ref.listen(authNotifierProvider, (previous, next) {
    if (_shouldClearPendingInviteAfterAuthChange(previous, next)) {
      ref.read(pendingInviteProvider.notifier).clear();
    }

    notifier.refresh();
  });
  ref.onDispose(notifier.dispose);

  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);
  final router = GoRouter(
    initialLocation: authCheckingRoute,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final inviteToken = _inviteTokenFromState(state);
      if (inviteToken != null && !_hasAuthenticatedSession(authState)) {
        ref.read(pendingInviteProvider.notifier).setToken(inviteToken);
      }

      return _redirectFor(
        authState,
        state.uri.path,
        ref.read(pendingInviteProvider),
      );
    },
    routes: [
      GoRoute(
        path: authCheckingRoute,
        builder: (BuildContext context, GoRouterState state) {
          return const AuthCheckingScreen();
        },
      ),
      GoRoute(
        path: authLoginRoute,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: authRestoreErrorRoute,
        builder: (BuildContext context, GoRouterState state) {
          return const AuthRestoreFailureScreen();
        },
      ),
      GoRoute(
        path: authUnexpectedErrorRoute,
        builder: (BuildContext context, GoRouterState state) {
          return const AuthUnexpectedErrorScreen();
        },
      ),
      GoRoute(
        path: homeRoute,
        redirect: (BuildContext context, GoRouterState state) {
          return storiesRoute;
        },
      ),
      GoRoute(
        name: acceptInviteRouteName,
        path: acceptInviteRoute,
        builder: (BuildContext context, GoRouterState state) {
          final inviteToken = _inviteTokenFromState(state);
          if (inviteToken == null) {
            return AcceptInviteScreen.invalid(
              onCancel: () {
                _clearPendingInviteAndGoToStories(ref, context);
              },
            );
          }

          return AcceptInviteScreen(
            rawToken: inviteToken,
            onCancel: () {
              _clearPendingInviteAndGoToStories(ref, context);
            },
            onAccepted: (userStory) {
              _completeAcceptedInvite(ref, context, userStory);
            },
            onUnavailable: () {
              ref.read(pendingInviteProvider.notifier).clear();
            },
          );
        },
      ),
      GoRoute(
        name: storiesRouteName,
        path: storiesRoute,
        builder: (BuildContext context, GoRouterState state) {
          final session = _sessionForAuthenticatedRoute(
            ref.read(authNotifierProvider),
          );

          return StoriesScreen(
            displayName: session?.user.displayName ?? '',
            avatarUrl: session?.user.avatarUrl,
            onCreateStory: () {
              context.pushNamed(createStoryRouteName);
            },
            onStorySelected: (storyId) {
              context.pushNamed(
                storyDetailsRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
          );
        },
      ),
      GoRoute(
        name: createStoryRouteName,
        path: createStoryRoute,
        builder: (BuildContext context, GoRouterState state) {
          return CreateStoryScreen(
            onCancel: () {
              _popOrGoToStories(context);
            },
            onCreated: (story) {
              context.pushReplacementNamed(
                storyDetailsRouteName,
                pathParameters: {_storyIdPathParameter: story.id},
              );
            },
          );
        },
      ),
      GoRoute(
        name: storyDetailsRouteName,
        path: storyDetailsRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return StoryDetailsScreen(
            storyId: storyId,
            onBack: () {
              _popOrGoToStories(context);
            },
            onEditStory: (userStory) {
              context.pushNamed(
                editStoryRouteName,
                pathParameters: {_storyIdPathParameter: userStory.story.id},
                extra: userStory,
              );
            },
            onInvite: () {
              context.pushNamed(
                inviteStoryRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onParticipantsSelected: (_) {
              context.pushNamed(
                storyParticipantsRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onMemoriesSelected: (_) {
              context.pushNamed(
                storyMemoriesRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onMapSelected: (_) {
              context.pushNamed(
                storyMapRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onTimelineSelected: (_) {
              context.pushNamed(
                storyTimelineRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
          );
        },
      ),
      GoRoute(
        name: storyTimelineRouteName,
        path: storyTimelineRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return StoryTimelineRoute(
            storyId: storyId,
            onBack: () {
              _popOrGoToStoryDetails(context, storyId);
            },
            onCreateMemory: () {
              context.pushNamed(
                createMemoryRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
                extra: _MemoryDetailsOrigin.timeline,
              );
            },
            onMemorySelected: (memory) {
              context.pushNamed(
                memoryDetailsRouteName,
                pathParameters: {_memoryIdPathParameter: memory.id},
                extra: _MemoryDetailsOrigin.timeline,
                queryParameters: {
                  _memoryDetailsOriginQueryParameter:
                      _memoryDetailsTimelineOrigin,
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: storyMapRouteName,
        path: storyMapRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return StoryMapRoute(
            storyId: storyId,
            onBack: () {
              _popOrGoToStoryDetails(context, storyId);
            },
            onMemorySelected: (memory) {
              context.pushNamed(
                memoryDetailsRouteName,
                pathParameters: {_memoryIdPathParameter: memory.id},
                extra: _MemoryDetailsOrigin.map,
                queryParameters: {
                  _memoryDetailsOriginQueryParameter: _memoryDetailsMapOrigin,
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: storyMemoriesRouteName,
        path: storyMemoriesRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return StoryMemoriesRoute(
            storyId: storyId,
            onBack: () {
              _popOrGoToStoryDetails(context, storyId);
            },
            onCreateMemory: () {
              context.pushNamed(
                createMemoryRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onMemorySelected: (memory) {
              context.pushNamed(
                memoryDetailsRouteName,
                pathParameters: {_memoryIdPathParameter: memory.id},
              );
            },
          );
        },
      ),
      GoRoute(
        name: createMemoryRouteName,
        path: createMemoryRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return CreateMemoryScreen(
            storyId: storyId,
            onBack: () {
              if (state.extra == _MemoryDetailsOrigin.timeline) {
                _popOrGoToStoryTimeline(context, storyId);
                return;
              }

              _popOrGoToStoryMemories(context, storyId);
            },
            onPickLocation: (initialLocation) {
              return _pickMemoryLocation(context, initialLocation);
            },
            onMemoryCreated: (memory) {
              context.pushReplacementNamed(
                memoryDetailsRouteName,
                pathParameters: {_memoryIdPathParameter: memory.id},
                extra: state.extra,
                queryParameters: _memoryDetailsOriginQueryParameters(
                  state.extra,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        name: memoryDetailsRouteName,
        path: memoryDetailsRoute,
        builder: (BuildContext context, GoRouterState state) {
          final memoryId =
              state.pathParameters[_memoryIdPathParameter] ?? '';
          final session = _sessionForAuthenticatedRoute(
            ref.read(authNotifierProvider),
          );
          final origin = _memoryDetailsOriginFor(state);

          return MemoryDetailsRoute(
            memoryId: memoryId,
            currentUserId: session?.user.id,
            onBackUnavailable: () {
              _popOrGoToStories(context);
            },
            onBack: (memory) {
              if (origin == _MemoryDetailsOrigin.timeline) {
                _popOrGoToStoryTimeline(context, memory.storyId);
                return;
              }

              if (origin == _MemoryDetailsOrigin.map) {
                _popOrGoToStoryMap(context, memory.storyId);
                return;
              }

              _popOrGoToStoryMemories(context, memory.storyId);
            },
            onEdit: (memory) {
              context.pushNamed(
                editMemoryRouteName,
                pathParameters: {_memoryIdPathParameter: memory.id},
              );
            },
            onDelete: (memory) {
              _completeDeletedMemory(ref, context, memory, origin);
            },
          );
        },
      ),
      GoRoute(
        name: editMemoryRouteName,
        path: editMemoryRoute,
        builder: (BuildContext context, GoRouterState state) {
          final memoryId =
              state.pathParameters[_memoryIdPathParameter] ?? '';

          return MemoryEditRoute(
            memoryId: memoryId,
            onBack: () {
              _popOrGoToMemoryDetails(context, memoryId);
            },
            onPickLocation: (initialLocation) {
              return _pickMemoryLocation(context, initialLocation);
            },
            onMemoryUpdated: (memory) {
              _popOrGoToMemoryDetails(context, memory.id);
            },
          );
        },
      ),
      GoRoute(
        name: memoryLocationPickerRouteName,
        path: memoryLocationPickerRoute,
        builder: (BuildContext context, GoRouterState state) {
          final extra = state.extra;

          return LocationPickerRoute(
            initialLocation: extra is MemoryLocation ? extra : null,
            fallbackRouteName: storiesRouteName,
          );
        },
      ),
      GoRoute(
        name: storyParticipantsRouteName,
        path: storyParticipantsRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';
          final session = _sessionForAuthenticatedRoute(
            ref.read(authNotifierProvider),
          );
          if (session == null) {
            return const AuthUnexpectedErrorScreen();
          }

          return ParticipantsScreen(
            storyId: storyId,
            currentUserId: session.user.id,
            onBack: () {
              _popOrGoToStoryDetails(context, storyId);
            },
            onInvite: () {
              context.pushNamed(
                inviteStoryRouteName,
                pathParameters: {_storyIdPathParameter: storyId},
              );
            },
            onLeftStory: () {
              _completeLeftStory(ref, context, storyId);
            },
            onParticipantRemoved: (_) {},
          );
        },
      ),
      GoRoute(
        name: inviteStoryRouteName,
        path: inviteStoryRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';

          return InviteScreen(
            storyId: storyId,
            onBack: () {
              _popOrGoToStoryDetails(context, storyId);
            },
          );
        },
      ),
      GoRoute(
        name: editStoryRouteName,
        path: editStoryRoute,
        builder: (BuildContext context, GoRouterState state) {
          final storyId =
              state.pathParameters[_storyIdPathParameter] ?? '';
          final extra = state.extra;

          return EditStoryRoute(
            storyId: storyId,
            initialUserStory: extra is UserStory ? extra : null,
            onCancel: () {
              _popOrGoToStoryDetails(context, storyId);
            },
            onUpdated: (updatedUserStory) {
              ref
                  .read(storyDetailsProvider(storyId).notifier)
                  .applyUpdatedStory(updatedUserStory);
              ref
                  .read(storiesNotifierProvider.notifier)
                  .applyUpdatedStory(updatedUserStory);
              _popOrGoToStoryDetails(context, storyId);
            },
          );
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

String? _redirectFor(
  AsyncValue<AuthState> authState,
  String path,
  PendingInviteState pendingInvite,
) {
  if (authState.isLoading) {
    return path == authCheckingRoute ? null : authCheckingRoute;
  }

  if (authState.hasError) {
    return path == authUnexpectedErrorRoute
        ? null
        : authUnexpectedErrorRoute;
  }

  final value = authState.asData?.value;
  if (value is AuthRestoreFailure) {
    return path == authRestoreErrorRoute
        ? null
        : authRestoreErrorRoute;
  }

  if (value is AuthAuthenticated ||
      value is AuthLoggingOut ||
      value is AuthLogoutFailure) {
    final pendingToken = pendingInvite.rawToken;
    if (pendingToken != null && !_isAcceptInviteRoute(path)) {
      return _acceptInvitePath(pendingToken);
    }

    if (_isAuthenticatedRoute(path) || _isAcceptInviteRoute(path)) {
      return null;
    }

    return storiesRoute;
  }

  if (path == authLoginRoute) {
    return null;
  }

  return authLoginRoute;
}

bool _shouldClearPendingInviteAfterAuthChange(
  AsyncValue<AuthState>? previous,
  AsyncValue<AuthState> next,
) {
  final previousValue = previous?.asData?.value;
  final nextValue = next.asData?.value;
  final previousHadSession = previousValue is AuthAuthenticated ||
      previousValue is AuthLoggingOut ||
      previousValue is AuthLogoutFailure;

  return previousHadSession && nextValue is AuthUnauthenticated;
}

bool _hasAuthenticatedSession(AsyncValue<AuthState> authState) {
  final value = authState.asData?.value;
  return value is AuthAuthenticated ||
      value is AuthLoggingOut ||
      value is AuthLogoutFailure;
}

bool _isAuthenticatedRoute(String path) {
  return path == storiesRoute ||
      path.startsWith('$storiesRoute/') ||
      path == memoryLocationPickerRoute ||
      path.startsWith('/memories/');
}

bool _isAcceptInviteRoute(String path) {
  final segments = Uri(path: path).pathSegments;
  return segments.length == 2 && segments.first == 'invite';
}

String? _inviteTokenFromState(GoRouterState state) {
  final canonicalInvite = _inviteDeepLinkParser.parse(state.uri);
  if (canonicalInvite != null) {
    return canonicalInvite.rawToken;
  }

  if (state.uri.scheme.isNotEmpty ||
      state.uri.host.isNotEmpty ||
      state.uri.hasQuery ||
      state.uri.hasFragment) {
    return null;
  }

  final rawToken = state.pathParameters[_inviteTokenPathParameter];
  if (rawToken == null) {
    return null;
  }

  return _inviteDeepLinkParser
      .parseString(
        'https://app.memorymap.app/invite/${Uri.encodeComponent(rawToken)}',
      )
      ?.rawToken;
}

String _acceptInvitePath(String rawToken) {
  return '/invite/${Uri.encodeComponent(rawToken)}';
}

void _popOrGoToStories(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(storiesRouteName);
}

void _popOrGoToStoryDetails(BuildContext context, String storyId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(
    storyDetailsRouteName,
    pathParameters: {_storyIdPathParameter: storyId},
  );
}

void _popOrGoToStoryMemories(BuildContext context, String storyId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(
    storyMemoriesRouteName,
    pathParameters: {_storyIdPathParameter: storyId},
  );
}

void _popOrGoToStoryTimeline(BuildContext context, String storyId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(
    storyTimelineRouteName,
    pathParameters: {_storyIdPathParameter: storyId},
  );
}

void _popOrGoToStoryMap(BuildContext context, String storyId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(
    storyMapRouteName,
    pathParameters: {_storyIdPathParameter: storyId},
  );
}

void _popOrGoToMemoryDetails(BuildContext context, String memoryId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  context.goNamed(
    memoryDetailsRouteName,
    pathParameters: {_memoryIdPathParameter: memoryId},
  );
}

Object? _memoryDetailsOriginFor(GoRouterState state) {
  final extra = state.extra;
  if (extra == _MemoryDetailsOrigin.timeline ||
      extra == _MemoryDetailsOrigin.map) {
    return extra;
  }

  return switch (state.uri.queryParameters[_memoryDetailsOriginQueryParameter]) {
    _memoryDetailsTimelineOrigin => _MemoryDetailsOrigin.timeline,
    _memoryDetailsMapOrigin => _MemoryDetailsOrigin.map,
    _ => null,
  };
}

Map<String, String> _memoryDetailsOriginQueryParameters(Object? origin) {
  if (origin == _MemoryDetailsOrigin.timeline) {
    return {
      _memoryDetailsOriginQueryParameter: _memoryDetailsTimelineOrigin,
    };
  }
  if (origin == _MemoryDetailsOrigin.map) {
    return {
      _memoryDetailsOriginQueryParameter: _memoryDetailsMapOrigin,
    };
  }

  return const <String, String>{};
}

Future<MemoryLocation?> _pickMemoryLocation(
  BuildContext context,
  MemoryLocation? initialLocation,
) {
  return context.pushNamed<MemoryLocation>(
    memoryLocationPickerRouteName,
    extra: initialLocation,
  );
}

void _clearPendingInviteAndGoToStories(Ref ref, BuildContext context) {
  ref.read(pendingInviteProvider.notifier).clear();
  context.goNamed(storiesRouteName);
}

void _completeAcceptedInvite(
  Ref ref,
  BuildContext context,
  UserStory userStory,
) {
  final storyId = userStory.story.id;

  ref.read(pendingInviteProvider.notifier).clear();
  ref.read(storiesNotifierProvider.notifier).upsertUserStory(userStory);
  ref.read(storyDetailsProvider(storyId).notifier).applyUpdatedStory(userStory);
  context.goNamed(
    storyDetailsRouteName,
    pathParameters: {_storyIdPathParameter: storyId},
  );
}

void _completeLeftStory(
  Ref ref,
  BuildContext context,
  String storyId,
) {
  ref.read(storiesNotifierProvider.notifier).removeStoryById(storyId);
  context.goNamed(storiesRouteName);
  ref.invalidate(storyDetailsProvider(storyId));
  ref.invalidate(storyParticipantsProvider(storyId));
  ref.invalidate(storyMemoriesProvider(storyId));
  ref.invalidate(storyMapProvider(storyId));
  ref.invalidate(storyMapSelectionProvider(storyId));
}

void _completeDeletedMemory(
  Ref ref,
  BuildContext context,
  Memory memory,
  Object? origin,
) {
  if (origin == _MemoryDetailsOrigin.timeline) {
    context.go(_storyTimelinePath(memory.storyId));
  } else if (origin == _MemoryDetailsOrigin.map) {
    context.go(_storyMapPath(memory.storyId));
  } else {
    context.go(_storyMemoriesPath(memory.storyId));
  }
  ref.invalidate(memoryDetailsProvider(memory.id));
}

String _storyMemoriesPath(String storyId) {
  return '/stories/${Uri.encodeComponent(storyId)}/memories';
}

String _storyMapPath(String storyId) {
  return '/stories/${Uri.encodeComponent(storyId)}/map';
}

String _storyTimelinePath(String storyId) {
  return '/stories/${Uri.encodeComponent(storyId)}/timeline';
}

enum _MemoryDetailsOrigin {
  timeline,
  map,
}

AuthSession? _sessionForAuthenticatedRoute(AsyncValue<AuthState> authState) {
  final value = authState.asData?.value;
  return switch (value) {
    AuthAuthenticated(:final session) => session,
    AuthLoggingOut(:final session) => session,
    AuthLogoutFailure(:final session) => session,
    _ => null,
  };
}
