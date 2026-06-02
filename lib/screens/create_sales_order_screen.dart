import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/warehouse_info.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  const CreateSalesOrderScreen({super.key});

  @override
  State<CreateSalesOrderScreen> createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();

  TextEditingController? _itemTextController;
  String? _selectedItemCode;
  String? _selectedSeries;
  String? _selectedWarehouse;
  String? _selectedCenter;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingSelectors = true;
  bool _isSaving = false;
  bool _isValidatingItem = false;
  String? _customerError;
  String? _itemError;
  double _totalAmount = 0.0;

  List<String> _seriesOptions = [];
  List<String> _customerSeriesOptions = [];
  List<String> _customerTypeOptions = [];
  List<String> _customerGroupOptions = [];
  List<String> _territoryOptions = [];
  List<String> _paymentTermsOptions = [];
  List<_CostCenterOption> _costCenterOptions = [];
  List<_CustomerOption> _customerOptions = [];
  List<_ItemOption> _itemOptions = [];

  List<WarehouseInfo> _warehouseOptions(AppState appState) {
    final warehouses = appState.warehouses.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final seen = <String>{};
    return warehouses.where((warehouse) {
      final name = warehouse.name.trim();
      if (name.isEmpty || seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();
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
    try {
      final docType = await appState.frappeService.fetchDocument(
        'DocType',
        'Sales Order',
      );
      final fields = docType['fields'];
      if (fields is List) {
        for (final row in fields) {
          if (row is! Map) continue;
          if (row['fieldname']?.toString() != 'naming_series') continue;

          final options = _splitFrappeOptions(row['options']);
          final defaultValue = row['default']?.toString().trim() ?? '';
          if (defaultValue.isNotEmpty && options.contains(defaultValue)) {
            return [
              defaultValue,
              ...options.where((option) => option != defaultValue),
            ];
          }
          return options;
        }
      }
    } catch (_) {}

    try {
      final message = await appState.frappeService.callMethod(
        'frappe.model.naming.get_options',
        args: {'doctype': 'Sales Order'},
      );
      return _splitFrappeOptions(message);
    } catch (_) {
      return [];
    }
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
    try {
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
    } catch (_) {
      return [];
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
    _qtyCtrl.addListener(_calculateTotal);
    _rateCtrl.addListener(_calculateTotal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectors();
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _itemTextController = null;
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {
      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
      _totalAmount = qty * rate;
    });
  }

  Future<void> _validateItem(String value) async {
    final candidate = _selectedItemCode ?? value.trim();
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

  Future<void> _showCustomerSelectSheet() async {
    final searchCtrl = TextEditingController();
    String? selectedCustomerId;
    var shouldAddCustomer = false;

    try {
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
                      controller: searchCtrl,
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
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext, true);
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add Customer Baru'),
                    ),
                    const SizedBox(height: 10),
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
    } finally {
      searchCtrl.dispose();
    }

    if (selectedCustomerId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _customerCtrl.text = selectedCustomerId!;
          _customerError = null;
        });
      });
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
    nameCtrl.dispose();
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
    if (_customerError != null || _itemError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan validasi customer dan item terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final appState = context.read<AppState>();
      final qty = double.parse(_qtyCtrl.text.trim());
      final rate = double.tryParse(_rateCtrl.text.trim());
      final itemCode =
          _selectedItemCode ?? _itemTextController?.text.trim() ?? '';
      if (itemCode.isEmpty) {
        throw Exception('Item code tidak boleh kosong');
      }
      final selectedWarehouseInfo = _selectedWarehouseInfo(
        _warehouseOptions(appState),
      );
      await appState.createSalesOrder(
        customer: _customerCtrl.text.trim(),
        itemCode: itemCode,
        qty: qty,
        warehouse: _selectedWarehouse,
        rate: rate,
        series: _selectedSeries,
        costCenter: _selectedCenter,
        company: selectedWarehouseInfo?.company,
        transactionDate: _selectedDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales Order berhasil dibuat'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat Sales Order: $e'),
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
    });

    try {
      final seriesOptions = await _fetchSalesOrderSeriesOptions(appState);
      final costCenters = await _fetchCostCenterOptions(appState);
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
      final customerGroupOptions = await _fetchLinkOptions(
        appState,
        doctype: 'Customer Group',
        filters: const [
          ['is_group', '=', 0],
        ],
      );
      final territoryOptions = await _fetchLinkOptions(
        appState,
        doctype: 'Territory',
        filters: const [
          ['is_group', '=', 0],
        ],
      );
      final paymentTermsOptions = await _fetchLinkOptions(
        appState,
        doctype: 'Payment Terms Template',
      );

      List<Map<String, dynamic>> customerData;
      try {
        customerData = await appState.frappeService.fetchResource(
          'Customer',
          fields: const ['name', 'customer_name'],
          orderBy: 'customer_name asc',
        );
      } catch (_) {
        customerData = await appState.frappeService.fetchResource(
          'Customer',
          fields: const ['name'],
          orderBy: 'name asc',
        );
      }

      final customerOptions = customerData
          .map((row) {
            final id = row['name']?.toString() ?? '';
            final name = row['customer_name']?.toString() ?? id;
            if (id.isEmpty) return null;
            return _CustomerOption(id: id, name: name);
          })
          .whereType<_CustomerOption>()
          .toList();

      List<Map<String, dynamic>> itemData;
      try {
        itemData = await appState.frappeService.fetchResource(
          'Item',
          fields: const ['name', 'item_name'],
          orderBy: 'item_name asc',
        );
      } catch (_) {
        itemData = await appState.frappeService.fetchResource(
          'Item',
          fields: const ['name'],
          orderBy: 'name asc',
        );
      }

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
        await appState.refreshWarehouses();
      }
      final warehouseOptions = _warehouseOptions(appState);
      final selectedWarehouseValid = warehouseOptions.any(
        (warehouse) => warehouse.name == _selectedWarehouse,
      );
      final selectedWarehouse = selectedWarehouseValid
          ? _selectedWarehouse
          : (warehouseOptions.isNotEmpty ? warehouseOptions.first.name : null);
      String selectedWarehouseCompany = '';
      for (final warehouse in warehouseOptions) {
        if (warehouse.name == selectedWarehouse) {
          selectedWarehouseCompany = warehouse.company;
          break;
        }
      }
      final availableCostCenters = selectedWarehouseCompany.isEmpty
          ? costCenters
          : costCenters
                .where((center) => center.company == selectedWarehouseCompany)
                .toList();
      final costCenterChoices = availableCostCenters.isNotEmpty
          ? availableCostCenters
          : costCenters;

      if (!mounted) return;
      setState(() {
        _seriesOptions = _normalizeOptions(seriesOptions);
        _customerSeriesOptions = _normalizeOptions(customerSeriesOptions);
        _customerTypeOptions = _normalizeOptions(customerTypeOptions);
        _customerGroupOptions = _normalizeOptions(customerGroupOptions);
        _territoryOptions = _normalizeOptions(territoryOptions);
        _paymentTermsOptions = _normalizeOptions(paymentTermsOptions);
        _costCenterOptions = _normalizeCostCenterOptions(costCenters);
        _customerOptions = customerOptions;
        _selectedSeries = _seriesOptions.contains(_selectedSeries)
            ? _selectedSeries
            : (_seriesOptions.isNotEmpty ? _seriesOptions.first : null);
        _selectedCenter =
            costCenterChoices.any((center) => center.name == _selectedCenter)
            ? _selectedCenter
            : (costCenterChoices.isNotEmpty
                  ? costCenterChoices.first.name
                  : null);
        _itemOptions = itemOptions;
        _selectedWarehouse = selectedWarehouse;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seriesOptions = [];
        _customerSeriesOptions = [];
        _customerTypeOptions = [];
        _customerGroupOptions = [];
        _territoryOptions = [];
        _paymentTermsOptions = [];
        _costCenterOptions = [];
        _customerOptions = [];
        _selectedSeries = null;
        _selectedCenter = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSelectors = false;
        });
      }
    }
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
        shadowColor: Colors.black.withOpacity(0.08),
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'New Sales Order',
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
              // Document Info Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                            color: AppColors.primary.withOpacity(0.2),
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
                      hint: _isLoadingSelectors
                          ? const Text('Loading series...')
                          : const Text('Pilih series'),
                    ),

                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd-MM-yyyy').format(_selectedDate),
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
                            color: AppColors.primary.withOpacity(0.2),
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
                            color: AppColors.primary.withOpacity(0.2),
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
                      color: Colors.black.withOpacity(0.05),
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
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onSubmit,
                          ) {
                            _itemTextController ??= textEditingController;
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onChanged: (value) {
                                if (_selectedItemCode != null) {
                                  setState(() => _selectedItemCode = null);
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
                                    color: AppColors.primary.withOpacity(0.2),
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
                                  color: AppColors.primary.withOpacity(0.2),
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
                                  color: AppColors.primary.withOpacity(0.2),
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
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
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

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                              color: AppColors.primary.withOpacity(0.2),
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
                            child: Text('— None —'),
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
                        onChanged: (v) => setState(() {
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
                        }),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          'Warehouse tidak tersedia — refresh Stock tab terlebih dahulu',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
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
              : const Text(
                  'Save Sales Order',
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

  const _CustomerOption({required this.id, required this.name});
}

class _CostCenterOption {
  final String name;
  final String company;

  const _CostCenterOption({required this.name, required this.company});
}
