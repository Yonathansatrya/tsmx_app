import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stock_ledger_movement.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'warehouse_widgets.dart';

class WarehouseDeadStockView extends StatefulWidget {
  const WarehouseDeadStockView({super.key});

  @override
  State<WarehouseDeadStockView> createState() => _WarehouseDeadStockViewState();
}

class _WarehouseDeadStockViewState extends State<WarehouseDeadStockView> {
  final _search = TextEditingController();
  List<DeadStockItem> _rows = const [];
  int _threshold = 90;
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
      _rows = await context.read<AppState>().fetchDeadStock();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();
    final totalValue = rows.fold<double>(0, (sum, row) => sum + row.stockValue);
    final totalQty = rows.fold<int>(0, (sum, row) => sum + row.quantity);
    final warehouses = _rows.map((row) => row.warehouse).toSet().toList()
      ..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Dead Stock Monitoring',
            subtitle: 'Stok tanpa pergerakan masuk atau keluar',
            icon: Icons.inventory_2_outlined,
          ),
          warehouseSectionGap,
          Row(
            children: [
              Expanded(child: _metric('Item dead stock', '${rows.length}')),
              const SizedBox(width: 10),
              Expanded(child: _metric('Total qty', '$totalQty')),
            ],
          ),
          const SizedBox(height: 10),
          WarehouseInfoPanel(
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.warning,
            message:
                'Nilai modal tertahan: Rp ${formatErpCurrency(totalValue)}. Pergerakan diperiksa maksimal 365 hari terakhir.',
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
            initialValue: _threshold,
            decoration: const InputDecoration(
              labelText: 'Batas tanpa pergerakan',
              prefixIcon: Icon(Icons.hourglass_empty_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 90, child: Text('Minimal 90 hari')),
              DropdownMenuItem(value: 180, child: Text('Minimal 180 hari')),
              DropdownMenuItem(value: 365, child: Text('Lebih dari 365 hari')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _threshold = value);
            },
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
            title: 'Daftar Dead Stock',
            subtitle: '${rows.length} baris stok ditampilkan',
            icon: Icons.list_alt_rounded,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            const ErpEmptyState(
              title: 'Dead stock tidak ditemukan',
              message: 'Ubah batas hari, filter gudang, atau pencarian.',
            )
          else
            ...rows.map(_deadStockCard),
        ],
      ),
    );
  }

  List<DeadStockItem> _filteredRows() {
    final query = _search.text.trim().toLowerCase();
    return _rows.where((row) {
      final meetsThreshold = _threshold == 365
          ? row.inactiveDays > 365
          : row.inactiveDays >= _threshold;
      return meetsThreshold &&
          (_warehouse == null || row.warehouse == _warehouse) &&
          (query.isEmpty ||
              row.itemCode.toLowerCase().contains(query) ||
              row.itemName.toLowerCase().contains(query));
    }).toList()..sort((a, b) {
      final age = b.inactiveDays.compareTo(a.inactiveDays);
      return age != 0 ? age : b.stockValue.compareTo(a.stockValue);
    });
  }

  Widget _deadStockCard(DeadStockItem row) => Padding(
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
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              row.inactiveDays > 365 ? '>365' : '${row.inactiveDays}',
              style: const TextStyle(
                color: AppColors.danger,
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
                    color: AppColors.danger,
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

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
