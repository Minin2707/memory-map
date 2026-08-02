import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldMapAllStoryFailuresToSafeEnglishMessages', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('en'));

    expect(
      storyFailureMessage(l10n, const StoryValidationFailure()),
      'The request was invalid. Please try again.',
    );
    expect(
      storyFailureMessage(l10n, const StoryUnauthorized()),
      'Your session needs attention. Please try again.',
    );
    expect(
      storyFailureMessage(l10n, const StoryNotFound()),
      'Story is unavailable.',
    );
    expect(
      storyFailureMessage(l10n, const StoryNetworkUnavailable()),
      'No network connection. Check your connection and try again.',
    );
    expect(
      storyFailureMessage(l10n, const StoryRequestTimedOut()),
      'The request timed out. Please try again.',
    );
    expect(
      storyFailureMessage(l10n, const StoryServerFailure()),
      'The server is temporarily unavailable. Please try again.',
    );
    expect(
      storyFailureMessage(l10n, const UnknownStoryFailure()),
      'Something went wrong. Please try again.',
    );
  });

  testWidgets('shouldMapAllStoryFailuresToSafeRussianMessages', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('ru'));

    expect(
      storyFailureMessage(l10n, const StoryValidationFailure()),
      'Запрос содержит ошибку. Попробуйте ещё раз.',
    );
    expect(
      storyFailureMessage(l10n, const StoryUnauthorized()),
      'Сеанс требует внимания. Попробуйте ещё раз.',
    );
    expect(
      storyFailureMessage(l10n, const StoryNotFound()),
      'История недоступна.',
    );
    expect(
      storyFailureMessage(l10n, const StoryNetworkUnavailable()),
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.',
    );
    expect(
      storyFailureMessage(l10n, const StoryRequestTimedOut()),
      'Время ожидания истекло. Попробуйте ещё раз.',
    );
    expect(
      storyFailureMessage(l10n, const StoryServerFailure()),
      'Сервер временно недоступен. Попробуйте ещё раз.',
    );
    expect(
      storyFailureMessage(l10n, const UnknownStoryFailure()),
      'Что-то пошло не так. Попробуйте ещё раз.',
    );
  });

  testWidgets('shouldNotExposeInfrastructureDetails', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('en'));

    final message = storyFailureMessage(l10n, const UnknownStoryFailure());

    expect(message, isNot(contains('Dio')));
    expect(message, isNot(contains('StoryApplicationException')));
    expect(message, isNot(contains('accessToken')));
    expect(message, isNot(contains('raw response')));
  });
}

Future<AppLocalizations> loadL10n(
  WidgetTester tester,
  Locale locale,
) async {
  late AppLocalizations l10n;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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
  await tester.pump();

  return l10n;
}
