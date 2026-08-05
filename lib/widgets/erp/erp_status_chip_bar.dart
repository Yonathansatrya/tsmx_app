import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ErpStatusChipBar<T> extends StatelessWidget {
  final List<ErpStatusChip<T>> chips;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const ErpStatusChipBar({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = selected == chip.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: _StatusChipLabel(
                label: chip.label,
                count: chip.count,
                selected: isSelected,
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(chip.value),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isSelected ? AppColors.white : AppColors.primary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.softGreen,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ErpStatusChip<T> {
  final String label;
  final T? value;
  final int? count;

  const ErpStatusChip({required this.label, this.value, this.count});
}

class _StatusChipLabel extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;

  const _StatusChipLabel({
    required this.label,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final badgeCount = count;
    if (badgeCount == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.white.withValues(alpha: 0.18)
                : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            '$badgeCount',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
