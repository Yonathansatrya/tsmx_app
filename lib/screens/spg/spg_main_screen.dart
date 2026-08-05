import 'package:flutter/material.dart';

import '../sales/sales_visit_tab.dart';
import '../shared/role_main_screen.dart';
import 'spg_daily_activity_tab.dart';
import 'spg_daily_report_tab.dart';

class SpgMainScreen extends StatelessWidget {
  const SpgMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'SPG',
      fallbackUsername: 'SPG',
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on_rounded),
          label: 'Kunjungan',
        ),
        NavigationDestination(
          icon: Icon(Icons.photo_camera_outlined),
          selectedIcon: Icon(Icons.photo_camera_rounded),
          label: 'Foto',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Selling',
        ),
      ],
      screensBuilder: (_) => const [
        SalesVisitTab(showCheckIn: false, spgMode: true),
        SpgDailyActivityTab(),
        SpgDailyReportTab(),
      ],
    );
  }
}
