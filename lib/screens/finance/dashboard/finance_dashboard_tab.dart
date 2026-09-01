part of '../finance_main_screen.dart';

class _DashboardView extends StatelessWidget {
  final FinanceDashboardData data;

  const _DashboardView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData(
              'Cash Flow',
              data.netCashFlow,
              Icons.waterfall_chart,
              color: _financeGreen,
              onTap: () => _showDocumentRows(
                context,
                title: 'Cash Flow Monitoring',
                rows: data.cashFlowEntries,
                emptyTitle: 'Belum ada Payment Entry',
              ),
            ),
            _MetricData(
              'Bank',
              data.bankBalance,
              Icons.account_balance,
              color: _financeBlue,
              onTap: () => _showBankBalances(context, data.bankBalances),
            ),
            _MetricData(
              'Collection',
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
            _MetricData(
              'Expense',
              data.expenseTotal,
              Icons.trending_down,
              color: _financeOrange,
              onTap: () => _showDocumentRows(
                context,
                title: 'Expense Monitoring',
                rows: data.expenseEntries,
                emptyTitle: 'Belum ada expense',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TrendCard(
          title: 'Cash Flow Monitoring',
          points: data.cashFlowTrend,
          onTap: () => _showTrendDetails(
            context,
            title: 'Cash Flow Monitoring',
            points: data.cashFlowTrend,
            reportRows: data.cashFlowMetrics,
          ),
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          metrics: [
            _MetricData(
              'Outstanding AR',
              data.outstandingAr,
              Icons.call_received,
              color: _financeBlue,
              onTap: () => _showDocumentRows(
                context,
                title: 'Outstanding AR',
                rows: data.arInvoices,
                emptyTitle: 'Tidak ada AR outstanding',
              ),
            ),
            _MetricData(
              'Outstanding AP',
              data.outstandingAp,
              Icons.call_made,
              color: _financeOrange,
              onTap: () => _showDocumentRows(
                context,
                title: 'Outstanding AP',
                rows: data.apInvoices,
                emptyTitle: 'Tidak ada AP outstanding',
              ),
            ),
            _MetricData(
              'Journal Approval',
              data.pendingJournalCount.toDouble(),
              Icons.approval,
              color: _financePurple,
              currency: false,
              onTap: () => _showDocumentRows(
                context,
                title: 'Journal Entry Approval',
                rows: data.journalEntries,
                emptyTitle: 'Tidak ada Journal Entry pending',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
