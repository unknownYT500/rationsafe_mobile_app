// ration_safe_mobile_app/lib/screens/tabs/audit_log_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';

class AuditLogTab extends StatelessWidget {
  const AuditLogTab({super.key});

  String _formatLocalTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return isoString.length > 19
          ? isoString.substring(0, 19).replaceAll('T', ' ')
          : isoString;
    }
  }

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
              Expanded(
                child: Text(
                  'IMMUTABLE AUDIT LOG',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
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
                          Flexible(
                            child: GlowingBadge(
                              label: log.action,
                              color: actionColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatLocalTimestamp(log.timestamp),
                            style: const TextStyle(
                              color: AppColors.textDim,
                              fontSize: 10.5,
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
                          Flexible(
                            child: Text(
                              'Actor: ${log.actorId}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.link_rounded, size: 14, color: AppColors.textDim),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${log.resourceType}: ${log.resourceId}',
                              style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
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
