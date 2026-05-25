import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class DashboardOrderRow extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final String status;

  const DashboardOrderRow({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OrderInfo(
              label: label,
              subtitle: subtitle,
            ),
          ),
          _OrderValue(
            value: value,
            status: status,
          ),
        ],
      ),
    );
  }
}

class _OrderInfo extends StatelessWidget {
  final String label;
  final String subtitle;

  const _OrderInfo({
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }
}

class _OrderValue extends StatelessWidget {
  final String value;
  final String status;

  const _OrderValue({
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase().replaceAll('_', ' '),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}