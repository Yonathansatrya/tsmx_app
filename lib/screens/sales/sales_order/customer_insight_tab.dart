import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_order_insight.dart';
import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';

class CustomerInsightTab extends StatefulWidget {
  const CustomerInsightTab({super.key});
  @override
  State<CustomerInsightTab> createState() => _CustomerInsightTabState();
}

class _CustomerInsightTabState extends State<CustomerInsightTab> {
  List<SalesCustomerOption> customers = const [];
  SalesCustomerOption? selected;
  CustomerSalesInsight? insight;
  List<CustomerPurchaseHistory> history = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomers());
  }

  Future<void> _loadCustomers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      customers = await context.read<AppState>().fetchSalesCustomers();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadInsight(SalesCustomerOption customer) async {
    setState(() {
      selected = customer;
      loading = true;
      error = null;
    });
    try {
      final state = context.read<AppState>();
      insight = await state.fetchCustomerSalesInsight(
        customer.id,
        company: 'PT Tani Mandiri Sukses',
      );
      history = await state.fetchCustomerPurchaseHistory(
        customer: customer.id,
        doctype: 'Sales Order',
        company: 'PT Tani Mandiri Sukses',
      );
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
    children: [
      DropdownButtonFormField<SalesCustomerOption>(
        key: ValueKey(selected?.id),
        initialValue: selected,
        items: customers
            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
            .toList(),
        onChanged: (value) {
          if (value != null) _loadInsight(value);
        },
        decoration: const InputDecoration(
          labelText: 'Customer',
          border: OutlineInputBorder(),
        ),
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) ErpErrorBox(message: error!),
      if (selected?.address.isNotEmpty == true)
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Alamat customer'),
          subtitle: Text(selected!.address),
          trailing: const Chip(label: Text('Maps next')),
        ),
      if (insight != null) ...[
        Card(
          child: ListTile(
            title: Text(
              'Credit Limit: Rp ${formatErpCurrency(insight!.creditLimit)}',
            ),
            subtitle: Text(
              'Outstanding: Rp ${formatErpCurrency(insight!.outstanding)}',
            ),
            trailing: Text(
              'Sisa\nRp ${formatErpCurrency(insight!.availableCredit)}',
              textAlign: TextAlign.end,
            ),
          ),
        ),
        const Text(
          'Histori Pembelian',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        if (history.isEmpty)
          const ErpEmptyState(title: 'Belum ada histori pembelian')
        else
          ...history.map(
            (row) => Card(
              child: ListTile(
                title: Text(row.id),
                subtitle: Text('${row.date} - ${row.status}'),
                trailing: Text('Rp ${formatErpCurrency(row.total)}'),
              ),
            ),
          ),
      ],
    ],
  );
}
