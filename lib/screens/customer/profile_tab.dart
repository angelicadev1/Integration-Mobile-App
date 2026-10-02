import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/circuit_breaker.dart';
import '../../core/device_security_service.dart';
import '../../core/sms_service.dart';
import '../../core/constants.dart';
import '../common/sms_gateway_dialog.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileTab({super.key, required this.onLogout});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final BankingRepository _repo = BankingRepository();
  final DeviceSecurityService _securityService = DeviceSecurityService();
  late TextEditingController _gatewayUrlController;
  String _userPhone = '+63 917 123 4567';

  @override
  void initState() {
    super.initState();
    _gatewayUrlController = TextEditingController(text: _repo.gatewayUrl);
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    final p = await _repo.getRegisteredRawPhone();
    if (mounted) {
      setState(() => _userPhone = p);
    }
  }

  @override
  void dispose() {
    _gatewayUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _repo.currentUser;
    final cb = _repo.circuitBreaker;
    final storage = _repo.tokenStorage;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile & DevSecOps Security',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.plumCard),
          ),
          const SizedBox(height: 4),
          Text(
            'Identity verification, encrypted token vault, and resilience telemetry',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // User Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppGradients.violetMagenta,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryViolet.withAlpha(80),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Retail Customer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.plumCard),
                            ),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customer ID: ${user?.customerId ?? "N/A"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.emeraldMint.withAlpha(80)),
                        ),
                        child: const Text(
                          'KYC VERIFIED',
                          style: TextStyle(
                            color: AppColors.emeraldMint,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Security & Encrypted Token Storage Section (As specified in diagram)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primaryViolet.withAlpha(80)),
            ),
            color: AppColors.violetSubtle,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.enhanced_encryption_rounded, color: AppColors.primaryViolet, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Encrypted Token Storage',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.plumCard),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Client-side JWT storage is shielded with authenticated stream encryption and salt derivation.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  _buildProfileRow('Storage Status', storage.hasToken ? 'ACTIVE & ENCRYPTED' : 'NO STORED TOKEN',
                      isHighlight: storage.hasToken),
                  const SizedBox(height: 8),
                  _buildProfileRow('Token Digest', storage.maskedTokenPreview, isMonospace: true),
                  const SizedBox(height: 8),
                  _buildProfileRow('Storage Target', 'Encrypted Client Memory / Keystore'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TR-M06: Device Integrity & Root Detection Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _securityService.isRootDetected ? AppColors.roseRed.withAlpha(120) : AppColors.emeraldMint.withAlpha(120),
              ),
            ),
            color: _securityService.isRootDetected ? AppColors.roseLight : AppColors.emeraldLight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _securityService.isRootDetected ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                            color: _securityService.isRootDetected ? AppColors.roseRed : AppColors.emeraldMint,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Device Integrity & Root Detection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.plumCard)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _securityService.isRootDetected ? Colors.red.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _securityService.isRootDetected ? 'THREAT DETECTED' : 'SECURE (UNROOTED)',
                          style: TextStyle(
                            color: _securityService.isRootDetected ? AppColors.roseRed : AppColors.emeraldMint,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Detects su binaries, Superuser.apk, Magisk, test-keys ROMs, and protects sensitive banking screens (TR-M06).',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  _buildProfileRow('Root Binary Status', _securityService.isRootDetected ? 'UNTRUSTED / ROOTED' : 'No su binary found (Clean)'),
                  const SizedBox(height: 8),
                  _buildProfileRow('Screen Capture Shield', 'ACTIVE (FLAG_SECURE Enabled)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: Icon(
                          _securityService.isSimulatingRoot ? Icons.security : Icons.bug_report_outlined,
                          size: 16,
                          color: _securityService.isSimulatingRoot ? AppColors.emeraldMint : AppColors.roseRed,
                        ),
                        label: Text(
                          _securityService.isSimulatingRoot ? 'Clear Simulated Root Threat' : 'Simulate Root Threat (TR-M06)',
                          style: TextStyle(
                            fontSize: 11,
                            color: _securityService.isSimulatingRoot ? AppColors.emeraldMint : AppColors.roseRed,
                          ),
                        ),
                        onPressed: () {
                          _securityService.toggleSimulatedRoot(!_securityService.isSimulatingRoot);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Circuit Breaker Telemetry Section (As specified in diagram)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.amberGold.withAlpha(100)),
            ),
            color: AppColors.amberLight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.amberGold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Circuit Breaker Telemetry',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.plumCard),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cb.state == CircuitState.closed
                              ? AppColors.emeraldLight
                              : cb.state == CircuitState.open
                                  ? AppColors.roseLight
                                  : AppColors.amberLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cb.state.name.toUpperCase(),
                          style: TextStyle(
                            color: cb.state == CircuitState.closed
                                ? AppColors.emeraldMint
                                : cb.state == CircuitState.open
                                    ? AppColors.roseRed
                                    : AppColors.amberGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Protects loopback requests against cascading failure across the Docker bridge.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  _buildProfileRow('Loopback Target', _repo.gatewayUrl),
                  const SizedBox(height: 8),
                  _buildProfileRow('Consecutive Failures', '${cb.consecutiveFailures} / ${cb.failureThreshold}'),
                  const SizedBox(height: 8),
                  _buildProfileRow('Total Handled Requests', '${cb.totalSuccesses} success / ${cb.totalFailures} failures'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset Circuit Breaker', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          cb.reset();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Circuit Breaker reset to CLOSED (Healthy).')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.electric_bolt, size: 16, color: AppColors.roseRed),
                        label: const Text('Trip Breaker', style: TextStyle(fontSize: 11, color: AppColors.roseRed)),
                        onPressed: () {
                          cb.trip(reason: 'Manual chaos test by user');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Real-Time SMS & 2FA Gateway Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.emeraldMint.withAlpha(80)),
            ),
            color: AppColors.emeraldLight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sms_outlined, color: AppColors.emeraldMint, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Real-Time SMS & 2FA Gateway',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.plumCard),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SmsService().isRealSmsActive ? AppColors.emeraldMint.withAlpha(30) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          SmsService().provider.name.toUpperCase(),
                          style: TextStyle(
                            color: SmsService().isRealSmsActive ? AppColors.emeraldMint : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dispatches real-time one-time passwords (OTP) via SMS upon sign-in and prior to ledger mutations.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  _buildProfileRow(
                    'Registered Phone',
                    _repo.customContactPhoneOverride ?? _userPhone,
                    isMonospace: true,
                    isHighlight: true,
                  ),
                  const SizedBox(height: 8),
                  _buildProfileRow('Active Provider', SmsService().provider.name.toUpperCase()),
                  const SizedBox(height: 8),
                  _buildProfileRow(
                    'Last Dispatch Status',
                    SmsService().lastResult?.statusMessage ?? 'No SMS dispatched yet',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings_phone, size: 16),
                      label: const Text('Configure SMS Gateway & Phone', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => const SmsGatewayDialog(),
                        );
                        if (res == true) {
                          _loadUserPhone();
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Backend Gateway Configuration
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
                    'Backend Operating Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.plumCard),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Air-Gapped Standalone Mock'),
                          selected: _repo.isMockMode,
                          selectedColor: AppColors.primaryViolet,
                          labelStyle: TextStyle(
                            color: _repo.isMockMode ? Colors.white : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _repo.setMode(BackendMode.mock));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Live Gateway 127.0.0.1'),
                          selected: _repo.isGatewayMode,
                          selectedColor: AppColors.primaryViolet,
                          labelStyle: TextStyle(
                            color: _repo.isGatewayMode ? Colors.white : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _repo.setMode(BackendMode.gateway));
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_repo.isGatewayMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gatewayUrlController,
                      decoration: InputDecoration(
                        labelText: 'Spring Cloud Gateway URL',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: AppColors.primaryViolet),
                          onPressed: () {
                            _repo.setGatewayUrl(_gatewayUrlController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Target URL updated to ${_gatewayUrlController.text.trim()}')),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('127.0.0.1:8080 (PC)', style: TextStyle(fontSize: 10)),
                          onPressed: () {
                            _gatewayUrlController.text = AppConstants.defaultLoopbackUrl;
                            _repo.setGatewayUrl(AppConstants.defaultLoopbackUrl);
                          },
                        ),
                        ActionChip(
                          label: const Text('10.0.2.2:8080 (Android)', style: TextStyle(fontSize: 10)),
                          onPressed: () {
                            _gatewayUrlController.text = AppConstants.androidEmulatorUrl;
                            _repo.setGatewayUrl(AppConstants.androidEmulatorUrl);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.roseRed),
              label: const Text('Sign Out', style: TextStyle(color: AppColors.roseRed, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.roseRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _repo.logout();
                widget.onLogout();
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, {bool isHighlight = false, bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: isMonospace ? 'monospace' : null,
            color: isHighlight ? AppColors.emeraldMint : AppColors.plumCard,
          ),
        ),
      ],
    );
  }
}
