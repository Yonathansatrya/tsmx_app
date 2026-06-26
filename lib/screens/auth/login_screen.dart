import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../app_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _siteFormKey = GlobalKey<FormState>();
  final _credentialFormKey = GlobalKey<FormState>();
  final _siteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSiteConfirmed = false;
  List<Map<String, String>> _siteHistory = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppState>();
      if (appState.selectedSiteBaseUrl.trim().isNotEmpty) {
        _siteController.text = appState.selectedSiteName;
        _isSiteConfirmed = true;
      }
      final history = await appState.loadFrappeSiteHistory();
      if (!mounted) return;
      setState(() => _siteHistory = history);
    });
  }

  @override
  void dispose() {
    _siteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueWithSite({String? displayName}) async {
    if (!_siteFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    final configured = await appState.configureFrappeSite(
      codeOrUrl: _siteController.text.trim(),
      displayName: displayName,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSiteConfirmed = configured;
    });

    if (!configured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.lastAuthError ?? 'Site tidak valid.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_credentialFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await appState.login(
      username,
      password,
      baseUrl: appState.selectedSiteBaseUrl,
    );

    if (success) {
      await appState.saveFrappeConfig(
        username: username,
        password: password,
        baseUrl: appState.selectedSiteBaseUrl,
        siteName: appState.selectedSiteName,
      );
      await appState.prefetchInitialData();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppMainScreen()),
      );
    } else {
      if (!mounted) return;
      final err = appState.lastAuthError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null
                ? 'Invalid login. Please check your credentials.'
                : 'Login failed: $err',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _useHistorySite(Map<String, String> site) async {
    _siteController.text = site['baseUrl'] ?? '';
    await _continueWithSite(displayName: site['siteName']);
  }

  void _changeCompany() {
    setState(() {
      _isSiteConfirmed = false;
      _siteController.clear();
      _usernameController.clear();
      _passwordController.clear();
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      labelStyle: const TextStyle(color: AppColors.slate, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shadowColor: AppColors.primary.withValues(alpha: 0.18),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ).copyWith(
      overlayColor: WidgetStateProperty.all(
        AppColors.accentYellow.withValues(alpha: 0.25),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _LoginBrand(),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _isSiteConfirmed
                      ? Form(
                          key: _credentialFormKey,
                          child: _credentialForm(appState),
                        )
                      : Form(key: _siteFormKey, child: _siteOnboardingForm()),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Powered by TMSX Hub',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _siteOnboardingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormHeader(
          title: 'Kode Perusahaan',
          subtitle: 'Masuk ke site ERPNext yang diberikan admin.',
        ),
        const SizedBox(height: 14),
        if (_siteHistory.isNotEmpty) ...[
          const Text(
            'Terakhir digunakan',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final site in _siteHistory)
                ActionChip(
                  avatar: const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(site['siteName'] ?? 'Site'),
                  onPressed: _isLoading ? null : () => _useHistorySite(site),
                  backgroundColor: AppColors.softGreen,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  labelStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _siteController,
          decoration: _inputDecoration(
            label: 'Kode Perusahaan',
            icon: Icons.dns_outlined,
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_isLoading) _continueWithSite();
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Masukkan kode perusahaan';
            }
            return null;
          },
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _isLoading ? null : _continueWithSite,
          style: _primaryButtonStyle(),
          child: _isLoading
              ? const _ButtonSpinner()
              : const Text(
                  'LANJUT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _credentialForm(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormHeader(
          title: 'Sign In',
          subtitle: 'Gunakan akun ERPNext untuk site yang dipilih.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                appState.selectedSiteName.isEmpty
                    ? 'Site terpilih'
                    : appState.selectedSiteName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _changeCompany,
              child: const Text('Ganti'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _usernameController,
          decoration: _inputDecoration(
            label: 'Email / Username',
            icon: Icons.person_outline,
          ),
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration(
            label: 'Password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              splashRadius: 22,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_isLoading) _submit();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 4) return 'Password too short';
            return null;
          },
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            appState.setRememberDevice(!appState.rememberDevice);
          },
          child: Row(
            children: [
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: appState.rememberDevice,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.softGreen,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: appState.setRememberDevice,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Ingat perangkat ini',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: _primaryButtonStyle(),
          child: _isLoading
              ? const _ButtonSpinner()
              : const Text(
                  'SIGN IN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ],
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mobile ERP untuk operasional multi-company',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.slate,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FormHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FormHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
