import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';
import '../../models/account_model.dart';
import '../../models/quote_model.dart';
import '../receipt/receipt_voucher_screen.dart';

/// Convert Screen with Live Quote Countdown.
/// Meets requirement TR-M11:
/// "Convert screen with live quote countdown"
class ConvertScreen extends StatefulWidget {
  final String? initialSourceAccountId;
  final String? initialTargetAccountId;

  const ConvertScreen({
    super.key,
    this.initialSourceAccountId,
    this.initialTargetAccountId,
  });

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  final BankingRepository _repo = BankingRepository();
  final TextEditingController _amountController = TextEditingController(text: '1000');

  String? _sourceAccountId;
  String? _targetAccountId;
  QuoteModel? _activeQuote;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isLoadingQuote = false;
  bool _isConverting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final accounts = _repo.currentAccounts;
    if (accounts.isNotEmpty) {
      _sourceAccountId = widget.initialSourceAccountId ?? accounts.first.accountId;
      if (accounts.length > 1) {
        _targetAccountId = widget.initialTargetAccountId ?? accounts[1].accountId;
      }
    }
    _amountController.addListener(_onAmountChanged);
    _fetchLiveQuote();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _fetchLiveQuote();
  }

  AccountModel? get _sourceAccount {
    if (_sourceAccountId == null) return null;
    final list = _repo.currentAccounts;
    final idx = list.indexWhere((a) => a.accountId == _sourceAccountId);
    return idx != -1 ? list[idx] : null;
  }

  AccountModel? get _targetAccount {
    if (_targetAccountId == null) return null;
    final list = _repo.currentAccounts;
    final idx = list.indexWhere((a) => a.accountId == _targetAccountId);
    return idx != -1 ? list[idx] : null;
  }

  Future<void> _fetchLiveQuote() async {
    final src = _sourceAccount;
    final dest = _targetAccount;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (src == null || dest == null || amount <= 0 || src.currencyCode == dest.currencyCode) {
      _countdownTimer?.cancel();
      setState(() {
        _activeQuote = null;
        _remainingSeconds = 0;
      });
      return;
    }

    setState(() {
      _isLoadingQuote = true;
      _errorMessage = null;
    });

    try {
      final quote = await _repo.getLiveQuote(
        fromCurrency: src.currencyCode,
        toCurrency: dest.currencyCode,
        sourceAmount: amount,
        validitySeconds: 30,
      );

      _countdownTimer?.cancel();
      _remainingSeconds = quote.validitySeconds;

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      });

      if (mounted) {
        setState(() {
          _activeQuote = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingQuote = false;
        });
      }
    }
  }

  Future<void> _executeConversion() async {
    final quote = _activeQuote;
    final src = _sourceAccount;
    final dest = _targetAccount;
    if (quote == null || src == null || dest == null) return;

    if (_remainingSeconds <= 0) {
      setState(() => _errorMessage = 'Quote expired. Please refresh the quote to lock in current rate.');
      return;
    }

    setState(() {
      _isConverting = true;
      _errorMessage = null;
    });

    try {
      final txn = await _repo.convertPocket(
        sourceAccountId: src.accountId,
        targetAccountId: dest.accountId,
        quoteId: quote.quoteId,
        amount: quote.sourceAmount,
        idempotencyKey: _repo.generateIdempotencyKey(),
      );

      if (mounted) {
        setState(() => _isConverting = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => ReceiptVoucherScreen(transaction: txn),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isConverting = false;
        });
      }
    }
  }

  void _applyAmountPercentage(double pct) {
    final src = _sourceAccount;
    if (src == null) return;
    final calculated = (src.balanceAmount * pct).toStringAsFixed(2);
    _amountController.text = calculated;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _repo.currentAccounts;
    final src = _sourceAccount;
    final quote = _activeQuote;
    final isExpired = _remainingSeconds <= 0;

    Color timerColor = AppColors.mintDark;
    if (_remainingSeconds < 15 && _remainingSeconds >= 6) {
      timerColor = AppColors.amberDark;
    } else if (_remainingSeconds < 6) {
      timerColor = AppColors.roseDanger;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Convert Pockets & ForEx', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Slide Deck Context Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppGradients.heroPlum,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.plumBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.currency_exchange_rounded, color: AppColors.magentaHot, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MULTI-CURRENCY POCKET CONVERSION (TR-M11)',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Guaranteed ForEx rates locked with real-time countdown timer before posting to ledger.',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // From Pocket Selector Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.cardBorderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FROM POCKET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('src_$_sourceAccountId'),
                      initialValue: _sourceAccountId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.accountId,
                          child: Text('${a.typeLabel} (${a.currencyCode}) - ${a.formattedBalance}', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _sourceAccountId = val);
                        _fetchLiveQuote();
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Source Amount to Convert',
                        prefixText: src != null ? '${AppConstants.getCurrencySymbol(src.currencyCode)} ' : '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick percentage chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 6,
                          children: [
                            _buildPctChip('25%', () => _applyAmountPercentage(0.25)),
                            _buildPctChip('50%', () => _applyAmountPercentage(0.50)),
                            _buildPctChip('75%', () => _applyAmountPercentage(0.75)),
                            _buildPctChip('Max (100%)', () => _applyAmountPercentage(1.0)),
                          ],
                        ),
                        if (src != null)
                          Text(
                            'Bal: ${src.formattedBalance}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Swap Button
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  final tmp = _sourceAccountId;
                  setState(() {
                    _sourceAccountId = _targetAccountId;
                    _targetAccountId = tmp;
                  });
                  _fetchLiveQuote();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.violetMagenta,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryViolet.withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // To Pocket Selector Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.cardBorderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TO POCKET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('target_$_targetAccountId'),
                      initialValue: _targetAccountId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.accountId,
                          child: Text('${a.typeLabel} (${a.currencyCode}) - ${a.formattedBalance}', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _targetAccountId = val);
                        _fetchLiveQuote();
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.violetSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated You Receive:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            quote != null
                                ? AppConstants.formatCurrency(quote.targetAmount, quote.toCurrency)
                                : '—',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: AppColors.primaryViolet,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Quote Countdown Banner (TR-M11)
            if (quote != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isExpired ? AppColors.roseLight : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isExpired ? AppColors.roseBorder : AppColors.cardBorderLight,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: timerColor.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: isExpired
                                  ? const Icon(Icons.timer_off_outlined, color: AppColors.roseDanger, size: 22)
                                  : CircularProgressIndicator(
                                      value: _remainingSeconds / 30.0,
                                      strokeWidth: 3.5,
                                      color: timerColor,
                                      backgroundColor: timerColor.withAlpha(40),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isExpired
                                  ? 'Quote Expired'
                                  : 'Rate guaranteed for: ${_remainingSeconds}s',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isExpired ? AppColors.roseDark : timerColor,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryViolet),
                          label: const Text('Refresh Quote', style: TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.bold)),
                          onPressed: _isLoadingQuote ? null : _fetchLiveQuote,
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.cardBorderLight),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Live Exchange Rate:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          '1 ${quote.fromCurrency} = ${quote.exchangeRate} ${quote.toCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cross-Border Spread Fee (0.5%):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          AppConstants.formatCurrency(quote.feeAmount, quote.feeCurrency),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.roseLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.roseBorder),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.roseDark, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isExpired ? null : AppGradients.violetMagenta,
                  color: isExpired ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isExpired
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primaryViolet.withAlpha(80),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isExpired
                        ? 'Refresh Quote to Convert'
                        : 'Convert Now (${quote != null ? quote.fromCurrency : ""} → ${quote != null ? quote.toCurrency : ""})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _isConverting
                      ? null
                      : isExpired
                          ? _fetchLiveQuote
                          : _executeConversion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPctChip(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.violetSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryViolet),
        ),
      ),
    );
  }
}
