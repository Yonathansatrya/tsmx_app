import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../models/stock_area_option.dart';
import '../../widgets/warehouse_gauge.dart';

class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String? _selectedHubId;
  String? _selectedAreaId;
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final appState = context.read<AppState>();
    if (appState.warehouses.isEmpty) {
      await appState.refreshWarehouses();
    }
    if (!mounted) return;

    _applyDefaultSelection(appState);

    if (appState.inventory.isEmpty && _selectedHubId != null) {
      await appState.refreshInventoryForWarehouse(_selectedHubId!);
    }

    if (appState.stockEntries.isEmpty) {
      await appState.refreshStockEntries();
    }
  }

  void _applyDefaultSelection(AppState appState) {
    final hubs = appState.stockHubs;
    if (hubs.isEmpty) return;

    final hubId = _selectedHubId ?? hubs.first.key;
    final areas = appState.stockAreasForHub(hubId);
    final areaId = _selectedAreaId ??
        (areas.isNotEmpty ? areas.first.areaId : null);

    setState(() {
      _selectedHubId = hubId;
      _selectedAreaId = areaId;
      _selectionInitialized = true;
    });
  }

  Future<void> _onPullRefresh() async {
    final appState = context.read<AppState>();
    await appState.refreshWarehouses();
    if (!mounted) return;
    _applyDefaultSelection(appState);
    if (_selectedHubId != null) {
      await appState.refreshInventoryForWarehouse(_selectedHubId!);
    }
  }

  void _onHubChanged(String? hubId) {
    if (hubId == null) return;

    final appState = context.read<AppState>();
    final areas = appState.stockAreasForHub(hubId);

    setState(() {
      _selectedHubId = hubId;
      _selectedAreaId =
          areas.isNotEmpty ? areas.first.areaId : _selectedAreaId;
    });

    appState.refreshInventoryForWarehouse(hubId);
  }

  List<InventoryItem> _inventoryForHub(AppState appState, String hubId) {
    final areaIds =
        appState.stockAreasForHub(hubId).map((a) => a.areaId).toSet();
    if (areaIds.isEmpty) return appState.inventory;

    return appState.inventory
        .where((item) => areaIds.contains(item.warehouseId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final hubs = appState.stockHubs;

    if (!_selectionInitialized && hubs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyDefaultSelection(appState);
      });
    }

    final selectedHubId = _selectedHubId;
    final areas = selectedHubId != null
        ? appState.stockAreasForHub(selectedHubId)
        : <StockAreaOption>[];

    if (selectedHubId != null &&
        areas.isNotEmpty &&
        (_selectedAreaId == null ||
            !areas.any((a) => a.areaId == _selectedAreaId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedAreaId = areas.first.areaId);
      });
    }

    final selectedAreaId = _selectedAreaId;

    final filteredInventory = selectedAreaId == null
        ? <InventoryItem>[]
        : appState.inventory
            .where((item) => item.warehouseId == selectedAreaId)
            .toList();

    final hubInventory = selectedHubId != null
        ? _inventoryForHub(appState, selectedHubId)
        : <InventoryItem>[];

    final totalUnitsInStock = filteredInventory.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    final hubTotalUnits = hubInventory.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    final capacityPercentage = hubTotalUnits > 0
        ? (totalUnitsInStock / hubTotalUnits).clamp(0.0, 1.0)
        : 0.0;

    final stockValue = filteredInventory.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.unitValue,
    );

    final hasValuation = filteredInventory.any((item) => item.unitValue > 0);

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
            _buildHeader(appState, hubs),

            const SizedBox(height: 16),

            if (areas.isNotEmpty) _buildAreaSelector(areas),

            if (areas.isEmpty && !appState.isInventoryLoading) ...[
              const SizedBox(height: 8),
              const Text(
                'No warehouses loaded from ERP. Pull down to refresh.',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],

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
                    hasValuation: hasValuation,
                    totalUnitsInStock: totalUnitsInStock,
                    hubTotalUnits: hubTotalUnits,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WarehouseGauge(
                    percentage: capacityPercentage,
                    label: _selectedAreaTitle(areas),
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

            const SizedBox(height: 24),
            _buildStockEntriesSection(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildStockEntriesSection(AppState appState) {
    final entries = appState.stockEntries.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Stock Entries',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        if (appState.isStockEntriesLoading)
          const LinearProgressIndicator()
        else if (appState.stockEntriesError != null)
          Text(
            appState.stockEntriesError!,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          )
        else if (entries.isEmpty)
          const Text(
            'No stock entries loaded.',
            style: TextStyle(fontSize: 12, color: AppColors.slate),
          )
        else
          ...entries.map(
            (e) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${e.stockEntryType} · ${e.date}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    e.statusText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(AppState appState, List<MapEntry<String, String>> hubs) {
    final hubId = _selectedHubId;
    final hubValid = hubId != null && hubs.any((h) => h.key == hubId);

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
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text(
                'Warehouse',
                style: TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              constraints: const BoxConstraints(minHeight: 32, maxHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              child: hubs.isEmpty
                  ? const Text(
                      'Loading…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: hubValid ? hubId : hubs.first.key,
                        isDense: true,
                        isExpanded: true,
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
                        items: hubs.map((h) {
                          return DropdownMenuItem<String>(
                            value: h.key,
                            child: Text(
                              h.value,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 12),
                            ),
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

  Widget _buildAreaSelector(List<StockAreaOption> areas) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          final isSelected = _selectedAreaId == area.areaId;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedAreaId = area.areaId);
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
                    area.icon,
                    size: 22,
                    color: isSelected ? AppColors.white : AppColors.primary,
                  ),
                  const Spacer(),
                  Text(
                    area.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? AppColors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    area.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    required bool hasValuation,
    required int totalUnitsInStock,
    required int hubTotalUnits,
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
            'STOCK VALUATION',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: AppColors.slate,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            hasValuation ? 'Rp ${_formatCurrency(stockValue)}' : '—',
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
                'Units in area: $totalUnitsInStock',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hubTotalUnits > 0
                    ? 'Hub total: $hubTotalUnits units'
                    : 'No stock in hub',
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
                  item.minStockThreshold > 0
                      ? 'Reorder level: ${item.minStockThreshold} units'
                      : 'Reorder level not set',
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

  String _selectedAreaTitle(List<StockAreaOption> areas) {
    for (final area in areas) {
      if (area.areaId == _selectedAreaId) return area.title;
    }
    return 'Warehouse';
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
