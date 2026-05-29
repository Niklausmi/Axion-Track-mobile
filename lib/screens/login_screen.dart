// lib/screens/login_screen.dart  — v2 (Hardcoded Server URL, shake on error)
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
  // Hardcoded to your custom endpoint behind the scenes
  final _serverCtrl = TextEditingController(text: 'https://track.axiontrack.com');
  final _emailCtrl  = TextEditingController(text: '');
  final _passCtrl   = TextEditingController(text: '');
  bool _obscure = true;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shake = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack);
    _logoCtrl.forward();
  }

  @override
  void dispose() {
    _serverCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _shakeCtrl.dispose(); _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    // Simplified conditional checking since Server URL is guaranteed to be populated
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    await context.read<AppState>().login(
      serverUrl: _serverCtrl.text.trim(),
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Column(children: [
        // Hero
        Expanded(child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)]),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(scale: _logoAnim, child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 40),
            )),
            const SizedBox(height: 20),
            RichText(text: const TextSpan(children: [
              TextSpan(text: 'Axion',   style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontFamily: 'Inter')),
              TextSpan(text: ' Track', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Inter')),
            ])),
            const SizedBox(height: 6),
            const Text('Professional Fleet Management',
              style: TextStyle(fontSize: 14, color: AppColors.text3, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('GPS · IoT · Real-time Analytics',
              style: TextStyle(fontSize: 11, color: AppColors.text4, letterSpacing: 0.6)),
          ]),
        )),

        // Form with shake animation wrapper
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            final offset = sin(_shake.value * pi * 5) * 8;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: Column(children: [
              // Error Banner Context Overlay
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: state.error != null ? Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.error!, style: const TextStyle(fontSize: 13, color: AppColors.red))),
                  ]),
                ) : const SizedBox.shrink(),
              ),

              // Server URL text field elements have been cleanly extracted from here
              
              _label('Email'),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'admin@example.com',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.text3))),
              const SizedBox(height: 12),

              _label('Password'),
              TextField(
                controller: _passCtrl, obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.text3),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.text3),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: state.isLoading ? null : _login,
                child: state.isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Connect to Fleet →'),
              )),
              const SizedBox(height: 14),
              
              // Adjusted helper links targeting your secure platform setup directly
              GestureDetector(
                onTap: () {
                  _emailCtrl.text  = 'demo@axiontrack.com';
                  _passCtrl.text   = 'demo';
                },
                child: RichText(text: const TextSpan(children: [
                  TextSpan(text: 'Need assistance? ', style: TextStyle(fontSize: 13, color: AppColors.text3, fontFamily: 'Inter')),
                  TextSpan(text: 'Contact Support', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                ])),
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
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.text3, letterSpacing: 0.6))));
}