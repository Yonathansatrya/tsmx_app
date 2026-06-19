import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../theme/app_colors.dart';
import 'sales_history_tab.dart';
import 'sales_ui.dart';
import 'sales_order/customer_insight_tab.dart';
import 'sales_order/sales_order_list_tab.dart';
import 'sales_order/stock_check_tab.dart';

class SalesOrderTab extends StatelessWidget {
  final ValueListenable<int>? selectedTabIndex;

  const SalesOrderTab({super.key, this.selectedTabIndex});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            _SalesOrderTabBody(selectedTabIndex: selectedTabIndex),
            // disable for now, untuk testing team sales 
            // Positioned(
            //   right: 16,
            //   bottom: 24,
            //   child: FloatingActionButton.extended(
            //     backgroundColor: AppColors.primary,
            //     foregroundColor: AppColors.white,
            //     elevation: 3,
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(16),
            //     ),
            //     onPressed: () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => const CreateSalesOrderScreen(),
            //       ),
            //     ),
            //     icon: const Icon(Icons.add_rounded),
            //     label: const Text('Buat Sales Order'),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _SalesOrderTabBody extends StatefulWidget {
  final ValueListenable<int>? selectedTabIndex;

  const _SalesOrderTabBody({this.selectedTabIndex});

  @override
  State<_SalesOrderTabBody> createState() => _SalesOrderTabBodyState();
}

class _SalesOrderTabBodyState extends State<_SalesOrderTabBody> {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    widget.selectedTabIndex?.addListener(_syncSelectedTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabController = DefaultTabController.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelectedTab());
  }

  @override
  void didUpdateWidget(covariant _SalesOrderTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTabIndex == widget.selectedTabIndex) return;
    oldWidget.selectedTabIndex?.removeListener(_syncSelectedTab);
    widget.selectedTabIndex?.addListener(_syncSelectedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelectedTab());
  }

  @override
  void dispose() {
    widget.selectedTabIndex?.removeListener(_syncSelectedTab);
    super.dispose();
  }

  void _syncSelectedTab() {
    if (!mounted) return;
    final controller = _tabController;
    final target = widget.selectedTabIndex?.value;
    if (controller == null || target == null) return;
    if (target < 0 || target >= controller.length) return;
    if (controller.index == target) return;
    controller.animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SalesPillTabBar(
            tabs: [
              Tab(text: 'Sales Order'),
              Tab(text: 'Cek Stok'),
              Tab(text: 'Customer'),
              Tab(text: 'Histori'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              SalesOrderListTab(),
              StockCheckTab(),
              CustomerInsightTab(),
              SalesHistoryTab(compact: true),
            ],
          ),
        ),
      ],
    );
  }
}
