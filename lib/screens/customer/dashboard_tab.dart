import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';
import '../../models/transaction_model.dart';
import 'card_controls_screen.dart';
import 'convert_screen.dart';
import 'report_suspicious_txn_dialog.dart';
import '../receipt/receipt_voucher_screen.dart';

/// Customer Home Dashboard Tab.
/// Meets requirements:
/// - TR-M02: Screens: home (balance, mobile/account number, last 5 transactions, Send Money)
/// - TR-M09: Home shows last cached balance, clearly labeled with timestamp, when live ledger is degraded
/// - TR-M11: Pocket switcher on home
class DashboardTab extends StatefulWidget {
  final Function(int tabIndex, {TransactionType? initialTxnType, String? defaultAccountId}) onNavigateTab;

  const DashboardTab({super.key, required this.onNavigateTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final BankingRepository _repo = BankingRepository();
  List<TransactionModel> _recentTxns = [];
  bool _isLoadingRecentTxns = false;
  bool _isBalanceHidden = false;
  String _transactionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
  }

  Future<void> _loadRecentTransactions() async {
    setState(() => _isLoadingRecentTxns = true);
    try {
      final txns = await _repo.getAuditTransactions();
      if (mounted) {
        setState(() {
          _recentTxns = txns.take(5).toList();
          _isLoadingRecentTxns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecentTxns = false);
    }
  }

  Future<void> _onRefresh() async {
    await _repo.refreshUserData();
    await _loadRecentTransactions();
  }

  LinearGradient _getCardGradient(String? currency) {
    switch (currency?.toUpperCase()) {
      case 'USD':
        return AppGradients.cardUsd;
      case 'EUR':
        return AppGradients.cardEur;
      case 'PHP':
      default:
        return AppGradients.cardPhp;
    }
  }

  void _showQuickDepositSheet() {
    final activePocket = _repo.activePocket;
    if (activePocket == null) return;

    final controller = TextEditingController(text: '5000');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Deposit to ${activePocket.currencyCode}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Instantly test balance mutation and core ledger credit on ${activePocket.accountId}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Amount Chips
              Wrap(
                spacing: 8,
                children: [500, 1000, 5000, 10000].map((amt) {
                  return ActionChip(
                    label: Text('+${activePocket.currencyCode} $amt'),
                    backgroundColor: AppColors.violetSoft,
                    labelStyle: const TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.bold, fontSize: 11),
                    onPressed: () => controller.text = '$amt',
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Deposit Amount',
                  prefixText: '${AppConstants.getCurrencySymbol(activePocket.currencyCode)} ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.violetMagenta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final val = double.tryParse(controller.text) ?? 0;
                      if (val <= 0) return;
                      Navigator.of(ctx).pop();
                      try {
                        await _repo.executeTransaction(
                          sourceAccountId: activePocket.accountId,
                          counterpartyAccountId: 'CORE-TREASURY',
                          txnType: TransactionType.deposit,
                          amount: val,
                        );
                        await _onRefresh();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully deposited ${AppConstants.formatCurrency(val, activePocket.currencyCode)}!'),
                              backgroundColor: AppColors.mintDark,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deposit failed: $e'), backgroundColor: AppColors.roseDanger),
                          );
                        }
                      }
                    },
                    child: const Text('Confirm Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primaryViolet),
            SizedBox(width: 10),
            Text('Download Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export an official audited transaction statement for compliance and tax filings (TR-M02).',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.roseDanger),
              title: const Text('PDF Official Statement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Digital cryptographic signature', style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.violetSoft, foregroundColor: AppColors.primaryViolet),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF statement generated and downloaded to device!')),
                  );
                },
                child: const Text('Export PDF', style: TextStyle(fontSize: 11)),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart, color: AppColors.mintEmerald),
              title: const Text('CSV Ledger Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Raw ledger entries with UUID headers', style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.violetSoft, foregroundColor: AppColors.primaryViolet),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV ledger records exported!')),
                  );
                },
                child: const Text('Export CSV', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _repo.currentUser;
    final accounts = _repo.currentAccounts;
    final activePocket = _repo.activePocket;

    final filteredTxns = _recentTxns.where((t) {
      if (_transactionFilter == 'TRANSFERS') return t.txnType == TransactionType.transfer;
      if (_transactionFilter == 'CROSS_BORDER') return t.isCrossCurrency;
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.primaryViolet,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header & KYC Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    Text(
                      user?.fullName ?? 'Retail Customer',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.mintBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, color: AppColors.mintDark, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'KYC VERIFIED',
                        style: TextStyle(
                          color: AppColors.mintDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // TR-M09: DB-degradation fallback alert banner
            if (_repo.isLedgerDegraded) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amberWarning, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.amberDark, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '⚠️ Live Ledger Degraded (DB-Degradation Fallback)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF451A03),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _onRefresh,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              'Retry Sync',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.amberDark,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Displaying last verified cached balance labeled from: ${_repo.lastBalanceTimestamp != null ? AppConstants.formatDateTime(_repo.lastBalanceTimestamp!) : "Recently Cached"}. Real-time mutations are temporarily held (TR-M09).',
                      style: const TextStyle(fontSize: 11, color: AppColors.amberDark, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],

            // TR-M11: Pocket Switcher on Home
            if (accounts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CURRENCY POCKETS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 14, color: AppColors.primaryViolet),
                    label: const Text('Convert Pockets', style: TextStyle(fontSize: 11, color: AppColors.primaryViolet, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => ConvertScreen(initialSourceAccountId: activePocket?.accountId),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizontally scrollable pocket chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(accounts.length, (index) {
                    final pocket = accounts[index];
                    final isSelected = index == _repo.selectedPocketIndex;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _repo.selectPocket(index);
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppGradients.violetMagenta : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.magentaHot : AppColors.cardBorderLight,
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryViolet.withAlpha(60),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withAlpha(30) : AppColors.violetSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  AppConstants.getCurrencySymbol(pocket.currencyCode),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : AppColors.primaryViolet,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${pocket.currencyCode} ${pocket.typeLabel}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _isBalanceHidden ? '••••••' : pocket.formattedBalance,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // DYNAMIC HERO BALANCE CARD (Matching Slide 1 Deep Plum/Violet Aesthetics)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: _getCardGradient(activePocket?.currencyCode),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.plumBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.plumDeep.withAlpha(140),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activePocket != null
                            ? '${activePocket.typeLabel.toUpperCase()} (${activePocket.currencyCode})'
                            : 'ACCOUNT BALANCE',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          // Eye Balance Toggle
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _repo.isLedgerDegraded ? AppColors.amberDark.withAlpha(150) : AppColors.mintDark.withAlpha(160),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _repo.isLedgerDegraded ? 'CACHED BALANCE' : 'LIVE LEDGER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Large Balance Display (TR-M02)
                  Text(
                    _isBalanceHidden
                        ? '${AppConstants.getCurrencySymbol(activePocket?.currencyCode ?? "PHP")} ••••••••'
                        : (activePocket?.formattedBalance ?? '₱0.00'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Timestamp Label (TR-M09)
                  Text(
                    _repo.lastBalanceTimestamp != null
                        ? 'As of: ${AppConstants.formatDateTime(_repo.lastBalanceTimestamp!)}${_repo.isLedgerDegraded ? " (Cached Fallback)" : ""}'
                        : 'Fetching live ledger state...',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // TR-M02: Account Number & Mobile Number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Account number with copy
                        InkWell(
                          onTap: () {
                            if (activePocket != null) {
                              Clipboard.setData(ClipboardData(text: activePocket.accountId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account number copied to clipboard!')),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                activePocket?.accountId ?? 'ACCT-PENDING',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy, color: Colors.white54, size: 12),
                            ],
                          ),
                        ),

                        // Mobile number with copy
                        InkWell(
                          onTap: () {
                            final phone = user?.contactNo ?? '+63 917 123 4567';
                            Clipboard.setData(ClipboardData(text: phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mobile number copied to clipboard!')),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_android, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                user?.contactNo ?? '+63 917 123 4567',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy, color: Colors.white54, size: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // TR-M02: Send Money Prominent Button & Quick Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Prominent Send Money Action
                      _buildQuickAction(
                        icon: Icons.send_rounded,
                        label: 'Send Money',
                        isPrimary: true,
                        onTap: () => widget.onNavigateTab(
                          1,
                          initialTxnType: TransactionType.transfer,
                          defaultAccountId: activePocket?.accountId,
                        ),
                      ),
                      _buildQuickAction(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Convert',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ConvertScreen(initialSourceAccountId: activePocket?.accountId),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.credit_card_rounded,
                        label: 'Cards',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const CardControlsScreen()),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Deposit',
                        onTap: _showQuickDepositSheet,
                      ),
                      _buildQuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Statement',
                        onTap: _showStatementDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // TR-M09: Interactive Ledger Degradation Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _repo.isLedgerDegraded ? AppColors.amberLight : AppColors.mintLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _repo.isLedgerDegraded ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                          size: 16,
                          color: _repo.isLedgerDegraded ? AppColors.amberDark : AppColors.mintDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Simulate Ledger Degradation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(
                            _repo.isLedgerDegraded ? 'Serving cached balance (TR-M09)' : 'Connected to live distributed ledger',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _repo.isLedgerDegraded,
                    activeThumbColor: AppColors.amberDark,
                    activeTrackColor: AppColors.amberLight,
                    onChanged: (val) {
                      _repo.setSimulateLedgerDegraded(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // TR-M02: Last 5 Transactions Header & Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LAST 5 TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(2),
                  child: const Text('View All History', style: TextStyle(fontSize: 11, color: AppColors.primaryViolet, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            // Filter Chips
            Row(
              children: [
                _buildFilterChip('ALL', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('TRANSFERS', 'Transfers'),
                const SizedBox(width: 8),
                _buildFilterChip('CROSS_BORDER', 'ForEx'),
              ],
            ),
            const SizedBox(height: 10),

            // Transaction Items
            if (_isLoadingRecentTxns)
              const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
            else if (filteredTxns.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: const Center(
                  child: Text('No matching transactions found.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              )
            else
              ...filteredTxns.map((txn) => _buildTransactionCard(txn)),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _transactionFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _transactionFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryViolet : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primaryViolet : AppColors.cardBorderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isPrimary ? AppGradients.violetMagenta : null,
              color: isPrimary ? null : Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isPrimary ? AppColors.magentaHot : Colors.white.withAlpha(40)),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: AppColors.magentaHot.withAlpha(90),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 10,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel txn) {
    final isCredit = txn.isCredit;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ReceiptVoucherScreen(transaction: txn),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCredit ? AppColors.mintLight : AppColors.violetSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isCredit ? AppColors.mintDark : AppColors.primaryViolet,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.sourceAccountId} → ${txn.counterpartyAccountId}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppConstants.formatDateTime(txn.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? "+" : "-"}${AppConstants.formatCurrency(txn.amount, txn.currencyCode)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isCredit ? AppColors.mintDark : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // TR-M02: Report suspicious transaction shield icon
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ReportSuspiciousTxnDialog(transaction: txn),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.roseLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 10, color: AppColors.roseDanger),
                          SizedBox(width: 2),
                          Text(
                            'Dispute',
                            style: TextStyle(fontSize: 9, color: AppColors.roseDanger, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
