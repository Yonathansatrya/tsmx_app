import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'inactive_customer_tab.dart';
import 'sales_ui.dart';

class CustomerRequestTab extends StatelessWidget {
  const CustomerRequestTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SalesPillTabBar(
                tabs: const [
                  Tab(text: 'Inactive'),
                  Tab(text: 'NOO'),
                  Tab(text: 'Promo Session'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  InactiveCustomerTab(),
                  _NooRequestTab(),
                  _PromoSessionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NooRequestTab extends StatelessWidget {
  const _NooRequestTab();

  @override
  Widget build(BuildContext context) {
    return _RequestPlaceholderTab(
      title: 'Pengajuan NOO',
      subtitle: 'Ajukan customer baru dari mobile sebelum dibuatkan master.',
      icon: Icons.person_add_alt_1_rounded,
      buttonLabel: 'Buat Pengajuan NOO',
      checklist: const [
        _RequestChecklistItem(
          icon: Icons.store_mall_directory_rounded,
          title: 'Data customer',
          subtitle: 'Nama outlet, group, area, dan alamat utama.',
        ),
        _RequestChecklistItem(
          icon: Icons.badge_rounded,
          title: 'PIC dan kontak',
          subtitle: 'Nama penanggung jawab, nomor telepon, dan email.',
        ),
        _RequestChecklistItem(
          icon: Icons.location_on_rounded,
          title: 'Lokasi customer',
          subtitle: 'Koordinat untuk validasi kunjungan sales.',
        ),
        _RequestChecklistItem(
          icon: Icons.attach_file_rounded,
          title: 'Dokumen pendukung',
          subtitle: 'Foto toko, NPWP/NIK, atau dokumen lain jika tersedia.',
        ),
      ],
    );
  }
}

class _PromoSessionTab extends StatelessWidget {
  const _PromoSessionTab();

  @override
  Widget build(BuildContext context) {
    return _RequestPlaceholderTab(
      title: 'Pengajuan Promo Session',
      subtitle: 'Ajukan promo penjualan untuk periode dan customer tertentu.',
      icon: Icons.local_offer_rounded,
      buttonLabel: 'Buat Pengajuan Promo',
      checklist: const [
        _RequestChecklistItem(
          icon: Icons.storefront_rounded,
          title: 'Customer / area promo',
          subtitle: 'Pilih customer, area, atau channel yang ikut promo.',
        ),
        _RequestChecklistItem(
          icon: Icons.calendar_month_rounded,
          title: 'Periode promo',
          subtitle: 'Tanggal mulai dan selesai promo session.',
        ),
        _RequestChecklistItem(
          icon: Icons.inventory_2_rounded,
          title: 'Item promo',
          subtitle: 'Produk, target quantity, dan aturan promo.',
        ),
        _RequestChecklistItem(
          icon: Icons.payments_rounded,
          title: 'Nilai promo',
          subtitle: 'Diskon, bonus, atau nominal klaim yang diajukan.',
        ),
      ],
    );
  }
}

class _RequestPlaceholderTab extends StatelessWidget {
  const _RequestPlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonLabel,
    required this.checklist,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonLabel;
  final List<_RequestChecklistItem> checklist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SalesUi.compactScreenPadding,
      children: [
        SalesHeroCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Draft UI',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        SalesUi.gap(),
        SalesInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SalesSectionTitle(
                title: 'Data yang dibutuhkan',
                subtitle: 'Form akan disambungkan ke backend tmsx_mobile.',
              ),
              SalesUi.gap(),
              ...checklist,
            ],
          ),
        ),
        SalesUi.gap(),
        FilledButton.icon(
          onPressed: () => _showBackendSnack(context),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(buttonLabel),
        ),
      ],
    );
  }

  void _showBackendSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backend pengajuan belum tersedia. UI sudah disiapkan.'),
      ),
    );
  }
}

class _RequestChecklistItem extends StatelessWidget {
  const _RequestChecklistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
