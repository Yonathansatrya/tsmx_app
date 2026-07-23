import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'inactive_customer_tab.dart';
import 'noo_request_tab.dart';
import 'promo_session_tab.dart';
import 'sales_ui.dart';

class CustomerRequestTab extends StatelessWidget {
  const CustomerRequestTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SalesPillTabBar(
                tabs: const [
                  Tab(text: 'Inactive'),
                  Tab(text: 'NOO'),
                  Tab(text: 'Promo Session'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  InactiveCustomerTab(),
                  NooRequestTab(),
                  PromoSessionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
