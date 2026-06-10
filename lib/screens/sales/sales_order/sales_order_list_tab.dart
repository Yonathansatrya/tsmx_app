import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../create_sales_order_screen.dart';

class SalesOrderListTab extends StatelessWidget {
  const SalesOrderListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: state.refreshSalesOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (state.isSalesOrdersLoading) const LinearProgressIndicator(),
          if (state.salesOrdersError != null)
            ErpErrorBox(message: state.salesOrdersError!),
          if (state.salesOrders.isEmpty && !state.isSalesOrdersLoading)
            const ErpEmptyState(title: 'Belum ada Sales Order')
          else
            ...state.salesOrders.map(
              (order) => Card(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSalesOrderScreen(
                        editOrderId: order.docStatus == 0 ? order.id : null,
                      ),
                    ),
                  ),
                  title: Text(
                    order.id,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${order.customer}\n${order.date} - ${order.statusText}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    'Rp ${formatErpCurrency(order.value)}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
