import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';
import 'sales_ui.dart';

class SalesHistoryTab extends StatelessWidget {
  const SalesHistoryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: state.refreshSalesOrders,
      child: ListView(
        padding: SalesUi.screenPadding,
        children: [
          const SalesSectionTitle(
            title: 'Histori Order & Approval',
            subtitle:
                'Pantau status order dan hasil approval dari pihak berwenang.',
          ),
          SalesUi.gap(14),
          if (state.salesOrdersError != null)
            ErpErrorBox(message: state.salesOrdersError!),
          if (state.salesOrders.isEmpty)
            const ErpEmptyState(title: 'Belum ada histori Sales Order')
          else
            ...state.salesOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SalesInfoCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.id,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.customer} - ${order.date}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            order.statusText,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rp ${formatErpCurrency(order.value)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
