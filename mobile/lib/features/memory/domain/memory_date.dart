final class MemoryDate implements Comparable<MemoryDate> {
  factory MemoryDate({
    required int year,
    required int month,
    required int day,
  }) {
    _validate(year, month, day);

    return MemoryDate._(
      year: year,
      month: month,
      day: day,
    );
  }

  factory MemoryDate.parse(String value) {
    if (!_datePattern.hasMatch(value)) {
      throw FormatException('Invalid memory date', value);
    }

    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));

    return MemoryDate(
      year: year,
      month: month,
      day: day,
    );
  }

  const MemoryDate._({
    required this.year,
    required this.month,
    required this.day,
  });

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final int year;
  final int month;
  final int day;

  String toIso8601Date() {
    return '${_pad4(year)}-${_pad2(month)}-${_pad2(day)}';
  }

  @override
  int compareTo(MemoryDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }

    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) {
      return monthComparison;
    }

    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryDate &&
            year == other.year &&
            month == other.month &&
            day == other.day;
  }

  @override
  int get hashCode => Object.hash(
        year,
        month,
        day,
      );

  @override
  String toString() => 'MemoryDate';

  static void _validate(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError('year must be between 1 and 9999');
    }

    if (month < 1 || month > 12) {
      throw ArgumentError('month must be between 1 and 12');
    }

    final maxDay = _daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw ArgumentError('day must be valid for year and month');
    }
  }

  static int _daysInMonth(int year, int month) {
    return switch (month) {
      1 || 3 || 5 || 7 || 8 || 10 || 12 => 31,
      4 || 6 || 9 || 11 => 30,
      2 => _isLeapYear(year) ? 29 : 28,
      _ => throw ArgumentError('month must be between 1 and 12'),
    };
  }

  static bool _isLeapYear(int year) {
    return year % 400 == 0 || year % 4 == 0 && year % 100 != 0;
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String _pad4(int value) => value.toString().padLeft(4, '0');
}
