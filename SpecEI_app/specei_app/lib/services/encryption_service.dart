import 'package:cryptography/cryptography.dart';
import '../core/logger.dart';
import 'security_service.dart';

/// Handles Media Encryption (AES-GCM) and Key Wrapping (Envelope Encryption).
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _aes = AesGcm.with256bits();
  final _securityService = SecurityService();

  /// Encrypt raw bytes (media).
  /// Returns [EncryptedMediaEnvelope] containing ciphertext and wrapped key.
  Future<EncryptedMediaEnvelope> encryptData(List<int> data) async {
    try {
      // 1. Generate Ephemeral Symmetric Key (Per-file key)
      final secretKey = await _aes.newSecretKey();
      final nonce = _aes.newNonce();

      // 2. Encrypt Data (AES-256-GCM)
      final secretBox = await _aes.encrypt(
        data,
        secretKey: secretKey,
        nonce: nonce,
      );

      // 3. Wrap (Encrypt) the Symmetric Key using Device Public Key
      // "Sealed Box" / ECIES approach
      final devicePubKey = await _securityService.getDevicePublicKey();

      final wrappedKey = await _wrapKey(secretKey, devicePubKey);

      return EncryptedMediaEnvelope(
        ciphertext: secretBox.cipherText,
        nonce: secretBox.nonce,
        mac: secretBox.mac.bytes,
        wrappedKey: wrappedKey.encryptedKey,
        ephemeralPublicKey: wrappedKey.ephemeralPublicKey,
      );
    } catch (e, stack) {
      AppLogger.error('Encryption Failed', e, stack);
      rethrow;
    }
  }

  /// Decrypt envelope to get raw bytes.
  Future<List<int>> decryptData(EncryptedMediaEnvelope envelope) async {
    try {
      // 1. Unwrap the Symmetric Key
      // This requires the Device PRIVATE Key, so must be done by SecurityService
      final secretKey = await _securityService.unwrapKey(
        envelope.wrappedKey,
        envelope.ephemeralPublicKey,
      );

      if (secretKey == null) {
        throw Exception("Failed to unwrap content key");
      }

      // 2. Decrypt Data
      final secretBox = SecretBox(
        envelope.ciphertext,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      );

      final clearText = await _aes.decrypt(secretBox, secretKey: secretKey);

      return clearText;
    } catch (e, stack) {
      AppLogger.error('Decryption Failed', e, stack);
      rethrow;
    }
  }

  /// Helper to wrap a key using ECIES (X25519 + HKDF + AES)
  /// Returns the encrypted key and the ephemeral public key used to derive shared secret.
  Future<_KeyWrapResult> _wrapKey(
    SecretKey keyToWrap,
    PublicKey receiverPubKey,
  ) async {
    // 1. Generate Ephemeral Key Pair
    final algorithm = X25519();
    final ephemeralKeyPair = await algorithm.newKeyPair();
    final ephemeralPubKey = await ephemeralKeyPair.extractPublicKey();

    // 2. Derive Shared Secret (ECDH)
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: receiverPubKey,
    );

    // 3. Derive Wrapping Key (HKDF)
    // We use the shared secret to generate a key specifically for wrapping
    // Using a KDF ensures good distribution
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final wrappingKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: ephemeralPubKey.bytes, // Bind to ephemeral key
    );

    // 4. Encrypt the target key
    final keyBytes = await keyToWrap.extractBytes();
    final nonce = AesGcm.with256bits().newNonce();

    final encryptedBox = await AesGcm.with256bits().encrypt(
      keyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
    );

    // Pack result: nonce + ciphertext + mac
    // Ideally we structure this better, but for MVP:
    final combined = [
      ...nonce,
      ...encryptedBox.cipherText,
      ...encryptedBox.mac.bytes,
    ];

    return _KeyWrapResult(combined, ephemeralPubKey);
  }
}

/// Data structure for the encrypted blob stored on disk/db
class EncryptedMediaEnvelope {
  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> mac;
  final List<int> wrappedKey; // The AES key encrypted with Device Key
  final PublicKey ephemeralPublicKey; // Needed to derive the unwrapping key

  EncryptedMediaEnvelope({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.wrappedKey,
    required this.ephemeralPublicKey,
  });
}

class _KeyWrapResult {
  final List<int> encryptedKey;
  final PublicKey ephemeralPublicKey;

  _KeyWrapResult(this.encryptedKey, this.ephemeralPublicKey);
}
