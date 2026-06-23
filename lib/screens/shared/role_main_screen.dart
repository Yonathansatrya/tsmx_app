import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';

typedef RoleScreensBuilder =
    List<Widget> Function(ValueChanged<int> onMenuSelected);
typedef RoleFloatingActionButtonBuilder =
    Widget? Function(BuildContext context, int currentIndex);

class RoleMainScreen extends StatefulWidget {
  final String title;
  final String fallbackUsername;
  final List<NavigationDestination> destinations;
  final RoleScreensBuilder screensBuilder;
  final FutureOr<void> Function(AppState state)? onInitialize;
  final RoleFloatingActionButtonBuilder? floatingActionButtonBuilder;

  const RoleMainScreen({
    super.key,
    required this.title,
    required this.fallbackUsername,
    required this.destinations,
    required this.screensBuilder,
    this.onInitialize,
    this.floatingActionButtonBuilder,
  });

  @override
  State<RoleMainScreen> createState() => _RoleMainScreenState();
}

class _RoleMainScreenState extends State<RoleMainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = widget.screensBuilder(_changeTab);
    assert(
      _screens.length == widget.destinations.length,
      'Jumlah screen dan navigation destination harus sama.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onInitialize?.call(context.read<AppState>());
    });
  }

  void _changeTab(int index) {
    if (index < 0 || index >= _screens.length || index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: widget.floatingActionButtonBuilder?.call(
        context,
        _currentIndex,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    state.currentUser ?? widget.fallbackUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.primary.withValues(alpha: 0.06)),
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _changeTab,
          height: 64,
          elevation: 0,
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.softGreen,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: widget.destinations,
        ),
      ),
    );
  }
}
