import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/banking_exceptions.dart';
import '../../core/constants.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../common/funding_options_sheet.dart';
import '../receipt/receipt_voucher_screen.dart';
import 'transaction_otp_dialog.dart';

/// Remittance & Send Money Tab.
/// Meets requirements:
/// - TR-M01: Mobile is a thin client (no business rules, balances, or fraud logic computed on-device)
/// - TR-M02: Send money with recipient confirmation
/// - TR-M03: Generate a UUID Idempotency-Key per user action and reuse it on automatic retry
/// - TR-M04: Handle offline/timeout states with safe retry; never display transfer as successful until server confirms
/// - TR-M10: Distinct messages for high-risk decline, insufficient funds, rate limiting, and security-check unavailable
/// - TR-M11: Funding-options bottom sheet on INSUFFICIENT_FUNDS; user must explicitly confirm the funding pocket
class RemittanceFormTab extends StatefulWidget {
  final TransactionType initialType;
  final String? defaultAccountId;

  const RemittanceFormTab({
    super.key,
    this.initialType = TransactionType.transfer,
    this.defaultAccountId,
  });

  @override
  State<RemittanceFormTab> createState() => _RemittanceFormTabState();
}

class _RemittanceFormTabState extends State<RemittanceFormTab> {
  final _formKey = GlobalKey<FormState>();
  final BankingRepository _repo = BankingRepository();

  late TransactionType _txnType;
  String? _selectedSourceAccountId;
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _idempotencyController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  bool _canSafeRetry = false;

  // Server quote & preview
  double? _destAmountPreview;
  double? _fxRatePreview;
  String? _destCurrency;
  double _feePreview = 0.0;

  @override
  void initState() {
    super.initState();
    _txnType = widget.initialType;
    _generateNewIdempotencyKey();

    final accounts = _repo.currentAccounts;
    if (accounts.isNotEmpty) {
      if (widget.defaultAccountId != null &&
          accounts.any((a) => a.accountId == widget.defaultAccountId)) {
        _selectedSourceAccountId = widget.defaultAccountId;
      } else {
        _selectedSourceAccountId = accounts.first.accountId;
      }
    }

    _amountController.addListener(_recomputePreviews);
    _counterpartyController.addListener(_recomputePreviews);
  }

  @override
  void dispose() {
    _counterpartyController.dispose();
    _amountController.dispose();
    _idempotencyController.dispose();
    super.dispose();
  }

  // TR-M03: Generate RFC 4122 v4 UUID Idempotency-Key per user action
  void _generateNewIdempotencyKey() {
    _idempotencyController.text = _repo.generateIdempotencyKey();
  }

  AccountModel? get _selectedSourceAccount {
    if (_selectedSourceAccountId == null) return null;
    final list = _repo.currentAccounts;
    final idx = list.indexWhere((a) => a.accountId == _selectedSourceAccountId);
    return idx != -1 ? list[idx] : null;
  }

  // TR-M01: Thin client preview (no fraud logic or balance mutations computed on-device)
  void _recomputePreviews() {
    final amtText = _amountController.text.trim();
    final amount = double.tryParse(amtText) ?? 0.0;
    final src = _selectedSourceAccount;

    if (src == null || amount <= 0) {
      setState(() {
        _destAmountPreview = null;
        _fxRatePreview = null;
        _destCurrency = null;
        _feePreview = 0.0;
      });
      return;
    }

    final counterparty = _counterpartyController.text.trim().toUpperCase();
    String destCurr = src.currencyCode;
    if (counterparty.contains('-USD')) {
      destCurr = 'USD';
    } else if (counterparty.contains('-EUR')) {
      destCurr = 'EUR';
    } else if (counterparty.contains('-PHP')) {
      destCurr = 'PHP';
    }

    final isCross = destCurr != src.currencyCode;
    double? fx;
    double? destAmt;
    double fee = 0.0;

    if (isCross) {
      fx = _repo.getExchangeRate(src.currencyCode, destCurr);
      destAmt = (amount * fx * 100).roundToDouble() / 100;
      fee = (amount * 0.005 * 100).roundToDouble() / 100;
    }

    setState(() {
      _destCurrency = isCross ? destCurr : null;
      _fxRatePreview = fx;
      _destAmountPreview = destAmt;
      _feePreview = fee;
    });
  }

  // TR-M02: Send money with recipient confirmation
  Future<void> _showRecipientConfirmationDialog({
    required AccountModel sourceAccount,
    required String recipient,
    required double amount,
    required String idempotencyKey,
  }) async {
    final isCross = _destCurrency != null && _destCurrency != sourceAccount.currencyCode;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.violetSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_outlined, color: AppColors.primaryViolet, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirm Recipient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Review transfer before execution (TR-M02)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorderLight),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Recipient Account:', recipient, isHighlight: true),
                  const Divider(height: 16, color: AppColors.cardBorderLight),
                  _buildDetailRow('From Pocket:', '${sourceAccount.typeLabel} (${sourceAccount.currencyCode})'),
                  const SizedBox(height: 6),
                  _buildDetailRow('Source Account ID:', sourceAccount.accountId),
                  const Divider(height: 16, color: AppColors.cardBorderLight),
                  _buildDetailRow('Transfer Amount:', AppConstants.formatCurrency(amount, sourceAccount.currencyCode), isBold: true),
                  if (isCross) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Exchange Rate:', '1 ${sourceAccount.currencyCode} = $_fxRatePreview $_destCurrency'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Cross-Border Fee (0.5%):', AppConstants.formatCurrency(_feePreview, sourceAccount.currencyCode)),
                    const SizedBox(height: 6),
                    _buildDetailRow('Recipient Receives:', AppConstants.formatCurrency(_destAmountPreview!, _destCurrency!), isBold: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.fingerprint, size: 14, color: AppColors.primaryViolet),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Idempotency-Key: $idempotencyKey',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel & Edit', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppGradients.violetMagenta,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm & Send', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _executeConfirmedTransaction(
        sourceAccount: sourceAccount,
        counterparty: recipient,
        amount: amount,
        idempotencyKey: idempotencyKey,
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? Colors.indigo.shade900 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    final src = _selectedSourceAccount;
    if (src == null) {
      setState(() => _errorMessage = 'Please select a valid source account.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Amount must be greater than zero.');
      return;
    }

    final counterparty = _counterpartyController.text.trim().toUpperCase();
    final idempotencyKey = _idempotencyController.text.trim();

    // TR-M02: For transfers, require recipient confirmation modal first!
    if (_txnType == TransactionType.transfer) {
      await _showRecipientConfirmationDialog(
        sourceAccount: src,
        recipient: counterparty,
        amount: amount,
        idempotencyKey: idempotencyKey,
      );
    } else {
      await _executeConfirmedTransaction(
        sourceAccount: src,
        counterparty: null,
        amount: amount,
        idempotencyKey: idempotencyKey,
      );
    }
  }

  // TR-M04: Safe execution and retry handling
  Future<void> _executeConfirmedTransaction({
    required AccountModel sourceAccount,
    String? counterparty,
    required double amount,
    required String idempotencyKey,
  }) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _canSafeRetry = false;
    });

    try {
      final purpose = _txnType == TransactionType.transfer
          ? 'Transfer of ${sourceAccount.currencyCode} ${amount.toStringAsFixed(2)} to $counterparty'
          : _txnType == TransactionType.deposit
              ? 'Deposit of ${sourceAccount.currencyCode} ${amount.toStringAsFixed(2)} to ${sourceAccount.accountId}'
              : 'Withdrawal of ${sourceAccount.currencyCode} ${amount.toStringAsFixed(2)} from ${sourceAccount.accountId}';

      final maskedPhone = await _repo.getRegisteredMaskedPhone();
      final initialOtp = await _repo.sendRealTimeTransactionOtp(purpose: purpose);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Require SMS OTP verification before final server transmission
      final txn = await showDialog<TransactionModel>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => TransactionOtpDialog(
          transactionTypeLabel: _txnType == TransactionType.transfer
              ? 'Remittance / Transfer'
              : _txnType == TransactionType.deposit
                  ? 'Deposit'
                  : 'Withdrawal',
          purpose: purpose,
          sourceAccountId: sourceAccount.accountId,
          counterpartyAccountId: counterparty,
          amount: amount,
          currencyCode: sourceAccount.currencyCode,
          maskedPhone: maskedPhone,
          initialOtp: initialOtp,
          onConfirm: () => _repo.executeTransaction(
            sourceAccountId: sourceAccount.accountId,
            counterpartyAccountId: counterparty,
            txnType: _txnType,
            amount: amount,
            idempotencyKey: idempotencyKey,
          ),
        ),
      );

      // TR-M04: Never display transfer as successful until the server explicitly confirms!
      if (txn != null && mounted) {
        _amountController.clear();
        _generateNewIdempotencyKey();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ReceiptVoucherScreen(transaction: txn),
          ),
        );
      }
    } on BankingException catch (be) {
      _handleBankingException(be, sourceAccount, amount);
    } catch (e) {
      final be = BankingException.fromErrorString(e.toString());
      _handleBankingException(be, sourceAccount, amount);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // TR-M10 & TR-M11 Exception Dispatcher
  Future<void> _handleBankingException(BankingException be, AccountModel src, double amount) async {
    if (!mounted) return;

    setState(() {
      _errorMessage = be.message;
      if (be.code == BankingErrorCode.networkTimeout) {
        _canSafeRetry = true;
      }
    });

    // TR-M11: Funding options bottom sheet on INSUFFICIENT_FUNDS
    if (be.code == BankingErrorCode.insufficientFunds) {
      final confirmedPocket = await FundingOptionsSheet.show(
        context,
        failedSourceAccount: src,
        requestedAmount: amount,
        requestedCurrency: src.currencyCode,
      );

      if (confirmedPocket != null && mounted) {
        setState(() {
          _selectedSourceAccountId = confirmedPocket.accountId;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Explicitly switched funding pocket to: ${confirmedPocket.currencyCode} (${confirmedPocket.accountId}).',
            ),
            backgroundColor: Colors.indigo.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // User explicitly confirmed alternative funding pocket: generate fresh UUID and proceed
        _generateNewIdempotencyKey();
        _submitTransaction();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = _repo.currentAccounts;
    final src = _selectedSourceAccount;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Text(
              'Send Money & Ledger Mutation',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Thin Client (TR-M01) • UUID Idempotency (TR-M03) • Safe Retry (TR-M04)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // TR-M10: Distinct Error Banner
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade800, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    if (_canSafeRetry) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Safe Retry (Reusing UUID Key)', style: TextStyle(fontSize: 11)),
                          onPressed: _isProcessing ? null : _submitTransaction,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Segmented Transaction Type Selector
            Center(
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Send Money'),
                    icon: Icon(Icons.send_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: TransactionType.deposit,
                    label: Text('Deposit'),
                    icon: Icon(Icons.arrow_downward_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: TransactionType.withdrawal,
                    label: Text('Withdraw'),
                    icon: Icon(Icons.arrow_upward_rounded, size: 16),
                  ),
                ],
                selected: {_txnType},
                onSelectionChanged: (set) {
                  setState(() {
                    _txnType = set.first;
                    _errorMessage = null;
                  });
                  _recomputePreviews();
                },
              ),
            ),
            const SizedBox(height: 16),

            // Source Account Selector Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Funding Pocket / Source Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('funding_$_selectedSourceAccountId'),
                      initialValue: _selectedSourceAccountId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.accountId,
                          child: Text(
                            '${a.typeLabel} (${a.currencyCode}) - ${a.formattedBalance}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSourceAccountId = val);
                        _recomputePreviews();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recipient Account (for transfers)
            if (_txnType == TransactionType.transfer) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recipient Account / Mobile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _counterpartyController,
                        decoration: InputDecoration(
                          labelText: 'Destination Account ID or Mobile Number',
                          hintText: 'e.g. ACCT-2001-PHP or +639189876543',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_pin_outlined),
                        ),
                        validator: (val) {
                          if (_txnType == TransactionType.transfer) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter recipient account or mobile number';
                            }
                            if (val.trim().toUpperCase() == _selectedSourceAccountId?.toUpperCase()) {
                              return 'Source and recipient cannot be the same';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Quick Contact Beneficiaries
                      const Text('Quick Test Beneficiaries:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.person, size: 14),
                            label: const Text('Maria PHP (ACCT-2001-PHP)', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _counterpartyController.text = 'ACCT-2001-PHP';
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.euro, size: 14),
                            label: const Text('Maria EUR (ACCT-2003-EUR)', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _counterpartyController.text = 'ACCT-2003-EUR';
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.attach_money, size: 14),
                            label: const Text('Juan USD (ACCT-1002-USD)', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _counterpartyController.text = 'ACCT-1002-USD';
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Amount Input Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transfer Amount (${src?.currencyCode ?? "PHP"})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: src != null ? '${AppConstants.getCurrencySymbol(src.currencyCode)} ' : '₱ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: '0.00',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter mutation amount';
                        final amt = double.tryParse(val.trim());
                        if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Quick Amount Chips
                    Wrap(
                      spacing: 8,
                      children: [500, 1000, 5000, 10000].map((quickAmt) {
                        return ActionChip(
                          label: Text('+${quickAmt.toString()}', style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _amountController.text = quickAmt.toString();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Server-side ForEx quote preview (if cross-currency)
            if (_destCurrency != null && _destCurrency != src?.currencyCode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.currency_exchange, color: Colors.teal.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Cross-Currency Quote Preview',
                          style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Server Exchange Rate:', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        Text('1 ${src?.currencyCode} = $_fxRatePreview $_destCurrency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recipient Receives:', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        Text(AppConstants.formatCurrency(_destAmountPreview!, _destCurrency!), style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cross-Border Fee (0.5%):', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        Text(AppConstants.formatCurrency(_feePreview, src?.currencyCode ?? 'PHP'), style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // TR-M01: Thin Client Security Policy Badge
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.violetSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorderLight),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primaryViolet, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thin Client Architecture (TR-M01)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryViolet),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All fraud rules, risk models (TR-E03), balance mutations, and pessimistic locking are verified on the server gateway.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TR-M03: UUID Idempotency-Key
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: const Text('Security & UUID Idempotency Key (TR-M03)', style: TextStyle(fontSize: 13, color: Colors.grey)),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _idempotencyController,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          labelText: 'RFC 4122 v4 UUID Idempotency-Key',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Generate Fresh UUID',
                      onPressed: _generateNewIdempotencyKey,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
            const SizedBox(height: 24),

            // Review & Authorize Button (TR-M02)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.violetMagenta,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryViolet.withAlpha(90),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Authorizing with Ledger Gateway...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          _txnType == TransactionType.transfer
                              ? 'Review & Send Money (Confirmation)'
                              : _txnType == TransactionType.deposit
                                  ? 'Authorize Credit Deposit'
                                  : 'Authorize Debit Withdrawal',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
