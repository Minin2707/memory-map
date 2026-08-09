import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/presentation/participant_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldMapParticipantFailuresInEnglishSafely', (tester) async {
    late AppLocalizations l10n;
    await pumpLocalizations(tester, (context) {
      l10n = AppLocalizations.of(context);
    });

    final cases = <ParticipantFailure, String>{
      const ParticipantValidationFailure():
          'The request was invalid. Please try again.',
      const ParticipantUnauthorized():
          'Your session needs attention. Please try again.',
      const ParticipantNotFound(): 'Participants are unavailable.',
      const ParticipantLastOwnerConflict():
          'The last owner cannot leave this story.',
      const ParticipantCannotRemoveSelf():
          'Use Leave story to remove yourself.',
      const ParticipantOwnerCannotBeRemoved():
          'Owners cannot be removed from here.',
      const ParticipantNetworkUnavailable():
          'No network connection. Check your connection and try again.',
      const ParticipantRequestTimedOut():
          'The request timed out. Please try again.',
      const ParticipantServerFailure():
          'The server is temporarily unavailable. Please try again.',
      const UnknownParticipantFailure():
          'Something went wrong. Please try again.',
    };

    for (final entry in cases.entries) {
      final message = participantFailureMessage(l10n, entry.key);

      expect(message, entry.value);
      expect(message, isNot(contains('Dio')));
      expect(message, isNot(contains('HTTP')));
      expect(message, isNot(contains('ProblemDetail')));
      expect(message, isNot(contains('private-story-id')));
      expect(message, isNot(contains('private-user-id')));
    }
  });

  testWidgets('shouldMapParticipantFailuresInRussianSafely', (tester) async {
    late AppLocalizations l10n;
    await pumpLocalizations(
      tester,
      (context) {
        l10n = AppLocalizations.of(context);
      },
      locale: const Locale('ru'),
    );

    expect(
      participantFailureMessage(l10n, const ParticipantLastOwnerConflict()),
      'Последний владелец не может покинуть эту историю.',
    );
    expect(
      participantFailureMessage(l10n, const ParticipantCannotRemoveSelf()),
      'Чтобы удалить себя, используйте действие «Покинуть историю».',
    );
    expect(
      participantFailureMessage(l10n, const ParticipantOwnerCannotBeRemoved()),
      'Владельца нельзя удалить отсюда.',
    );
    expect(
      participantFailureMessage(l10n, const ParticipantNetworkUnavailable()),
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.',
    );
  });
}

Future<void> pumpLocalizations(
  WidgetTester tester,
  ValueChanged<BuildContext> onContext, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          onContext(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}
