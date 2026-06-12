import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'warehouse_widgets.dart';

enum _ValuationSort { highestValue, lowestValue, highestQty, itemName }

class WarehouseInventoryValuationView extends StatefulWidget {
  const WarehouseInventoryValuationView({super.key});

  @override
  State<WarehouseInventoryValuationView> createState() =>
      _WarehouseInventoryValuationViewState();
}

class _WarehouseInventoryValuationViewState
    extends State<WarehouseInventoryValuationView> {
  final _search = TextEditingController();
  String? _warehouse;
  _ValuationSort _sort = _ValuationSort.highestValue;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().refreshInventory();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = _filteredRows(state.inventory);
    final totalValue = rows.fold<double>(0, (sum, row) => sum + _value(row));
    final totalQty = rows.fold<int>(0, (sum, row) => sum + row.quantity);
    final missingRate = rows.where((row) => row.unitValue <= 0).length;
    final warehouses =
        state.warehouses
            .where((row) => !row.isGroup && row.isDisabled != true)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Inventory Valuation',
            subtitle: 'Nilai stok berdasarkan qty dan valuation rate ERPNext',
            icon: Icons.payments_outlined,
          ),
          warehouseSectionGap,
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Total nilai',
                  'Rp ${formatErpCurrency(totalValue)}',
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Total qty',
                  '$totalQty',
                  Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          if (missingRate > 0) ...[
            const SizedBox(height: 10),
            WarehouseInfoPanel(
              icon: Icons.info_outline_rounded,
              color: AppColors.warning,
              message:
                  '$missingRate baris stok belum memiliki valuation rate sehingga nilainya dihitung Rp 0.',
            ),
          ],
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
                (row) => DropdownMenuItem(
                  value: row.name,
                  child: Text(row.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(
              () => _warehouse = value?.isEmpty == true ? null : value,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_ValuationSort>(
            initialValue: _sort,
            decoration: const InputDecoration(
              labelText: 'Urutkan',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            items: const [
              DropdownMenuItem(
                value: _ValuationSort.highestValue,
                child: Text('Nilai tertinggi'),
              ),
              DropdownMenuItem(
                value: _ValuationSort.lowestValue,
                child: Text('Nilai terendah'),
              ),
              DropdownMenuItem(
                value: _ValuationSort.highestQty,
                child: Text('Qty tertinggi'),
              ),
              DropdownMenuItem(
                value: _ValuationSort.itemName,
                child: Text('Nama item'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sort = value);
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
            title: 'Nilai per Item',
            subtitle: '${rows.length} baris stok ditampilkan',
            icon: Icons.list_alt_rounded,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            const ErpEmptyState(
              title: 'Data valuasi tidak ditemukan',
              message: 'Ubah filter atau tarik ke bawah untuk refresh.',
            )
          else
            ...rows.map(_valuationCard),
        ],
      ),
    );
  }

  List<InventoryItem> _filteredRows(List<InventoryItem> inventory) {
    final query = _search.text.trim().toLowerCase();
    final rows = inventory.where((row) {
      return (_warehouse == null || row.warehouseId == _warehouse) &&
          (query.isEmpty ||
              row.sku.toLowerCase().contains(query) ||
              row.name.toLowerCase().contains(query));
    }).toList();
    rows.sort(switch (_sort) {
      _ValuationSort.highestValue => (a, b) => _value(b).compareTo(_value(a)),
      _ValuationSort.lowestValue => (a, b) => _value(a).compareTo(_value(b)),
      _ValuationSort.highestQty => (a, b) => b.quantity.compareTo(a.quantity),
      _ValuationSort.itemName => (a, b) => a.name.compareTo(b.name),
    });
    return rows;
  }

  double _value(InventoryItem row) => row.quantity * row.unitValue;

  Widget _metricCard(String label, String value, IconData icon) => Container(
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
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 9),
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
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _valuationCard(InventoryItem row) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Rp ${formatErpCurrency(_value(row))}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${row.sku} | ${row.warehouseId}',
            style: const TextStyle(color: AppColors.slate, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallMetric('Qty', '${row.quantity}')),
              const SizedBox(width: 8),
              Expanded(
                child: _smallMetric(
                  'Rate',
                  'Rp ${formatErpCurrency(row.unitValue)}',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _smallMetric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.slate, fontSize: 9),
        ),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
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
