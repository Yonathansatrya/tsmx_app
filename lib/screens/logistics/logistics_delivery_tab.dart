import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_note.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_doc_utils.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'logistics_widgets.dart';

class LogisticsDeliveryTab extends StatefulWidget {
  const LogisticsDeliveryTab({super.key});

  @override
  State<LogisticsDeliveryTab> createState() => _LogisticsDeliveryTabState();
}

class _LogisticsDeliveryTabState extends State<LogisticsDeliveryTab> {
  final _search = TextEditingController();
  final _picker = ImagePicker();
  Timer? _debounce;
  bool _outstandingOnly = true;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<AppState>().refreshDeliveryNotes();

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<AppState>().setDeliveryNoteQuery(search: value);
    });
  }

  List<DeliveryNote> _filter(List<DeliveryNote> rows) {
    final query = _search.text.trim().toLowerCase();
    return rows.where((row) {
      final isOutstanding =
          row.statusKey != DeliveryNoteStatusKey.completed &&
          row.statusKey != DeliveryNoteStatusKey.cancelled &&
          row.statusKey != DeliveryNoteStatusKey.closed;
      if (_outstandingOnly && !isOutstanding) return false;
      return query.isEmpty ||
          row.id.toLowerCase().contains(query) ||
          row.customer.toLowerCase().contains(query) ||
          row.statusText.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _chooseProofPhoto(DeliveryNote row) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tambah bukti pengiriman ${row.id}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Pilih foto dari galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) return;

    setState(() {
      _busyId = row.id;
      _error = null;
    });
    try {
      await context.read<AppState>().uploadDeliveryNoteProof(
        deliveryNoteId: row.id,
        filePath: photo.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto bukti terpasang ke ${row.id}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _openDetail(DeliveryNote row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final busy = _busyId == row.id;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    row.id,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.customer,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailRow('Posting Date', row.date),
                  _detailRow('ERP Status', row.statusText),
                  _detailRow('Total', 'Rp ${formatErpCurrency(row.value)}'),
                  _detailRow('Qty', '${row.itemsCount}'),
                  const SizedBox(height: 14),
                  LogisticsInfoPanel(
                    message:
                        'Status pengiriman memakai status bawaan ERPNext dari Delivery Note. Jika status berubah di Frappe, aplikasi akan ikut saat refresh.',
                    icon: Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _chooseProofPhoto(row),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Upload Foto Bukti / POD'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final rows = _filter(appState.deliveryNotes);
    final outstanding = appState.deliveryNotes.where((row) {
      return row.statusKey != DeliveryNoteStatusKey.completed &&
          row.statusKey != DeliveryNoteStatusKey.cancelled &&
          row.statusKey != DeliveryNoteStatusKey.closed;
    }).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: logisticsPagePadding,
        children: [
          LogisticsSectionHeader(
            title: 'Delivery Monitoring',
            subtitle: '$outstanding outstanding delivery dari ERPNext',
            icon: Icons.assignment_turned_in_rounded,
          ),
          const SizedBox(height: 12),
          const LogisticsInfoPanel(
            message:
                'List ini mengambil Delivery Note ERPNext. Status pengiriman mengikuti status bawaan Frappe, sedangkan bukti POD disimpan sebagai attachment Delivery Note.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: _searchChanged,
            decoration: const InputDecoration(
              labelText: 'Cari Delivery Note atau customer',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _outstandingOnly,
            onChanged: (value) => setState(() => _outstandingOnly = value),
            title: const Text(
              'Tampilkan outstanding saja',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Sembunyikan completed, closed, cancelled'),
          ),
          if (appState.isDeliveryNotesLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (appState.deliveryNotesError != null) ...[
            const SizedBox(height: 10),
            LogisticsInfoPanel(
              message: _friendlyError(appState.deliveryNotesError!),
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            LogisticsInfoPanel(
              message: _error!,
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
          ],
          logisticsSectionGap,
          LogisticsSectionHeader(
            title: 'Delivery Notes Mobile',
            subtitle: '${rows.length} dokumen ditampilkan',
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !appState.isDeliveryNotesLoading)
            const ErpEmptyState(
              title: 'Delivery Note tidak ditemukan',
              message: 'Ubah filter/pencarian atau tarik untuk refresh.',
            )
          else
            ...rows.map(_deliveryCard),
          if (appState.hasMoreDeliveryNotes ||
              appState.isMoreDeliveryNotesLoading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: appState.isMoreDeliveryNotesLoading
                    ? null
                    : () => context.read<AppState>().loadMoreDeliveryNotes(),
                icon: appState.isMoreDeliveryNotesLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  appState.isMoreDeliveryNotesLoading
                      ? 'Loading delivery...'
                      : 'Load more delivery notes',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryCard(DeliveryNote row) {
    final busy = _busyId == row.id;
    final statusColor = _deliveryStatusColor(row);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openDetail(row),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  foregroundColor: statusColor,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_shipping_outlined),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.id,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        row.customer,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          LogisticsStatusChip(
                            label: row.statusText,
                            color: statusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${formatErpCurrency(row.value)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
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
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
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
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  Color _deliveryStatusColor(DeliveryNote row) {
    if (row.statusKey == DeliveryNoteStatusKey.completed) {
      return AppColors.success;
    }
    if (row.statusKey == DeliveryNoteStatusKey.cancelled ||
        row.statusKey == DeliveryNoteStatusKey.closed) {
      return AppColors.slate;
    }
    if (!isDocSubmitted(row.docStatus)) return AppColors.warning;
    return AppColors.primary;
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
