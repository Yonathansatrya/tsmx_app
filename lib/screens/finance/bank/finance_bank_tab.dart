part of '../finance_main_screen.dart';

class _CashBankView extends StatelessWidget {
  final FinanceDashboardData data;

  const _CashBankView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData(
              'Cash In',
              data.cashIn,
              Icons.south_west_rounded,
              color: _financeGreen,
              onTap: () => _showDocumentRows(
                context,
                title: 'Cash In',
                rows: data.cashFlowEntries
                    .where((row) => row.status == 'Receive')
                    .toList(),
                emptyTitle: 'Belum ada cash in',
              ),
            ),
            _MetricData(
              'Cash Out',
              data.cashOut,
              Icons.north_east_rounded,
              color: _financeOrange,
              onTap: () => _showDocumentRows(
                context,
                title: 'Cash Out',
                rows: data.cashFlowEntries
                    .where((row) => row.status == 'Pay')
                    .toList(),
                emptyTitle: 'Belum ada cash out',
              ),
            ),
            _MetricData(
              'Net Flow',
              data.netCashFlow,
              Icons.swap_vert_rounded,
              color: _financeCyan,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Bank Balance Monitoring',
          icon: Icons.account_balance_rounded,
          color: _financeBlue,
          child: data.bankBalances.isEmpty
              ? const ErpEmptyState(
                  title: 'Belum ada rekening bank',
                  message: 'Saldo dihitung dari GL Entry akun bertipe Bank.',
                )
              : Column(
                  children: [
                    for (final bank in data.bankBalances.take(8))
                      _AmountRow(
                        label: bank.account,
                        amount: bank.balance,
                        onTap: () => _showBankBalance(context, bank),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
