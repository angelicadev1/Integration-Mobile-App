import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';
import '../../models/transaction_model.dart';
import '../../models/dispute_model.dart';

/// Report Suspicious Transaction Dialog / Screen.
/// Meets requirement TR-M02: "report suspicious transaction"
class ReportSuspiciousTxnDialog extends StatefulWidget {
  final TransactionModel transaction;

  const ReportSuspiciousTxnDialog({
    super.key,
    required this.transaction,
  });

  static Future<DisputeModel?> show(BuildContext context, {required TransactionModel transaction}) async {
    return await showDialog<DisputeModel>(
      context: context,
      builder: (ctx) => ReportSuspiciousTxnDialog(transaction: transaction),
    );
  }

  @override
  State<ReportSuspiciousTxnDialog> createState() => _ReportSuspiciousTxnDialogState();
}

class _ReportSuspiciousTxnDialogState extends State<ReportSuspiciousTxnDialog> {
  final BankingRepository _repo = BankingRepository();
  final TextEditingController _descController = TextEditingController();

  String _selectedReason = 'Unauthorized Transaction';
  bool _freezeRequested = true;
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Unauthorized Transaction',
    'Suspected Phishing or Fraud',
    'Incorrect Transaction Amount',
    'Duplicate Mutation / Double Charge',
    'Lost or Stolen Payment Instrument',
    'Other Suspicious Anomaly',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final dispute = await _repo.reportSuspiciousTransaction(
        txnId: widget.transaction.txnId,
        accountId: widget.transaction.accountId,
        amount: widget.transaction.amount,
        currencyCode: widget.transaction.currencyCode,
        reason: _selectedReason,
        description: _descController.text.trim(),
        freezeRequested: _freezeRequested,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop(dispute);
        _showConfirmationDialog(dispute);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit dispute: $e'), backgroundColor: AppColors.roseRed),
        );
      }
    }
  }

  void _showConfirmationDialog(DisputeModel dispute) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppColors.emeraldMint),
            SizedBox(width: 8),
            Text('Dispute Filed', style: TextStyle(color: AppColors.plumCard, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your fraud dispute has been filed with the bank security operations team.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ticket Reference: ${dispute.disputeId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.plumCard)),
                  const SizedBox(height: 4),
                  Text('Transaction: ${dispute.txnId}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('Status: ${dispute.status}', style: const TextStyle(fontSize: 11, color: AppColors.amberGold, fontWeight: FontWeight.bold)),
                  if (dispute.freezeRequested) ...[
                    const SizedBox(height: 6),
                    const Text('Account frozen immediately to safeguard balances.', style: TextStyle(fontSize: 11, color: AppColors.roseRed)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.roseLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: AppColors.roseRed, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Suspicious Txn',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.plumCard),
                      ),
                      Text(
                        'File an immediate security dispute',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Txn Summary Card
            Container(
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
                      const Text('Txn ID:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(t.txnId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace', color: AppColors.plumCard)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        AppConstants.formatCurrency(t.amount, t.currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.roseRed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(AppConstants.formatDateTime(t.timestamp), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason selector
            const Text('Reason for Report:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.plumCard)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('reason_$_selectedReason'),
              initialValue: _selectedReason,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 12),

            // Description input
            const Text('Additional Details (Optional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.plumCard)),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe why you believe this transaction is fraudulent or unauthorized...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Emergency Freeze Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _freezeRequested,
              activeColor: AppColors.roseRed,
              onChanged: (val) => setState(() => _freezeRequested = val ?? true),
              title: const Text(
                'Freeze this account immediately',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.roseRed),
              ),
              subtitle: const Text(
                'Recommended: Immediately halts all debits and withdrawals to prevent balance drain.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.roseRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submitReport,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Report'),
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
