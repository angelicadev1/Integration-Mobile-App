import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/circuit_breaker.dart';
import '../../core/constants.dart';
import '../../models/transaction_model.dart';
import 'dashboard_tab.dart';
import 'remittance_form_tab.dart';
import 'history_tab.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import 'card_controls_screen.dart';
import 'convert_screen.dart';
import '../common/service_unavailable_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const CustomerHomeScreen({super.key, required this.onLogout});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final BankingRepository _repo = BankingRepository();
  int _currentIndex = 0;

  // Parameters passed to Remittance tab
  TransactionType _remitInitialType = TransactionType.transfer;
  String? _remitDefaultAccountId;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdate);
    _repo.circuitBreaker.addListener(_onRepoUpdate);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdate);
    _repo.circuitBreaker.removeListener(_onRepoUpdate);
    super.dispose();
  }

  void _onRepoUpdate() {
    if (mounted) setState(() {});
  }

  void _navigateToTab(int index, {TransactionType? initialTxnType, String? defaultAccountId}) {
    setState(() {
      _currentIndex = index;
      if (initialTxnType != null) _remitInitialType = initialTxnType;
      if (defaultAccountId != null) _remitDefaultAccountId = defaultAccountId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cb = _repo.circuitBreaker;
    final unreadCount = _repo.unreadNotificationCount;

    final List<Widget> tabs = [
      DashboardTab(onNavigateTab: _navigateToTab),
      RemittanceFormTab(
        key: ValueKey('$_remitInitialType-$_remitDefaultAccountId'),
        initialType: _remitInitialType,
        defaultAccountId: _remitDefaultAccountId,
      ),
      const HistoryTab(),
      const NotificationsTab(),
      ProfileTab(onLogout: widget.onLogout),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppGradients.violetMagenta,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryViolet.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAPSTONE LEDGER',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                ),
                Text(
                  'Retail Mobile Banking',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Connection Mode Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _repo.isMockMode ? AppColors.violetSubtle : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _repo.isMockMode ? AppColors.violetLight.withAlpha(120) : const Color(0xFF93C5FD),
              ),
            ),
            child: Text(
              _repo.isMockMode ? 'MOCK' : '127.0.0.1',
              style: TextStyle(
                color: _repo.isMockMode ? AppColors.primaryViolet : const Color(0xFF1E40AF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Circuit Breaker Status Indicator Dot (TR-M02: tap opens Service Status)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const ServiceUnavailableScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Tooltip(
                message: 'Circuit Breaker: ${cb.state.name.toUpperCase()} (Tap for Service Status)',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cb.state == CircuitState.closed
                        ? AppColors.emeraldMint
                        : cb.state == CircuitState.open
                            ? AppColors.roseRed
                            : AppColors.amberGold,
                    boxShadow: [
                      BoxShadow(
                        color: (cb.state == CircuitState.closed
                                ? AppColors.emeraldMint
                                : cb.state == CircuitState.open
                                    ? AppColors.roseRed
                                    : AppColors.amberGold)
                            .withAlpha(120),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Quick Persona & Feature Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Banking Actions & Personas',
            onSelected: (val) async {
              if (val == 'juan') {
                await _repo.login('juan.delacruz@example.com', 'password123');
              } else if (val == 'maria') {
                await _repo.login('maria.santos@example.com', 'password123');
              } else if (val == 'admin') {
                await _repo.login('admin@ledgerbank.com', 'admin123');
              } else if (val == 'cards') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const CardControlsScreen()),
                );
              } else if (val == 'convert') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const ConvertScreen()),
                );
              } else if (val == 'status') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const ServiceUnavailableScreen()),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('FEATURES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const PopupMenuItem(
                value: 'cards',
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 16, color: AppColors.primaryViolet),
                    SizedBox(width: 8),
                    Text('Card Controls & Security'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'convert',
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange, size: 16, color: AppColors.magentaHot),
                    SizedBox(width: 8),
                    Text('Convert Pockets (Live Quote)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.amberGold),
                    SizedBox(width: 8),
                    Text('System & Service Status'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('DEMO PERSONAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const PopupMenuItem(
                value: 'juan',
                child: Text('Juan Dela Cruz (PHP/USD)'),
              ),
              const PopupMenuItem(
                value: 'maria',
                child: Text('Maria Santos (PHP/EUR)'),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: Text('System Administrator'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppColors.violetSubtle,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
            // Reset remit params if manually tapped
            if (idx == 1) {
              _remitInitialType = TransactionType.transfer;
              _remitDefaultAccountId = null;
            }
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryViolet),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: AppColors.primaryViolet),
            label: 'Transact',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.primaryViolet),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.magentaHot,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.magentaHot,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications, color: AppColors.primaryViolet),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: AppColors.primaryViolet),
            label: 'Security',
          ),
        ],
      ),
    );
  }
}
