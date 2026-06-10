import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../profile_screen.dart';
import 'sales_collection_tab.dart';
import 'sales_history_tab.dart';
import 'sales_order_tab.dart';
import 'sales_overview_tab.dart';
import 'sales_visit_tab.dart';

class SalesMainScreen extends StatefulWidget {
  const SalesMainScreen({super.key});

  @override
  State<SalesMainScreen> createState() => _SalesMainScreenState();
}

class _SalesMainScreenState extends State<SalesMainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    SalesOverviewTab(onMenuSelected: _changeTab),
    const SalesOrderTab(),
    const SalesCollectionTab(),
    const SalesVisitTab(),
    const SalesHistoryTab(),
  ];

  void _changeTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshDataForCurrentRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final username = appState.currentUser ?? 'Salesman';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, appState, username),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppState appState,
    String username,
  ) {
    return AppBar(
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
                const Text(
                  'TMSX SALES TEAM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  username,
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
        height: 64,
        elevation: 0,
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.softGreen,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Order',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Koleksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Kunjungan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Histori',
          ),
        ],
      ),
    );
  }
}
