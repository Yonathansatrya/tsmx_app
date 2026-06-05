import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/journal_entry.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/erp_doc_utils.dart';
import '../utils/erp_format.dart';
import '../widgets/erp/erp_detail_sheet.dart';
import '../widgets/erp/erp_empty_state.dart';
import '../widgets/erp/erp_error_box.dart';
import '../widgets/erp/erp_status_badge.dart';
import '../widgets/erp/erp_workflow_helper.dart';

enum _JournalDateFilter { all, today, last7Days, monthToDate, last30Days }

enum _JournalStatusFilter { all, draft, submitted, cancelled }

enum _JournalSort { newest, oldest, debitHigh, creditHigh }

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _searchCtrl = TextEditingController();
  _JournalDateFilter _dateFilter = _JournalDateFilter.all;
  _JournalStatusFilter _statusFilter = _JournalStatusFilter.all;
  _JournalSort _sort = _JournalSort.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshJournalEntries();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<JournalEntry> _filtered(List<JournalEntry> entries) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = entries.where((entry) {
      final matchSearch =
          query.isEmpty ||
          entry.id.toLowerCase().contains(query) ||
          entry.voucherType.toLowerCase().contains(query) ||
          entry.company.toLowerCase().contains(query) ||
          entry.title.toLowerCase().contains(query);

      final matchStatus = switch (_statusFilter) {
        _JournalStatusFilter.all => true,
        _JournalStatusFilter.draft => isDocDraft(entry.docStatus),
        _JournalStatusFilter.submitted => isDocSubmitted(entry.docStatus),
        _JournalStatusFilter.cancelled => isDocCancelled(entry.docStatus),
      };

      final postingDate = DateTime.tryParse(entry.postingDate);
      final matchDate = switch (_dateFilter) {
        _JournalDateFilter.all => true,
        _JournalDateFilter.today =>
          postingDate != null &&
              DateTime(postingDate.year, postingDate.month, postingDate.day) ==
                  today,
        _JournalDateFilter.last7Days =>
          postingDate != null &&
              !postingDate.isBefore(today.subtract(const Duration(days: 6))),
        _JournalDateFilter.monthToDate =>
          postingDate != null &&
              postingDate.year == now.year &&
              postingDate.month == now.month,
        _JournalDateFilter.last30Days =>
          postingDate != null &&
              !postingDate.isBefore(today.subtract(const Duration(days: 29))),
      };

      return matchSearch && matchStatus && matchDate;
    }).toList();

    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a.postingDate);
      final bDate = DateTime.tryParse(b.postingDate);
      return switch (_sort) {
        _JournalSort.newest => (bDate ?? DateTime(0)).compareTo(
          aDate ?? DateTime(0),
        ),
        _JournalSort.oldest => (aDate ?? DateTime(0)).compareTo(
          bDate ?? DateTime(0),
        ),
        _JournalSort.debitHigh => b.totalDebit.compareTo(a.totalDebit),
        _JournalSort.creditHigh => b.totalCredit.compareTo(a.totalCredit),
      };
    });

    return filtered;
  }

  String _dateLabel(_JournalDateFilter filter) {
    return switch (filter) {
      _JournalDateFilter.all => 'All Dates',
      _JournalDateFilter.today => 'Today',
      _JournalDateFilter.last7Days => '7 Days',
      _JournalDateFilter.monthToDate => 'MTD',
      _JournalDateFilter.last30Days => '30 Days',
    };
  }

  String _statusLabel(_JournalStatusFilter filter) {
    return switch (filter) {
      _JournalStatusFilter.all => 'All',
      _JournalStatusFilter.draft => 'Draft',
      _JournalStatusFilter.submitted => 'Submitted',
      _JournalStatusFilter.cancelled => 'Cancelled',
    };
  }

  String _sortLabel(_JournalSort sort) {
    return switch (sort) {
      _JournalSort.newest => 'Newest',
      _JournalSort.oldest => 'Oldest',
      _JournalSort.debitHigh => 'Debit High',
      _JournalSort.creditHigh => 'Credit High',
    };
  }

  Future<void> _openDetail(JournalEntry entry) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    JournalEntry detail;
    try {
      detail = await context.read<AppState>().loadJournalEntryDetail(entry.id);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final rows = <ErpDetailRow>[
      ErpDetailRow(label: 'Voucher', value: detail.voucherType),
      ErpDetailRow(label: 'Company', value: detail.company),
      ErpDetailRow(label: 'Posting', value: detail.postingDate),
      ErpDetailRow(
        label: 'Total Debit',
        value: 'Rp ${formatErpCurrency(detail.totalDebit)}',
      ),
      ErpDetailRow(
        label: 'Total Credit',
        value: 'Rp ${formatErpCurrency(detail.totalCredit)}',
      ),
      ErpDetailRow(
        label: 'Difference',
        value: 'Rp ${formatErpCurrency(detail.difference)}',
      ),
      docStatusRow(detail.docStatus),
      if (detail.remark.trim().isNotEmpty)
        ErpDetailRow(label: 'Remark', value: detail.remark.trim()),
      ..._accountRows(detail.accounts),
    ];

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.title.isEmpty ? detail.voucherType : detail.title,
      statusText: detail.statusText,
      rows: rows,
      footer: _JournalFooter(entry: detail, onChanged: () => setState(() {})),
    );
  }

  List<ErpDetailRow> _accountRows(List<JournalEntryAccount> accounts) {
    if (accounts.isEmpty) {
      return const [ErpDetailRow(label: 'Accounts', value: 'No account rows')];
    }

    return accounts.take(12).map((account) {
      final side = account.debit > 0
          ? 'Dr Rp ${formatErpCurrency(account.debit)}'
          : 'Cr Rp ${formatErpCurrency(account.credit)}';
      final party = account.party.isEmpty ? '' : ' - ${account.party}';
      return ErpDetailRow(
        label: account.account.isEmpty ? 'Account' : account.account,
        value: '$side$party',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = _filtered(appState.journalEntries);
    final totalDebit = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalDebit,
    );
    final totalCredit = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalCredit,
    );
    final difference = totalDebit - totalCredit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Journal Entries'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: appState.isJournalEntriesLoading
                ? null
                : () => appState.refreshJournalEntries(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => appState.refreshJournalEntries(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _JournalSummaryCard(
              count: entries.length,
              debit: totalDebit,
              credit: totalCredit,
              difference: difference,
              isLoading: appState.isJournalEntriesLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search journal, voucher, company',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            _FilterStrip(
              dateFilter: _dateFilter,
              statusFilter: _statusFilter,
              sort: _sort,
              dateLabel: _dateLabel,
              statusLabel: _statusLabel,
              sortLabel: _sortLabel,
              onDateChanged: (value) => setState(() => _dateFilter = value),
              onStatusChanged: (value) => setState(() => _statusFilter = value),
              onSortChanged: (value) => setState(() => _sort = value),
            ),
            if (appState.journalEntriesError != null) ...[
              const SizedBox(height: 12),
              ErpErrorBox(message: appState.journalEntriesError!),
            ],
            const SizedBox(height: 12),
            if (appState.isJournalEntriesLoading &&
                appState.journalEntries.isEmpty)
              const LinearProgressIndicator()
            else if (entries.isEmpty)
              const ErpEmptyState(
                title: 'No journal entries',
                message: 'Try another filter or pull down to refresh.',
              )
            else
              ...entries.map((entry) {
                return _JournalEntryCard(
                  entry: entry,
                  onTap: () => _openDetail(entry),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _JournalFooter extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onChanged;

  const _JournalFooter({required this.entry, required this.onChanged});

  Future<void> _submit(BuildContext context) async {
    final ok = await confirmErpAction(
      context,
      title: 'Submit journal?',
      message: 'Submit Journal Entry ${entry.id}?',
    );
    if (!ok || !context.mounted) return;
    final success = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Journal Entry', entry.id),
      successMessage: 'Journal Entry submitted',
    );
    if (success && context.mounted) {
      Navigator.pop(context);
      onChanged();
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await confirmErpAction(
      context,
      title: 'Cancel journal?',
      message: 'Cancel Journal Entry ${entry.id}?',
    );
    if (!ok || !context.mounted) return;
    final success = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().cancelDocument('Journal Entry', entry.id),
      successMessage: 'Journal Entry cancelled',
    );
    if (success && context.mounted) {
      Navigator.pop(context);
      onChanged();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmErpAction(
      context,
      title: 'Delete journal?',
      message: 'Delete draft Journal Entry ${entry.id}?',
    );
    if (!ok || !context.mounted) return;
    final success = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().deleteJournalEntry(entry.id),
      successMessage: 'Journal Entry deleted',
    );
    if (success && context.mounted) {
      Navigator.pop(context);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDocCancelled(entry.docStatus)) {
      return const _ReadOnlyNotice(message: 'Cancelled journal is read-only.');
    }

    if (isDocSubmitted(entry.docStatus)) {
      return Column(
        children: [
          erpActionButton(
            label: 'Cancel',
            icon: Icons.cancel_rounded,
            onPressed: () => _cancel(context),
          ),
        ],
      );
    }

    return Column(
      children: [
        erpActionButton(
          label: 'Submit',
          icon: Icons.check_circle_rounded,
          filled: true,
          onPressed: () => _submit(context),
        ),
        const SizedBox(height: 8),
        erpActionButton(
          label: 'Delete Draft',
          icon: Icons.delete_outline_rounded,
          onPressed: () => _delete(context),
        ),
      ],
    );
  }
}

class _JournalSummaryCard extends StatelessWidget {
  final int count;
  final double debit;
  final double credit;
  final double difference;
  final bool isLoading;

  const _JournalSummaryCard({
    required this.count,
    required this.debit,
    required this.credit,
    required this.difference,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General Ledger Journals',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading ? 'Syncing with Frappe...' : '$count entries',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'Debit', value: debit),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(label: 'Credit', value: credit),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryMetric(label: 'Difference', value: difference),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final double value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${formatErpCurrency(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  final _JournalDateFilter dateFilter;
  final _JournalStatusFilter statusFilter;
  final _JournalSort sort;
  final String Function(_JournalDateFilter filter) dateLabel;
  final String Function(_JournalStatusFilter filter) statusLabel;
  final String Function(_JournalSort sort) sortLabel;
  final ValueChanged<_JournalDateFilter> onDateChanged;
  final ValueChanged<_JournalStatusFilter> onStatusChanged;
  final ValueChanged<_JournalSort> onSortChanged;

  const _FilterStrip({
    required this.dateFilter,
    required this.statusFilter,
    required this.sort,
    required this.dateLabel,
    required this.statusLabel,
    required this.sortLabel,
    required this.onDateChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterMenu<_JournalDateFilter>(
            icon: Icons.date_range_rounded,
            label: dateLabel(dateFilter),
            value: dateFilter,
            values: _JournalDateFilter.values,
            itemLabel: dateLabel,
            onChanged: onDateChanged,
          ),
          _FilterMenu<_JournalStatusFilter>(
            icon: Icons.fact_check_outlined,
            label: statusLabel(statusFilter),
            value: statusFilter,
            values: _JournalStatusFilter.values,
            itemLabel: statusLabel,
            onChanged: onStatusChanged,
          ),
          _FilterMenu<_JournalSort>(
            icon: Icons.sort_rounded,
            label: sortLabel(sort),
            value: sort,
            values: _JournalSort.values,
            itemLabel: sortLabel,
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (_) => values
            .map(
              (item) =>
                  PopupMenuItem<T>(value: item, child: Text(itemLabel(item))),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;

  const _JournalEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  ErpStatusBadge(statusText: entry.statusText),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  entry.voucherType,
                  if (entry.company.isNotEmpty) entry.company,
                ].join(' - '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CardMetric(
                      label: 'Debit',
                      value: 'Rp ${formatErpCurrency(entry.totalDebit)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CardMetric(
                      label: 'Credit',
                      value: 'Rp ${formatErpCurrency(entry.totalCredit)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CardMetric(
                      label: 'Posting',
                      value: entry.postingDate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.slate,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  final String message;

  const _ReadOnlyNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.slate,
        ),
      ),
    );
  }
}
