import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';

void main() {
  group('MemoryUpdateField', () {
    test('shouldRepresentNotProvided', () {
      const field = MemoryUpdateField<String>.notProvided();

      expect(field.isProvided, isFalse);
      expect(field.value, isNull);
    });

    test('shouldRepresentProvidedNonNullValue', () {
      const field = MemoryUpdateField<String>.provided('Updated title');

      expect(field.isProvided, isTrue);
      expect(field.value, 'Updated title');
    });

    test('shouldRepresentProvidedNull', () {
      const field = MemoryUpdateField<String?>.provided(null);

      expect(field.isProvided, isTrue);
      expect(field.value, isNull);
    });

    test('shouldSupportMemoryDateAndLocationValues', () {
      final date = MemoryDate(year: 2026, month: 8, day: 9);
      final location = MemoryLocation(latitude: 41.715123, longitude: 44.827456);

      final dateField = MemoryUpdateField<MemoryDate>.provided(date);
      final locationField = MemoryUpdateField<MemoryLocation>.provided(location);

      expect(dateField.value, date);
      expect(locationField.value, location);
    });

    test('shouldDistinguishNotProvidedProvidedNullAndProvidedValue', () {
      const notProvided = MemoryUpdateField<String?>.notProvided();
      const providedNull = MemoryUpdateField<String?>.provided(null);
      const providedValue = MemoryUpdateField<String?>.provided('value');

      expect(notProvided, isNot(providedNull));
      expect(providedNull, isNot(providedValue));
      expect(notProvided, isNot(providedValue));
    });

    test('shouldCompareFieldsByValue', () {
      expect(
        const MemoryUpdateField<String>.provided('Updated title'),
        const MemoryUpdateField<String>.provided('Updated title'),
      );
      expect(
        const MemoryUpdateField<String?>.provided(null),
        const MemoryUpdateField<String?>.provided(null),
      );
      expect(
        const MemoryUpdateField<String>.notProvided(),
        const MemoryUpdateField<String>.notProvided(),
      );
      expect(
        const MemoryUpdateField<String>.provided('Updated title').hashCode,
        const MemoryUpdateField<String>.provided('Updated title').hashCode,
      );
    });

    test('shouldUseSafeToString', () {
      const field = MemoryUpdateField<String>.provided('SECRET TITLE');

      expect(field.toString(), 'MemoryUpdateField[provided]');
      expect(field.toString(), isNot(contains('SECRET TITLE')));
      expect(
        const MemoryUpdateField<String>.notProvided().toString(),
        'MemoryUpdateField[notProvided]',
      );
    });
  });
}
