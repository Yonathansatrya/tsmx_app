import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/inventory_item.dart';
import '../../../models/warehouse_info.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';

class CreateMaterialRequestScreen extends StatefulWidget {
  final InventoryItem? initialItem;

  const CreateMaterialRequestScreen({super.key, this.initialItem});

  @override
  State<CreateMaterialRequestScreen> createState() =>
      _CreateMaterialRequestScreenState();
}

class _CreateMaterialRequestScreenState
    extends State<CreateMaterialRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');

  List<_Option> _items = [];
  List<String> _companies = [];
  List<WarehouseInfo> _warehouses = [];
  String _requestType = 'Purchase';
  String? _selectedItem;
  String? _selectedCompany;
  String? _selectedWarehouse;
  DateTime _transactionDate = DateTime.now();
  DateTime _scheduleDate = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem?.sku;
    _selectedWarehouse = widget.initialItem?.warehouseId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      if (appState.warehouses.isEmpty) await appState.refreshWarehouses();
      if (appState.buyingCompanies.isEmpty) {
        await appState.loadBuyingFilterOptions();
      }
      final items = await _options(appState, 'Item', 'item_name');
      final companies = appState.buyingCompanies.isNotEmpty
          ? appState.buyingCompanies
          : await _names(appState, 'Company');
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

      if (!mounted) return;
      setState(() {
        _items = items;
        _companies = companies;
        _warehouses = warehouses;
        _selectedItem ??= items.isNotEmpty ? items.first.id : null;
        _selectedCompany ??= companies.isNotEmpty ? companies.first : null;
        _selectedWarehouse ??= warehouses.isNotEmpty
            ? warehouses.first.name
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          if (id.isEmpty) return null;
          final label = row[labelField]?.toString() ?? id;
          return _Option(id, label);
        })
        .whereType<_Option>()
        .toList();
  }

  Future<List<String>> _names(AppState appState, String doctype) async {
    final rows = await appState.frappeService.fetchResource(
      doctype,
      fields: const ['name'],
      orderBy: 'name asc',
    );
    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  Future<void> _pickDate({required bool schedule}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule ? _scheduleDate : _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (schedule) {
        _scheduleDate = picked;
      } else {
        _transactionDate = picked;
        if (_scheduleDate.isBefore(picked)) _scheduleDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().createMaterialRequest(
        materialRequestType: _requestType,
        itemCode: _selectedItem!,
        qty: double.parse(_qtyCtrl.text.trim()),
        transactionDate: _transactionDate,
        scheduleDate: _scheduleDate,
        company: _selectedCompany,
        warehouse: _selectedWarehouse,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material Request draft berhasil dibuat'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat Material Request: $error'),
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Material Request')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  _InfoCard(initialItem: widget.initialItem),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _requestType,
                    decoration: _decoration('Tipe Request'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Purchase',
                        child: Text('Purchase'),
                      ),
                      DropdownMenuItem(
                        value: 'Material Transfer',
                        child: Text('Material Transfer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _requestType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCompany,
                    isExpanded: true,
                    decoration: _decoration('Company'),
                    items: _companies
                        .map(
                          (company) => DropdownMenuItem(
                            value: company,
                            child: Text(
                              company,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCompany = value),
                    validator: (value) =>
                        value == null ? 'Company wajib dipilih' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: _decoration('Item'),
                    items: _items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedItem = value),
                    validator: (value) =>
                        value == null ? 'Item wajib dipilih' : null,
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
                      if (qty == null || qty <= 0) {
                        return 'Qty harus lebih dari 0';
                      }
                      return null;
                    },
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
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTile(
                          label: 'Tanggal',
                          value: _transactionDate,
                          onTap: () => _pickDate(schedule: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTile(
                          label: 'Dibutuhkan',
                          value: _scheduleDate,
                          onTap: () => _pickDate(schedule: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _saving || _loading ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan Draft'),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final InventoryItem? initialItem;

  const _InfoCard({required this.initialItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.assignment_add),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              initialItem == null
                  ? 'Buat request barang untuk kebutuhan departemen.'
                  : 'Prefill dari low stock: ${initialItem!.name}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(value)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
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
