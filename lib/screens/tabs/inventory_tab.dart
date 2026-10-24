// ration_safe_mobile_app/lib/screens/tabs/inventory_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

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
                'CENTRAL GRAIN STOCKPILES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textDim,
                ),
              ),
              GlowingBadge(
                label: 'GOVERNMENT RESERVES',
                color: AppColors.cyan400,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (state.lots.isEmpty)
            CyberCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No grain stockpile lots available.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            ...state.lots.map((lot) {
              final pct = lot.totalQuantity > 0 ? (lot.remainingQuantity / lot.totalQuantity) : 0.0;
              final isWheat = lot.grainType.toUpperCase().contains('WHEAT');

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: CyberCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: isWheat ? AppColors.amber500.withValues(alpha: 0.3) : AppColors.cyan400.withValues(alpha: 0.3),
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
                                  color: (isWheat ? AppColors.amber400 : AppColors.cyan400).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  size: 18,
                                  color: isWheat ? AppColors.amber400 : AppColors.cyan400,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lot.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Lot ID: ${lot.id}',
                                    style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GlowingBadge(
                            label: lot.grainType.toUpperCase(),
                            color: isWheat ? AppColors.amber400 : AppColors.cyan400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AppColors.borderSubtle, height: 1),
                      const SizedBox(height: 14),

                      // Capacity Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Warehouse Stock',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            '${lot.remainingQuantity.toStringAsFixed(1)} / ${lot.totalQuantity.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: AppColors.bgPrimary,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct > 0.25 ? AppColors.emerald500 : AppColors.rose500,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statBox('Total Batch', '${lot.totalQuantity.toStringAsFixed(0)} kg'),
                          _statBox('Dispensed', '${(lot.totalQuantity - lot.remainingQuantity).toStringAsFixed(0)} kg'),
                          _statBox('Remaining', '${lot.remainingQuantity.toStringAsFixed(0)} kg'),
                        ],
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

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          Text(value, style: const TextStyle(color: AppColors.textMain, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
