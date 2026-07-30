import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/app/router_refresh_notifier.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/presentation/auth_checking_screen.dart';
import 'package:memory_map/features/auth/presentation/auth_restore_failure_screen.dart';
import 'package:memory_map/features/auth/presentation/auth_unexpected_error_screen.dart';
import 'package:memory_map/features/auth/presentation/authenticated_home_screen.dart';
import 'package:memory_map/features/auth/presentation/login_screen.dart';

const authCheckingRoute = '/auth/checking';
const authLoginRoute = '/auth/login';
const authRestoreErrorRoute = '/auth/restore-error';
const authUnexpectedErrorRoute = '/auth/unexpected-error';
const homeRoute = '/home';

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
      final destination = _destinationFor(authState);

      if (state.matchedLocation == destination) {
        return null;
      }

      return destination;
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
        builder: (BuildContext context, GoRouterState state) {
          return const AuthenticatedHomeScreen();
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

String _destinationFor(AsyncValue<AuthState> authState) {
  if (authState.isLoading) {
    return authCheckingRoute;
  }

  if (authState.hasError) {
    return authUnexpectedErrorRoute;
  }

  final value = authState.asData?.value;
  return switch (value) {
    AuthAuthenticated() ||
    AuthLoggingOut() ||
    AuthLogoutFailure() =>
      homeRoute,
    AuthRestoreFailure() => authRestoreErrorRoute,
    AuthUnauthenticated() ||
    AuthAuthenticating() ||
    AuthLoginFailure() ||
    null =>
      authLoginRoute,
  };
}
