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
              label: Text(chip.label),
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

  const ErpStatusChip({required this.label, this.value});
}
