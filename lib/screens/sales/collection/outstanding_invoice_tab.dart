import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';

class OutstandingInvoiceTab extends StatelessWidget {
  const OutstandingInvoiceTab({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final invoices = state.salesInvoices
        .where((i) => i.outstandingAmount > 0)
        .toList();
    return RefreshIndicator(
      onRefresh: state.fetchSalesInvoicesFromFrappe,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isSalesInvoicesLoading) const LinearProgressIndicator(),
          if (state.salesInvoicesError != null)
            ErpErrorBox(message: state.salesInvoicesError!),
          if (invoices.isEmpty)
            const ErpEmptyState(title: 'Tidak ada outstanding invoice')
          else
            ...invoices.map(
              (invoice) => Card(
                child: ListTile(
                  title: Text(
                    invoice.id,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${invoice.customer}\nJatuh tempo: ${invoice.dueDate}',
                  ),
                  trailing: Text(
                    'Rp ${formatErpCurrency(invoice.outstandingAmount)}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
