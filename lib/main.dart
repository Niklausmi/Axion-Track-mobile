// lib/main.dart
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light));
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const AxionTrackApp()));
}

class AxionTrackApp extends StatelessWidget {
  const AxionTrackApp({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final themeMode = switch (state.themeMode) {
      ThemeMode2.light => ThemeMode.light,
      ThemeMode2.dark  => ThemeMode.dark,
      ThemeMode2.auto  => ThemeMode.system,
    };
    return MaterialApp(
      title: 'Axion Track',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login':  (_) => const LoginScreen(),
        '/home':   (_) => const HomeScreen(),
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logo;
  late AnimationController _text;
  late Animation<double>   _scale;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _logo  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _text  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _logo, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _text, curve: Curves.easeOut);
    _logo.forward();
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _text.forward(); });
    Future.delayed(const Duration(milliseconds: 1800), () { if (mounted) _navigate(); });
  }

  Future<void> _navigate() async {
    final ok = await context.read<AppState>().tryAutoLogin();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, ok ? '/home' : '/login');
  }

  @override
  void dispose() { _logo.dispose(); _text.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF050A14), Color(0xFF0A1428), Color(0xFF050A14)])),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Logo
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: AC.blue.withOpacity(0.5), blurRadius: 30, offset: const Offset(0,10)),
                  BoxShadow(color: AC.blue.withOpacity(0.15), blurRadius: 80),
                ]),
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 50))),
          const SizedBox(height: 24),
          // App name
          FadeTransition(
            opacity: _fade,
            child: RichText(text: const TextSpan(children: [
              TextSpan(text: 'Axion',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900,
                  color: Colors.white, fontFamily: 'Inter', letterSpacing: -2)),
              TextSpan(text: ' Track',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900,
                  color: AC.blue, fontFamily: 'Inter', letterSpacing: -2)),
            ]))),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _fade,
            child: const Text('Professional Fleet Management',
              style: TextStyle(fontSize: 14, color: AC.text3, fontWeight: FontWeight.w500))),
          const SizedBox(height: 60),
          FadeTransition(
            opacity: _fade,
            child: const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AC.blue), strokeWidth: 2.5))),
        ])),
      ),
    );
  }
}
