import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('memoryFailureMessage', () {
    test('shouldMapEveryFailureToSafeEnglishMessage', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        memoryFailureMessage(l10n, const MemoryValidationFailure()),
        'The request was invalid. Please try again.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryUnauthorized()),
        'Your session needs attention. Please try again.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryStoryUnavailable()),
        'Story memories are unavailable.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryNotFound()),
        'Memory is unavailable.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryCreationUnavailable()),
        'Memory cannot be created from here.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryUpdateUnavailable()),
        'Memory cannot be updated from here.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryDeletionUnavailable()),
        'Memory cannot be deleted from here.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryNetworkUnavailable()),
        'No network connection. Check your connection and try again.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryRequestTimedOut()),
        'The request timed out. Please try again.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryServerFailure()),
        'The server is temporarily unavailable. Please try again.',
      );
      expect(
        memoryFailureMessage(l10n, const UnknownMemoryFailure()),
        'Something went wrong. Please try again.',
      );
    });

    test('shouldMapEveryFailureToSafeRussianMessage', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      expect(
        memoryFailureMessage(l10n, const MemoryStoryUnavailable()),
        'Воспоминания истории недоступны.',
      );
      expect(
        memoryFailureMessage(l10n, const MemoryNotFound()),
        'Воспоминание недоступно.',
      );
      expect(
        memoryFailureMessage(l10n, const UnknownMemoryFailure()),
        'Что-то пошло не так. Попробуйте ещё раз.',
      );
    });

    test('shouldNotExposeIdentifiersOrInfrastructureDetails', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      for (final failure in <MemoryFailure>[
        const MemoryStoryUnavailable(),
        const MemoryNotFound(),
        const MemoryDeletionUnavailable(),
        const MemoryServerFailure(),
        const UnknownMemoryFailure(),
      ]) {
        final message = memoryFailureMessage(l10n, failure);

        expect(message, isNot(contains('private-story-id')));
        expect(message, isNot(contains('private-memory-id')));
        expect(message, isNot(contains('Dio')));
        expect(message, isNot(contains('HTTP')));
        expect(message, isNot(contains('ProblemDetail')));
        expect(message, isNot(contains('accessToken')));
      }
    });
  });
}
