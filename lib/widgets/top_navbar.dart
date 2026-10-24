// ration_safe_mobile_app/lib/widgets/top_navbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class TopNavbarWidget extends StatelessWidget {
  const TopNavbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Row 1: Brand Logo + Status Controls
          Row(
            children: [
              // Brand Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.emerald500, AppColors.cyan500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald500.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.grain, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'GrainTrust',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'AUTONOMOUS PDS TERMINAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.cyan400,
                      ),
                    ),
                  ],
                ),
              ),

              // Online / Offline Mode Toggle Pill
              InkWell(
                onTap: () => state.toggleOnline(),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.isOnline
                        ? AppColors.emerald500.withValues(alpha: 0.15)
                        : AppColors.rose500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.isOnline ? AppColors.emerald500 : AppColors.rose500,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 14,
                        color: state.isOnline ? AppColors.emerald400 : AppColors.rose400,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: state.isOnline ? AppColors.emerald400 : AppColors.rose400,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Terminal Selector & Role Dropdown & Clear DB
          Row(
            children: [
              // Terminal Selector Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedNodeId,
                      dropdownColor: AppColors.bgSecondary,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMain),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.cyan400, size: 18),
                      items: [
                        DropdownMenuItem(
                          value: 'node-alpha-001',
                          child: Text(
                            'Sector 4 Community Depot',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: state.selectedNodeId == 'node-alpha-001'
                                  ? AppColors.cyan400
                                  : AppColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'node-beta-002',
                          child: Text(
                            'Rural Outpost Station 9',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: state.selectedNodeId == 'node-beta-002'
                                  ? AppColors.amber400
                                  : AppColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) state.setSelectedNodeId(val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Role Selector Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.activeRole,
                      dropdownColor: AppColors.bgSecondary,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMain),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textDim, size: 16),
                      items: const [
                        DropdownMenuItem(value: 'DISTRIBUTION_OPERATOR', child: Text('Distribution Op')),
                        DropdownMenuItem(value: 'REGISTRATION_OPERATOR', child: Text('Registration Op')),
                        DropdownMenuItem(value: 'SUPERVISOR', child: Text('Supervisor')),
                        DropdownMenuItem(value: 'AUDITOR', child: Text('Auditor')),
                        DropdownMenuItem(value: 'ADMINISTRATOR', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) state.setActiveRole(val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Clear DB Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textDim),
                tooltip: 'Reset Ledger',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.bgSecondary,
                      title: const Text('Reset Central Database?'),
                      content: const Text(
                        'This will reset all central records, erase local outboxes, and re-seed the depot and lots. Continue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500),
                          onPressed: () {
                            Navigator.pop(ctx);
                            state.resetDatabase();
                          },
                          child: const Text('Reset DB'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          // Offline Alert Banner
          if (!state.isOnline) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber500.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.amber400),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Terminal operating in Autonomous Edge mode. Issuances will be signed locally with Ed25519.',
                      style: TextStyle(color: AppColors.amber400, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
