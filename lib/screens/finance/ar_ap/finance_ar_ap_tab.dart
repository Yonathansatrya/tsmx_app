part of '../finance_main_screen.dart';

class _ReceivablePayableView extends StatelessWidget {
  final FinanceDashboardData data;

  const _ReceivablePayableView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData(
              'Outstanding AR',
              data.outstandingAr,
              Icons.groups,
              color: _financeBlue,
            ),
            _MetricData(
              'Outstanding AP',
              data.outstandingAp,
              Icons.storefront,
              color: _financeOrange,
            ),
            _MetricData(
              'Daily Collection',
              data.dailyCollection,
              Icons.payments,
              color: _financeCyan,
              onTap: () => _showDocumentRows(
                context,
                title: 'Daily Collection',
                rows: data.collectionEntries,
                emptyTitle: 'Belum ada collection',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Outstanding AR/AP',
          icon: Icons.receipt_long_rounded,
          color: _financeBlue,
          child: Column(
            children: [
              _AmountRow(
                label: 'Sales Invoice belum lunas',
                amount: data.outstandingAr,
                onTap: () => _showDocumentRows(
                  context,
                  title: 'Sales Invoice Outstanding',
                  rows: data.arInvoices,
                  emptyTitle: 'Tidak ada AR outstanding',
                ),
              ),
              _AmountRow(
                label: 'Purchase Invoice belum lunas',
                amount: data.outstandingAp,
                onTap: () => _showDocumentRows(
                  context,
                  title: 'Purchase Invoice Outstanding',
                  rows: data.apInvoices,
                  emptyTitle: 'Tidak ada AP outstanding',
                ),
              ),
              _AmountRow(
                label: 'Selisih AR - AP',
                amount: data.outstandingAr - data.outstandingAp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
