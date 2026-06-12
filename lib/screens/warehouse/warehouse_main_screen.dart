import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../profile_screen.dart';
import 'warehouse_inventory_tab.dart';
import 'warehouse_operations_tab.dart';
import 'warehouse_overview_tab.dart';
import 'warehouse_quality_tab.dart';

class WarehouseMainScreen extends StatefulWidget {
  const WarehouseMainScreen({super.key});

  @override
  State<WarehouseMainScreen> createState() => _WarehouseMainScreenState();
}

class _WarehouseMainScreenState extends State<WarehouseMainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    WarehouseOverviewTab(onMenuSelected: _changeTab),
    const WarehouseOperationsTab(),
    const WarehouseInventoryTab(),
    const WarehouseQualityTab(),
  ];

  void _changeTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      await Future.wait([
        state.refreshWarehouses(),
        state.refreshInventory(),
        state.refreshStockEntries(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 14,
        title: Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TMSX WAREHOUSE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    state.currentUser ?? 'Warehouse',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _changeTab,
          height: 64,
          elevation: 0,
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.softGreen,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz_rounded),
              label: 'Operasi',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stok',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check_rounded),
              label: 'QC',
            ),
          ],
        ),
      ),
    );
  }
}
