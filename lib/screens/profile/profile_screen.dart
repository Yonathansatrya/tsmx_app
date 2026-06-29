import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({super.key, this.showBackButton = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final _passwordFormKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final TabController _tabController;
  Map<String, dynamic> _userProfile = const {};
  bool _loadingProfile = true;
  bool _uploadingImage = false;
  bool _changingPassword = false;
  bool _logoutAllSessions = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await context.read<AppState>().fetchCurrentUserProfile();
      if (!mounted) return;
      setState(() => _userProfile = profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _chooseProfilePhoto() async {
    if (_uploadingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ganti Foto Profil',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih foto yang jelas agar akun mudah dikenali.',
                style: TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 16),
              _PhotoSourceTile(
                icon: Icons.camera_alt_rounded,
                title: 'Ambil dari kamera',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
              _PhotoSourceTile(
                icon: Icons.photo_library_rounded,
                title: 'Pilih dari galeri',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (photo == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final imageUrl = await context.read<AppState>().uploadCurrentUserImage(
        photo.path,
      );
      if (!mounted) return;
      setState(() => _userProfile = {..._userProfile, 'user_image': imageUrl});
      _showMessage('Foto profil berhasil diperbarui.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submitPasswordChange() async {
    if (!_passwordFormKey.currentState!.validate() || _changingPassword) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah password?'),
        content: Text(
          _logoutAllSessions
              ? 'Password akan diperbarui dan sesi pada perangkat lain akan dikeluarkan.'
              : 'Gunakan password baru saat login berikutnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ubah Password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _changingPassword = true);
    try {
      await context.read<AppState>().changeCurrentUserPassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        logoutAllSessions: _logoutAllSessions,
      );
      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('Password berhasil diperbarui.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Profil Saya',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.slate,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_outline_rounded),
                  text: 'Informasi',
                ),
                Tab(icon: Icon(Icons.shield_outlined), text: 'Keamanan'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildInformationTab(appState), _buildSecurityTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab(AppState appState) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _buildIdentityCard(appState),
          if (_loadingProfile) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.softGreen,
            ),
          ],
          if (_profileError != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(message: _profileError!, onRetry: _loadProfile),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Informasi Akun',
            subtitle: 'Data utama akun ERPNext',
            icon: Icons.account_circle_outlined,
            children: [
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Nama Lengkap',
                value: _profileValue(
                  'full_name',
                  fallback: _profileValue('first_name'),
                ),
              ),
              _DetailRow(
                icon: Icons.alternate_email_rounded,
                label: 'Email',
                value: _profileValue('email', fallback: appState.currentUser),
              ),
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Username',
                value: _profileValue('username'),
              ),
              _DetailRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Role Profile',
                value: _profileValue(
                  'role_profile_name',
                  fallback: appState.userRole,
                ),
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telepon',
                value: _profileValue(
                  'mobile_no',
                  fallback: _profileValue('phone'),
                ),
              ),
              _DetailRow(
                icon: Icons.language_rounded,
                label: 'Bahasa',
                value: _profileValue('language'),
              ),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Zona Waktu',
                value: _profileValue('time_zone'),
                isLast: true,
              ),
            ],
          ),
          if (appState.currentEmployee != null) ...[
            const SizedBox(height: 14),
            _buildEmployeeCard(appState),
          ],
          if (appState.mobileAccess.isSalesUser) ...[
            const SizedBox(height: 14),
            _buildSalesMappingCard(appState),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _confirmResetLocalData(appState),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text(
              'Reset Data Lokal',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _confirmLogout(appState),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: AppColors.danger,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Keluar dari Akun',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(AppState appState) {
    final fullName = _profileValue(
      'full_name',
      fallback: _profileValue('first_name', fallback: appState.currentUser),
    );
    final email = _profileValue('email', fallback: appState.currentUser);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileAvatar(imageUrl: _absoluteImageUrl(appState)),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: AppColors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _uploadingImage ? null : _chooseProfilePhoto,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: _uploadingImage
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _IdentityBadge(label: appState.userRole),
                    if (appState.selectedSiteName.trim().isNotEmpty)
                      _IdentityBadge(
                        label: appState.selectedSiteName,
                        icon: Icons.business_rounded,
                      ),
                    _IdentityBadge(
                      label: appState.isAuthenticated ? 'Aktif' : 'Tidak Aktif',
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(AppState appState) {
    final employee = appState.currentEmployeeProfile;
    return _SectionCard(
      title: 'Informasi Karyawan',
      subtitle: appState.currentEmployee ?? 'Data Employee',
      icon: Icons.business_center_outlined,
      children: [
        _DetailRow(
          icon: Icons.person_pin_outlined,
          label: 'Nama Karyawan',
          value: _mapValue(
            employee,
            'employee_name',
            fallback: appState.currentEmployee,
          ),
        ),
        _DetailRow(
          icon: Icons.work_outline_rounded,
          label: 'Jabatan',
          value: _mapValue(employee, 'designation'),
        ),
        _DetailRow(
          icon: Icons.account_tree_outlined,
          label: 'Departemen',
          value: _mapValue(employee, 'department'),
        ),
        _DetailRow(
          icon: Icons.apartment_rounded,
          label: 'Perusahaan',
          value: _mapValue(employee, 'company'),
        ),
        _DetailRow(
          icon: Icons.location_city_outlined,
          label: 'Cabang',
          value: _mapValue(employee, 'branch'),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildSalesMappingCard(AppState appState) {
    final hasError = appState.salesIdentityError != null;
    return _SectionCard(
      title: hasError ? 'Mapping Sales Perlu Dicek' : 'Mapping Sales',
      subtitle: hasError
          ? appState.salesIdentityError!
          : 'Akun sudah terhubung ke Sales Person',
      icon: hasError ? Icons.warning_amber_rounded : Icons.handshake_outlined,
      action: IconButton(
        tooltip: 'Cek ulang mapping',
        onPressed: appState.resolveCurrentSalesIdentity,
        icon: const Icon(Icons.refresh_rounded),
      ),
      children: [
        _DetailRow(
          icon: Icons.person_outline_rounded,
          label: 'User',
          value: appState.currentUser ?? '-',
        ),
        _DetailRow(
          icon: Icons.badge_outlined,
          label: 'Employee',
          value: appState.currentEmployee ?? '-',
        ),
        _DetailRow(
          icon: Icons.sell_outlined,
          label: 'Sales Person',
          value: appState.currentSalesPerson ?? '-',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            children: [
              _SecurityIcon(),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keamanan Akun',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Kelola password dan sesi login akun ERPNext Anda.',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Ubah Password',
          subtitle: 'Pastikan password baru aman dan mudah Anda ingat',
          icon: Icons.lock_reset_rounded,
          children: [
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _oldPasswordController,
                    label: 'Password Lama',
                    visible: _showOldPassword,
                    onToggleVisibility: () {
                      setState(() => _showOldPassword = !_showOldPassword);
                    },
                    validator: (value) => _requiredPassword(value),
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _newPasswordController,
                    label: 'Password Baru',
                    visible: _showNewPassword,
                    onToggleVisibility: () {
                      setState(() => _showNewPassword = !_showNewPassword);
                    },
                    validator: (value) {
                      final required = _requiredPassword(value);
                      if (required != null) return required;
                      if (value!.length < 8) return 'Minimal 8 karakter';
                      if (value == _oldPasswordController.text) {
                        return 'Password baru harus berbeda';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _confirmPasswordController,
                    label: 'Konfirmasi Password Baru',
                    visible: _showConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitPasswordChange(),
                    onToggleVisibility: () {
                      setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      );
                    },
                    validator: (value) {
                      final required = _requiredPassword(value);
                      if (required != null) return required;
                      if (value != _newPasswordController.text) {
                        return 'Konfirmasi password tidak cocok';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _logoutAllSessions,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _logoutAllSessions = value);
                      },
                      title: const Text(
                        'Keluar dari perangkat lain',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text(
                        'Disarankan jika akun terasa tidak aman.',
                        style: TextStyle(color: AppColors.slate, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _changingPassword ? null : _submitPasswordChange,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _changingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.lock_reset_rounded),
                    label: Text(
                      _changingPassword ? 'Memperbarui...' : 'Ubah Password',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Tips Keamanan',
          subtitle: 'Panduan singkat menjaga akun tetap aman',
          icon: Icons.verified_user_outlined,
          children: const [
            _DetailRow(
              icon: Icons.password_rounded,
              label: 'Minimal password',
              value: '8 karakter',
            ),
            _DetailRow(
              icon: Icons.devices_other_rounded,
              label: 'Perangkat lain',
              value: 'Logout bila perlu',
            ),
            _DetailRow(
              icon: Icons.privacy_tip_outlined,
              label: 'Bagikan password',
              value: 'Jangan pernah',
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmLogout(AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk memakai aplikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await appState.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _confirmResetLocalData(AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset data lokal?'),
        content: const Text(
          'Cache dashboard, notifikasi, company, dan data sementara akan dibersihkan. '
          'Anda perlu login ulang setelah proses ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await appState.resetLocalAppCache();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String? _absoluteImageUrl(AppState appState) {
    final image = _userProfile['user_image']?.toString().trim() ?? '';
    if (image.isEmpty) return null;
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    return Uri.parse(appState.frappeService.baseUrl).resolve(image).toString();
  }

  String _profileValue(String key, {String? fallback}) {
    return _mapValue(_userProfile, key, fallback: fallback);
  }

  String _mapValue(
    Map<String, dynamic> values,
    String key, {
    String? fallback,
  }) {
    final value = values[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    final cleanFallback = fallback?.trim() ?? '';
    return cleanFallback.isEmpty ? '-' : cleanFallback;
  }

  String? _requiredPassword(String? value) {
    if (value == null || value.isEmpty) return 'Wajib diisi';
    return null;
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;

  const _ProfileAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
      ),
      child: imageUrl == null
          ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 44)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
    );
  }
}

class _IdentityBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _IdentityBadge({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.slate),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Coba lagi',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _PhotoSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: AppColors.surfaceMuted,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggleVisibility,
    required this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SecurityIcon extends StatelessWidget {
  const _SecurityIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(
        Icons.security_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
  }
}
