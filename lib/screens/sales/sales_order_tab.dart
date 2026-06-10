import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../create_sales_order_screen.dart';

class SalesOrderMobileScreen extends StatefulWidget {
  const SalesOrderMobileScreen({super.key});

  @override
  State<SalesOrderMobileScreen> createState() => _SalesOrderMobileScreenState();
}

class _SalesOrderMobileScreenState extends State<SalesOrderMobileScreen>
    with SingleTickerProviderStateMixin {
  static const _salesWarehouse = 'Stores - Jakarta';

  late TabController _tabController;
  final TextEditingController _stockSearchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _stockQuery = '';

  String? _selectedCustomer;
  String? _selectedItemCode;
  List<_LookupOption> _customerOptions = [];
  bool _isLoadingCustomers = false;
  bool _isLoadingInsight = false;
  double _creditLimit = 0.0;
  double _outstanding = 0.0;
  double _itemPrice = 0.0;
  List<dynamic> _stocksList = [];
  List<dynamic> _purchaseHistory = [];

  XFile? _uploadedPhoto;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().fetchInventoryFromFrappe(
        filters: const [
          ['warehouse', '=', _salesWarehouse],
        ],
      );
      _loadAllCustomers();
    });
  }

  Future<void> _loadAllCustomers() async {
    setState(() => _isLoadingCustomers = true);
    final appState = context.read<AppState>();
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await appState.frappeService.fetchResource(
          'Customer',
          fields: const ['name', 'customer_name'],
          orderBy: 'customer_name asc',
        );
      } catch (_) {
        rows = await appState.frappeService.fetchResource(
          'Customer',
          fields: const ['name'],
          orderBy: 'name asc',
        );
      }
      if (!mounted) return;
      setState(() {
        _customerOptions = rows
            .map((row) {
              final id = row['name']?.toString() ?? '';
              final name = row['customer_name']?.toString() ?? id;
              return _LookupOption(id: id, name: name);
            })
            .where((option) => option.id.isNotEmpty)
            .toList();
      });
    } finally {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  Future<_LookupOption?> _showLookupSelector({
    required String title,
    required String hint,
    required List<_LookupOption> options,
  }) {
    return showModalBottomSheet<_LookupOption>(
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
            final filtered = options.where((option) {
              return normalized.isEmpty ||
                  option.id.toLowerCase().contains(normalized) ||
                  option.name.toLowerCase().contains(normalized);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'Data tidak ditemukan',
                                  style: TextStyle(color: AppColors.slate),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  return ListTile(
                                    title: Text(
                                      option.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: option.name == option.id
                                        ? null
                                        : Text(option.id),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, option),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stockSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _uploadedPhoto = image;
        _isUploadingPhoto = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto berhasil diupload dan disinkronkan ke ERPNext!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _fetchCustomerAndItemDetails() async {
    if (_selectedCustomer == null) return;
    setState(() {
      _isLoadingInsight = true;
    });

    final appState = context.read<AppState>();
    try {
      final insight = await appState.fetchCustomerSalesInsight(
        _selectedCustomer!,
        company: 'PT Tani Mandiri Sukses',
      );

      double price = 0.0;
      List<dynamic> stocks = [];
      if (_selectedItemCode != null) {
        final itemInsight = await appState.fetchItemSalesInsight(
          _selectedItemCode!,
          customer: _selectedCustomer,
          company: 'PT Tani Mandiri Sukses',
          warehouse: _salesWarehouse,
        );
        price = itemInsight.price;
        stocks = itemInsight.stocks;
      }

      final history = await appState.fetchCustomerPurchaseHistory(
        customer: _selectedCustomer!,
        doctype: 'Sales Order',
        company: 'PT Tani Mandiri Sukses',
      );

      if (mounted) {
        setState(() {
          _creditLimit = insight.creditLimit;
          _outstanding = insight.outstanding;
          _itemPrice = price;
          _stocksList = stocks;
          _purchaseHistory = history;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInsight = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Sales Order'),
            Tab(text: 'Cek Stok'),
            Tab(text: 'Customer Check'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Sales Order'),
        backgroundColor: AppColors.primary,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderDraftsTab(appState),
          _buildStockCheckTab(appState),
          _buildCustomerCheckTab(appState),
        ],
      ),
    );
  }

  Widget _buildOrderDraftsTab(AppState appState) {
    final orders = appState.salesOrders;

    return RefreshIndicator(
      onRefresh: () => appState.refreshSalesOrders(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Foto Order / Customer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Ambil foto PO fisik atau toko customer untuk diunggah langsung ke ERPNext.',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),

                const SizedBox(height: 12),

                if (_uploadedPhoto != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_uploadedPhoto!.path),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : _pickImage,
                    icon: _isUploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 16),
                    label: Text(
                      _isUploadingPhoto
                          ? 'Mengunggah...'
                          : 'Ambil Foto Dokumen',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales Order Saya',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              Text(
                '${orders.length} Order',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Belum ada Sales Order yang dibuat oleh user ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ),
              ),
            )
          else
            ...orders.map((order) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  title: Row(
                    children: [
                      Text(
                        order.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.statusText.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFCA8A04),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      Text(
                        order.customer,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        order.date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rp ${formatErpCurrency(order.value)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.docStatus == 0
                                ? Icons.edit_note_rounded
                                : Icons.visibility_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 2),
                          Text(
                            order.docStatus == 0 ? 'Edit/Revisi' : 'Lihat',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          order.docStatus == 0
                              ? 'Membuka draft ${order.id} untuk direvisi'
                              : 'Membuka detail ${order.id}',
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStockCheckTab(AppState appState) {
    final query = _stockQuery.toLowerCase().trim();
    final items = appState.inventory.where((item) {
      final matchesWarehouse = item.warehouseId == _salesWarehouse;
      final matchesQuery =
          query.isEmpty ||
          item.sku.toLowerCase().contains(query) ||
          item.name.toLowerCase().contains(query);
      return matchesWarehouse && matchesQuery;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warehouse: Stores - Jakarta',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stockSearchController,
                onChanged: (val) => setState(() => _stockQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari SKU barang atau nama produk...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: item.quantity <= 100
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : AppColors.softGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Total: ${item.quantity} Dus',
                              style: TextStyle(
                                color: item.quantity <= 100
                                    ? Colors.red
                                    : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'SKU: ${item.sku}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Text(
                        'Stores - Jakarta',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Customer Check Tab ---
  Widget _buildCustomerCheckTab(AppState appState) {
    final productsByCode = <String, _LookupOption>{};
    for (final item in appState.inventory.where(
      (item) => item.warehouseId == _salesWarehouse,
    )) {
      productsByCode[item.sku] = _LookupOption(id: item.sku, name: item.name);
    }
    final products = productsByCode.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedCustomer = _customerOptions
        .where((option) => option.id == _selectedCustomer)
        .firstOrNull;
    final selectedProduct = products
        .where((option) => option.id == _selectedItemCode)
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cek Limit Kredit & Harga Customer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),

                const SizedBox(height: 14),

                _SearchSelectorField(
                  label: 'Customer',
                  hint: 'Cari nama atau kode customer',
                  value: selectedCustomer?.label,
                  isLoading: _isLoadingCustomers,
                  onTap: () async {
                    final selected = await _showLookupSelector(
                      title: 'Pilih Customer',
                      hint: 'Cari nama atau kode customer',
                      options: _customerOptions,
                    );
                    if (selected == null || !mounted) return;
                    setState(() {
                      _selectedCustomer = selected.id;
                    });
                    _fetchCustomerAndItemDetails();
                  },
                ),

                const SizedBox(height: 12),

                _SearchSelectorField(
                  label: 'Produk Stores - Jakarta',
                  hint: 'Cari nama atau kode produk',
                  value: selectedProduct?.label,
                  onTap: () async {
                    final selected = await _showLookupSelector(
                      title: 'Pilih Produk',
                      hint: 'Cari nama atau kode produk',
                      options: products,
                    );
                    if (selected == null || !mounted) return;
                    setState(() {
                      _selectedItemCode = selected.id;
                    });
                    _fetchCustomerAndItemDetails();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_isLoadingInsight)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedCustomer != null) ...[
            // Credit Limit & Outstanding Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Kredit Customer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Limit Kredit:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                        ),
                        Text(
                          'Rp ${formatErpCurrency(_creditLimit)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Outstanding Piutang:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                        ),
                        Text(
                          'Rp ${formatErpCurrency(_outstanding)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color:
                                _outstanding > _creditLimit && _creditLimit > 0
                                ? Colors.red
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Limit bar
                    if (_creditLimit > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_outstanding / _creditLimit).clamp(0.0, 1.0),
                          backgroundColor: AppColors.border,
                          color: _outstanding > _creditLimit
                              ? Colors.red
                              : AppColors.primary,
                          minHeight: 8,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${((_outstanding / _creditLimit) * 100).toStringAsFixed(0)}% terpakai',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.slate,
                            ),
                          ),
                          Text(
                            'Sisa Kredit: Rp ${formatErpCurrency((_creditLimit - _outstanding).clamp(0.0, double.infinity))}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Item Price & Stock Realtime per Gudang
            if (_selectedItemCode != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harga & Stok: $_selectedItemCode',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Harga Price List:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                            ),
                          ),
                          Text(
                            'Rp ${formatErpCurrency(_itemPrice)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      const Divider(height: 1),

                      const SizedBox(height: 12),

                      const Text(
                        'Stok Real-time Stores - Jakarta:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_stocksList.isEmpty)
                        const Text(
                          'Tidak ada stok terdaftar untuk gudang ini.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        ..._stocksList.map((st) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  st.warehouse.split(' - ').last,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                  ),
                                ),
                                Text(
                                  '${st.actualQty.toStringAsFixed(0)} Dus',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Customer Purchase History
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'History Pembelian Customer (SO)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_purchaseHistory.isEmpty)
                      const Text(
                        'Belum ada riwayat pembelian.',
                        style: TextStyle(fontSize: 11, color: AppColors.slate),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _purchaseHistory.length.clamp(0, 5),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final h = _purchaseHistory[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.id,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    Text(
                                      h.date,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.slate,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rp ${formatErpCurrency(h.total)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    Text(
                                      h.status,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: h.status == 'Submitted'
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Silakan pilih customer terlebih dahulu untuk memantau limit kredit, outstanding piutang, dan riwayat pembelian.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LookupOption {
  final String id;
  final String name;

  const _LookupOption({required this.id, required this.name});

  String get label => name == id ? name : '$name ($id)';
}

class _SearchSelectorField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final bool isLoading;
  final VoidCallback onTap;

  const _SearchSelectorField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search_rounded),
        ),
        child: Text(
          value ?? hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null ? AppColors.slate : AppColors.navy,
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
