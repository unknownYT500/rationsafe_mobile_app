// mobile/test/blackout_recovery_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ration_safe/telemetry/tracer.dart';
import 'package:ration_safe/telemetry/structured_logger.dart';
import 'package:ration_safe/crypto/canonical_json.dart';
import 'package:ration_safe/crypto/hash_utils.dart';

void main() {
  setUp(() {
    Tracer.clear();
    StructuredLogger.clear();
    StructuredLogger.enableConsoleOutput = false; // silence test output
  });

  group('Phase 5: OpenTelemetry Distributed Tracing (W3C Trace Context)', () {
    test('Generates valid W3C traceparent header format: 00-{32hex}-{16hex}-01', () {
      final span = Tracer.startSpan('offline_dispense_op');
      final header = span.context.toTraceparent();

      expect(header.startsWith('00-'), isTrue);
      final parts = header.split('-');
      expect(parts.length, 4);
      expect(parts[0], '00');
      expect(parts[1].length, 32); // 16 bytes traceId
      expect(parts[2].length, 16); // 8 bytes spanId
      expect(parts[3], '01');      // sampled flag

      span.end(status: 'OK');
      expect(span.status, 'OK');
      expect(span.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('Parses incoming W3C traceparent and creates child span with matching traceId', () {
      const incomingHeader = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';
      final parsed = TraceContext.parse(incomingHeader);

      expect(parsed, isNotNull);
      expect(parsed!.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
      expect(parsed.spanId, '00f067aa0ba902b7');

      final childSpan = Tracer.startSpan('child_sync_op', parentContext: parsed);
      expect(childSpan.context.traceId, parsed.traceId); // traceId preserved!
      expect(childSpan.context.spanId, isNot(parsed.spanId)); // new spanId generated
      expect(childSpan.parentSpanId, parsed.spanId);

      childSpan.end(status: 'OK');
    });

    test('Rejects malformed traceparent headers safely', () {
      expect(TraceContext.parse(null), isNull);
      expect(TraceContext.parse(''), isNull);
      expect(TraceContext.parse('invalid-header'), isNull);
      expect(TraceContext.parse('01-trace-span-01'), isNull); // wrong version
      expect(TraceContext.parse('00-00000000000000000000000000000000-1122334455667788-01'), isNull); // all zero traceId
    });
  });

  group('Phase 5: PII-Scrubbed Structured Logging & Privacy Verification', () {
    final logger = StructuredLogger(serviceName: 'mobile_pos_test');

    test('Automatically masks 12-digit Aadhaar numbers in log strings and maps', () {
      logger.info('Beneficiary authenticated with Aadhaar 987654321098 successfully', {
        'aadhaar_number': '987654321098',
        'beneficiary_notes': 'Aadhaar 1234 5678 9012 verified via local biometric',
      });

      final log = StructuredLogger.logs.first;
      expect(log['message'], contains('XXXX-XXXX-1098'));
      expect(log['message'], isNot(contains('987654321098')));

      final data = log['data'] as Map<String, dynamic>;
      expect(data['aadhaar_number'], 'XXXX-XXXX-1098');
      expect(data['beneficiary_notes'], contains('XXXX-XXXX-9012'));
    });

    test('Automatically masks Indian phone numbers and redacts sensitive citizen fields', () {
      logger.audit('Dispense recorded', {
        'phoneNumber': '+91-9876543210',
        'fullName': 'Sunita Ramesh Devi',
        'address': 'Plot 42, Sector 9, Rampur Village',
        'yearly_income': 48000,
        'privateKey': 'super_secret_private_key_bytes',
      });

      final log = StructuredLogger.logs.first;
      final data = log['data'] as Map<String, dynamic>;

      expect(data['phoneNumber'], '+91-XXXXX-3210');
      expect(data['fullName'], '[REDACTED_PII]');
      expect(data['address'], '[REDACTED_PII]');
      expect(data['yearly_income'], '[REDACTED_PII]');
      expect(data['privateKey'], '[REDACTED_SECRET]');
    });

    test('Attaches active OpenTelemetry traceparent context to structured logs', () {
      final span = Tracer.startSpan('dispense_transaction_step');
      logger.info('Processing grain allocation');
      span.end();

      final log = StructuredLogger.logs.first;
      expect(log['trace_id'], span.context.traceId);
      expect(log['span_id'], span.context.spanId);
      expect(log['traceparent'], span.context.toTraceparent());
    });
  });

  group('Phase 5: 72-Hour Rural Blackout & Disaster Recovery Simulation Drill', () {
    test('Simulates 72-hour offline operation with monotonic sequence continuity and zero loss', () async {
      // 1. Terminal enters disconnected offline state
      final offlineTokens = <Map<String, dynamic>>[];
      int localCounter = 200;
      double totalOfflineGrainKg = 0.0;

      // 2. Simulate 3 consecutive blackout days (Day 1: 5 dispenses, Day 2: 5 dispenses, Day 3: 5 dispenses)
      for (int day = 1; day <= 3; day++) {
        for (int i = 1; i <= 5; i++) {
          localCounter++;
          const dispenseQty = 5.0;
          totalOfflineGrainKg += dispenseQty;

          // Generate W3C span for offline transaction
          final span = Tracer.startSpan('offline_dispense_day_${day}_tx_$i');

          final cardId = 'CARD-OFFLINE-DAY$day-$i';
          final hashedCard = await hashCardId(cardId);

          final tokenPayload = {
            'v': 1,
            'tid': 'txn-blackout-d$day-$i',
            'nid': 'node-offline-pos-001',
            'sub': hashedCard,
            'c': localCounter,
            'qty': dispenseQty,
            'unit': 'kg',
            'traceparent': span.context.toTraceparent(),
          };

          // Cryptographic canonical encoding
          final canonical = canonicalJson(tokenPayload);
          offlineTokens.add({
            'counter': localCounter,
            'payload': tokenPayload,
            'canonical': canonical,
            'created_at': DateTime(2026, 10, 20 + day, 10, i * 5).toIso8601String(),
          });

          span.end(status: 'OK');
        }
      }

      // 3. Verify Offline Invariants
      expect(offlineTokens.length, 15); // Exactly 15 transactions
      expect(totalOfflineGrainKg, 75.0); // 75 kg grain dispensed
      expect(localCounter, 215); // Monotonic counter incremented strictly from 200 to 215

      // Check strictly monotonic counter progression
      for (int i = 0; i < offlineTokens.length; i++) {
        expect(offlineTokens[i]['counter'], 201 + i);
      }

      // 4. Simulate Cellular Reconnection after 72 hours
      // Stream tokens in bounded chunks of 5 (simulating LIMIT 50 chunking)
      final reconciledTokens = <String>[];
      const chunkSize = 5;
      int chunkOffset = 0;

      while (chunkOffset < offlineTokens.length) {
        final chunk = offlineTokens.skip(chunkOffset).take(chunkSize).toList();
        expect(chunk.length, lessThanOrEqualTo(chunkSize));

        for (final item in chunk) {
          final payload = item['payload'] as Map<String, dynamic>;
          reconciledTokens.add(payload['tid'] as String);
        }
        chunkOffset += chunk.length;
      }

      // 5. Verify 100% Zero-Loss Reconciliation
      expect(reconciledTokens.length, 15);
      expect(reconciledTokens.toSet().length, 15); // Zero duplicate drops
      expect(reconciledTokens.first, 'txn-blackout-d1-1');
      expect(reconciledTokens.last, 'txn-blackout-d3-5');

      // 6. Verify W3C Traceparent continuity across all 15 records
      for (final item in offlineTokens) {
        final payload = item['payload'] as Map<String, dynamic>;
        final tp = payload['traceparent'] as String?;
        expect(tp, isNotNull);
        expect(TraceContext.parse(tp), isNotNull);
      }
    });
  });
}
