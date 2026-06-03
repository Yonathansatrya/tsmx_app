import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../state/app_state.dart';
import '../models/warehouse_info.dart';

class CreateStockEntryScreen extends StatefulWidget {
  const CreateStockEntryScreen({super.key});

  @override
  State<CreateStockEntryScreen> createState() => _CreateStockEntryScreenState();
}

class _CreateStockEntryScreenState extends State<CreateStockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final DateTime _postingDate = DateTime.now();

  List<WarehouseInfo> _warehouses = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    if (appState.warehouses.isEmpty) await appState.refreshWarehouses();
    setState(() {
      _warehouses = appState.warehouses.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final qty = double.parse(_qtyCtrl.text.trim());
      final itemCode = _itemCtrl.text.trim();
      final warehouse = _warehouses.isNotEmpty ? _warehouses.first.name : null;

      final items = [
        {'item_code': itemCode, 'warehouse': warehouse, 'qty': qty},
      ];

      await appState.createStockEntry(
        stockEntryType: 'Stock Reconciliation',
        items: items,
        postingDate: _postingDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock Entry dibuat'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat Stock Entry: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        title: const Text(
          'Create Stock Entry',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _itemCtrl,
                      decoration: const InputDecoration(labelText: 'Item Code'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Item wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: (v) {
                        final q = double.tryParse(v?.trim() ?? '');
                        if (q == null || q <= 0) return 'Qty harus > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Warehouse'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _warehouses.isNotEmpty
                              ? _warehouses.first.name
                              : null,
                          items: _warehouses
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.name,
                                  child: Text(w.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Create Stock Entry',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
