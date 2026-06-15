import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sales_order_approval.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/erp_format.dart';
import '../utils/num_parse.dart';
import '../widgets/erp/erp_empty_state.dart';
import '../widgets/erp/erp_status_badge.dart';

class SalesOrderApprovalScreen extends StatefulWidget {
  final bool embedded;

  const SalesOrderApprovalScreen({super.key, this.embedded = false});

  @override
  State<SalesOrderApprovalScreen> createState() =>
      _SalesOrderApprovalScreenState();
}

class _SalesOrderApprovalScreenState extends State<SalesOrderApprovalScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabController;
  List<SalesOrderApproval> _rows = const [];
  List<SalesOrderApprovalHistory> _history = const [];
  SalesOrderApproval? _selected;
  Map<String, dynamic>? _detail;
  Timer? _syncTimer;
  String? _processingName;
  bool _loading = true;
  bool _detailLoading = false;
  String? _error;
  String? _historyError;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final rows = await appState.fetchSalesOrderApprovals();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        if (_selected != null) {
          _selected = _approvalByName(rows, _selected!.name) ?? _selected;
        }
      });
    } catch (error) {
      if (!silent && mounted) setState(() => _error = _friendlyError(error));
    }
    try {
      final history = await appState.fetchSalesOrderApprovalHistory();
      if (mounted) setState(() => _history = history);
    } catch (error) {
      if (!silent && mounted) {
        setState(() => _historyError = _friendlyError(error));
      }
    }
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _selectApproval(SalesOrderApproval approval) async {
    setState(() {
      _selected = approval;
      _detail = null;
      _detailError = null;
      _detailLoading = true;
    });
    _tabController.animateTo(2);
    try {
      final detail = await context
          .read<AppState>()
          .fetchSalesOrderApprovalDetail(approval.name);
      if (mounted && _selected?.name == approval.name) {
        setState(() => _detail = detail);
      }
    } catch (error) {
      if (mounted && _selected?.name == approval.name) {
        setState(() => _detailError = _friendlyError(error));
      }
    } finally {
      if (mounted && _selected?.name == approval.name) {
        setState(() => _detailLoading = false);
      }
    }
  }

  Future<void> _chooseAction(SalesOrderApproval approval, String action) async {
    final reject = _isRejectAction(action);
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(reject ? 'Reject Sales Order?' : 'Approve Sales Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${approval.name}\n${approval.customerName}\n'
              'Rp ${formatErpCurrency(approval.grandTotal)}',
            ),
            if (reject) ...[
              const SizedBox(height: 14),
              TextField(
                controller: reason,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Alasan reject',
                  hintText: 'Wajib diisi agar sales dapat memperbaiki order',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (reject && reason.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            style: reject
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(reject ? 'Reject' : 'Approve'),
          ),
        ],
      ),
    );
    final reasonText = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    setState(() {
      _processingName = approval.name;
      _detailError = null;
    });
    try {
      await context.read<AppState>().applySalesOrderWorkflow(
        approval: approval,
        action: action,
        reason: reasonText,
      );
      await _load(silent: true);
      if (!mounted) return;
      final nextApproval = _approvalByName(_rows, approval.name);
      if (nextApproval == null) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        _tabController.animateTo(0);
      } else {
        await _selectApproval(nextApproval);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${approval.name}: action $action berhasil.'),
          backgroundColor: reject ? AppColors.danger : AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _detailError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _processingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = TabBarView(
      controller: _tabController,
      children: [_todoTab(), _historyTab(), _detailTab()],
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
                  const Tab(text: 'Riwayat'),
                  const Tab(text: 'Detail'),
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
        title: const Text(
          'Approval Sales Order',
          style: TextStyle(
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
            const Tab(text: 'Riwayat'),
            const Tab(text: 'Detail'),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _todoTab() {
    final query = _search.text.trim().toLowerCase();
    final rows = _rows.where((row) {
      return query.isEmpty ||
          row.name.toLowerCase().contains(query) ||
          row.customer.toLowerCase().contains(query) ||
          row.customerName.toLowerCase().contains(query) ||
          row.workflowState.toLowerCase().contains(query);
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _summaryCard(
            icon: Icons.checklist_rounded,
            title: '${_rows.length} Todo Approval',
            message:
                'Pilih Sales Order untuk melihat detail sebelum memberi keputusan.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari Sales Order atau customer',
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
          ..._history.map(_historyCard),
      ],
    ),
  );

  Widget _detailTab() {
    final approval = _selected;
    if (approval == null) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: ErpEmptyState(
          title: 'Pilih Todo terlebih dahulu',
          message:
              'Buka tab Todo, lalu pilih Sales Order untuk melihat detail lengkap.',
        ),
      );
    }
    final detail = _detail;
    final items = _mapRows(detail?['items']);
    final salesTeam = _mapRows(detail?['sales_team']);
    final processing = _processingName == approval.name;
    return RefreshIndicator(
      onRefresh: () => _selectApproval(approval),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _detailHeader(approval),
          if (_detailLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_detailError != null) ...[
            const SizedBox(height: 12),
            _errorBox(_detailError!),
          ],
          if (detail != null) ...[
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Informasi Order',
              children: [
                _detailRow('Customer', _text(detail['customer_name'])),
                _detailRow('Tanggal Order', _text(detail['transaction_date'])),
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
          _decisionCard(approval, processing),
        ],
      ),
    );
  }

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

  Widget _approvalCard(SalesOrderApproval row) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => _selectApproval(row),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.receipt_long_outlined),
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
                    row.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rp ${formatErpCurrency(row.grandTotal)}'
                    '${row.transactionDate.isEmpty ? '' : ' | ${row.transactionDate}'}',
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

  Widget _historyCard(SalesOrderApprovalHistory history) {
    final rejected = history.content.toLowerCase().contains('reject');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: (rejected ? AppColors.danger : AppColors.success)
                  .withValues(alpha: 0.1),
              foregroundColor: rejected ? AppColors.danger : AppColors.success,
              child: Icon(rejected ? Icons.close_rounded : Icons.check_rounded),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.salesOrder,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _plainText(history.content),
                    style: const TextStyle(color: AppColors.navy, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${history.actor} | ${history.createdAt}',
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

  Widget _decisionCard(
    SalesOrderApproval approval,
    bool processing,
  ) => Container(
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
          'Action mengikuti Workflow ERPNext dan role akun yang sedang login.',
          style: TextStyle(color: AppColors.slate, fontSize: 11),
        ),
        const SizedBox(height: 14),
        if (processing)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: approval.actions.map((action) {
              final reject = _isRejectAction(action);
              return reject
                  ? OutlinedButton.icon(
                      onPressed: () => _chooseAction(approval, action),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(action),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => _chooseAction(approval, action),
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

  SalesOrderApproval? _approvalByName(
    List<SalesOrderApproval> rows,
    String name,
  ) {
    for (final row in rows) {
      if (row.name == name) return row;
    }
    return null;
  }

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

  String _plainText(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

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
