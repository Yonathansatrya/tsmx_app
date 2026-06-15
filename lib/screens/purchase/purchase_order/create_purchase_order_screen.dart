import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_order.dart';
import '../../../models/warehouse_info.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  final String? editOrderId;

  const CreatePurchaseOrderScreen({super.key, this.editOrderId});

  bool get isEditMode => editOrderId != null;

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();

  TextEditingController? _itemTextController;
  String? _initialItemText;
  String? _selectedItemCode;
  String? _selectedWarehouse;
  String? _selectedSeries;
  DateTime _selectedDate = DateTime.now();
  DateTime _requiredByDate = DateTime.now();

  bool _isLoadingSelectors = true;
  bool _isSaving = false;
  bool _isValidatingItem = false;
  String? _supplierError;
  String? _itemError;

  List<WarehouseInfo> _warehouseOptions = [];
  List<String> _seriesOptions = [];
  List<_SupplierOption> _supplierOptions = [];
  List<_ItemOption> _itemOptions = [];

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_calculateTotal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectors();
    });
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _itemTextController = null;
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {});
  }

  Future<List<_SupplierOption>> _fetchSupplierOptions(AppState appState) async {
    try {
      final supplierData = await appState.frappeService.fetchResource(
        'Supplier',
        fields: const ['name', 'supplier_name'],
        orderBy: 'supplier_name asc',
      );
      return supplierData
          .map((row) {
            final name = row['name']?.toString() ?? '';
            final label = row['supplier_name']?.toString() ?? name;
            if (name.isEmpty) return null;
            return _SupplierOption(id: name, label: label);
          })
          .whereType<_SupplierOption>()
          .toList();
    } catch (_) {
      try {
        final supplierData = await appState.frappeService.fetchResource(
          'Supplier',
          fields: const ['name'],
          orderBy: 'name asc',
        );
        return supplierData
            .map((row) {
              final name = row['name']?.toString() ?? '';
              if (name.isEmpty) return null;
              return _SupplierOption(id: name, label: name);
            })
            .whereType<_SupplierOption>()
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<_ItemOption>> _fetchItemOptions(AppState appState) async {
    try {
      final itemData = await appState.frappeService.fetchResource(
        'Item',
        fields: const ['name', 'item_name'],
        orderBy: 'item_name asc',
      );
      return itemData
          .map((row) {
            final code = row['name']?.toString() ?? '';
            final label = row['item_name']?.toString() ?? code;
            if (code.isEmpty) return null;
            return _ItemOption(code: code, label: label);
          })
          .whereType<_ItemOption>()
          .toList();
    } catch (_) {
      try {
        final itemData = await appState.frappeService.fetchResource(
          'Item',
          fields: const ['name'],
          orderBy: 'name asc',
        );
        return itemData
            .map((row) {
              final code = row['name']?.toString() ?? '';
              if (code.isEmpty) return null;
              return _ItemOption(code: code, label: code);
            })
            .whereType<_ItemOption>()
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> _loadSelectors() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoadingSelectors = true;
    });

    try {
      if (appState.warehouses.isEmpty) {
        await appState.refreshWarehouses();
      }
      final warehouses = appState.warehouses.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _warehouseOptions = warehouses
          .where((warehouse) => warehouse.name.trim().isNotEmpty)
          .toList();
      _selectedWarehouse = _warehouseOptions.isNotEmpty
          ? _warehouseOptions.first.name
          : null;

      final suppliers = await _fetchSupplierOptions(appState);
      final items = await _fetchItemOptions(appState);
      final series = await appState.fetchNamingSeries('Purchase Order');

      if (!mounted) return;
      setState(() {
        _supplierOptions = suppliers;
        _itemOptions = items;
        _seriesOptions = series;
        _selectedSeries = series.isNotEmpty ? series.first : null;
      });
      if (widget.isEditMode) {
        final editingOrder = await appState.loadPurchaseOrderDetail(
          widget.editOrderId!,
        );
        if (!mounted) return;
        _applyEditingOrder(editingOrder);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSelectors = false;
        });
      }
    }
  }

  void _applyEditingOrder(PurchaseOrder order) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    setState(() {
      _supplierCtrl.text = order.supplierId;
      _selectedDate = _parseDate(order.eta) ?? _selectedDate;
      _requiredByDate = _selectedDate;
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
      _supplierError = null;
      _itemError = null;
    });
  }

  DateTime? _parseDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final parts = trimmed.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _itemError = 'Item tidak ditemukan');
    } finally {
      if (mounted) {
        setState(() => _isValidatingItem = false);
      }
    }
  }

  List<_SupplierOption> _filteredSuppliers(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _supplierOptions.take(30).toList();
    return _supplierOptions.where((supplier) {
      return supplier.id.toLowerCase().contains(normalized) ||
          supplier.label.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<void> _showSupplierSelectSheet() async {
    final searchCtrl = TextEditingController();
    try {
      final result = await showModalBottomSheet<String>(
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
              final suppliers = _filteredSuppliers(query);
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
                          'Pilih Supplier',
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
                        labelText: 'Search nama supplier',
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
                    SizedBox(
                      height: MediaQuery.of(sheetContext).size.height * 0.42,
                      child: suppliers.isEmpty
                          ? const Center(
                              child: Text(
                                'Supplier tidak ditemukan',
                                style: TextStyle(color: AppColors.slate),
                              ),
                            )
                          : ListView.separated(
                              itemCount: suppliers.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final supplier = suppliers[index];
                                final selected =
                                    supplier.id == _supplierCtrl.text.trim();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    supplier.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: supplier.label == supplier.id
                                      ? null
                                      : Text(supplier.id),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext, supplier.id);
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

      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _supplierCtrl.text = result;
            _supplierError = null;
          });
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchCtrl.dispose();
      });
    }
  }

  String get _formattedTotal {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final total = qty * rate;
    return 'Rp ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => '.')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSeries == null) return;
    if (_supplierError != null || _itemError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan validasi supplier dan item terlebih dahulu'),
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

      if (widget.isEditMode) {
        await appState.updatePurchaseOrder(
          orderId: widget.editOrderId!,
          supplier: _supplierCtrl.text.trim(),
          itemCode: itemCode,
          qty: qty,
          warehouse: _selectedWarehouse,
          rate: rate,
          transactionDate: _selectedDate,
          requiredBy: _requiredByDate,
        );
      } else {
        await appState.createPurchaseOrder(
          supplier: _supplierCtrl.text.trim(),
          itemCode: itemCode,
          qty: qty,
          namingSeries: _selectedSeries!,
          warehouse: _selectedWarehouse,
          rate: rate,
          transactionDate: _selectedDate,
          requiredBy: _requiredByDate,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Purchase Order berhasil diperbarui'
                : 'Purchase Order berhasil dibuat',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Gagal memperbarui Purchase Order: $e'
                : 'Gagal membuat Purchase Order: $e',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          widget.isEditMode ? 'Edit Purchase Order' : 'New Purchase Order',
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
                      'Purchase Order Info',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _requiredByDate.isBefore(_selectedDate)
                              ? _selectedDate
                              : _requiredByDate,
                          firstDate: _selectedDate,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _requiredByDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Required By',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd-MM-yyyy').format(_requiredByDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSeries,
                      decoration: InputDecoration(
                        labelText: 'Series',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                      onChanged: widget.isEditMode
                          ? null
                          : (value) => setState(() => _selectedSeries = value),
                      validator: (value) => widget.isEditMode || value != null
                          ? null
                          : 'Series wajib dipilih',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _supplierCtrl,
                      readOnly: true,
                      onTap: _showSupplierSelectSheet,
                      decoration: InputDecoration(
                        labelText: 'Supplier',
                        hintText: _isLoadingSelectors
                            ? 'Loading supplier...'
                            : 'Pilih supplier atau ketik langsung',
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
                        suffixIcon: _supplierCtrl.text.isNotEmpty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.arrow_drop_down_rounded),
                        errorText: _supplierError,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Supplier wajib diisi'
                          : null,
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
                          setState(() {
                            _selectedDate = picked;
                            if (_requiredByDate.isBefore(picked)) {
                              _requiredByDate = picked;
                            }
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
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
                              'Tanggal PO',
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
                                if (_selectedItemCode != null) {
                                  setState(() => _selectedItemCode = null);
                                }
                                _validateItem(value);
                              },
                              decoration: InputDecoration(
                                labelText: 'Item Code / Nama',
                                hintText: 'Cari item dengan nama atau kode',
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
                              if (q == null || q <= 0) return 'Qty harus > 0';
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
                              labelText: 'Rate (optional)',
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
                              if (r == null || r < 0) return 'Rate harus >= 0';
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
                            'Total',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                          Text(
                            _formattedTotal,
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
                    if (_warehouseOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue:
                            _warehouseOptions.any(
                              (w) => w.name == _selectedWarehouse,
                            )
                            ? _selectedWarehouse
                            : _warehouseOptions.first.name,
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
                        items: _warehouseOptions
                            .map(
                              (warehouse) => DropdownMenuItem(
                                value: warehouse.name,
                                child: Text(
                                  warehouse.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _selectedWarehouse = value;
                        }),
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
              : Text(
                  widget.isEditMode
                      ? 'Update Purchase Order'
                      : 'Save Purchase Order',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
        ),
      ),
    );
  }
}

class _SupplierOption {
  final String id;
  final String label;

  const _SupplierOption({required this.id, required this.label});
}

class _ItemOption {
  final String code;
  final String label;

  _ItemOption({required this.code, required this.label});
}
