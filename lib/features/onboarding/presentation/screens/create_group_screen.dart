// lib/features/onboarding/presentation/screens/create_group_screen.dart — Group creation UI reading state from CreateGroupNotifier
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../shared/widgets/animated_gradient_bg.dart';
import '../../../../shared/widgets/avatar_picker_widget.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/qr_display_widget.dart';
import '../notifiers/create_group_notifier.dart';
import '../../models/group_invite.dart';
import '../../../../core/constants/app_constants.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  late final TextEditingController _nicknameController;
  bool _nicknameInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nicknameInitialized) {
      final l10n = AppLocalizations.of(context)!;
      _nicknameController = TextEditingController(text: l10n.captainDefault);
      _nicknameInitialized = true;
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    if (_nicknameInitialized) {
      _nicknameController.dispose();
    }
    super.dispose();
  }

  void _handleGenerateQr() {
    final notifier = context.read<CreateGroupNotifier>();
    final l10n = AppLocalizations.of(context)!;
    final nickname = _nicknameController.text.trim().isNotEmpty
        ? _nicknameController.text.trim()
        : l10n.captainDefault;
    notifier.generateQr(
      nickname,
      groupName: _groupNameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = context.watch<CreateGroupNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createFlight),
      ),
      body: AnimatedGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notifier.qrData == null) ...[
                  TextField(
                    controller: _groupNameController,
                    maxLength: GroupInvite.maxGroupNameLength,
                    decoration: InputDecoration(
                      hintText: l10n.groupNameHint,
                      prefixIcon: const Icon(Icons.flight),
                    ),
                    // Contatore nascosto finché il limite non è vicino, come
                    // per l'input della chat.
                    buildCounter: (
                      context, {
                      required int currentLength,
                      required bool isFocused,
                      int? maxLength,
                    }) {
                      if (maxLength == null || currentLength < maxLength * 0.9) {
                        return null;
                      }
                      return Text(
                        '$currentLength/$maxLength',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: l10n.nicknameHint,
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.chooseAvatar,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  AvatarPickerWidget(
                    selectedIndex: notifier.selectedAvatarIndex,
                    onSelected: (index) => notifier.selectAvatar(index),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _handleGenerateQr,
                    child: Text(l10n.generateQr),
                  ),
                ] else ...[
                  Center(
                    child: QrDisplayWidget(data: notifier.qrData!),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.go(
                        '/chat/${notifier.generatedGroupId}',
                        extra: {
                          AppConstants.extraProfile: notifier.localProfile,
                          AppConstants.extraGroupName: notifier.groupName,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.continueToChat),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
