import 'package:flutter/material.dart';

class ErpErrorBox extends StatelessWidget {
  final String message;

  const ErpErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.red,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
