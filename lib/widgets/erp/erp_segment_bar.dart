import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ErpSegmentOption {
  final String id;
  final String label;

  const ErpSegmentOption({required this.id, required this.label});
}

class ErpSegmentBar extends StatelessWidget {
  final List<ErpSegmentOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const ErpSegmentBar({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.id == selectedId;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(option.id),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected ? AppColors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
