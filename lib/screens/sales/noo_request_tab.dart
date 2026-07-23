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

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final filters = <List<dynamic>>[];
      if (state.isSalesUserRole) {
        final salesPerson = state.currentSalesPerson?.trim() ?? '';
        if (salesPerson.isNotEmpty) {
          filters.add(['sales_person', '=', salesPerson]);
        }
      }
      final rows = await state.frappeService.fetchResource(
        'NOO Request',
        fields: const [
          'name',
          'request_date',
          'company',
          'sales_person',
          'customer_name',
          'customer_type',
          'customer_group',
          'territory',
          'mobile_no',
          'status',
          'modified',
        ],
        filters: filters.isEmpty ? null : filters,
        orderBy: 'modified desc',
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
            const Text(
              'Belum ada pengajuan NOO',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tekan tombol Buat NOO untuk membuat pengajuan baru.',
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
    final customer = _text(row['customer_name'], fallback: name);
    final status = _text(row['status'], fallback: 'Pending Approval');
    final salesPerson = _text(row['sales_person'], fallback: '-');
    final company = _text(row['company'], fallback: '-');
    final date = _formatDate(row['request_date']);
    final territory = _text(row['territory']);
    final mobileNo = _text(row['mobile_no']);

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
                  if (territory.isNotEmpty || mobileNo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (territory.isNotEmpty)
                          _miniBadge(Icons.map_rounded, territory),
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
          initialChildSize: 0.56,
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
                        _detailRow('Territory', _text(row['territory'])),
                        _detailRow('No. HP', _text(row['mobile_no'])),
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
}
