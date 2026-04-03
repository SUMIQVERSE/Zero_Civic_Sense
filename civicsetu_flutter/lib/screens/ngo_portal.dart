import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class NgoPortalScreen extends StatefulWidget {
  const NgoPortalScreen({super.key, required this.store, required this.l10n});

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<NgoPortalScreen> createState() => _NgoPortalScreenState();
}

class _NgoPortalScreenState extends State<NgoPortalScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: _tabIndex,
      child: PortalScaffold(
        store: widget.store,
        l10n: widget.l10n,
        title: widget.l10n.t('ngo.title'),
        child: Column(
          children: [
            TabBar(
              onTap: (value) => setState(() => _tabIndex = value),
              isScrollable: true,
              tabs: [
                Tab(text: widget.l10n.t('ngo.issues')),
                Tab(text: widget.l10n.t('ngo.requests')),
                Tab(text: widget.l10n.t('ngo.analytics')),
                Tab(text: widget.l10n.t('ngo.donations')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildIssuesTab(),
                  _buildRequestsTab(),
                  _buildAnalyticsTab(),
                  _buildDonationsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesTab() {
    final user = widget.store.currentUser!;
    final requests = widget.store.ngoRequests
        .where((request) => request.ngoId == user.id)
        .toList();
    final requestedIssueIds =
        requests.map((request) => request.issueId).toSet();
    final unresolved = widget.store.issues
        .where((issue) => issue.status != IssueStatus.resolved)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: unresolved.map((issue) {
        final requested = requestedIssueIds.contains(issue.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('${issue.city}, ${issue.state}'),
                const SizedBox(height: 8),
                Text(issue.description),
                const SizedBox(height: 12),
                if (requested)
                  const InfoPill(label: 'Request raised')
                else
                  FilledButton(
                    onPressed: () => widget.store.addNgoRequest(
                      NgoRequest(
                        id: 'ngo-${DateTime.now().microsecondsSinceEpoch}',
                        issueId: issue.id,
                        ngoId: user.id,
                        ngoName: user.ngoName ?? user.fullName,
                        status: 'pending',
                        createdAt: DateTime.now(),
                      ),
                    ),
                    child: Text(widget.l10n.t('ngo.raiseRequest')),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRequestsTab() {
    final user = widget.store.currentUser!;
    final requests = widget.store.ngoRequests
        .where((request) => request.ngoId == user.id)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: requests.map((request) {
        final issue = widget.store.issues.firstWhere(
          (entry) => entry.id == request.issueId,
        );
        final color = request.status == 'approved'
            ? const Color(0xFF166534)
            : request.status == 'rejected'
                ? const Color(0xFFB91C1C)
                : const Color(0xFFB45309);
        final bg = request.status == 'approved'
            ? const Color(0xFFDCFCE7)
            : request.status == 'rejected'
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFFFEDD5);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              issue.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${issue.city}, ${issue.state}'),
            trailing: InfoPill(
              label: request.status,
              color: color,
              background: bg,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalyticsTab() {
    final ratings = widget.store.stateQualityRatings;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.l10n.t('ngo.analytics'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 12),
        ...ratings.take(5).map((rating) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.l10n.stateName(rating.state),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${rating.qualityScore}/100'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: rating.qualityScore / 100,
                    borderRadius: BorderRadius.circular(999),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${rating.resolutionRate}% resolved - ${rating.awaitingVerificationIssues} awaiting verification',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDonationsTab(BuildContext context) {
    final user = widget.store.currentUser!;
    final donations = widget.store.donations
        .where((donation) => donation.ngoId == user.id)
        .toList();
    final total = donations.fold<double>(
      0,
      (sum, donation) => sum + donation.amount,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatCard(
          label: widget.l10n.t('ngo.totalDonations'),
          value: 'Rs ${total.toStringAsFixed(0)}',
          color: const Color(0xFF166534),
          background: const Color(0xFFDCFCE7),
          icon: Icons.currency_rupee_rounded,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _openDonationDialog(context),
          child: Text(widget.l10n.t('ngo.addDonation')),
        ),
        const SizedBox(height: 12),
        ...donations.map((donation) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                donation.donorName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(donation.message),
              trailing: Text('Rs ${donation.amount.toStringAsFixed(0)}'),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openDonationDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final messageController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.l10n.t('ngo.addDonation')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Donor name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.l10n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final user = widget.store.currentUser!;
                if (amount == null || nameController.text.trim().isEmpty) {
                  return;
                }
                widget.store.addDonation(
                  Donation(
                    id: 'donation-${DateTime.now().microsecondsSinceEpoch}',
                    ngoId: user.id,
                    donorName: nameController.text.trim(),
                    amount: amount,
                    message: messageController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(widget.l10n.t('common.submit')),
            ),
          ],
        );
      },
    );
  }
}
