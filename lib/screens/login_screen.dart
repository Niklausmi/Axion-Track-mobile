// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _serverCtrl = TextEditingController(text: 'https://demo.traccar.org');
  final _emailCtrl  = TextEditingController(text: 'demo@traccar.org');
  final _passCtrl   = TextEditingController(text: 'demo');
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _serverCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _animCtrl.dispose(); super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_serverCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required'), backgroundColor: AC.red));
      return;
    }
    await context.read<AppState>().login(
      serverUrl: _serverCtrl.text.trim(),
      email:     _emailCtrl.text.trim(),
      password:  _passCtrl.text);
    if (mounted && context.read<AppState>().isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [
                  // ── Hero section ──
                  Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1428), Color(0xFF0A0E1A)])),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: AC.blue.withOpacity(0.5), blurRadius: 24, offset: const Offset(0,8)),
                        BoxShadow(color: AC.blue.withOpacity(0.2), blurRadius: 60, offset: const Offset(0,0)),
                      ]),
                    child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 42)),
                  const SizedBox(height: 20),
                  // App name
                  RichText(text: const TextSpan(children: [
                    TextSpan(text: 'Axion',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                        color: Colors.white, fontFamily: 'Inter', letterSpacing: -1.5)),
                    TextSpan(text: ' Track',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                        color: AC.blue, fontFamily: 'Inter', letterSpacing: -1.5)),
                  ])),
                  const SizedBox(height: 8),
                  const Text('Professional Fleet Management',
                    style: TextStyle(fontSize: 14, color: AC.text3, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('GPS · IoT · Real-time Analytics',
                    style: TextStyle(fontSize: 11, color: AC.text4, letterSpacing: 0.5)),
                  const SizedBox(height: 28),
                  // Stats row
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const _HeroStat('99.9%', 'Uptime'),
                    _dot(),
                    const _HeroStat('< 5s', 'Latency'),
                    _dot(),
                    const _HeroStat('256-bit', 'Encrypted'),
                  ]),
                ]),
              ),
            ),

            // ── Form section ──
            Container(
              decoration: const BoxDecoration(
                color: AC.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(children: [
                // Error
                if (state.error != null) Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AC.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AC.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.error!,
                      style: const TextStyle(fontSize: 13, color: AC.red, fontWeight: FontWeight.w500))),
                  ])),

                _label('SERVER URL'),
                TextField(
                  controller: _serverCtrl,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: AC.text1, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'https://your-traccar-server.com',
                    prefixIcon: Icon(Icons.dns_outlined, color: AC.text3, size: 20))),
                const SizedBox(height: 12),

                _label('EMAIL'),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AC.text1, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'admin@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AC.text3, size: 20))),
                const SizedBox(height: 12),

                _label('PASSWORD'),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  onSubmitted: (_) => _login(),
                  style: const TextStyle(color: AC.text1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AC.text3, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                        color: AC.text3, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure)))),
                const SizedBox(height: 20),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AC.blue,
                      disabledBackgroundColor: AC.blue.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                    child: state.isLoading
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                          SizedBox(width: 12),
                          Text('Connecting…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        ])
                      : const Text('Connect to Fleet →',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
                const SizedBox(height: 14),

                // Demo shortcut
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _serverCtrl.text = 'https://demo.traccar.org';
                      _emailCtrl.text  = 'demo@traccar.org';
                      _passCtrl.text   = 'demo';
                    });
                  },
                  child: RichText(text: const TextSpan(children: [
                    TextSpan(text: "Don't have a server? ",
                      style: TextStyle(fontSize: 13, color: AC.text3, fontFamily: 'Inter')),
                    TextSpan(text: 'Use Demo',
                      style: TextStyle(fontSize: 13, color: AC.blue,
                        fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                  ]))),
              ]),
            ),
              ]),
            ),
          ),
        ))),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AC.text3, letterSpacing: 0.8))));

  Widget _dot() => Container(
    width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: const BoxDecoration(color: AC.text4, shape: BoxShape.circle));
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AC.blue)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: AC.text3, fontWeight: FontWeight.w500)),
  ]);
}
