import 'package:flutter/material.dart';
import '../shared/role_main_screen.dart';
import 'logistics_delivery_tab.dart';
import 'logistics_overview_tab.dart';
import 'logistics_tracking_tab.dart';

class LogisticsMainScreen extends StatelessWidget {
  const LogisticsMainScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMainScreen(
    title: 'TMSX LOGISTICS',
    fallbackUsername: 'Logistics',
    onInitialize: (state) async {
      await Future.wait([
        state.refreshDeliveryNotes(),
        state.refreshSalesOrders(),
      ]);
    },
    screensBuilder: (onMenuSelected) => [
      LogisticsOverviewTab(onMenuSelected: onMenuSelected),
      const LogisticsTrackingTab(),
      const LogisticsDeliveryTab(),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.route_outlined),
        selectedIcon: Icon(Icons.route_rounded),
        label: 'Armada',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_turned_in_outlined),
        selectedIcon: Icon(Icons.assignment_turned_in_rounded),
        label: 'Delivery',
      ),
    ],
  );
}
