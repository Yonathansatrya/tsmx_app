import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../models/warehouse_info.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'warehouse_widgets.dart';

enum WarehouseOperation {
  transfer(
    title: 'Transfer Antar Gudang',
    stockEntryType: 'Material Transfer',
    icon: Icons.swap_horiz_rounded,
  ),
  receive(
    title: 'Goods Receive',
    stockEntryType: 'Material Receipt',
    icon: Icons.move_to_inbox_rounded,
  ),
  issue(
    title: 'Goods Issue',
    stockEntryType: 'Material Issue',
    icon: Icons.outbox_rounded,
  );

  final String title;
  final String stockEntryType;
  final IconData icon;

  const WarehouseOperation({
    required this.title,
    required this.stockEntryType,
    required this.icon,
  });
}

class WarehouseStockEntryScreen extends StatefulWidget {
  final WarehouseOperation operation;

  const WarehouseStockEntryScreen({super.key, required this.operation});

  @override
  State<WarehouseStockEntryScreen> createState() =>
      _WarehouseStockEntryScreenState();
}

class _WarehouseStockEntryScreenState extends State<WarehouseStockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rows = <_WarehouseOperationRow>[];
  List<WarehouseInfo> _warehouses = const [];
  List<InventoryItem> _items = const [];
  String? _sourceWarehouse;
  String? _targetWarehouse;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _needsSource => widget.operation != WarehouseOperation.receive;
  bool get _needsTarget => widget.operation != WarehouseOperation.issue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (state.warehouses.isEmpty) await state.refreshWarehouses();
      if (state.inventory.isEmpty) await state.refreshInventory();
      final warehouses =
          state.warehouses
              .where((row) => !row.isGroup && row.isDisabled != true)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final uniqueItems = <String, InventoryItem>{};
      for (final item in state.inventory) {
        uniqueItems.putIfAbsent(item.sku, () => item);
      }
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _items = uniqueItems.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _sourceWarehouse = _sourceWarehouse ?? _firstWarehouse(warehouses);
        _targetWarehouse =
            _targetWarehouse ??
            _firstWarehouse(warehouses, except: _sourceWarehouse);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _firstWarehouse(List<WarehouseInfo> rows, {String? except}) {
    for (final row in rows) {
      if (row.name != except) return row.name;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rows.isEmpty) {
      setState(() => _error = 'Tambahkan minimal satu item.');
      return;
    }
    if (_needsSource && _needsTarget && _sourceWarehouse == _targetWarehouse) {
      setState(() => _error = 'Gudang asal dan tujuan harus berbeda.');
      return;
    }
    if (widget.operation == WarehouseOperation.transfer &&
        _warehouseCompany(_sourceWarehouse) !=
            _warehouseCompany(_targetWarehouse)) {
      setState(
        () => _error =
            'Transfer antar gudang hanya dapat dilakukan dalam company yang sama.',
      );
      return;
    }
    final stockError = _validateSourceStock();
    if (stockError != null) {
      setState(() => _error = stockError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = [
        for (final row in _rows)
          {
            'item_code': row.item.sku,
            'qty': row.qty,
            if (_needsSource) 's_warehouse': _sourceWarehouse,
            if (_needsTarget) 't_warehouse': _targetWarehouse,
          },
      ];
      await context.read<AppState>().createStockEntry(
        stockEntryType: widget.operation.stockEntryType,
        items: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.operation.title} berhasil dibuat sebagai draft.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateSourceStock() {
    if (!_needsSource || _sourceWarehouse == null) return null;
    for (final row in _rows) {
      final available = context
          .read<AppState>()
          .inventory
          .where(
            (item) =>
                item.sku == row.item.sku &&
                item.warehouseId == _sourceWarehouse,
          )
          .fold<int>(0, (sum, item) => sum + item.quantity);
      if (row.qty > available) {
        return '${row.item.name} hanya tersedia $available di gudang asal.';
      }
    }
    return null;
  }

  String _warehouseCompany(String? warehouse) {
    for (final row in _warehouses) {
      if (row.name == warehouse) return row.company;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.operation.title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: warehousePagePadding,
              children: [
                _instructionPanel(),
                const SizedBox(height: 14),
                if (_needsSource)
                  _warehouseField(
                    label: 'Gudang asal',
                    value: _sourceWarehouse,
                    onChanged: (value) => setState(() {
                      _sourceWarehouse = value;
                      if (_targetWarehouse == value) {
                        _targetWarehouse = _firstWarehouse(
                          _warehouses,
                          except: value,
                        );
                      }
                    }),
                  ),
                if (_needsSource && _needsTarget) const SizedBox(height: 12),
                if (_needsTarget)
                  _warehouseField(
                    label: 'Gudang tujuan',
                    value: _targetWarehouse,
                    onChanged: (value) =>
                        setState(() => _targetWarehouse = value),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Daftar Item',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _showItemPicker,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_rows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Belum ada item. Tekan Tambah untuk memilih item.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate),
                      ),
                    ),
                  )
                else
                  ..._rows.indexed.map(
                    (entry) => _itemCard(entry.$1, entry.$2),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _saving ? 'Menyimpan...' : 'Simpan Draft Stock Entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _instructionPanel() => WarehouseInfoPanel(
    icon: widget.operation.icon,
    message: switch (widget.operation) {
      WarehouseOperation.transfer =>
        'Pindahkan beberapa item dari satu gudang ke gudang lain.',
      WarehouseOperation.receive => 'Catat barang yang masuk ke gudang tujuan.',
      WarehouseOperation.issue => 'Catat barang yang keluar dari gudang asal.',
    },
  );

  Widget _warehouseField({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = _warehouseByName(value);
    return FormField<String>(
      initialValue: value,
      validator: (_) => value == null ? '$label wajib dipilih' : null,
      builder: (field) => InkWell(
        onTap: () async {
          final next = await _showWarehousePicker(label, value);
          if (next == null) return;
          onChanged(next.name);
          field.didChange(next.name);
        },
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.warehouse_outlined),
            suffixIcon: const Icon(Icons.search_rounded),
            errorText: field.errorText,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected?.name ?? 'Pilih atau cari gudang',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected == null ? AppColors.slate : AppColors.navy,
                  fontWeight: selected == null
                      ? FontWeight.w500
                      : FontWeight.w800,
                ),
              ),
              if (selected != null && _warehouseSubtitle(selected).isNotEmpty)
                Text(
                  _warehouseSubtitle(selected),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.slate, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  WarehouseInfo? _warehouseByName(String? name) {
    for (final row in _warehouses) {
      if (row.name == name) return row;
    }
    return null;
  }

  String _warehouseSubtitle(WarehouseInfo row) => [
    if (row.company.isNotEmpty) row.company,
    if (row.parentWarehouse?.isNotEmpty == true) row.parentWarehouse!,
  ].join(' | ');

  Future<WarehouseInfo?> _showWarehousePicker(
    String title,
    String? selectedName,
  ) {
    return showModalBottomSheet<WarehouseInfo>(
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
            final normalized = query.trim().toLowerCase();
            final filtered = normalized.isEmpty
                ? _warehouses
                : _warehouses.where((row) {
                    return row.name.toLowerCase().contains(normalized) ||
                        row.displayName.toLowerCase().contains(normalized) ||
                        row.company.toLowerCase().contains(normalized) ||
                        (row.parentWarehouse ?? '').toLowerCase().contains(
                          normalized,
                        );
                  }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: const InputDecoration(
                        labelText: 'Cari nama, lokasi, atau company',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(sheetContext).size.height * 0.5,
                      child: filtered.isEmpty
                          ? const Center(child: Text('Gudang tidak ditemukan'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = filtered[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.softGreen,
                                    foregroundColor: AppColors.primary,
                                    child: Icon(Icons.warehouse_outlined),
                                  ),
                                  title: Text(
                                    row.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Text(_warehouseSubtitle(row)),
                                  trailing: row.name == selectedName
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.success,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(sheetContext, row),
                                );
                              },
                            ),
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

  Widget _itemCard(int index, _WarehouseOperationRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          child: Text('${index + 1}'),
        ),
        title: Text(
          row.item.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${row.item.sku} | Qty ${row.qty}'),
        trailing: IconButton(
          tooltip: 'Hapus item',
          onPressed: () => setState(() => _rows.removeAt(index)),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        onTap: () => _askQuantity(row.item, existingIndex: index),
      ),
    ),
  );

  Future<void> _showItemPicker() async {
    final selected = await showModalBottomSheet<InventoryItem>(
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
            final normalized = query.trim().toLowerCase();
            final filtered = normalized.isEmpty
                ? _items.take(40).toList()
                : _items.where((item) {
                    return item.sku.toLowerCase().contains(normalized) ||
                        item.name.toLowerCase().contains(normalized);
                  }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: const InputDecoration(
                        labelText: 'Cari item atau kode',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(sheetContext).size.height * 0.5,
                      child: filtered.isEmpty
                          ? const Center(child: Text('Item tidak ditemukan'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(item.sku),
                                  onTap: () =>
                                      Navigator.pop(sheetContext, item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null) await _askQuantity(selected);
  }

  Future<void> _askQuantity(InventoryItem item, {int? existingIndex}) async {
    final controller = TextEditingController(
      text: existingIndex == null ? '1' : '${_rows[existingIndex].qty}',
    );
    final qty = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty == null || !mounted) return;
    setState(() {
      final duplicate = _rows.indexWhere((row) => row.item.sku == item.sku);
      if (existingIndex != null) {
        _rows[existingIndex] = _WarehouseOperationRow(item: item, qty: qty);
      } else if (duplicate >= 0) {
        _rows[duplicate] = _WarehouseOperationRow(item: item, qty: qty);
      } else {
        _rows.add(_WarehouseOperationRow(item: item, qty: qty));
      }
    });
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _WarehouseOperationRow {
  final InventoryItem item;
  final double qty;

  const _WarehouseOperationRow({required this.item, required this.qty});
}
