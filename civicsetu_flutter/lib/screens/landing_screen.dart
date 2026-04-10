import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import 'complaint_camera_screen.dart';
import 'donation_portal.dart';
import 'settings_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, required this.store, required this.l10n});

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  void _openTrack() {
    widget.store.loginAs(UserRole.citizen, citizenInitialTabIndex: 0);
  }

  Future<void> _openDonationPortal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DonationPortalScreen(store: widget.store, l10n: widget.l10n),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(store: widget.store, l10n: widget.l10n),
      ),
    );
  }

  Future<void> _openCameraReport() async {
    final result = await Navigator.of(context).push<ComplaintCameraResult>(
      MaterialPageRoute(
        builder: (context) => ComplaintCameraScreen(
          l10n: widget.l10n,
          autoFetchLocation: widget.store.autoLocationEnabled,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    widget.store.stageComplaintCapture(
      PendingComplaintCapture(
        imagePath: result.imagePath,
        locationDraft: result.locationDraft,
      ),
    );
    widget.store.loginAs(UserRole.citizen, citizenInitialTabIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    final portals = [
      const _PortalCardData(
        role: UserRole.citizen,
        icon: Icons.person_rounded,
        accent: Color(0xFFE8821C),
      ),
      const _PortalCardData(
        role: UserRole.authority,
        icon: Icons.admin_panel_settings_rounded,
        accent: Color(0xFF2563EB),
      ),
      const _PortalCardData(
        role: UserRole.contractor,
        icon: Icons.handyman_rounded,
        accent: Color(0xFF0F766E),
      ),
      const _PortalCardData(
        role: UserRole.ngo,
        icon: Icons.volunteer_activism_rounded,
        accent: Color(0xFFBE185D),
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1C2D), Color(0xFF173451), Color(0xFFECE3D6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8821C),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.l10n.t('app.name'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.l10n.t('landing.portalHint'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<AppLanguage>(
                      onSelected: (value) {
                        widget.store.setLanguage(value);
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
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          widget.store.language.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  widget.l10n.t('landing.choosePortal'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.l10n.t('landing.description'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 128),
                    itemCount: portals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final portal = portals[index];
                      return _PortalCard(
                        title: widget.l10n.roleLabel(portal.role),
                        subtitle: widget.l10n.portalDemoSubtitle(portal.role),
                        icon: portal.icon,
                        accent: portal.accent,
                        onTap: () => widget.store.loginAs(portal.role),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _HomeDock(
          portalsLabel: widget.l10n.t('landing.dockPortals'),
          donateLabel: widget.l10n.t('landing.dockDonate'),
          reportLabel: widget.l10n.t('citizen.report'),
          trackLabel: widget.l10n.t('landing.dockTrack'),
          settingsLabel: widget.l10n.t('landing.dockSettings'),
          onPortalsTap: () {},
          onDonateTap: _openDonationPortal,
          onReportTap: _openCameraReport,
          onTrackTap: _openTrack,
          onSettingsTap: _openSettings,
        ),
      ),
    );
  }
}

class _PortalCardData {
  const _PortalCardData({
    required this.role,
    required this.icon,
    required this.accent,
  });

  final UserRole role;
  final IconData icon;
  final Color accent;
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140B1C2D),
                blurRadius: 24,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: accent, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0B1C2D),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF52606F),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDock extends StatelessWidget {
  const _HomeDock({
    required this.portalsLabel,
    required this.donateLabel,
    required this.reportLabel,
    required this.trackLabel,
    required this.settingsLabel,
    required this.onPortalsTap,
    required this.onDonateTap,
    required this.onReportTap,
    required this.onTrackTap,
    required this.onSettingsTap,
  });

  final String portalsLabel;
  final String donateLabel;
  final String reportLabel;
  final String trackLabel;
  final String settingsLabel;
  final VoidCallback onPortalsTap;
  final VoidCallback onDonateTap;
  final VoidCallback onReportTap;
  final VoidCallback onTrackTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1C2D).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DockItem(
                          icon: Icons.grid_view_rounded,
                          label: portalsLabel,
                          isActive: true,
                          onTap: onPortalsTap,
                        ),
                        _DockItem(
                          icon: Icons.favorite_border_rounded,
                          label: donateLabel,
                          onTap: onDonateTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 84),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DockItem(
                          icon: Icons.track_changes_rounded,
                          label: trackLabel,
                          onTap: onTrackTap,
                        ),
                        _DockItem(
                          icon: Icons.settings_outlined,
                          label: settingsLabel,
                          onTap: onSettingsTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  elevation: 10,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onReportTap,
                    child: Ink(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8821C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reportLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFFFFD5AA)
        : Colors.white.withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
