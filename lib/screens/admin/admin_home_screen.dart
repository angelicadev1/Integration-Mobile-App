import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';
import '../../models/account_model.dart';
import '../../models/customer_model.dart';
import '../../models/recon_model.dart';
import '../../models/user_session.dart';

class AdminHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminHomeScreen({super.key, required this.onLogout});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  final BankingRepository _repo = BankingRepository();
  late TabController _tabController;

  bool _isLoading = false;
  List<CustomerModel> _customers = [];
  List<AccountModel> _accounts = [];
  List<ReconRunModel> _reconRuns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final custs = await _repo.getAllCustomers();
      final accts = await _repo.getAllAccounts();
      final runs = await _repo.getReconciliationRuns();

      if (mounted) {
        setState(() {
          _customers = custs;
          _accounts = accts;
          _reconRuns = runs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Total liquidity in PHP
    double totalPhp = 0.0;
    for (var a in _accounts) {
      final rate = _repo.getExchangeRate(a.currencyCode, 'PHP');
      totalPhp += (a.balanceAmount * rate);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Bank Governance Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout Admin',
            onPressed: () {
              _repo.logout();
              widget.onLogout();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.verified_user_outlined), text: 'KYC Review'),
            Tab(icon: Icon(Icons.account_balance_outlined), text: 'Accounts'),
            Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Recon Audit'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Executive KPI Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.indigo.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildKpiCard('Total System Liquidity', AppConstants.formatCurrency(totalPhp, 'PHP'), Colors.indigo.shade900),
                      _buildKpiCard('Managed Accounts', '${_accounts.length}', Colors.blue.shade800),
                      _buildKpiCard('Registered Customers', '${_customers.length}', Colors.green.shade800),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildKycReviewTab(),
                      _buildAccountGovernanceTab(),
                      _buildReconciliationTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // --- TAB 1: KYC Review ---
  Widget _buildKycReviewTab() {
    if (_customers.isEmpty) {
      return const Center(child: Text('No customers found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final cust = _customers[i];
        final isVerified = cust.kycStatus == KycStatus.verified;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cust.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cust.kycStatusLabel,
                        style: TextStyle(
                          color: isVerified ? Colors.green.shade800 : Colors.orange.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('ID: ${cust.customerId} • Email: ${cust.email}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('ID Document: ${cust.idType} (${cust.idNumber})', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('Address: ${cust.address}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isVerified)
                      FilledButton.tonal(
                        onPressed: () async {
                          await _repo.updateKycStatus(cust.customerId, KycStatus.verified);
                          _loadAdminData();
                        },
                        child: const Text('Approve KYC', style: TextStyle(fontSize: 12)),
                      )
                    else
                      OutlinedButton(
                        onPressed: () async {
                          await _repo.updateKycStatus(cust.customerId, KycStatus.pendingVerification);
                          _loadAdminData();
                        },
                        child: const Text('Revoke / Review', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: Account Governance ---
  Widget _buildAccountGovernanceTab() {
    if (_accounts.isEmpty) {
      return const Center(child: Text('No accounts registered in system.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _accounts.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final acct = _accounts[i];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: acct.isFrozen ? Colors.red.shade200 : Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(acct.accountId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: acct.isFrozen ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            acct.statusLabel,
                            style: TextStyle(
                              color: acct.isFrozen ? Colors.red.shade800 : Colors.green.shade800,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${acct.typeLabel} • Customer: ${acct.customerId}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(acct.formattedBalance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: acct.isFrozen ? Colors.green.shade50 : Colors.red.shade50,
                    foregroundColor: acct.isFrozen ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                  onPressed: () async {
                    final newStatus = acct.isFrozen ? AccountStatus.active : AccountStatus.frozen;
                    await _repo.updateAccountStatus(acct.accountId, newStatus);
                    _loadAdminData();
                  },
                  child: Text(acct.isFrozen ? 'Unfreeze' : 'Freeze', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: Reconciliation Engine ---
  Widget _buildReconciliationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reconciliation Ledger Runs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Core balance verification against PostgreSQL audit ledger', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run Batch', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await _repo.triggerReconciliationRun();
                  _loadAdminData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reconciliation run triggered and ledger audit completed!')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._reconRuns.map((run) {
            final isBalanced = !run.hasExceptions;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isBalanced ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(run.runId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            run.status,
                            style: TextStyle(
                              color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildReconStat('Checked', '${run.totalChecked}'),
                        _buildReconStat('Matched', '${run.totalMatched}', color: Colors.green.shade700),
                        _buildReconStat('Exceptions', '${run.totalExceptions}', color: run.hasExceptions ? Colors.red : Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Executed: ${AppConstants.formatDateTime(run.startedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReconStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
