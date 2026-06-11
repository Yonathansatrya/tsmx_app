import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/sales_workspace.dart';
import '../../services/sales_visit_location_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';
import 'collection/collection_widgets.dart';

class SalesVisitTab extends StatefulWidget {
  const SalesVisitTab({super.key});

  @override
  State<SalesVisitTab> createState() => _SalesVisitTabState();
}

class _SalesVisitTabState extends State<SalesVisitTab> {
  final picker = ImagePicker();
  final notes = TextEditingController();
  List<SalesCustomerOption> customers = const [];
  List<SalesVisit> visits = const [];
  List<SalesTrackingPoint> trackingPoints = const [];
  final competitors = <Map<String, dynamic>>[];
  final potentialOrders = <Map<String, dynamic>>[];
  SalesCustomerOption? customer;
  CustomerVisitLocation? target;
  XFile? photo;
  bool loading = true;
  bool loadingLocation = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final state = context.read<AppState>();
    try {
      final result = await Future.wait([
        state.fetchSalesCustomers(),
        state.fetchSalesVisits(),
      ]);
      customers = result[0] as List<SalesCustomerOption>;
      visits = result[1] as List<SalesVisit>;
      final active = state.activeSalesVisit;
      if (state.userRole == 'Sales' && active != null) {
        try {
          target = await state.fetchCustomerVisitLocation(active.customer);
        } catch (_) {
          target ??= CustomerVisitLocation(
            addressId: active.address,
            displayAddress: active.address,
            latitude: active.targetLatitude,
            longitude: active.targetLongitude,
          );
        }
      }
      if (state.userRole != 'Sales') {
        trackingPoints = await state.fetchLatestSalesTrackingPoints();
      }
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectCustomer(SalesCustomerOption? value) async {
    setState(() {
      customer = value;
      target = null;
      error = null;
      loadingLocation = value != null;
    });
    if (value == null) return;
    try {
      target = await context.read<AppState>().fetchCustomerVisitLocation(
        value.id,
      );
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  Future<void> _startJourney() async {
    if (customer == null || target == null) return;
    await _runAction(() async {
      await context.read<AppState>().startSalesVisitJourney(
        customer: customer!.id,
        target: target!,
      );
      await _load();
    });
  }

  Future<void> _checkIn(SalesVisit visit) async {
    if (photo == null) {
      setState(
        () => error = 'Foto toko/customer wajib diambil sebelum check-in.',
      );
      return;
    }
    final visitTarget =
        target ??
        CustomerVisitLocation(
          addressId: visit.address,
          displayAddress: visit.address,
          latitude: visit.targetLatitude,
          longitude: visit.targetLongitude,
        );
    await _runAction(() async {
      await context.read<AppState>().checkInSalesVisit(
        visit: visit,
        target: visitTarget,
        photoPath: photo!.path,
        notes: notes.text,
        competitors: competitors,
        potentialOrders: potentialOrders,
      );
      photo = null;
      notes.clear();
      competitors.clear();
      potentialOrders.clear();
      await _load();
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const Material(
          color: AppColors.white,
          child: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.route_rounded), text: 'Perjalanan'),
              Tab(icon: Icon(Icons.storefront_rounded), text: 'Aktivitas'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Riwayat'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [_journeyTab(), _activityTab(), _historyTab()],
          ),
        ),
      ],
    ),
  );

  Widget _journeyTab() {
    final state = context.watch<AppState>();
    if (state.userRole != 'Sales') return _managerJourneyTab();
    final active = state.activeSalesVisit;
    final point = state.latestVisitLocation;
    final distance = active == null || point == null
        ? null
        : _distanceToVisit(state, active, point);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Perjalanan Customer',
            subtitle: 'Lokasi dicatat sampai check-in berhasil',
            icon: Icons.route_rounded,
          ),
          _stepPanel(active),
          const SizedBox(height: 12),
          if (active == null) ...[
            InkWell(
              onTap: loadingLocation ? null : _showCustomerSelectSheet,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Customer tujuan',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  suffixIcon: Icon(Icons.search_rounded),
                ),
                child: Text(
                  customer == null
                      ? 'Pilih atau cari customer'
                      : customer!.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: customer == null ? AppColors.slate : AppColors.navy,
                    fontWeight: customer == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (loadingLocation) const LinearProgressIndicator(),
            if (target != null) ...[
              const SizedBox(height: 12),
              CollectionInfoPanel(
                title: target!.displayAddress,
                message:
                    'Check-in tersedia dalam radius ${target!.geofenceRadius.toStringAsFixed(0)} meter.',
                icon: Icons.location_on_outlined,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: loading || target == null ? null : _startJourney,
              icon: const Icon(Icons.navigation_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Mulai Perjalanan'),
              ),
            ),
          ] else ...[
            _activeJourneyCard(active, point, distance),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading ? null : () => _confirmCancelJourney(active),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Batalkan Perjalanan'),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErpErrorBox(message: error!),
          ],
        ],
      ),
    );
  }

  Widget _activeJourneyCard(
    SalesVisit visit,
    VisitLocationPoint? point,
    double? distance,
  ) {
    final traveling = visit.status.toLowerCase() == 'traveling';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              visit.customer,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            CollectionInfoPanel(
              title: traveling ? 'Perjalanan aktif' : 'Sudah check-in',
              message: point == null
                  ? 'Menunggu lokasi GPS...'
                  : 'Akurasi ${point.accuracy.toStringAsFixed(0)} m'
                        '${distance == null ? '' : ' • Jarak ${distance.toStringAsFixed(0)} m'}',
              icon: traveling
                  ? Icons.navigation_rounded
                  : Icons.check_circle_outline_rounded,
              color: traveling ? AppColors.warning : AppColors.success,
            ),
            if (traveling) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () => _runAction(
                        () =>
                            context.read<AppState>().getCurrentVisitLocation(),
                      ),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Perbarui Lokasi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _activityTab() {
    final state = context.watch<AppState>();
    if (state.userRole != 'Sales') return _managerActivityTab();
    final active = state.activeSalesVisit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const CollectionSectionHeader(
          title: 'Aktivitas Kunjungan',
          subtitle: 'Isi setelah tiba di lokasi customer',
          icon: Icons.assignment_turned_in_outlined,
        ),
        if (active == null || active.status.toLowerCase() != 'traveling')
          CollectionInfoPanel(
            title: active == null
                ? 'Belum ada perjalanan aktif'
                : 'Kunjungan aktif',
            message: active == null
                ? 'Mulai perjalanan dari tab Perjalanan terlebih dahulu.'
                : 'Anda sudah check-in. Selesaikan kunjungan melalui tombol check-out.',
            icon: Icons.info_outline_rounded,
          ),
        if (active != null && active.status.toLowerCase() == 'traveling') ...[
          _visitForm(active, state),
        ],
        if (active != null && active.status.toLowerCase() == 'checked in') ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : () => _confirmCheckOut(active),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Check-out dan Selesaikan Kunjungan'),
          ),
        ],
        if (loading) const LinearProgressIndicator(),
        if (error != null) ErpErrorBox(message: error!),
      ],
    );
  }

  Widget _visitForm(SalesVisit visit, AppState state) {
    final point = state.latestVisitLocation;
    final distance = point == null
        ? null
        : _distanceToVisit(state, visit, point);
    final allowedRadius = target?.geofenceRadius ?? 50;
    final canCheckIn =
        point != null &&
        point.accuracy <= 50 &&
        distance != null &&
        distance <= allowedRadius;
    final checkInHint = _checkInHint(
      point: point,
      distance: distance,
      allowedRadius: allowedRadius,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan kunjungan',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _rowEditor(
              title: 'Monitoring Kompetitor',
              rows: competitors,
              icon: Icons.compare_arrows_rounded,
              onAdd: () => _showCompetitorDialog(),
            ),
            const SizedBox(height: 12),
            _rowEditor(
              title: 'Order Potensial',
              rows: potentialOrders,
              icon: Icons.lightbulb_outline_rounded,
              onAdd: () => _showPotentialOrderDialog(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 75,
                  maxWidth: 1600,
                );
                if (image != null && mounted) setState(() => photo = image);
              },
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                photo == null
                    ? 'Ambil Foto Toko/Customer'
                    : 'Foto siap digunakan',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                photo == null
                    ? 'Foto wajib sebelum check-in.'
                    : 'Foto sudah siap dilampirkan ke kunjungan.',
                style: TextStyle(
                  color: photo == null ? AppColors.warning : AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            CollectionInfoPanel(
              title: canCheckIn ? 'Lokasi siap check-in' : 'Validasi lokasi',
              message: checkInHint,
              icon: canCheckIn
                  ? Icons.check_circle_outline_rounded
                  : Icons.my_location_rounded,
              color: canCheckIn ? AppColors.success : AppColors.warning,
            ),
            if (!canCheckIn) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () => _runAction(
                        () =>
                            context.read<AppState>().getCurrentVisitLocation(),
                      ),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Perbarui Lokasi Sekarang'),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading || photo == null || !canCheckIn
                  ? null
                  : () => _checkIn(visit),
              icon: const Icon(Icons.location_on_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Text('Validasi Lokasi dan Check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowEditor({
    required String title,
    required List<Map<String, dynamic>> rows,
    required IconData icon,
    required VoidCallback onAdd,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      if (rows.isEmpty)
        const Text('Opsional', style: TextStyle(color: AppColors.slate))
      else
        ...rows.indexed.map(
          (entry) => ListTile(
            dense: true,
            title: Text(entry.$2.values.first.toString()),
            subtitle: Text(entry.$2.values.skip(1).join(' • ')),
            trailing: IconButton(
              onPressed: () => setState(() => rows.removeAt(entry.$1)),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ),
    ],
  );

  Widget _historyTab() {
    final completed = visits
        .where(
          (visit) =>
              visit.status.toLowerCase() == 'checked out' ||
              visit.status.toLowerCase() == 'cancelled',
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Riwayat Kunjungan',
            subtitle: 'Aktivitas salesman yang sudah selesai',
            icon: Icons.history_rounded,
          ),
          if (completed.isEmpty)
            const ErpEmptyState(title: 'Belum ada riwayat kunjungan')
          else
            ...completed.map(
              (visit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.softGreen,
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.storefront_outlined),
                    ),
                    title: Text(
                      visit.customer,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${visit.checkInTime}\n${visit.status}'
                      '${visit.salesPerson.isEmpty ? '' : ' • ${visit.salesPerson}'}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepPanel(SalesVisit? active) {
    final status = active?.status.toLowerCase();
    final step = active == null
        ? 1
        : status == 'traveling'
        ? 2
        : 3;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            for (var index = 1; index <= 3; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: index <= step
                          ? AppColors.primary
                          : AppColors.surfaceMuted,
                      foregroundColor: index <= step
                          ? AppColors.white
                          : AppColors.slate,
                      child: Text(
                        '$index',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      switch (index) {
                        1 => 'Pilih tujuan',
                        2 => 'Tiba & check-in',
                        _ => 'Selesaikan',
                      },
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: index <= step
                            ? AppColors.primary
                            : AppColors.slate,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 3)
                Container(
                  width: 22,
                  height: 2,
                  color: index < step ? AppColors.primary : AppColors.border,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _checkInHint({
    required VisitLocationPoint? point,
    required double? distance,
    required double allowedRadius,
  }) {
    if (point == null) {
      return 'Tekan Perbarui Lokasi agar aplikasi memeriksa posisi Anda.';
    }
    if (point.accuracy > 50) {
      return 'Sinyal GPS belum akurat (${point.accuracy.toStringAsFixed(0)} m). '
          'Coba di area terbuka lalu perbarui lokasi.';
    }
    if (distance == null) {
      return 'Lokasi tujuan customer belum dapat dihitung.';
    }
    if (distance > allowedRadius) {
      return 'Anda masih ${distance.toStringAsFixed(0)} m dari customer. '
          'Dekati hingga maksimal ${allowedRadius.toStringAsFixed(0)} m.';
    }
    return 'Anda berada ${distance.toStringAsFixed(0)} m dari customer dan '
        'sudah masuk radius kunjungan.';
  }

  Future<void> _confirmCancelJourney(SalesVisit visit) async {
    final confirmed = await _confirmAction(
      title: 'Batalkan perjalanan?',
      message:
          'Perjalanan ke ${visit.customer} akan dihentikan dan ditandai Cancelled.',
      actionLabel: 'Batalkan Perjalanan',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runAction(() async {
      await context.read<AppState>().cancelSalesVisitJourney(visit.id);
      await _load();
    });
  }

  Future<void> _confirmCheckOut(SalesVisit visit) async {
    final confirmed = await _confirmAction(
      title: 'Selesaikan kunjungan?',
      message: 'Pastikan seluruh aktivitas di ${visit.customer} sudah selesai.',
      actionLabel: 'Check-out',
    );
    if (!confirmed || !mounted) return;
    await _runAction(() async {
      await context.read<AppState>().checkOutSalesVisit(visit.id);
      await _load();
    });
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Kembali'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _friendlyError(Object value) {
    var message = value.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    message = message.replaceAll(RegExp(r'<[^>]*>'), ' ');
    message = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (message.contains('Customer belum memiliki Primary Address')) {
      return 'Alamat utama customer belum tersedia. Hubungi admin untuk '
          'melengkapi Primary Address customer.';
    }
    if (message.contains('Koordinat Primary Address')) {
      return 'Koordinat alamat customer belum tersedia. Hubungi admin untuk '
          'melengkapi latitude dan longitude.';
    }
    if (message.contains('GPS belum aktif')) {
      return 'GPS belum aktif. Aktifkan lokasi perangkat lalu coba lagi.';
    }
    if (message.contains('Izin lokasi')) {
      return 'Aplikasi belum mendapat izin lokasi. Aktifkan izin lokasi pada '
          'pengaturan perangkat.';
    }
    return message;
  }

  Widget _managerJourneyTab() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const CollectionSectionHeader(
          title: 'Lokasi Terakhir Salesman',
          subtitle: 'Satu lokasi terbaru per salesman',
          icon: Icons.location_searching_rounded,
        ),
        if (trackingPoints.isEmpty)
          const ErpEmptyState(title: 'Belum ada lokasi perjalanan')
        else
          ...trackingPoints.map(
            (point) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.softGreen,
                  foregroundColor: AppColors.primary,
                  child: Icon(Icons.person_pin_circle_outlined),
                ),
                title: Text(
                  point.salesPerson.isEmpty
                      ? 'Salesman belum dipetakan'
                      : point.salesPerson,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${point.customer}\n'
                  '${point.capturedAt?.toLocal().toString() ?? '-'} | '
                  'akurasi ${point.accuracy.toStringAsFixed(0)} m',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ErpErrorBox(message: error!),
      ],
    ),
  );

  Widget _managerActivityTab() {
    final active = visits.where((visit) {
      final status = visit.status.toLowerCase();
      return status == 'traveling' || status == 'checked in';
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Aktivitas Kunjungan Aktif',
            subtitle: 'Manager/Admin memantau tanpa mengubah kunjungan',
            icon: Icons.monitor_heart_outlined,
          ),
          if (active.isEmpty)
            const ErpEmptyState(title: 'Tidak ada kunjungan aktif')
          else
            ...active.map(
              (visit) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.softGreen,
                    foregroundColor: visit.status.toLowerCase() == 'traveling'
                        ? AppColors.warning
                        : AppColors.primary,
                    child: Icon(
                      visit.status.toLowerCase() == 'traveling'
                          ? Icons.navigation_rounded
                          : Icons.storefront_rounded,
                    ),
                  ),
                  title: Text(
                    visit.customer,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${visit.salesPerson.isEmpty ? 'Salesman belum dipetakan' : visit.salesPerson}\n'
                    '${visit.status} | ${visit.journeyStartTime}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double? _distanceToVisit(
    AppState state,
    SalesVisit visit,
    VisitLocationPoint point,
  ) {
    if (visit.targetLatitude == 0 && visit.targetLongitude == 0) return null;
    return state.visitDistanceTo(
      CustomerVisitLocation(
        addressId: visit.address,
        displayAddress: visit.address,
        latitude: visit.targetLatitude,
        longitude: visit.targetLongitude,
      ),
      point,
    );
  }

  Future<void> _showCompetitorDialog() async {
    final values = await _showRowDialog(
      title: 'Tambah Kompetitor',
      labels: const ['Nama kompetitor', 'Produk', 'Harga', 'Catatan'],
    );
    if (values == null || values.first.isEmpty) return;
    setState(
      () => competitors.add({
        'competitor_name': values[0],
        'product': values[1],
        'price': double.tryParse(values[2]) ?? 0,
        'notes': values[3],
      }),
    );
  }

  Future<void> _showCustomerSelectSheet() async {
    final selected = await showModalBottomSheet<SalesCustomerOption>(
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
                ? customers.take(30).toList()
                : customers.where((row) {
                    return row.id.toLowerCase().contains(normalized) ||
                        row.name.toLowerCase().contains(normalized);
                  }).toList();
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
                    children: [
                      const Expanded(
                        child: Text(
                          'Pilih Customer Tujuan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Cari nama atau ID customer',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * 0.48,
                    child: filtered.isEmpty
                        ? const Center(child: Text('Customer tidak ditemukan'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.softGreen,
                                  foregroundColor: AppColors.primary,
                                  child: Icon(Icons.storefront_outlined),
                                ),
                                title: Text(
                                  row.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: row.id == row.name
                                    ? null
                                    : Text(row.id),
                                trailing: customer?.id == row.id
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
            );
          },
        );
      },
    );
    if (selected != null) await _selectCustomer(selected);
  }

  Future<void> _showPotentialOrderDialog() async {
    final values = await _showRowDialog(
      title: 'Tambah Order Potensial',
      labels: const ['Item', 'Qty', 'Catatan'],
    );
    if (values == null || values.first.isEmpty) return;
    setState(
      () => potentialOrders.add({
        'item': values[0],
        'qty': double.tryParse(values[1]) ?? 0,
        'notes': values[2],
      }),
    );
  }

  Future<List<String>?> _showRowDialog({
    required String title,
    required List<String> labels,
  }) async {
    final controllers = labels.map((_) => TextEditingController()).toList();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < labels.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controllers[index],
                    keyboardType:
                        labels[index] == 'Harga' || labels[index] == 'Qty'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: labels[index]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controllers.map((controller) => controller.text.trim()).toList(),
            ),
            child: const Text('Tambahkan'),
          ),
        ],
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    return result;
  }
}
