import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.navy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'HankenGrotesk',
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 42,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  appState.currentUser ?? 'Guest User',
                  style: const TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'TMSX User Profile',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _profileMenu(
            icon: Icons.badge_rounded,
            title: 'Role Profile',
            value: appState.userRole,
          ),

          if (appState.userRole == 'Sales') ...[
            _salesMappingCard(context, appState),
            const SizedBox(height: 6),
          ],

          _profileMenu(
            icon: Icons.business_rounded,
            title: 'Company',
            value:
                appState.currentEmployeeProfile['company']?.toString() ??
                'PT Tani Mandiri Sukses',
          ),

          _profileMenu(
            icon: Icons.verified_user_rounded,
            title: 'Status',
            value: appState.isAuthenticated ? 'Active' : 'Inactive',
          ),

          if (appState.currentEmployee != null) ...[
            const SizedBox(height: 8),
            _employeeProfileCard(appState),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await appState.logout();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.red.withValues(alpha: 0.08),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesMappingCard(BuildContext context, AppState appState) {
    final hasError = appState.salesIdentityError != null;
    return Card(
      color: hasError ? const Color(0xFFFFF7ED) : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasError
              ? Colors.orange.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  hasError ? Icons.warning_amber_rounded : Icons.badge_outlined,
                  color: hasError ? Colors.orange : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasError
                        ? 'Mapping Sales Belum Lengkap'
                        : 'Mapping Sales Terhubung',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cek ulang mapping',
                  onPressed: appState.resolveCurrentSalesIdentity,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (hasError)
              Text(
                appState.salesIdentityError!,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              const Divider(),
              _mappingRow('User', appState.currentUser ?? '-'),
              _mappingRow('Employee', appState.currentEmployee ?? '-'),
              _mappingRow('Sales Person', appState.currentSalesPerson ?? '-'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mappingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.slate),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeProfileCard(AppState appState) {
    final employee = appState.currentEmployeeProfile;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Employee',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const Divider(),
            _mappingRow(
              'Nama',
              employee['employee_name']?.toString() ??
                  appState.currentEmployee ??
                  '-',
            ),
            _mappingRow('ID', appState.currentEmployee ?? '-'),
            _mappingRow('Status', employee['status']?.toString() ?? '-'),
            _mappingRow('Jabatan', employee['designation']?.toString() ?? '-'),
            _mappingRow(
              'Departemen',
              employee['department']?.toString() ?? '-',
            ),
            _mappingRow('Branch', employee['branch']?.toString() ?? '-'),
            _mappingRow(
              'Bergabung',
              employee['date_of_joining']?.toString() ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMenu({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: AppColors.slate,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
