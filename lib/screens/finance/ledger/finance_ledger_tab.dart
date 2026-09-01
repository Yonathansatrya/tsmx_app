part of '../finance_main_screen.dart';

class _AccountingView extends StatelessWidget {
  final FinanceDashboardData data;

  const _AccountingView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          title: 'Journal Entry Approval',
          icon: Icons.approval_rounded,
          color: _financePurple,
          child: data.journalEntries.isEmpty
              ? const ErpEmptyState(
                  title: 'Tidak ada Journal Entry pending',
                  message: 'Draft journal akan muncul di sini untuk dicek.',
                )
              : Column(
                  children: [
                    for (final row in data.journalEntries.take(6))
                      _DocumentRow(row: row, doctype: 'Journal Entry'),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Journal Entry Monitoring',
          icon: Icons.receipt_long_rounded,
          color: _financeCyan,
          child: data.recentJournalEntries.isEmpty
              ? const ErpEmptyState(
                  title: 'Belum ada Journal Entry',
                  message: 'Journal periode ini belum tersedia.',
                )
              : Column(
                  children: [
                    for (final row in data.recentJournalEntries.take(8))
                      _DocumentRow(row: row, doctype: 'Journal Entry'),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _ReportSection(title: 'Profit & Loss', rows: data.profitLoss),
        const SizedBox(height: 12),
        _ReportSection(title: 'Balance Sheet', rows: data.balanceSheet),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'General Ledger Monitoring',
          icon: Icons.auto_stories_rounded,
          color: _financeBlue,
          child: data.ledgerRows.isEmpty
              ? const ErpEmptyState(
                  title: 'Belum ada mutasi ledger',
                  message: 'GL Entry periode ini belum tersedia.',
                )
              : Column(
                  children: [
                    for (final row in data.ledgerRows.take(10))
                      _LedgerRow(row: row),
                  ],
                ),
        ),
      ],
    );
  }
}
