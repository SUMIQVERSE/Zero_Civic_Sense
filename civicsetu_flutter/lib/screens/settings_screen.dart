import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.l10n,
  });

  final AppStore store;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.t('settings.title'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('settings.title'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('settings.subtitle'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('settings.appearance'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('common.language'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.t('settings.languageHelp')),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppLanguage.values
                            .map(
                              (language) => ChoiceChip(
                                selected: store.language == language,
                                label: Text(language.label),
                                onSelected: (_) {
                                  store.setLanguage(language);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile.adaptive(
                  value: store.isDarkMode,
                  onChanged: store.setDarkMode,
                  title: Text(l10n.t('settings.nightMode')),
                  subtitle: Text(l10n.t('settings.nightModeSubtitle')),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('settings.preferences'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: store.alertsEnabled,
                      onChanged: store.setAlertsEnabled,
                      title: Text(l10n.t('settings.alerts')),
                      subtitle: Text(l10n.t('settings.alertsSubtitle')),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: store.autoLocationEnabled,
                      onChanged: store.setAutoLocationEnabled,
                      title: Text(l10n.t('settings.autoLocation')),
                      subtitle: Text(l10n.t('settings.autoLocationSubtitle')),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: store.aiAssistEnabled,
                      onChanged: store.setAiAssistEnabled,
                      title: Text(l10n.t('settings.aiAssist')),
                      subtitle: Text(l10n.t('settings.aiAssistSubtitle')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
