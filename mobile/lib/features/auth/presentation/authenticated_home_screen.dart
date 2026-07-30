import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';

class AuthenticatedHomeScreen extends ConsumerWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authNotifierProvider);
    final authState = authValue.asData?.value;
    final session = _sessionFor(authState);
    final displayName = session?.user.displayName ?? 'there';
    final isLoggingOut = authState is AuthLoggingOut;
    final logoutFailure = authState is AuthLogoutFailure
        ? authFailureMessage(authState.failure)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Map'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome, $displayName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Authenticated session is ready'),
                if (logoutFailure != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    logoutFailure,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: isLoggingOut
                      ? null
                      : () {
                          ref.read(authNotifierProvider.notifier).logout();
                        },
                  child: isLoggingOut
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Logging out...'),
                          ],
                        )
                      : const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AuthSession? _sessionFor(AuthState? authState) {
    return switch (authState) {
      AuthAuthenticated(:final session) => session,
      AuthLoggingOut(:final session) => session,
      AuthLogoutFailure(:final session) => session,
      _ => null,
    };
  }
}
