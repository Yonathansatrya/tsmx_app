import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/approval_request.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

enum _ApprovalFilter { all, sales, buying, stock, other }

class ApprovalCenterScreen extends StatefulWidget {
  const ApprovalCenterScreen({super.key});

  @override
  State<ApprovalCenterScreen> createState() => _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends State<ApprovalCenterScreen> {
  _ApprovalFilter _filter = _ApprovalFilter.all;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshApprovalRequests();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ApprovalRequest> _filtered(List<ApprovalRequest> items) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return items.where((item) {
      final matchSearch =
          query.isEmpty ||
          item.documentName.toLowerCase().contains(query) ||
          item.documentType.toLowerCase().contains(query) ||
          item.workflowState.toLowerCase().contains(query);

      final type = item.documentType.toLowerCase();
      final matchFilter = switch (_filter) {
        _ApprovalFilter.all => true,
        _ApprovalFilter.sales =>
          type.contains('sales') || type.contains('delivery'),
        _ApprovalFilter.buying =>
          type.contains('purchase') || type.contains('material request'),
        _ApprovalFilter.stock => type.contains('stock'),
        _ApprovalFilter.other =>
          !type.contains('sales') &&
              !type.contains('delivery') &&
              !type.contains('purchase') &&
              !type.contains('material request') &&
              !type.contains('stock'),
      };

      return matchSearch && matchFilter;
    }).toList();
  }

  String _filterLabel(_ApprovalFilter filter) {
    return switch (filter) {
      _ApprovalFilter.all => 'All',
      _ApprovalFilter.sales => 'Sales',
      _ApprovalFilter.buying => 'Buying',
      _ApprovalFilter.stock => 'Stock',
      _ApprovalFilter.other => 'Other',
    };
  }

  Color _doctypeColor(String doctype) {
    final value = doctype.toLowerCase();
    if (value.contains('sales') || value.contains('delivery')) {
      return AppColors.primary;
    }
    if (value.contains('purchase') || value.contains('material')) {
      return AppColors.warning;
    }
    if (value.contains('stock')) {
      return AppColors.success;
    }
    return AppColors.slate;
  }

  Future<void> _openActionSheet(ApprovalRequest request) async {
    final actions = {
      if (request.action.trim().isNotEmpty) request.action.trim(),
      'Approve',
      'Reject',
    }.toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  request.documentName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.documentType} - ${request.workflowState.isEmpty ? request.status : request.workflowState}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 16),
                ...actions.map((action) {
                  final destructive = action.toLowerCase().contains('reject');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: destructive
                        ? OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _runAction(request, action);
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: Text(action),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _runAction(request, action);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: Text(action),
                          ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runAction(ApprovalRequest request, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action document?'),
        content: Text('${request.documentType} ${request.documentName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<AppState>().applyApprovalAction(request, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$action berhasil dikirim'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = _filtered(appState.approvalRequests);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Approval Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: appState.isApprovalRequestsLoading
                ? null
                : () => appState.refreshApprovalRequests(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => appState.refreshApprovalRequests(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _ApprovalSummaryCard(
              count: appState.approvalRequests.length,
              isLoading: appState.isApprovalRequestsLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search document or workflow state',
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
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _ApprovalFilter.values.map((filter) {
                  final selected = filter == _filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(filter)),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.softGreen,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (appState.approvalRequestsError != null) ...[
              const SizedBox(height: 12),
              _ApprovalErrorBox(message: appState.approvalRequestsError!),
            ],
            const SizedBox(height: 12),
            if (appState.isApprovalRequestsLoading &&
                appState.approvalRequests.isEmpty)
              const LinearProgressIndicator()
            else if (items.isEmpty)
              const _ApprovalEmptyState()
            else
              ...items.map(
                (item) => _ApprovalCard(
                  item: item,
                  color: _doctypeColor(item.documentType),
                  onTap: () => _openActionSheet(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalSummaryCard extends StatelessWidget {
  final int count;
  final bool isLoading;

  const _ApprovalSummaryCard({required this.count, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.approval_rounded, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Approvals',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoading
                      ? 'Syncing with Frappe...'
                      : 'Workflow Action inbox',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalRequest item;
  final Color color;
  final VoidCallback onTap;

  const _ApprovalCard({
    required this.item,
    required this.color,
    required this.onTap,
  });

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
            border: Border.all(color: color.withValues(alpha: 0.16)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.fact_check_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.documentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.documentType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    if (item.workflowState.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.workflowState,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.action.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.action,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
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

class _ApprovalErrorBox extends StatelessWidget {
  final String message;

  const _ApprovalErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.16)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ApprovalEmptyState extends StatelessWidget {
  const _ApprovalEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 52, color: AppColors.slate),
          SizedBox(height: 12),
          Text(
            'No pending approvals',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Workflow actions assigned in Frappe will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
