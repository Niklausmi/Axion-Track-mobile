// lib/screens/login_screen.dart  — v3 (Light Mode + Sticky Auto-Login Routing)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Fix 8: hardcoded to Axion Track server — not user-editable
  static const _serverUrl = 'https://track.axiontrack.com';
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscure = true;
  bool _checkingAutoLogin = true; // Block UI flash during persistent check

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoAnim;

  @override
  void initState() {
    super.initState();
    
    // Shake animation configs
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shake = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    // Logo entrance configs
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack);
    _logoCtrl.forward();

    // Trigger explicit session lookup instantly upon widget initialization
    _performSessionAutoCheck();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _shakeCtrl.dispose(); _logoCtrl.dispose();
    super.dispose();
  }

  // ── Session Auto Check Gate ──
  Future<void> _performSessionAutoCheck() async {
    final state = context.read<AppState>();
    
    // Attempt the persistent token lookup sequence
    final success = await state.tryAutoLogin();
    
    if (!mounted) return;
    
    if (success && state.isLoggedIn) {
      // Sticky session verified! Transition forward immediately
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // No valid persistence profiles found; drop screen block and reveal form
      setState(() => _checkingAutoLogin = false);
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    await context.read<AppState>().login(
      serverUrl: _serverUrl,
      email:     _emailCtrl.text.trim(),
      password:  _passCtrl.text,
    );
    if (mounted) {
      final state = context.read<AppState>();
      if (state.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _shakeCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // If looking up persistent storage states, show a clean, native light loader 
    // to block the form from flashing on screen for authenticated users.
    if (_checkingAutoLogin) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Column(children: [
        // Hero Header Area
        Expanded(child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)]),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(scale: _logoAnim, child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 40),
            )),
            const SizedBox(height: 20),
            RichText(text: const TextSpan(children: [
              TextSpan(text: 'Axion',   style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontFamily: 'Inter')),
              TextSpan(text: ' Track', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Inter')),
            ])),
            const SizedBox(height: 6),
            const Text('Professional Fleet Management',
              style: TextStyle(fontSize: 14, color: AppColors.text3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('GPS · IoT · Real-time Analytics',
              style: TextStyle(fontSize: 11, color: AppColors.text4, letterSpacing: 0.6, fontWeight: FontWeight.w500)),
          ]),
        )),

        // Input Console Area with Shaker Translation bindings
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            final offset = sin(_shake.value * pi * 5) * 8;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4))],
              border: const Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(children: [
              // Error Alert Notification Banner
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: state.error != null ? Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2), 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.error!, style: const TextStyle(fontSize: 13, color: AppColors.red, fontWeight: FontWeight.w600))),
                  ]),
                ) : const SizedBox.shrink(),
              ),

              _label('Email Address'),
              TextField(
                controller: _emailCtrl, 
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'name@company.com',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.text3, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              _label('Password'),
              TextField(
                controller: _passCtrl, 
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.text3, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.text3, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ])),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        color: AppColors.text2, letterSpacing: 0.6))));
}