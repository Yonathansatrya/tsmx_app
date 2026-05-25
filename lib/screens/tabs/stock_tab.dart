import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../widgets/warehouse_gauge.dart';

class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String selectedWarehouseId = 'jakarta';
  String selectedAreaId = 'jakarta_inbound';

  final Map<String, String> warehouses = {
    'jakarta': 'Jakarta Distribution Hub',
    'curug': 'Curug Logistics Hub',
    'medan': 'Sumatra Depot Medan',
  };

  final Map<String, List<Map<String, dynamic>>> warehouseAreas = {
    'jakarta': [
      {
        'id': 'jakarta_inbound',
        'title': 'Inbound',
        'subtitle': 'Barang pertama masuk',
        'icon': Icons.input_rounded,
      },
      {
        'id': 'jakarta_ripening',
        'title': 'Ripening',
        'subtitle': 'Pematangan buah',
        'icon': Icons.spa_rounded,
      },
      {
        'id': 'jakarta_stores',
        'title': 'Stores',
        'subtitle': 'Stok siap jual',
        'icon': Icons.storefront_rounded,
      },
    ],
    'curug': [
      {
        'id': 'curug_stores',
        'title': 'Stores',
        'subtitle': 'Stok gudang Curug',
        'icon': Icons.storefront_rounded,
      },
    ],
    'medan': [
      {
        'id': 'medan_stores',
        'title': 'Stores',
        'subtitle': 'Stok gudang Medan',
        'icon': Icons.storefront_rounded,
      },
    ],
  };

  final Map<String, int> warehouseMaxCapacities = {
    'jakarta_inbound': 1200,
    'jakarta_ripening': 800,
    'jakarta_stores': 1500,
    'curug_stores': 1000,
    'medan_stores': 1500,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.inventory.isEmpty) {
        appState.refreshInventoryForWarehouse(selectedWarehouseId);
      }
    });
  }

  Future<void> _onPullRefresh() async {
    await context.read<AppState>().refreshInventoryForWarehouse(
      selectedWarehouseId,
    );
  }

  void _onHubChanged(String? hubId) {
    if (hubId == null) return;

    setState(() {
      selectedWarehouseId = hubId;
      selectedAreaId = warehouseAreas[hubId]!.first['id'].toString();
    });

    context.read<AppState>().refreshInventoryForWarehouse(hubId);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // inventory is refreshed in initState; UI will react to updates

    final areas = warehouseAreas[selectedWarehouseId] ?? [];

    final filteredInventory = appState.inventory.where((item) {
      return item.warehouseId == selectedAreaId;
    }).toList();

    final totalUnitsInStock = filteredInventory.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    final maxCapacity = warehouseMaxCapacities[selectedAreaId] ?? 1000;

    final capacityPercentage = (totalUnitsInStock / maxCapacity).clamp(
      0.0,
      1.0,
    );

    final double stockValue = totalUnitsInStock * 350000;

    final urgentCount = filteredInventory
        .where((item) => item.status == StockStatus.urgent)
        .length;
    final lowStockCount = filteredInventory
        .where((item) => item.status == StockStatus.lowStock)
        .length;
    final normalCount = filteredInventory
        .where((item) => item.status == StockStatus.inStock)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onPullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _buildHeader(),

            const SizedBox(height: 16),

            _buildAreaSelector(areas),

            const SizedBox(height: 16),

            if (appState.isInventoryLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (appState.inventoryError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                ),
                child: Text(
                  'Unable to load stock data: ${appState.inventoryError}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildStatusBadge(
                    label: 'Urgent',
                    value: urgentCount,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatusBadge(
                    label: 'Low Stock',
                    value: lowStockCount,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatusBadge(
                    label: 'Healthy',
                    value: normalCount,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildValuationCard(
                    stockValue: stockValue,
                    totalUnitsInStock: totalUnitsInStock,
                    maxCapacity: maxCapacity,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WarehouseGauge(
                    percentage: capacityPercentage,
                    label: _getSelectedAreaTitle(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stock Inventory List',
                  style: TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '${filteredInventory.length} items logged',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (filteredInventory.isEmpty && !appState.isInventoryLoading)
              const _StockEmptyState()
            else
              ...filteredInventory.map(_buildInventoryCard),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warehouse',
                  style: TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedWarehouseId,
                  isDense: true,
                  dropdownColor: AppColors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                  style: const TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                  items: warehouses.entries.map((w) {
                    return DropdownMenuItem<String>(
                      value: w.key,
                      child: Text(w.value),
                    );
                  }).toList(),
                  onChanged: _onHubChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSelector(List<Map<String, dynamic>> areas) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          final isSelected = selectedAreaId == area['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedAreaId = area['id'];
              });
            },
            child: Container(
              width: 155,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    area['icon'],
                    size: 22,
                    color: isSelected ? AppColors.white : AppColors.primary,
                  ),
                  const Spacer(),
                  Text(
                    area['title'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? AppColors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    area['subtitle'],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.white.withOpacity(0.75)
                          : AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildValuationCard({
    required double stockValue,
    required int totalUnitsInStock,
    required int maxCapacity,
  }) {
    return Container(
      height: 184,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ESTIMATED STOCK VALUATION',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: AppColors.slate,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            'Rp ${_formatCurrency(stockValue)}',
            style: const TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Units Stored: $totalUnitsInStock',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Capacity limit: $maxCapacity units',
                style: const TextStyle(fontSize: 10, color: AppColors.slate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    Color badgeColor = Colors.green;
    String badgeLabel = 'IN STOCK';

    if (item.status == StockStatus.lowStock) {
      badgeColor = Colors.orange;
      badgeLabel = 'LOW STOCK';
    } else if (item.status == StockStatus.urgent) {
      badgeColor = Colors.red;
      badgeLabel = 'URGENT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _smallBadge(item.sku, AppColors.slate),
                    const SizedBox(width: 6),
                    _smallBadge(badgeLabel, badgeColor),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Min stock: ${item.minStockThreshold} units',
                  style: const TextStyle(fontSize: 9, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Text(
            '${item.quantity}',
            style: TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: item.status == StockStatus.urgent
                  ? Colors.red
                  : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  String _getSelectedAreaTitle() {
    final areas = warehouseAreas[selectedWarehouseId] ?? [];

    final selected = areas.firstWhere(
      (area) => area['id'] == selectedAreaId,
      orElse: () => {'title': 'Warehouse'},
    );

    return selected['title'];
  }

  Widget _buildStatusBadge({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.85),
            ),
          ),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double val) {
    final strVal = val.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = strVal.length - 1; i >= 0; i--) {
      buffer.write(strVal[i]);
      count++;

      if (count == 3 && i > 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}

class _StockEmptyState extends StatelessWidget {
  const _StockEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slate),
          SizedBox(height: 12),
          Text(
            'No stock items in this area',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try another warehouse area or pull down to refresh.',
            style: TextStyle(color: AppColors.slate, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
