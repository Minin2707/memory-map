import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/presentation/media_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldMapKnownFailuresToLocalizedSafeMessages', (tester) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      mediaFailureMessage(l10n, const MediaValidationFailure()),
      'The photo request was invalid. Please try again.',
    );
    expect(
      mediaFailureMessage(l10n, const MediaUnauthorized()),
      'Your session needs attention. Please try again.',
    );
    expect(
      mediaFailureMessage(l10n, const MediaPreprocessingFailure()),
      'Could not prepare this photo. Choose another image.',
    );
    expect(
      mediaFailureMessage(l10n, const UnknownMediaFailure()),
      'Something went wrong. Please try again.',
    );
  });
}
