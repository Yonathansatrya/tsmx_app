import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final appState = context.read<AppState>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await appState.login(username, password);

    if (success) {
      await appState.saveFrappeConfig(
        baseUrl: 'http://apps.willshine.id:8014',
        username: username,
        password: password,
        savePassword: appState.rememberDevice,
      );

      try {
        await appState.refreshSalesOrders();
        await appState.refreshPurchaseOrders();
        await appState.refreshInventory();
      } catch (_) {
        // Ignore fetch failures until app is running.
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid login. Please check your credentials.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color.fromARGB(255, 46, 80, 51)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7FAF6),
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE8DA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Container(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'PT. Tani Mandiri Sukses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'SIGN IN',
                            style: TextStyle(
                              // textAlign: TextAlign.center,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 1.3,
                            ),
                          ),

                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _usernameController,
                            decoration: _inputDecoration(
                              label: 'Username or ID',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username';
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
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 4) {
                                return 'Password too short';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  appState.setRememberDevice(
                                    !appState.rememberDevice,
                                  );
                                },
                                child: Row(
                                  children: [
                                    Transform.scale(
                                      scale: 0.78,
                                      child: Switch(
                                        value: appState.rememberDevice,
                                        activeColor: Colors.white,
                                        activeTrackColor: AppColors.primary,
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor: AppColors.softGreen,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: appState.setRememberDevice,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Remember',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withOpacity(
                                    0.08,
                                  ),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please contact IT support for credentials reset.',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Forgot Access?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shadowColor: AppColors.primary.withOpacity(
                                    0.4,
                                  ),
                                  elevation: 5,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ).copyWith(
                                  overlayColor: WidgetStateProperty.all(
                                    AppColors.accentYellow,
                                  ),
                                ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
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
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Powered by TMSX',
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
      ),
    );
  }
}
