import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/banking_repository.dart';
import '../../core/sms_service.dart';
import '../../models/transaction_model.dart';

class TransactionOtpDialog extends StatefulWidget {
  final String transactionTypeLabel;
  final String purpose;
  final String sourceAccountId;
  final String? counterpartyAccountId;
  final double amount;
  final String currencyCode;
  final String maskedPhone;
  final String initialOtp;
  final Future<TransactionModel> Function() onConfirm;

  const TransactionOtpDialog({
    super.key,
    required this.transactionTypeLabel,
    required this.purpose,
    required this.sourceAccountId,
    this.counterpartyAccountId,
    required this.amount,
    required this.currencyCode,
    required this.maskedPhone,
    required this.initialOtp,
    required this.onConfirm,
  });

  @override
  State<TransactionOtpDialog> createState() => _TransactionOtpDialogState();
}

class _TransactionOtpDialogState extends State<TransactionOtpDialog> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _currentOtp;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _showSmsBanner = true;

  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
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

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _autoFillOtp(String code) {
    if (code.length == 6) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = code[i];
      }
      _focusNodes[5].requestFocus();
      _handleConfirm();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    final repo = BankingRepository();
    final newCode = await repo.sendRealTimeTransactionOtp(purpose: widget.purpose);
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

    final statusMsg = SmsService().lastResult?.statusMessage ?? 'A fresh transaction authorization OTP was sent via SMS.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(statusMsg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleConfirm() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the authorization code.');
      return;
    }

    if (code != _currentOtp) {
      setState(() => _errorMessage = 'Invalid transaction authorization OTP. Verification failed.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final txn = await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(txn);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedAmount = AppConstants.formatCurrency(widget.amount, widget.currencyCode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Simulated Incoming SMS Banner
            if (_showSmsBanner)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sms, color: Colors.white, size: 12),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'SMS • CapstoneBank (2882)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showSmsBanner = false),
                          child: const Icon(Icons.close, color: Colors.white54, size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Authorize ${widget.transactionTypeLabel} of $formattedAmount with OTP: $_currentOtp. Valid for 5 minutes.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () => _autoFillOtp(_currentOtp),
                        icon: const Icon(Icons.touch_app, size: 14, color: Colors.amberAccent),
                        label: Text(
                          'Auto-Fill: $_currentOtp',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Dialog Header Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_clock_outlined, color: Colors.indigo.shade800, size: 32),
            ),
            const SizedBox(height: 12),

            Text(
              'Authorize ${widget.transactionTypeLabel}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Before this transaction is posted to the core ledger, verify the OTP sent to your registered number:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              widget.maskedPhone,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
            ),
            if (SmsService().lastResult != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SmsService().lastResult!.isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SmsService().lastResult!.isSuccess ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SmsService().lastResult!.isSuccess ? Icons.check_circle_outline : Icons.info_outline,
                      size: 12,
                      color: SmsService().lastResult!.isSuccess ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        SmsService().lastResult!.statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: SmsService().lastResult!.isSuccess ? Colors.green.shade900 : Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Transaction Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        formattedAmount,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Source Account:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        widget.sourceAccountId,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (widget.counterpartyAccountId != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recipient Account:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          widget.counterpartyAccountId!,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Banner
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

            // 6-Digit OTP Cells
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 42,
                  height: 48,
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.indigo.shade800, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        if (index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else {
                          _focusNodes[index].unfocus();
                          _handleConfirm();
                        }
                      } else if (val.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Resend Code Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't get the SMS? ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                if (_resendCountdown > 0)
                  Text(
                    'Resend in ${_resendCountdown}s',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  )
                else
                  GestureDetector(
                    onTap: _resendOtp,
                    child: Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Actions: Confirm & Cancel
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _handleConfirm,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.indigo.shade800,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Confirm Post'),
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
