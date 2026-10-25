import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ration_safe/crypto/ephemeral_qr.dart';
import 'package:ration_safe/data/local_db.dart';
import 'package:ration_safe/models/beneficiary.dart';

void main() {
  group('Phase 3: Exponential Backoff with Jitter Tests', () {
    test('calculateBackoffWithJitter calculates backoff within expected exponential ranges', () {
      for (int i = 0; i < 20; i++) {
        // Attempt 0: 2^0 * 1000 = 1000ms + [0, 999]ms
        final backoff0 = LocalDatabase.calculateBackoffWithJitter(0);
        expect(backoff0.inMilliseconds >= 1000, isTrue);
        expect(backoff0.inMilliseconds < 2000, isTrue);

        // Attempt 1: 2^1 * 1000 = 2000ms + [0, 999]ms
        final backoff1 = LocalDatabase.calculateBackoffWithJitter(1);
        expect(backoff1.inMilliseconds >= 2000, isTrue);
        expect(backoff1.inMilliseconds < 3000, isTrue);

        // Attempt 2: 2^2 * 1000 = 4000ms + [0, 999]ms
        final backoff2 = LocalDatabase.calculateBackoffWithJitter(2);
        expect(backoff2.inMilliseconds >= 4000, isTrue);
        expect(backoff2.inMilliseconds < 5000, isTrue);

        // Attempt 3: 2^3 * 1000 = 8000ms + [0, 999]ms
        final backoff3 = LocalDatabase.calculateBackoffWithJitter(3);
        expect(backoff3.inMilliseconds >= 8000, isTrue);
        expect(backoff3.inMilliseconds < 9000, isTrue);

        // Attempt 10: Max capped at 60000ms + [0, 999]ms
        final backoff10 = LocalDatabase.calculateBackoffWithJitter(10);
        expect(backoff10.inMilliseconds >= 60000, isTrue);
        expect(backoff10.inMilliseconds < 61000, isTrue);
      }
    });
  });

  group('Phase 3: Dynamic Ephemeral QR Protocol Tests', () {
    const mockCard = CardBeneficiary(
      id: 'CARD-AP-HYD-998811',
      personId: 'PERSON-101',
      status: 'ACTIVE',
      issuedAt: '2026-01-01',
      firstName: 'Ramesh',
      lastName: 'Kumar',
      fullName: 'Ramesh Kumar',
      phoneNumber: '9876543210',
      familyCount: 4,
      address: 'Plot 42, Jubilee Hills',
      city: 'Hyderabad',
      state: 'Telangana',
      allocatedQty: 35.0,
      consumedQty: 10.0,
      remainingQty: 25.0,
    );

    setUp(() {
      EphemeralQrService.clearReplayCache();
    });

    test('generates valid ephemeral QR payload with 180s TTL and HMAC signature', () async {
      final payload = await EphemeralQrService.generateToken(
        mockCard,
        ttlSeconds: 180,
      );

      expect(payload.cid, equals('CARD-AP-HYD-998811'));
      expect(payload.v, equals(1));
      expect(payload.sub.length, equals(64)); // SHA-256 masked subject
      expect(payload.nonce.length, equals(32)); // 16 bytes = 32 hex chars
      expect(payload.sig.length, equals(64)); // HMAC-SHA256 = 64 hex chars
      expect(payload.exp - payload.ts, equals(180));

      final jsonStr = jsonEncode(payload.toJson());
      final parsed = EphemeralQrPayload.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(parsed.cid, equals(payload.cid));
      expect(parsed.nonce, equals(payload.nonce));
      expect(parsed.sig, equals(payload.sig));
    });

    test('successfully verifies authentic fresh QR payload', () async {
      final payload = await EphemeralQrService.generateToken(mockCard);
      final rawQr = jsonEncode(payload.toJson());

      final result = await EphemeralQrService.verifyToken(rawQr);
      expect(result.isValid, isTrue);
      expect(result.code, equals('OK'));
      expect(result.payload, isNotNull);
      expect(result.payload!.cid, equals('CARD-AP-HYD-998811'));
    });

    test('rejects tampered signature', () async {
      final payload = await EphemeralQrService.generateToken(mockCard);

      // Tamper signature by changing last char
      final badSig = payload.sig.substring(0, 63) + (payload.sig.endsWith('a') ? 'b' : 'a');
      final tamperedMap = payload.toJson();
      tamperedMap['sig'] = badSig;

      final result = await EphemeralQrService.verifyToken(jsonEncode(tamperedMap));
      expect(result.isValid, isFalse);
      expect(result.code, equals('ERR_QR_INVALID_SIGNATURE'));
    });

    test('rejects tampered beneficiary card ID with original signature', () async {
      final payload = await EphemeralQrService.generateToken(mockCard);

      final tamperedMap = payload.toJson();
      tamperedMap['cid'] = 'CARD-AP-HYD-FORGED01';

      final result = await EphemeralQrService.verifyToken(jsonEncode(tamperedMap));
      expect(result.isValid, isFalse);
      expect(result.code, equals('ERR_QR_INVALID_SIGNATURE'));
    });

    test('rejects expired QR tokens exceeding TTL + clock skew', () async {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final expiredTimestamp = nowSec - 250;
      final expTimestamp = expiredTimestamp + 180; // Expired 70s ago

      final expiredMap = {
        'v': 1,
        'cid': mockCard.id,
        'sub': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'ts': expiredTimestamp,
        'exp': expTimestamp,
        'nonce': '12345678901234567890123456789012',
        'sig': 'dummy_sig_that_should_not_even_reach_hmac_check',
      };

      final result = await EphemeralQrService.verifyToken(
        jsonEncode(expiredMap),
        allowedClockSkewSeconds: 15,
      );
      expect(result.isValid, isFalse);
      expect(result.code, equals('ERR_QR_EXPIRED'));
    });

    test('anti-replay cache strictly rejects replayed nonces within TTL window', () async {
      final payload = await EphemeralQrService.generateToken(mockCard);
      final rawQr = jsonEncode(payload.toJson());

      // First verification: SUCCESS
      final firstCheck = await EphemeralQrService.verifyToken(rawQr);
      expect(firstCheck.isValid, isTrue);

      // Second verification of identical token: REJECTED AS REPLAYED
      final secondCheck = await EphemeralQrService.verifyToken(rawQr);
      expect(secondCheck.isValid, isFalse);
      expect(secondCheck.code, equals('ERR_QR_REPLAYED'));
      expect(secondCheck.message, contains('Replay detected'));
    });
  });
}
