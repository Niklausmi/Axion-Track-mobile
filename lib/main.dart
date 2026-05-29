// lib/main.dart  — v2
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'utils/theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const AxionTrackApp()),
  );
}

class AxionTrackApp extends StatelessWidget {
  const AxionTrackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Axion Track',
    theme: AppTheme.theme,
    debugShowCheckedModeBanner: false,
    home: const _SplashRouter(),
    routes: {
      '/login': (_) => const LoginScreen(),
      '/home':  (_) => const HomeScreen(),
    },
  );
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();
  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    // Minimum splash time + auto-login
    final results = await Future.wait([
      context.read<AppState>().tryAutoLogin(),
      Future.delayed(const Duration(milliseconds: 1400)),
    ]);
    if (!mounted) return;
    final loggedIn = results[0] as bool;
    Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/login');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
      ),
      child: Center(child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            const Text('Axion Track',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white,
                letterSpacing: -0.5, fontFamily: 'Inter')),
            const SizedBox(height: 6),
            Text('Fleet Management', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
            const SizedBox(height: 48),
            SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(color: Colors.white.withOpacity(0.6), strokeWidth: 2.5)),
          ]),
        ),
      )),
    ),
  );
}
