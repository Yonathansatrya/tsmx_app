import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stock_ledger_movement.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'warehouse_widgets.dart';

enum _AgingBucket { all, fresh, medium, old, veryOld }

class WarehouseStockAgingView extends StatefulWidget {
  const WarehouseStockAgingView({super.key});

  @override
  State<WarehouseStockAgingView> createState() =>
      _WarehouseStockAgingViewState();
}

class _WarehouseStockAgingViewState extends State<WarehouseStockAgingView> {
  final _search = TextEditingController();
  List<StockAgingItem> _rows = const [];
  _AgingBucket _bucket = _AgingBucket.all;
  String? _warehouse;
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
      _rows = await context.read<AppState>().fetchStockAging();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();
    final oldCount = _rows.where((row) => row.ageDays > 90).length;
    final oldValue = _rows
        .where((row) => row.ageDays > 90)
        .fold<double>(0, (sum, row) => sum + row.stockValue);
    final warehouses = _rows.map((row) => row.warehouse).toSet().toList()
      ..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Stock Aging',
            subtitle: 'Umur stok berdasarkan tanggal barang masuk terakhir',
            icon: Icons.timelapse_rounded,
          ),
          warehouseSectionGap,
          Row(
            children: [
              Expanded(child: _metric('Stok >90 hari', '$oldCount')),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Nilai >90 hari',
                  'Rp ${formatErpCurrency(oldValue)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const WarehouseInfoPanel(
            icon: Icons.info_outline_rounded,
            message:
                'Umur dihitung dari penerimaan terakhir dalam 365 hari. Item tanpa penerimaan pada periode tersebut ditandai >365 hari.',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', _AgingBucket.all),
                _chip('0-30 hari', _AgingBucket.fresh),
                _chip('31-60 hari', _AgingBucket.medium),
                _chip('61-90 hari', _AgingBucket.old),
                _chip('>90 hari', _AgingBucket.veryOld),
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
            title: 'Daftar Umur Stok',
            subtitle: '${rows.length} baris stok ditampilkan',
            icon: Icons.list_alt_rounded,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            const ErpEmptyState(
              title: 'Data stock aging tidak ditemukan',
              message: 'Ubah filter atau tarik ke bawah untuk refresh.',
            )
          else
            ...rows.map(_agingCard),
        ],
      ),
    );
  }

  Widget _chip(String label, _AgingBucket value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _bucket == value,
      onSelected: (_) => setState(() => _bucket = value),
    ),
  );

  List<StockAgingItem> _filteredRows() {
    final query = _search.text.trim().toLowerCase();
    final rows = _rows.where((row) {
      return (_warehouse == null || row.warehouse == _warehouse) &&
          (query.isEmpty ||
              row.itemCode.toLowerCase().contains(query) ||
              row.itemName.toLowerCase().contains(query)) &&
          _matchesBucket(row.ageDays);
    }).toList()..sort((a, b) => b.ageDays.compareTo(a.ageDays));
    return rows;
  }

  bool _matchesBucket(int days) => switch (_bucket) {
    _AgingBucket.fresh => days <= 30,
    _AgingBucket.medium => days >= 31 && days <= 60,
    _AgingBucket.old => days >= 61 && days <= 90,
    _AgingBucket.veryOld => days > 90,
    _ => true,
  };

  Widget _agingCard(StockAgingItem row) => Padding(
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
              color: _color(row.ageDays).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              row.ageDays > 365 ? '>365' : '${row.ageDays}',
              style: TextStyle(
                color: _color(row.ageDays),
                fontSize: 11,
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
                  'Qty ${row.quantity} | Rp ${formatErpCurrency(row.stockValue)}',
                  style: const TextStyle(
                    color: AppColors.primary,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 15,
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

  Color _color(int days) {
    if (days > 90) return AppColors.danger;
    if (days > 60) return AppColors.warning;
    if (days > 30) return const Color(0xFFCA8A04);
    return AppColors.success;
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
