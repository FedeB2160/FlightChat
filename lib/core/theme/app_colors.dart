// lib/core/theme/app_colors.dart — Design system color palette and semantic tokens
import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primary = Color(0xFF2563EB);       // Azioni, bubble propria
  static const Color onPrimary = Color(0xFFFFFFFF);      // Testo su primary
  static const Color secondary = Color(0xFF6366F1);      // Accenti, stato
  // DECISION: token fuori dalla palette del piano. `secondary` su `surface` dà 4.07:1,
  // sotto il minimo WCAG AA di 4.5:1 per il nickname mittente (bodySmall 12px).
  // Questa variante più chiara sullo stesso hue dà 6.09:1.
  static const Color secondaryLight = Color(0xFF818CF8); // Nickname mittente su surface
  static const Color accent = Color(0xFF059669);          // Online, conferma, successo
  static const Color background = Color(0xFF0F172A);      // Sfondo app
  static const Color surface = Color(0xFF111827);          // Card, bubble altrui
  static const Color muted = Color(0xFF1E293B);            // Input, separatori
  static const Color foreground = Color(0xFFF8FAFC);       // Testo primario
  static const Color mutedForeground = Color(0xFFCBD5E1);  // Testo secondario
  static const Color border = Color(0xFF334155);            // Bordi, divider
  static const Color destructive = Color(0xFFDC2626);       // Errori
  static const Color onDestructive = Color(0xFFFFFFFF);     // Testo su errori
}
