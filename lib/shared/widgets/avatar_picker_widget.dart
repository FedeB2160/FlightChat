// lib/shared/widgets/avatar_picker_widget.dart — Grid picker for aviation-themed avatar icons with haptic feedback
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onSelected(index);
          },
          child: AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.muted,
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2.0)
                    : null,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20.0,
              ),
            ),
          ),
        );
      },
    );
  }
}
