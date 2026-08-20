import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentAuditRecord', () {
    group('fromJson', () {
      test('should deserialize a successful invocation', () {
        // Arrange
        final json = <String, dynamic>{
          'timestamp': '2030-01-01T00:00:00.000Z',
          'requestId': '1',
          'principalId': 'user-1',
          'commandId': 'archive_order',
          'outcome': 'success',
          'durationMs': 12,
          'params': <String, dynamic>{'orderId': '<string:4>'},
          'transport': 'socket',
        };

        // Act
        final record = AgentAuditRecord.fromJson(json);

        // Assert
        expect(record.principalId, 'user-1');
        expect(record.commandId, 'archive_order');
        expect(record.outcome, AgentAuditOutcome.success);
        expect(record.durationMs, 12);
        expect(record.params, {'orderId': '<string:4>'});
        expect(record.errorCode, isNull);
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final record = AgentAuditRecord.fromJson(null);

        // Assert
        expect(record.requestId, '');
        expect(record.principalId, '');
        expect(record.commandId, '');
        expect(record.outcome, AgentAuditOutcome.failure);
        expect(record.durationMs, 0);
        expect(record.params, isEmpty);
      });
    });

    group('toJson', () {
      test('should round-trip a failed invocation through JSON', () {
        // Arrange
        final original = AgentAuditRecord(
          timestamp: DateTime.utc(2030, 6, 1),
          requestId: '7',
          principalId: 'user-2',
          commandId: 'tap',
          outcome: AgentAuditOutcome.failure,
          durationMs: 3,
          params: const {'id': '<string:6>'},
          errorCode: AgentErrorCode.unauthorized,
          transport: 'in_process',
        );

        // Act
        final restored = AgentAuditRecord.fromJson(
          AgentAuditRecord.fromJson(original.toJson()).toJson(),
        );

        // Assert
        expect(restored.timestamp, DateTime.utc(2030, 6, 1));
        expect(restored.requestId, '7');
        expect(restored.outcome, AgentAuditOutcome.failure);
        expect(restored.errorCode, AgentErrorCode.unauthorized);
        expect(restored.transport, 'in_process');
        expect(restored.params, {'id': '<string:6>'});
      });
    });
  });
}
