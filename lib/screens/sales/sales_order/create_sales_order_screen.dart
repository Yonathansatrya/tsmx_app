import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/sales_order.dart';
import '../../../models/sales_order_insight.dart';
import '../../../models/sales_workspace.dart';
import '../../../models/warehouse_info.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  final String? editOrderId;

  const CreateSalesOrderScreen({super.key, this.editOrderId});

  bool get isEditMode => editOrderId != null;

  @override
  State<CreateSalesOrderScreen> createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  static const _defaultWarehouseName = 'Stores - Jakarta';
  static const _defaultCompanyName = 'Distribusi Jakarta';
  static const _defaultCostCenterName = 'Sales - Jakarta';

  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final List<_AdditionalItemRow> _additionalItems = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _photos = [];
  CustomerSalesInsight? _customerInsight;
  final Map<String, ItemSalesInsight> _itemInsights = {};
  final Set<String> _loadingItemPrices = {};
  bool _isLoadingCustomerInsight = false;
  String? _customerInsightError;
  Timer? _pricingDebounce;
  int _pricingRequestVersion = 0;
  String? _selectedCurrency;
  String? _selectedPriceList;
  String? _priceListCurrency;

  TextEditingController? _itemTextController;
  String? _initialItemText;
  String? _selectedItemCode;
  String? _selectedSeries;
  String? _selectedWarehouse;
  String? _selectedCenter;
  String? _selectedSalesPerson;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedDeliveryDate = DateTime.now();

  bool _isLoadingSelectors = true;
  bool _isSaving = false;
  bool _isValidatingItem = false;
  String? _seriesError;
  String? _selectorLoadError;
  String? _customerError;
  String? _itemError;
  double _totalAmount = 0.0;

  List<String> _seriesOptions = [];
  List<String> _customerSeriesOptions = [];
  List<String> _customerTypeOptions = [];
  List<String> _customerGroupOptions = [];
  List<String> _territoryOptions = [];
  List<String> _paymentTermsOptions = [];
  List<String> _salesPersonOptions = [];
  List<String> _currencyOptions = [];
  List<String> _priceListOptions = [];
  List<_CostCenterOption> _costCenterOptions = [];
  List<_CustomerOption> _customerOptions = [];
  List<_ItemOption> _itemOptions = [];

  List<WarehouseInfo> _warehouseOptions(AppState appState) {
    final warehouses = appState.warehouses.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final seen = <String>{};
    return warehouses.where((warehouse) {
      final name = warehouse.name.trim();
      if (name.isEmpty || warehouse.isDisabled == true || seen.contains(name)) {
        return false;
      }
      seen.add(name);
      return true;
    }).toList();
  }

  String? _defaultWarehouse(List<WarehouseInfo> warehouses) {
    for (final warehouse in warehouses) {
      if (warehouse.name.trim().toLowerCase() ==
          _defaultWarehouseName.toLowerCase()) {
        return warehouse.name;
      }
    }
    for (final warehouse in warehouses) {
      if (warehouse.company.trim().toLowerCase() ==
          _defaultCompanyName.toLowerCase()) {
        return warehouse.name;
      }
    }
    return warehouses.isNotEmpty ? warehouses.first.name : null;
  }

  Future<void> _ensureWarehouseEnabled(AppState appState) async {
    final warehouse = _selectedWarehouse?.trim() ?? '';
    if (warehouse.isEmpty) return;

    final document = await appState.frappeService.fetchDocument(
      'Warehouse',
      warehouse,
    );
    final disabled = document['disabled'] == 1 || document['disabled'] == true;
    final isGroup = document['is_group'] == 1 || document['is_group'] == true;
    if (disabled || isGroup) {
      throw Exception(
        disabled
            ? 'Warehouse $warehouse sudah dinonaktifkan. Pilih warehouse lain.'
            : 'Warehouse $warehouse merupakan group dan tidak dapat digunakan.',
      );
    }
  }

  List<String> _splitFrappeOptions(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    }

    return raw
            ?.toString()
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        <String>[];
  }

  List<String> _normalizeOptions(List<String> options) {
    final seen = <String>{};
    final result = <String>[];
    for (var option in options) {
      final trimmed = option.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(trimmed);
    }
    return result;
  }

  List<_CostCenterOption> _normalizeCostCenterOptions(
    List<_CostCenterOption> options,
  ) {
    final seen = <String>{};
    final result = <_CostCenterOption>[];
    for (final option in options) {
      final trimmed = option.name.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(option);
    }
    return result;
  }

  Future<List<String>> _fetchSalesOrderSeriesOptions(AppState appState) async {
    return appState.fetchNamingSeries('Sales Order');
  }

  Future<List<String>> _fetchDocTypeSelectOptions(
    AppState appState, {
    required String doctype,
    required String fieldname,
  }) async {
    try {
      final docType = await appState.frappeService.fetchDocument(
        'DocType',
        doctype,
      );
      final fields = docType['fields'];
      if (fields is List) {
        for (final row in fields) {
          if (row is! Map) continue;
          if (row['fieldname']?.toString() != fieldname) continue;
          return _splitFrappeOptions(row['options']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> _fetchLinkOptions(
    AppState appState, {
    required String doctype,
    List<List<dynamic>>? filters,
  }) async {
    final data = await appState.frappeService.fetchResource(
      doctype,
      fields: const ['name'],
      filters: filters,
      orderBy: 'name asc',
    );
    return data
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String _selectorErrorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  Future<T> _loadSelector<T>({
    required String label,
    required Future<T> Function() load,
    required T fallback,
    required List<String> errors,
  }) async {
    try {
      return await load();
    } catch (error) {
      errors.add('$label: ${_selectorErrorMessage(error)}');
      return fallback;
    }
  }

  Future<List<String>> _fetchSalesPersonOptions(AppState appState) async {
    Future<List<String>> fetch(List<List<dynamic>> filters) async {
      final data = await appState.frappeService.fetchResource(
        'Sales Person',
        fields: const ['name'],
        filters: filters,
        orderBy: 'name asc',
      );
      return data
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    }

    try {
      return await fetch(const [
        ['is_group', '=', 0],
        ['enabled', '=', 1],
      ]);
    } catch (_) {
      return fetch(const [
        ['is_group', '=', 0],
      ]);
    }
  }

  WarehouseInfo? _selectedWarehouseInfo(List<WarehouseInfo> warehouses) {
    for (final warehouse in warehouses) {
      if (warehouse.name == _selectedWarehouse) return warehouse;
    }
    return null;
  }

  List<_CostCenterOption> _costCentersForWarehouse(
    List<WarehouseInfo> warehouses,
  ) {
    final company = _selectedWarehouseInfo(warehouses)?.company ?? '';
    if (company.isEmpty) return _costCenterOptions;

    final filtered = _costCenterOptions
        .where((center) => center.company == company)
        .toList();
    return filtered.isNotEmpty ? filtered : _costCenterOptions;
  }

  String _selectedCompany(List<WarehouseInfo> warehouses) {
    return _selectedWarehouseInfo(warehouses)?.company ?? '';
  }

  Future<List<_CostCenterOption>> _fetchCostCenterOptions(
    AppState appState,
  ) async {
    Future<List<_CostCenterOption>> fetch({
      required List<String> fields,
      List<List<dynamic>>? filters,
    }) async {
      final data = await appState.frappeService.fetchResource(
        'Cost Center',
        fields: fields,
        filters: filters,
        orderBy: 'name asc',
      );
      return data
          .map((row) {
            final name = row['name']?.toString() ?? '';
            if (name.isEmpty) return null;
            return _CostCenterOption(
              name: name,
              company: row['company']?.toString() ?? '',
            );
          })
          .whereType<_CostCenterOption>()
          .toList();
    }

    try {
      return await fetch(
        fields: const ['name', 'company', 'is_group', 'disabled'],
        filters: const [
          ['is_group', '=', 0],
          ['disabled', '=', 0],
        ],
      );
    } catch (_) {
      try {
        return await fetch(
          fields: const ['name', 'company', 'is_group'],
          filters: const [
            ['is_group', '=', 0],
          ],
        );
      } catch (_) {
        try {
          return await fetch(fields: const ['name', 'company']);
        } catch (_) {
          return fetch(fields: const ['name']);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_onPricingInputChanged);
    _rateCtrl.addListener(_calculateTotal);
    _discountCtrl.addListener(_calculateTotal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      final defaultWarehouse = _defaultWarehouse(_warehouseOptions(appState));
      if (defaultWarehouse != null && _selectedWarehouse == null) {
        setState(() => _selectedWarehouse = defaultWarehouse);
      }
      _loadSelectors();
    });
  }

  @override
  void dispose() {
    _pricingDebounce?.cancel();
    _customerCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discountCtrl.dispose();
    for (final row in _additionalItems) {
      row.dispose();
    }
    _itemTextController = null;
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {
      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
      final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
      final subtotal =
          (qty * (rate - discount).clamp(0, double.infinity)) +
          _additionalItems.fold<double>(0, (total, row) {
            final rowQty = double.tryParse(row.qtyController.text.trim()) ?? 0;
            final rowRate =
                double.tryParse(row.rateController.text.trim()) ?? 0;
            final rowDiscount =
                double.tryParse(row.discountController.text.trim()) ?? 0;
            return total +
                (rowQty * (rowRate - rowDiscount).clamp(0, double.infinity));
          });
      _totalAmount = subtotal;
    });
  }

  void _onPricingInputChanged() {
    _calculateTotal();
    _scheduleRepriceAllItems();
  }

  void _addItemRow() {
    final row = _AdditionalItemRow();
    row.qtyController.addListener(_onPricingInputChanged);
    row.rateController.addListener(_calculateTotal);
    row.discountController.addListener(_calculateTotal);
    setState(() => _additionalItems.add(row));
  }

  void _scheduleRepriceAllItems() {
    _pricingRequestVersion++;
    _pricingDebounce?.cancel();
    _pricingDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _repriceAllItems();
    });
  }

  Future<void> _repriceAllItems() async {
    final firstCode = _selectedItemCode;
    if (firstCode != null && firstCode.isNotEmpty) {
      await _loadItemInsight(firstCode, applyPrice: true);
    }
    for (final row in _additionalItems) {
      final code = row.itemCode;
      if (code != null && code.isNotEmpty) {
        await _loadItemInsight(code, applyPrice: true, row: row);
      }
    }
  }

  void _removeItemRow(int index) {
    final row = _additionalItems.removeAt(index);
    row.dispose();
    _calculateTotal();
  }

  List<Map<String, dynamic>> _buildItemsPayload(String firstItemCode) {
    final deliveryDate = _selectedDeliveryDate
        .toIso8601String()
        .split('T')
        .first;
    Map<String, dynamic> itemPayload({
      required String itemCode,
      required double qty,
      double? rate,
      double? discountAmount,
      String? warehouse,
    }) {
      final pricing = _itemInsights[itemCode];
      return {
        'item_code': itemCode,
        'qty': qty,
        'delivery_date': deliveryDate,
        if (rate != null && rate > 0) 'rate': rate,
        if (discountAmount != null && discountAmount > 0)
          'discount_amount': discountAmount,
        if (pricing != null && pricing.priceListRate > 0)
          'price_list_rate': pricing.priceListRate,
        if ((discountAmount == null || discountAmount <= 0) &&
            pricing != null &&
            pricing.discountPercentage > 0)
          'discount_percentage': pricing.discountPercentage,
        if ((discountAmount == null || discountAmount <= 0) &&
            pricing != null &&
            pricing.pricingRule.isNotEmpty)
          'pricing_rule': pricing.pricingRule,
        if (warehouse != null && warehouse.trim().isNotEmpty)
          'warehouse': warehouse.trim(),
        if (_selectedCenter != null && _selectedCenter!.trim().isNotEmpty)
          'cost_center': _selectedCenter!.trim(),
      };
    }

    return [
      itemPayload(
        itemCode: firstItemCode,
        qty: double.parse(_qtyCtrl.text.trim()),
        rate: double.tryParse(_rateCtrl.text.trim()),
        discountAmount: double.tryParse(_discountCtrl.text.trim()),
        warehouse: _selectedWarehouse,
      ),
      ..._additionalItems.map(
        (row) => itemPayload(
          itemCode: row.itemCode!,
          qty: double.parse(row.qtyController.text.trim()),
          rate: double.tryParse(row.rateController.text.trim()),
          discountAmount: double.tryParse(row.discountController.text.trim()),
          warehouse: row.warehouse ?? _selectedWarehouse,
        ),
      ),
    ];
  }

  Future<void> _loadCustomerInsight() async {
    final customer = _customerCtrl.text.trim();
    if (customer.isEmpty) return;
    setState(() {
      _isLoadingCustomerInsight = true;
      _customerInsightError = null;
    });
    try {
      final insight = await context.read<AppState>().fetchCustomerSalesInsight(
        customer,
        company: _selectedCompany(_warehouseOptions(context.read<AppState>())),
      );
      if (!mounted) return;
      setState(() {
        _customerInsight = insight;
        _selectedPriceList = insight.priceList.isNotEmpty
            ? insight.priceList
            : _selectedPriceList;
        _selectedCurrency = insight.currency.isNotEmpty
            ? insight.currency
            : _selectedCurrency;
        _priceListCurrency = insight.priceListCurrency.isNotEmpty
            ? insight.priceListCurrency
            : (_selectedCurrency ?? _priceListCurrency);
      });
      await _repriceAllItems();
    } catch (error) {
      if (!mounted) return;
      setState(() => _customerInsightError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCustomerInsight = false);
    }
  }

  Future<ItemSalesInsight?> _loadItemInsight(
    String itemCode, {
    bool applyPrice = false,
    _AdditionalItemRow? row,
  }) async {
    if (itemCode.isEmpty) return null;
    final requestVersion = _pricingRequestVersion;
    final loadingKey = row == null ? 'first:$itemCode' : 'row:${row.hashCode}';
    setState(() => _loadingItemPrices.add(loadingKey));
    try {
      final appState = context.read<AppState>();
      final qty =
          double.tryParse((row?.qtyController ?? _qtyCtrl).text.trim()) ?? 1;
      final insight = await context.read<AppState>().fetchItemSalesInsight(
        itemCode,
        customer: _customerCtrl.text.trim(),
        company: _selectedCompany(_warehouseOptions(appState)),
        priceList: _selectedPriceList,
        currency: _selectedCurrency,
        warehouse: row?.warehouse ?? _selectedWarehouse,
        transactionDate: _selectedDate,
        qty: qty,
        ignorePricingRule: false,
      );
      if (!mounted || requestVersion != _pricingRequestVersion) return insight;
      if (row == null && _selectedItemCode != itemCode) return insight;
      if (row != null && row.itemCode != itemCode) return insight;
      setState(() {
        _itemInsights[itemCode] = insight;
        if (applyPrice && insight.price > 0) {
          if (row == null) {
            _rateCtrl.text = insight.price.toString();
          } else {
            row.rateController.text = insight.price.toString();
          }
        }
      });
      return insight;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil stok/harga: $error')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _loadingItemPrices.remove(loadingKey));
    }
  }

  Future<void> _showItemInsight(String itemCode) async {
    final insight = _itemInsights[itemCode] ?? await _loadItemInsight(itemCode);
    if (!mounted || insight == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                insight.itemCode,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                insight.price > 0
                    ? '${insight.priceList}: ${insight.currency} ${insight.price.toStringAsFixed(0)}'
                    : 'Harga price list tidak ditemukan',
              ),
              const SizedBox(height: 12),
              const Text(
                'Stock per Gudang',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: insight.stocks
                      .map(
                        (stock) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(stock.warehouse),
                          subtitle: Text(
                            'Reserved ${stock.reservedQty.toStringAsFixed(0)} | '
                            'Projected ${stock.projectedQty.toStringAsFixed(0)}',
                          ),
                          trailing: Text(
                            stock.actualQty.toStringAsFixed(0),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  void _showCustomerHistory() {
    final customer = _customerCtrl.text.trim();
    if (customer.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CustomerHistorySheet(
        customer: customer,
        company: _selectedCompany(
          _warehouseOptions(this.context.read<AppState>()),
        ),
      ),
    );
  }

  Future<bool> _confirmOrderRisks(List<Map<String, dynamic>> items) async {
    final warnings = <String>[];
    final customer = _customerInsight;
    if (customer != null &&
        customer.creditLimit > 0 &&
        customer.outstanding + _totalAmount > customer.creditLimit) {
      warnings.add(
        'Total order melewati limit kredit customer sebesar '
        'Rp ${(customer.outstanding + _totalAmount - customer.creditLimit).toStringAsFixed(0)}.',
      );
    }

    for (final item in items) {
      final itemCode = item['item_code']?.toString() ?? '';
      final warehouse = item['warehouse']?.toString() ?? '';
      final qty = (item['qty'] as num?)?.toDouble() ?? 0;
      if (itemCode.isEmpty || warehouse.isEmpty) continue;
      final insight =
          _itemInsights[itemCode] ?? await _loadItemInsight(itemCode);
      if (insight == null) continue;
      final matching = insight.stocks.where(
        (row) => row.warehouse == warehouse,
      );
      final actual = matching.isEmpty ? 0 : matching.first.actualQty;
      if (actual < qty) {
        warnings.add(
          '$itemCode di $warehouse hanya tersedia ${actual.toStringAsFixed(0)}, '
          'order ${qty.toStringAsFixed(0)}.',
        );
      }
    }

    if (warnings.isEmpty || !mounted) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Konfirmasi Risiko Order'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: warnings
                    .map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $warning'),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Periksa Lagi'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tetap Simpan Draft'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _normalizeItemCode(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'\(([^)]+)\)\$').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return trimmed;
  }

  Future<void> _validateItem(String value) async {
    final candidate = _selectedItemCode ?? _normalizeItemCode(value);
    if (candidate.isEmpty) {
      setState(() => _itemError = null);
      return;
    }

    setState(() => _isValidatingItem = true);
    try {
      final appState = context.read<AppState>();
      await appState.frappeService.fetchDocument('Item', candidate);
      if (!mounted) return;
      setState(() => _itemError = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _itemError = 'Item tidak ditemukan');
    } finally {
      if (mounted) {
        setState(() => _isValidatingItem = false);
      }
    }
  }

  List<_CustomerOption> _filteredCustomers(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _customerOptions.take(30).toList();

    return _customerOptions.where((customer) {
      return customer.id.toLowerCase().contains(normalized) ||
          customer.name.toLowerCase().contains(normalized);
    }).toList();
  }

  _CustomerOption? _selectedCustomerOption() {
    final id = _customerCtrl.text.trim();
    for (final customer in _customerOptions) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  Future<void> _showCustomerSelectSheet() async {
    String? selectedCustomerId;
    var shouldAddCustomer = false;

    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final customers = _filteredCustomers(query);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Customer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Search nama customer',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  if (context.read<AppState>().userRole != 'Sales') ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext, true);
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add Customer Baru'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * 0.42,
                    child: customers.isEmpty
                        ? const Center(
                            child: Text(
                              'Customer tidak ditemukan',
                              style: TextStyle(color: AppColors.slate),
                            ),
                          )
                        : ListView.separated(
                            itemCount: customers.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final customer = customers[index];
                              final selected =
                                  customer.id == _customerCtrl.text.trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: customer.name == customer.id
                                    ? null
                                    : Text(customer.id),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheetContext, customer.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result is bool && result) {
      shouldAddCustomer = true;
    } else if (result is String && result.isNotEmpty) {
      selectedCustomerId = result;
    }

    if (selectedCustomerId != null && mounted) {
      setState(() {
        _customerCtrl.text = selectedCustomerId!;
        _customerError = null;
        _customerInsight = null;
        _customerInsightError = null;
        _pricingRequestVersion++;
        _itemInsights.clear();
      });
      await _loadCustomerInsight();
    }

    if (shouldAddCustomer && mounted) {
      await _showAddCustomerSheet();
    }
  }

  Future<void> _showAddCustomerSheet() async {
    final appState = context.read<AppState>();
    final warehouses = _warehouseOptions(appState);
    final company = _selectedCompany(warehouses);
    final nameCtrl = TextEditingController(text: _customerCtrl.text.trim());
    final formKey = GlobalKey<FormState>();
    String? selectedSeries = _customerSeriesOptions.isNotEmpty
        ? _customerSeriesOptions.first
        : null;
    String? selectedType = _customerTypeOptions.isNotEmpty
        ? _customerTypeOptions.first
        : null;
    String? selectedGroup = _customerGroupOptions.isNotEmpty
        ? _customerGroupOptions.first
        : null;
    String? selectedTerritory = _territoryOptions.isNotEmpty
        ? _territoryOptions.first
        : null;
    String? selectedPaymentTerms = _paymentTermsOptions.isNotEmpty
        ? _paymentTermsOptions.first
        : null;

    if (company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih warehouse terlebih dahulu untuk menentukan company.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        var isCreatingCustomer = false;
        var sheetOpen = true;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              if (selectedSeries == null ||
                  selectedType == null ||
                  selectedPaymentTerms == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Series, type, dan payment terms wajib tersedia dari Frappe.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              setSheetState(() => isCreatingCustomer = true);
              try {
                final created = await appState.createCustomer(
                  customerName: nameCtrl.text.trim(),
                  customerType: selectedType!,
                  namingSeries: selectedSeries!,
                  paymentTerms: selectedPaymentTerms!,
                  company: company,
                  customerGroup: selectedGroup,
                  territory: selectedTerritory,
                );
                final customerId =
                    created['name']?.toString() ?? nameCtrl.text.trim();
                if (!mounted || !sheetContext.mounted) return;
                setState(() {
                  _customerCtrl.text = customerId;
                  _customerError = null;
                  if (!_customerOptions.any(
                    (customer) => customer.id == customerId,
                  )) {
                    _customerOptions = [
                      _CustomerOption(
                        id: customerId,
                        name: nameCtrl.text.trim(),
                      ),
                      ..._customerOptions,
                    ];
                  }
                });
                setSheetState(() => isCreatingCustomer = false);
                sheetOpen = false;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Customer $customerId berhasil dibuat'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal membuat customer: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } finally {
                if (mounted && sheetOpen) {
                  setSheetState(() => isCreatingCustomer = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Customer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Customer name wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _buildSheetDropdown(
                      label: 'Series',
                      value: selectedSeries,
                      options: _customerSeriesOptions,
                      onChanged: (value) =>
                          setSheetState(() => selectedSeries = value),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetDropdown(
                      label: 'Customer Type',
                      value: selectedType,
                      options: _customerTypeOptions,
                      onChanged: (value) =>
                          setSheetState(() => selectedType = value),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetDropdown(
                      label: 'Customer Group',
                      value: selectedGroup,
                      options: _customerGroupOptions,
                      requiredField: false,
                      onChanged: (value) =>
                          setSheetState(() => selectedGroup = value),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetDropdown(
                      label: 'Territory',
                      value: selectedTerritory,
                      options: _territoryOptions,
                      requiredField: false,
                      onChanged: (value) =>
                          setSheetState(() => selectedTerritory = value),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetDropdown(
                      label: 'Payment Terms',
                      value: selectedPaymentTerms,
                      options: _paymentTermsOptions,
                      onChanged: (value) =>
                          setSheetState(() => selectedPaymentTerms = value),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: isCreatingCustomer ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isCreatingCustomer
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Create Customer'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool requiredField = true,
  }) {
    final normalizedOptions = _normalizeOptions(options);
    return DropdownButtonFormField<String>(
      initialValue: normalizedOptions.contains(value)
          ? value
          : (normalizedOptions.isNotEmpty ? normalizedOptions.first : null),
      decoration: InputDecoration(labelText: label),
      items: normalizedOptions
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: normalizedOptions.isEmpty ? null : onChanged,
      validator: (value) =>
          requiredField && (value == null || value.trim().isEmpty)
          ? '$label wajib diisi'
          : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeliveryDate.isBefore(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery Date tidak boleh sebelum Transaction Date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedSeries == null || _selectedSeries!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Naming series Sales Order wajib dipilih'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedWarehouse == null || _selectedWarehouse!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warehouse wajib dipilih'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final appState = context.read<AppState>();
    final customerSalesTeam = _selectedCustomerOption()?.salesTeam ?? const [];
    if (appState.userRole == 'Sales' && customerSalesTeam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.salesIdentityError ??
                'Customer belum memiliki Sales Team untuk akun Sales ini.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (appState.userRole != 'Sales' &&
        (_selectedSalesPerson == null ||
            _selectedSalesPerson!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales Person wajib dipilih'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_customerError != null || _itemError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan validasi customer dan item terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final invalidAdditionalItem = _additionalItems.any((row) {
      final qty = double.tryParse(row.qtyController.text.trim());
      final rateText = row.rateController.text.trim();
      final rate = rateText.isEmpty ? 0 : double.tryParse(rateText);
      return row.itemCode == null ||
          row.itemCode!.isEmpty ||
          qty == null ||
          qty <= 0 ||
          rate == null ||
          rate < 0;
    });
    if (invalidAdditionalItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi item tambahan, qty, dan harga dengan benar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _ensureWarehouseEnabled(appState);
      final itemCode = (_selectedItemCode ?? '').isNotEmpty
          ? _selectedItemCode!
          : _normalizeItemCode(_itemTextController?.text ?? '');
      if (itemCode.isEmpty) {
        throw Exception('Item code tidak boleh kosong');
      }
      final items = _buildItemsPayload(itemCode);
      if (!await _confirmOrderRisks(items)) return;
      final selectedWarehouseInfo = _selectedWarehouseInfo(
        _warehouseOptions(appState),
      );
      final SalesOrder savedOrder;
      if (widget.isEditMode) {
        savedOrder = await appState.updateSalesOrder(
          orderId: widget.editOrderId!,
          customer: _customerCtrl.text.trim(),
          items: items,
          warehouse: _selectedWarehouse,
          costCenter: _selectedCenter,
          company: selectedWarehouseInfo?.company,
          currency: _selectedCurrency,
          sellingPriceList: _selectedPriceList,
          priceListCurrency: _priceListCurrency,
          ignorePricingRule: false,
          salesPerson: appState.userRole == 'Sales'
              ? null
              : _selectedSalesPerson,
          salesTeam: appState.userRole == 'Sales' ? customerSalesTeam : null,
          transactionDate: _selectedDate,
          deliveryDate: _selectedDeliveryDate,
        );
      } else {
        savedOrder = await appState.createSalesOrder(
          customer: _customerCtrl.text.trim(),
          items: items,
          warehouse: _selectedWarehouse,
          series: _selectedSeries,
          costCenter: _selectedCenter,
          company: selectedWarehouseInfo?.company,
          currency: _selectedCurrency,
          sellingPriceList: _selectedPriceList,
          priceListCurrency: _priceListCurrency,
          salesPerson: appState.userRole == 'Sales'
              ? null
              : _selectedSalesPerson,
          salesTeam: appState.userRole == 'Sales' ? customerSalesTeam : null,
          transactionDate: _selectedDate,
          deliveryDate: _selectedDeliveryDate,
        );
      }
      var failedUploads = 0;
      final uploadErrors = <String>[];
      for (final photo in _photos) {
        try {
          await appState.uploadSalesOrderAttachment(savedOrder.id, photo.path);
        } catch (error) {
          failedUploads++;
          uploadErrors.add(error.toString());
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.isEditMode ? 'Sales Order berhasil diperbarui' : 'Sales Order berhasil dibuat'}'
            '${failedUploads > 0 ? ', tetapi $failedUploads foto gagal di-upload' : ''}',
          ),
          backgroundColor: failedUploads > 0
              ? Colors.orange
              : AppColors.primary,
        ),
      );
      if (uploadErrors.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Attachment Gagal'),
            content: Text(uploadErrors.join('\n\n')),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Gagal memperbarui Sales Order: $e'
                : 'Gagal membuat Sales Order: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _loadSelectors() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoadingSelectors = true;
      _selectorLoadError = null;
    });

    try {
      final selectorErrors = <String>[];
      final seriesOptions = await _loadSelector<List<String>>(
        label: 'Series Sales Order',
        load: () => _fetchSalesOrderSeriesOptions(appState),
        fallback: const [],
        errors: selectorErrors,
      );
      final costCenters = await _loadSelector<List<_CostCenterOption>>(
        label: 'Cost Center',
        load: () => _fetchCostCenterOptions(appState),
        fallback: const [],
        errors: selectorErrors,
      );
      final customerSeriesOptions = await _fetchDocTypeSelectOptions(
        appState,
        doctype: 'Customer',
        fieldname: 'naming_series',
      );
      final customerTypeOptions = await _fetchDocTypeSelectOptions(
        appState,
        doctype: 'Customer',
        fieldname: 'customer_type',
      );
      final customerGroupOptions = await _loadSelector<List<String>>(
        label: 'Customer Group',
        load: () => _fetchLinkOptions(
          appState,
          doctype: 'Customer Group',
          filters: const [
            ['is_group', '=', 0],
          ],
        ),
        fallback: const [],
        errors: selectorErrors,
      );
      final territoryOptions = await _loadSelector<List<String>>(
        label: 'Territory',
        load: () => _fetchLinkOptions(
          appState,
          doctype: 'Territory',
          filters: const [
            ['is_group', '=', 0],
          ],
        ),
        fallback: const [],
        errors: selectorErrors,
      );
      final paymentTermsOptions = await _loadSelector<List<String>>(
        label: 'Payment Terms Template',
        load: () =>
            _fetchLinkOptions(appState, doctype: 'Payment Terms Template'),
        fallback: const [],
        errors: selectorErrors,
      );
      final salesPersonOptions = await _loadSelector<List<String>>(
        label: 'Sales Person',
        load: () => _fetchSalesPersonOptions(appState),
        fallback: const [],
        errors: selectorErrors,
      );
      final currencyOptions = await _loadSelector<List<String>>(
        label: 'Currency',
        load: () => _fetchLinkOptions(appState, doctype: 'Currency'),
        fallback: const [],
        errors: selectorErrors,
      );
      var priceListOptions = await _loadSelector<List<String>>(
        label: 'Price List',
        load: () => _fetchLinkOptions(
          appState,
          doctype: 'Price List',
          filters: const [
            ['selling', '=', 1],
            ['enabled', '=', 1],
          ],
        ),
        fallback: const [],
        errors: selectorErrors,
      );
      if (priceListOptions.isEmpty) {
        priceListOptions = await _loadSelector<List<String>>(
          label: 'Price List',
          load: () => _fetchLinkOptions(
            appState,
            doctype: 'Price List',
            filters: const [
              ['selling', '=', 1],
            ],
          ),
          fallback: const [],
          errors: selectorErrors,
        );
      }
      String defaultSellingPriceList = '';
      try {
        final sellingSettings = await appState.frappeService.fetchDocument(
          'Selling Settings',
          'Selling Settings',
        );
        defaultSellingPriceList =
            sellingSettings['selling_price_list']?.toString() ??
            sellingSettings['default_price_list']?.toString() ??
            '';
      } catch (_) {}

      final salesCustomers = await _loadSelector<List<SalesCustomerOption>>(
        label: 'Customer / Sales Team',
        load: appState.fetchSalesCustomers,
        fallback: const [],
        errors: selectorErrors,
      );
      final customerOptions = salesCustomers
          .map(
            (customer) => _CustomerOption(
              id: customer.id,
              name: customer.name,
              salesTeam: customer.salesTeam,
            ),
          )
          .toList();

      final itemData = await _loadSelector<List<Map<String, dynamic>>>(
        label: 'Item',
        load: () async {
          try {
            return await appState.frappeService.fetchResource(
              'Item',
              fields: const ['name', 'item_name'],
              orderBy: 'item_name asc',
            );
          } catch (_) {
            return appState.frappeService.fetchResource(
              'Item',
              fields: const ['name'],
              orderBy: 'name asc',
            );
          }
        },
        fallback: const [],
        errors: selectorErrors,
      );

      final itemOptions = itemData
          .map((row) {
            final code = row['name']?.toString() ?? '';
            final name = row['item_name']?.toString() ?? code;
            if (code.isEmpty) return null;
            return _ItemOption(code: code, name: name);
          })
          .whereType<_ItemOption>()
          .toList();

      if (appState.warehouses.isEmpty) {
        await _loadSelector<void>(
          label: 'Warehouse',
          load: appState.refreshWarehouses,
          fallback: null,
          errors: selectorErrors,
        );
      }
      final warehouseOptions = _warehouseOptions(appState);
      final selectedWarehouseValid = warehouseOptions.any(
        (warehouse) => warehouse.name == _selectedWarehouse,
      );
      final selectedWarehouse = selectedWarehouseValid
          ? _selectedWarehouse
          : _defaultWarehouse(warehouseOptions);
      String selectedWarehouseCompany = '';
      for (final warehouse in warehouseOptions) {
        if (warehouse.name == selectedWarehouse) {
          selectedWarehouseCompany = warehouse.company;
          break;
        }
      }
      String companyCurrency = '';
      if (selectedWarehouseCompany.isNotEmpty) {
        try {
          final companyDoc = await appState.frappeService.fetchDocument(
            'Company',
            selectedWarehouseCompany,
          );
          companyCurrency =
              companyDoc['default_currency']?.toString() ??
              companyDoc['currency']?.toString() ??
              '';
        } catch (_) {}
      }
      final availableCostCenters = selectedWarehouseCompany.isEmpty
          ? costCenters
          : costCenters
                .where((center) => center.company == selectedWarehouseCompany)
                .toList();
      final costCenterChoices = availableCostCenters.isNotEmpty
          ? availableCostCenters
          : costCenters;
      String? defaultCostCenter;
      for (final center in costCenterChoices) {
        if (center.name.trim().toLowerCase() ==
            _defaultCostCenterName.toLowerCase()) {
          defaultCostCenter = center.name;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _seriesOptions = _normalizeOptions(seriesOptions);
        _seriesError = seriesOptions.isEmpty
            ? 'Series Sales Order tidak dapat dibaca.'
            : null;
        _selectorLoadError = selectorErrors.isEmpty
            ? null
            : selectorErrors.toSet().join('\n');
        _customerSeriesOptions = _normalizeOptions(customerSeriesOptions);
        _customerTypeOptions = _normalizeOptions(customerTypeOptions);
        _customerGroupOptions = _normalizeOptions(customerGroupOptions);
        _territoryOptions = _normalizeOptions(territoryOptions);
        _paymentTermsOptions = _normalizeOptions(paymentTermsOptions);
        _salesPersonOptions = _normalizeOptions(salesPersonOptions);
        _currencyOptions = _normalizeOptions(currencyOptions);
        _priceListOptions = _normalizeOptions(priceListOptions);
        _costCenterOptions = _normalizeCostCenterOptions(costCenters);
        _customerOptions = customerOptions;
        _selectedSeries = _seriesOptions.contains(_selectedSeries)
            ? _selectedSeries
            : (_seriesOptions.isNotEmpty ? _seriesOptions.first : null);
        _selectedCenter =
            costCenterChoices.any((center) => center.name == _selectedCenter)
            ? _selectedCenter
            : (defaultCostCenter ??
                  (costCenterChoices.isNotEmpty
                      ? costCenterChoices.first.name
                      : null));
        _selectedSalesPerson = appState.userRole == 'Sales'
            ? appState.currentSalesPerson
            : (_salesPersonOptions.contains(_selectedSalesPerson)
                  ? _selectedSalesPerson
                  : (_salesPersonOptions.isNotEmpty
                        ? _salesPersonOptions.first
                        : null));
        _itemOptions = itemOptions;
        _selectedWarehouse = selectedWarehouse;
        _selectedCurrency = _currencyOptions.contains(_selectedCurrency)
            ? _selectedCurrency
            : (_currencyOptions.contains(companyCurrency)
                  ? companyCurrency
                  : (_currencyOptions.isNotEmpty
                        ? _currencyOptions.first
                        : null));
        _selectedPriceList = _priceListOptions.contains(_selectedPriceList)
            ? _selectedPriceList
            : (_priceListOptions.contains(defaultSellingPriceList)
                  ? defaultSellingPriceList
                  : (_priceListOptions.isNotEmpty
                        ? _priceListOptions.first
                        : null));
        _priceListCurrency ??= _selectedCurrency;
      });
      if (widget.isEditMode) {
        final editingOrder = await appState.loadSalesOrderDetail(
          widget.editOrderId!,
        );
        if (!mounted) return;
        _applyEditingOrder(editingOrder);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectorLoadError = _selectorErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSelectors = false;
        });
      }
    }
  }

  void _applyEditingOrder(SalesOrder order) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    for (final row in _additionalItems) {
      row.dispose();
    }
    _additionalItems.clear();
    for (final item in order.items.skip(1)) {
      final row = _AdditionalItemRow(
        itemCode: item.itemCode,
        qty: item.qty.toString(),
        rate: item.rate > 0 ? item.rate.toString() : '',
        discount: item.discountAmount > 0
            ? item.discountAmount.toString()
            : '0',
        warehouse: item.warehouse.isNotEmpty ? item.warehouse : null,
      );
      row.qtyController.addListener(_onPricingInputChanged);
      row.rateController.addListener(_calculateTotal);
      row.discountController.addListener(_calculateTotal);
      _additionalItems.add(row);
    }
    setState(() {
      _customerCtrl.text = order.customerId;
      _selectedCurrency = order.currency.isNotEmpty
          ? order.currency
          : _selectedCurrency;
      _selectedPriceList = order.sellingPriceList.isNotEmpty
          ? order.sellingPriceList
          : _selectedPriceList;
      _priceListCurrency = order.priceListCurrency.isNotEmpty
          ? order.priceListCurrency
          : _priceListCurrency;
      _discountCtrl.text = firstItem?.discountAmount.toString() ?? '0';
      _selectedDate = DateTime.tryParse(order.date) ?? _selectedDate;
      _selectedDeliveryDate = _selectedDate;
      if (firstItem != null) {
        _selectedItemCode = firstItem.itemCode.isNotEmpty
            ? firstItem.itemCode
            : firstItem.itemName;
        _qtyCtrl.text = firstItem.qty.toString();
        _rateCtrl.text = firstItem.rate > 0 ? firstItem.rate.toString() : '';
        if (firstItem.warehouse.isNotEmpty) {
          _selectedWarehouse = firstItem.warehouse;
        }
        _initialItemText = firstItem.itemCode.isNotEmpty
            ? '${firstItem.itemName} (${firstItem.itemCode})'
            : firstItem.itemName;
        _itemTextController?.text = _initialItemText!;
      }
      _customerError = null;
      _itemError = null;
    });
    _loadCustomerInsight();
    _calculateTotal();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final warehouseOptions = _warehouseOptions(appState);
    final costCenterOptions = _costCentersForWarehouse(warehouseOptions);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          widget.isEditMode ? 'Edit Sales Order' : 'New Sales Order',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectorLoadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sebagian data tidak dapat dibaca',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectorLoadError!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Coba lagi',
                        onPressed: _isLoadingSelectors ? null : _loadSelectors,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Document Info Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Document Info',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _seriesOptions.isNotEmpty
                          ? (_seriesOptions.contains(_selectedSeries)
                                ? _selectedSeries
                                : _seriesOptions.first)
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Series',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      items: _seriesOptions
                          .map(
                            (series) => DropdownMenuItem(
                              value: series,
                              child: Text(series),
                            ),
                          )
                          .toList(),
                      onChanged: _seriesOptions.isEmpty
                          ? null
                          : (v) => setState(() => _selectedSeries = v),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Series wajib dipilih'
                          : null,
                      hint: _isLoadingSelectors
                          ? const Text('Loading series...')
                          : const Text('Pilih series'),
                    ),
                    if (_seriesError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _seriesError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isLoadingSelectors
                                ? null
                                : _loadSelectors,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );

                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;

                                  if (_selectedDeliveryDate.isBefore(picked)) {
                                    _selectedDeliveryDate = picked;
                                  }
                                });
                                _scheduleRepriceAllItems();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: AppColors.slate,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _selectedDeliveryDate.isBefore(
                                      _selectedDate,
                                    )
                                    ? _selectedDate
                                    : _selectedDeliveryDate,
                                firstDate: _selectedDate,
                                lastDate: DateTime(2030),
                              );

                              if (picked != null) {
                                setState(() => _selectedDeliveryDate = picked);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.local_shipping_outlined,
                                        size: 14,
                                        color: AppColors.slate,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Delivery',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(_selectedDeliveryDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: costCenterOptions.isNotEmpty
                          ? (costCenterOptions.any(
                                  (center) => center.name == _selectedCenter,
                                )
                                ? _selectedCenter
                                : costCenterOptions.first.name)
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Cost Center',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: costCenterOptions
                          .map(
                            (center) => DropdownMenuItem(
                              value: center.name,
                              child: Text(center.name),
                            ),
                          )
                          .toList(),
                      onChanged: costCenterOptions.isEmpty
                          ? null
                          : (v) => setState(() => _selectedCenter = v),
                      hint: _isLoadingSelectors
                          ? const Text('Loading cost centers...')
                          : const Text('Pilih cost center'),
                    ),

                    const SizedBox(height: 12),

                    if (appState.userRole == 'Sales')
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Sales',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Text(
                          appState.currentSalesPerson ??
                              appState.salesIdentityError ??
                              '-',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue:
                            _salesPersonOptions.contains(_selectedSalesPerson)
                            ? _selectedSalesPerson
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Sales Person',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        items: _salesPersonOptions
                            .map(
                              (salesPerson) => DropdownMenuItem(
                                value: salesPerson,
                                child: Text(salesPerson),
                              ),
                            )
                            .toList(),
                        onChanged: _salesPersonOptions.isEmpty
                            ? null
                            : (value) =>
                                  setState(() => _selectedSalesPerson = value),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Sales Person wajib dipilih'
                            : null,
                        hint: _isLoadingSelectors
                            ? const Text('Loading sales persons...')
                            : const Text('Pilih sales person'),
                      ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _customerCtrl,
                      readOnly: true,
                      onTap: _showCustomerSelectSheet,
                      decoration: InputDecoration(
                        labelText: 'Nama Customer',
                        hintText: _isLoadingSelectors
                            ? 'Loading customer...'
                            : 'Pilih atau search customer',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon:
                            _customerError == null &&
                                _customerCtrl.text.isNotEmpty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.arrow_drop_down_rounded),
                        errorText: _customerError,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Customer wajib diisi'
                          : null,
                    ),
                    if (_isLoadingCustomerInsight) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ] else if (_customerInsight != null) ...[
                      const SizedBox(height: 10),
                      _CustomerInsightCard(
                        insight: _customerInsight!,
                        orderTotal: _totalAmount,
                        onHistory: _showCustomerHistory,
                      ),
                    ] else if (_customerInsightError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Informasi kredit customer gagal dimuat.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextButton.icon(
                              onPressed: _loadCustomerInsight,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry informasi customer'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cardShadow,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Currency & Price List',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            child: Text(
                              _selectedCurrency ?? '-',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Selling Price List',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            child: Text(
                              _selectedPriceList ?? '-',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_priceListCurrency != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Price List Currency: $_priceListCurrency',
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Warehouse',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (warehouseOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey('warehouse:${_selectedWarehouse ?? ''}'),
                        initialValue:
                            warehouseOptions.any(
                              (w) => w.name == _selectedWarehouse,
                            )
                            ? _selectedWarehouse
                            : '',
                        decoration: InputDecoration(
                          labelText: 'Pilih Warehouse',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('- None -'),
                          ),
                          ...warehouseOptions.map(
                            (w) => DropdownMenuItem<String>(
                              value: w.name,
                              child: Text(
                                w.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedWarehouse = v == '' ? null : v;
                            final nextCostCenters = _costCentersForWarehouse(
                              warehouseOptions,
                            );
                            _selectedCenter =
                                nextCostCenters.any(
                                  (center) => center.name == _selectedCenter,
                                )
                                ? _selectedCenter
                                : (nextCostCenters.isNotEmpty
                                      ? nextCostCenters.first.name
                                      : null);
                          });
                          _loadCustomerInsight();
                          _scheduleRepriceAllItems();
                        },
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          'Warehouse tidak tersedia. Refresh Stock tab terlebih dahulu.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Item Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<_ItemOption>(
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text.toLowerCase();
                        if (query.isEmpty) {
                          return _itemOptions.take(20);
                        }
                        return _itemOptions.where((option) {
                          final label = option.label.toLowerCase();
                          return label.contains(query) ||
                              option.code.toLowerCase().contains(query);
                        });
                      },
                      displayStringForOption: (option) => option.label,
                      onSelected: (option) {
                        setState(() {
                          _selectedItemCode = option.code;
                          _itemTextController?.text = option.label;
                          _itemError = null;
                        });
                        _loadItemInsight(option.code, applyPrice: true);
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onSubmit,
                          ) {
                            _itemTextController ??= textEditingController;
                            if (_initialItemText != null &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text = _initialItemText!;
                            }
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onChanged: (value) {
                                final code = _normalizeItemCode(value);
                                if (_selectedItemCode != null &&
                                    code != _selectedItemCode) {
                                  setState(() => _selectedItemCode = null);
                                }
                                if (value.contains('(') &&
                                    value.endsWith(')') &&
                                    code.isNotEmpty) {
                                  setState(() => _selectedItemCode = code);
                                }
                                _validateItem(value);
                              },
                              decoration: InputDecoration(
                                labelText: 'Nama Item / Kode',
                                hintText: 'Cari dengan nama atau kode',
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                suffixIcon: _isValidatingItem
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : _itemError == null &&
                                          (_itemTextController
                                                  ?.text
                                                  .isNotEmpty ??
                                              false)
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                errorText: _itemError,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Item wajib diisi';
                                }
                                return null;
                              },
                            );
                          },
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) {
                              final q = double.tryParse(v?.trim() ?? '');
                              if (q == null || q <= 0) return 'Qty > 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Harga/Unit',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final r = double.tryParse(v.trim());
                              if (r == null || r < 0) return 'Harga >= 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Discount Amount',
                        prefixIcon: const Icon(Icons.discount_outlined),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        final discount = double.tryParse(value?.trim() ?? '');
                        if (discount == null || discount < 0) {
                          return 'Diskon harus 0 atau lebih';
                        }
                        final rate =
                            double.tryParse(_rateCtrl.text.trim()) ?? 0;
                        if (rate > 0 && discount > rate) {
                          return 'Diskon tidak boleh melebihi harga';
                        }
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _selectedItemCode == null
                            ? null
                            : () => _showItemInsight(_selectedItemCode!),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Cek stok & harga'),
                      ),
                    ),
                    if (_selectedItemCode != null)
                      _ItemPricingLine(
                        insight: _itemInsights[_selectedItemCode],
                        isLoading: _loadingItemPrices.contains(
                          'first:$_selectedItemCode',
                        ),
                      ),
                    const SizedBox(height: 12),
                    ..._additionalItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Item ${index + 2}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Hapus item',
                                  onPressed: () => _removeItemRow(index),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            Autocomplete<_ItemOption>(
                              optionsBuilder: (textEditingValue) {
                                final query = textEditingValue.text
                                    .toLowerCase();
                                if (query.isEmpty) {
                                  return _itemOptions.take(20);
                                }
                                return _itemOptions.where((option) {
                                  final label = option.label.toLowerCase();
                                  return label.contains(query) ||
                                      option.code.toLowerCase().contains(query);
                                });
                              },
                              displayStringForOption: (option) => option.label,
                              onSelected: (option) {
                                setState(() {
                                  row.itemCode = option.code;
                                  row.itemTextController?.text = option.label;
                                });
                                _loadItemInsight(
                                  option.code,
                                  applyPrice: true,
                                  row: row,
                                );
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onSubmit,
                                  ) {
                                    row.itemTextController =
                                        textEditingController;
                                    if (row.itemCode != null &&
                                        textEditingController.text.isEmpty) {
                                      final currentOption = _itemOptions
                                          .firstWhere(
                                            (option) =>
                                                option.code == row.itemCode,
                                            orElse: () => _ItemOption(
                                              code: row.itemCode ?? '',
                                              name: row.itemCode ?? '',
                                            ),
                                          );
                                      textEditingController.text =
                                          currentOption.label;
                                    }
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      onChanged: (value) {
                                        final code = _normalizeItemCode(value);
                                        if (row.itemCode != null &&
                                            code != row.itemCode) {
                                          setState(() => row.itemCode = null);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Nama Item / Kode',
                                        hintText: 'Cari dengan nama atau kode',
                                        filled: true,
                                        fillColor: AppColors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (row.itemCode == null ||
                                            row.itemCode!.trim().isEmpty) {
                                          return 'Item wajib dipilih';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: row.qtyController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
                                    ),
                                    validator: (value) {
                                      final qty = double.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      return qty == null || qty <= 0
                                          ? 'Qty > 0'
                                          : null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: row.rateController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Harga/Unit',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return null;
                                      }
                                      final rate = double.tryParse(
                                        value.trim(),
                                      );
                                      return rate == null || rate < 0
                                          ? 'Harga >= 0'
                                          : null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: row.discountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Discount Amount',
                                prefixIcon: Icon(Icons.discount_outlined),
                              ),
                              validator: (value) {
                                final discount = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (discount == null || discount < 0) {
                                  return 'Diskon harus 0 atau lebih';
                                }
                                final rate =
                                    double.tryParse(
                                      row.rateController.text.trim(),
                                    ) ??
                                    0;
                                if (rate > 0 && discount > rate) {
                                  return 'Diskon tidak boleh melebihi harga';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: row.itemCode == null
                                    ? null
                                    : () => _showItemInsight(row.itemCode!),
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: const Text('Cek stok & harga'),
                              ),
                            ),
                            if (row.itemCode != null)
                              _ItemPricingLine(
                                insight: _itemInsights[row.itemCode],
                                isLoading: _loadingItemPrices.contains(
                                  'row:${row.hashCode}',
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: _addItemRow,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Item'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                          Text(
                            'Rp ${_totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _AttachmentCard(
                photos: _photos,
                onCamera: () => _pickPhoto(ImageSource.camera),
                onGallery: () => _pickPhoto(ImageSource.gallery),
                onRemove: (index) => setState(() => _photos.removeAt(index)),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed:
              (_isSaving ||
                  _isLoadingSelectors ||
                  _isValidatingItem ||
                  _selectedSeries == null)
              ? null
              : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.isEditMode ? 'Update Sales Order' : 'Save Sales Order',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
        ),
      ),
    );
  }
}

class _ItemOption {
  final String code;
  final String name;

  _ItemOption({required this.code, required this.name});

  String get label => '$name ($code)';
}

class _CustomerOption {
  final String id;
  final String name;
  final List<Map<String, dynamic>> salesTeam;

  const _CustomerOption({
    required this.id,
    required this.name,
    this.salesTeam = const [],
  });
}

class _CostCenterOption {
  final String name;
  final String company;

  const _CostCenterOption({required this.name, required this.company});
}

class _AdditionalItemRow {
  String? itemCode;
  String? warehouse;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController discountController;
  TextEditingController? itemTextController;

  _AdditionalItemRow({
    this.itemCode,
    String qty = '1',
    String rate = '',
    String discount = '0',
    this.warehouse,
  }) : qtyController = TextEditingController(text: qty),
       rateController = TextEditingController(text: rate),
       discountController = TextEditingController(text: discount);

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    discountController.dispose();
  }
}

class _CustomerInsightCard extends StatelessWidget {
  final CustomerSalesInsight insight;
  final double orderTotal;
  final VoidCallback onHistory;

  const _CustomerInsightCard({
    required this.insight,
    required this.orderTotal,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final overLimit =
        insight.creditLimit > 0 &&
        insight.projectedOutstanding(orderTotal) > insight.creditLimit;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overLimit
            ? Colors.red.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overLimit
              ? Colors.red.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informasi Kredit Customer',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InsightMetric(
                label: 'Credit Limit',
                value: insight.creditLimit > 0
                    ? 'Rp ${insight.creditLimit.toStringAsFixed(0)}'
                    : 'Tidak dibatasi',
              ),
              _InsightMetric(
                label: 'Outstanding',
                value: 'Rp ${insight.outstanding.toStringAsFixed(0)}',
                warning: overLimit,
              ),
              _InsightMetric(
                label: 'Sisa Kredit',
                value: insight.creditLimit > 0
                    ? 'Rp ${insight.availableCredit.toStringAsFixed(0)}'
                    : '-',
                warning: insight.availableCredit < 0,
              ),
              _InsightMetric(
                label: 'Total Order',
                value: 'Rp ${orderTotal.toStringAsFixed(0)}',
              ),
              _InsightMetric(
                label: 'Projected Piutang',
                value:
                    'Rp ${insight.projectedOutstanding(orderTotal).toStringAsFixed(0)}',
                warning: overLimit,
              ),
              _InsightMetric(
                label: 'Sisa Setelah Order',
                value: insight.creditLimit > 0
                    ? 'Rp ${insight.projectedAvailableCredit(orderTotal).toStringAsFixed(0)}'
                    : '-',
                warning: insight.projectedAvailableCredit(orderTotal) < 0,
              ),
              _InsightMetric(
                label: 'Price List',
                value: insight.priceList.isEmpty
                    ? 'Default'
                    : insight.priceList,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Lihat history pembelian'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPricingLine extends StatelessWidget {
  final ItemSalesInsight? insight;
  final bool isLoading;

  const _ItemPricingLine({required this.insight, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final value = insight;
    if (value == null) return const SizedBox.shrink();
    final detail = <String>[
      if (value.priceList.isNotEmpty) value.priceList,
      if (value.priceListRate > 0)
        'List ${value.currency} ${value.priceListRate.toStringAsFixed(0)}',
      if (value.discountPercentage > 0)
        'Diskon ${value.discountPercentage.toStringAsFixed(1)}%',
      if (value.pricingRule.isNotEmpty) 'Rule ${value.pricingRule}',
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        detail.isEmpty
            ? 'Harga manual / price list tidak ditemukan'
            : detail.join(' | '),
        style: const TextStyle(fontSize: 11, color: AppColors.slate),
      ),
    );
  }
}

class _CustomerHistorySheet extends StatefulWidget {
  final String customer;
  final String company;

  const _CustomerHistorySheet({required this.customer, required this.company});

  @override
  State<_CustomerHistorySheet> createState() => _CustomerHistorySheetState();
}

class _CustomerHistorySheetState extends State<_CustomerHistorySheet>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 20;
  late final TabController _tabController;
  final Map<String, List<CustomerPurchaseHistory>> _rows = {
    'Sales Order': [],
    'Sales Invoice': [],
  };
  final Map<String, bool> _loading = {
    'Sales Order': false,
    'Sales Invoice': false,
  };
  final Map<String, bool> _hasMore = {
    'Sales Order': true,
    'Sales Invoice': true,
  };
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMore('Sales Order');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMore(String doctype) async {
    if (_loading[doctype] == true || _hasMore[doctype] != true) return;
    setState(() {
      _loading[doctype] = true;
      _error = null;
    });
    try {
      final page = await context.read<AppState>().fetchCustomerPurchaseHistory(
        customer: widget.customer,
        doctype: doctype,
        company: widget.company,
        offset: _rows[doctype]!.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _rows[doctype]!.map((row) => row.id).toSet();
      setState(() {
        _rows[doctype]!.addAll(page.where((row) => known.add(row.id)));
        _hasMore[doctype] = page.isNotEmpty;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading[doctype] = false);
    }
  }

  Future<void> _showDetail(CustomerPurchaseHistory row) async {
    showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: context.read<AppState>().loadSalesHistoryDetail(
          row.doctype,
          row.id,
        ),
        builder: (context, snapshot) {
          final doc = snapshot.data;
          final items = doc?['items'];
          return AlertDialog(
            title: Text(row.id),
            content: snapshot.connectionState != ConnectionState.done
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : snapshot.hasError
                ? Text('Gagal memuat detail: ${snapshot.error}')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Text('${row.date} | ${row.status}'),
                        const SizedBox(height: 8),
                        if (items is List)
                          ...items.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item is Map
                                    ? item['item_name']?.toString() ??
                                          item['item_code']?.toString() ??
                                          'Item'
                                    : 'Item',
                              ),
                              trailing: Text(
                                item is Map
                                    ? 'x${item['qty']?.toString() ?? '0'}'
                                    : '',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(String doctype) {
    final rows = _rows[doctype]!;
    if (rows.isEmpty && _loading[doctype] == true) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        if (rows.isEmpty && _loading[doctype] != true)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Belum ada transaksi customer ini.'),
          ),
        ...rows.map(
          (row) => ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => _showDetail(row),
            title: Text(row.id),
            subtitle: Text(
              '${row.date} | ${row.status}'
              '${row.itemsCount > 0 ? ' | Qty ${row.itemsCount}' : ''}'
              '${row.outstanding > 0 ? ' | Outstanding Rp ${row.outstanding.toStringAsFixed(0)}' : ''}',
            ),
            trailing: Text(
              'Rp ${row.total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (_hasMore[doctype] == true)
          TextButton.icon(
            onPressed: _loading[doctype] == true
                ? null
                : () => _loadMore(doctype),
            icon: _loading[doctype] == true
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: const Text('Load more'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'History Pembelian Customer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            TabBar(
              controller: _tabController,
              onTap: (index) =>
                  _loadMore(index == 0 ? 'Sales Order' : 'Sales Invoice'),
              tabs: const [
                Tab(text: 'Sales Order'),
                Tab(text: 'Sales Invoice'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTab('Sales Order'),
                  _buildTab('Sales Invoice'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _InsightMetric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.slate),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: warning ? Colors.red : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  const _AttachmentCard({
    required this.photos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Attachment Sales Order',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Foto akan masuk ke panel Attachments setelah Draft Sales Order berhasil disimpan.',
              style: TextStyle(fontSize: 11, color: AppColors.slate),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          ...photos.asMap().entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: Text(
                entry.value.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                onPressed: () => onRemove(entry.key),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
