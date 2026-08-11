import 'package:flutter/material.dart';

import '../shared/role_main_screen.dart';
import 'daily_activity/spg_daily_activity_tab.dart';
import 'daily_report/spg_daily_report_tab.dart';
import 'overview/spg_overview_tab.dart';
import 'visit/spg_visit_tab.dart';

class SpgMainScreen extends StatelessWidget {
  const SpgMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'SPG',
      fallbackUsername: 'SPG',
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on_rounded),
          label: 'Absensi',
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
      screensBuilder: (onMenuSelected) => [
        SpgOverviewTab(onMenuSelected: onMenuSelected),
        const SpgVisitTab(showCheckIn: false),
        const SpgDailyActivityTab(),
        const SpgDailyReportTab(),
      ],
    );
  }
}
