import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';

class ApprovalSoScreen extends StatelessWidget {
  const ApprovalSoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final orders = appState.salesOrders;

    return RefreshIndicator(
      onRefresh: appState.refreshSalesOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          const Text(
            'Histori Order & Approval',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Sales hanya dapat memantau status. Approval dilakukan oleh pihak yang berwenang.',
            style: TextStyle(color: AppColors.slate, fontSize: 12),
          ),

          const SizedBox(height: 16),

          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history_rounded, color: AppColors.slate, size: 30),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada histori Sales Order',
                    style: TextStyle(color: AppColors.slate),
                  ),
                ],
              ),
            )
          else
            ...orders.map((order) {
              final isDraft = order.docStatus == 0;
              final isRejected =
                  order.statusText.toLowerCase().contains('cancel') ||
                  order.statusText.toLowerCase().contains('reject');
              final color = isRejected
                  ? Colors.red
                  : isDraft
                  ? Colors.orange
                  : Colors.green;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.id,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              order.statusText,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${order.customer} - ${order.date}',
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Divider(height: 1),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Rp ${formatErpCurrency(order.value)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.slate,
                            size: 15,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
