import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';

class PromiseToPayTab extends StatefulWidget {
  const PromiseToPayTab({super.key});
  @override
  State<PromiseToPayTab> createState() => _PromiseToPayTabState();
}

class _PromiseToPayTabState extends State<PromiseToPayTab> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  List<SalesCustomerOption> customers = const [];
  List<PromiseToPay> promises = const [];
  SalesCustomerOption? customer;
  DateTime? date;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final state = context.read<AppState>();
      final result = await Future.wait([
        state.fetchSalesCustomers(),
        state.fetchPromisesToPay(),
      ]);
      customers = result[0] as List<SalesCustomerOption>;
      promises = result[1] as List<PromiseToPay>;
    } catch (e) {
      error = 'Pastikan Custom DocType TMSX Promise To Pay tersedia. $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final parsed = double.tryParse(
      amount.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (customer == null || date == null || parsed == null || parsed <= 0) {
      return;
    }
    setState(() => loading = true);
    try {
      await context.read<AppState>().createPromiseToPay(
        customer: customer!.id,
        amount: parsed,
        promiseDate: date!,
        notes: notes.text,
      );
      amount.clear();
      notes.clear();
      customer = null;
      date = null;
      await _load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        DropdownButtonFormField<SalesCustomerOption>(
          key: ValueKey(customer?.id),
          initialValue: customer,
          items: customers
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (value) => setState(() => customer = value),
          decoration: const InputDecoration(labelText: 'Customer'),
        ),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nominal janji bayar'),
        ),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Catatan'),
        ),
        ListTile(
          title: Text(
            date == null
                ? 'Pilih tanggal janji bayar'
                : date!.toIso8601String().split('T').first,
          ),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: DateTime.now(),
            );
            if (picked != null) setState(() => date = picked);
          },
        ),
        FilledButton.icon(
          onPressed: loading ? null : _save,
          icon: const Icon(Icons.save),
          label: const Text('Simpan ke ERPNext'),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ErpErrorBox(message: error!),
        const SizedBox(height: 16),
        if (promises.isEmpty)
          const ErpEmptyState(title: 'Belum ada janji bayar')
        else
          ...promises.map(
            (row) => Card(
              child: ListTile(
                title: Text(row.customer),
                subtitle: Text('${row.promiseDate} - ${row.status}'),
                trailing: Text('Rp ${formatErpCurrency(row.amount)}'),
              ),
            ),
          ),
      ],
    ),
  );
}
