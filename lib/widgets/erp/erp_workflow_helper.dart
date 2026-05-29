import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_doc_utils.dart';
import 'erp_detail_sheet.dart';

Future<bool> runErpWorkflowAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
}) async {
  try {
    await action();
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }
}

Future<bool> confirmErpAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ],
    ),
  );
  return ok == true;
}

Widget erpActionButton({
  required String label,
  required IconData icon,
  required VoidCallback? onPressed,
  bool filled = false,
}) {
  final child = filled
      ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label))
      : OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
  return SizedBox(width: double.infinity, child: child);
}

Widget erpWorkflowSection({required String title, required List<Widget> children}) {
  if (children.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.slate,
        ),
      ),
      const SizedBox(height: 8),
      ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
    ],
  );
}

List<Widget> erpRelatedDocChips({
  required List<String> docIds,
  required void Function(String id) onTap,
}) {
  if (docIds.isEmpty) return [];
  return [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: docIds.map((id) {
        return ActionChip(
          label: Text(id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          onPressed: () => onTap(id),
        );
      }).toList(),
    ),
  ];
}

ErpDetailRow docStatusRow(int docStatus) =>
    ErpDetailRow(label: 'Doc Status', value: docStatusLabel(docStatus));
