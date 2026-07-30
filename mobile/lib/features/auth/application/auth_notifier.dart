import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
  retry: (retryCount, error) => null,
);

final class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    return _restoreSession(ref.watch(authRepositoryProvider));
  }

  Future<void> retrySessionRestore() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<AuthState>();
    state = await AsyncValue.guard<AuthState>(() async {
      return _restoreSession(ref.read(authRepositoryProvider));
    });
  }

  Future<void> loginWithGoogle() async {
    if (_isLoading || _currentState is AuthAuthenticating) {
      return;
    }

    state = const AsyncData<AuthState>(AuthAuthenticating());

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .loginWithGoogle();

      state = AsyncData<AuthState>(AuthAuthenticated(session));
    } on AuthApplicationException catch (error) {
      state = AsyncData<AuthState>(_mapLoginFailure(error.failure));
    } on Object catch (error, stackTrace) {
      state = AsyncError<AuthState>(error, stackTrace);
    }
  }

  Future<void> logout() async {
    final session = _logoutSession;
    if (session == null) {
      return;
    }

    state = AsyncData<AuthState>(AuthLoggingOut(session));

    try {
      await ref.read(authRepositoryProvider).logout(session);
      state = const AsyncData<AuthState>(AuthUnauthenticated());
    } on AuthApplicationException catch (error) {
      state = AsyncData<AuthState>(
        AuthLogoutFailure(
          session: session,
          failure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError<AuthState>(error, stackTrace);
    }
  }

  Future<AuthState> _restoreSession(AuthRepository repository) async {
    try {
      final session = await repository.restoreSession();
      if (session == null) {
        return const AuthUnauthenticated();
      }

      return AuthAuthenticated(session);
    } on AuthApplicationException catch (error) {
      return AuthRestoreFailure(error.failure);
    }
  }

  AuthState _mapLoginFailure(AuthFailure failure) {
    if (failure is AuthCancelled) {
      return const AuthUnauthenticated();
    }

    return AuthLoginFailure(failure);
  }

  bool get _isLoading => state is AsyncLoading<AuthState>;

  AuthState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<AuthState>) {
      return currentState.value;
    }

    return null;
  }

  AuthSession? get _logoutSession {
    final currentState = _currentState;

    return switch (currentState) {
      AuthAuthenticated(:final session) => session,
      AuthLogoutFailure(:final session) => session,
      _ => null,
    };
  }
}
