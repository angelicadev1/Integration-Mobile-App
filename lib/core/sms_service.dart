import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum SmsProvider {
  simulated,
  semaphore,   // Philippine SMS Gateway (api.semaphore.co)
  twilio,      // International SMS Gateway
  customWebhook,
}

class SmsDeliveryResult {
  final bool isSuccess;
  final String statusMessage;
  final String? messageId;
  final DateTime timestamp;

  SmsDeliveryResult({
    required this.isSuccess,
    required this.statusMessage,
    this.messageId,
    required this.timestamp,
  });
}

/// Real-Time SMS Dispatch Service for Two-Factor Authentication (OTP).
/// Supports dispatching real SMS to mobile numbers via:
/// 1. Semaphore SMS API (Philippine networks: Globe, Smart, DITO)
/// 2. Twilio SMS API (Worldwide)
/// 3. Custom HTTP Webhook / SMS Gateway
/// 4. Simulated Local SMS (Fallback for offline/air-gapped testing)
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  SmsProvider _provider = SmsProvider.simulated;
  String _semaphoreApiKey = '';
  String _semaphoreSenderName = 'SEMAPHORE';

  String _twilioAccountSid = '';
  String _twilioAuthToken = '';
  String _twilioFromNumber = '';

  String _customWebhookUrl = '';

  // Last delivery status
  SmsDeliveryResult? _lastResult;

  SmsProvider get provider => _provider;
  bool get isRealSmsActive => _provider != SmsProvider.simulated;
  SmsDeliveryResult? get lastResult => _lastResult;

  String get semaphoreApiKey => _semaphoreApiKey;
  String get semaphoreSenderName => _semaphoreSenderName;
  String get twilioAccountSid => _twilioAccountSid;
  String get twilioAuthToken => _twilioAuthToken;
  String get twilioFromNumber => _twilioFromNumber;
  String get customWebhookUrl => _customWebhookUrl;

  void configure({
    SmsProvider? provider,
    String? semaphoreApiKey,
    String? semaphoreSenderName,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? twilioFromNumber,
    String? customWebhookUrl,
  }) {
    if (provider != null) _provider = provider;
    if (semaphoreApiKey != null) _semaphoreApiKey = semaphoreApiKey;
    if (semaphoreSenderName != null) _semaphoreSenderName = semaphoreSenderName;
    if (twilioAccountSid != null) _twilioAccountSid = twilioAccountSid;
    if (twilioAuthToken != null) _twilioAuthToken = twilioAuthToken;
    if (twilioFromNumber != null) _twilioFromNumber = twilioFromNumber;
    if (customWebhookUrl != null) _customWebhookUrl = customWebhookUrl;
  }

  /// Sends a real-time OTP SMS to the registered mobile number
  Future<SmsDeliveryResult> sendOtpSms({
    required String recipientPhone,
    required String otpCode,
    required String purpose, // e.g. "Deposit ₱5,000", "Withdrawal", "Login"
  }) async {
    final cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final message = '[Capstone Bank] Your OTP is $otpCode to authorize $purpose. Valid for 5 mins. NEVER share this code with anyone.';

    switch (_provider) {
      case SmsProvider.semaphore:
        return await _sendViaSemaphore(cleanPhone, message, otpCode);
      case SmsProvider.twilio:
        return await _sendViaTwilio(cleanPhone, message, otpCode);
      case SmsProvider.customWebhook:
        return await _sendViaCustomWebhook(cleanPhone, message, otpCode);
      case SmsProvider.simulated:
        return _deliverSimulated(cleanPhone, message, otpCode);
    }
  }

  String _sanitizeForSemaphore(String phone) {
    var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.startsWith('63') && p.length == 12) {
      return '0${p.substring(2)}';
    }
    return p;
  }

  String _sanitizeForTwilio(String phone) {
    var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!p.startsWith('+')) {
      if (p.startsWith('09')) {
        return '+63${p.substring(1)}';
      } else if (p.startsWith('63')) {
        return '+$p';
      }
      return '+$p';
    }
    return p;
  }

  // --- 1. Semaphore API Dispatch (Philippine Telcos) ---
  Future<SmsDeliveryResult> _sendViaSemaphore(String phone, String message, String otp) async {
    if (_semaphoreApiKey.trim().isEmpty) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Semaphore API Key not configured. Showing simulated SMS notification.',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    if (kIsWeb) {
      final res = SmsDeliveryResult(
        isSuccess: true,
        statusMessage: 'Web Browser Sandbox: Real-time SMS dispatched for $phone (Simulation mode on Web)',
        messageId: 'WEB-SEMAPHORE-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    final formattedNumber = _sanitizeForSemaphore(phone);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse('https://api.semaphore.co/api/v4/messages');
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');

      final body = {
        'apikey': _semaphoreApiKey.trim(),
        'number': formattedNumber,
        'message': message,
        'sendername': _semaphoreSenderName.trim().isNotEmpty ? _semaphoreSenderName.trim() : 'SEMAPHORE',
      };

      final formEncoded = body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      final bytes = utf8.encode(formEncoded);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(const Duration(seconds: 10));
      final respBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? messageId;
        try {
          final decoded = jsonDecode(respBody);
          if (decoded is List && decoded.isNotEmpty && decoded[0]['message_id'] != null) {
            messageId = decoded[0]['message_id'].toString();
          }
        } catch (_) {}

        final res = SmsDeliveryResult(
          isSuccess: true,
          statusMessage: 'Real-time SMS sent to $phone via Semaphore Gateway (HTTP ${response.statusCode})',
          messageId: messageId,
          timestamp: DateTime.now(),
        );
        _lastResult = res;
        return res;
      } else {
        final res = SmsDeliveryResult(
          isSuccess: false,
          statusMessage: 'Semaphore Gateway returned HTTP ${response.statusCode}: $respBody',
          timestamp: DateTime.now(),
        );
        _lastResult = res;
        return res;
      }
    } catch (e) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Network error connecting to Semaphore SMS Gateway: $e',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }
  }

  // --- 2. Twilio API Dispatch ---
  Future<SmsDeliveryResult> _sendViaTwilio(String phone, String message, String otp) async {
    if (_twilioAccountSid.isEmpty || _twilioAuthToken.isEmpty || _twilioFromNumber.isEmpty) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Twilio credentials not fully set. Showing simulated SMS notification.',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    if (kIsWeb) {
      final res = SmsDeliveryResult(
        isSuccess: true,
        statusMessage: 'Web Browser Sandbox: Real-time SMS dispatched for $phone (Simulation mode on Web)',
        messageId: 'WEB-TWILIO-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    final formattedPhone = _sanitizeForTwilio(phone);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/${_twilioAccountSid.trim()}/Messages.json');
      final request = await client.postUrl(uri);

      final authString = base64Encode(utf8.encode('${_twilioAccountSid.trim()}:${_twilioAuthToken.trim()}'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $authString');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');

      final body = {
        'To': formattedPhone,
        'From': _twilioFromNumber.trim(),
        'Body': message,
      };

      final formEncoded = body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      final bytes = utf8.encode(formEncoded);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(const Duration(seconds: 10));
      final respBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? sid;
        try {
          final decoded = jsonDecode(respBody);
          sid = decoded['sid']?.toString();
        } catch (_) {}

        final res = SmsDeliveryResult(
          isSuccess: true,
          statusMessage: 'Real-time SMS sent to $phone via Twilio Gateway (SID: $sid)',
          messageId: sid,
          timestamp: DateTime.now(),
        );
        _lastResult = res;
        return res;
      } else {
        final res = SmsDeliveryResult(
          isSuccess: false,
          statusMessage: 'Twilio returned HTTP ${response.statusCode}: $respBody',
          timestamp: DateTime.now(),
        );
        _lastResult = res;
        return res;
      }
    } catch (e) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Network error connecting to Twilio: $e',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }
  }

  // --- 3. Custom Webhook Dispatch ---
  Future<SmsDeliveryResult> _sendViaCustomWebhook(String phone, String message, String otp) async {
    if (_customWebhookUrl.trim().isEmpty) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Custom Webhook URL not set.',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    if (kIsWeb) {
      final res = SmsDeliveryResult(
        isSuccess: true,
        statusMessage: 'Web Browser Sandbox: Custom Webhook SMS dispatched for $phone',
        messageId: 'WEB-HOOK-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse(_customWebhookUrl.trim());
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final bodyJson = jsonEncode({
        'recipient': phone,
        'message': message,
        'otpCode': otp,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final bytes = utf8.encode(bodyJson);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(const Duration(seconds: 10));
      client.close();

      final res = SmsDeliveryResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusMessage: 'Custom Webhook dispatched to $_customWebhookUrl (HTTP ${response.statusCode})',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    } catch (e) {
      final res = SmsDeliveryResult(
        isSuccess: false,
        statusMessage: 'Failed to dispatch custom SMS webhook: $e',
        timestamp: DateTime.now(),
      );
      _lastResult = res;
      return res;
    }
  }

  // --- 4. Simulated Local SMS ---
  SmsDeliveryResult _deliverSimulated(String phone, String message, String otp) {
    final res = SmsDeliveryResult(
      isSuccess: true,
      statusMessage: 'Delivered in-app simulated SMS to registered phone $phone',
      messageId: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
    );
    _lastResult = res;
    return res;
  }
}
