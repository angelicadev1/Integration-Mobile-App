import 'package:flutter/material.dart';
import 'core/banking_repository.dart';
import 'core/constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CapstoneBankingApp());
}

class CapstoneBankingApp extends StatefulWidget {
  const CapstoneBankingApp({super.key});

  @override
  State<CapstoneBankingApp> createState() => _CapstoneBankingAppState();
}

class _CapstoneBankingAppState extends State<CapstoneBankingApp> {
  final BankingRepository _repo = BankingRepository();

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capstone Retail Ledger Bank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryViolet,
          brightness: Brightness.light,
          primary: AppColors.primaryViolet,
          secondary: AppColors.magentaHot,
          surface: Colors.white,
          error: AppColors.roseDanger,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: AppColors.primaryViolet),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.cardBorderLight),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryViolet,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    final user = _repo.currentUser;

    if (user == null) {
      return LoginScreen(
        onLoginSuccess: () {
          setState(() {});
        },
      );
    }

    if (user.isAdmin) {
      return AdminHomeScreen(
        onLogout: () {
          setState(() {});
        },
      );
    }

    return CustomerHomeScreen(
      onLogout: () {
        setState(() {});
      },
    );
  }
}
