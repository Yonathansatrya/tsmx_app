import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'sales_ui.dart';
import 'create_noo_request_screen.dart';

class NooRequestTab extends StatefulWidget {
  const NooRequestTab({super.key});

  @override
  State<NooRequestTab> createState() => _NooRequestTabState();
}

class _NooRequestTabState extends State<NooRequestTab> {
  static const _statusOptions = [
    'Draft',
    'Pending Approval',
    'Approved',
    'Rejected',
    'Created Customer',
  ];

  bool _isLoading = true;
  String? _error;
  String? _statusFilter;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _filteredRequests();
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView(
            padding: SalesUi.compactScreenPadding,
            children: [
              SalesHeroCard(
                title: 'Daftar NOO',
                subtitle:
                    'Pantau pengajuan outlet baru sebelum menjadi Customer.',
                icon: Icons.person_add_alt_1_rounded,
                trailing: IconButton.filledTonal(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadRequests,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ),
              SalesUi.gap(),
              _statusFilterBar(),
              SalesUi.gap(),
              if (_error != null)
                _errorCard(_error!)
              else if (_isLoading)
                _loadingCard()
              else if (visibleRequests.isEmpty)
                _emptyCard()
              else
                ...visibleRequests.map(_requestCard),
              const SizedBox(height: 84),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create-noo-request',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Buat NOO',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateNooRequestScreen()),
    );
    if (created != true || !mounted) return;
    await _loadRequests();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengajuan NOO berhasil dikirim.')),
    );
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    Navigator.of(context).pop();
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateNooRequestScreen(initial: row)),
    );
    if (updated != true || !mounted) return;
    await _loadRequests();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengajuan NOO berhasil diperbarui.')),
    );
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final salesPerson =
          (state.currentSalesPerson ??
                  await state.resolveCurrentSalesIdentity())
              ?.trim() ??
          '';
      final rows = await _fetchNooRequests(
        state,
        fields: const [
          'name',
          'request_date',
          'company',
          'sales_person',
          'customer_name',
          'customer_type',
          'customer_group',
          'mobile_no',
          'address_line1',
          'status',
          'modified',
        ],
        filters: null,
        scopedFilters: salesPerson.isEmpty
            ? null
            : [
                ['sales_person', '=', salesPerson],
              ],
      );
      if (!mounted) return;
      setState(() => _requests = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNooRequests(
    AppState state, {
    required List<String> fields,
    List<List<dynamic>>? filters,
    List<List<dynamic>>? scopedFilters,
  }) async {
    Object? resourceError;
    Object? reportError;
    const baseFields = [
      'name',
      'request_date',
      'company',
      'sales_person',
      'customer_name',
      'customer_type',
      'customer_group',
      'status',
      'modified',
    ];

    try {
      return await state.frappeService.fetchResource(
        'NOO Request',
        fields: fields,
        filters: filters,
        orderBy: 'modified desc',
        limit: 50,
        limitStart: 0,
      );
    } catch (error) {
      resourceError = error;
    }

    if (filters == null && scopedFilters != null) {
      try {
        return await state.frappeService.fetchResource(
          'NOO Request',
          fields: fields,
          filters: scopedFilters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (_) {
        // Keep the original unscoped error for the fallback checks below.
      }
    }

    if (_isFieldShapeError(resourceError)) {
      try {
        return await state.frappeService.fetchResource(
          'NOO Request',
          fields: baseFields,
          filters: filters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (error) {
        resourceError = error;
      }
    }

    try {
      return await state.frappeService.fetchReportView(
        'NOO Request',
        fields: fields,
        filters: filters,
        orderBy: 'modified desc',
        limit: 50,
        limitStart: 0,
      );
    } catch (error) {
      reportError = error;
    }

    if (filters == null && scopedFilters != null) {
      try {
        return await state.frappeService.fetchReportView(
          'NOO Request',
          fields: fields,
          filters: scopedFilters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (_) {
        // Keep the report error from the same filter shape used by the page.
      }
    }

    if (_isFieldShapeError(reportError)) {
      try {
        return await state.frappeService.fetchReportView(
          'NOO Request',
          fields: baseFields,
          filters: filters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (error) {
        reportError = error;
      }
    }

    throw Exception(_nooAccessDiagnostic(state, resourceError, reportError));
  }

  bool _isFieldShapeError(Object? error) {
    final message = error.toString().toLowerCase();
    return message.contains('field') ||
        message.contains('unknown column') ||
        message.contains('status') ||
        message.contains('mobile_no') ||
        message.contains('address_line1') ||
        message.contains('request_date');
  }

  String _nooAccessDiagnostic(
    AppState state,
    Object? resourceError,
    Object? reportError,
  ) {
    final user = state.currentUser?.trim();
    final site = state.selectedSiteName.trim().isNotEmpty
        ? state.selectedSiteName.trim()
        : state.selectedSiteBaseUrl.trim();
    final identity = [
      if (site.isNotEmpty) 'site: $site',
      if (user?.isNotEmpty == true) 'user: $user',
      'role: ${state.userRole}',
      if (state.currentSalesPerson?.trim().isNotEmpty == true)
        'sales person: ${state.currentSalesPerson!.trim()}',
    ].join(', ');

    return 'Gagal membaca NOO Request ($identity). '
        'Pastikan role user punya Read/Create/Write untuk NOO Request dan User terhubung ke Sales Person. '
        'Resource: ${_cleanNooError(resourceError)}. '
        'ReportView: ${_cleanNooError(reportError)}.';
  }

  String _cleanNooError(Object? error) {
    if (error == null) return '-';
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.length > 180 ? '${text.substring(0, 180)}...' : text;
  }

  Widget _loadingCard() {
    return const SalesInfoCard(
      child: SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _emptyCard() {
    final hasFilter = _statusFilter != null;
    return SalesInfoCard(
      child: SizedBox(
        height: 170,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilter
                  ? 'Tidak ada NOO ${_statusFilter!}'
                  : 'Belum ada pengajuan NOO',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilter
                  ? 'Pilih status lain atau reset ke All.'
                  : 'Tekan tombol Buat NOO untuk membuat pengajuan baru.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return SalesInfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal memuat data',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Coba lagi',
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statusFilterChip(label: 'All', value: null),
          ..._statusOptions.map(
            (status) => _statusFilterChip(label: status, value: status),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip({required String label, required String? value}) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _statusFilter = value),
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.softGreen,
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final name = _text(row['name']);
    final customer = _text(row['customer_name'], fallback: name);
    final status = _text(row['status'], fallback: 'Pending Approval');
    final salesPerson = _text(row['sales_person'], fallback: '-');
    final company = _text(row['company'], fallback: '-');
    final date = _formatDate(row['request_date']);
    final mobileNo = _text(row['mobile_no']);
    final customerType = _text(row['customer_type']);
    final customerGroup = _text(row['customer_group']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SalesInfoCard(
        onTap: () => _showDetail(row),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.store_mall_directory_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          customer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$name • $date',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$salesPerson • $company',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (customerType.isNotEmpty ||
                      customerGroup.isNotEmpty ||
                      mobileNo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (customerType.isNotEmpty)
                          _miniBadge(Icons.badge_rounded, customerType),
                        if (customerGroup.isNotEmpty)
                          _miniBadge(Icons.group_work_rounded, customerGroup),
                        if (mobileNo.isNotEmpty)
                          _miniBadge(Icons.phone_rounded, mobileNo),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.slate),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    final isRejected = lower.contains('reject') || lower.contains('cancel');
    final isApproved =
        lower.contains('approved') || lower.contains('created customer');
    final color = isRejected
        ? AppColors.danger
        : (isApproved ? AppColors.success : AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.64,
          minChildSize: 0.36,
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
                  SalesHeroCard(
                    title: _text(row['customer_name'], fallback: '-'),
                    subtitle: _text(row['name']),
                    icon: Icons.store_mall_directory_rounded,
                    trailing: _statusChip(
                      _text(row['status'], fallback: 'Pending Approval'),
                    ),
                  ),
                  SalesUi.gap(),
                  if (_canEdit(row)) ...[
                    FilledButton.icon(
                      onPressed: () => _openEdit(row),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Pengajuan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    SalesUi.gap(),
                  ],
                  SalesInfoCard(
                    child: Column(
                      children: [
                        _detailRow('Tanggal', _formatDate(row['request_date'])),
                        _detailRow('Company', _text(row['company'])),
                        _detailRow('Sales Person', _text(row['sales_person'])),
                        _detailRow(
                          'Customer Type',
                          _text(row['customer_type']),
                        ),
                        _detailRow(
                          'Customer Group',
                          _text(row['customer_group']),
                        ),
                        _detailRow('No. HP', _text(row['mobile_no'])),
                        _detailRow('Alamat Utama', _text(row['address_line1'])),
                      ],
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
              value.isEmpty ? '-' : value,
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

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    final parts = raw.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return raw;
  }

  List<Map<String, dynamic>> _filteredRequests() {
    final status = _statusFilter?.trim().toLowerCase();
    if (status == null || status.isEmpty) return _requests;
    return _requests.where((row) {
      final rowStatus = _text(
        row['status'],
        fallback: 'Pending Approval',
      ).toLowerCase();
      return rowStatus == status;
    }).toList();
  }

  bool _canEdit(Map<String, dynamic> row) {
    final status = _text(
      row['status'],
      fallback: 'Pending Approval',
    ).toLowerCase();
    return status == 'draft' || status == 'pending approval';
  }
}
