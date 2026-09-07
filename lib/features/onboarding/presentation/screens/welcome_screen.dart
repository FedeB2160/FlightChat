// lib/features/onboarding/presentation/screens/welcome_screen.dart — Welcome screen with staggered entrance animations, pulsing logo, and navigation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../shared/widgets/animated_gradient_bg.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _entranceController;
  late final List<Animation<double>> _staggerAnimations;

  @override
  void initState() {
    super.initState();
    // Repeating gentle pulse on the logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Staggered entrance animation: ~100ms delay per component
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    const stepCount = 6;
    _staggerAnimations = List.generate(stepCount, (i) {
      final start = (i * 0.1).clamp(0.0, 0.5);
      final end = (start + 0.45).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _entranceController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildStagger({required int index, required Widget child}) {
    final animation = _staggerAnimations[index];
    final slideTween = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero);
    return SlideTransition(
      position: slideTween.animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _buildStagger(
                  index: 0,
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/logo/flightchat_logo.svg',
                        width: 120,
                        height: 120,
                        placeholderBuilder: (context) => const Icon(
                          Icons.airplanemode_active,
                          size: 120,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildStagger(
                  index: 1,
                  child: Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStagger(
                  index: 2,
                  child: Text(
                    l10n.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStagger(
                  index: 3,
                  child: GlassCard(
                    onTap: () => context.push('/create'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flight_takeoff, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          l10n.createFlight,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStagger(
                  index: 4,
                  child: GlassCard(
                    onTap: () => context.push('/join'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Text(
                          l10n.joinFlight,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildStagger(
                  index: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth, color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        l10n.bluetoothActive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
