import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stock_ledger_movement.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'warehouse_widgets.dart';

enum _MovementFilter { all, fast, slow }

class WarehouseFastSlowMovingView extends StatefulWidget {
  const WarehouseFastSlowMovingView({super.key});

  @override
  State<WarehouseFastSlowMovingView> createState() =>
      _WarehouseFastSlowMovingViewState();
}

class _WarehouseFastSlowMovingViewState
    extends State<WarehouseFastSlowMovingView> {
  final _search = TextEditingController();
  List<StockMovementVelocityItem> _rows = const [];
  _MovementFilter _filter = _MovementFilter.all;
  String? _warehouse;
  int _periodDays = 30;
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
      _rows = await context.read<AppState>().fetchStockMovementVelocity(
        periodDays: _periodDays,
      );
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();
    final movingRows = _rows.where((row) => row.outgoingQuantity > 0).length;
    final idleRows = _rows.length - movingRows;
    final warehouses = _rows.map((row) => row.warehouse).toSet().toList()
      ..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Fast & Slow Moving',
            subtitle: 'Analisis pergerakan barang keluar per gudang',
            icon: Icons.speed_rounded,
          ),
          warehouseSectionGap,
          Row(
            children: [
              Expanded(child: _metric('Stok bergerak', '$movingRows')),
              const SizedBox(width: 10),
              Expanded(child: _metric('Belum bergerak', '$idleRows')),
            ],
          ),
          const SizedBox(height: 10),
          const WarehouseInfoPanel(
            icon: Icons.info_outline_rounded,
            message:
                'Fast moving memiliki qty keluar minimal sebesar rata-rata. Slow moving berada di bawah rata-rata, termasuk yang belum bergerak.',
          ),
          warehouseSectionGap,
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari item atau kode',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _warehouse,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter gudang',
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua gudang')),
              ...warehouses.map(
                (warehouse) => DropdownMenuItem(
                  value: warehouse,
                  child: Text(warehouse, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(
              () => _warehouse = value?.isEmpty == true ? null : value,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _periodDays,
            decoration: const InputDecoration(
              labelText: 'Periode analisis',
              prefixIcon: Icon(Icons.date_range_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 hari terakhir')),
              DropdownMenuItem(value: 90, child: Text('90 hari terakhir')),
            ],
            onChanged: (value) {
              if (value == null || value == _periodDays) return;
              setState(() => _periodDays = value);
              _load();
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', _MovementFilter.all),
                _chip('Fast moving', _MovementFilter.fast),
                _chip('Slow moving', _MovementFilter.slow),
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
          warehouseSectionGap,
          WarehouseSectionHeader(
            title: 'Peringkat Pergerakan',
            subtitle: '${rows.length} baris stok ditampilkan',
            icon: Icons.format_list_numbered_rounded,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            const ErpEmptyState(
              title: 'Data pergerakan tidak ditemukan',
              message: 'Ubah filter atau tarik ke bawah untuk refresh.',
            )
          else
            ...rows.asMap().entries.map(
              (entry) => _movementCard(entry.key + 1, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, _MovementFilter value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  List<StockMovementVelocityItem> _filteredRows() {
    final query = _search.text.trim().toLowerCase();
    final averageOutgoing = _rows.isEmpty
        ? 0.0
        : _rows.fold<double>(0, (sum, row) => sum + row.outgoingQuantity) /
              _rows.length;
    final rows = _rows.where((row) {
      final matchesMovement = switch (_filter) {
        _MovementFilter.fast =>
          row.outgoingQuantity > 0 && row.outgoingQuantity >= averageOutgoing,
        _MovementFilter.slow =>
          row.outgoingQuantity == 0 || row.outgoingQuantity < averageOutgoing,
        _ => true,
      };
      return matchesMovement &&
          (_warehouse == null || row.warehouse == _warehouse) &&
          (query.isEmpty ||
              row.itemCode.toLowerCase().contains(query) ||
              row.itemName.toLowerCase().contains(query));
    }).toList();
    rows.sort((a, b) {
      if (_filter == _MovementFilter.slow) {
        return a.outgoingQuantity.compareTo(b.outgoingQuantity);
      }
      return b.outgoingQuantity.compareTo(a.outgoingQuantity);
    });
    return rows;
  }

  Widget _movementCard(int rank, StockMovementVelocityItem row) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _movementColor(row).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: _movementColor(row),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.itemName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${row.itemCode} | ${row.warehouse}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.slate, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Text(
                  'Keluar ${_formatQty(row.outgoingQuantity)} | ${row.transactionCount} transaksi | Stok ${row.currentQuantity}',
                  style: TextStyle(
                    color: _movementColor(row),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  Color _movementColor(StockMovementVelocityItem row) =>
      row.outgoingQuantity > 0 ? AppColors.success : AppColors.warning;

  String _formatQty(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(2);

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
