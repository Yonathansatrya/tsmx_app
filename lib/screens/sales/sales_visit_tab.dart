import 'dart:io';

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
  const SalesVisitTab({
    super.key,
    this.showCheckIn = true,
    this.showHistory = true,
    this.spgMode = false,
  });

  final bool? showCheckIn;
  final bool? showHistory;
  final bool spgMode;

  bool get shouldShowCheckIn => showCheckIn ?? true;
  bool get shouldShowHistory => showHistory ?? true;

  @override
  State<SalesVisitTab> createState() => _SalesVisitTabState();
}

class SalesVisitCheckInScreen extends StatelessWidget {
  const SalesVisitCheckInScreen({super.key, this.spgMode = false});

  final bool spgMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(spgMode ? 'Check-in SPG' : 'Check-in Kunjungan'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
      ),
      body: SalesVisitTab(
        showCheckIn: true,
        showHistory: false,
        spgMode: spgMode,
      ),
    );
  }
}

class _SalesVisitTabState extends State<SalesVisitTab> {
  final picker = ImagePicker();
  List<SalesCustomerOption> customers = const [];
  List<SalesVisit> visits = const [];
  SalesCustomerOption? customer;
  CustomerVisitLocation? target;
  XFile? photo;
  int historyLimit = 20;
  bool loading = true;
  bool loadingLocation = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() => super.dispose();

  Future<void> _load({bool forceRefresh = false}) async {
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
      if (widget.shouldShowCheckIn) {
        nextError = _friendlyError(e);
      }
    }

    try {
      nextVisits = widget.spgMode
          ? await state.fetchSpgVisits(forceRefresh: forceRefresh)
          : await state.fetchSalesVisits(forceRefresh: forceRefresh);
      final active = state.activeSalesVisit;
      if (active != null) {
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
      if (widget.shouldShowHistory) {
        nextError ??= _friendlyError(e);
      }
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
      if (widget.spgMode) {
        await context.read<AppState>().checkInSpgCustomer(
          customer: customer!.id,
          target: target!,
          photoPath: photo!.path,
        );
      } else {
        await context.read<AppState>().checkInSalesCustomer(
          customer: customer!.id,
          target: target!,
          photoPath: photo!.path,
        );
      }
      photo = null;
      await _load();
    });
  }

  Future<void> _pickVisitPhoto(CameraDevice cameraDevice) async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: cameraDevice,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (image != null && mounted) {
      setState(() => photo = image);
    }
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
    final history = visits
        .where((visit) => widget.shouldShowCheckIn || visit.id != active?.id)
        .take(historyLimit)
        .toList();
    final hasMoreHistory = visits.length > history.length;

    final content = RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (widget.shouldShowCheckIn) ...[
            const CollectionSectionHeader(
              title: 'Check-in Customer',
              subtitle: 'Pilih customer, validasi radius, foto, lalu check-in',
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
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null &&
              (widget.shouldShowHistory || widget.shouldShowCheckIn)) ...[
            const SizedBox(height: 12),
            ErpErrorBox(message: error!),
          ],
          if (widget.shouldShowHistory) ...[
            const SizedBox(height: 18),
            CollectionSectionHeader(
              title: widget.shouldShowCheckIn
                  ? 'Riwayat Check-in'
                  : 'Data Kunjungan',
              subtitle: widget.shouldShowCheckIn
                  ? 'Kunjungan yang selesai terakhir'
                  : 'Ketuk baris untuk melihat detail waktu dan lokasi',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 8),
            if (!widget.shouldShowCheckIn && active != null) ...[
              _activeSummaryTile(active),
              const SizedBox(height: 8),
            ],
            if (history.isEmpty)
              const ErpEmptyState(title: 'Belum ada riwayat check-in')
            else
              ...history.map(_visitTile),
            if (hasMoreHistory) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => historyLimit += 20),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load more'),
              ),
            ],
          ],
        ],
      ),
    );

    if (widget.shouldShowCheckIn) return content;
    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create-sales-visit',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            onPressed: _openCreateVisit,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('+ Kunjungan'),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateVisit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesVisitCheckInScreen(spgMode: widget.spgMode),
      ),
    );
    if (mounted) await _load();
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _pickVisitPhoto(CameraDevice.front),
                    icon: const Icon(Icons.photo_camera_front_rounded),
                    label: const Text('Selfie'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _pickVisitPhoto(CameraDevice.rear),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),
            if (photo != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.file(
                      File(photo!.path),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: AppColors.navy.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                        child: IconButton(
                          tooltip: 'Hapus foto',
                          onPressed: () => setState(() => photo = null),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              _visitCustomerLabel(visit),
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

  Widget _activeSummaryTile(SalesVisit visit) => Card(
    color: AppColors.softGreen,
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: Icon(Icons.location_on_rounded),
      ),
      title: Text(
        _visitCustomerLabel(visit),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text('Kunjungan aktif. Selesaikan dari dashboard Sales.'),
      trailing: const Text(
        'ACTIVE',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
      ),
      onTap: () => _showVisitDetail(visit),
    ),
  );

  Widget _visitTile(SalesVisit visit) {
    final customerLabel = _visitCustomerLabel(visit);
    final customerCode = visit.customer.trim();
    final timeText = _visitTimeText(visit);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVisitDetail(visit),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.softGreen,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (customerCode.isNotEmpty &&
                        customerCode != customerLabel) ...[
                      const SizedBox(height: 3),
                      Text(
                        customerCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (!widget.spgMode &&
                        visit.salesPerson.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        visit.salesPerson,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (timeText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _visitStatusPill(visit.status),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.slate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _visitCustomerLabel(SalesVisit visit) {
    final directName = visit.customerName.trim();
    final customerCode = visit.customer.trim();
    if (directName.isNotEmpty && directName != customerCode) {
      return directName;
    }
    for (final option in customers) {
      if (option.id == customerCode && option.name.trim().isNotEmpty) {
        return option.name.trim();
      }
    }
    if (directName.isNotEmpty) return directName;
    if (customerCode.isNotEmpty) return customerCode;
    return visit.id;
  }

  String _visitTimeText(SalesVisit visit) {
    final checkIn = visit.checkInTime.trim();
    final checkOut = visit.checkOutTime.trim();
    if (checkIn.isEmpty && checkOut.isEmpty) return '';
    if (checkOut.isEmpty) return 'Check-in $checkIn';
    if (checkIn.isEmpty) return 'Check-out $checkOut';
    return '$checkIn - $checkOut';
  }

  Widget _visitStatusPill(String status) {
    final normalized = status.trim().toLowerCase();
    final color = normalized.contains('cancel')
        ? AppColors.danger
        : normalized.contains('out') || normalized.contains('complete')
        ? AppColors.success
        : normalized.contains('travel')
        ? AppColors.warning
        : AppColors.primary;
    final label = status.trim().isEmpty ? 'Draft' : status.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showVisitDetail(SalesVisit visit) {
    final customerLabel = _visitCustomerLabel(visit);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.38,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CollectionSectionHeader(
                    title: customerLabel,
                    subtitle: visit.id,
                    icon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _detailRow('Status', visit.status),
                          _detailRow('Customer ID', visit.customer),
                          if (!widget.spgMode)
                            _detailRow('Sales Person', visit.salesPerson),
                          _detailRow('Employee', visit.employee),
                          _detailRow(
                            'Employee Checkin IN',
                            visit.employeeCheckinIn,
                          ),
                          _detailRow(
                            'Employee Checkin OUT',
                            visit.employeeCheckinOut,
                          ),
                          _detailRow('Check-in', visit.checkInTime),
                          _detailRow('Check-out', visit.checkOutTime),
                          _detailRow('Alamat', visit.address),
                          _detailRow(
                            'Jarak Check-in',
                            visit.checkInDistance <= 0
                                ? ''
                                : '${visit.checkInDistance.toStringAsFixed(0)} m',
                          ),
                          _detailRow(
                            'Koordinat Check-in',
                            _coordinate(
                              visit.checkInLatitude,
                              visit.checkInLongitude,
                            ),
                          ),
                          _detailRow(
                            'Koordinat Check-out',
                            _coordinate(
                              visit.checkOutLatitude,
                              visit.checkOutLongitude,
                            ),
                          ),
                          _detailRow('Catatan', visit.notes),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _coordinate(double latitude, double longitude) {
    if (latitude == 0 && longitude == 0) return '';
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  Widget _stepPanel(SalesVisit? active) {
    final step = active == null || active.employeeCheckinIn.trim().isEmpty
        ? 1
        : 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            for (var index = 1; index <= 2; index++) ...[
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
                        1 => 'Check-in',
                        _ => 'Check-out',
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
              if (index < 2)
                Container(
                  width: 52,
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
      if (widget.spgMode) {
        await context.read<AppState>().checkOutSpgVisit(visit.id);
      } else {
        await context.read<AppState>().checkOutSalesVisit(visit.id);
      }
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
