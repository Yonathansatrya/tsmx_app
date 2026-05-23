import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class BadgeScannerDialog extends StatefulWidget {
  const BadgeScannerDialog({super.key});

  @override
  State<BadgeScannerDialog> createState() => _BadgeScannerDialogState();
}

class _BadgeScannerDialogState extends State<BadgeScannerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String _statusText = 'Align employee badge behind device...';
  bool _isSuccess = false;

  final List<Map<String, String>> _mockEmployees = [
    {'id': 'EMP-4001', 'name': 'Aditya Nugroho', 'role': 'Warehouse Director'},
    {'id': 'EMP-4002', 'name': 'Siti Rahma', 'role': 'Logistics Operations Lead'},
    {'id': 'EMP-4003', 'name': 'Budi Hartono', 'role': 'Supply Chain Manager'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Simulate scanning flow
    _startSimulatedScan();
  }

  void _startSimulatedScan() {
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _statusText = 'Reading RFID signal...';
      });
    });

    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      // Select random employee
      final emp = (_mockEmployees..shuffle()).first;

      setState(() {
        _statusText = 'Access Granted!\nWelcome, ${emp['name']}';
        _isSuccess = true;
      });

      // Login
      Provider.of<AppState>(context, listen: false).loginWithBadge(
        emp['id']!,
        '${emp['name']} (${emp['role']})',
      );

      Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1911),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isSuccess ? const Color(0xFF135e39) : const Color(0xFFFFD700),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isSuccess ? Colors.green : const Color(0xFFFFD700)).withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BADGE IDENTIFICATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Radar scanner animation
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer scan rings
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isSuccess ? Colors.green.withOpacity(0.3) : const Color(0xFFFFD700).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isSuccess ? Colors.green.withOpacity(0.5) : const Color(0xFFFFD700).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                // Scanner radar sweeping line
                if (!_isSuccess)
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animController.value * 2 * 3.1415,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFFD700).withOpacity(0.3),
                                const Color(0xFFFFD700),
                              ],
                              stops: const [0.0, 0.85, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Central icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFF135e39) : const Color(0xFF162D1F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isSuccess ? Colors.green : const Color(0xFFFFD700)).withOpacity(0.25),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    _isSuccess ? Icons.verified_user : Icons.contact_emergency,
                    color: _isSuccess ? Colors.white : const Color(0xFFFFD700),
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Progress message
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? Colors.greenAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            if (!_isSuccess)
              const Text(
                'Supports RFID & NFC proximity scans',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
