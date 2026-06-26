import 'package:flutter/material.dart';

import '../../config/mobile_role_registry.dart';
import '../../theme/app_colors.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  final String moduleKey;

  const ModulePlaceholderScreen({super.key, required this.moduleKey});

  @override
  Widget build(BuildContext context) {
    final meta = MobileRoleRegistry.metaFor(moduleKey);
    final title = meta?.defaultLabel ?? moduleKey;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                meta?.icon ?? Icons.hourglass_empty_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meta?.defaultSubtitle ??
                    'Modul ini akan tersedia pada rilis berikutnya.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Roadmap',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
