import 'package:flutter/material.dart';

/// Capstone Design System & Color Palette
/// Modeled after the Core Retail Ledger Slide Deck visual identity:
/// Deep cosmic plum, electric violet, vivid magenta/fuchsia, and emerald mint.
class AppColors {
  // Midnight Plum & Dark Theme (Cover & Architecture Models)
  static const Color plumDeep = Color(0xFF0D0819);
  static const Color plumDark = Color(0xFF160D2A);
  static const Color plumCard = Color(0xFF21133E);
  static const Color plumSurface = Color(0xFF2C1952);
  static const Color plumBorder = Color(0xFF4C2788);

  // Vibrant Electric Violet (Primary Brand)
  static const Color primaryViolet = Color(0xFF7C3AED);
  static const Color violetLight = Color(0xFF8B5CF6);
  static const Color violetGlow = Color(0xFFA855F7);
  static const Color violetSoft = Color(0xFFF3E8FF);
  static const Color violetBg = Color(0xFFF8F6FD);
  static const Color violetSubtle = Color(0xFFF3E8FF);

  // Vivid Magenta / Fuchsia Accents (Signatures from Slide Deck)
  static const Color magentaHot = Color(0xFFD946EF);
  static const Color magentaDark = Color(0xFFC026D3);
  static const Color magentaPill = Color(0xFF9333EA);
  static const Color magentaLight = Color(0xFFFDF4FF);
  static const Color magentaBorder = Color(0xFFF0ABFC);

  // Emerald / Mint Accents ("Testing 100% Passed" & Success Decisions)
  static const Color mintEmerald = Color(0xFF10B981);
  static const Color mintDark = Color(0xFF059669);
  static const Color mintLight = Color(0xFFECFDF5);
  static const Color mintBorder = Color(0xFFA7F3D0);
  static const Color emeraldMint = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color emeraldDark = Color(0xFF059669);

  // Amber / Warning Accents (Degradation / Velocity Throttled)
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);
  static const Color amberGold = Color(0xFFF59E0B);

  // Rose / Red Accents (High Risk Decline / Frozen Cards)
  static const Color roseDanger = Color(0xFFEF4444);
  static const Color roseDark = Color(0xFFDC2626);
  static const Color roseLight = Color(0xFFFEF2F2);
  static const Color roseBorder = Color(0xFFFECACA);
  static const Color roseRed = Color(0xFFEF4444);

  // Text & Neutral Colors
  static const Color textPrimary = Color(0xFF180E29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color backgroundLight = Color(0xFFF8F6FD);
  static const Color cardLight = Colors.white;
  static const Color cardBorderLight = Color(0xFFE9D5FF);
}

class AppGradients {
  static const LinearGradient heroPlum = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF100722), Color(0xFF220F3E), Color(0xFF331458)],
  );

  static const LinearGradient violetMagenta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
  );

  static const LinearGradient violetMagentaGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  );

  static const LinearGradient cardPhp = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF190933), Color(0xFF2E1053), Color(0xFF451577)],
  );

  static const LinearGradient cardUsd = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F1E28), Color(0xFF163640), Color(0xFF1F535E)],
  );

  static const LinearGradient cardEur = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D113B), Color(0xFF341764), Color(0xFF4C1D8D)],
  );

  static const LinearGradient mintSuccess = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );
}

class AppConstants {
  // Connection URLs
  static const String defaultLoopbackUrl = 'http://127.0.0.1:8080';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8080';
  static const String localhostUrl = 'http://localhost:8080';

  // Supported Currencies
  static const List<String> supportedCurrencies = ['PHP', 'USD', 'EUR'];

  // Default Currency Symbols
  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'PHP':
      default:
        return '₱';
    }
  }

  // Format currency amount with symbol and 2 decimals
  static String formatCurrency(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$sign$symbol$integerPart.${parts[1]}';
  }

  // Format date time
  static String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$sec';
  }

  static String formatDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
