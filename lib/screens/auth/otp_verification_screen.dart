import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/sms_service.dart';
import '../../models/user_session.dart';

class OtpVerificationScreen extends StatefulWidget {
  final UserSession session;
  final String maskedPhone;
  final String generatedOtp;
  final VoidCallback onVerificationSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.session,
    required this.maskedPhone,
    required this.generatedOtp,
    required this.onVerificationSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _currentOtp;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _showSmsBanner = true;

  // Countdown timer for Resend Code
  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.generatedOtp;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  String get _enteredCode {
    return _controllers.map((c) => c.text).join();
  }

  void _autoFillOtp(String code) {
    if (code.length == 6) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = code[i];
      }
      _focusNodes[5].requestFocus();
      _verifyOtp();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    // Generate fresh 6-digit OTP
    final newCode = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
    final repo = BankingRepository();
    final rawPhone = await repo.getRegisteredRawPhone();
    final result = await SmsService().sendOtpSms(
      recipientPhone: rawPhone,
      otpCode: newCode,
      purpose: 'Account Sign In',
    );

    if (!mounted) return;
    setState(() {
      _currentOtp = newCode;
      _errorMessage = null;
      _showSmsBanner = true;
      for (var c in _controllers) {
        c.clear();
      }
    });
    _focusNodes[0].requestFocus();
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.statusMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP.');
      return;
    }

    if (code != _currentOtp) {
      setState(() => _errorMessage = 'Invalid verification code. Please check your SMS and try again.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final repo = BankingRepository();
      await repo.completeLoginWithOtp(widget.session);

      if (mounted) {
        widget.onVerificationSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('2-Step Verification'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Simulated Incoming SMS Notification Banner
              if (_showSmsBanner)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.sms, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'MESSAGES • NOW',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showSmsBanner = false),
                            child: const Icon(Icons.close, color: Colors.white54, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CapstoneBank (2882)',
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your mobile banking OTP is $_currentOtp. Valid for 5 minutes. Do not share this code with anyone.',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _autoFillOtp(_currentOtp),
                          icon: const Icon(Icons.touch_app, size: 16, color: Colors.amberAccent),
                          label: Text(
                            'Auto-Fill Code: $_currentOtp',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Shield Security Graphic
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade200, width: 2),
                ),
                child: Icon(Icons.phone_android_rounded, color: Colors.indigo.shade800, size: 40),
              ),
              const SizedBox(height: 20),

              Text(
                'Enter Verification Code',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: 'We have dispatched a 6-digit one-time password (OTP) via SMS to registered number\n'),
                    TextSpan(
                      text: widget.maskedPhone,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              if (SmsService().lastResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SmsService().lastResult!.isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SmsService().lastResult!.isSuccess ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SmsService().lastResult!.isSuccess ? Icons.check_circle_outline : Icons.info_outline,
                        size: 14,
                        color: SmsService().lastResult!.isSuccess ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          SmsService().lastResult!.statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: SmsService().lastResult!.isSuccess ? Colors.green.shade900 : Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Error Banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // 6-Digit OTP Form Input Cells
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 54,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.indigo.shade800, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                            _verifyOtp();
                          }
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // Verify & Sign In Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.indigo.shade800,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Verify & Access Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              // Resend Code Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive the SMS? ", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    )
                  else
                    GestureDetector(
                      onTap: _resendOtp,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Security notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Capstone Bank fraud prevention: We will never call or message asking for your verification code.',
                        style: TextStyle(fontSize: 11, color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
