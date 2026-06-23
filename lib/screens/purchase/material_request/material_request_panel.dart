import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/inventory_item.dart';
import '../../../models/material_request.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_summary_card.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';
import '../../tabs/buying/buying_document_detail_sheet.dart';

class MaterialRequestPanel extends StatefulWidget {
  const MaterialRequestPanel({super.key});

  @override
  State<MaterialRequestPanel> createState() => _MaterialRequestPanelState();
}

class _MaterialRequestPanelState extends State<MaterialRequestPanel> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<MaterialRequest> _rows = const [];
  String? _status;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppState>().frappeService.fetchResource(
        'Material Request',
        fields: const [
          'name',
          'material_request_type',
          'status',
          'docstatus',
          'transaction_date',
          'schedule_date',
          'company',
        ],
        filters: _status == null
            ? null
            : [
                ['status', '=', _status],
              ],
        orderBy: 'modified desc',
        limit: 100,
      );
      _rows = data.map(MaterialRequest.fromJson).toList();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MaterialRequest> _filteredRows() {
    final query = _search.text.trim().toLowerCase();
    return _rows.where((row) {
      return query.isEmpty ||
          row.id.toLowerCase().contains(query) ||
          row.type.toLowerCase().contains(query) ||
          row.company.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openDetail(MaterialRequest row) async {
    final appState = context.read<AppState>();
    Map<String, dynamic> doc;
    try {
      doc = await appState.frappeService.fetchDocument(
        'Material Request',
        row.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final detail = MaterialRequest.fromJson(doc);
    var workflowActions = <String>[];
    try {
      workflowActions = await appState.fetchDocumentWorkflowActions(
        doctype: 'Material Request',
        name: detail.id,
      );
    } catch (_) {}
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);

    showBuyingDocumentDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.type,
      statusText: detail.statusText,
      icon: Icons.assignment_outlined,
      metrics: [
        BuyingDetailMetric(
          label: 'Items',
          value: '${detail.items.length}',
          icon: Icons.inventory_2_outlined,
        ),
        BuyingDetailMetric(
          label: 'Estimated',
          value: 'Rp ${formatErpCurrency(detail.estimatedCost)}',
          icon: Icons.payments_outlined,
        ),
      ],
      infos: [
        BuyingDetailInfo(
          label: 'Doc Status',
          value: docStatusLabel(detail.docStatus),
        ),
        BuyingDetailInfo(label: 'Transaction Date', value: detail.date),
        BuyingDetailInfo(
          label: 'Needed By',
          value: detail.scheduleDate.isEmpty ? '-' : detail.scheduleDate,
        ),
        if (detail.company.isNotEmpty)
          BuyingDetailInfo(label: 'Company', value: detail.company),
      ],
      items: detail.items
          .map(
            (item) => BuyingDetailItem(
              title: item.itemName,
              subtitle: item.itemCode,
              qty:
                  '${formatErpCurrency(item.qty)}${item.uom.isEmpty ? '' : ' ${item.uom}'}',
              note: [
                if (item.warehouse.isNotEmpty) item.warehouse,
                if (item.scheduleDate.isNotEmpty) item.scheduleDate,
              ].join(' | '),
            ),
          )
          .toList(),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._workflowButtons(
            doctype: 'Material Request',
            name: detail.id,
            actions: workflowActions,
          ),
          if (canSubmit)
            erpActionButton(
              label: 'Submit Material Request',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submit(detail.id),
            ),
        ],
      ),
    );
  }

  Future<void> _submit(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Material Request?',
      message: 'Submit $id untuk proses approval/kebutuhan barang?',
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
    if (ok && mounted) {
      Navigator.pop(context);
      await _load();
    }
  }

  List<Widget> _workflowButtons({
    required String doctype,
    required String name,
    required List<String> actions,
  }) {
    return actions.map((action) {
      final lower = action.toLowerCase();
      final needsReason =
          lower.contains('reject') ||
          lower.contains('tolak') ||
          lower.contains('decline') ||
          lower.contains('return');
      final isApprove =
          lower.contains('approve') ||
          lower.contains('submit') ||
          lower.contains('confirm');
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: erpActionButton(
          label: action,
          icon: needsReason
              ? Icons.cancel_outlined
              : isApprove
              ? Icons.verified_outlined
              : Icons.route_outlined,
          filled: isApprove && !needsReason,
          onPressed: () => _applyWorkflowAction(
            doctype: doctype,
            name: name,
            action: action,
            needsReason: needsReason,
          ),
        ),
      );
    }).toList();
  }

  Future<void> _applyWorkflowAction({
    required String doctype,
    required String name,
    required String action,
    required bool needsReason,
  }) async {
    var reason = '';
    if (needsReason) {
      reason = await _askReason(action) ?? '';
      if (reason.trim().isEmpty) return;
      if (!mounted) return;
    } else {
      final ok = await confirmErpAction(
        context,
        title: '$action $name?',
        message: 'Lanjutkan action "$action" untuk $name?',
      );
      if (!ok || !mounted) return;
    }

    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().applyDocumentWorkflow(
        doctype: doctype,
        name: name,
        action: action,
        reason: reason,
      ),
      successMessage: '$action berhasil',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await _load();
    }
  }

  Future<String?> _askReason(String action) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action - alasan wajib'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan',
            hintText: 'Tulis alasan agar tercatat di ERPNext',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _openCreateSheet({InventoryItem? suggestion}) async {
    final result = await showModalBottomSheet<_MaterialRequestDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _MaterialRequestFormSheet(suggestion: suggestion),
    );
    if (result == null || !mounted) return;
    await _create(result);
  }

  Future<void> _create(_MaterialRequestDraft draft) async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().frappeService.createDocument(
        'Material Request',
        {
          'material_request_type': draft.type,
          'transaction_date': DateTime.now().toIso8601String().split('T').first,
          'schedule_date': draft.scheduleDate,
          if (draft.company.isNotEmpty) 'company': draft.company,
          'items': [
            {
              'item_code': draft.itemCode,
              'qty': draft.qty,
              'schedule_date': draft.scheduleDate,
              if (draft.warehouse.isNotEmpty) 'warehouse': draft.warehouse,
            },
          ],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material Request berhasil dibuat')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final rows = _filteredRows();
    final total = rows.fold<double>(0, (sum, row) => sum + row.estimatedCost);
    final lowStock = appState.inventory
        .where((item) => item.status != StockStatus.inStock)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Material Request',
          valueLabel: 'requests',
          totalValue: total,
          documentCount: rows.length,
          subtitle: 'Request barang, approval, dan kebutuhan pembelian',
          isLoading: _loading,
        ),
        const SizedBox(height: 12),
        _CreateMaterialRequestCard(
          saving: _saving,
          lowStock: lowStock,
          onCreate: () => _openCreateSheet(),
          onCreateBulk: lowStock.isEmpty
              ? null
              : () => _createBulkLowStock(lowStock),
          onUseSuggestion: (item) => _openCreateSheet(suggestion: item),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 250),
              () => mounted ? setState(() {}) : null,
            );
          },
          decoration: InputDecoration(
            hintText: 'Cari MR, tipe, atau company',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.fact_check_outlined),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Semua status')),
            DropdownMenuItem(value: 'Draft', child: Text('Draft')),
            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
            DropdownMenuItem(value: 'Ordered', child: Text('Ordered')),
            DropdownMenuItem(value: 'Stopped', child: Text('Stopped')),
            DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
          ],
          onChanged: (value) {
            setState(() => _status = value);
            _load();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: _error!),
        ],
        if (_loading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 12),
        if (rows.isEmpty && !_loading)
          const ErpEmptyState(
            title: 'Belum ada Material Request',
            message: 'Buat request barang dari tombol di atas.',
          )
        else
          ...rows.map(
            (row) => ErpDocumentCard(
              id: row.id,
              party: row.type,
              statusText: row.statusText,
              date: row.scheduleDate.isEmpty ? row.date : row.scheduleDate,
              value: row.estimatedCost,
              onTap: () => _openDetail(row),
            ),
          ),
      ],
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _createBulkLowStock(List<InventoryItem> items) async {
    if (items.isEmpty) return;
    final ok = await confirmErpAction(
      context,
      title: 'Buat MR dari low stock?',
      message:
          'Aplikasi akan membuat 1 Material Request berisi ${items.length} item low stock.',
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      final scheduleDate = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      await context.read<AppState>().frappeService.createDocument(
        'Material Request',
        {
          'material_request_type': 'Purchase',
          'transaction_date': DateTime.now().toIso8601String().split('T').first,
          'schedule_date': scheduleDate,
          'items': items
              .map(
                (item) => {
                  'item_code': item.sku,
                  'qty': _suggestedQty(item),
                  'schedule_date': scheduleDate,
                  if (item.warehouseId.isNotEmpty)
                    'warehouse': item.warehouseId,
                },
              )
              .toList(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Material Request ${items.length} item berhasil dibuat',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _suggestedQty(InventoryItem item) {
    final target = item.minStockThreshold <= 0 ? 1 : item.minStockThreshold;
    return (target - item.quantity).clamp(1, 999999);
  }
}

class _CreateMaterialRequestCard extends StatelessWidget {
  final bool saving;
  final List<InventoryItem> lowStock;
  final VoidCallback onCreate;
  final VoidCallback? onCreateBulk;
  final ValueChanged<InventoryItem> onUseSuggestion;

  const _CreateMaterialRequestCard({
    required this.saving,
    required this.lowStock,
    required this.onCreate,
    required this.onCreateBulk,
    required this.onUseSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: saving ? null : onCreate,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_task_rounded),
            label: const Text('Buat Request Barang'),
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving ? null : onCreateBulk,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Buat MR dari ${lowStock.length} low stock'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Planning otomatis dari low stock',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...lowStock.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${item.sku} | Stok ${item.quantity}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onUseSuggestion(item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialRequestDraft {
  final String type;
  final String itemCode;
  final double qty;
  final String scheduleDate;
  final String warehouse;
  final String company;

  const _MaterialRequestDraft({
    required this.type,
    required this.itemCode,
    required this.qty,
    required this.scheduleDate,
    required this.warehouse,
    required this.company,
  });
}

class _MaterialRequestFormSheet extends StatefulWidget {
  final InventoryItem? suggestion;

  const _MaterialRequestFormSheet({this.suggestion});

  @override
  State<_MaterialRequestFormSheet> createState() =>
      _MaterialRequestFormSheetState();
}

class _MaterialRequestFormSheetState extends State<_MaterialRequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _warehouseCtrl;
  late final TextEditingController _companyCtrl;
  String _type = 'Purchase';
  DateTime _scheduleDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    _itemCtrl = TextEditingController(text: suggestion?.sku ?? '');
    final qty = suggestion == null
        ? '1'
        : (suggestion.minStockThreshold - suggestion.quantity)
              .clamp(1, 999999)
              .toString();
    _qtyCtrl = TextEditingController(text: qty);
    _warehouseCtrl = TextEditingController(text: suggestion?.warehouseId ?? '');
    _companyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _warehouseCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buat Material Request',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipe request',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Purchase',
                      child: Text('Purchase'),
                    ),
                    DropdownMenuItem(
                      value: 'Material Transfer',
                      child: Text('Material Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'Material Issue',
                      child: Text('Material Issue'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _itemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Code',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Item wajib diisi' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  validator: (value) {
                    final qty = double.tryParse(value?.trim() ?? '');
                    if (qty == null || qty <= 0) return 'Qty harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _warehouseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse tujuan (opsional)',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _companyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company (opsional)',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickScheduleDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Dibutuhkan: ${_formatDate(_scheduleDate)}'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan ke ERPNext'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduleDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduleDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _MaterialRequestDraft(
        type: _type,
        itemCode: _itemCtrl.text.trim(),
        qty: double.parse(_qtyCtrl.text.trim()),
        scheduleDate: _formatDate(_scheduleDate),
        warehouse: _warehouseCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
