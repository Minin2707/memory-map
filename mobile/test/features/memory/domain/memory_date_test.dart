import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';

void main() {
  group('MemoryDate', () {
    test('shouldCreateValidDate', () {
      final date = MemoryDate(year: 2026, month: 8, day: 9);

      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 9);
    });

    test('shouldAllowLeapYearDate', () {
      final date = MemoryDate(year: 2024, month: 2, day: 29);

      expect(date.toIso8601Date(), '2024-02-29');
    });

    test('shouldRejectInvalidLeapDay', () {
      expect(
        () => MemoryDate(year: 2023, month: 2, day: 29),
        throwsA(argumentErrorWithMessage('day must be valid for year and month')),
      );
    });

    test('shouldRejectInvalidMonth', () {
      expect(
        () => MemoryDate(year: 2026, month: 0, day: 1),
        throwsA(argumentErrorWithMessage('month must be between 1 and 12')),
      );
      expect(
        () => MemoryDate(year: 2026, month: 13, day: 1),
        throwsA(argumentErrorWithMessage('month must be between 1 and 12')),
      );
    });

    test('shouldRejectInvalidDay', () {
      expect(
        () => MemoryDate(year: 2026, month: 2, day: 30),
        throwsA(argumentErrorWithMessage('day must be valid for year and month')),
      );
      expect(
        () => MemoryDate(year: 2026, month: 1, day: 0),
        throwsA(argumentErrorWithMessage('day must be valid for year and month')),
      );
      expect(
        () => MemoryDate(year: 2026, month: 1, day: 32),
        throwsA(argumentErrorWithMessage('day must be valid for year and month')),
      );
    });

    test('shouldRejectYearOutsideFourDigitBackendContract', () {
      expect(
        () => MemoryDate(year: 0, month: 1, day: 1),
        throwsA(argumentErrorWithMessage('year must be between 1 and 9999')),
      );
      expect(
        () => MemoryDate(year: 10000, month: 1, day: 1),
        throwsA(argumentErrorWithMessage('year must be between 1 and 9999')),
      );
    });

    test('shouldParseStrictCanonicalDate', () {
      final date = MemoryDate.parse('2026-08-09');

      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 9);
      expect(date.toIso8601Date(), '2026-08-09');
    });

    test('shouldParseMinimumFourDigitYear', () {
      final date = MemoryDate.parse('0001-01-01');

      expect(date.year, 1);
      expect(date.month, 1);
      expect(date.day, 1);
      expect(date.toIso8601Date(), '0001-01-01');
    });

    test('shouldRejectNonCanonicalDates', () {
      for (final value in <String>[
        '',
        '2026-8-9',
        '09.08.2026',
        '2026/08/09',
        '2026-08-09T00:00:00Z',
        ' 2026-08-09',
        '2026-08-09 ',
      ]) {
        expect(
          () => MemoryDate.parse(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });

    test('shouldRejectImpossibleParsedDate', () {
      expect(
        () => MemoryDate.parse('2026-02-30'),
        throwsA(argumentErrorWithMessage('day must be valid for year and month')),
      );
    });

    test('shouldCompareChronologically', () {
      final earlier = MemoryDate(year: 2024, month: 5, day: 18);
      final laterSameYear = MemoryDate(year: 2024, month: 8, day: 3);
      final laterYear = MemoryDate(year: 2025, month: 1, day: 1);

      expect(earlier.compareTo(laterSameYear), isNegative);
      expect(laterSameYear.compareTo(earlier), isPositive);
      expect(laterYear.compareTo(laterSameYear), isPositive);
      expect(earlier.compareTo(MemoryDate(year: 2024, month: 5, day: 18)), 0);
    });

    test('shouldCompareDatesByValue', () {
      final first = MemoryDate(year: 2026, month: 8, day: 9);
      final second = MemoryDate(year: 2026, month: 8, day: 9);
      final different = MemoryDate(year: 2026, month: 8, day: 10);

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldNotDependOnTimezoneForDateOnlyRoundTrip', () {
      final date = MemoryDate.parse('2026-08-09');

      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 9);
      expect(date.toIso8601Date(), '2026-08-09');
    });

    test('shouldUseSafeToString', () {
      final date = MemoryDate.parse('2035-12-17');

      expect(date.toString(), 'MemoryDate');
      expect(date.toString(), isNot(contains('2035')));
      expect(date.toString(), isNot(contains('12')));
      expect(date.toString(), isNot(contains('17')));
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
