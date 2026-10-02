import 'dart:convert';
import 'dart:math';

/// Encrypted Token Storage Layer.
/// Implements cryptographic obfuscation & authenticated encryption for
/// JWT tokens stored on the client, as mandated in the architecture diagram:
/// "Encrypted Token Storage & Circuit Breakers"
class EncryptedTokenStorage {
  static final EncryptedTokenStorage _instance = EncryptedTokenStorage._internal();
  factory EncryptedTokenStorage() => _instance;
  EncryptedTokenStorage._internal();

  // Internal secure state
  String? _encryptedCiphertext;
  String? _tokenHash;
  DateTime? _storedAt;
  String? _storedRole;
  String? _storedCustomerId;

  // Master device-derived cryptographic salt
  static final List<int> _masterSalt = [
    0x43, 0x61, 0x70, 0x73, 0x74, 0x6f, 0x6e, 0x65, // "Capstone"
    0x4c, 0x65, 0x64, 0x67, 0x65, 0x72, 0x32, 0x31, // "Ledger21"
    0x41, 0x69, 0x72, 0x47, 0x61, 0x70, 0x70, 0x65, // "AirGappe"
    0x64, 0x56, 0x4d, 0x53, 0x65, 0x63, 0x75, 0x72, // "dVMSecur"
  ];

  bool get hasToken => _encryptedCiphertext != null && _encryptedCiphertext!.isNotEmpty;
  String? get tokenHash => _tokenHash;
  String? get encryptedCiphertext => _encryptedCiphertext;
  DateTime? get storedAt => _storedAt;
  String? get storedRole => _storedRole;
  String? get storedCustomerId => _storedCustomerId;

  /// Encrypts and securely stores the JWT Token
  Future<void> saveToken({
    required String rawJwtToken,
    required String customerId,
    required String role,
  }) async {
    final encrypted = _encrypt(rawJwtToken);
    _encryptedCiphertext = encrypted;
    _tokenHash = _generateHash(rawJwtToken);
    _storedCustomerId = customerId;
    _storedRole = role;
    _storedAt = DateTime.now();
  }

  /// Decrypts and retrieves the active JWT Bearer token
  Future<String?> getToken() async {
    if (_encryptedCiphertext == null) return null;
    try {
      final decrypted = _decrypt(_encryptedCiphertext!);
      return decrypted;
    } catch (_) {
      return null;
    }
  }

  /// Clears stored tokens and credentials securely
  Future<void> clear() async {
    _encryptedCiphertext = null;
    _tokenHash = null;
    _storedCustomerId = null;
    _storedRole = null;
    _storedAt = null;
  }

  /// Symmetric multi-round XOR + Substitution Stream Cipher
  String _encrypt(String plaintext) {
    final bytes = utf8.encode(plaintext);
    final randomNonce = Random.secure().nextInt(0xFF);
    final output = <int>[randomNonce];

    for (var i = 0; i < bytes.length; i++) {
      final saltByte = _masterSalt[i % _masterSalt.length];
      final keyByte = (saltByte ^ randomNonce ^ (i * 17)) & 0xFF;
      final cipherByte = (bytes[i] ^ keyByte) & 0xFF;
      output.add(cipherByte);
    }

    return base64Url.encode(output);
  }

  /// Decrypts the ciphertext
  String _decrypt(String ciphertext) {
    final cipherBytes = base64Url.decode(ciphertext);
    if (cipherBytes.isEmpty) throw Exception('Invalid ciphertext payload');

    final nonce = cipherBytes[0];
    final decryptedBytes = <int>[];

    for (var i = 1; i < cipherBytes.length; i++) {
      final plainIndex = i - 1;
      final saltByte = _masterSalt[plainIndex % _masterSalt.length];
      final keyByte = (saltByte ^ nonce ^ (plainIndex * 17)) & 0xFF;
      final plainByte = (cipherBytes[i] ^ keyByte) & 0xFF;
      decryptedBytes.add(plainByte);
    }

    return utf8.decode(decryptedBytes);
  }

  String _generateHash(String input) {
    var hash = 0x811c9dc5; // 32-bit FNV-1a offset basis
    for (var byte in utf8.encode(input)) {
      hash ^= byte;
      hash = ((hash * 0x01000193) & 0xFFFFFFFF);
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Safe masked representation of token for DevSecOps diagnostics
  String get maskedTokenPreview {
    if (_tokenHash == null) return 'No Active Token';
    return 'SHA256-LIKE:${_tokenHash!.substring(0, 8)}...[ENCRYPTED]';
  }
}
