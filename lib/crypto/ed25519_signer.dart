// ration_safe_mobile_app/lib/crypto/ed25519_signer.dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'canonical_json.dart';
import 'hash_utils.dart';

class Ed25519Service {
  final Ed25519 _algorithm = Ed25519();
  
  // Hardened hardware-backed secure storage options
  static const _androidOptions = AndroidOptions(
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );
  
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  static const String _privKeyStorageKey = 'graintrust_node_private_key_hex';
  static const String _pubKeyStorageKey = 'graintrust_node_public_key_hex';

  /// Securely zeroes out sensitive byte buffers in memory to prevent RAM scraping.
  void _zeroize(List<int> bytes) {
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

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
    List<int>? privBytes;
    try {
      privBytes = await keyPair.extractPrivateKeyBytes();
      final pubKey = await keyPair.extractPublicKey();

      final privHex = bytesToHex(privBytes);
      final pubHex = bytesToHex(pubKey.bytes);

      await _storage.write(key: _privKeyStorageKey, value: privHex);
      await _storage.write(key: _pubKeyStorageKey, value: pubHex);

      return {
        'privateKeyHex': privHex,
        'publicKeyHex': pubHex,
      };
    } finally {
      if (privBytes != null) {
        _zeroize(privBytes);
      }
    }
  }

  /// Signs an arbitrary JSON payload using canonical JSON serialization and Ed25519.
  /// Zeroizes the raw seed bytes from RAM immediately upon signature creation.
  Future<String> signCanonicalPayload(
    Map<String, dynamic> payload,
    String privateKeyHex,
  ) async {
    final canonicalString = canonicalJson(payload);
    final messageBytes = utf8.encode(canonicalString);

    final privBytes = hexToBytes(privateKeyHex);
    try {
      final keyPair = await _algorithm.newKeyPairFromSeed(privBytes.sublist(0, 32));

      final signature = await _algorithm.sign(
        messageBytes,
        keyPair: keyPair,
      );

      return bytesToHex(signature.bytes);
    } finally {
      _zeroize(privBytes);
    }
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
