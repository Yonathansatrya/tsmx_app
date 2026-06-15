import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/warehouse_info.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';

class CreatePurchaseReceiptScreen extends StatefulWidget {
  const CreatePurchaseReceiptScreen({super.key});

  @override
  State<CreatePurchaseReceiptScreen> createState() =>
      _CreatePurchaseReceiptScreenState();
}

class _CreatePurchaseReceiptScreenState
    extends State<CreatePurchaseReceiptScreen> {
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
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const String _doctype = 'Purchase Receipt';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<List<_Option>> _options(
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
          return id.isEmpty
              ? null
              : _Option(id, row[labelField]?.toString() ?? id);
        })
        .whereType<_Option>()
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      if (appState.warehouses.isEmpty) await appState.refreshWarehouses();
      final series = await appState.fetchNamingSeries(_doctype);
      final items = await _options(appState, 'Item', 'item_name');
      final suppliers = await _options(appState, 'Supplier', 'supplier_name');
      final warehouses =
          appState.warehouses
              .where(
                (w) => w.name.isNotEmpty && !w.isGroup && w.isDisabled != true,
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
        _items = items;
        _suppliers = suppliers;
        _warehouses = warehouses;
        _selectedSeries = series.isNotEmpty ? series.first : null;
        _selectedWarehouse =
            defaultWarehouse ??
            (warehouses.isNotEmpty ? warehouses.first.name : null);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  WarehouseInfo? get _warehouse {
    for (final warehouse in _warehouses) {
      if (warehouse.name == _selectedWarehouse) return warehouse;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final qty = double.parse(_qtyCtrl.text.trim());
      await appState.createPurchaseReceipt(
        supplier: _selectedSupplier!,
        itemCode: _selectedItem!,
        qty: qty,
        rate: double.tryParse(_rateCtrl.text.trim()),
        namingSeries: _selectedSeries!,
        warehouse: _selectedWarehouse!,
        postingDate: _date,
        company: _warehouse?.company,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_doctype draft berhasil dibuat'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat $_doctype: $error'),
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );

  DropdownButtonFormField<String> _dropdown(
    String label,
    String? value,
    List<_Option> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _decoration(label),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option.id,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (selected) => selected == null ? '$label wajib dipilih' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('New $_doctype')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      ListTile(
                        title: Text(_error!),
                        trailing: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSeries,
                      isExpanded: true,
                      decoration: _decoration('Series'),
                      items: _series
                          .map(
                            (series) => DropdownMenuItem(
                              value: series,
                              child: Text(
                                series,
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
                    _dropdown(
                      'Supplier',
                      _selectedSupplier,
                      _suppliers,
                      (value) => setState(() => _selectedSupplier = value),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      'Item',
                      _selectedItem,
                      _items,
                      (value) => setState(() => _selectedItem = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedWarehouse,
                      isExpanded: true,
                      decoration: _decoration('Warehouse'),
                      items: _warehouses
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
                      onChanged: (value) =>
                          setState(() => _selectedWarehouse = value),
                      validator: (value) =>
                          value == null ? 'Warehouse wajib dipilih' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _decoration('Posting Date'),
                        child: Text(DateFormat('dd-MM-yyyy').format(_date)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decoration('Quantity'),
                      validator: (value) {
                        final qty = double.tryParse(value?.trim() ?? '');
                        return qty == null || qty <= 0 ? 'Qty > 0' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decoration('Rate'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final rate = double.tryParse(value.trim());
                        return rate == null || rate < 0 ? 'Rate >= 0' : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saving || _loading || _error != null ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save $_doctype'),
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
