// ration_safe_mobile_app/lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_navbar.dart';
import 'tabs/dispense_tab.dart';
import 'tabs/registration_tab.dart';
import 'tabs/edge_sync_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/audit_log_tab.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    final screens = const [
      DispenseTab(),
      RegistrationTab(),
      EdgeSyncTab(),
      InventoryTab(),
      AuditLogTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Top Header & Terminal Controls
            const TopNavbarWidget(),

            // Active Tab Content
            Expanded(
              child: IndexedStack(
                index: state.activeTabIndex,
                children: screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: NavigationBar(
          selectedIndex: state.activeTabIndex,
          onDestinationSelected: (idx) => state.setActiveTab(idx),
          backgroundColor: AppColors.bgSecondary,
          indicatorColor: AppColors.cyan400.withValues(alpha: 0.2),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.grain, color: AppColors.textDim),
              selectedIcon: Icon(Icons.grain, color: AppColors.cyan400),
              label: 'Dispense',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: AppColors.textDim),
              selectedIcon: Icon(Icons.people_rounded, color: AppColors.cyan400),
              label: 'Cards',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: state.outboxDepth > 0,
                label: Text('${state.outboxDepth}'),
                backgroundColor: AppColors.amber500,
                child: const Icon(Icons.sync_rounded, color: AppColors.textDim),
              ),
              selectedIcon: Badge(
                isLabelVisible: state.outboxDepth > 0,
                label: Text('${state.outboxDepth}'),
                backgroundColor: AppColors.amber500,
                child: const Icon(Icons.sync_rounded, color: AppColors.cyan400),
              ),
              label: 'Sync',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, color: AppColors.textDim),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.cyan400),
              label: 'Stockpile',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_edu_rounded, color: AppColors.textDim),
              selectedIcon: Icon(Icons.history_edu_rounded, color: AppColors.cyan400),
              label: 'Audit Log',
            ),
          ],
        ),
      ),
    );
  }
}
