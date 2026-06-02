import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../models/stock_area_option.dart';
import '../../widgets/warehouse_gauge.dart';
import '../item_stock_detail_screen.dart';

class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String? _selectedCompany;
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

    if (appState.inventory.isEmpty && _selectedCompany != null) {
      await appState.refreshInventoryForCompany(_selectedCompany!);
    }

    if (appState.stockEntries.isEmpty) {
      await appState.refreshStockEntries();
    }
  }

  void _applyDefaultSelection(AppState appState) {
    final companies = appState.stockCompanies;
    if (companies.isEmpty) return;

    final company = _selectedCompany ?? companies.first.key;
    final areas = appState.stockWarehousesForCompany(company);
    final areaId =
        _selectedAreaId ?? (areas.isNotEmpty ? areas.first.areaId : null);

    setState(() {
      _selectedCompany = company;
      _selectedAreaId = areaId;
      _selectionInitialized = true;
    });
  }

  Future<void> _onPullRefresh() async {
    final appState = context.read<AppState>();
    await appState.refreshWarehouses();
    if (!mounted) return;
    _applyDefaultSelection(appState);
    if (_selectedCompany != null) {
      await appState.refreshInventoryForCompany(_selectedCompany!);
    }
  }

  void _onCompanyChanged(String? company) {
    if (company == null) return;

    final appState = context.read<AppState>();
    final areas = appState.stockWarehousesForCompany(company);

    setState(() {
      _selectedCompany = company;
      _selectedAreaId = areas.isNotEmpty ? areas.first.areaId : _selectedAreaId;
    });

    appState.refreshInventoryForCompany(company);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final companies = appState.stockCompanies;

    if (!_selectionInitialized && companies.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyDefaultSelection(appState);
      });
    }

    final selectedCompany = _selectedCompany;
    final areas = selectedCompany != null
        ? appState.stockWarehousesForCompany(selectedCompany)
        : <StockAreaOption>[];

    if (selectedCompany != null &&
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

    final totalBoxesInStock = filteredInventory.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    const int boxesPerSmallRoom = 900;
    const int smallRoomsUsed = 3;
    final int estimatedMaxBoxCapacity = boxesPerSmallRoom * smallRoomsUsed;

    final capacityPercentage = estimatedMaxBoxCapacity > 0
        ? (totalBoxesInStock / estimatedMaxBoxCapacity).clamp(0.0, 1.0)
        : 0.0;

    final urgentCount = filteredInventory
        .where((item) => item.status == StockStatus.urgent)
        .length;
    final lowStockCount = filteredInventory
        .where((item) => item.status == StockStatus.lowStock)
        .length;
    final normalCount = filteredInventory
        .where((item) => item.status == StockStatus.inStock)
        .length;

    const double extraBottomSpace = 140;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _onPullRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, extraBottomSpace),
            children: [
              _buildHeader(companies),

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
              WarehouseGauge(
                percentage: capacityPercentage,
                label: _selectedAreaTitle(areas),
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
                ...filteredInventory.map(
                  (item) => _buildInventoryCard(
                    item,
                    companyLabel: _companyTitle(companies, selectedCompany),
                    areaLabel: _selectedAreaTitle(areas),
                  ),
                ),

              const SizedBox(height: 24),
              _buildStockEntriesSection(appState),
            ],
          ),
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

  Widget _buildHeader(List<MapEntry<String, String>> companies) {
    final company = _selectedCompany;
    final companyValid =
        company != null && companies.any((entry) => entry.key == company);

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
              child: companies.isEmpty
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
                        value: companyValid ? company : companies.first.key,
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
                        items: companies.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: _onCompanyChanged,
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
      height: 125,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          final isSelected = _selectedAreaId == area.areaId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAreaId = area.areaId;
              });
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              scale: isSelected ? 1.03 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                width: 185,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.24)
                          : AppColors.primaryDark.withOpacity(0.05),
                      blurRadius: isSelected ? 18 : 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warehouse_rounded,
                          size: 20,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.primary,
                        ),

                        const Spacer(),

                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isSelected ? 1 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: Tooltip(
                        message: area.title,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          area.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.navy,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Tooltip(
                      message: area.subtitle,
                      waitDuration: const Duration(milliseconds: 500),
                      child: Text(
                        area.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.white.withOpacity(0.78)
                              : AppColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _companyTitle(
    List<MapEntry<String, String>> companies,
    String? company,
  ) {
    if (company == null) return null;
    for (final entry in companies) {
      if (entry.key == company) return entry.value;
    }
    return company;
  }

  void _openItemDetail(
    InventoryItem item, {
    String? companyLabel,
    String? areaLabel,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemStockDetailScreen(
          item: item,
          companyLabel: companyLabel,
          areaLabel: areaLabel,
        ),
      ),
    );
  }

  Widget _buildInventoryCard(
    InventoryItem item, {
    String? companyLabel,
    String? areaLabel,
  }) {
    Color badgeColor = Colors.green;
    String badgeLabel = 'IN STOCK';

    if (item.status == StockStatus.lowStock) {
      badgeColor = Colors.orange;
      badgeLabel = 'LOW STOCK';
    } else if (item.status == StockStatus.urgent) {
      badgeColor = Colors.red;
      badgeLabel = 'URGENT';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openItemDetail(
          item,
          companyLabel: companyLabel,
          areaLabel: areaLabel,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.slate,
                      ),
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
        ),
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
