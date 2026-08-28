import 'package:flutter/material.dart';

/// Cooperative Bank of Oromia (CBO) Corporate Brand Colors & Futuristic OmniRecon Tokens
class CboColors {
  CboColors._();

  // Primary CBO Brand & Cyber Accents
  static const Color primaryBlue = Color(0xFF003366);
  static const Color primaryCyan = Color(0xFF009688);
  static const Color primaryCyanDark = Color(0xFF00695C);
  static const Color primaryCyanLight = Color(0xFF4DB6AC);
  static const Color primaryCyanUltraLight = Color(0xFFE0F2F1);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color electricTeal = Color(0xFF00B4D8);

  // Secondary & Functional FinTech Accents
  static const Color accentGold = Color(0xFFE6A100);
  static const Color accentGoldLight = Color(0xFFFFF8E1);
  static const Color neonGold = Color(0xFFFFB703);

  static const Color bankGreen = Color(0xFF2E7D32);
  static const Color bankGreenLight = Color(0xFFE8F5E9);
  static const Color neonGreen = Color(0xFF00E676);

  static const Color alertRed = Color(0xFFD32F2F);
  static const Color alertRedLight = Color(0xFFFFEBEE);
  static const Color neonCrimson = Color(0xFFFF1744);

  static const Color cyberPurple = Color(0xFF7C3AED);
  static const Color cyberPurpleLight = Color(0xFFEDE9FE);
  static const Color cyberIndigo = Color(0xFF4F46E5);

  // Neutral & Surface Colors (Light Mode)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Dark & Futuristic HUD Palette (Dark Mode & Cyber Glass)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassGlowCyan = Color(0x2600E5FF);

  // Text & Slate Shades
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMedium = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);
  static const Color slateUltraLight = Color(0xFFF1F5F9);

  // Reconciliation Status Design Tokens
  static const Color statusOkBg = Color(0xFFE8F5E9);
  static const Color statusOkText = Color(0xFF1B5E20);
  static const Color statusOkGlow = Color(0xFF00E676);

  static const Color statusMismatchBg = Color(0xFFFFF9C4);
  static const Color statusMismatchText = Color(0xFFF57F17);
  static const Color statusMismatchGlow = Color(0xFFFFB703);

  static const Color statusMissingBg = Color(0xFFFFEBEE);
  static const Color statusMissingText = Color(0xFFC62828);
  static const Color statusMissingGlow = Color(0xFFFF1744);

  static const Color statusPendingBg = Color(0xFFF3E8FF);
  static const Color statusPendingText = Color(0xFF6B21A8);

  // Futuristic Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF009688), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFF00796B), Color(0xFF0284C7), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFE6A100), Color(0xFFFFB703)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
