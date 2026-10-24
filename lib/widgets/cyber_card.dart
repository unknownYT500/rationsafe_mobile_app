// ration_safe_mobile_app/lib/widgets/cyber_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final bool glow;
  final VoidCallback? onTap;

  const CyberCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(
        borderColor: borderColor,
        glow: glow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
