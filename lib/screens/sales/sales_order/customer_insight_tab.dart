import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_order_insight.dart';
import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../sales_ui.dart';

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
      final result = await context.read<AppState>().fetchSalesCustomers();
      if (!mounted) return;
      setState(() => customers = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadInsight(SalesCustomerOption customer) async {
    setState(() {
      selected = customer;
      insight = null;
      history = const [];
      loading = true;
      error = null;
    });
    try {
      final state = context.read<AppState>();
      final employeeCompany =
          state.currentEmployeeProfile['company']?.toString().trim() ?? '';
      final company = employeeCompany.isEmpty ? null : employeeCompany;
      final result = await Future.wait([
        state.fetchCustomerSalesInsight(customer.id, company: company),
        state.fetchCustomerPurchaseHistory(
          customer: customer.id,
          doctype: 'Sales Order',
          company: company,
        ),
        state.fetchCustomerPurchaseHistory(
          customer: customer.id,
          doctype: 'Sales Invoice',
          company: company,
        ),
      ]);
      final customerInsight = result[0] as CustomerSalesInsight;
      final customerHistory = <CustomerPurchaseHistory>[
        ...(result[1] as List<CustomerPurchaseHistory>),
        ...(result[2] as List<CustomerPurchaseHistory>),
      ]..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        insight = customerInsight;
        history = customerHistory;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: selected == null
        ? _loadCustomers
        : () => _loadInsight(selected!),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: SalesUi.compactScreenPadding,
      children: [
        DropdownButtonFormField<SalesCustomerOption>(
          key: ValueKey(selected?.id),
          initialValue: selected,
          isExpanded: true,
          items: customers
              .map(
                (customer) => DropdownMenuItem(
                  value: customer,
                  child: Text(customer.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: loading
              ? null
              : (value) {
                  if (value != null) _loadInsight(value);
                },
          decoration: InputDecoration(
            labelText: 'Customer',
            hintText: loading ? 'Memuat customer...' : 'Pilih customer',
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        SalesUi.gap(12),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          ErpErrorBox(message: error!),
          OutlinedButton.icon(
            onPressed: selected == null
                ? _loadCustomers
                : () => _loadInsight(selected!),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
        if (!loading && error == null && customers.isEmpty)
          const ErpEmptyState(
            title: 'Belum ada customer yang ditugaskan ke sales ini',
          ),
        if (!loading &&
            error == null &&
            customers.isNotEmpty &&
            selected == null)
          const ErpEmptyState(
            title: 'Pilih customer untuk melihat informasi penjualan',
          ),
        if (selected?.address.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SalesInfoCard(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alamat customer',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selected!.address,
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (insight != null) ...[
          SalesInfoCard(
            child: Row(
              children: [
                Expanded(
                  child: _InsightMetric(
                    label: 'Credit Limit',
                    value: 'Rp ${formatErpCurrency(insight!.creditLimit)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InsightMetric(
                    label: 'Outstanding',
                    value: 'Rp ${formatErpCurrency(insight!.outstanding)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InsightMetric(
                    label: 'Sisa',
                    value: 'Rp ${formatErpCurrency(insight!.availableCredit)}',
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
          SalesUi.gap(18),
          const SalesSectionTitle(title: 'Histori Pembelian'),
          SalesUi.gap(10),
          if (history.isEmpty)
            const ErpEmptyState(title: 'Belum ada histori pembelian')
          else
            ...history.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SalesInfoCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.id,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${row.doctype} | ${row.date} | ${row.status}',
                              maxLines: row.outstanding > 0 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 12,
                              ),
                            ),
                            if (row.outstanding > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Outstanding: Rp ${formatErpCurrency(row.outstanding)}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Rp ${formatErpCurrency(row.total)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InsightMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.slate, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: highlight ? AppColors.primary : AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
