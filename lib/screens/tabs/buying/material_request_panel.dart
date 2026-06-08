import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/material_request.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_summary_card.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';

class MaterialRequestPanel extends StatefulWidget {
  const MaterialRequestPanel({super.key});

  @override
  State<MaterialRequestPanel> createState() => _MaterialRequestPanelState();
}

class _MaterialRequestPanelState extends State<MaterialRequestPanel> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.materialRequests.isEmpty) {
        appState.refreshMaterialRequests();
      }
    });
  }

  List<MaterialRequest> _filter(List<MaterialRequest> docs) {
    final q = _search.toLowerCase();
    return docs.where((d) {
      return q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.materialRequestType.toLowerCase().contains(q);
    }).toList();
  }

  void _openDetail(MaterialRequest doc) {
    final canSubmit = isDocDraft(doc.docStatus);
    showErpDetailSheet(
      context: context,
      title: doc.id,
      subtitle: doc.materialRequestType,
      statusText: doc.statusText,
      rows: [
        docStatusRow(doc.docStatus),
        ErpDetailRow(label: 'Date', value: doc.date),
        ErpDetailRow(label: 'Qty', value: '${doc.itemsCount}'),
      ],
      footer: canSubmit
          ? erpActionButton(
              label: 'Submit Material Request',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submit(doc.id),
            )
          : null,
    );
  }

  Future<void> _submit(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Material Request?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Material Request', id),
      successMessage: 'Material Request submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.materialRequests);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Material Requests',
          valueLabel: 'requests',
          totalValue: 0,
          documentCount: filtered.length,
          isLoading: appState.isMaterialRequestsLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search MR…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        if (appState.materialRequestsError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.materialRequestsError!),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isMaterialRequestsLoading)
          const ErpEmptyState(title: 'No material requests found')
        else
          ...filtered.map(
            (d) => ErpDocumentCard(
              id: d.id,
              party: d.materialRequestType,
              statusText: d.statusText,
              date: d.date,
              value: d.itemsCount.toDouble(),
              onTap: () => _openDetail(d),
            ),
          ),
      ],
    );
  }
}
