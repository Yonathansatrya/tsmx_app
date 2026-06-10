import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';

class SalesHistoryTab extends StatelessWidget {
  const SalesHistoryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: state.refreshSalesOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          const Text(
            'Histori Order & Approval',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Sales memantau status; approval dilakukan pihak berwenang.',
          ),
          if (state.salesOrdersError != null)
            ErpErrorBox(message: state.salesOrdersError!),
          if (state.salesOrders.isEmpty)
            const ErpEmptyState(title: 'Belum ada histori Sales Order')
          else
            ...state.salesOrders.map(
              (order) => Card(
                child: ListTile(
                  title: Text(
                    order.id,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('${order.customer} - ${order.date}'),
                  trailing: Text(
                    '${order.statusText}\nRp ${formatErpCurrency(order.value)}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
