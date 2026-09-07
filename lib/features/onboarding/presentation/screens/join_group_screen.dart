// lib/features/onboarding/presentation/screens/join_group_screen.dart — QR scanner and join group flow with JoinGroupNotifier
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../shared/widgets/avatar_picker_widget.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/qr_scanner_widget.dart';
import '../notifiers/join_group_notifier.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final TextEditingController _nicknameController;
  bool _nicknameInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nicknameInitialized) {
      final l10n = AppLocalizations.of(context)!;
      _nicknameController = TextEditingController(text: l10n.nicknameDefault(2));
      _nicknameInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_nicknameInitialized) {
      _nicknameController.dispose();
    }
    super.dispose();
  }

  void _onScan(String rawValue) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = context.read<JoinGroupNotifier>();
    final success = notifier.processScan(rawValue);
    if (success) {
      _showProfileBottomSheet();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidQr),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  /// Persiste profilo e gruppo, e solo dopo naviga: entrare in una chat il cui
  /// gruppo non è stato salvato porterebbe alla schermata "volo non trovato".
  Future<void> _handleJoin(
    JoinGroupNotifier notifier,
    BuildContext sheetContext,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final nickname = _nicknameController.text.trim().isNotEmpty
        ? _nicknameController.text.trim()
        : l10n.nicknameDefault(2);
    final groupId = notifier.scannedInvite!.groupId;

    try {
      await notifier.confirmJoin(nickname);
    } catch (e) {
      debugPrint('JoinGroupScreen: join non riuscito: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saveFailed),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    if (!mounted) return;
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    context.go('/chat/$groupId');
  }

  void _showProfileBottomSheet() {
    final l10n = AppLocalizations.of(context)!;
    final notifier = context.read<JoinGroupNotifier>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return ChangeNotifierProvider.value(
          value: notifier,
          child: Consumer<JoinGroupNotifier>(
            builder: (context, modalNotifier, _) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.accent, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    AvatarPickerWidget(
                      selectedIndex: modalNotifier.selectedAvatarIndex,
                      onSelected: (index) => modalNotifier.selectAvatar(index),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => _handleJoin(
                        modalNotifier,
                        bottomSheetContext,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                      ),
                      child: Text(l10n.joinChat),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = context.watch<JoinGroupNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinFlight),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          QrScannerWidget(onScan: _onScan),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.scanInstruction,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (notifier.scanSuccess)
            Container(
              color: AppColors.background.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }
}
