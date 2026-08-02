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

const storiesRouteName = 'stories';
const createStoryRouteName = 'createStory';
const storyDetailsRouteName = 'storyDetails';
const editStoryRouteName = 'editStory';

const _storyIdPathParameter = 'storyId';

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  ref.listen(authNotifierProvider, (_, __) {
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
      return _redirectFor(authState, state.uri.path);
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
    if (_isAuthenticatedRoute(path)) {
      return null;
    }

    return storiesRoute;
  }

  if (path == authLoginRoute) {
    return null;
  }

  return authLoginRoute;
}

bool _isAuthenticatedRoute(String path) {
  return path == storiesRoute || path.startsWith('$storiesRoute/');
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

AuthSession? _sessionForAuthenticatedRoute(AsyncValue<AuthState> authState) {
  final value = authState.asData?.value;
  return switch (value) {
    AuthAuthenticated(:final session) => session,
    AuthLoggingOut(:final session) => session,
    AuthLogoutFailure(:final session) => session,
    _ => null,
  };
}
