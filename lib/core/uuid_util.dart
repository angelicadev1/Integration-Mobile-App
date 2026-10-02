import 'dart:math';

/// Cryptographically secure RFC 4122 Version 4 UUID Generator.
/// Meets requirement TR-M03:
/// "Generate a UUID Idempotency-Key per user action and reuse it on automatic retry"
class UuidUtil {
  static final Random _secureRandom = Random.secure();

  /// Generates a standard RFC 4122 v4 UUID string
  /// Example: 'c4a760a8-dbcf-5254-a0d9-6a4474bd9e1a'
  static String generateV4() {
    final values = List<int>.generate(16, (_) => _secureRandom.nextInt(256));

    // Set version to 4 (0100 in bits 4-7 of time_hi_and_version)
    values[6] = (values[6] & 0x0f) | 0x40;

    // Set variant to RFC 4122 (10 in bits 6-7 of clock_seq_hi_and_reserved)
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();

    return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
        '${hex[4]}${hex[5]}-'
        '${hex[6]}${hex[7]}-'
        '${hex[8]}${hex[9]}-'
        '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
  }

  /// Validates whether a string conforms to UUID v4 format
  static bool isValidUuid(String? uuid) {
    if (uuid == null) return false;
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(uuid);
  }
}
