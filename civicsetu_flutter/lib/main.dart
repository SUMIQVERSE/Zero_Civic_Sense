import 'package:flutter/material.dart';

import 'app_store.dart';
import 'localization.dart';
import 'models.dart';
import 'screens/authority_portal.dart';
import 'screens/citizen_portal.dart';
import 'screens/contractor_portal.dart';
import 'screens/landing_screen.dart';
import 'screens/ngo_portal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final l10n = AppLocalizations(_store.language);
        final colorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B1C2D),
          brightness: Brightness.light,
        ).copyWith(secondary: const Color(0xFFE8821C));
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: l10n.t('app.name'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
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
          home: _buildHome(l10n),
        );
      },
    );
  }

  Widget _buildHome(AppLocalizations l10n) {
    final user = _store.currentUser;
    if (user == null) {
      return LandingScreen(store: _store, l10n: l10n);
    }
    return switch (user.role) {
      UserRole.citizen => CitizenPortalScreen(store: _store, l10n: l10n),
      UserRole.authority => AuthorityPortalScreen(store: _store, l10n: l10n),
      UserRole.contractor => ContractorPortalScreen(store: _store, l10n: l10n),
      UserRole.ngo => NgoPortalScreen(store: _store, l10n: l10n),
    };
  }
}
