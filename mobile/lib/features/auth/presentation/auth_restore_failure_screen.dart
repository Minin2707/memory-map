import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class AuthRestoreFailureScreen extends ConsumerWidget {
  const AuthRestoreFailureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authNotifierProvider);
    final l10n = AppLocalizations.of(context);
    final authState = authValue.asData?.value;
    final message = authState is AuthRestoreFailure
        ? authFailureMessage(l10n, authState.failure)
        : l10n.unknownAuthFailure;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.restoreSessionTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(authNotifierProvider.notifier)
                        .retrySessionRestore();
                  },
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
