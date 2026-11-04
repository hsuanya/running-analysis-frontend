import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/auth/auth_provider.dart';
import 'package:frontend/feature/auth/auth_state.dart';
import 'package:frontend/utils/locale_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(String rawError, bool isZh) {
    final lower = rawError.toLowerCase();
    if (lower.contains('incorrect username or password')) {
      return isZh ? '使用者名稱或密碼錯誤，請重新確認' : 'Incorrect username or password';
    } else if (lower.contains('timeout')) {
      return isZh ? '伺服器連線逾時，請檢查網路連線' : 'Connection timeout, please try again';
    } else if (lower.contains('user not found') || lower.contains('not found')) {
      return isZh ? '查無此使用者帳號' : 'User not found';
    } else if (lower.contains('connection refused') ||
        lower.contains('network error') ||
        lower.contains('failed host lookup')) {
      return isZh ? '無法連線至伺服器，請檢查網路連線' : 'Unable to connect to server, please check network';
    } else if (rawError.isNotEmpty) {
      return isZh ? '登入失敗：$rawError' : 'Login failed: $rawError';
    }
    return isZh ? '登入失敗，請檢查帳號密碼或網路連線' : 'Login failed, please check your credentials or network';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .login(_usernameController.text.trim(), _passwordController.text);

    if (!success && mounted) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = context.l10n;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDF4FE), Color(0xFFC7DCF8)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                  child: PopupMenuButton<String>(
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 4),
                    icon: const Icon(Icons.language, color: Color(0xFF2A3E5C), size: 28),
                    tooltip: l10n.switchLanguage,
                    color: const Color(0xFF1E2638),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onSelected: (code) {
                      ref.read(localeProvider.notifier).setLocale(Locale(code));
                    },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'zh',
                    child: Row(
                      children: [
                        Text(
                          '🇹🇼 繁體中文',
                          style: TextStyle(
                            color: currentLocale.languageCode == 'zh'
                                ? const Color(0xFF79A9EA)
                                : Colors.white,
                            fontWeight: currentLocale.languageCode == 'zh'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (currentLocale.languageCode == 'zh') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 16, color: Color(0xFF79A9EA)),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        Text(
                          '🇺🇸 English',
                          style: TextStyle(
                            color: currentLocale.languageCode == 'en'
                                ? const Color(0xFF79A9EA)
                                : Colors.white,
                            fontWeight: currentLocale.languageCode == 'en'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (currentLocale.languageCode == 'en') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 16, color: Color(0xFF79A9EA)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final double offset =
                          math.sin(_shakeAnimation.value * math.pi * 6) *
                          (1 - _shakeAnimation.value) *
                          10;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      );
                    },
                    child: Card(
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                    color: Colors.white.withValues(alpha: 0.85),
                    margin: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Icon & Title
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x22508FE8),
                              ),
                              child: const Icon(
                                Icons.directions_run_rounded,
                                size: 48,
                                color: Color(0xFF508FE8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.appTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2A3E5C),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.login,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 32),

                          // Username field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Color(0xFF1F2937)),
                            decoration: InputDecoration(
                              labelText: l10n.username,
                              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF508FE8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Color(0x55508FE8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Color(0xFF508FE8), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.redAccent),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.usernameHint;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Color(0xFF1F2937)),
                            decoration: InputDecoration(
                              labelText: l10n.password,
                              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF508FE8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF6B7280),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Color(0x55508FE8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Color(0xFF508FE8), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.redAccent),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.passwordHint;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Error Banner display
                          if (authState.status == AuthStatus.error &&
                              authState.errorMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 18.0),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _getFriendlyErrorMessage(
                                        authState.errorMessage!,
                                        currentLocale.languageCode == 'zh',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Login Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: authState.status == AuthStatus.loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF508FE8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                elevation: 2,
                              ),
                              child: authState.status == AuthStatus.loading
                                  ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                                  : Text(
                                      l10n.login,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Switch to Register Page
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.dontHaveAccount,
                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.push('/register');
                                },
                                child: Text(
                                  l10n.registerNow,
                                  style: const TextStyle(
                                    color: Color(0xFF508FE8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
