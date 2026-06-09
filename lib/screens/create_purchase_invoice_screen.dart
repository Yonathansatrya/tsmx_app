import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/warehouse_info.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

class CreatePurchaseInvoiceScreen extends StatefulWidget {
  const CreatePurchaseInvoiceScreen({super.key});

  @override
  State<CreatePurchaseInvoiceScreen> createState() =>
      _CreatePurchaseInvoiceScreenState();
}

class _CreatePurchaseInvoiceScreenState
    extends State<CreatePurchaseInvoiceScreen> {
  static const _defaultWarehouse = 'Stores - Jakarta';
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();

  List<String> _series = [];
  List<_Option> _suppliers = [];
  List<_Option> _items = [];
  List<WarehouseInfo> _warehouses = [];
  String? _selectedSeries;
  String? _selectedSupplier;
  String? _selectedItem;
  String? _selectedWarehouse;
  DateTime _postingDate = DateTime.now();
  DateTime _dueDate = DateTime.now();
  bool _updateStock = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<List<_Option>> _fetchOptions(
    AppState appState,
    String doctype,
    String labelField,
  ) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await appState.frappeService.fetchResource(
        doctype,
        fields: ['name', labelField],
        orderBy: '$labelField asc',
      );
    } catch (_) {
      rows = await appState.frappeService.fetchResource(
        doctype,
        fields: const ['name'],
        orderBy: 'name asc',
      );
    }
    return rows
        .map((row) {
          final id = row['name']?.toString() ?? '';
          if (id.isEmpty) return null;
          return _Option(id, row[labelField]?.toString() ?? id);
        })
        .whereType<_Option>()
        .toList();
  }

  Future<void> _loadOptions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final appState = context.read<AppState>();
      if (appState.warehouses.isEmpty) await appState.refreshWarehouses();
      final series = await appState.fetchNamingSeries('Purchase Invoice');
      final suppliers = await _fetchOptions(
        appState,
        'Supplier',
        'supplier_name',
      );
      final items = await _fetchOptions(appState, 'Item', 'item_name');
      final warehouses =
          appState.warehouses
              .where(
                (warehouse) =>
                    warehouse.name.isNotEmpty &&
                    !warehouse.isGroup &&
                    warehouse.isDisabled != true,
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      String? defaultWarehouse;
      for (final warehouse in warehouses) {
        if (warehouse.name.toLowerCase() == _defaultWarehouse.toLowerCase()) {
          defaultWarehouse = warehouse.name;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _series = series;
        _suppliers = suppliers;
        _items = items;
        _warehouses = warehouses;
        _selectedSeries = series.isNotEmpty ? series.first : null;
        _selectedWarehouse =
            defaultWarehouse ??
            (warehouses.isNotEmpty ? warehouses.first.name : null);
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  WarehouseInfo? get _warehouseInfo {
    for (final warehouse in _warehouses) {
      if (warehouse.name == _selectedWarehouse) return warehouse;
    }
    return null;
  }

  Future<void> _pickDate({required bool dueDate}) async {
    final initial = dueDate ? _dueDate : _postingDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: dueDate ? _postingDate : DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (dueDate) {
        _dueDate = picked;
      } else {
        _postingDate = picked;
        if (_dueDate.isBefore(picked)) _dueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate.isBefore(_postingDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due Date tidak boleh sebelum Date')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().createPurchaseInvoice(
        supplier: _selectedSupplier!,
        itemCode: _selectedItem!,
        qty: double.parse(_qtyCtrl.text.trim()),
        rate: double.tryParse(_rateCtrl.text.trim()),
        namingSeries: _selectedSeries!,
        postingDate: _postingDate,
        dueDate: _dueDate,
        updateStock: _updateStock,
        warehouse: _updateStock ? _selectedWarehouse : null,
        company: _warehouseInfo?.company,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase Invoice draft berhasil dibuat'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat Purchase Invoice: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(label),
        child: Text(
          DateFormat('dd-MM-yyyy').format(value),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'New Purchase Invoice',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadError != null) ...[
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        title: Text(_loadError!),
                        trailing: IconButton(
                          onPressed: _loadOptions,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          'Purchase Invoice Info',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSeries,
                          decoration: _decoration('Series'),
                          isExpanded: true,
                          items: _series
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSeries = value),
                          validator: (value) =>
                              value == null ? 'Series wajib dipilih' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSupplier,
                          decoration: _decoration('Supplier'),
                          isExpanded: true,
                          items: _suppliers
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.id,
                                  child: Text(
                                    option.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSupplier = value),
                          validator: (value) =>
                              value == null ? 'Supplier wajib dipilih' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dateField(
                                'Date',
                                _postingDate,
                                () => _pickDate(dueDate: false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _dateField(
                                'Due Date',
                                _dueDate,
                                () => _pickDate(dueDate: true),
                              ),
                            ),
                          ],
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedItem,
                          decoration: _decoration('Item'),
                          isExpanded: true,
                          items: _items
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.id,
                                  child: Text(
                                    option.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedItem = value),
                          validator: (value) =>
                              value == null ? 'Item wajib dipilih' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _decoration('Accepted Qty'),
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
                                controller: _rateCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _decoration('Rate'),
                                validator: (value) {
                                  final rate = double.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  return rate == null || rate < 0
                                      ? 'Rate >= 0'
                                      : null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Update Stock'),
                          subtitle: const Text(
                            'Saat aktif, warehouse wajib dipilih',
                          ),
                          value: _updateStock,
                          onChanged: (value) =>
                              setState(() => _updateStock = value),
                        ),
                        if (_updateStock) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedWarehouse,
                            decoration: _decoration('Warehouse'),
                            isExpanded: true,
                            items: _warehouses
                                .map(
                                  (warehouse) => DropdownMenuItem(
                                    value: warehouse.name,
                                    child: Text(
                                      warehouse.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedWarehouse = value),
                            validator: (value) => _updateStock && value == null
                                ? 'Warehouse wajib dipilih'
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saving || _loading || _loadError != null ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Save Purchase Invoice',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
        ),
      ),
    );
  }
}

class _Option {
  final String id;
  final String label;

  const _Option(this.id, this.label);
}
