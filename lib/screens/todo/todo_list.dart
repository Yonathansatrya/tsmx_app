import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/erp_approval_todo.dart';
import '../../models/sales_order_approval.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_doc_utils.dart';
import '../../utils/erp_format.dart';
import '../../utils/num_parse.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_status_badge.dart';
import '../../widgets/erp/erp_workflow_helper.dart';

class SalesOrderApprovalScreen extends StatefulWidget {
  final bool embedded;
  final String title;
  final Set<String>? doctypeFilter;
  final bool showHistoryTab;

  const SalesOrderApprovalScreen({
    super.key,
    this.embedded = false,
    this.title = 'Approval Dokumen',
    this.doctypeFilter,
    this.showHistoryTab = true,
  });

  @override
  State<SalesOrderApprovalScreen> createState() =>
      _SalesOrderApprovalScreenState();
}

class _SalesOrderApprovalScreenState extends State<SalesOrderApprovalScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabController;
  List<ErpApprovalTodo> _rows = const [];
  List<SalesOrderApprovalHistory> _history = const [];
  Timer? _syncTimer;
  bool _loading = true;
  String? _error;
  String? _historyError;
  String? _doctypeQuickFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.showHistoryTab ? 2 : 1,
      vsync: this,
    );
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _syncTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _load(silent: true),
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _tabController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _historyError = null;
      });
    }
    final appState = context.read<AppState>();
    try {
      final rows = await appState.fetchApprovalTodos();
      final filtered = widget.doctypeFilter == null
          ? rows
          : rows
                .where((row) => widget.doctypeFilter!.contains(row.doctype))
                .toList();
      if (!mounted) return;
      setState(() => _rows = filtered);
    } catch (error) {
      if (!silent && mounted) setState(() => _error = _friendlyError(error));
    }
    if (widget.showHistoryTab) {
      try {
        final history = await appState.fetchSalesOrderApprovalHistory();
        if (mounted) setState(() => _history = history);
      } catch (error) {
        if (!silent && mounted) {
          setState(() => _historyError = _friendlyError(error));
        }
      }
    }
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _selectApproval(ErpApprovalTodo approval) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ErpApprovalDetailPage(
          approval: approval,
          onChanged: () => _load(silent: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = TabBarView(
      controller: _tabController,
      children: [_todoTab(), if (widget.showHistoryTab) _historyTab()],
    );
    if (widget.embedded) {
      return ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            Material(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Todo (${_rows.length})'),
                  if (widget.showHistoryTab) const Tab(text: 'Riwayat'),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Todo (${_rows.length})'),
            if (widget.showHistoryTab) const Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _todoTab() {
    final query = _search.text.trim().toLowerCase();
    final rows = _rows.where((row) {
      final matchType =
          _doctypeQuickFilter == null || row.doctype == _doctypeQuickFilter;
      final matchSearch =
          query.isEmpty ||
          row.name.toLowerCase().contains(query) ||
          row.doctype.toLowerCase().contains(query) ||
          row.party.toLowerCase().contains(query) ||
          row.partyName.toLowerCase().contains(query) ||
          row.workflowState.toLowerCase().contains(query);
      return matchType && matchSearch;
    }).toList();
    final summary = _ApprovalTodoSummary.from(_rows);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _ApprovalTodoSummaryCard(
            summary: summary,
            selectedDoctype: _doctypeQuickFilter,
            onSelected: (doctype) => setState(() {
              _doctypeQuickFilter = _doctypeQuickFilter == doctype
                  ? null
                  : doctype;
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari dokumen, customer, supplier, atau status',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
          const SizedBox(height: 16),
          if (rows.isEmpty && !_loading)
            const ErpEmptyState(
              title: 'Todo approval sudah kosong',
              message:
                  'Hanya action Workflow yang tersedia untuk role login yang ditampilkan.',
            )
          else
            ...rows.map(_approvalCard),
        ],
      ),
    );
  }

  Widget _historyTab() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _summaryCard(
          icon: Icons.history_rounded,
          title: 'Riwayat Keputusan',
          message:
              'Log approve dan reject yang dilakukan melalui aplikasi TMSX.',
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_historyError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_historyError!),
        ],
        const SizedBox(height: 16),
        if (_history.isEmpty && !_loading)
          const ErpEmptyState(
            title: 'Belum ada riwayat approval',
            message:
                'Riwayat akan muncul setelah approve atau reject dilakukan dari aplikasi.',
          )
        else
          ..._groupedHistory().map(_historyGroupCard),
      ],
    ),
  );

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String message,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(color: AppColors.slate, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _approvalCard(ErpApprovalTodo row) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => _selectApproval(row),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.primary,
              child: Icon(_approvalIcon(row.doctype)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ErpStatusBadge(
                        statusText: row.workflowState.isEmpty
                            ? row.status
                            : row.workflowState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.partyLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.moduleLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _approvalAmount(row),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
          ],
        ),
      ),
    ),
  );

  IconData _approvalIcon(String doctype) => switch (doctype) {
    'Sales Order' => Icons.point_of_sale_rounded,
    'Purchase Order' => Icons.shopping_bag_rounded,
    'Purchase Invoice' => Icons.receipt_long_rounded,
    'Material Request' => Icons.assignment_turned_in_rounded,
    _ => Icons.approval_outlined,
  };

  String _approvalAmount(ErpApprovalTodo row) {
    final value = row.doctype == 'Material Request'
        ? '${formatErpCurrency(row.amount)} qty'
        : 'Rp ${formatErpCurrency(row.amount)}';
    return '$value${row.date.isEmpty ? '' : ' | ${row.date}'}';
  }

  Widget _historyGroupCard(_ApprovalHistoryGroup group) {
    final latest = group.latest;
    final rejected = latest.content.toLowerCase().contains('reject');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openHistoryDetail(group),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    (rejected ? AppColors.danger : AppColors.success)
                        .withValues(alpha: 0.1),
                foregroundColor: rejected
                    ? AppColors.danger
                    : AppColors.success,
                child: Icon(
                  rejected ? Icons.close_rounded : Icons.check_rounded,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.documentName,
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
                            color: AppColors.softGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${group.items.length} log',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _plainText(latest.content),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      latest.doctype,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${latest.actor} | ${latest.createdAt}',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }

  void _openHistoryDetail(_ApprovalHistoryGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SalesOrderApprovalHistoryDetailPage(group: group),
      ),
    );
  }

  List<_ApprovalHistoryGroup> _groupedHistory() {
    final grouped = <String, List<SalesOrderApprovalHistory>>{};
    for (final item in _history) {
      final documentName = item.salesOrder.isEmpty ? item.id : item.salesOrder;
      final key = '${item.doctype}::$documentName';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final groups = grouped.entries
        .map((entry) => _ApprovalHistoryGroup(entry.key, entry.value))
        .toList();
    groups.sort((a, b) => b.latest.createdAt.compareTo(a.latest.createdAt));
    return groups;
  }

  Widget _errorBox(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  );

  String _plainText(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _SalesOrderApprovalDetailPage extends StatefulWidget {
  final SalesOrderApproval approval;
  final FutureOr<void> Function() onChanged;

  const _SalesOrderApprovalDetailPage({
    required this.approval,
    required this.onChanged,
  });

  @override
  State<_SalesOrderApprovalDetailPage> createState() =>
      _SalesOrderApprovalDetailPageState();
}

class _ApprovalHistoryGroup {
  final String key;
  final List<SalesOrderApprovalHistory> items;

  _ApprovalHistoryGroup(this.key, List<SalesOrderApprovalHistory> items)
    : items = List.unmodifiable(items);

  SalesOrderApprovalHistory get latest => items.first;
  String get doctype => latest.doctype;
  String get documentName {
    if (latest.salesOrder.isNotEmpty) return latest.salesOrder;
    final parts = key.split('::');
    return parts.length == 2 ? parts.last : key;
  }
}

class _ApprovalTodoSummary {
  final Map<String, int> counts;

  const _ApprovalTodoSummary(this.counts);

  factory _ApprovalTodoSummary.from(List<ErpApprovalTodo> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.doctype] = (counts[row.doctype] ?? 0) + 1;
    }
    return _ApprovalTodoSummary(counts);
  }

  int get total => counts.values.fold<int>(0, (sum, count) => sum + count);

  int countFor(String doctype) => counts[doctype] ?? 0;

  List<String> get visibleDoctypes {
    const preferred = [
      'Purchase Order',
      'Purchase Invoice',
      'Material Request',
      'Sales Order',
    ];
    final ordered = [
      ...preferred.where(counts.containsKey),
      ...counts.keys.where((doctype) => !preferred.contains(doctype)),
    ];
    return ordered;
  }
}

class _ApprovalTodoSummaryCard extends StatelessWidget {
  final _ApprovalTodoSummary summary;
  final String? selectedDoctype;
  final ValueChanged<String> onSelected;

  const _ApprovalTodoSummaryCard({
    required this.summary,
    required this.selectedDoctype,
    required this.onSelected,
  });

  IconData _icon(String doctype) => switch (doctype) {
    'Purchase Order' => Icons.shopping_bag_rounded,
    'Purchase Invoice' => Icons.receipt_long_rounded,
    'Material Request' => Icons.assignment_turned_in_rounded,
    'Sales Order' => Icons.point_of_sale_rounded,
    _ => Icons.approval_outlined,
  };

  Color _color(String doctype) => switch (doctype) {
    'Purchase Order' => AppColors.primary,
    'Purchase Invoice' => AppColors.warning,
    'Material Request' => AppColors.success,
    'Sales Order' => AppColors.navy,
    _ => AppColors.slate,
  };

  String _shortLabel(String doctype) => switch (doctype) {
    'Purchase Order' => 'PO',
    'Purchase Invoice' => 'PI',
    'Material Request' => 'MR',
    'Sales Order' => 'SO',
    _ => doctype,
  };

  @override
  Widget build(BuildContext context) {
    final doctypes = summary.visibleDoctypes;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.softGreen,
                foregroundColor: AppColors.primary,
                child: const Icon(Icons.checklist_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.total} Todo Approval',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Pilih dokumen untuk melihat detail sebelum memberi keputusan.',
                      style: TextStyle(color: AppColors.slate, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (doctypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: doctypes.map((doctype) {
                final active = selectedDoctype == doctype;
                final color = _color(doctype);
                return ChoiceChip(
                  selected: active,
                  onSelected: (_) => onSelected(doctype),
                  avatar: Icon(
                    _icon(doctype),
                    size: 16,
                    color: active ? AppColors.white : color,
                  ),
                  label: Text(
                    '${_shortLabel(doctype)} ${summary.countFor(doctype)}',
                  ),
                  labelStyle: TextStyle(
                    color: active ? AppColors.white : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  selectedColor: color,
                  backgroundColor: color.withValues(alpha: 0.08),
                  side: BorderSide(color: color.withValues(alpha: 0.18)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErpApprovalDetailPage extends StatefulWidget {
  final ErpApprovalTodo approval;
  final FutureOr<void> Function() onChanged;

  const _ErpApprovalDetailPage({
    required this.approval,
    required this.onChanged,
  });

  @override
  State<_ErpApprovalDetailPage> createState() => _ErpApprovalDetailPageState();
}

class _ErpApprovalDetailPageState extends State<_ErpApprovalDetailPage> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<AppState>().fetchApprovalDocument(
        doctype: widget.approval.doctype,
        name: widget.approval.name,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAction(String action) async {
    final reject = _isRejectAction(action);
    var reason = '';
    if (reject) {
      reason = await _askReason(action) ?? '';
      if (reason.trim().isEmpty || !mounted) return;
    } else {
      final ok = await confirmErpAction(
        context,
        title: '$action ${widget.approval.name}?',
        message: 'Lanjutkan action "$action" untuk dokumen ini?',
      );
      if (!ok || !mounted) return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await context.read<AppState>().applyDocumentWorkflow(
        doctype: widget.approval.doctype,
        name: widget.approval.name,
        action: action,
        reason: reason,
      );
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.approval.name}: action $action berhasil.'),
          backgroundColor: reject ? AppColors.danger : AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
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
          autofocus: true,
          minLines: 3,
          maxLines: 5,
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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final items = _mapRows(detail?['items']);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Detail Approval',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _processing ? null : _loadDetail,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _detailHeader(),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(_error!),
            ],
            if (detail != null) ...[
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Informasi Dokumen',
                children: _documentInfoRows(detail),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: widget.approval.doctype == 'Material Request'
                    ? 'Kebutuhan'
                    : 'Nilai Dokumen',
                children: _amountRows(detail),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Item (${items.length})',
                children: items.isEmpty
                    ? [const Text('Tidak ada item.')]
                    : items.map(_itemRow).toList(),
              ),
            ],
            const SizedBox(height: 16),
            _decisionCard(),
          ],
        ),
      ),
    );
  }

  Widget _detailHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.approval.name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ErpStatusBadge(
              statusText: widget.approval.workflowState.isEmpty
                  ? widget.approval.status
                  : widget.approval.workflowState,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.approval.moduleLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.approval.partyLabel,
          style: const TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 10),
        Text(
          widget.approval.doctype == 'Material Request'
              ? '${formatErpCurrency(widget.approval.amount)} qty'
              : 'Rp ${formatErpCurrency(widget.approval.amount)}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  List<Widget> _documentInfoRows(Map<String, dynamic> detail) {
    final partnerLabel = widget.approval.doctype == 'Sales Order'
        ? 'Customer'
        : widget.approval.doctype == 'Material Request'
        ? 'Tipe Request'
        : 'Supplier';
    return [
      _detailRow(partnerLabel, widget.approval.partyLabel),
      _detailRow('Company', _text(detail['company'])),
      _detailRow(
        'Tanggal',
        _text(detail['transaction_date']).isNotEmpty
            ? _text(detail['transaction_date'])
            : _text(detail['posting_date']),
      ),
      _detailRow('Dibutuhkan', _text(detail['schedule_date'])),
      _detailRow('Jatuh Tempo', _text(detail['due_date'])),
      _detailRow('Dibuat oleh', _text(detail['owner'])),
    ];
  }

  List<Widget> _amountRows(Map<String, dynamic> detail) {
    if (widget.approval.doctype == 'Material Request') {
      return [
        _detailRow('Total Qty', formatErpCurrency(detail['total_qty'])),
        _detailRow('Status Dokumen', docStatusLabel(widget.approval.docStatus)),
      ];
    }
    return [
      _moneyRow('Subtotal', detail['net_total']),
      _moneyRow('Diskon', detail['discount_amount']),
      _moneyRow('Pajak & Biaya', detail['total_taxes_and_charges']),
      _moneyRow('Outstanding', detail['outstanding_amount']),
      _moneyRow('Grand Total', detail['grand_total'], emphasized: true),
    ];
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Divider(height: 22),
        ...children,
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _moneyRow(String label, dynamic value, {bool emphasized = false}) {
    final formatted = 'Rp ${formatErpCurrency(NumParse.asDouble(value))}';
    if (!emphasized) return _detailRow(label, formatted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(item['item_name']).isEmpty
              ? _text(item['item_code'])
              : _text(item['item_name']),
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${_number(item['qty'])} ${_text(item['uom'])} x '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['rate']))} = '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['amount']))}',
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _decisionCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Keputusan Approval',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Periksa detail, lalu pilih action sesuai Workflow ERPNext.',
          style: TextStyle(color: AppColors.slate, fontSize: 11),
        ),
        const SizedBox(height: 14),
        if (_processing)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.approval.actions.map((action) {
              final reject = _isRejectAction(action);
              return reject
                  ? OutlinedButton.icon(
                      onPressed: () => _chooseAction(action),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(action),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => _chooseAction(action),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(action),
                    );
            }).toList(),
          ),
      ],
    ),
  );

  Widget _errorBox(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  );

  List<Map<String, dynamic>> _mapRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _number(dynamic value) {
    final number = NumParse.asDouble(value);
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  bool _isRejectAction(String action) {
    final normalized = action.toLowerCase();
    return normalized.contains('reject') ||
        normalized.contains('tolak') ||
        normalized.contains('decline') ||
        normalized.contains('return');
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _SalesOrderApprovalHistoryDetailPage extends StatefulWidget {
  final _ApprovalHistoryGroup group;

  const _SalesOrderApprovalHistoryDetailPage({required this.group});

  @override
  State<_SalesOrderApprovalHistoryDetailPage> createState() =>
      _SalesOrderApprovalHistoryDetailPageState();
}

class _SalesOrderApprovalHistoryDetailPageState
    extends State<_SalesOrderApprovalHistoryDetailPage> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<AppState>().fetchApprovalDocument(
        doctype: widget.group.doctype,
        name: widget.group.documentName,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final party = _historyPartyName(detail);
    final state = _text(detail?['workflow_state']).isEmpty
        ? _text(detail?['status'])
        : _text(detail?['workflow_state']);
    final items = _mapRows(detail?['items']);
    final salesTeam = _mapRows(detail?['sales_team']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Riwayat Approval',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDetail,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _summaryHeader(
              documentName: widget.group.documentName,
              doctype: widget.group.doctype,
              party: party,
              state: state,
              total: _historyTotal(detail),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(_error!),
            ],
            if (detail != null) ...[
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Detail Dokumen',
                children: _historyDetailRows(detail, party),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: widget.group.doctype == 'Material Request'
                    ? 'Kebutuhan'
                    : 'Nilai Dokumen',
                children: _historyAmountRows(detail),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Item (${items.length})',
                children: items.isEmpty
                    ? [const Text('Tidak ada item.')]
                    : items.map(_itemRow).toList(),
              ),
              if (salesTeam.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Sales Team',
                  children: salesTeam
                      .map(
                        (row) => _detailRow(
                          _text(row['sales_person']),
                          '${_number(row['allocated_percentage'])}% kontribusi',
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 16),
            const Text(
              'Activity Log',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...widget.group.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _timelineItem(
                item,
                isFirst: index == 0,
                isLast: index == widget.group.items.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _summaryHeader({
    required String documentName,
    required String doctype,
    required String party,
    required String state,
    required double total,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                documentName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (state.isNotEmpty) ErpStatusBadge(statusText: state),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          doctype,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          party.isEmpty ? 'Party belum terbaca' : party,
          style: const TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                doctype == 'Material Request'
                    ? '${formatErpCurrency(total)} qty'
                    : 'Rp ${formatErpCurrency(total)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${widget.group.items.length} aktivitas',
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _historyPartyName(Map<String, dynamic>? detail) {
    if (detail == null) return '';
    if (widget.group.doctype == 'Sales Order') {
      return _text(detail['customer_name']).isEmpty
          ? _text(detail['customer'])
          : _text(detail['customer_name']);
    }
    if (widget.group.doctype == 'Material Request') {
      return _text(detail['company']).isEmpty
          ? _text(detail['material_request_type'])
          : _text(detail['company']);
    }
    return _text(detail['supplier_name']).isEmpty
        ? _text(detail['supplier'])
        : _text(detail['supplier_name']);
  }

  double _historyTotal(Map<String, dynamic>? detail) {
    if (detail == null) return 0;
    if (widget.group.doctype == 'Material Request') {
      return NumParse.asDouble(detail['total_qty']);
    }
    return NumParse.asDouble(detail['grand_total'] ?? detail['rounded_total']);
  }

  List<Widget> _historyDetailRows(Map<String, dynamic> detail, String party) {
    final partnerLabel = widget.group.doctype == 'Sales Order'
        ? 'Customer'
        : widget.group.doctype == 'Material Request'
        ? 'Tipe Request'
        : 'Supplier';
    return [
      _detailRow(partnerLabel, party),
      _detailRow('Company', _text(detail['company'])),
      _detailRow(
        'Tanggal',
        _text(detail['transaction_date']).isNotEmpty
            ? _text(detail['transaction_date'])
            : _text(detail['posting_date']),
      ),
      _detailRow('Dibutuhkan', _text(detail['schedule_date'])),
      _detailRow('Jatuh Tempo', _text(detail['due_date'])),
      _detailRow('Gudang', _text(detail['set_warehouse'])),
      _detailRow('Currency', _text(detail['currency'])),
      _detailRow('Dibuat oleh', _text(detail['owner'])),
    ];
  }

  List<Widget> _historyAmountRows(Map<String, dynamic> detail) {
    if (widget.group.doctype == 'Material Request') {
      return [
        _detailRow('Total Qty', formatErpCurrency(detail['total_qty'])),
        _detailRow('Status Dokumen', _text(detail['status'])),
      ];
    }
    return [
      _moneyRow('Subtotal', detail['net_total']),
      _moneyRow('Diskon', detail['discount_amount']),
      _moneyRow('Pajak & Biaya', detail['total_taxes_and_charges']),
      _moneyRow('Outstanding', detail['outstanding_amount']),
      _moneyRow('Grand Total', detail['grand_total'], emphasized: true),
    ];
  }

  Widget _timelineItem(
    SalesOrderApprovalHistory item, {
    required bool isFirst,
    required bool isLast,
  }) {
    final rejected = item.content.toLowerCase().contains('reject');
    final color = rejected ? AppColors.danger : AppColors.success;
    final action = _approvalActionLabel(item.content);
    final content = _plainText(item.content);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : AppColors.border,
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(
                    rejected ? Icons.close_rounded : Icons.check_rounded,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: color.withValues(alpha: 0.1),
                          foregroundColor: color,
                          child: Text(
                            _initials(item.actor),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: item.actor.isEmpty
                                          ? 'Unknown'
                                          : item.actor,
                                      style: const TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' $action',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.createdAt,
                                style: const TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _miniRow('Tipe', item.doctype),
                        const SizedBox(height: 3),
                        _miniRow('Dokumen', item.salesOrder),
                        const SizedBox(height: 6),
                        Text(
                          content.isEmpty ? '-' : content,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 10),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _errorBox(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  );

  String _approvalActionLabel(String content) {
    final plain = _plainText(content).toLowerCase();
    if (plain.contains('reject')) return 'rejected';
    if (plain.contains('approve')) return 'approved';
    return 'Aktivitas Approval';
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Divider(height: 22),
        ...children,
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _moneyRow(String label, dynamic value, {bool emphasized = false}) {
    final formatted = 'Rp ${formatErpCurrency(NumParse.asDouble(value))}';
    if (!emphasized) return _detailRow(label, formatted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(item['item_name']).isEmpty
              ? _text(item['item_code'])
              : _text(item['item_name']),
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${_number(item['qty'])} ${_text(item['uom'])} x '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['rate']))} = '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['amount']))}',
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  List<Map<String, dynamic>> _mapRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _number(dynamic value) {
    final number = NumParse.asDouble(value);
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  String _initials(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '?';
    final parts = clean
        .replaceAll('@', ' ')
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return clean.characters.first.toUpperCase();
    return parts
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }

  String _plainText(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _SalesOrderApprovalDetailPageState
    extends State<_SalesOrderApprovalDetailPage> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context
          .read<AppState>()
          .fetchSalesOrderApprovalDetail(widget.approval.name);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAction(String action) async {
    final reject = _isRejectAction(action);
    final decision = await showDialog<_ApprovalDecision>(
      context: context,
      builder: (dialogContext) => _ApprovalDecisionDialog(
        approval: widget.approval,
        action: action,
        isReject: reject,
      ),
    );
    if (decision == null || !mounted) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await context.read<AppState>().applySalesOrderWorkflow(
        approval: widget.approval,
        action: action,
        reason: decision.reason,
      );
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.approval.name}: action $action berhasil.'),
          backgroundColor: reject ? AppColors.danger : AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final items = _mapRows(detail?['items']);
    final salesTeam = _mapRows(detail?['sales_team']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Detail Approval',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _processing ? null : _loadDetail,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _detailHeader(widget.approval),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(_error!),
            ],
            if (detail != null) ...[
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Informasi Order',
                children: [
                  _detailRow('Customer', _text(detail['customer_name'])),
                  _detailRow(
                    'Tanggal Order',
                    _text(detail['transaction_date']),
                  ),
                  _detailRow('Tanggal Kirim', _text(detail['delivery_date'])),
                  _detailRow('Company', _text(detail['company'])),
                  _detailRow('Gudang', _text(detail['set_warehouse'])),
                  _detailRow('Price List', _text(detail['selling_price_list'])),
                  _detailRow('Currency', _text(detail['currency'])),
                  _detailRow('Dibuat oleh', _text(detail['owner'])),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Nilai Order',
                children: [
                  _moneyRow('Subtotal', detail['net_total']),
                  _moneyRow('Diskon', detail['discount_amount']),
                  _moneyRow('Pajak & Biaya', detail['total_taxes_and_charges']),
                  _moneyRow(
                    'Grand Total',
                    detail['grand_total'],
                    emphasized: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Item (${items.length})',
                children: items.isEmpty
                    ? [const Text('Tidak ada item.')]
                    : items.map(_itemRow).toList(),
              ),
              if (salesTeam.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Sales Team',
                  children: salesTeam
                      .map(
                        (row) => _detailRow(
                          _text(row['sales_person']),
                          '${_number(row['allocated_percentage'])}% kontribusi',
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 16),
            _decisionCard(),
          ],
        ),
      ),
    );
  }

  Widget _detailHeader(SalesOrderApproval approval) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                approval.name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ErpStatusBadge(
              statusText: approval.workflowState.isEmpty
                  ? approval.status
                  : approval.workflowState,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          approval.customerName,
          style: const TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 10),
        Text(
          'Rp ${formatErpCurrency(approval.grandTotal)}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Divider(height: 22),
        ...children,
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _moneyRow(String label, dynamic value, {bool emphasized = false}) {
    final formatted = 'Rp ${formatErpCurrency(NumParse.asDouble(value))}';
    if (!emphasized) return _detailRow(label, formatted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(item['item_name']).isEmpty
              ? _text(item['item_code'])
              : _text(item['item_name']),
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${_number(item['qty'])} ${_text(item['uom'])} x '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['rate']))} = '
          'Rp ${formatErpCurrency(NumParse.asDouble(item['amount']))}',
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _decisionCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Keputusan Approval',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Periksa detail, lalu pilih action sesuai Workflow ERPNext.',
          style: TextStyle(color: AppColors.slate, fontSize: 11),
        ),
        const SizedBox(height: 14),
        if (_processing)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.approval.actions.map((action) {
              final reject = _isRejectAction(action);
              return reject
                  ? OutlinedButton.icon(
                      onPressed: () => _chooseAction(action),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(action),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => _chooseAction(action),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(action),
                    );
            }).toList(),
          ),
      ],
    ),
  );

  Widget _errorBox(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  );

  List<Map<String, dynamic>> _mapRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _number(dynamic value) {
    final number = NumParse.asDouble(value);
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  bool _isRejectAction(String action) {
    final normalized = action.toLowerCase();
    return normalized.contains('reject') ||
        normalized.contains('tolak') ||
        normalized.contains('decline');
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ApprovalDecision {
  final String reason;

  const _ApprovalDecision({this.reason = ''});
}

class _ApprovalDecisionDialog extends StatefulWidget {
  final SalesOrderApproval approval;
  final String action;
  final bool isReject;

  const _ApprovalDecisionDialog({
    required this.approval,
    required this.action,
    required this.isReject,
  });

  @override
  State<_ApprovalDecisionDialog> createState() =>
      _ApprovalDecisionDialogState();
}

class _ApprovalDecisionDialogState extends State<_ApprovalDecisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isReject ? 'Reject Sales Order?' : 'Approve Sales Order?',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.approval.name}\n${widget.approval.customerName}\n'
              'Rp ${formatErpCurrency(widget.approval.grandTotal)}',
            ),
            if (widget.isReject) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Alasan reject',
                  hintText: 'Wajib diisi agar sales dapat memperbaiki order',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (!widget.isReject) return null;
                  final reason = value?.trim() ?? '';
                  if (reason.isEmpty) return 'Alasan reject wajib diisi';
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ApprovalDecision(reason: _reasonController.text.trim()),
            );
          },
          style: widget.isReject
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(widget.isReject ? 'Reject' : 'Approve'),
        ),
      ],
    );
  }
}
