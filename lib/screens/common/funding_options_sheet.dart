import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';
import '../../models/account_model.dart';

/// Funding Options Bottom Sheet shown on INSUFFICIENT_FUNDS.
/// Meets requirement TR-M11:
/// "funding-options bottom sheet on INSUFFICIENT_FUNDS; the user must explicitly confirm the funding pocket"
class FundingOptionsSheet extends StatefulWidget {
  final AccountModel failedSourceAccount;
  final double requestedAmount;
  final String requestedCurrency;
  final Function(AccountModel confirmedPocket) onPocketConfirmed;

  const FundingOptionsSheet({
    super.key,
    required this.failedSourceAccount,
    required this.requestedAmount,
    required this.requestedCurrency,
    required this.onPocketConfirmed,
  });

  static Future<AccountModel?> show(
    BuildContext context, {
    required AccountModel failedSourceAccount,
    required double requestedAmount,
    required String requestedCurrency,
  }) async {
    return await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FundingOptionsSheet(
        failedSourceAccount: failedSourceAccount,
        requestedAmount: requestedAmount,
        requestedCurrency: requestedCurrency,
        onPocketConfirmed: (pocket) {
          Navigator.of(ctx).pop(pocket);
        },
      ),
    );
  }

  @override
  State<FundingOptionsSheet> createState() => _FundingOptionsSheetState();
}

class _FundingOptionsSheetState extends State<FundingOptionsSheet> {
  final BankingRepository _repo = BankingRepository();
  String? _selectedAlternativeAccountId;

  @override
  void initState() {
    super.initState();
    final alternatives = _repo.getAlternativeFundingPockets(
      excludeAccountId: widget.failedSourceAccount.accountId,
    );
    if (alternatives.isNotEmpty) {
      _selectedAlternativeAccountId = alternatives.first.accountId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = _repo.getAlternativeFundingPockets(
      excludeAccountId: widget.failedSourceAccount.accountId,
    );

    AccountModel? selectedPocket;
    if (_selectedAlternativeAccountId != null) {
      final idx = alternatives.indexWhere((a) => a.accountId == _selectedAlternativeAccountId);
      if (idx != -1) selectedPocket = alternatives[idx];
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.roseLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.roseRed.withAlpha(60)),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.roseRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Funding Options (Insufficient Funds)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.plumCard),
                    ),
                    Text(
                      'Select an alternative funding pocket to complete transfer',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Insufficient funds alert banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.roseLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.roseRed.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.roseRed, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Source pocket ${widget.failedSourceAccount.accountId} has ${widget.failedSourceAccount.formattedBalance}, but ${widget.requestedCurrency} ${widget.requestedAmount.toStringAsFixed(2)} is required.',
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AVAILABLE ALTERNATIVE POCKETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryViolet,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${alternatives.length} Available',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emeraldMint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (alternatives.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No alternative pockets with sufficient balance available.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alternatives.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final acct = alternatives[i];
                final isSelected = acct.accountId == _selectedAlternativeAccountId;
                final rate = _repo.getExchangeRate(acct.currencyCode, widget.requestedCurrency);
                final equivBal = (acct.balanceAmount * rate).toStringAsFixed(2);

                return InkWell(
                  onTap: () {
                    setState(() => _selectedAlternativeAccountId = acct.accountId);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.violetSubtle : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryViolet : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryViolet.withAlpha(25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryViolet : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryViolet,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${acct.typeLabel} (${acct.currencyCode})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.plumCard),
                              ),
                              Text(
                                acct.accountId,
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              acct.formattedBalance,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.emeraldMint,
                              ),
                            ),
                            if (acct.currencyCode != widget.requestedCurrency)
                              Text(
                                '≈ ${widget.requestedCurrency} $equivBal',
                                style: const TextStyle(fontSize: 10, color: AppColors.primaryViolet, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // Explicit Confirmation Button (TR-M11)
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: selectedPocket != null ? AppGradients.violetMagenta : null,
              color: selectedPocket == null ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selectedPocket != null
                  ? [
                      BoxShadow(
                        color: AppColors.primaryViolet.withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: selectedPocket == null
                    ? null
                    : () {
                        widget.onPocketConfirmed(selectedPocket!);
                      },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        selectedPocket == null
                            ? 'Select a Funding Pocket'
                            : 'Confirm & Fund via ${selectedPocket.currencyCode} Pocket',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel Transfer', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}
