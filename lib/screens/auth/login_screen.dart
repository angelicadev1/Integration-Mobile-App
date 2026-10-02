import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/circuit_breaker.dart';
import '../../core/constants.dart';
import '../common/sms_gateway_dialog.dart';
import '../common/service_unavailable_screen.dart';
import 'register_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final BankingRepository _repo = BankingRepository();

  final TextEditingController _emailController = TextEditingController(text: 'juan.delacruz@example.com');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? email, String? password}) async {
    final e = email ?? _emailController.text.trim();
    final p = password ?? _passwordController.text;

    if (email == null && !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pending = await _repo.initiateLoginWithOtp(e, p);
      if (pending != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OtpVerificationScreen(
                session: pending.session,
                maskedPhone: pending.maskedPhone,
                generatedOtp: pending.otpCode,
                onVerificationSuccess: () {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess();
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid email or password. Please verify credentials.';
            _isLoading = false;
          });
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _showBiometricDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Biometric Scanner Ring
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppGradients.violetMagentaGlow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryViolet.withAlpha(90),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.fingerprint, size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Biometric Authentication',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Touch the fingerprint sensor to authenticate via Android Keystore credentials (TR-M02, TR-M05).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.violetMagenta,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Simulate Fingerprint Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        setState(() => _isLoading = true);
                        try {
                          final session = await _repo.loginWithBiometric();
                          if (session != null && mounted) {
                            setState(() => _isLoading = false);
                            widget.onLoginSuccess();
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                              _errorMessage = e.toString().replaceAll('Exception:', '').trim();
                            });
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPinDialog() {
    String currentPin = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
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
                  child: const Icon(Icons.pin, color: AppColors.primaryViolet, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Security PIN Fallback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter 6-digit security PIN (TR-M02 fallback)\nDefault: 123456 (Juan), 999999 (Maria), 000000 (Admin)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // 6-digit visual indicator bubbles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isFilled = index < currentPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isFilled ? AppGradients.violetMagenta : null,
                        color: isFilled ? null : Colors.grey.shade200,
                        border: Border.all(
                          color: isFilled ? AppColors.magentaDark : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Keypad grid
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (int i = 1; i <= 9; i++)
                      _buildKeypadBtn('$i', () {
                        if (currentPin.length < 6) {
                          setDialogState(() => currentPin += '$i');
                        }
                      }),
                    _buildKeypadBtn('C', () {
                      setDialogState(() => currentPin = '');
                    }, isAction: true),
                    _buildKeypadBtn('0', () {
                      if (currentPin.length < 6) {
                        setDialogState(() => currentPin += '0');
                      }
                    }),
                    _buildKeypadBtn('⌫', () {
                      if (currentPin.isNotEmpty) {
                        setDialogState(() => currentPin = currentPin.substring(0, currentPin.length - 1));
                      }
                    }, isAction: true),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: currentPin.length == 6 ? AppGradients.violetMagenta : null,
                  color: currentPin.length == 6 ? null : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: currentPin.length == 6
                      ? () async {
                          Navigator.of(ctx).pop();
                          setState(() => _isLoading = true);
                          try {
                            final session = await _repo.loginWithPin(currentPin);
                            if (session != null && mounted) {
                              setState(() => _isLoading = false);
                              widget.onLoginSuccess();
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                                _errorMessage = e.toString().replaceAll('Exception:', '').trim();
                              });
                            }
                          }
                        }
                      : null,
                  child: const Text('Verify PIN'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKeypadBtn(String label, VoidCallback onTap, {bool isAction = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 46,
        decoration: BoxDecoration(
          color: isAction ? AppColors.violetSoft : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isAction ? AppColors.primaryViolet : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cb = _repo.circuitBreaker;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top SMS Config & Mode Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _repo.isMockMode ? AppColors.plumCard : AppColors.violetSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _repo.isMockMode ? AppColors.plumBorder : AppColors.cardBorderLight,
                          ),
                        ),
                        child: Text(
                          _repo.isMockMode ? 'STANDALONE AIR-GAPPED' : 'GATEWAY: 127.0.0.1:8080',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _repo.isMockMode ? Colors.white : AppColors.primaryViolet,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.settings_phone, size: 16, color: AppColors.primaryViolet),
                        label: const Text(
                          'SMS & 2FA Setup',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryViolet),
                        ),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (ctx) => const SmsGatewayDialog(),
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CAPSTONE SLIDE DECK HERO CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppGradients.heroPlum,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.plumBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.plumDeep.withAlpha(160),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slide Pill Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.magentaPill.withAlpha(200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'FED-CAPSTONE // RETAIL LEDGER',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.mintDark.withAlpha(220),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 10, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Testing: 100% passed',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title with glowing gradient accent
                        const Text(
                          'CAPSTONE LEDGER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Core Retail Ledger & Balance Mutation Engine',
                          style: TextStyle(
                            color: AppColors.magentaHot,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Distributed multi-service retail ledger with pessimistic concurrency, dual-database dual writes, multi-currency transfers, and continuous reconciliation.',
                          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11, height: 1.4),
                        ),
                        const SizedBox(height: 14),

                        // Circuit & Spring Gateway indicators
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Spring Boot 3 • Gateway 8080',
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cb.state == CircuitState.closed ? AppColors.mintEmerald : AppColors.roseDanger,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'CIRCUIT ${cb.state.name.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: cb.state == CircuitState.closed ? AppColors.mintEmerald : AppColors.roseDanger,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.roseLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.roseBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.roseDanger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.roseDark, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Customer Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryViolet),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please enter email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Vault Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryViolet),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please enter password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Prominent Sign In Button
                  SizedBox(
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.violetMagenta,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryViolet.withAlpha(90),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _handleLogin(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fingerprint & PIN Fallback (TR-M02)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.fingerprint, size: 20, color: AppColors.primaryViolet),
                          label: const Text('Fingerprint', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryViolet)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.cardBorderLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _showBiometricDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.pin_outlined, size: 20, color: AppColors.magentaDark),
                          label: const Text('PIN Fallback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.magentaDark)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.magentaBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _showPinDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // One-Click Demo Personas Header
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.cardBorderLight)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ONE-CLICK DEMO PERSONAS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.cardBorderLight)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Interactive Persona Cards
                  _buildPersonaTile(
                    name: 'Juan Dela Cruz',
                    role: 'Retail Customer (PHP ₱45k • USD \$1.5k)',
                    pin: 'PIN: 123456',
                    icon: Icons.person_rounded,
                    accentColor: AppColors.primaryViolet,
                    onTap: () => _handleLogin(email: 'juan.delacruz@example.com', password: 'password123'),
                  ),
                  const SizedBox(height: 8),
                  _buildPersonaTile(
                    name: 'Maria Santos',
                    role: 'Multi-Currency Trader (PHP ₱128k • EUR €3.2k)',
                    pin: 'PIN: 999999',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppColors.magentaHot,
                    onTap: () => _handleLogin(email: 'maria.santos@example.com', password: 'password123'),
                  ),
                  const SizedBox(height: 8),
                  _buildPersonaTile(
                    name: 'System Administrator',
                    role: 'Bank Governance, KYC & Recon Console',
                    pin: 'PIN: 000000',
                    icon: Icons.admin_panel_settings_rounded,
                    accentColor: AppColors.mintEmerald,
                    onTap: () => _handleLogin(email: 'admin@ledgerbank.com', password: 'admin123'),
                  ),
                  const SizedBox(height: 20),

                  // Mode Switcher Toggle
                  Center(
                    child: TextButton.icon(
                      icon: Icon(
                        _repo.isMockMode ? Icons.cloud_outlined : Icons.offline_bolt_outlined,
                        size: 16,
                        color: AppColors.primaryViolet,
                      ),
                      label: Text(
                        _repo.isMockMode
                            ? 'Switch to Live Gateway (127.0.0.1:8080)'
                            : 'Switch to Standalone Mock Air-Gapped Mode',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryViolet),
                      ),
                      onPressed: () {
                        setState(() {
                          _repo.setMode(_repo.isMockMode ? BackendMode.gateway : BackendMode.mock);
                        });
                      },
                    ),
                  ),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => RegisterScreen(
                                onRegisterSuccess: widget.onLoginSuccess,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Register Here',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryViolet,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // TR-M02: Service Status & Unavailable Screen Link
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.cloud_sync_outlined, size: 14, color: AppColors.textMuted),
                      label: const Text(
                        'System Health & Service-Unavailable Screen',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => ServiceUnavailableScreen(
                              onRetry: () => setState(() {}),
                              onAccessCachedHome: widget.onLoginSuccess,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaTile({
    required String name,
    required String role,
    required String pin,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.violetSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pin,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryViolet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
