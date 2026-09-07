// lib/shared/widgets/glass_card.dart — Glassmorphic card with backdrop blur filter and semi-transparent surface
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: child,
    );

    final Widget filterCard = ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: cardContent,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: filterCard,
      );
    }

    return filterCard;
  }
}
