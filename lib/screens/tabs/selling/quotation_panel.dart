import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/quotation.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_summary_card.dart';

class QuotationPanel extends StatefulWidget {
  const QuotationPanel({super.key});

  @override
  State<QuotationPanel> createState() => _QuotationPanelState();
}

class _QuotationPanelState extends State<QuotationPanel> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.quotations.isEmpty) {
        appState.refreshQuotations();
      }
    });
  }

  List<Quotation> _filter(List<Quotation> docs) {
    final q = _search.toLowerCase();
    return docs.where((d) {
      return q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.customer.toLowerCase().contains(q);
    }).toList();
  }

  void _openDetail(Quotation doc) {
    showErpDetailSheet(
      context: context,
      title: doc.id,
      subtitle: doc.customer,
      statusText: doc.statusText,
      rows: [
        ErpDetailRow(label: 'Date', value: doc.date),
        ErpDetailRow(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(doc.value)}',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.quotations);
    final total = filtered.fold<double>(0, (s, d) => s + d.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Quotations',
          valueLabel: 'quotes',
          totalValue: total,
          documentCount: filtered.length,
          isLoading: appState.isQuotationsLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search quotation or customer…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
          ),
        ),
        if (appState.quotationsError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.quotationsError!),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isQuotationsLoading)
          const ErpEmptyState(title: 'No quotations found')
        else
          ...filtered.map(
            (d) => ErpDocumentCard(
              id: d.id,
              party: d.customer,
              statusText: d.statusText,
              date: d.date,
              value: d.value,
              onTap: () => _openDetail(d),
            ),
          ),
      ],
    );
  }
}
