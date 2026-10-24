// ration_safe_mobile_app/lib/screens/tabs/audit_log_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';

class AuditLogTab extends StatelessWidget {
  const AuditLogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'IMMUTABLE AUDIT LOG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textDim,
                ),
              ),
              GlowingBadge(
                label: 'APPEND-ONLY SECURE',
                color: AppColors.emerald400,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (state.auditLogs.isEmpty)
            CyberCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No audit events recorded yet.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            ...state.auditLogs.map((log) {
              Color actionColor = AppColors.cyan400;
              if (log.action.contains('APPROV')) {
                actionColor = AppColors.emerald400;
              } else if (log.action.contains('DISPENSE')) {
                actionColor = AppColors.emerald500;
              } else if (log.action.contains('RESET')) {
                actionColor = AppColors.rose500;
              } else if (log.action.contains('SYNC')) {
                actionColor = AppColors.amber400;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CyberCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlowingBadge(
                            label: log.action,
                            color: actionColor,
                          ),
                          Text(
                            log.timestamp.length > 19
                                ? log.timestamp.substring(0, 19).replaceAll('T', ' ')
                                : log.timestamp,
                            style: const TextStyle(
                              color: AppColors.textDim,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_circle_outlined, size: 14, color: AppColors.textDim),
                          const SizedBox(width: 5),
                          Text(
                            'Actor: ${log.actorId}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.link_rounded, size: 14, color: AppColors.textDim),
                          const SizedBox(width: 5),
                          Text(
                            '${log.resourceType}: ${log.resourceId}',
                            style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                          ),
                        ],
                      ),
                      if (log.details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgPrimary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            jsonEncode(log.details),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
