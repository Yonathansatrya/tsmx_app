import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'logistics_widgets.dart';

class LogisticsTrackingTab extends StatelessWidget {
  const LogisticsTrackingTab({super.key});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {},
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: logisticsPagePadding,
      children: const [
        LogisticsSectionHeader(
          title: 'Tracking Armada',
          subtitle: 'Alur perjalanan barang dari loading sampai POD',
          icon: Icons.route_rounded,
        ),
        SizedBox(height: 12),
        LogisticsInfoPanel(
          message:
              'Tahap awal sebaiknya mulai dari update status manual. GPS dan monitoring perjalanan dibuat setelah alur status sudah stabil.',
          icon: Icons.info_outline_rounded,
        ),
        SizedBox(height: 16),
        LogisticsActionCard(
          title: 'Status loading barang',
          subtitle: 'Driver atau admin menandai barang mulai dimuat',
          icon: Icons.inventory_2_outlined,
        ),
        LogisticsActionCard(
          title: 'Armada berangkat',
          subtitle: 'Catat jam berangkat dan dokumen pengiriman terkait',
          icon: Icons.local_shipping_outlined,
        ),
        LogisticsActionCard(
          title: 'Monitoring perjalanan',
          subtitle: 'Pantau progress armada selama proses pengiriman',
          icon: Icons.map_outlined,
        ),
        LogisticsActionCard(
          title: 'Status sampai tujuan',
          subtitle: 'Konfirmasi armada tiba di lokasi customer',
          icon: Icons.flag_outlined,
        ),
        LogisticsActionCard(
          title: 'Status bongkar',
          subtitle: 'Catat proses bongkar barang di lokasi tujuan',
          icon: Icons.move_down_outlined,
        ),
        LogisticsActionCard(
          title: 'Foto POD',
          subtitle: 'Upload proof of delivery sebagai attachment',
          icon: Icons.camera_alt_outlined,
          color: AppColors.warning,
        ),
        LogisticsActionCard(
          title: 'GPS Tracking driver',
          subtitle: 'Tracking lokasi driver secara periodik',
          icon: Icons.gps_fixed_rounded,
          color: AppColors.danger,
        ),
      ],
    ),
  );
}
