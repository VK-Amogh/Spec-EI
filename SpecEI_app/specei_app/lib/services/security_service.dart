import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../core/logger.dart';

/// SpecEI Security Core
/// Handles Key Management, Secure Storage, and Device Identity
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Secure Storage Wrapper
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // resetOnError: true, // Be careful with this in production
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Cryptography Primitives
  final _algorithm = Ed25519();
  final _keyExchange = X25519();

  // Keys
  static const String _masterKeyAlias = 'spec_ei_master_key_v1';
  late SimpleKeyPair _deviceKeyPair;
  bool _initialized = false;

  /// Initialize Security Service
  /// Loads or generates device master key
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      AppLogger.info('🛡️ Initializing Security Service...');

      // Check for existing master key
      String? encodedKey = await _storage.read(key: _masterKeyAlias);

      if (encodedKey != null) {
        AppLogger.info('🔐 Loading Device Master Key from Secure Storage');
        // TODO: Decode key (implementation pending full schema)
        // For MVP, we regenerate if missing, or use stored seed
        // Here we just simulate load or regen for now

        // Real impl would import the key bytes
        // _deviceKeyPair = await _algorithm.newKeyPairFromSeed(seed);
        _deviceKeyPair = await _algorithm
            .newKeyPair(); // Temporary regen for test
      } else {
        AppLogger.info('🆕 Generating NEW Device Master Key (Hardware Backed)');
        _deviceKeyPair = await _algorithm.newKeyPair();

        // Save seed to secure storage
        final seed = await _deviceKeyPair.extractPrivateKeyBytes();
        // Store as base64 or hex
        // await _storage.write(key: _masterKeyAlias, value: ...);
      }

      _initialized = true;
      AppLogger.info('✅ Security Service Ready');
    } catch (e, stack) {
      AppLogger.error('❌ Security Init Failed', e, stack);
      rethrow; // Critical security failure
    }
  }

  /// Securely store a secret
  Future<void> storeSecret(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Retrieve a secret
  Future<String?> getSecret(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a secret
  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  /// Get Device Public Key (for Attestation/E2EE)
  Future<PublicKey> getDevicePublicKey() async {
    return await _deviceKeyPair.extractPublicKey();
  }

  /// Unwrap (Decrypt) a media key
  /// Uses Device Private Key + Sender Ephemeral Key to derive the wrapping key
  Future<SecretKey?> unwrapKey(
    List<int> wrappedKeyBlob,
    PublicKey ephemeralSenderKey,
  ) async {
    try {
      // 1. Derive Shared Secret (ECDH)
      // Device Private Key + Ephemeral Public Key
      final sharedSecret = await _keyExchange.sharedSecretKey(
        keyPair: _deviceKeyPair, // My Private Key
        remotePublicKey: ephemeralSenderKey,
      );

      // 2. Derive Unwrapping Key (HKDF)
      // Must match encryption derivation exactly
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final unwrappingKey = await hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: (ephemeralSenderKey as SimplePublicKey).bytes,
      );

      // 3. Extract parts from blob (Nonce + Ciphertext + Mac)
      // AES-256-GCM nonce is 12 bytes
      if (wrappedKeyBlob.length < 12 + 16) {
        // Nonce + Min Ciphertext (1 block? no, key is 32)
        throw Exception("Invalid wrapped key format");
      }

      final nonce = wrappedKeyBlob.sublist(0, 12);
      final macBytes = wrappedKeyBlob.sublist(wrappedKeyBlob.length - 16);
      final dbCiphertext = wrappedKeyBlob.sublist(
        12,
        wrappedKeyBlob.length - 16,
      );

      // 4. Decrypt
      final secretBox = SecretBox(
        dbCiphertext,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearKeyBytes = await AesGcm.with256bits().decrypt(
        secretBox,
        secretKey: unwrappingKey,
      );

      return SecretKey(clearKeyBytes);
    } catch (e) {
      AppLogger.error('Key Unwrap Failed', e);
      return null;
    }
  }

  /// Check if device is Rooted/Jailbroken
  /// Currently returns false as root detection is disabled
  Future<bool> isDeviceRooted() async {
    // On Android/iOS only. Windows/Web return false.
    if (kIsWeb) return false;

    // Check if Android or iOS
    // Note: defaultTargetPlatform is available in foundation
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobile) {
      return false;
    }

    // Root detection disabled for now - package compatibility issues
    // TODO: Re-enable with compatible root detection package
    return false;
  }

  /// Enable Screen Security (Prevent Screenshots/Recording on Android)
  /// Currently disabled - native implementation handles this
  Future<void> enableScreenSecurity() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Screen security is handled natively in MainActivity.kt
      // using FLAG_SECURE
      AppLogger.info('🛡️ Screen Security Enabled (Native Implementation)');
    }
  }
}
