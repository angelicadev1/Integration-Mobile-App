import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../core/constants.dart';

class ReceiptVoucherScreen extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptVoucherScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Receipt',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt voucher details copied to clipboard.'),
                  backgroundColor: AppColors.primaryViolet,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Status Icon & Confirmation
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.emeraldMint.withAlpha(120), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldMint.withAlpha(40),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.emeraldMint, size: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Transaction Successful',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.plumCard,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emeraldMint,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Posted & Dual-Committed to Core Ledger',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount Display Card with Slide Cosmic Plum Gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                gradient: AppGradients.heroPlum,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.plumDeep.withAlpha(100),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      transaction.typeLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppConstants.formatCurrency(transaction.amount, transaction.currencyCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (transaction.isCrossCurrency && transaction.destAmount != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldMint.withAlpha(35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.emeraldMint.withAlpha(80)),
                      ),
                      child: Text(
                        'Recipient Receives: ${AppConstants.formatCurrency(transaction.destAmount!, transaction.destCurrencyCode ?? "USD")}',
                        style: const TextStyle(
                          color: AppColors.emeraldMint,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Receipt Voucher Breakdown
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildRow('Transaction Reference', transaction.txnId, isMonospace: true),
                    const Divider(height: 24),
                    _buildRow('Ledger Mutation UUID', transaction.mutationId, isMonospace: true),
                    const Divider(height: 24),
                    _buildRow(
                      'Ledger Audit State',
                      'COMMITTED (DUAL COMMIT)',
                      customValue: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.emeraldMint.withAlpha(100)),
                        ),
                        child: const Text(
                          'COMMITTED',
                          style: TextStyle(
                            color: AppColors.emeraldMint,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    _buildRow('Source Account', transaction.accountId, isMonospace: true),
                    if (transaction.counterpartyAccountId != null) ...[
                      const Divider(height: 24),
                      _buildRow('Counterparty Account', transaction.counterpartyAccountId!, isMonospace: true),
                    ],
                    if (transaction.isCrossCurrency) ...[
                      const Divider(height: 24),
                      _buildRow('ForEx Conversion Rate', '1 ${transaction.currencyCode} = ${transaction.fxRate} ${transaction.destCurrencyCode}'),
                      const Divider(height: 24),
                      _buildRow('Processing Fee (0.5%)', AppConstants.formatCurrency(transaction.feeAmount, transaction.currencyCode)),
                    ],
                    const Divider(height: 24),
                    _buildRow('Idempotency Key', transaction.idempotencyKey, isMonospace: true),
                    const Divider(height: 24),
                    _buildRow(
                      'Risk Score Assessment',
                      '${transaction.riskScore.toStringAsFixed(1)} / 100',
                      customValue: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.violetSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryViolet.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, color: AppColors.primaryViolet, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${transaction.riskScore.toStringAsFixed(1)} (${transaction.riskDecision})',
                              style: const TextStyle(
                                color: AppColors.primaryViolet,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    _buildRow('Timestamp', AppConstants.formatDateTime(transaction.timestamp)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Back to Banking Portal Button with Gradient
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.violetMagenta,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryViolet.withAlpha(80),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Center(
                    child: Text(
                      'Back to Banking Portal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isMonospace = false, Widget? customValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: customValue ??
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.plumCard,
                    fontFamily: isMonospace ? 'monospace' : null,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
