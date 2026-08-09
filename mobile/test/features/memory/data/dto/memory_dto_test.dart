import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/data/dto/memory_dto.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

void main() {
  group('MemoryDto', () {
    test('shouldParseMemory', () {
      final memory = MemoryDto.fromJson(validMemoryJson());

      expect(memory.id, 'memory-id');
      expect(memory.storyId, 'story-id');
      expect(memory.createdBy, 'user-id');
      expect(memory.title, 'First picnic');
      expect(memory.description, 'Near the river');
      expect(memory.placeName, 'Riverside Park');
      expect(memory.latitude, 55.751244);
      expect(memory.longitude, 37.618423);
      expect(memory.eventDate, MemoryDate(year: 2026, month: 8, day: 9));
      expect(memory.createdAt, DateTime.parse('2026-08-09T10:00:00Z'));
      expect(memory.updatedAt, DateTime.parse('2026-08-09T11:00:00Z'));
    });

    test('shouldAllowNullNullableFields', () {
      final memory = MemoryDto.fromJson(
        <String, Object?>{
          ...validMemoryJson(),
          'description': null,
          'placeName': null,
        },
      );

      expect(memory.description, isNull);
      expect(memory.placeName, isNull);
    });

    test('shouldAllowBlankNullableFields', () {
      final memory = MemoryDto.fromJson(
        <String, Object?>{
          ...validMemoryJson(),
          'description': '   ',
          'placeName': '   ',
        },
      );

      expect(memory.description, '   ');
      expect(memory.placeName, '   ');
    });

    test('shouldRejectNonMapMemory', () {
      expectMalformed(() => MemoryDto.fromJson(<Object?>[]));
    });

    test('shouldRejectMissingRequiredField', () {
      final json = validMemoryJson()..remove('storyId');

      expectMalformed(() => MemoryDto.fromJson(json));
    });

    test('shouldRejectWrongRequiredStringType', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'title': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankIdentifier', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'createdBy': '   ',
          },
        ),
      );
    });

    test('shouldRejectBlankTitle', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'title': '   ',
          },
        ),
      );
    });

    test('shouldRejectWrongNullableFieldType', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'placeName': 123,
          },
        ),
      );
    });

    test('shouldRejectWrongCoordinateType', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'latitude': '55.7',
          },
        ),
      );
    });

    test('shouldRejectOutOfRangeCoordinates', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'longitude': 181.0,
          },
        ),
      );
    });

    test('shouldRejectInvalidEventDate', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'eventDate': '2026-02-30',
          },
        ),
      );
    });

    test('shouldRejectInvalidTimestamp', () {
      expectMalformed(
        () => MemoryDto.fromJson(
          <String, Object?>{
            ...validMemoryJson(),
            'updatedAt': 'not-a-date',
          },
        ),
      );
    });

    test('shouldIgnoreUnknownFields', () {
      final memory = MemoryDto.fromJson(
        <String, Object?>{
          ...validMemoryJson(),
          'role': 'OWNER',
          'token': 'secret-token',
        },
      ).toDomain();

      expect(memory.id, 'memory-id');
    });

    test('shouldMapMemoryToUtcDomain', () {
      final memory = MemoryDto.fromJson(
        <String, Object?>{
          ...validMemoryJson(),
          'createdAt': '2026-08-09T13:00:00+03:00',
          'updatedAt': '2026-08-09T14:00:00+03:00',
        },
      ).toDomain();

      expect(
        memory,
        Memory(
          id: 'memory-id',
          storyId: 'story-id',
          createdBy: 'user-id',
          title: 'First picnic',
          description: 'Near the river',
          placeName: 'Riverside Park',
          location: MemoryLocation(
            latitude: 55.751244,
            longitude: 37.618423,
          ),
          eventDate: MemoryDate(year: 2026, month: 8, day: 9),
          createdAt: DateTime.parse('2026-08-09T10:00:00Z'),
          updatedAt: DateTime.parse('2026-08-09T11:00:00Z'),
        ),
      );
      expect(memory.createdAt.isUtc, isTrue);
      expect(memory.updatedAt.isUtc, isTrue);
    });

    test('shouldNotNormalizeTextFields', () {
      final memory = MemoryDto.fromJson(
        <String, Object?>{
          ...validMemoryJson(),
          'id': ' memory-id ',
          'title': ' First picnic ',
          'description': ' Near the river ',
          'placeName': ' Riverside Park ',
        },
      ).toDomain();

      expect(memory.id, ' memory-id ');
      expect(memory.title, ' First picnic ');
      expect(memory.description, ' Near the river ');
      expect(memory.placeName, ' Riverside Park ');
    });

    test('shouldCompareByValue', () {
      expect(MemoryDto.fromJson(validMemoryJson()), MemoryDto.fromJson(
        validMemoryJson(),
      ));
    });

    test('shouldExposeSafeToString', () {
      final memory = MemoryDto.fromJson(validMemoryJson());

      expect(memory.toString(), 'MemoryDto');
      expect(memory.toString(), isNot(contains('memory-id')));
      expect(memory.toString(), isNot(contains('token')));
    });
  });
}

void expectMalformed(Object? Function() action) {
  expect(action, throwsA(isA<FormatException>()));
}

Map<String, Object?> validMemoryJson() {
  return <String, Object?>{
    'id': 'memory-id',
    'storyId': 'story-id',
    'createdBy': 'user-id',
    'title': 'First picnic',
    'description': 'Near the river',
    'placeName': 'Riverside Park',
    'latitude': 55.751244,
    'longitude': 37.618423,
    'eventDate': '2026-08-09',
    'createdAt': '2026-08-09T10:00:00Z',
    'updatedAt': '2026-08-09T11:00:00Z',
  };
}
