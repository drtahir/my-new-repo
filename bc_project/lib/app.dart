// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/pin_lock_screen.dart';
import 'ui/screens/add_transaction_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/zakat_screen.dart';
import 'ui/screens/reports_screen.dart';
import 'core/database/app_database.dart';
import 'ui/screens/bc_screen.dart';
import 'ui/screens/bc_detail_screen.dart';

class FamilyFinanceApp extends ConsumerStatefulWidget {
  const FamilyFinanceApp({super.key});

  @override
  ConsumerState<FamilyFinanceApp> createState() => _FamilyFinanceAppState();
}

class _FamilyFinanceAppState extends ConsumerState<FamilyFinanceApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _pinRequired = false;
  bool _checkingAuth = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Re-lock after 5 minutes of background
      if (_backgroundedAt != null && _pinRequired) {
        final elapsed = DateTime.now().difference(_backgroundedAt!);
        if (elapsed.inMinutes >= 5) {
          setState(() => _isUnlocked = false);
        }
      }
    }
  }

  Future<void> _checkAuth() async {
    final auth = ref.read(authServiceProvider);
    final pinEnabled = await auth.isPinEnabled;
    if (mounted) {
      setState(() {
        _pinRequired = pinEnabled;
        _isUnlocked = !pinEnabled; // auto-unlock if no PIN
        _checkingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance & Zakat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routes: {
        '/': (ctx) => _buildRoot(),
        '/settings': (ctx) => const SettingsScreen(),
        '/zakat': (ctx) => const ZakatScreen(),
        '/reports': (ctx) => const ReportsScreen(),
        '/transaction/add': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          return AddTransactionScreen(initialType: args is String ? args : null);
        },
        '/transaction/edit': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          return AddTransactionScreen(existingTransaction: args is Transaction ? args : null);
        },
        '/transactions': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          return AddTransactionScreen(initialType: args is String ? args : null);
        },
      },
    );
  }

  Widget _buildRoot() {
    if (_checkingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pinRequired && !_isUnlocked) {
      return PinLockScreen(onUnlocked: () => setState(() => _isUnlocked = true));
    }
    return const MainShell();
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF6F8FC),
      cardTheme: CardTheme(
        elevation: 0,
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1A1D27) : colorScheme.surface,
        foregroundColor: isDark ? Colors.white : colorScheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
        indicatorColor: colorScheme.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? const Color(0xFF252836) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
