import 'package:fabric_flutter/helper/agent/agent_audit.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentAuditRedactor', () {
    group('redact', () {
      test('should summarize values without exposing them', () {
        // Arrange
        const redactor = AgentAuditRedactor();
        final params = <String, dynamic>{
          'email': 'agent@example.com',
          'count': 3,
          'active': true,
          'tags': ['a', 'b'],
          'nested': <String, dynamic>{'a': 1},
          'missing': null,
        };

        // Act
        final summary = redactor.redact(params);

        // Assert
        expect(summary['email'], '<string:17>');
        expect(summary['count'], '<num>');
        expect(summary['active'], '<bool>');
        expect(summary['tags'], '<list:2>');
        expect(summary['nested'], '<map:1>');
        expect(summary['missing'], '<null>');
        expect(summary.values.join(), isNot(contains('agent@example.com')));
      });

      test('should fully redact credential shaped keys', () {
        // Arrange
        const redactor = AgentAuditRedactor();
        final params = <String, dynamic>{
          'auth': 'Bearer super-secret-token',
          'access_token': 'super-secret-token',
          'accessToken': 'super-secret-token',
          'Refresh-Token': 'super-secret-token',
          'password': 'hunter2',
          'apiKey': 'k',
        };

        // Act
        final summary = redactor.redact(params);

        // Assert
        for (final value in summary.values) {
          expect(value, AgentAuditRedactor.redacted);
        }
        expect(summary.values.join(), isNot(contains('super-secret-token')));
        expect(summary.values.join(), isNot(contains('hunter2')));
      });

      test('should never leak the length of a credential', () {
        // Arrange
        const redactor = AgentAuditRedactor();

        // Act
        final summary = redactor.redact(<String, dynamic>{'token': 'abcdef'});

        // Assert
        expect(summary['token'], '<redacted>');
        expect(summary['token'], isNot(contains('6')));
      });

      test('should return an empty summary for null or empty params', () {
        // Arrange
        const redactor = AgentAuditRedactor();

        // Act & Assert
        expect(redactor.redact(null), isEmpty);
        expect(redactor.redact(<String, dynamic>{}), isEmpty);
      });

      test('should honor a custom sensitive key set', () {
        // Arrange
        const redactor = AgentAuditRedactor(sensitiveKeys: {'orderid'});

        // Act
        final summary = redactor.redact(<String, dynamic>{
          'orderId': '12345',
          'token': 'abc',
        });

        // Assert
        expect(summary['orderId'], AgentAuditRedactor.redacted);
        expect(summary['token'], '<string:3>');
      });
    });

    group('describe', () {
      test('should classify an unknown type by its runtime type', () {
        // Arrange
        const redactor = AgentAuditRedactor();

        // Act
        final description = redactor.describe(DateTime.utc(2030));

        // Assert
        expect(description, '<DateTime>');
      });
    });
  });

  group('AgentAuditLog', () {
    group('record', () {
      test('should forward the record to the sink', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final log = AgentAuditLog(sink: records.add, debugLog: false);
        final entry = AgentAuditRecord(
          timestamp: DateTime.utc(2030),
          requestId: '1',
          principalId: 'user-1',
          commandId: 'tap',
          outcome: AgentAuditOutcome.success,
          durationMs: 1,
        );

        // Act
        await log.record(entry);

        // Assert
        expect(records.single.commandId, 'tap');
      });

      test('should swallow a failing sink', () async {
        // Arrange
        final log = AgentAuditLog(
          sink: (record) => throw StateError('sink down'),
          debugLog: false,
        );
        final entry = AgentAuditRecord(
          timestamp: DateTime.utc(2030),
          requestId: '1',
          principalId: 'user-1',
          commandId: 'tap',
          outcome: AgentAuditOutcome.success,
          durationMs: 1,
        );

        // Act & Assert
        await expectLater(log.record(entry), completes);
      });

      test('should do nothing when no sink is configured', () async {
        // Arrange
        const log = AgentAuditLog(debugLog: false);
        final entry = AgentAuditRecord(
          timestamp: DateTime.utc(2030),
          requestId: '1',
          principalId: 'user-1',
          commandId: 'tap',
          outcome: AgentAuditOutcome.success,
          durationMs: 1,
        );

        // Act & Assert
        await expectLater(log.record(entry), completes);
      });
    });
  });
}
