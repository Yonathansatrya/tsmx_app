import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_badge.dart';
import '../sales_ui.dart';
import 'create_sales_order_screen.dart';

class SalesOrderListTab extends StatelessWidget {
  const SalesOrderListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: state.refreshSalesOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SalesUi.compactScreenPadding,
        children: [
          if (state.isSalesOrdersLoading) const LinearProgressIndicator(),
          if (state.salesOrdersError != null) ...[
            ErpErrorBox(message: state.salesOrdersError!),
            OutlinedButton.icon(
              onPressed: state.refreshSalesOrders,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
          if (state.salesOrders.isEmpty &&
              !state.isSalesOrdersLoading &&
              state.salesOrdersError == null)
            const ErpEmptyState(title: 'Belum ada Sales Order')
          else if (state.salesOrders.isNotEmpty)
            ...state.salesOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SalesInfoCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () {
                    if (order.docStatus == 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateSalesOrderScreen(editOrderId: order.id),
                        ),
                      );
                      return;
                    }
                    showErpDetailSheet(
                      context: context,
                      title: order.id,
                      subtitle: order.customer,
                      statusText: order.statusText,
                      rows: [
                        ErpDetailRow(label: 'Tanggal', value: order.date),
                        ErpDetailRow(
                          label: 'Total',
                          value: 'Rp ${formatErpCurrency(order.value)}',
                        ),
                        ErpDetailRow(
                          label: 'Jumlah item',
                          value: '${order.itemsCount}',
                        ),
                        ErpDetailRow(
                          label: 'Terkirim',
                          value: '${order.perDelivered.toStringAsFixed(0)}%',
                        ),
                        ErpDetailRow(
                          label: 'Tertagih',
                          value: '${order.perBilled.toStringAsFixed(0)}%',
                        ),
                      ],
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              order.customer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.date} • ${order.itemsCount} item',
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ErpStatusBadge(statusText: order.statusText),
                          const SizedBox(height: 8),
                          Text(
                            'Rp ${formatErpCurrency(order.value)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
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
