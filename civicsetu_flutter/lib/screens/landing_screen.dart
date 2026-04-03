import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.store, required this.l10n});

  final AppStore store;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (l10n.t('landing.stats.resolved'), '1,200+'),
      (l10n.t('landing.stats.states'), '25+'),
      (l10n.t('landing.stats.ngos'), '230+'),
      (l10n.t('landing.stats.contractors'), '350+'),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1C2D), Color(0xFF18354D), Color(0xFFECE3D6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFE8821C),
                    child: Icon(Icons.location_city, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.t('app.name'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  PopupMenuButton<AppLanguage>(
                    onSelected: (value) {
                      store.setLanguage(value);
                    },
                    itemBuilder: (context) => AppLanguage.values
                        .map(
                          (lang) => PopupMenuItem(
                            value: lang,
                            child: Text(lang.label),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        store.language.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              InfoPill(
                label: l10n.t('landing.badge'),
                background: const Color(0x33E8821C),
                color: const Color(0xFFFFD5AA),
                icon: Icons.public,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('app.tagline'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Mobile-first civic issue reporting, bidding, proof verification, NGO support, and quality analytics.',
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, index) {
                  final item = stats[index];
                  return StatCard(
                    label: item.$1,
                    value: item.$2,
                    background: Colors.white.withOpacity(0.95),
                    color: const Color(0xFF0B1C2D),
                  );
                },
              ),
              const SizedBox(height: 24),
              ...[
                UserRole.citizen,
                UserRole.authority,
                UserRole.contractor,
                UserRole.ngo,
              ].map((role) {
                final icon = switch (role) {
                  UserRole.citizen => Icons.person_rounded,
                  UserRole.authority => Icons.admin_panel_settings_rounded,
                  UserRole.contractor => Icons.handyman_rounded,
                  UserRole.ngo => Icons.volunteer_activism_rounded,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE8821C),
                        child: Icon(icon, color: Colors.white),
                      ),
                      title: Text(
                        l10n.roleLabel(role),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Demo access for ${role.key} workflow'),
                      trailing: FilledButton(
                        onPressed: () => store.loginAs(role),
                        child: Text(l10n.t('landing.enter')),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
