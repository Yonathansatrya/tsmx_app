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
    var nextCustomers = customers;
    var nextVisits = visits;
    String? nextError;
    try {
      nextCustomers = await state.fetchSalesCustomers();
    } catch (e) {
      nextError = _friendlyError(e);
    }

    try {
      nextVisits = await state.fetchSalesVisits();
      final active = state.activeSalesVisit;
      if (state.mobileAccess.isSalesUser && active != null) {
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
    } catch (e) {
      nextError ??= _friendlyError(e);
    } finally {
      if (mounted) {
        setState(() {
          customers = nextCustomers;
          visits = nextVisits;
          error = nextError;
          loading = false;
        });
      }
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

  Future<void> _checkInSelectedCustomer() async {
    if (customer == null || target == null) return;
    if (photo == null) {
      setState(() => error = 'Selfie wajib diambil sebelum check-in.');
      return;
    }
    await _runAction(() async {
      await context.read<AppState>().checkInSalesCustomer(
        customer: customer!.id,
        target: target!,
        photoPath: photo!.path,
        notes: notes.text,
      );
      photo = null;
      notes.clear();
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
  Widget build(BuildContext context) => _checkInTab();

  Widget _checkInTab() {
    final state = context.watch<AppState>();
    final active = state.activeSalesVisit;
    final point = state.latestVisitLocation;
    final selectedDistance = target == null || point == null
        ? null
        : state.visitDistanceTo(target!, point);
    final activeDistance = active == null || point == null
        ? null
        : _distanceToVisit(state, active, point);
    final selectedRadius = target?.geofenceRadius ?? 50;
    final canCheckIn =
        active == null &&
        customer != null &&
        target != null &&
        photo != null &&
        point != null &&
        point.accuracy <= 50 &&
        selectedDistance != null &&
        selectedDistance <= selectedRadius;
    final completed = visits
        .where((visit) => visit.status.toLowerCase() == 'checked out')
        .take(8)
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Check-in Customer',
            subtitle: 'Pilih customer, validasi radius, selfie, lalu check-in',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          _stepPanel(active),
          const SizedBox(height: 12),
          if (active == null)
            _checkInForm(
              state: state,
              point: point,
              distance: selectedDistance,
              canCheckIn: canCheckIn,
            )
          else
            _activeCheckInCard(active, point, activeDistance),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErpErrorBox(message: error!),
          ],
          const SizedBox(height: 18),
          CollectionSectionHeader(
            title: active == null ? 'Riwayat Check-in' : 'Check-in Aktif',
            subtitle: active == null
                ? 'Kunjungan yang selesai terakhir'
                : 'Checkout setelah aktivitas di customer selesai',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 8),
          if (active != null)
            _visitTile(active)
          else if (completed.isEmpty)
            const ErpEmptyState(title: 'Belum ada riwayat check-in')
          else
            ...completed.map(_visitTile),
        ],
      ),
    );
  }

  Widget _checkInForm({
    required AppState state,
    required VisitLocationPoint? point,
    required double? distance,
    required bool canCheckIn,
  }) {
    final allowedRadius = target?.geofenceRadius ?? 50;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: loadingLocation ? null : _showCustomerSelectSheet,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Customer',
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
                    fontWeight: FontWeight.w800,
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
                    'Radius check-in ${allowedRadius.toStringAsFixed(0)} meter.',
                icon: Icons.map_outlined,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () => _runAction(
                      () => context.read<AppState>().getCurrentVisitLocation(),
                    ),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Ambil Lokasi Sekarang'),
            ),
            if (point != null) ...[
              const SizedBox(height: 10),
              CollectionInfoPanel(
                title: canCheckIn ? 'Lokasi valid' : 'Validasi radius',
                message: _checkInHint(
                  point: point,
                  distance: distance,
                  allowedRadius: allowedRadius,
                ),
                icon: canCheckIn
                    ? Icons.check_circle_outline_rounded
                    : Icons.location_searching_rounded,
                color: canCheckIn ? AppColors.success : AppColors.warning,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      final image = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 70,
                        maxWidth: 1280,
                      );
                      if (image != null && mounted) {
                        setState(() => photo = image);
                      }
                    },
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(photo == null ? 'Ambil Selfie' : 'Selfie siap'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan opsional',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: loading || !canCheckIn
                  ? null
                  : _checkInSelectedCustomer,
              icon: const Icon(Icons.login_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Text('Check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCheckInCard(
    SalesVisit visit,
    VisitLocationPoint? point,
    double? distance,
  ) {
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
              title: 'Sedang check-in',
              message: point == null
                  ? 'Tekan checkout saat aktivitas selesai.'
                  : 'Akurasi ${point.accuracy.toStringAsFixed(0)} m'
                        '${distance == null ? '' : ' | Jarak ${distance.toStringAsFixed(0)} m'}',
              icon: Icons.storefront_rounded,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : () => _confirmCheckOut(visit),
              icon: const Icon(Icons.logout_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Text('Check-out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitTile(SalesVisit visit) => Card(
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
        '${visit.checkInTime.isEmpty ? '-' : visit.checkInTime}'
        '${visit.checkOutTime.isEmpty ? '' : '\nCheckout: ${visit.checkOutTime}'}'
        '${visit.salesPerson.isEmpty ? '' : '\n${visit.salesPerson}'}',
      ),
      isThreeLine: true,
      trailing: Text(
        visit.status,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

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

  Future<void> _showCustomerSelectSheet() async {
    final selected = await showModalBottomSheet<SalesCustomerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pilih Customer Tujuan',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau ID customer',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                        ),
                      ),
                      Flexible(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                    'Customer tidak ditemukan',
                                    style: TextStyle(
                                      color: AppColors.slate,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  14,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                itemBuilder: (context, index) {
                                  final row = filtered[index];
                                  return ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.softGreen,
                                      foregroundColor: AppColors.primary,
                                      child: Icon(Icons.storefront_outlined),
                                    ),
                                    title: Text(
                                      row.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    subtitle: row.id == row.name
                                        ? null
                                        : Text(
                                            row.id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    trailing: customer?.id == row.id
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.success,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.pop(sheetContext, row),
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
    if (selected != null) await _selectCustomer(selected);
  }
}
