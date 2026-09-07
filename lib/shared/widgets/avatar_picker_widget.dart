// lib/shared/widgets/avatar_picker_widget.dart — Grid picker for aviation-themed avatar icons with haptic feedback
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../models/user_profile.dart';

class AvatarPickerWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AvatarPickerWidget({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: UserProfile.avatarIcons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
      ),
      itemBuilder: (context, index) {
        final isSelected = index == selectedIndex;
        final icon = UserProfile.avatarIcons[index];

        // DECISION: 48dp anziché i 44dp del piano. 44 è il minimo Apple ma sta
        // sotto il minimo Material di 48dp, e prima l'area sensibile coincideva
        // col cerchio dentro una cella più larga. IconButton porta anche il
        // ripple di pressione, che il GestureDetector nudo non dava.
        return Center(
          child: Semantics(
            selected: isSelected,
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onSelected(index);
                },
                tooltip: l10n.avatarOptionLabel(index + 1),
                icon: Icon(icon, size: 20.0),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.muted,
                  minimumSize: const Size(48, 48),
                  shape: isSelected
                      ? const CircleBorder(
                          side: BorderSide(
                            color: AppColors.primary,
                            width: 2.0,
                          ),
                        )
                      : const CircleBorder(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
