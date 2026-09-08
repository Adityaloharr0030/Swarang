import 'package:flutter/material.dart';

/// Application color palette.
///
/// Rich, vibrant saffron-to-magenta palette inspired by the energy
/// of Garba nights — warm golds, deep crimsons, and festive magentas.
class AppColors {
  AppColors._();

  // Primary — deep saffron with a hint of crimson
  static const Color primaryLight = Color(0xFFD84315);
  static const Color primaryDark = Color(0xFFFFAB91);

  // Seed color for Material 3 dynamic color scheme
  static const Color seedColor = Color(0xFFD84315);

  // Gradient palette for stat cards and headers
  static const Color gradientStart = Color(0xFFFF6F00);  // Amber deep
  static const Color gradientMid = Color(0xFFE65100);     // Deep orange
  static const Color gradientEnd = Color(0xFFBF360C);     // Burnt sienna

  // Accent gradients for different card types
  static const Color peopleGradientStart = Color(0xFF7B1FA2);  // Purple
  static const Color peopleGradientEnd = Color(0xFFAB47BC);    // Light purple
  static const Color songsGradientStart = Color(0xFFC62828);   // Red
  static const Color songsGradientEnd = Color(0xFFEF5350);     // Light red
  static const Color assignGradientStart = Color(0xFF00695C);  // Teal
  static const Color assignGradientEnd = Color(0xFF26A69A);    // Light teal

  // Semantic colors
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFF9A825);
  static const Color info = Color(0xFF1565C0);

  // Neutral
  static const Color surfaceLight = Color(0xFFFFF8F5);
  static const Color surfaceDark = Color(0xFF1A1110);

  // Glass morphism
  static const Color glassLight = Color(0x30FFFFFF);
  static const Color glassDark = Color(0x20FFFFFF);
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color glassBorderDark = Color(0x15FFFFFF);

  // Shimmer accents for nav bar
  static const Color navGlowLight = Color(0x18D84315);
  static const Color navGlowDark = Color(0x25FFAB91);
}
