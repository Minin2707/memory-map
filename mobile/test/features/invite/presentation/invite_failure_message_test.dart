import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/presentation/invite_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('inviteFailureMessage', () {
    testWidgets('shouldMapEveryInviteFailureToLocalizedSafeMessage', (
      WidgetTester tester,
    ) async {
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

      final cases = <InviteFailure, String>{
        const InviteValidationFailure(): l10n.inviteFailureValidation,
        const InviteUnauthorized(): l10n.inviteFailureUnauthorized,
        const InviteNotFound(): l10n.inviteFailureNotFound,
        const InviteNetworkUnavailable():
            l10n.inviteFailureNetworkUnavailable,
        const InviteRequestTimedOut(): l10n.inviteFailureRequestTimedOut,
        const InviteServerFailure(): l10n.inviteFailureServerFailure,
        const UnknownInviteFailure(): l10n.inviteFailureUnknown,
      };

      for (final entry in cases.entries) {
        final message = inviteFailureMessage(l10n, entry.key);

        expect(message, entry.value);
        expect(message, isNot(contains('raw-token')));
        expect(message, isNot(contains('share-token-123')));
        expect(message, isNot(contains('story-id')));
        expect(message, isNot(contains('Dio')));
        expect(message, isNot(contains('HTTP')));
        expect(message, isNot(contains('SQL')));
      }
    });
  });
}
