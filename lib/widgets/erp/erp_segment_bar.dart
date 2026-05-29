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
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = options[index];
          final selected = opt.id == selectedId;

          return GestureDetector(
            onTap: () => onSelected(opt.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
                ),
              ),
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.white : AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
