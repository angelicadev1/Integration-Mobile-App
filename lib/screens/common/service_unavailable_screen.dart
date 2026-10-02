import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/circuit_breaker.dart';
import '../../core/constants.dart';

/// Dedicated Service Unavailable Screen.
/// Meets requirement TR-M02: "service-unavailable screen"
class ServiceUnavailableScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onAccessCachedHome;

  const ServiceUnavailableScreen({
    super.key,
    this.onRetry,
    this.onAccessCachedHome,
  });

  @override
  State<ServiceUnavailableScreen> createState() => _ServiceUnavailableScreenState();
}

class _ServiceUnavailableScreenState extends State<ServiceUnavailableScreen> {
  final BankingRepository _repo = BankingRepository();
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    try {
      _repo.circuitBreaker.reset();
      await _repo.refreshUserData();
      if (mounted) {
        setState(() => _isRetrying = false);
        if (widget.onRetry != null) {
          widget.onRetry!();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cb = _repo.circuitBreaker;
    final cooldown = cb.remainingCooldown?.inSeconds ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('System Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.amberLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.amberGold.withAlpha(120), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amberGold.withAlpha(40),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.amberGold),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Service Temporarily Unavailable',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.plumCard,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  'The core ledger backend or API gateway is currently unreachable. Our automated resilience safeguards have engaged to protect financial integrity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Circuit Breaker Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Resilience Guard:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cb.state == CircuitState.open ? AppColors.roseRed : AppColors.amberGold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cb.state.name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: cb.state == CircuitState.open ? AppColors.roseRed : AppColors.amberGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gateway Target:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text(
                            _repo.gatewayUrl,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace', color: AppColors.plumCard),
                          ),
                        ],
                      ),
                      if (cooldown > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cooldown Remaining:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text(
                              '${cooldown}s',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryViolet),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Retry Button with Gradient
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
                      onTap: _isRetrying ? null : _handleRetry,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isRetrying)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isRetrying ? 'Re-probing Gateway...' : 'Retry Connection',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Access Cached Balance Button (TR-M09)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryViolet,
                      side: BorderSide(color: AppColors.primaryViolet.withAlpha(120)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.history_toggle_off_rounded),
                    label: const Text(
                      'View Last Cached Balance (Degraded Mode)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      _repo.setSimulateLedgerDegraded(true);
                      if (widget.onAccessCachedHome != null) {
                        widget.onAccessCachedHome!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
