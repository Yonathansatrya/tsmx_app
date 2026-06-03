import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/barcode_stock_lookup.dart';
import '../models/inventory_item.dart';
import '../models/warehouse_info.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'item_stock_detail_screen.dart';

class BarcodeWarehouseScreen extends StatefulWidget {
  const BarcodeWarehouseScreen({super.key});

  @override
  State<BarcodeWarehouseScreen> createState() => _BarcodeWarehouseScreenState();
}

class _BarcodeWarehouseScreenState extends State<BarcodeWarehouseScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualCtrl = TextEditingController();
  String? _selectedWarehouse;
  String? _lastScanned;
  bool _isLookingUp = false;
  bool _scannerEnabled = true;
  String? _error;
  List<BarcodeStockLookup> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (appState.warehouses.isEmpty) {
        appState.refreshWarehouses();
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  List<WarehouseInfo> _warehouses(AppState appState) {
    final seen = <String>{};
    final warehouses = appState.warehouses.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return warehouses.where((warehouse) {
      final name = warehouse.name.trim();
      if (name.isEmpty || seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();
  }

  Future<void> _lookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _isLookingUp) return;
    if (_lastScanned == code && _results.isNotEmpty) return;

    setState(() {
      _isLookingUp = true;
      _error = null;
      _lastScanned = code;
      _manualCtrl.text = code;
    });

    try {
      final results = await context.read<AppState>().lookupStockByBarcode(
        code,
        warehouse: _selectedWarehouse,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue ?? '')
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _lookup(code);
  }

  InventoryItem _toInventoryItem(BarcodeStockLookup result) {
    final qty = result.actualQty.round();
    final status = qty > 0 ? StockStatus.inStock : StockStatus.urgent;
    return InventoryItem(
      sku: result.itemCode,
      name: result.itemName,
      warehouseId: result.warehouse,
      quantity: qty,
      minStockThreshold: 0,
      unitValue: result.valuationRate,
      status: status,
    );
  }

  void _openStockDetail(BarcodeStockLookup result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemStockDetailScreen(
          item: _toInventoryItem(result),
          areaLabel: result.warehouse,
        ),
      ),
    );
  }

  String _qty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final warehouses = _warehouses(appState);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Barcode Warehouse'),
        actions: [
          IconButton(
            tooltip: _scannerEnabled ? 'Pause scanner' : 'Resume scanner',
            onPressed: () {
              setState(() => _scannerEnabled = !_scannerEnabled);
              if (_scannerEnabled) {
                _scannerController.start();
              } else {
                _scannerController.stop();
              }
            },
            icon: Icon(
              _scannerEnabled
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _ScannerPanel(
            controller: _scannerController,
            enabled: _scannerEnabled,
            onDetect: _onDetect,
          ),
          const SizedBox(height: 12),
          _LookupControls(
            controller: _manualCtrl,
            warehouses: warehouses,
            selectedWarehouse: _selectedWarehouse,
            isLoading: _isLookingUp,
            onWarehouseChanged: (value) {
              setState(() => _selectedWarehouse = value);
              final code = _manualCtrl.text.trim();
              if (code.isNotEmpty) _lookup(code);
            },
            onLookup: () => _lookup(_manualCtrl.text),
            onClear: () {
              setState(() {
                _manualCtrl.clear();
                _lastScanned = null;
                _error = null;
                _results = [];
              });
            },
          ),
          if (_isLookingUp) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 14),
          if (_results.isEmpty && !_isLookingUp && _error == null)
            const _EmptyLookupState()
          else
            ..._results.map(
              (result) => _StockLookupCard(
                result: result,
                qtyFormatter: _qty,
                onOpenDetail: () => _openStockDetail(result),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerPanel extends StatelessWidget {
  final MobileScannerController controller;
  final bool enabled;
  final void Function(BarcodeCapture capture) onDetect;

  const _ScannerPanel({
    required this.controller,
    required this.enabled,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Stack(
        children: [
          if (enabled)
            MobileScanner(controller: controller, onDetect: onDetect)
          else
            const Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 70,
                color: AppColors.white,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.14),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 230,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentYellow,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arahkan kamera ke barcode item atau QR code.',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupControls extends StatelessWidget {
  final TextEditingController controller;
  final List<WarehouseInfo> warehouses;
  final String? selectedWarehouse;
  final bool isLoading;
  final ValueChanged<String?> onWarehouseChanged;
  final VoidCallback onLookup;
  final VoidCallback onClear;

  const _LookupControls({
    required this.controller,
    required this.warehouses,
    required this.selectedWarehouse,
    required this.isLoading,
    required this.onWarehouseChanged,
    required this.onLookup,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onLookup(),
            decoration: InputDecoration(
              labelText: 'Barcode / Item Code',
              prefixIcon: const Icon(Icons.qr_code_2_rounded),
              suffixIcon: IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      warehouses.any((w) => w.name == selectedWarehouse)
                      ? selectedWarehouse
                      : '',
                  decoration: const InputDecoration(labelText: 'Warehouse'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All warehouses'),
                    ),
                    ...warehouses.map(
                      (warehouse) => DropdownMenuItem(
                        value: warehouse.name,
                        child: Text(
                          warehouse.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      onWarehouseChanged(value == '' ? null : value),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onLookup,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Lookup'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockLookupCard extends StatelessWidget {
  final BarcodeStockLookup result;
  final String Function(double value) qtyFormatter;
  final VoidCallback onOpenDetail;

  const _StockLookupCard({
    required this.result,
    required this.qtyFormatter,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = result.actualQty > 0
        ? AppColors.success
        : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.actualQty > 0 ? 'AVAILABLE' : 'EMPTY',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.itemCode} - ${result.warehouse.isEmpty ? 'All warehouses' : result.warehouse}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Actual',
                  value: qtyFormatter(result.actualQty),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Reserved',
                  value: qtyFormatter(result.reservedQty),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Projected',
                  value: qtyFormatter(result.projectedQty),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDetail,
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('Open Stock Ledger'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.16)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyLookupState extends StatelessWidget {
  const _EmptyLookupState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 38, horizontal: 18),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            color: AppColors.slate,
            size: 52,
          ),
          SizedBox(height: 12),
          Text(
            'Scan or enter an item code',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Stock availability from Frappe Bin will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
