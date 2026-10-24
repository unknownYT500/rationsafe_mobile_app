// ration_safe_mobile_app/lib/crypto/hash_utils.dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID string for local transactions and entities.
String generateUuidV7() {
  return _uuid.v7();
}

/// Derives a SHA-256 hex hash of card_id to preserve privacy (no PII in signed tokens).
Future<String> hashCardId(String cardId) async {
  final sha256 = Sha256();
  final sink = await sha256.hash(utf8.encode(cardId));
  return sink.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Helper to convert hex string to byte list.
List<int> hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

/// Helper to convert byte list to hex string.
String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
