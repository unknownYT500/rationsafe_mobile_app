// ration_safe_mobile_app/lib/widgets/state_stepper.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StateStepperWidget extends StatelessWidget {
  final String currentState;

  const StateStepperWidget({
    super.key,
    required this.currentState,
  });

  static const List<Map<String, dynamic>> _stages = [
    {
      'state': 'ATTEMPT',
      'label': 'Attempt',
      'icon': Icons.play_arrow_rounded,
      'color': AppColors.stateAttempt,
    },
    {
      'state': 'FAIL_REASON',
      'label': 'Fail Reason',
      'icon': Icons.warning_amber_rounded,
      'color': AppColors.stateFail,
    },
    {
      'state': 'FALLBACK_AUTH',
      'label': 'Fallback Auth',
      'icon': Icons.admin_panel_settings_outlined,
      'color': AppColors.stateFallback,
    },
    {
      'state': 'PROVISIONAL_ISSUE',
      'label': 'Provisional',
      'icon': Icons.schedule_rounded,
      'color': AppColors.stateProvisional,
    },
    {
      'state': 'RECONCILED',
      'label': 'Reconciled',
      'icon': Icons.check_circle_rounded,
      'color': AppColors.stateReconciled,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '5-STAGE TRANSACTION LIFECYCLE',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _stages.map((stage) {
                final isCurrent = stage['state'] == currentState;
                final color = stage['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? color.withValues(alpha: 0.18) : AppColors.bgPrimary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? color : AppColors.borderSubtle,
                        width: isCurrent ? 1.5 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stage['icon'] as IconData,
                          size: 14,
                          color: isCurrent ? color : AppColors.textDim,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stage['label'] as String,
                          style: TextStyle(
                            color: isCurrent ? color : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
