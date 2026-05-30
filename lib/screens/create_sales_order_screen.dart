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
  bool _isValidatingCustomer = false;
  bool _isValidatingItem = false;
  String? _customerError;
  String? _itemError;
  double _totalAmount = 0.0;

  List<String> _seriesOptions = [];
  List<String> _costCenterOptions = [];
  List<_ItemOption> _itemOptions = [];

  List<WarehouseInfo> _warehouseOptions(AppState appState) {
    final warehouses = appState.warehouses.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return warehouses;
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
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {
      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
      _totalAmount = qty * rate;
    });
  }

  Future<void> _validateCustomer(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _customerError = null);
      return;
    }

    setState(() => _isValidatingCustomer = true);
    try {
      final appState = context.read<AppState>();
      await appState.frappeService.fetchDocument('Customer', value.trim());
      setState(() => _customerError = null);
    } catch (e) {
      setState(() => _customerError = 'Customer tidak ditemukan');
    } finally {
      setState(() => _isValidatingCustomer = false);
    }
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
      setState(() => _itemError = null);
    } catch (e) {
      setState(() => _itemError = 'Item tidak ditemukan');
    } finally {
      setState(() => _isValidatingItem = false);
    }
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
      await appState.createSalesOrder(
        customer: _customerCtrl.text.trim(),
        itemCode: itemCode,
        qty: qty,
        warehouse: _selectedWarehouse,
        rate: rate,
        series: _selectedSeries,
        costCenter: _selectedCenter,
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
      final seriesData = await appState.frappeService.fetchResource(
        'Series',
        fields: const ['name', 'document_type'],
        filters: const [
          ['document_type', '=', 'Sales Order'],
        ],
        orderBy: 'name asc',
      );
      final costCenterData = await appState.frappeService.fetchResource(
        'Cost Center',
        fields: const ['name'],
        orderBy: 'name asc',
      );

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

      final seriesOptions = seriesData
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      final costCenters = costCenterData
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

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

      setState(() {
        _seriesOptions = seriesOptions.isNotEmpty
            ? seriesOptions
            : ['TMSX-E-SO-YY-#####'];
        _costCenterOptions = costCenters.isNotEmpty
            ? costCenters
            : ['Kemitraan'];
        _selectedSeries ??= _seriesOptions.first;
        _selectedCenter ??= _costCenterOptions.first;
        _itemOptions = itemOptions;
        _selectedWarehouse ??= warehouseOptions.isNotEmpty
            ? warehouseOptions.first.name
            : null;
      });
    } catch (_) {
      setState(() {
        _seriesOptions = ['TMSX-E-SO-YY-#####'];
        _costCenterOptions = ['Kemitraan'];
        _selectedSeries ??= _seriesOptions.first;
        _selectedCenter ??= _costCenterOptions.first;
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

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSeries ?? 'TMSX-E-SO-YY-#####',
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
                            items: _seriesOptions.isNotEmpty
                                ? _seriesOptions
                                      .map(
                                        (series) => DropdownMenuItem(
                                          value: series,
                                          child: Text(series),
                                        ),
                                      )
                                      .toList()
                                : [
                                    const DropdownMenuItem(
                                      value: 'TMSX-E-SO-YY-#####',
                                      child: Text('TMSX-E-SO-YY-#####'),
                                    ),
                                  ],
                            onChanged: _seriesOptions.isEmpty
                                ? null
                                : (v) => setState(() => _selectedSeries = v),
                            hint: _isLoadingSelectors
                                ? const Text('Loading series...')
                                : const Text('Pilih series'),
                          ),
                        ),
                      ],
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
                      value: _selectedCenter ?? 'Kemitraan',
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
                      items: _costCenterOptions.isNotEmpty
                          ? _costCenterOptions
                                .map(
                                  (center) => DropdownMenuItem(
                                    value: center,
                                    child: Text(center),
                                  ),
                                )
                                .toList()
                          : const [
                              DropdownMenuItem(
                                value: 'Kemitraan',
                                child: Text('Kemitraan'),
                              ),
                            ],
                      onChanged: _costCenterOptions.isEmpty
                          ? null
                          : (v) => setState(
                              () => _selectedCenter = v ?? 'Kemitraan',
                            ),
                      hint: _isLoadingSelectors
                          ? const Text('Loading cost centers...')
                          : const Text('Pilih cost center'),
                    ),

                    SizedBox(height: 12),

                    TextFormField(
                      controller: _customerCtrl,
                      onChanged: _validateCustomer,
                      decoration: InputDecoration(
                        labelText: 'Nama Customer',
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
                        suffixIcon: _isValidatingCustomer
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
                            : _customerError == null &&
                                  _customerCtrl.text.isNotEmpty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
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
                        value:
                            warehouseOptions.any(
                              (w) => w.name == _selectedWarehouse,
                            )
                            ? _selectedWarehouse
                            : null,
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— None —'),
                          ),
                          ...warehouseOptions.map(
                            (w) => DropdownMenuItem(
                              value: w.name,
                              child: Text(
                                w.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedWarehouse = v),
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
