import 'dart:convert';

import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/helper/filter_helper.dart';
import 'package:fabric_flutter/serialized/filter_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the canonical filter set backing the cross-repo golden vector.
///
/// Every entry carries both a non-null operator and a non-null value, so the
/// encoded bytes are stable across the inclusion-rule change and can be handed
/// to the TypeScript decoder as a conformance fixture.
List<FilterData> canonicalFilters() => [
  FilterData(
    id: 'status',
    type: InputDataType.string,
    operator: FilterOperator.equal,
    value: 'active',
    index: 0,
  ),
  FilterData(
    id: 'amount',
    type: InputDataType.int,
    operator: FilterOperator.greaterThan,
    value: 100,
    index: 1,
  ),
  FilterData(
    id: 'created',
    type: InputDataType.date,
    operator: FilterOperator.between,
    value: [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 3, 31)],
    index: 2,
  ),
  FilterData(
    id: 'sort',
    type: InputDataType.string,
    operator: FilterOperator.sort,
    value: ['created', 'desc'],
    index: 3,
  ),
];

/// Golden payload produced by [FilterHelper.encode] for [canonicalFilters].
///
/// Measured from a live encode rather than transcribed from the source, so it
/// is evidence of the wire format instead of a restatement of the intent.
const String canonicalEncoded =
    'W3siaWQiOiJzdGF0dXMiLCJ0eXBlIjoic3RyaW5nIiwib3BlcmF0b3IiOiJlcXVhbCIsInZh'
    'bHVlIjoiYWN0aXZlIiwiaW5kZXgiOjB9LHsiaWQiOiJhbW91bnQiLCJ0eXBlIjoiaW50Iiwi'
    'b3BlcmF0b3IiOiJncmVhdGVyVGhhbiIsInZhbHVlIjoxMDAsImluZGV4IjoxfSx7ImlkIjoi'
    'Y3JlYXRlZCIsInR5cGUiOiJkYXRlIiwib3BlcmF0b3IiOiJiZXR3ZWVuIiwidmFsdWUiOlsi'
    'MjAyNC0wMS0wMVQwMDowMDowMC4wMDBaIiwiMjAyNC0wMy0zMVQwMDowMDowMC4wMDBaIl0s'
    'ImluZGV4IjoyfSx7ImlkIjoic29ydCIsInR5cGUiOiJzdHJpbmciLCJvcGVyYXRvciI6InNv'
    'cnQiLCJ2YWx1ZSI6WyJjcmVhdGVkIiwiZGVzYyJdLCJpbmRleCI6M31d';

/// Golden payload for `FilterHelper.encode(canonicalFilters(), includeSort: false)`.
///
/// Measured from a live encode, like [canonicalEncoded]. This is the fixture a
/// service that receives ordering through its own parameter should validate
/// against: it is [canonicalEncoded] minus the sort row, with the surviving
/// rows keeping their original indices.
const String canonicalEncodedNoSort =
    'W3siaWQiOiJzdGF0dXMiLCJ0eXBlIjoic3RyaW5nIiwib3BlcmF0b3IiOiJlcXVhbCIsInZh'
    'bHVlIjoiYWN0aXZlIiwiaW5kZXgiOjB9LHsiaWQiOiJhbW91bnQiLCJ0eXBlIjoiaW50Iiwi'
    'b3BlcmF0b3IiOiJncmVhdGVyVGhhbiIsInZhbHVlIjoxMDAsImluZGV4IjoxfSx7ImlkIjoi'
    'Y3JlYXRlZCIsInR5cGUiOiJkYXRlIiwib3BlcmF0b3IiOiJiZXR3ZWVuIiwidmFsdWUiOlsi'
    'MjAyNC0wMS0wMVQwMDowMDowMC4wMDBaIiwiMjAyNC0wMy0zMVQwMDowMDowMC4wMDBaIl0s'
    'ImluZGV4IjoyfV0=';

void main() {
  group('FilterHelper.encode', () {
    test('should produce the byte-exact golden payload', () {
      // Arrange
      final filters = canonicalFilters();

      // Act
      final encoded = FilterHelper.encode(filters);

      // Assert — pins the cross-repo wire format. A change here is a breaking
      // change for every decoder, not a refactor.
      expect(encoded, canonicalEncoded);
    });

    test('should include sort directives by default', () {
      // Arrange — the default must not change, or every existing caller's
      // deep-link round-trip silently loses its ordering.
      final filters = canonicalFilters();

      // Act
      final decoded = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(
        decoded.any((e) => e.operator == FilterOperator.sort),
        isTrue,
        reason: 'default encode must keep sort so the UI can restore it',
      );
    });

    test('should produce the byte-exact sort-free golden payload', () {
      // Arrange
      final filters = canonicalFilters();

      // Act
      final encoded = FilterHelper.encode(filters, includeSort: false);

      // Assert — the second cross-repo fixture. Pinned for the same reason as
      // the default vector: a change here breaks a decoder, not a refactor.
      expect(encoded, canonicalEncodedNoSort);
    });

    test('should drop sort rows when includeSort is false', () {
      // Arrange
      final filters = canonicalFilters();

      // Act
      final decoded = FilterHelper.decode(
        FilterHelper.encode(filters, includeSort: false),
      );

      // Assert
      expect(decoded.any((e) => e.operator == FilterOperator.sort), isFalse);
    });

    test('should keep the non-sort rows intact when includeSort is false', () {
      // Arrange — positive control for the drop test above. Without it that
      // assertion would also pass on an encoder that dropped everything.
      final filters = canonicalFilters();

      // Act
      final decoded = FilterHelper.decode(
        FilterHelper.encode(filters, includeSort: false),
      );

      // Assert
      expect(decoded.map((e) => e.id).toList(), [
        'status',
        'amount',
        'created',
      ]);
    });

    test('should preserve original indices when a sort row is dropped', () {
      // Arrange — a sort row in the middle, so renumbering would be visible.
      final filters = [
        FilterData(
          id: 'status',
          type: InputDataType.string,
          operator: FilterOperator.equal,
          value: 'active',
          index: 0,
        ),
        FilterData(
          id: 'sort',
          type: InputDataType.string,
          operator: FilterOperator.sort,
          value: ['created', 'desc'],
          index: 1,
        ),
        FilterData(
          id: 'amount',
          type: InputDataType.int,
          operator: FilterOperator.greaterThan,
          value: 100,
          index: 2,
        ),
      ];

      // Act
      final decoded = FilterHelper.decode(
        FilterHelper.encode(filters, includeSort: false),
      );

      // Assert — indices come from the model, not the list position, so the
      // surviving rows keep 0 and 2 rather than being renumbered to 0 and 1.
      expect(decoded.map((e) => e.index).toList(), [0, 2]);
    });

    test('should keep a real constraint on a field named sort', () {
      // Arrange — capability guard. The exclusion tests the operator alone, so
      // a legitimate filter on a field called `sort` must survive.
      final filters = [
        FilterData(
          id: 'sort',
          type: InputDataType.string,
          operator: FilterOperator.equal,
          value: 'manual',
          index: 0,
        ),
      ];

      // Act
      final decoded = FilterHelper.decode(
        FilterHelper.encode(filters, includeSort: false),
      );

      // Assert
      expect(decoded.length, 1);
      expect(decoded.first.operator, FilterOperator.equal);
    });

    test('should return null when only sort remains and includeSort is '
        'false', () {
      // Arrange
      final filters = [
        FilterData(
          id: 'sort',
          type: InputDataType.string,
          operator: FilterOperator.sort,
          value: ['created', 'desc'],
          index: 0,
        ),
      ];

      // Act
      final encoded = FilterHelper.encode(filters, includeSort: false);

      // Assert — an empty payload must stay omittable rather than encode `[]`.
      expect(encoded, isNull);
    });

    test('should emit exactly the five serialized keys and nothing else', () {
      // Arrange — the security claim is structural: the payload has no slot a
      // table name or SQL fragment could occupy.
      final filters = canonicalFilters();

      // Act
      final encoded = FilterHelper.encode(filters)!;
      final decoded =
          json.decode(utf8.fuse(base64).decode(encoded)) as List<dynamic>;

      // Assert
      for (final entry in decoded) {
        expect((entry as Map<String, dynamic>).keys.toSet(), {
          'id',
          'type',
          'operator',
          'value',
          'index',
        });
      }
    });

    test('should carry no SQL keyword or backtick-quoted identifier', () {
      // Arrange
      final filters = canonicalFilters();

      // Act
      final plain = utf8.fuse(base64).decode(FilterHelper.encode(filters)!);

      // Assert — a denylist is the wrong control for input, but it is a valid
      // assertion about output we fully generate.
      expect(plain, isNot(contains('`')));
      for (final token in ['select ', ' from ', ' where ', '--', ';']) {
        expect(plain.toLowerCase(), isNot(contains(token)));
      }
    });

    test('should return null for an empty filter list', () {
      // Arrange, Act & Assert
      expect(FilterHelper.encode([]), isNull);
    });

    test('should return null when no filter carries an operator', () {
      // Arrange — every entry is an inactive shell.
      final filters = [
        FilterData(id: 'a', operator: null, value: 'x'),
        FilterData(id: 'b', operator: null, value: 'y'),
      ];

      // Act & Assert
      expect(FilterHelper.encode(filters), isNull);
    });

    test('should drop entries that have no operator', () {
      // Arrange — positive control for the two null-returning tests above:
      // proves the list is reachable and that exclusion is per-entry, not a
      // blanket failure.
      final filters = [
        FilterData(id: 'kept', operator: FilterOperator.equal, value: 'yes'),
        FilterData(id: 'noOperator', operator: null, value: 'orphan'),
      ];

      // Act
      final plain = utf8.fuse(base64).decode(FilterHelper.encode(filters)!);

      // Assert
      expect(plain, contains('"id":"kept"'));
      expect(plain, isNot(contains('noOperator')));
    });

    test('should drop entries that have an operator but no value', () {
      // Arrange — the previously encoded shape: an operator alone was enough to
      // be included, which put a constraint-free row on the wire.
      final filters = [
        FilterData(id: 'kept', operator: FilterOperator.equal, value: 'yes'),
        FilterData(id: 'noValue', operator: FilterOperator.equal, value: null),
      ];

      // Act
      final plain = utf8.fuse(base64).decode(FilterHelper.encode(filters)!);

      // Assert
      expect(plain, contains('"id":"kept"'));
      expect(plain, isNot(contains('noValue')));
    });

    test('should drop entries whose value is an empty string', () {
      // Arrange — a field and operator chosen before the user typed anything.
      final filters = [
        FilterData(id: 'kept', operator: FilterOperator.equal, value: 'yes'),
        FilterData(id: 'emptyValue', operator: FilterOperator.equal, value: ''),
      ];

      // Act
      final plain = utf8.fuse(base64).decode(FilterHelper.encode(filters)!);

      // Assert
      expect(plain, contains('"id":"kept"'));
      expect(plain, isNot(contains('emptyValue')));
    });

    test('should drop placeholder any-operator entries', () {
      // Arrange — `any` matches everything, so it constrains nothing.
      final filters = [
        FilterData(id: 'kept', operator: FilterOperator.equal, value: 'yes'),
        FilterData(id: 'anyOp', operator: FilterOperator.any, value: 'ignored'),
      ];

      // Act
      final plain = utf8.fuse(base64).decode(FilterHelper.encode(filters)!);

      // Assert
      expect(plain, contains('"id":"kept"'));
      expect(plain, isNot(contains('anyOp')));
    });

    test('should require both an operator and a value, not either alone', () {
      // Arrange — the conjunction stated as one case: each rejected row fails
      // exactly one half of the rule, so neither half can be dropped silently.
      final filters = [
        FilterData(id: 'both', operator: FilterOperator.equal, value: 'yes'),
        FilterData(id: 'valueOnly', operator: null, value: 'orphan'),
        FilterData(
          id: 'operatorOnly',
          operator: FilterOperator.equal,
          value: null,
        ),
      ];

      // Act
      final restored = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(restored.map((e) => e.id).toList(), ['both']);
    });

    test('should keep falsy but meaningful values such as zero and false', () {
      // Arrange — guards against a truthiness-style check replacing the explicit
      // null/empty test. Zero and false are legitimate constraints.
      final filters = [
        FilterData(id: 'zero', operator: FilterOperator.equal, value: 0),
        FilterData(id: 'flag', operator: FilterOperator.equal, value: false),
      ];

      // Act
      final restored = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(restored.map((e) => e.id).toList(), ['zero', 'flag']);
    });

    test('should round-trip through decode preserving ids and operators', () {
      // Arrange
      final filters = canonicalFilters();

      // Act
      final restored = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(restored.map((e) => e.id).toList(), [
        'status',
        'amount',
        'created',
        'sort',
      ]);
      expect(restored.map((e) => e.operator).toList(), [
        FilterOperator.equal,
        FilterOperator.greaterThan,
        FilterOperator.between,
        FilterOperator.sort,
      ]);
    });
  });

  group('FilterHelper.decode', () {
    test('should return an empty list for a null payload', () {
      // Arrange, Act & Assert
      expect(FilterHelper.decode(null), isEmpty);
    });

    test('should return an empty list for a non-base64 payload', () {
      // Arrange, Act & Assert — must not throw out of a published API.
      expect(FilterHelper.decode('not base64 at all !!!'), isEmpty);
    });

    test('should return an empty list for base64 that is not JSON', () {
      // Arrange
      final payload = utf8.fuse(base64).encode('this is not json');

      // Act & Assert
      expect(FilterHelper.decode(payload), isEmpty);
    });

    test('should return an empty list when the JSON root is not a list', () {
      // Arrange — a JSON object parses cleanly but is the wrong shape.
      final payload = utf8.fuse(base64).encode('{"id":"status"}');

      // Act & Assert
      expect(FilterHelper.decode(payload), isEmpty);
    });

    test('should skip malformed entries instead of discarding the payload', () {
      // Arrange — one good entry beside a primitive and a bad-shaped map.
      final payload = utf8
          .fuse(base64)
          .encode(
            '[{"id":"good","type":"string","operator":"equal",'
            '"value":"v","index":0},"junk",42]',
          );

      // Act
      final restored = FilterHelper.decode(payload);

      // Assert
      expect(restored, hasLength(1));
      expect(restored.first.id, 'good');
    });

    test('should decode a well-formed payload', () {
      // Arrange — positive control: every negative test above would also pass
      // if decode returned an empty list unconditionally.
      // Act
      final restored = FilterHelper.decode(canonicalEncoded);

      // Assert
      expect(restored, hasLength(4));
      expect(restored.first.id, 'status');
    });
  });

  group('FilterHelper.valueFromType', () {
    test('should return the value unchanged when it is null', () {
      // Arrange, Act & Assert
      expect(
        FilterHelper.valueFromType(
          dataType: InputDataType.date,
          sqlQueryType: SQLQueryType.sql,
          value: null,
        ),
        isNull,
      );
    });

    test('should serialize a date value as a quoted UTC yyyy-MM-dd string', () {
      // Arrange
      final date = DateTime.utc(2024, 3, 7, 18, 45);

      // Act
      final result = FilterHelper.valueFromType(
        dataType: InputDataType.date,
        sqlQueryType: SQLQueryType.sql,
        value: date,
      );

      // Assert
      expect(result, '"2024-03-07"');
    });

    test('should drop time-of-day information from the serialized date', () {
      // Arrange — a late-day timestamp must still format to its calendar date.
      final date = DateTime.utc(2024, 12, 31, 23, 59, 59);

      // Act
      final result = FilterHelper.valueFromType(
        dataType: InputDataType.date,
        sqlQueryType: SQLQueryType.sql,
        value: date,
      );

      // Assert
      expect(result, '"2024-12-31"');
    });
  });

  group('FilterHelper sort order round-trip', () {
    /// Builds a single sort filter so each test varies only the sort pair.
    List<FilterData> sortFilters(dynamic field, dynamic order) => [
      FilterData(
        id: 'sort',
        type: InputDataType.string,
        operator: FilterOperator.sort,
        value: [field, order],
        index: 0,
      ),
    ];

    test('should encode a sort filter whose order is a FilterOrder enum', () {
      // Arrange
      final filters = sortFilters('created', FilterOrder.desc);

      // Act
      final encoded = FilterHelper.encode(filters);

      // Assert — a null payload means the whole filter set was discarded and
      // the query would run unfiltered.
      expect(
        encoded,
        isNotNull,
        reason: 'an enum sort order must not discard the encoded payload',
      );
    });

    test('should decode an enum sort order back to its direction name', () {
      // Arrange
      final filters = sortFilters('created', FilterOrder.desc);

      // Act
      final decoded = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(decoded, hasLength(1));
      expect(decoded.first.value, ['created', 'desc']);
    });

    test('should decode a string sort order back to its direction name', () {
      // Arrange — positive control. Proves these assertions can observe a
      // success, so the enum cases above are not passing vacuously.
      final filters = sortFilters('created', 'asc');

      // Act
      final decoded = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(decoded, hasLength(1));
      expect(decoded.first.value, ['created', 'asc']);
    });

    test('should encode an enum sort order identically to its string name', () {
      // Arrange — the wire format must not fork by the caller's argument type.
      final withEnum = sortFilters('created', FilterOrder.desc);
      final withString = sortFilters('created', 'desc');

      // Act
      final encodedEnum = FilterHelper.encode(withEnum);
      final encodedString = FilterHelper.encode(withString);

      // Assert
      expect(encodedEnum, encodedString);
    });

    test('should preserve a dotted sort field alongside an enum order', () {
      // Arrange — the sort field is a document path and must survive intact.
      // Normalizing it the way the order is normalized would truncate it to
      // its last segment.
      final filters = sortFilters('sentiment.text', FilterOrder.asc);

      // Act
      final decoded = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(decoded, hasLength(1));
      expect(decoded.first.value, ['sentiment.text', 'asc']);
    });

    test('should keep other filters when a sort order is an enum', () {
      // Arrange — the user-visible symptom of an unencodable sort value is
      // that every unrelated constraint disappears with it.
      final filters = [
        FilterData(
          id: 'status',
          type: InputDataType.string,
          operator: FilterOperator.equal,
          value: 'active',
          index: 0,
        ),
        ...sortFilters('created', FilterOrder.desc),
      ];

      // Act
      final decoded = FilterHelper.decode(FilterHelper.encode(filters));

      // Assert
      expect(decoded.map((e) => e.id), containsAll(['status', 'sort']));
    });
  });
}
