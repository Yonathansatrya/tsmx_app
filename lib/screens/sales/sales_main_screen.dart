import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../shared/role_main_screen.dart';
import '../todo/todo_list.dart';
import 'sales_collection_tab.dart';
import 'sales_order_tab.dart';
import 'sales_overview_tab.dart';
import 'sales_visit_tab.dart';

class SalesMainScreen extends StatefulWidget {
  const SalesMainScreen({super.key});

  @override
  State<SalesMainScreen> createState() => _SalesMainScreenState();
}

class _SalesMainScreenState extends State<SalesMainScreen> {
  final _orderTabIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _orderTabIndex.dispose();
    super.dispose();
  }

  void _selectOrderTab(int index) {
    _orderTabIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final showTodo = appState.isSalesManagerRole;
    final todoCount = appState.salesOrderApprovalTodoCount;

    return RoleMainScreen(
      title: 'TMSX Hub Sales',
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
        SalesOrderTab(selectedTabIndex: _orderTabIndex),
        const SalesCollectionTab(),
        const SalesVisitTab(),
        if (showTodo)
          const SalesOrderApprovalScreen(
            embedded: true,
            title: 'Approval Sales Order',
          ),
      ],
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
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on_rounded),
          label: 'Kunjungan',
        ),
        if (showTodo)
          NavigationDestination(
            icon: _todoIcon(Icons.fact_check_outlined, todoCount),
            selectedIcon: _todoIcon(Icons.fact_check_rounded, todoCount),
            label: 'Todo',
          ),
      ],
    );
  }

  Widget _todoIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge.count(
      count: count,
      backgroundColor: Colors.redAccent,
      textColor: Colors.white,
      child: Icon(icon),
    );
  }
}
