import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../shared/role_main_screen.dart';
import '../tabs/selling_tab.dart';
import 'create_sales_order_screen.dart';
import 'customer_request_tab.dart';
import 'sales_collection_tab.dart';
import 'sales_overview_tab.dart';
import 'sales_visit_tab.dart';

class SalesMainScreen extends StatefulWidget {
  const SalesMainScreen({super.key});

  @override
  State<SalesMainScreen> createState() => _SalesMainScreenState();
}

class _SalesMainScreenState extends State<SalesMainScreen> {
  final _orderTabIndex = ValueNotifier<int>(0);
  static const _sellingSegments = ['so', 'dn', 'si'];

  @override
  void dispose() {
    _orderTabIndex.dispose();
    super.dispose();
  }

  void _selectOrderTab(int index) {
    _orderTabIndex.value = index.clamp(0, _sellingSegments.length - 1);
  }

  void _handleSellingSegmentChanged(String segment) {
    final nextIndex = _sellingSegments.indexOf(segment);
    if (nextIndex < 0 || _orderTabIndex.value == nextIndex) return;
    _orderTabIndex.value = nextIndex;
  }

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'Sales',
      fallbackUsername: 'Salesman',
      onInitialize: (state) async {
        await state.refreshDataForCurrentRole();
        if (state.isSalesManagerRole) {
          await state.fetchSalesOrderApprovals();
        }
      },
      screensBuilder: (onMenuSelected) => [
        SalesOverviewTab(
          onMenuSelected: onMenuSelected,
          onOrderTabSelected: _selectOrderTab,
        ),
        ValueListenableBuilder<int>(
          valueListenable: _orderTabIndex,
          builder: (context, index, _) {
            return SellingTab(
              selectedSegment: _sellingSegments[index],
              onSegmentChanged: _handleSellingSegmentChanged,
            );
          },
        ),
        const SalesCollectionTab(),
        const CustomerRequestTab(),
        const SalesVisitTab(showCheckIn: false),
      ],
      floatingActionButtonBuilder: _buildSalesFab,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Order',
        ),
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Koleksi',
        ),
        const NavigationDestination(
          icon: Icon(Icons.groups_2_outlined),
          selectedIcon: Icon(Icons.groups_2_rounded),
          label: 'Customer',
        ),
        const NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on_rounded),
          label: 'Kunjungan',
        ),
      ],
    );
  }

  Widget? _buildSalesFab(BuildContext context, int currentIndex) {
    if (currentIndex != 1) return null;
    return ValueListenableBuilder<int>(
      valueListenable: _orderTabIndex,
      builder: (context, orderTabIndex, _) {
        if (orderTabIndex != 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          onPressed: () => _openCreateSalesOrder(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Buat SO'),
        );
      },
    );
  }

  Future<void> _openCreateSalesOrder(BuildContext context) async {
    final state = context.read<AppState>();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()));
    if (!context.mounted) return;
    await Future.wait([
      state.refreshSalesOrders(),
      state.refreshSellingSummaries(documentType: 'Sales Order'),
    ]);
  }
}
