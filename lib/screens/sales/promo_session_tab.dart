import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'sales_ui.dart';

class PromoSessionTab extends StatelessWidget {
  const PromoSessionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: SalesUi.compactScreenPadding,
          children: [
            SalesHeroCard(
              title: 'Pengajuan Promo Session',
              subtitle:
                  'Ajukan promo harga atau diskon sebelum dibuat menjadi Promotional Scheme.',
              icon: Icons.local_offer_rounded,
            ),
            SalesUi.gap(),
            _flowCard(),
            SalesUi.gap(),
            _requiredDataCard(),
            SalesUi.gap(),
            _integrationCard(),
            const SizedBox(height: 84),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create-promo-session',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            onPressed: () => _showUnavailableMessage(context),
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

  Widget _flowCard() {
    return SalesInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SalesSectionTitle(
            title: 'Alur Pengajuan',
            subtitle: 'Ringkas, jelas, dan siap dipakai sales',
          ),
          const SizedBox(height: 14),
          _stepTile(
            number: '1',
            title: 'Pilih customer dan item',
            subtitle: 'Promo dapat diarahkan ke customer atau customer group.',
          ),
          _stepTile(
            number: '2',
            title: 'Isi periode dan nilai promo',
            subtitle: 'Masukkan tanggal aktif, harga promo, atau diskon item.',
          ),
          _stepTile(
            number: '3',
            title: 'Approval sebelum aktif',
            subtitle:
                'Promo yang disetujui akan menjadi Promotional Scheme ERPNext.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _requiredDataCard() {
    final fields = const [
      (Icons.storefront_rounded, 'Customer / Group'),
      (Icons.inventory_2_rounded, 'Item & UOM'),
      (Icons.price_change_rounded, 'Harga normal'),
      (Icons.discount_rounded, 'Diskon / Harga promo'),
      (Icons.date_range_rounded, 'Periode aktif'),
      (Icons.attach_file_rounded, 'Lampiran surat'),
    ];

    return SalesInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SalesSectionTitle(
            title: 'Data yang Disiapkan',
            subtitle: 'Field utama untuk pengajuan promo',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: fields
                .map((field) => _dataChip(icon: field.$1, label: field.$2))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _integrationCard() {
    return SalesInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SalesSectionTitle(
            title: 'Status Integrasi',
            subtitle: 'Disiapkan agar mengikuti ERPNext',
          ),
          const SizedBox(height: 12),
          _statusRow(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            text:
                'Membaca customer, item, company, dan price list dari site aktif.',
          ),
          const SizedBox(height: 10),
          _statusRow(
            icon: Icons.pending_actions_rounded,
            color: AppColors.warning,
            text:
                'Submit pengajuan dan approval promo masih menunggu DocType final.',
          ),
        ],
      ),
    );
  }

  Widget _stepTile({
    required String number,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dataChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _showUnavailableMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form Promo Session belum aktif untuk site ini.'),
      ),
    );
  }
}
