import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class SalesVisitScreen extends StatefulWidget {
  const SalesVisitScreen({super.key});

  @override
  State<SalesVisitScreen> createState() => _SalesVisitScreenState();
}

class _SalesVisitScreenState extends State<SalesVisitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCustomer;
  bool _isCheckedIn = false;
  bool _mockInsideGeofence = true;
  double _distanceToCustomer = 15.0;
  XFile? _shopPhoto;
  bool _isSavingVisit = false;

  // Competitor Monitoring Form State
  final TextEditingController _compNameController = TextEditingController();
  final TextEditingController _compProductController = TextEditingController();
  final TextEditingController _compPriceController = TextEditingController();
  final TextEditingController _compNotesController = TextEditingController();

  // Potential Order Form State
  final TextEditingController _potentialProductController =
      TextEditingController();
  final TextEditingController _potentialQtyController = TextEditingController();
  final TextEditingController _potentialNotesController =
      TextEditingController();

  final List<Map<String, dynamic>> _visitTimeline = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _compNameController.dispose();
    _compProductController.dispose();
    _compPriceController.dispose();
    _compNotesController.dispose();
    _potentialProductController.dispose();
    _potentialQtyController.dispose();
    _potentialNotesController.dispose();
    super.dispose();
  }

  Future<void> _takeShopPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _shopPhoto = image;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto toko berhasil disimpan sementara.')),
      );
    }
  }

  void _submitVisitCheckIn() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih customer untuk check-in!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_mockInsideGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal Check-in: Lokasi GPS berada di luar jangkauan geofencing customer (min 50m)!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_shopPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib mengambil foto toko/customer sebelum check-in!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSavingVisit = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isSavingVisit = false;
        _isCheckedIn = true;

        _visitTimeline.insert(0, {
          'time':
              '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
          'customer': _selectedCustomer,
          'type': 'Check-in Kunjungan',
          'status':
              'Inside Geofence (${_distanceToCustomer.toStringAsFixed(0)}m)',
          'photoUploaded': true,
          'competitorLogged': _compNameController.text.isNotEmpty,
          'potentialOrder': _potentialProductController.text.isNotEmpty
              ? '${_potentialQtyController.text} Dus ${_potentialProductController.text}'
              : null,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in berhasil disimpan sementara pada sesi ini.'),
          backgroundColor: AppColors.primary,
        ),
      );
    });
  }

  void _resetCheckIn() {
    setState(() {
      _selectedCustomer = null;
      _isCheckedIn = false;
      _shopPhoto = null;
      _compNameController.clear();
      _compProductController.clear();
      _compPriceController.clear();
      _compNotesController.clear();
      _potentialProductController.clear();
      _potentialQtyController.clear();
      _potentialNotesController.clear();
    });
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
            Tab(text: 'Check-in Kunjungan'),
            Tab(text: 'Timeline Aktivitas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCheckInTab(appState), _buildTimelineTab()],
      ),
    );
  }

  // --- Check-In Tab ---
  Widget _buildCheckInTab(AppState appState) {
    final customers =
        appState.salesOrders
            .map((so) => so.customer)
            .where((customer) => customer.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedCustomer = customers.contains(_selectedCustomer)
        ? _selectedCustomer
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCheckedIn) ...[
            // Main check-in configuration
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.gps_fixed_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Check-in Kunjungan GPS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedCustomer),
                    initialValue: selectedCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Toko / Customer',
                      border: OutlineInputBorder(),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomer = val;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  // Simulated Map widget
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Map grid graphic representation
                        Positioned.fill(
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                ),
                            itemBuilder: (context, idx) => Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Geofence circle mock
                        Center(
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color:
                                  (_mockInsideGeofence
                                          ? Colors.green
                                          : Colors.red)
                                      .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _mockInsideGeofence
                                    ? Colors.green
                                    : Colors.red,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        // Customer Pin
                        const Center(
                          child: Icon(
                            Icons.store_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        // Salesman Pin
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 500),
                          left: _mockInsideGeofence ? 140 : 80,
                          top: _mockInsideGeofence ? 100 : 30,
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        // Status badge in map
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _mockInsideGeofence
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _mockInsideGeofence
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _mockInsideGeofence
                                      ? 'Inside Geofence (${_distanceToCustomer.toStringAsFixed(0)}m)'
                                      : 'Outside Geofence (182m)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Simulator Controller for Testing
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Simulator Geofence:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate,
                          ),
                        ),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text(
                                'Inside',
                                style: TextStyle(fontSize: 9),
                              ),
                              selected: _mockInsideGeofence,
                              visualDensity: VisualDensity.compact,
                              onSelected: (val) {
                                setState(() {
                                  _mockInsideGeofence = true;
                                  _distanceToCustomer = 12.0;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text(
                                'Outside',
                                style: TextStyle(fontSize: 9),
                              ),
                              selected: !_mockInsideGeofence,
                              visualDensity: VisualDensity.compact,
                              onSelected: (val) {
                                setState(() {
                                  _mockInsideGeofence = false;
                                  _distanceToCustomer = 182.0;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Photo Capture
                  const Text(
                    'Foto Kunjungan / Toko (Wajib)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_shopPhoto != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_shopPhoto!.path),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _takeShopPhoto,
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: Text(
                        _shopPhoto == null
                            ? 'Ambil Foto Toko/Customer'
                            : 'Ubah Foto',
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Competitor Monitoring Panel
            ExpansionTile(
              title: const Text(
                'Survey Monitoring Kompetitor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              subtitle: const Text(
                'Catat harga/produk kompetitor di pasar (opsional)',
                style: TextStyle(fontSize: 9, color: AppColors.slate),
              ),
              leading: const Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
              ),
              collapsedBackgroundColor: AppColors.white,
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _compNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kompetitor / Pabrik',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _compProductController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk Kompetitor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _compPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga Jual Kompetitor (Rp)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _compNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan Kompetitor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Potential Order Panel
            ExpansionTile(
              title: const Text(
                'Input Order Potensial (Prospecting)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              subtitle: const Text(
                'Kebutuhan order masa depan customer (opsional)',
                style: TextStyle(fontSize: 9, color: AppColors.slate),
              ),
              leading: const Icon(
                Icons.star_outline_rounded,
                color: AppColors.primary,
              ),
              collapsedBackgroundColor: AppColors.white,
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _potentialProductController,
                  decoration: const InputDecoration(
                    labelText: 'Produk Minat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _potentialQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Potensi (Dus)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _potentialNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Estimasi Tanggal / Catatan Prospect',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSavingVisit ? null : _submitVisitCheckIn,
                icon: _isSavingVisit
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text(
                  'CHECK-IN KUNJUNGAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Checked in success visual
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 60,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Anda Sedang Checked-In!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toko: $_selectedCustomer',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Aktifitas kunjungan Anda saat ini direkam secara real-time. Koordinat GPS, foto toko, dan survey kompetitor Anda sudah terunggah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.slate,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _resetCheckIn,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('CHECK-OUT KUNJUNGAN'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Timeline Tab ---
  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
      children: [
        const Text(
          'Tracking Aktivitas Salesman Hari Ini',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Timeline kunjungan fisik dan aktivitas yang terekam hari ini.',
          style: TextStyle(fontSize: 11, color: AppColors.slate),
        ),
        const SizedBox(height: 20),

        if (_visitTimeline.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada riwayat kunjungan terekam hari ini.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ),
            ),
          )
        else
          ..._visitTimeline.map((log) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                Column(
                  children: [
                    Text(
                      log['time'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 1,
                      height: 90,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Bullet point circle indicator
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details Card
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['customer'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['type'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.gps_fixed_rounded,
                                size: 10,
                                color: AppColors.slate,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                log['status'],
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.slate,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          if (log['competitorLogged'] ||
                              log['potentialOrder'] != null) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                          ],
                          if (log['competitorLogged'])
                            const Row(
                              children: [
                                Icon(
                                  Icons.analytics_rounded,
                                  size: 10,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Survey kompetitor tercatat',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          if (log['potentialOrder'] != null) ...[
                            if (log['competitorLogged'])
                              const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Prospek Order: ${log['potentialOrder']}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }
}
