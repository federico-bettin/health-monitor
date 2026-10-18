import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/auth_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    _animController.forward();
    _navigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final settings = SettingsService.instance;

    if (!settings.onboardingDone) {
      context.go(AppRoutes.onboarding);
      return;
    }
    if (settings.biometricEnabled) {
      final ok = await AuthService().authenticate(reason: 'Accedi a Health Monitor');
      if (!mounted) return;
      if (!ok) { setState(() => _authFailed = true); return; }
    }
    if (!mounted) return;
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: _authFailed ? _buildAuthFailed() : FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.monitor_heart, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Text('Health Monitor',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryDark, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('Il tuo monitor della salute personale',
                  style: TextStyle(fontSize: 14,
                      color: AppTheme.textSecondaryDark)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthFailed() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline, size: 64, color: AppTheme.primary),
      const SizedBox(height: 24),
      const Text('Autenticazione richiesta',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDark)),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () { setState(() => _authFailed = false); _navigate(); },
        child: const Text('Riprova')),
    ]);
  }
}
