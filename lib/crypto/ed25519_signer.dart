// ration_safe_mobile_app/lib/crypto/ed25519_signer.dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'canonical_json.dart';
import 'hash_utils.dart';

class Ed25519Service {
  final Ed25519 _algorithm = Ed25519();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _privKeyStorageKey = 'graintrust_node_private_key_hex';
  static const String _pubKeyStorageKey = 'graintrust_node_public_key_hex';

  /// Retrieves or generates the durable Ed25519 key pair for this terminal.
  Future<Map<String, String>> getOrCreateNodeKeyPair() async {
    final existingPriv = await _storage.read(key: _privKeyStorageKey);
    final existingPub = await _storage.read(key: _pubKeyStorageKey);

    if (existingPriv != null && existingPub != null) {
      return {
        'privateKeyHex': existingPriv,
        'publicKeyHex': existingPub,
      };
    }

    // Generate fresh keypair
    final keyPair = await _algorithm.newKeyPair();
    final privBytes = await keyPair.extractPrivateKeyBytes();
    final pubKey = await keyPair.extractPublicKey();

    final privHex = bytesToHex(privBytes);
    final pubHex = bytesToHex(pubKey.bytes);

    await _storage.write(key: _privKeyStorageKey, value: privHex);
    await _storage.write(key: _pubKeyStorageKey, value: pubHex);

    return {
      'privateKeyHex': privHex,
      'publicKeyHex': pubHex,
    };
  }

  /// Signs an arbitrary JSON payload using canonical JSON serialization and Ed25519.
  Future<String> signCanonicalPayload(
    Map<String, dynamic> payload,
    String privateKeyHex,
  ) async {
    final canonicalString = canonicalJson(payload);
    final messageBytes = utf8.encode(canonicalString);

    final privBytes = hexToBytes(privateKeyHex);
    final keyPair = await _algorithm.newKeyPairFromSeed(privBytes.sublist(0, 32));

    final signature = await _algorithm.sign(
      messageBytes,
      keyPair: keyPair,
    );

    return bytesToHex(signature.bytes);
  }

  /// Verifies an Ed25519 signature against the canonical payload.
  Future<bool> verifyCanonicalPayload(
    Map<String, dynamic> payload,
    String signatureHex,
    String publicKeyHex,
  ) async {
    try {
      final canonicalString = canonicalJson(payload);
      final messageBytes = utf8.encode(canonicalString);
      final signatureBytes = hexToBytes(signatureHex);
      final pubBytes = hexToBytes(publicKeyHex);

      final pubKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: pubKey);

      return await _algorithm.verify(
        messageBytes,
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }
}
