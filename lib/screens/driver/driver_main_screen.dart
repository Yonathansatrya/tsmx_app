import 'package:flutter/material.dart';

import '../logistics/logistics_delivery_tab.dart';
import '../shared/role_main_screen.dart';

class DriverMainScreen extends StatelessWidget {
  const DriverMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'Driver',
      fallbackUsername: 'Driver',
      onInitialize: (state) async {
        await state.refreshDeliveryNotes();
      },
      screensBuilder: (_) => [const LogisticsDeliveryTab()],
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping_rounded),
          label: 'Delivery',
        ),
      ],
    );
  }
}
