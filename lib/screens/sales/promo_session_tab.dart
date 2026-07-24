import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'create_promo_request_screen.dart';
import 'sales_ui.dart';

class PromoSessionTab extends StatefulWidget {
  const PromoSessionTab({super.key});

  @override
  State<PromoSessionTab> createState() => _PromoSessionTabState();
}

class _PromoSessionTabState extends State<PromoSessionTab> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView(
            padding: SalesUi.compactScreenPadding,
            children: [
              SalesHeroCard(
                title: 'Pengajuan Promo Session',
                subtitle:
                    'Pantau promo sebelum diproses menjadi Promotional Scheme.',
                icon: Icons.local_offer_rounded,
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
              if (_error != null)
                _errorCard(_error!)
              else if (_isLoading)
                _loadingCard()
              else if (_requests.isEmpty)
                _emptyCard()
              else
                ..._requests.map(_requestCard),
              const SizedBox(height: 84),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create-promo-session',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Buat Promo',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePromoRequestScreen()),
    );
    if (created != true || !mounted) return;
    await _loadRequests();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengajuan promo berhasil dikirim.')),
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
      final filters = <List<dynamic>>[];
      final salesPerson =
          (state.currentSalesPerson ??
                  await state.resolveCurrentSalesIdentity())
              ?.trim() ??
          '';
      if (state.isSalesUserRole && salesPerson.isNotEmpty) {
        filters.add(['sales_person', '=', salesPerson]);
      }
      final rows = await _fetchPromoRequests(
        state,
        filters: filters.isEmpty ? null : filters,
        scopedFilters: salesPerson.isEmpty
            ? null
            : [
                ['sales_person', '=', salesPerson],
              ],
        fields: const [
          'name',
          'request_date',
          'company',
          'sales_person',
          'customer_group',
          'customer',
          'valid_from',
          'valid_upto',
          'status',
          'promo_note',
          'modified',
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

  Future<List<Map<String, dynamic>>> _fetchPromoRequests(
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
      'customer_group',
      'customer',
      'valid_from',
      'valid_upto',
      'modified',
    ];

    try {
      return await state.frappeService.fetchResource(
        'Promo Request',
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
          'Promo Request',
          fields: fields,
          filters: scopedFilters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (_) {
        // Keep the original unscoped error for diagnostics below.
      }
    }

    if (_isFieldShapeError(resourceError)) {
      try {
        return await state.frappeService.fetchResource(
          'Promo Request',
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

    if (!state.isSalesUserRole) {
      try {
        return await state.frappeService.fetchReportView(
          'Promo Request',
          fields: fields,
          filters: filters,
          orderBy: 'modified desc',
          limit: 50,
          limitStart: 0,
        );
      } catch (error) {
        reportError = error;
      }
    }

    if (!state.isSalesUserRole && _isFieldShapeError(reportError)) {
      try {
        return await state.frappeService.fetchReportView(
          'Promo Request',
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

    throw Exception(_promoAccessDiagnostic(state, resourceError, reportError));
  }

  String _promoAccessDiagnostic(
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

    return 'Gagal membaca Promo Request ($identity). '
        'Pastikan DocType Promo Request sudah migrate di site aktif, role user punya Read/Create/Write, dan User terhubung ke Sales Person. '
        'Resource: ${_cleanPromoError(resourceError)}. '
        'ReportView: ${_cleanPromoError(reportError)}.';
  }

  bool _isFieldShapeError(Object? error) {
    final message = error.toString().toLowerCase();
    return message.contains('field') ||
        message.contains('unknown column') ||
        message.contains('status') ||
        message.contains('promo_note') ||
        message.contains('valid_upto') ||
        message.contains('request_date');
  }

  String _cleanPromoError(Object? error) {
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
    return SalesInfoCard(
      child: SizedBox(
        height: 170,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EmptyIcon(),
            SizedBox(height: 14),
            Text(
              'Belum ada pengajuan promo',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tekan tombol Buat Promo untuk membuat pengajuan baru.',
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

  Widget _requestCard(Map<String, dynamic> row) {
    final name = _text(row['name']);
    final status = _text(row['status'], fallback: 'Pending Approval');
    final salesPerson = _text(row['sales_person'], fallback: '-');
    final company = _text(row['company'], fallback: '-');
    final target = _target(row, fallback: name);
    final period =
        '${_formatDate(row['valid_from'])} s/d ${_formatDate(row['valid_upto'])}';
    final note = _text(row['promo_note']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SalesInfoCard(
        onTap: () => _showDetail(row),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _miniChip(Icons.date_range_rounded, period),
                      _miniChip(Icons.business_rounded, company),
                      _miniChip(Icons.person_rounded, salesPerson),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(status),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
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
    final normalized = status.toLowerCase();
    final isRejected =
        normalized.contains('reject') || normalized.contains('cancel');
    final isApproved =
        normalized.contains('approve') || normalized.contains('submit');
    final color = isRejected
        ? AppColors.danger
        : isApproved
        ? AppColors.success
        : AppColors.warning;
    final bg = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final name = _text(row['name']);
        final status = _text(row['status'], fallback: 'Pending Approval');
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SalesHeroCard(
                    title: _target(row, fallback: name),
                    subtitle: name,
                    icon: Icons.local_offer_rounded,
                    trailing: _statusChip(status),
                  ),
                  SalesUi.gap(),
                  SalesInfoCard(
                    child: Column(
                      children: [
                        _detailRow('Tanggal', _formatDate(row['request_date'])),
                        _detailRow(
                          'Periode',
                          '${_formatDate(row['valid_from'])} s/d ${_formatDate(row['valid_upto'])}',
                        ),
                        _detailRow('Company', _text(row['company'])),
                        _detailRow('Sales Person', _text(row['sales_person'])),
                        _detailRow(
                          'Customer Group',
                          _text(row['customer_group'], fallback: '-'),
                        ),
                        _detailRow(
                          'Customer',
                          _text(row['customer'], fallback: '-'),
                        ),
                        _detailRow(
                          'Catatan',
                          _text(row['promo_note'], fallback: '-'),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: isLast ? 12 : 0),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppColors.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
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
              value,
              textAlign: TextAlign.right,
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
  }

  String _target(Map<String, dynamic> row, {required String fallback}) {
    final customer = _text(row['customer']);
    if (customer.isNotEmpty) return customer;
    final customerGroup = _text(row['customer_group']);
    if (customerGroup.isNotEmpty) return customerGroup;
    return fallback;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
    );
  }
}
