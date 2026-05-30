import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/delivery_trip.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_summary_card.dart';

class DeliveryTripPanel extends StatefulWidget {
  const DeliveryTripPanel({super.key});

  @override
  State<DeliveryTripPanel> createState() => _DeliveryTripPanelState();
}

class _DeliveryTripPanelState extends State<DeliveryTripPanel> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.deliveryTrips.isEmpty) {
        appState.refreshDeliveryTrips();
      }
    });
  }

  List<DeliveryTrip> _filter(List<DeliveryTrip> trips) {
    final q = _search.toLowerCase();
    return trips.where((t) {
      final matchSearch =
          q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.reference.toLowerCase().contains(q) ||
          t.statusText.toLowerCase().contains(q);
      return matchSearch;
    }).toList();
  }

  void _openDetail(DeliveryTrip trip) {
    showErpDetailSheet(
      context: context,
      title: trip.id,
      subtitle: trip.reference.isEmpty ? 'Delivery trip' : trip.reference,
      statusText: trip.statusText,
      rows: [
        ErpDetailRow(label: 'Date', value: trip.date.isEmpty ? '—' : trip.date),
        ErpDetailRow(
          label: 'Distance',
          value: '${trip.totalDistance.toStringAsFixed(1)} km',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.deliveryTrips);
    final totalDistance = filtered.fold<double>(
      0,
      (sum, trip) => sum + trip.totalDistance,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Delivery Trips',
          valueLabel: 'km',
          totalValue: totalDistance,
          documentCount: filtered.length,
          isLoading: appState.isDeliveryTripsLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search trip or reference�',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
          ),
        ),
        if (appState.deliveryTripsError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.deliveryTripsError!),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isDeliveryTripsLoading)
          const ErpEmptyState(title: 'No delivery trips found')
        else
          ...filtered.map(
            (trip) => ErpDocumentCard(
              id: trip.id,
              party: trip.reference.isEmpty ? 'Delivery trip' : trip.reference,
              statusText: trip.statusText,
              date: trip.date,
              value: trip.totalDistance,
              onTap: () => _openDetail(trip),
            ),
          ),
      ],
    );
  }
}
