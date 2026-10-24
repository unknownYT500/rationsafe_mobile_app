// ration_safe_mobile_app/lib/widgets/diagnostic_card.dart
import 'package:flutter/material.dart';
import '../models/failure_diagnostic.dart';
import '../theme/app_theme.dart';
import 'cyber_card.dart';
import 'glowing_badge.dart';

class DiagnosticCard extends StatelessWidget {
  final String? code;
  final String? message;

  const DiagnosticCard({
    super.key,
    required this.code,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final diag = getFailureDiagnostic(code, message);

    Color themeColor;
    IconData icon;
    String sevLabel;

    switch (diag.severity) {
      case DiagnosticSeverity.error:
        themeColor = AppColors.rose500;
        icon = Icons.cancel_rounded;
        sevLabel = 'ERROR';
        break;
      case DiagnosticSeverity.warning:
        themeColor = AppColors.amber500;
        icon = Icons.warning_rounded;
        sevLabel = 'WARNING';
        break;
      case DiagnosticSeverity.info:
        themeColor = AppColors.cyan400;
        icon = Icons.info_rounded;
        sevLabel = 'INFO';
        break;
    }

    return CyberCard(
      borderColor: themeColor.withValues(alpha: 0.6),
      glow: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: themeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diag.title,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GlowingBadge(
                label: sevLabel,
                color: themeColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            diag.explanation,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.cyan400,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, height: 1.4),
                      children: [
                        const TextSpan(
                          text: 'Actionable Remediation: ',
                          style: TextStyle(
                            color: AppColors.cyan400,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: diag.remediation,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
