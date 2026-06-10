import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_error_box.dart';

class ArAgingTab extends StatefulWidget {
  const ArAgingTab({super.key});
  @override
  State<ArAgingTab> createState() => _ArAgingTabState();
}

class _ArAgingTabState extends State<ArAgingTab> {
  List<CollectionRanking> ranking = const [];
  String? rankingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      ranking = await context.read<AppState>().fetchCollectionRanking();
      rankingError = null;
    } catch (e) {
      rankingError = 'Endpoint ranking belum tersedia: $e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final buckets = <String, double>{
      '0-30': 0,
      '31-60': 0,
      '61-90': 0,
      '>90': 0,
    };
    final today = DateTime.now();
    for (final invoice in state.salesInvoices.where(
      (i) => i.outstandingAmount > 0,
    )) {
      final due = DateTime.tryParse(invoice.dueDate);
      final age = due == null ? 0 : today.difference(due).inDays;
      final key = age <= 30
          ? '0-30'
          : age <= 60
          ? '31-60'
          : age <= 90
          ? '61-90'
          : '>90';
      buckets[key] = buckets[key]! + invoice.outstandingAmount;
    }
    return RefreshIndicator(
      onRefresh: () async {
        await state.fetchSalesInvoicesFromFrappe();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AR Aging Monitoring',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...buckets.entries.map(
            (e) => Card(
              child: ListTile(
                title: Text('${e.key} hari'),
                trailing: Text('Rp ${formatErpCurrency(e.value)}'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Salesman Collection Ranking',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          if (rankingError != null) ErpErrorBox(message: rankingError!),
          ...ranking.map(
            (row) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${row.rank}')),
                title: Text(row.salesPerson),
                trailing: Text('Rp ${formatErpCurrency(row.amount)}'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Histori Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...state.salesInvoices
              .where(
                (invoice) =>
                    invoice.value > 0 && invoice.outstandingAmount <= 0,
              )
              .take(10)
              .map(
                (invoice) => Card(
                  child: ListTile(
                    title: Text(invoice.customer),
                    subtitle: Text('${invoice.id} - ${invoice.date}'),
                    trailing: Text('Rp ${formatErpCurrency(invoice.value)}'),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
