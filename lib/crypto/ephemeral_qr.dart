// mobile/lib/crypto/ephemeral_qr.dart
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'hash_utils.dart';
import '../models/beneficiary.dart';

/// Structured payload for Dynamic Ephemeral QR code presentation (180-second TTL).
class EphemeralQrPayload {
  final int v; // Protocol version (1)
  final String cid; // Card ID
  final String sub; // Privacy-preserving SHA-256 masked subject
  final int ts; // Issue epoch timestamp (seconds)
  final int exp; // Expiration epoch timestamp (seconds)
  final String nonce; // Cryptographically random 16-byte hex nonce
  final String sig; // Cryptographic signature/HMAC over canonical payload

  EphemeralQrPayload({
    this.v = 1,
    required this.cid,
    required this.sub,
    required this.ts,
    required this.exp,
    required this.nonce,
    required this.sig,
  });

  Map<String, dynamic> toJson() => {
    'v': v,
    'cid': cid,
    'sub': sub,
    'ts': ts,
    'exp': exp,
    'nonce': nonce,
    'sig': sig,
  };

  factory EphemeralQrPayload.fromJson(Map<String, dynamic> json) {
    return EphemeralQrPayload(
      v: (json['v'] as num?)?.toInt() ?? 1,
      cid: json['cid'] as String? ?? '',
      sub: json['sub'] as String? ?? '',
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      nonce: json['nonce'] as String? ?? '',
      sig: json['sig'] as String? ?? '',
    );
  }

  /// Canonical string representation used for signature generation and verification.
  String toCanonicalString() {
    return '$v|$cid|$sub|$ts|$exp|$nonce';
  }
}

/// Verification result for an Ephemeral QR code scan.
class EphemeralQrVerificationResult {
  final bool isValid;
  final String code; // 'OK', 'ERR_QR_EXPIRED', 'ERR_QR_REPLAYED', 'ERR_QR_INVALID_SIGNATURE', 'ERR_QR_MALFORMED'
  final String message;
  final EphemeralQrPayload? payload;

  EphemeralQrVerificationResult({
    required this.isValid,
    required this.code,
    required this.message,
    this.payload,
  });

  factory EphemeralQrVerificationResult.success(EphemeralQrPayload payload) {
    return EphemeralQrVerificationResult(
      isValid: true,
      code: 'OK',
      message: 'Ephemeral QR token verified successfully. Active for ${payload.exp - (DateTime.now().millisecondsSinceEpoch ~/ 1000)}s.',
      payload: payload,
    );
  }

  factory EphemeralQrVerificationResult.failure(String code, String message) {
    return EphemeralQrVerificationResult(
      isValid: false,
      code: code,
      message: message,
    );
  }
}

/// Service governing Dynamic Ephemeral QR generation, signing, and anti-replay verification.
class EphemeralQrService {
  static final _hmac = Hmac.sha256();
  static final _random = Random.secure();

  // Shared master/card secret key for HMAC validation (or derived card key)
  static const String _defaultSharedSecret = 'rationsafe_ephemeral_qr_pds_secret_2026';

  // Anti-Replay Cache: stores seen nonces and their expiration timestamp
  static final Map<String, int> _seenNonces = {};

  /// Generates a cryptographically authenticated Ephemeral QR payload with a 180-second TTL.
  static Future<EphemeralQrPayload> generateToken(
    CardBeneficiary card, {
    int ttlSeconds = 180,
    String? secretKeyOverride,
  }) async {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expSeconds = nowSeconds + ttlSeconds;

    // Generate random 16-byte nonce
    final nonceBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final nonce = bytesToHex(nonceBytes);

    // Compute privacy-preserving masked subject
    final sub = await hashCardId(card.id);

    // Build unsigned canonical payload
    final unsignedCanonical = '1|${card.id}|$sub|$nowSeconds|$expSeconds|$nonce';

    // Sign canonical string with HMAC-SHA256
    final secret = secretKeyOverride ?? _defaultSharedSecret;
    final mac = await _hmac.calculateMac(
      utf8.encode(unsignedCanonical),
      secretKey: SecretKey(utf8.encode(secret)),
    );
    final sig = bytesToHex(mac.bytes);

    return EphemeralQrPayload(
      v: 1,
      cid: card.id,
      sub: sub,
      ts: nowSeconds,
      exp: expSeconds,
      nonce: nonce,
      sig: sig,
    );
  }

  /// Verifies an incoming Ephemeral QR token string against expiration, replay cache, and cryptographic signature.
  static Future<EphemeralQrVerificationResult> verifyToken(
    String rawQrString, {
    int allowedClockSkewSeconds = 30,
    String? secretKeyOverride,
  }) async {
    // 1. JSON Parsing
    Map<String, dynamic> json;
    try {
      json = jsonDecode(rawQrString) as Map<String, dynamic>;
    } catch (_) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_MALFORMED',
        'Invalid QR format: Payload is not valid JSON.',
      );
    }

    final payload = EphemeralQrPayload.fromJson(json);
    if (payload.cid.isEmpty || payload.nonce.isEmpty || payload.sig.isEmpty) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_MALFORMED',
        'Malformed QR: Missing required fields (cid, nonce, sig).',
      );
    }

    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // 2. Expiration Verification
    if (nowSeconds > (payload.exp + allowedClockSkewSeconds)) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_EXPIRED',
        'Ephemeral QR code has expired. Beneficiary must generate a fresh dynamic QR on mobile terminal.',
      );
    }

    // 3. Premature/Future Timestamp Check
    if (payload.ts > (nowSeconds + allowedClockSkewSeconds)) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_CLOCK_SKEW',
        'Invalid token issue time: Timestamp is in the future. Check terminal system clock.',
      );
    }

    // 4. Anti-Replay Nonce Verification
    _pruneExpiredNonces(nowSeconds);
    if (_seenNonces.containsKey(payload.nonce)) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_REPLAYED',
        'SECURITY ALERT: Replay detected! This QR nonce has already been presented. Duplicate usage blocked.',
      );
    }

    // 5. Cryptographic Signature / HMAC Verification
    final unsignedCanonical = payload.toCanonicalString();
    final secret = secretKeyOverride ?? _defaultSharedSecret;
    final expectedMac = await _hmac.calculateMac(
      utf8.encode(unsignedCanonical),
      secretKey: SecretKey(utf8.encode(secret)),
    );
    final expectedSig = bytesToHex(expectedMac.bytes);

    if (payload.sig.toLowerCase() != expectedSig.toLowerCase()) {
      return EphemeralQrVerificationResult.failure(
        'ERR_QR_INVALID_SIGNATURE',
        'Cryptographic validation failed: QR token signature is invalid or has been tampered with.',
      );
    }

    // 6. Record Nonce in Anti-Replay Cache
    _seenNonces[payload.nonce] = payload.exp;

    return EphemeralQrVerificationResult.success(payload);
  }

  /// Calculates remaining seconds before token expires (clamped to 0).
  static int getRemainingSeconds(EphemeralQrPayload payload) {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final remaining = payload.exp - nowSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Prunes nonces whose expiration window has passed to prevent memory bloat.
  static void _pruneExpiredNonces(int currentEpochSeconds) {
    _seenNonces.removeWhere((_, exp) => exp < currentEpochSeconds);
  }

  /// Clears replay cache (useful for automated test reset).
  static void clearReplayCache() {
    _seenNonces.clear();
  }
}
