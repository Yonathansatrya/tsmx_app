import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'warehouse_widgets.dart';

class WarehouseBarcodeScannerScreen extends StatefulWidget {
  const WarehouseBarcodeScannerScreen({super.key});

  @override
  State<WarehouseBarcodeScannerScreen> createState() =>
      _WarehouseBarcodeScannerScreenState();
}

class _WarehouseBarcodeScannerScreenState
    extends State<WarehouseBarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualCode = TextEditingController();
  String? _scannedCode;
  List<InventoryItem> _matches = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCode.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      if (state.inventory.isEmpty) await state.refreshInventory();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scannedCode != null) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      await _findCode(value);
      break;
    }
  }

  Future<void> _findCode(String value) async {
    await _controller.stop();
    if (!mounted) return;
    final normalized = value.trim().toLowerCase();
    final inventory = context.read<AppState>().inventory;
    setState(() {
      _scannedCode = value.trim();
      _manualCode.text = value.trim();
      _matches =
          inventory
              .where(
                (item) =>
                    item.sku.toLowerCase() == normalized ||
                    item.name.toLowerCase() == normalized,
              )
              .toList()
            ..sort((a, b) => a.warehouseId.compareTo(b.warehouseId));
    });
  }

  Future<void> _scanAgain() async {
    setState(() {
      _scannedCode = null;
      _matches = const [];
      _error = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Barcode / QR Scan',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Scan Item',
            subtitle: 'Arahkan kamera ke barcode atau QR kode item',
            icon: Icons.qr_code_scanner_rounded,
          ),
          warehouseSectionGap,
          _scannerPanel(),
          const SizedBox(height: 12),
          _manualInput(),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            WarehouseInfoPanel(
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
              message: _error!,
            ),
          ],
          if (_scannedCode != null) ...[
            warehouseSectionGap,
            WarehouseSectionHeader(
              title: 'Hasil Scan',
              subtitle: 'Kode: $_scannedCode',
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 12),
            if (_matches.isEmpty)
              const WarehouseInfoPanel(
                icon: Icons.search_off_rounded,
                color: AppColors.warning,
                message:
                    'Item tidak ditemukan. Pastikan isi barcode atau QR sama dengan Item Code ERPNext.',
              )
            else ...[
              _summaryCard(),
              const SizedBox(height: 10),
              ..._matches.map(_stockCard),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanAgain,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan item lain'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _scannerPanel() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 220,
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: IconButton.filled(
              tooltip: 'Nyalakan atau matikan flash',
              onPressed: _controller.toggleTorch,
              icon: const Icon(Icons.flashlight_on_rounded),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _manualInput() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _manualCode,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) _findCode(value);
          },
          decoration: const InputDecoration(
            labelText: 'Masukkan Item Code manual',
            prefixIcon: Icon(Icons.keyboard_outlined),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(
        tooltip: 'Cari item',
        onPressed: () {
          if (_manualCode.text.trim().isNotEmpty) {
            _findCode(_manualCode.text);
          }
        },
        icon: const Icon(Icons.search_rounded),
      ),
    ],
  );

  Widget _summaryCard() {
    final totalStock = _matches.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _matches.first.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${_matches.first.sku} | Total stok $totalStock',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockCard(InventoryItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.warehouse_outlined),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              item.warehouseId,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${item.quantity}',
            style: TextStyle(
              color: item.quantity > 0 ? AppColors.success : AppColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
