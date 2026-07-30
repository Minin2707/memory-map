import 'package:flutter/material.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class AuthCheckingScreen extends StatelessWidget {
  const AuthCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.checkingSession),
            ],
          ),
        ),
      ),
    );
  }
}
