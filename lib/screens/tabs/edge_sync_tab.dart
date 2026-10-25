// ration_safe_mobile_app/lib/screens/tabs/edge_sync_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';
import '../../models/distribution_node.dart';

class EdgeSyncTab extends StatelessWidget {
  const EdgeSyncTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final activeNode = state.nodes.firstWhere(
      (n) => n.id == state.selectedNodeId,
      orElse: () => state.nodes.isNotEmpty
          ? state.nodes.first
          : NodeItem(
              id: 'node-alpha-001',
              name: 'Sector 4 Community Depot',
              publicKey: '',
              status: 'ONLINE',
              lastHeartbeat: '',
              outboxDepth: 0,
              location: 'Kanpur Urban Sector 4',
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Terminal Outbox Header Card
          CyberCard(
            borderColor: state.outboxDepth > 0 ? AppColors.amber500 : AppColors.borderAccent,
            glow: state.outboxDepth > 0,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.cyan400.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sync_alt_rounded, size: 20, color: AppColors.cyan400),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeNode.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Terminal ID: ${activeNode.id}',
                              style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GlowingBadge(
                      label: state.isOnline ? 'ONLINE' : 'OFFLINE',
                      color: state.isOnline ? AppColors.emerald400 : AppColors.rose400,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PENDING OUTBOX DEPTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${state.outboxDepth}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: state.outboxDepth > 0 ? AppColors.amber400 : AppColors.emerald400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.outboxDepth == 1 ? 'provisional token queued' : 'provisional tokens queued',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GlowingBadge(
                      label: state.outboxDepth > 0 ? 'SYNC REQUIRED' : 'UP TO DATE',
                      color: state.outboxDepth > 0 ? AppColors.amber400 : AppColors.emerald400,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Outbox Queue Metrics (Chunking & DLQ Diagnostics)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _queuePill('Pending', '${state.outboxStats['PENDING'] ?? 0}', AppColors.cyan400),
                          _queuePill('Retrying', '${state.outboxStats['RETRYING'] ?? 0}', AppColors.amber400),
                          _queuePill('Dead-Letter', '${state.outboxStats['DEAD_LETTER'] ?? 0}', (state.outboxStats['DEAD_LETTER'] ?? 0) > 0 ? AppColors.rose500 : AppColors.textDim),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Chunked Cursor Streaming: 50 items/batch · Exp Backoff with Randomized Jitter',
                        style: TextStyle(color: AppColors.textDim, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Batch Sync Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isOnline && state.outboxDepth > 0
                          ? AppColors.cyan400
                          : AppColors.bgSecondary,
                      foregroundColor: state.isOnline && state.outboxDepth > 0
                          ? Colors.black
                          : AppColors.textDim,
                      side: BorderSide(
                        color: state.isOnline && state.outboxDepth > 0
                            ? AppColors.cyan400
                            : AppColors.borderSubtle,
                      ),
                    ),
                    onPressed: !state.isOnline || state.syncLoading || state.outboxDepth == 0
                        ? null
                        : () => state.triggerBatchSync(),
                    child: state.syncLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.cloud_upload_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Trigger Chunked Batch Sync', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                  ),
                ),

                if (state.syncNotice != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.emerald400, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.syncNotice!,
                            style: const TextStyle(color: AppColors.emerald400, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Dead-Letter Queue (DLQ) Quarantine Alert
                if (state.deadLetterTokens.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.rose500.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.rose500, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${state.deadLetterTokens.length} Token(s) in Dead-Letter Queue (DLQ)',
                              style: const TextStyle(
                                color: AppColors.rose500,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Quarantined after repeated failures or irrecoverable rejection. Healthy queue items remain unblocked.',
                          style: TextStyle(color: AppColors.textDim, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              for (final dlq in state.deadLetterTokens) {
                                final id = dlq['id']?.toString();
                                if (id != null) await state.requeueDeadLetterToken(id);
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 14, color: AppColors.cyan400),
                            label: const Text('Re-queue All for Retry', style: TextStyle(color: AppColors.cyan400, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Network Node Registry Table / Cards
          const Text(
            'REGISTERED DISTRIBUTION NODES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 10),

          ...state.nodes.map((node) {
            final isSelected = node.id == state.selectedNodeId;
            final truncKey = node.publicKey.length > 20
                ? '${node.publicKey.substring(0, 16)}...${node.publicKey.substring(node.publicKey.length - 8)}'
                : node.publicKey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CyberCard(
                borderColor: isSelected ? AppColors.cyan400 : AppColors.borderSubtle,
                glow: isSelected,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          node.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppColors.cyan400 : AppColors.textMain,
                          ),
                        ),
                        GlowingBadge(
                          label: node.status,
                          color: node.isOnline ? AppColors.emerald400 : AppColors.rose400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      node.location,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key_outlined, size: 12, color: AppColors.cyan400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ed25519 PubKey: $truncKey',
                              style: const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget _queuePill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textDim,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
