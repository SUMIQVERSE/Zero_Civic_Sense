import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class DonationPortalScreen extends StatelessWidget {
  const DonationPortalScreen({
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
        final ngos =
            store.users.where((user) => user.role == UserRole.ngo).toList();
        final totalDonations = store.donations.fold<double>(
          0,
          (sum, donation) => sum + donation.amount,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.t('donation.title'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B1C2D), Color(0xFF173451)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('donation.title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('donation.subtitle'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: l10n.t('donation.activeNgos'),
                      value: '${ngos.length}',
                      background: const Color(0xFFE0F2FE),
                      color: const Color(0xFF075985),
                      icon: Icons.volunteer_activism_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: l10n.t('ngo.totalDonations'),
                      value:
                          l10n.rupeesLabel(totalDonations.toStringAsFixed(0)),
                      background: const Color(0xFFDCFCE7),
                      color: const Color(0xFF166534),
                      icon: Icons.currency_rupee_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (ngos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text(l10n.t('donation.noNgos'))),
                )
              else
                ...ngos.map((ngo) => _NgoDonationCard(
                      ngo: ngo,
                      l10n: l10n,
                      totalDonations: store.donations
                          .where((donation) => donation.ngoId == ngo.id)
                          .fold<double>(
                              0, (sum, donation) => sum + donation.amount),
                      supporterCount: store.donations
                          .where((donation) => donation.ngoId == ngo.id)
                          .length,
                      activeSupportCount: store.issues
                          .where(
                            (issue) =>
                                issue.assignedNgo == ngo.id &&
                                issue.status != IssueStatus.resolved,
                          )
                          .length,
                      resolvedCount: store.issues
                          .where(
                            (issue) =>
                                issue.assignedNgo == ngo.id &&
                                issue.status == IssueStatus.resolved,
                          )
                          .length,
                      onDonate: () => _openDonationSheet(context, ngo),
                    )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDonationSheet(BuildContext context, AppUser ngo) async {
    final pageContext = context;
    final donorController = TextEditingController();
    final amountController = TextEditingController();
    final messageController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ngo.ngoName ?? ngo.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.t('donation.subtitle')),
                const SizedBox(height: 20),
                TextField(
                  controller: donorController,
                  decoration: InputDecoration(
                    labelText: l10n.t('ngo.donorName'),
                    filled: true,
                    fillColor: Theme.of(sheetContext).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('common.amount'),
                    filled: true,
                    fillColor: Theme.of(sheetContext).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.t('common.message'),
                    filled: true,
                    fillColor: Theme.of(sheetContext).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount =
                          double.tryParse(amountController.text.trim());
                      final donorName = donorController.text.trim();
                      if (amount == null || amount <= 0 || donorName.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text(l10n.t('citizen.requiredFields')),
                          ),
                        );
                        return;
                      }
                      store.addDonation(
                        Donation(
                          id: 'donation-${DateTime.now().microsecondsSinceEpoch}',
                          ngoId: ngo.id,
                          donorName: donorName,
                          amount: amount,
                          message: messageController.text.trim(),
                          createdAt: DateTime.now(),
                        ),
                      );
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${l10n.t('donation.supportNow')} - ${ngo.ngoName ?? ngo.fullName}',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_rounded),
                    label: Text(l10n.t('donation.supportNow')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NgoDonationCard extends StatelessWidget {
  const _NgoDonationCard({
    required this.ngo,
    required this.l10n,
    required this.totalDonations,
    required this.supporterCount,
    required this.activeSupportCount,
    required this.resolvedCount,
    required this.onDonate,
  });

  final AppUser ngo;
  final AppLocalizations l10n;
  final double totalDonations;
  final int supporterCount;
  final int activeSupportCount;
  final int resolvedCount;
  final VoidCallback onDonate;

  @override
  Widget build(BuildContext context) {
    final title = ngo.ngoName ?? ngo.fullName;
    final location = [
      if ((ngo.city ?? '').isNotEmpty) ngo.city,
      if ((ngo.state ?? '').isNotEmpty) l10n.stateName(ngo.state ?? ''),
    ].join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBE185D).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Color(0xFFBE185D),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(location),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (ngo.registrationId != null)
                            InfoPill(
                              label:
                                  '${l10n.t('common.registration')}: ${ngo.registrationId}',
                              color: const Color(0xFF075985),
                              background: const Color(0xFFE0F2FE),
                            ),
                          if (ngo.rating != null)
                            InfoPill(
                              label:
                                  '${l10n.t('common.rating')}: ${ngo.rating!.toStringAsFixed(1)}',
                              color: const Color(0xFF92400E),
                              background: const Color(0xFFFFEDD5),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: l10n.t('donation.supporters'),
                    value: '$supporterCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    label: l10n.t('donation.impactProjects'),
                    value: '$activeSupportCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    label: l10n.t('donation.resolvedProjects'),
                    value: '$resolvedCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.rupeesLabel(totalDonations.toStringAsFixed(0)),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onDonate,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(l10n.t('donation.supportNow')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
