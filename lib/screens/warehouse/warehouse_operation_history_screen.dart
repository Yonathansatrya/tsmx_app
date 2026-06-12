import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stock_entry.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_status_badge.dart';

enum _HistoryType { all, transfer, receive, issue, opname }

class WarehouseOperationHistoryScreen extends StatefulWidget {
  const WarehouseOperationHistoryScreen({super.key});

  @override
  State<WarehouseOperationHistoryScreen> createState() =>
      _WarehouseOperationHistoryScreenState();
}

class _WarehouseOperationHistoryScreenState
    extends State<WarehouseOperationHistoryScreen> {
  final _search = TextEditingController();
  _HistoryType _type = _HistoryType.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      await Future.wait([
        state.refreshStockEntries(),
        state.refreshStockReconciliations(),
      ]);
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = _filterEntries(state.stockEntries);
    final reconciliations = _filterReconciliations(state.stockReconciliations);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Riwayat Operasi Gudang',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cari nomor dokumen atau gudang',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Semua', _HistoryType.all),
                  _filterChip('Transfer', _HistoryType.transfer),
                  _filterChip('Receive', _HistoryType.receive),
                  _filterChip('Issue', _HistoryType.issue),
                  _filterChip('Stock Opname', _HistoryType.opname),
                ],
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (entries.isEmpty && reconciliations.isEmpty && !_loading)
              const ErpEmptyState(
                title: 'Belum ada riwayat operasi',
                message: 'Buat transaksi gudang atau ubah filter pencarian.',
              )
            else ...[
              ...entries.map(_stockEntryCard),
              ...reconciliations.map(_reconciliationCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _HistoryType value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _type == value,
      onSelected: (_) => setState(() => _type = value),
    ),
  );

  List<StockEntry> _filterEntries(List<StockEntry> rows) {
    if (_type == _HistoryType.opname) return const [];
    final query = _search.text.trim().toLowerCase();
    return rows.where((row) {
      final type = row.stockEntryType.toLowerCase();
      final matchesType = switch (_type) {
        _HistoryType.transfer => type == 'material transfer',
        _HistoryType.receive => type == 'material receipt',
        _HistoryType.issue => type == 'material issue',
        _ => true,
      };
      return matchesType &&
          (query.isEmpty ||
              row.id.toLowerCase().contains(query) ||
              row.fromWarehouse.toLowerCase().contains(query) ||
              row.toWarehouse.toLowerCase().contains(query));
    }).toList();
  }

  List<StockReconciliationSummary> _filterReconciliations(
    List<StockReconciliationSummary> rows,
  ) {
    if (_type != _HistoryType.all && _type != _HistoryType.opname) {
      return const [];
    }
    final query = _search.text.trim().toLowerCase();
    return rows
        .where(
          (row) =>
              query.isEmpty ||
              row.id.toLowerCase().contains(query) ||
              row.company.toLowerCase().contains(query),
        )
        .toList();
  }

  Widget _stockEntryCard(StockEntry row) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.softGreen,
        foregroundColor: AppColors.primary,
        child: Icon(_iconForType(row.stockEntryType)),
      ),
      title: Text(row.id, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        '${row.stockEntryType} | ${row.date}\n${_warehouseRoute(row)}',
      ),
      isThreeLine: true,
      trailing: ErpStatusBadge(statusText: row.statusText),
    ),
  );

  Widget _reconciliationCard(StockReconciliationSummary row) => Card(
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.softGreen,
        foregroundColor: AppColors.primary,
        child: Icon(Icons.inventory_outlined),
      ),
      title: Text(row.id, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('Stock Opname | ${row.date}\n${row.company}'),
      isThreeLine: true,
      trailing: ErpStatusBadge(statusText: row.statusText),
    ),
  );

  String _warehouseRoute(StockEntry row) {
    if (row.fromWarehouse.isNotEmpty && row.toWarehouse.isNotEmpty) {
      return '${row.fromWarehouse} → ${row.toWarehouse}';
    }
    if (row.fromWarehouse.isNotEmpty) return 'Dari ${row.fromWarehouse}';
    if (row.toWarehouse.isNotEmpty) return 'Ke ${row.toWarehouse}';
    return 'Gudang mengikuti detail item';
  }

  IconData _iconForType(String type) => switch (type.toLowerCase()) {
    'material transfer' => Icons.swap_horiz_rounded,
    'material receipt' => Icons.move_to_inbox_rounded,
    'material issue' => Icons.outbox_rounded,
    _ => Icons.inventory_2_outlined,
  };

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
