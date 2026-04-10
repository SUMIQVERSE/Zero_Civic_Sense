import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';
import 'localization.dart';
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/authority_portal.dart';
import 'screens/citizen_portal.dart';
import 'screens/contractor_portal.dart';
import 'screens/landing_screen.dart';
import 'screens/ngo_portal.dart';
import 'screens/profile_onboarding_screen.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publicKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  runApp(const CivicSetuApp());
}

class CivicSetuApp extends StatefulWidget {
  const CivicSetuApp({super.key});

  @override
  State<CivicSetuApp> createState() => _CivicSetuAppState();
}

class _CivicSetuAppState extends State<CivicSetuApp> {
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    _store.initialize();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final l10n = AppLocalizations(_store.language);
        final lightColorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B1C2D),
          brightness: Brightness.light,
        ).copyWith(secondary: const Color(0xFFE8821C));
        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B1C2D),
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFFFA94D),
          surface: const Color(0xFF111827),
          surfaceContainerHighest: const Color(0xFF1F2937),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: l10n.t('app.name'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: const Color(0xFFF7F3EB),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: const Color(0xFF08111E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF111827),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          themeMode: _store.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: _buildHome(l10n),
        );
      },
    );
  }

  Widget _buildHome(AppLocalizations l10n) {
    if (!_store.isInitialized) {
      return _AppBootstrapScreen(l10n: l10n);
    }
    if (_store.isAuthConfigured) {
      if (_store.currentUser == null && _store.needsProfileSetup) {
        return ProfileOnboardingScreen(store: _store, l10n: l10n);
      }
      if (_store.currentUser == null) {
        return AuthScreen(store: _store, l10n: l10n);
      }
    }

    final user = _store.currentUser;
    if (user == null) {
      return LandingScreen(store: _store, l10n: l10n);
    }
    return switch (user.role) {
      UserRole.citizen => CitizenPortalScreen(
          store: _store,
          l10n: l10n,
          initialTabIndex: _store.citizenInitialTabIndex,
        ),
      UserRole.authority => AuthorityPortalScreen(store: _store, l10n: l10n),
      UserRole.contractor => ContractorPortalScreen(store: _store, l10n: l10n),
      UserRole.ngo => NgoPortalScreen(store: _store, l10n: l10n),
    };
  }
}

class _AppBootstrapScreen extends StatelessWidget {
  const _AppBootstrapScreen({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF08111E), Color(0xFF173451)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                l10n.t('auth.sessionRestoring'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
