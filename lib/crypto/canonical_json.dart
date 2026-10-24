// ration_safe_mobile_app/lib/crypto/canonical_json.dart
import 'dart:convert';

/// Deterministic JSON serializer (Canonical JSON).
/// Recursively sorts all Map keys alphabetically to guarantee byte-for-byte
/// digest compatibility between TypeScript and Flutter/Dart Ed25519 signers.
String canonicalJson(Object? obj) {
  if (obj == null) {
    return 'null';
  }

  if (obj is num) {
    if (obj is int) {
      return obj.toString();
    }
    // Match JavaScript JSON.stringify for doubles
    if (obj.isFinite && obj == obj.roundToDouble()) {
      return obj.toInt().toString();
    }
    return obj.toString();
  }

  if (obj is bool) {
    return obj ? 'true' : 'false';
  }

  if (obj is String) {
    return jsonEncode(obj);
  }

  if (obj is List) {
    final elements = obj.map((item) => canonicalJson(item)).join(',');
    return '[$elements]';
  }

  if (obj is Map) {
    final sortedKeys = obj.keys.map((k) => k.toString()).toList()..sort();
    final entries = sortedKeys.map((key) {
      final keyJson = jsonEncode(key);
      final valJson = canonicalJson(obj[key]);
      return '$keyJson:$valJson';
    }).join(',');
    return '{$entries}';
  }

  return jsonEncode(obj);
}
