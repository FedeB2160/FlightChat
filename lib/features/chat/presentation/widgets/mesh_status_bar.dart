// lib/features/chat/presentation/widgets/mesh_status_bar.dart — Status pill showing mesh network connectivity and node count
import 'package:flutter/material.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class MeshStatusBar extends StatelessWidget {
  final int connectedNodes;

  const MeshStatusBar({super.key, required this.connectedNodes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool hasNodes = connectedNodes > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasNodes ? AppColors.accent.withValues(alpha: 0.5) : AppColors.muted,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasNodes ? AppColors.accent : AppColors.mutedForeground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.nodesConnected(connectedNodes),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: hasNodes ? AppColors.accent : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
