import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/inventory_item.dart';
import '../../../models/material_request.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/document_trend_card.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_badge.dart';
import '../../../widgets/erp/erp_status_chip_bar.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';
import '../../purchase/material_request/create_material_request_screen.dart';
import 'buying_document_detail_sheet.dart';

class MaterialRequestPanel extends StatefulWidget {
  const MaterialRequestPanel({super.key});

  @override
  State<MaterialRequestPanel> createState() => _MaterialRequestPanelState();
}

class _MaterialRequestPanelState extends State<MaterialRequestPanel> {
  String _search = '';
  String? _statusFilter;
  Timer? _searchDebounce;

  static const _chips = <ErpStatusChip<String?>>[
    ErpStatusChip(label: 'Semua', value: null),
    ErpStatusChip(label: 'Draft', value: 'Draft'),
    ErpStatusChip(label: 'Pending', value: 'Pending'),
    ErpStatusChip(label: 'Partly Ordered', value: 'Partially Ordered'),
    ErpStatusChip(label: 'Ordered', value: 'Ordered'),
    ErpStatusChip(label: 'Stopped', value: 'Stopped'),
    ErpStatusChip(label: 'Cancelled', value: 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.materialRequests.isEmpty) {
        appState.refreshMaterialRequests();
      }
      if (appState.inventory.isEmpty) {
        appState.refreshInventory();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setMaterialRequestQuery(
          search: value,
          status: _statusFilter,
        );
      }
    });
  }

  List<MaterialRequest> _filter(List<MaterialRequest> docs) {
    final q = _search.toLowerCase();
    return docs.where((doc) {
      final matchSearch =
          q.isEmpty ||
          doc.id.toLowerCase().contains(q) ||
          doc.type.toLowerCase().contains(q) ||
          doc.company.toLowerCase().contains(q) ||
          doc.items.any(
            (item) =>
                item.itemCode.toLowerCase().contains(q) ||
                item.itemName.toLowerCase().contains(q),
          );
      final matchStatus =
          _statusFilter == null ||
          doc.statusText.toLowerCase() == _statusFilter!.toLowerCase();
      return matchSearch && matchStatus;
    }).toList();
  }

  List<InventoryItem> _planningItems(AppState appState) {
    final rows = appState.inventory.where((item) => item.quantity <= 0).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    return rows.take(5).toList();
  }

  Future<void> _openCreate({InventoryItem? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMaterialRequestScreen(initialItem: item),
      ),
    );
    if (mounted) {
      await context.read<AppState>().refreshMaterialRequests();
    }
  }

  Future<void> _openDetail(MaterialRequest doc) async {
    final detail = await context.read<AppState>().loadMaterialRequestDetail(
      doc.id,
    );
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);
    showBuyingDocumentDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.type,
      statusText: detail.statusText,
      icon: Icons.assignment_turned_in_rounded,
      metrics: [
        BuyingDetailMetric(
          label: 'Qty',
          value: formatErpCurrency(detail.totalQty),
          icon: Icons.inventory_2_outlined,
        ),
        BuyingDetailMetric(
          label: 'Item',
          value: '${detail.itemsCount}',
          icon: Icons.list_alt_rounded,
        ),
      ],
      infos: [
        BuyingDetailInfo(
          label: 'Status Dokumen',
          value: docStatusLabel(detail.docStatus),
        ),
        BuyingDetailInfo(label: 'Company', value: detail.company),
        BuyingDetailInfo(label: 'Tanggal', value: detail.transactionDate),
        BuyingDetailInfo(label: 'Dibutuhkan', value: detail.scheduleDate),
      ],
      items: detail.items
          .map(
            (item) => BuyingDetailItem(
              title: item.itemName,
              subtitle: item.itemCode,
              qty:
                  '${formatErpCurrency(item.qty)}${item.uom.isEmpty ? '' : ' ${item.uom}'}',
              rate: 'Ordered ${formatErpCurrency(item.orderedQty)}',
              amount: item.scheduleDate.isEmpty ? '-' : item.scheduleDate,
              note: item.warehouse,
            ),
          )
          .toList(),
      footer: canSubmit
          ? erpActionButton(
              label: 'Ajukan Material Request',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submit(detail.id),
            )
          : const Text(
              'Approval mengikuti Workflow ERPNext jika role dan workflow sudah aktif.',
              style: TextStyle(color: AppColors.slate, fontSize: 12),
            ),
    );
  }

  Future<void> _submit(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Ajukan Material Request?',
      message: 'Ajukan $id ke ERPNext?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Material Request', id),
      successMessage: 'Material Request berhasil diajukan',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.materialRequests);
    final planningItems = _planningItems(appState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentTrendCard(
          title: 'Material Request',
          emptyMessage: 'Belum ada request aktif pada periode ini.',
          points: appState.materialRequestTrendPoints,
          selectedYear: appState.buyingPeriodYear,
          selectedMonth: appState.buyingPeriodMonth,
          valuePrefix: '',
          valueSuffix: ' qty',
        ),
        const SizedBox(height: 12),
        _MaterialRequestHeader(count: appState.materialRequests.length),
        const SizedBox(height: 12),
        _PlanningCard(
          items: planningItems,
          onPick: (item) => _openCreate(item: item),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Cari MR, tipe, company, atau item...',
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
        const SizedBox(height: 10),
        ErpStatusChipBar<String?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (value) {
            setState(() => _statusFilter = value);
            context.read<AppState>().setMaterialRequestQuery(
              search: _search,
              status: value,
            );
          },
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isMaterialRequestsLoading)
          const ErpEmptyState(
            title: 'Belum ada request',
            message: 'Gunakan tombol Buat Request untuk mengajukan kebutuhan.',
          )
        else
          ...filtered.map(
            (doc) =>
                _MaterialRequestCard(doc: doc, onTap: () => _openDetail(doc)),
          ),
        if (appState.hasMoreMaterialRequests ||
            appState.isMoreMaterialRequestsLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMoreMaterialRequestsLoading
                  ? null
                  : () => context.read<AppState>().loadMoreMaterialRequests(),
              icon: appState.isMoreMaterialRequestsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMoreMaterialRequestsLoading
                    ? 'Memuat request...'
                    : 'Muat request lainnya',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaterialRequestCard extends StatelessWidget {
  final MaterialRequest doc;
  final VoidCallback onTap;

  const _MaterialRequestCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = doc.scheduleDate.isEmpty
        ? doc.transactionDate
        : doc.scheduleDate;
    final firstItem = doc.items.isNotEmpty
        ? doc.items.first.itemName
        : doc.type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'HankenGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  ErpStatusBadge(statusText: doc.statusText),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                firstItem,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date.isEmpty ? '-' : date,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                  Text(
                    '${formatErpCurrency(doc.totalQty)} qty',
                    style: const TextStyle(
                      fontFamily: 'HankenGrotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (doc.company.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  doc.company,
                  style: const TextStyle(fontSize: 9, color: AppColors.slate),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialRequestHeader extends StatelessWidget {
  final int count;

  const _MaterialRequestHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Material Request',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count request aktif',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Pantau kebutuhan barang, approval, dan rencana pembelian.',
                      style: TextStyle(color: AppColors.slate, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningCard extends StatelessWidget {
  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onPick;

  const _PlanningCard({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planning otomatis dari low stock',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            items.isEmpty
                ? 'Belum ada item stok kosong dari data inventory saat ini.'
                : 'Pilih item untuk membuat request dengan data item terisi otomatis.',
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${item.sku} | Stok ${item.quantity}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onPick(item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
