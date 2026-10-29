// ration_safe_mobile_app/lib/screens/tabs/dispense_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';
import '../../widgets/state_stepper.dart';
import '../../widgets/diagnostic_card.dart';
import '../../widgets/token_qr_dialog.dart';
import '../../models/beneficiary.dart';
import '../../models/provisional_token.dart';

class DispenseTab extends StatelessWidget {
  const DispenseTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final activeCard = state.cards.firstWhere(
      (c) => c.id == state.selectedCardId,
      orElse: () => state.cards.isNotEmpty
          ? state.cards.first
          : const CardBeneficiary(
              id: '',
              personId: '',
              status: 'ACTIVE',
              issuedAt: '',
              firstName: 'No Cards',
              lastName: '',
              fullName: 'No Beneficiary Enrolled',
              phoneNumber: '',
              familyCount: 0,
              address: '',
              city: '',
              state: '',
              allocatedQty: 0,
              consumedQty: 0,
              remainingQty: 0,
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Beneficiary Card Picker
          CyberCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SELECT BENEFICIARY CARD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textDim,
                      ),
                    ),
                    InkWell(
                      onTap: () => state.setActiveTab(1), // Switch to Registration Tab
                      child: Row(
                        children: const [
                          Icon(Icons.add_circle_outline, size: 14, color: AppColors.cyan400),
                          SizedBox(width: 4),
                          Text(
                            'Register Citizen',
                            style: TextStyle(color: AppColors.cyan400, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.cards.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.amber400),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No approved cards enrolled. Register and approve a citizen first.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => state.setActiveTab(1),
                          child: const Text('Enroll', style: TextStyle(color: AppColors.cyan400, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.selectedCardId.isEmpty ? state.cards.first.id : state.selectedCardId,
                        dropdownColor: AppColors.bgSecondary,
                        isExpanded: true,
                        items: state.cards.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Row(
                              children: [
                                const Icon(Icons.credit_card_rounded, size: 16, color: AppColors.cyan400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${c.fullName} (${c.id})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                GlowingBadge(
                                  label: '${c.remainingQty.toStringAsFixed(1)} kg left',
                                  color: c.remainingQty > 0 ? AppColors.emerald400 : AppColors.rose400,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) state.setSelectedCardId(val);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Beneficiary Details & Quota Progress Gauge
          if (activeCard.id.isNotEmpty) ...[
            CyberCard(
              borderColor: AppColors.borderAccent,
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
                            child: const Icon(Icons.person_rounded, size: 18, color: AppColors.cyan400),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeCard.fullName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${activeCard.phoneNumber} · Family: ${activeCard.familyCount}',
                                style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GlowingBadge(
                        label: activeCard.status,
                        color: activeCard.status == 'ACTIVE' ? AppColors.emerald400 : AppColors.rose500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  const SizedBox(height: 14),

                  // Quota Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Quota Entitlement',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${activeCard.consumedQty.toStringAsFixed(1)} / ${activeCard.allocatedQty.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: AppColors.cyan400,
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
                      value: activeCard.allocatedQty > 0
                          ? (activeCard.consumedQty / activeCard.allocatedQty).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: AppColors.bgPrimary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        activeCard.remainingQty > 0 ? AppColors.emerald500 : AppColors.rose500,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statPill('Allocated', '${activeCard.allocatedQty.toStringAsFixed(1)} kg', AppColors.textMuted),
                      _statPill('Consumed', '${activeCard.consumedQty.toStringAsFixed(1)} kg', AppColors.amber400),
                      _statPill('Remaining', '${activeCard.remainingQty.toStringAsFixed(1)} kg', AppColors.emerald400),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Dispense Parameters (Lot, Quantity, Supervisor Fallback)
          CyberCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISPENSE PARAMETERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 12),

                // Lot Selector
                const Text('Select Grain Stockpile Lot', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.distLotId.isEmpty && state.lots.isNotEmpty
                          ? state.lots.first.id
                          : state.distLotId,
                      dropdownColor: AppColors.bgSecondary,
                      isExpanded: true,
                      items: state.lots.map((l) {
                        return DropdownMenuItem<String>(
                          value: l.id,
                          child: Text(
                            '${l.name} (${l.remainingQuantity.toStringAsFixed(1)} kg left)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) state.setDistLotId(val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Requested Quantity with Stepper
                const Text('Requested Quantity (kg)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stepperButton(
                      icon: Icons.remove,
                      onPressed: () => state.setDistQuantity(state.distQuantity - 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cyan400.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${state.distQuantity.toStringAsFixed(1)} kg',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.cyan400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _stepperButton(
                      icon: Icons.add,
                      onPressed: () => state.setDistQuantity(state.distQuantity + 0.5),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Supervisor Fallback Checkbox
                InkWell(
                  onTap: () => state.setDistAllowFallback(!state.distAllowFallback),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: state.distAllowFallback,
                          activeColor: AppColors.purple500,
                          onChanged: (v) => state.setDistAllowFallback(v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'Supervisor Offline Fallback Override (Allows issue if quota depleted)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Issue Button CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isOnline ? AppColors.emerald500 : AppColors.amber500,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: state.distLoading
                        ? null
                        : () {
                            if (activeCard.id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No active beneficiary card selected. Please enroll and approve a citizen first.'),
                                  backgroundColor: AppColors.rose500,
                                ),
                              );
                              return;
                            }
                            if (state.lots.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No grain stockpile lots available. Ensure lots are seeded in the database.'),
                                  backgroundColor: AppColors.rose500,
                                ),
                              );
                              return;
                            }
                            state.executeDispense(
                              cardId: activeCard.id,
                              lotId: state.distLotId.isNotEmpty
                                  ? state.distLotId
                                  : (state.lots.isNotEmpty ? state.lots.first.id : ''),
                            );
                          },
                    child: state.distLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                state.isOnline ? Icons.check_circle_outline : Icons.edit_document,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                state.isOnline
                                    ? 'Issue Grain (Online Reconciled)'
                                    : 'Issue Grain (Sign Provisional Token)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. 5-State Lifecycle Stepper
          StateStepperWidget(currentState: state.distCurrentState),

          const SizedBox(height: 14),

          // 5. Diagnostics & Execution Summary Card
          if (state.distExecutionSummary != null) ...[
            if (state.distExecutionSummary!['success'] == false) ...[
              DiagnosticCard(
                code: state.distExecutionSummary!['code']?.toString(),
                message: state.distExecutionSummary!['message']?.toString(),
              ),
            ] else ...[
              CyberCard(
                borderColor: state.isOnline ? AppColors.emerald500 : AppColors.amber500,
                glow: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: state.isOnline ? AppColors.emerald400 : AppColors.amber400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.isOnline
                                  ? 'Grain Dispense Successful'
                                  : 'Provisional Token Generated',
                              style: TextStyle(
                                color: state.isOnline ? AppColors.emerald400 : AppColors.amber400,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        GlowingBadge(
                          label: state.distCurrentState,
                          color: state.isOnline ? AppColors.emerald400 : AppColors.amber400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.distExecutionSummary!['message'] ??
                          'The transaction has been committed and verified in the ledger.',
                      style: const TextStyle(color: AppColors.textMain, fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    if (state.distExecutionSummary!['token'] != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code, size: 16, color: AppColors.cyan400),
                          label: const Text('View Signed Token QR Receipt'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.cyan400),
                            foregroundColor: AppColors.cyan400,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => TokenQrDialog(
                                token: state.distExecutionSummary!['token'] as SignedProvisionalToken,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.cyan400, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
