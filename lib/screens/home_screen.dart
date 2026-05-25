import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

// tabs menu
import 'tabs/dashboard_tab.dart';
import 'tabs/purchase_tab.dart';
import 'tabs/sales_tab.dart';
import 'tabs/stock_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DashboardTab(),
    SalesTab(),
    PurchaseTab(),
    StockTab(),
  ];

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAuthenticated) {
      _redirectToLogin();

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _buildFloatingActionButton(context, appState),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        centerTitle: false,
        titleSpacing: 16,

        title: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PT. Tani Mandiri Sukses',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                Text(
                  appState.currentUser ?? 'Operator',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),

                if (appState.actionRequired.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${appState.actionRequired.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text(
                    'You have ${appState.actionRequired.length} unresolved action items.',
                  ),
                ),
              );
            },
          ),

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

          const SizedBox(width: 8),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: _tabs),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _changeTab,

          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,

          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.slate,

          selectedIconTheme: const IconThemeData(
            color: AppColors.primary,
            size: 26,
          ),

          unselectedIconTheme: const IconThemeData(
            color: AppColors.slate,
            size: 23,
          ),

          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),

          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: 'Sell',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping_rounded),
              label: 'Buy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stock',
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, AppState appState) {
    switch (_currentIndex) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () {
            _showCreateSalesOrderSheet(context);
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Sell',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        );

      case 2:
        return FloatingActionButton.extended(
          onPressed: () {
            _showCreatePurchaseOrderSheet(context);
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Buy',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        );

      case 3:
        return FloatingActionButton.extended(
          onPressed: () {
            _showCreateStockEntrySheet(context);
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Stock',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        );

      default:
        return null;
    }
  }

  void _showCreateSalesOrderSheet(BuildContext context) {
    _showComingSoonSheet(
      context,
      title: 'Create Sales Order',
      message: 'Form create Sales Order akan dibuat di tahap berikutnya.',
    );
  }

  void _showCreatePurchaseOrderSheet(BuildContext context) {
    _showComingSoonSheet(
      context,
      title: 'Create Purchase Order',
      message:
          'Form create Purchase Order akan dibuat setelah Sales Order selesai.',
    );
  }

  void _showCreateStockEntrySheet(BuildContext context) {
    _showComingSoonSheet(
      context,
      title: 'Create Stock Entry',
      message:
          'Form Stock Entry akan dibuat setelah modul Sales dan Purchase rapi.',
    );
  }

  void _showComingSoonSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.slate,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
