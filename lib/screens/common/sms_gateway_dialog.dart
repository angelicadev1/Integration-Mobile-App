import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/sms_service.dart';

class SmsGatewayDialog extends StatefulWidget {
  const SmsGatewayDialog({super.key});

  @override
  State<SmsGatewayDialog> createState() => _SmsGatewayDialogState();
}

class _SmsGatewayDialogState extends State<SmsGatewayDialog> {
  final SmsService _smsService = SmsService();
  final BankingRepository _repo = BankingRepository();

  late SmsProvider _selectedProvider;
  late TextEditingController _phoneController;
  late TextEditingController _semaphoreKeyController;
  late TextEditingController _semaphoreSenderController;
  late TextEditingController _twilioSidController;
  late TextEditingController _twilioTokenController;
  late TextEditingController _twilioFromController;
  late TextEditingController _webhookUrlController;

  bool _isTesting = false;
  String? _testResultStatus;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = _smsService.provider;
    _phoneController = TextEditingController(
      text: _repo.customContactPhoneOverride ?? '+63 917 123 4567',
    );
    _semaphoreKeyController = TextEditingController(text: _smsService.semaphoreApiKey);
    _semaphoreSenderController = TextEditingController(text: _smsService.semaphoreSenderName);
    _twilioSidController = TextEditingController(text: _smsService.twilioAccountSid);
    _twilioTokenController = TextEditingController(text: _smsService.twilioAuthToken);
    _twilioFromController = TextEditingController(text: _smsService.twilioFromNumber);
    _webhookUrlController = TextEditingController(text: _smsService.customWebhookUrl);

    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    final phone = await _repo.getRegisteredRawPhone();
    if (mounted && (_repo.customContactPhoneOverride == null || _repo.customContactPhoneOverride!.isEmpty)) {
      setState(() {
        _phoneController.text = phone;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _semaphoreKeyController.dispose();
    _semaphoreSenderController.dispose();
    _twilioSidController.dispose();
    _twilioTokenController.dispose();
    _twilioFromController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  void _saveConfiguration() {
    _smsService.configure(
      provider: _selectedProvider,
      semaphoreApiKey: _semaphoreKeyController.text.trim(),
      semaphoreSenderName: _semaphoreSenderController.text.trim(),
      twilioAccountSid: _twilioSidController.text.trim(),
      twilioAuthToken: _twilioTokenController.text.trim(),
      twilioFromNumber: _twilioFromController.text.trim(),
      customWebhookUrl: _webhookUrlController.text.trim(),
    );

    if (_phoneController.text.trim().isNotEmpty) {
      _repo.setContactPhoneOverride(_phoneController.text.trim());
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SMS Gateway updated: ${_selectedProvider.name.toUpperCase()} active.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendTestSms() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _testResultStatus = 'Please enter a valid phone number.';
        _testSuccess = false;
      });
      return;
    }

    // Apply config first
    _smsService.configure(
      provider: _selectedProvider,
      semaphoreApiKey: _semaphoreKeyController.text.trim(),
      semaphoreSenderName: _semaphoreSenderController.text.trim(),
      twilioAccountSid: _twilioSidController.text.trim(),
      twilioAuthToken: _twilioTokenController.text.trim(),
      twilioFromNumber: _twilioFromController.text.trim(),
      customWebhookUrl: _webhookUrlController.text.trim(),
    );

    setState(() {
      _isTesting = true;
      _testResultStatus = null;
    });

    final testCode = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
    final result = await _smsService.sendOtpSms(
      recipientPhone: phone,
      otpCode: testCode,
      purpose: 'Live Real-Time 2FA Gateway Verification',
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = result.isSuccess;
        _testResultStatus = result.statusMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sms_outlined, color: Colors.indigo.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS & 2FA Gateway Settings',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Configure real-time SMS dispatch to user phone',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Target Mobile Number
            const Text(
              'Recipient Mobile Number',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g. +63 917 123 4567 or 09171234567',
                prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your actual mobile number to receive live OTPs directly on your phone.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Provider Selector
            const Text(
              'Active SMS Provider',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SmsProvider>(
              initialValue: _selectedProvider,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(
                  value: SmsProvider.semaphore,
                  child: Text('Semaphore (Philippines - Globe/Smart/DITO)'),
                ),
                DropdownMenuItem(
                  value: SmsProvider.twilio,
                  child: Text('Twilio SMS API (Worldwide)'),
                ),
                DropdownMenuItem(
                  value: SmsProvider.customWebhook,
                  child: Text('Custom HTTP Webhook / Relay'),
                ),
                DropdownMenuItem(
                  value: SmsProvider.simulated,
                  child: Text('Simulated Local SMS (Offline / In-App)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedProvider = val);
              },
            ),
            const SizedBox(height: 16),

            // Provider Specific Inputs
            if (_selectedProvider == SmsProvider.semaphore) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cell_tower, color: Colors.blue.shade800, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Semaphore Philippine SMS Gateway',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Direct cellular gateway to Philippine networks (Globe, TM, Smart, TNT, DITO). Uses api.semaphore.co.',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _semaphoreKeyController,
                      decoration: InputDecoration(
                        labelText: 'Semaphore API Key',
                        hintText: 'Enter your Semaphore API key',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _semaphoreSenderController,
                      decoration: InputDecoration(
                        labelText: 'Sender Name (Optional, default: SEMAPHORE)',
                        hintText: 'SEMAPHORE',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedProvider == SmsProvider.twilio) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Twilio SMS Gateway (Worldwide)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _twilioSidController,
                      decoration: InputDecoration(
                        labelText: 'Twilio Account SID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _twilioTokenController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Twilio Auth Token',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _twilioFromController,
                      decoration: InputDecoration(
                        labelText: 'Twilio From Number (e.g. +1234567890)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedProvider == SmsProvider.customWebhook) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom HTTP Webhook Relay',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dispatches JSON POST payload with {recipient, message, otpCode} to your backend SMS relay.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _webhookUrlController,
                      decoration: InputDecoration(
                        labelText: 'Webhook URL (e.g. https://relay.example.com/sms)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_bolt_outlined, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulated Mode: Displays OTP in-app via notification banners and auto-fill buttons. Zero external telco balance required.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Test Result Feedback Banner
            if (_testResultStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _testSuccess ? Colors.green.shade300 : Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(_testSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _testSuccess ? Colors.green.shade800 : Colors.red.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResultStatus!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _testSuccess ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _sendTestSms,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_to_mobile, size: 16),
                    label: const Text('Test SMS', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveConfiguration,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.indigo.shade800,
                    ),
                    child: const Text('Save & Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
