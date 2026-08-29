import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class PulseLoadingIndicator extends StatelessWidget {
  final double size;
  final String? message;

  const PulseLoadingIndicator({
    Key? key,
    this.size = 90,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animation/loading.json',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return CircularProgressIndicator(
                  color: PulseColors.accentPrimary,
                  strokeWidth: 3,
                );
              },
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: PulseTypography.bodyMedium.copyWith(
                color: PulseColors.textSecondary,
              ),
            ).animate().fadeIn(duration: 300.ms),
          ]
        ],
      ),
    );
  }
}

class PulseCelebrationDialog extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onDismiss;

  const PulseCelebrationDialog({
    Key? key,
    required this.title,
    required this.description,
    this.onDismiss,
  }) : super(key: key);

  static void show(BuildContext context, {required String title, required String description}) {
    showDialog(
      context: context,
      builder: (ctx) => PulseCelebrationDialog(
        title: title,
        description: description,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PulseColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PulseColors.accentPrimary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              child: Lottie.asset(
                'assets/animation/party_celebration.json',
                repeat: false,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Icon(
                  Icons.celebration_rounded,
                  size: 80,
                  color: PulseColors.accentPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PulseTypography.displayMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyMedium.copyWith(color: PulseColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
    );
  }
}

class PulseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const PulseEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PulseColors.surfaceHigh.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(icon, size: 48, color: PulseColors.accentPrimary),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyMedium.copyWith(color: PulseColors.textSecondary),
            ).animate().fadeIn(delay: 200.ms),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!.animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}
