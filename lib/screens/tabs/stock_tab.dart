import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../models/stock_area_option.dart';
import '../../widgets/warehouse_gauge.dart';
import '../stock/item_stock_detail_screen.dart';

enum _StockStatusFilter { all, urgent, lowStock, inStock }

enum _StockSortOption { urgentFirst, quantityLow, quantityHigh, name }

class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String? _selectedCompany;
  WarehouseType? _selectedWarehouseType;
  final TextEditingController _stockSearchController = TextEditingController();
  _StockStatusFilter _stockStatusFilter = _StockStatusFilter.all;
  _StockSortOption _stockSortOption = _StockSortOption.urgentFirst;
  String? _selectedCategory;
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _stockSearchController.dispose();
    super.dispose();
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
    final warehouseType =
        _selectedWarehouseType ?? _defaultWarehouseType(areas);

    setState(() {
      _selectedCompany = company;
      _selectedWarehouseType = warehouseType;
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
      _selectedWarehouseType = _defaultWarehouseType(areas);
      _selectedCategory = null;
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
        (_selectedWarehouseType == null ||
            !areas.any((a) => a.warehouseType == _selectedWarehouseType))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedWarehouseType = _defaultWarehouseType(areas));
      });
    }

    final selectedWarehouseType = _selectedWarehouseType;
    final selectedAreas = selectedWarehouseType == null
        ? <StockAreaOption>[]
        : areas
              .where((area) => area.warehouseType == selectedWarehouseType)
              .toList();
    final selectedAreaIds = selectedAreas.map((area) => area.areaId).toSet();

    final areaInventory = selectedAreaIds.isEmpty
        ? <InventoryItem>[]
        : appState.inventory
              .where((item) => selectedAreaIds.contains(item.warehouseId))
              .toList();

    final filteredInventory = _filterAndSortInventory(areaInventory);

    final totalBoxesInStock = areaInventory.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    final int estimatedMaxBoxCapacity =
        _warehouseCapacityConfig(selectedWarehouseType)?.totalCapacity ?? 0;

    final capacityPercentage = estimatedMaxBoxCapacity > 0
        ? (totalBoxesInStock / estimatedMaxBoxCapacity).clamp(0.0, 1.0)
        : 0.0;

    final urgentCount = areaInventory
        .where((item) => item.status == StockStatus.urgent)
        .length;
    final lowStockCount = areaInventory
        .where((item) => item.status == StockStatus.lowStock)
        .length;
    final normalCount = areaInventory
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

              const SizedBox(height: 14),

              if (areas.isNotEmpty) _buildAreaSelector(areas),

              if (areas.isEmpty && !appState.isInventoryLoading) ...[
                const SizedBox(height: 8),
                const Text(
                  'No warehouses loaded from ERP. Pull down to refresh.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],

              const SizedBox(height: 14),

              if (appState.isInventoryLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (appState.inventoryError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.15),
                    ),
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Warehouse Summary',
                      style: TextStyle(
                        fontFamily: 'HankenGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    Center(
                      child: WarehouseGauge(
                        percentage: capacityPercentage,
                        label: _selectedAreaTitle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _capacitySummary(selectedWarehouseType),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              _buildSectionHeader(
                'Stock Inventory',
                _inventoryCountLabel(
                  filteredInventory.length,
                  areaInventory.length,
                ),
              ),
              const SizedBox(height: 8),
              _buildInventoryControls(
                resultCount: filteredInventory.length,
                totalCount: areaInventory.length,
                currentItems: areaInventory,
              ),
              const SizedBox(height: 10),

              if (filteredInventory.isEmpty && !appState.isInventoryLoading)
                _StockEmptyState(hasActiveFilters: _hasActiveStockFilters)
              else
                ...filteredInventory.map(
                  (item) => _buildInventoryCard(
                    item,
                    companyLabel: _companyTitle(companies, selectedCompany),
                    areaLabel: _selectedAreaTitle(),
                  ),
                ),

              const SizedBox(height: 22),
              _buildStockEntriesSection(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String detail) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }

  bool get _hasActiveStockFilters {
    return _stockSearchController.text.trim().isNotEmpty ||
        _stockStatusFilter != _StockStatusFilter.all ||
        _selectedCategory != null;
  }

  List<String> _getUniqueCategories(List<InventoryItem> items) {
    final categories = <String>{};
    for (final item in items) {
      if (item.category != null && item.category!.isNotEmpty) {
        categories.add(item.category!);
      }
    }
    return categories.toList()..sort();
  }

  String _warehouseTypeLabel(WarehouseType type) {
    return switch (type) {
      WarehouseType.inbound => 'Inbound',
      WarehouseType.ripening => 'Ripening',
      WarehouseType.stores => 'Stores',
    };
  }

  Color _warehouseTypeColor(WarehouseType type) {
    return switch (type) {
      WarehouseType.inbound => const Color(0xFF2196F3), // Blue
      WarehouseType.ripening => const Color(0xFFFF9800), // Orange
      WarehouseType.stores => const Color(0xFF4CAF50), // Green
    };
  }

  Map<WarehouseType, List<StockAreaOption>> _groupAreasByType(
    List<StockAreaOption> areas,
  ) {
    final grouped = <WarehouseType, List<StockAreaOption>>{};
    for (final area in areas) {
      grouped.putIfAbsent(area.warehouseType, () => []).add(area);
    }
    return grouped;
  }

  List<WarehouseType> _availableWarehouseTypes(List<StockAreaOption> areas) {
    const orderedTypes = [
      WarehouseType.stores,
      WarehouseType.ripening,
      WarehouseType.inbound,
    ];
    return orderedTypes
        .where((type) => areas.any((area) => area.warehouseType == type))
        .toList();
  }

  WarehouseType? _defaultWarehouseType(List<StockAreaOption> areas) {
    final types = _availableWarehouseTypes(areas);
    return types.isEmpty ? null : types.first;
  }

  String _warehouseTypeDescription(WarehouseType type) {
    return switch (type) {
      WarehouseType.inbound => 'Barang datang disortir dulu',
      WarehouseType.ripening => 'Pematangan buah',
      WarehouseType.stores => 'Barang siap jual',
    };
  }

  _WarehouseCapacity? _warehouseCapacityConfig(WarehouseType? type) {
    return switch (type) {
      WarehouseType.stores => const _WarehouseCapacity(
        roomCount: 5,
        capacityPerRoom: 1000,
        roomLabel: 'ruangan kecil',
      ),
      WarehouseType.ripening => const _WarehouseCapacity(
        roomCount: 3,
        capacityPerRoom: 1000,
        roomLabel: 'ruangan kecil',
      ),
      WarehouseType.inbound => const _WarehouseCapacity(
        roomCount: 2,
        capacityPerRoom: 2000,
        roomLabel: 'ruangan besar',
      ),
      null => null,
    };
  }

  String _capacitySummary(WarehouseType? type) {
    final config = _warehouseCapacityConfig(type);
    if (config == null) return 'Capacity not set';

    return 'Capacity: ${config.roomCount} ${config.roomLabel} x ${config.capacityPerRoomLabel} = ${config.totalCapacityLabel} boxes';
  }

  List<InventoryItem> _filterAndSortInventory(List<InventoryItem> items) {
    final query = _stockSearchController.text.trim().toLowerCase();

    final filtered = items.where((item) {
      final matchesSearch =
          query.isEmpty ||
          item.sku.toLowerCase().contains(query) ||
          item.name.toLowerCase().contains(query);

      final matchesStatus = switch (_stockStatusFilter) {
        _StockStatusFilter.all => true,
        _StockStatusFilter.urgent => item.status == StockStatus.urgent,
        _StockStatusFilter.lowStock => item.status == StockStatus.lowStock,
        _StockStatusFilter.inStock => item.status == StockStatus.inStock,
      };

      final matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      return switch (_stockSortOption) {
        _StockSortOption.urgentFirst => _statusRank(
          a.status,
        ).compareTo(_statusRank(b.status)),
        _StockSortOption.quantityLow => a.quantity.compareTo(b.quantity),
        _StockSortOption.quantityHigh => b.quantity.compareTo(a.quantity),
        _StockSortOption.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      };
    });

    return filtered;
  }

  int _statusRank(StockStatus status) {
    return switch (status) {
      StockStatus.urgent => 0,
      StockStatus.lowStock => 1,
      StockStatus.inStock => 2,
    };
  }

  String _inventoryCountLabel(int filteredCount, int totalCount) {
    if (_hasActiveStockFilters) {
      return '$filteredCount of $totalCount items';
    }
    return '$totalCount items';
  }

  String _sortLabel(_StockSortOption option) {
    return switch (option) {
      _StockSortOption.urgentFirst => 'Urgent first',
      _StockSortOption.quantityLow => 'Qty low-high',
      _StockSortOption.quantityHigh => 'Qty high-low',
      _StockSortOption.name => 'Name A-Z',
    };
  }

  String _statusFilterLabel(_StockStatusFilter filter) {
    return switch (filter) {
      _StockStatusFilter.all => 'All',
      _StockStatusFilter.urgent => 'Urgent',
      _StockStatusFilter.lowStock => 'Low',
      _StockStatusFilter.inStock => 'Healthy',
    };
  }

  Color _statusFilterColor(_StockStatusFilter filter) {
    return switch (filter) {
      _StockStatusFilter.all => AppColors.primary,
      _StockStatusFilter.urgent => Colors.red,
      _StockStatusFilter.lowStock => Colors.orange,
      _StockStatusFilter.inStock => Colors.green,
    };
  }

  Widget _buildInventoryControls({
    required int resultCount,
    required int totalCount,
    required List<InventoryItem> currentItems,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _stockSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search SKU or item name',
              hintStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.slate,
              ),
              suffixIcon: _stockSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.slate,
                      onPressed: () {
                        _stockSearchController.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _StockStatusFilter.values.map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildStatusFilterChip(filter),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSortMenu(),
            ],
          ),
          const SizedBox(height: 10),
          _buildCategoryFilterSection(currentItems),
          if (_hasActiveStockFilters) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$resultCount result${resultCount == 1 ? '' : 's'} from $totalCount items',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _stockSearchController.clear();
                    setState(() {
                      _stockStatusFilter = _StockStatusFilter.all;
                      _selectedCategory = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(_StockStatusFilter filter) {
    final isSelected = _stockStatusFilter == filter;
    final color = _statusFilterColor(filter);

    return ChoiceChip(
      label: Text(_statusFilterLabel(filter)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _stockStatusFilter = filter;
        });
      },
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: isSelected ? AppColors.white : color,
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.09),
      side: BorderSide(
        color: isSelected ? color : color.withValues(alpha: 0.16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _buildCategoryFilterSection(List<InventoryItem> currentItems) {
    final categories = _getUniqueCategories(currentItems);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'Category',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slate.withValues(alpha: 0.8),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildCategoryChip(null, 'All'),
              ),
              ...categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(category, category),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
        });
      },
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isSelected ? AppColors.white : AppColors.primary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSortMenu() {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_StockSortOption>(
          value: _stockSortOption,
          isDense: true,
          dropdownColor: AppColors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          style: const TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
          items: _StockSortOption.values.map((option) {
            return DropdownMenuItem<_StockSortOption>(
              value: option,
              child: Text(_sortLabel(option)),
            );
          }).toList(),
          onChanged: (option) {
            if (option == null) return;
            setState(() {
              _stockSortOption = option;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStockEntriesSection(AppState appState) {
    final entries = appState.stockEntries.take(8).toList();

    if (appState.isStockEntriesLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Recent Stock Entries', 'Loading'),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }

    if (appState.stockEntriesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Recent Stock Entries', 'Error'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
            ),
            child: Text(
              appState.stockEntriesError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      );
    }

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Recent Stock Entries', '0 entries'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
            child: const Text(
              'No stock entries loaded.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Stock Entries', '${entries.length} latest'),
        const SizedBox(height: 8),
        ...entries.map((e) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
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
                        '${e.stockEntryType} - ${e.date}',
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
          );
        }),
      ],
    );
  }

  Widget _buildHeader(List<MapEntry<String, String>> companies) {
    final company = _selectedCompany;
    final companyValid =
        company != null && companies.any((entry) => entry.key == company);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stock overview by company and area',
                      style: TextStyle(fontSize: 11, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            child: companies.isEmpty
                ? const Text(
                    'Loading...',
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
                        fontSize: 13,
                      ),
                      items: companies.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: _onCompanyChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSelector(List<StockAreaOption> areas) {
    if (areas.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedAreas = _groupAreasByType(areas);
    final warehouseTypes = _availableWarehouseTypes(areas);

    return SizedBox(
      height: 74,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: warehouseTypes.length,
        itemBuilder: (context, index) {
          final type = warehouseTypes[index];
          final typeAreas = groupedAreas[type] ?? const <StockAreaOption>[];
          final typeColor = _warehouseTypeColor(type);
          final isSelected = _selectedWarehouseType == type;
          final capacity = _warehouseCapacityConfig(type);

          return Padding(
            padding: EdgeInsets.only(
              right: index == warehouseTypes.length - 1 ? 0 : 10,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedWarehouseType = type;
                    _selectedCategory = null;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 178,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? typeColor : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? typeColor
                          : typeColor.withValues(alpha: 0.22),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withValues(
                          alpha: isSelected ? 0.16 : 0.05,
                        ),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.white.withValues(alpha: 0.2)
                              : typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          typeAreas.isEmpty
                              ? Icons.warehouse_rounded
                              : typeAreas.first.icon,
                          size: 18,
                          color: isSelected ? AppColors.white : typeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _warehouseTypeLabel(type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              capacity == null
                                  ? '${typeAreas.length} rooms'
                                  : '${capacity.roomCount} rooms - ${capacity.totalCapacityLabel} box',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.86)
                                    : AppColors.slate,
                              ),
                            ),
                            Text(
                              _warehouseTypeDescription(type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.76)
                                    : AppColors.slate.withValues(alpha: 0.86),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
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
        color: color.withValues(alpha: 0.1),
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

  String _selectedAreaTitle() {
    final type = _selectedWarehouseType;
    return type == null ? 'Warehouse' : _warehouseTypeLabel(type);
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.85),
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
  const _StockEmptyState({required this.hasActiveFilters});

  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.slate,
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveFilters
                ? 'No stock items match your filters'
                : 'No stock items in this area',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasActiveFilters
                ? 'Try a different keyword or reset the status filter.'
                : 'Try another warehouse area or pull down to refresh.',
            style: TextStyle(color: AppColors.slate, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WarehouseCapacity {
  final int roomCount;
  final int capacityPerRoom;
  final String roomLabel;

  const _WarehouseCapacity({
    required this.roomCount,
    required this.capacityPerRoom,
    required this.roomLabel,
  });

  int get totalCapacity => roomCount * capacityPerRoom;

  String get capacityPerRoomLabel => _formatNumber(capacityPerRoom);

  String get totalCapacityLabel => _formatNumber(totalCapacity);

  static String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
