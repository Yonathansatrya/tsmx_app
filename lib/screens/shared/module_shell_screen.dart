import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ModuleShellScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const ModuleShellScreen({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: child,
    );
  }
}
