import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class ContractorPortalScreen extends StatefulWidget {
  const ContractorPortalScreen({
    super.key,
    required this.store,
    required this.l10n,
  });

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<ContractorPortalScreen> createState() => _ContractorPortalScreenState();
}

class _ContractorPortalScreenState extends State<ContractorPortalScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser!;
    final myBids =
        widget.store.bids.where((bid) => bid.contractorId == user.id).toList();
    final myProjects = widget.store.issues
        .where((issue) => issue.assignedContractor == user.id)
        .toList();

    return DefaultTabController(
      length: 3,
      initialIndex: _tabIndex,
      child: PortalScaffold(
        store: widget.store,
        l10n: widget.l10n,
        title: widget.l10n.t('contractor.title'),
        child: Column(
          children: [
            TabBar(
              onTap: (value) => setState(() => _tabIndex = value),
              tabs: [
                Tab(text: widget.l10n.t('contractor.bids')),
                Tab(text: widget.l10n.t('contractor.projects')),
                Tab(text: widget.l10n.t('contractor.profile')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBidsTab(context),
                  _buildProjectsTab(context, myProjects),
                  _buildProfileTab(myBids, myProjects),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidsTab(BuildContext context) {
    final openIssues = widget.store.issues
        .where((issue) => issue.status == IssueStatus.openForBidding)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: openIssues.map((issue) {
        final alreadyBid = widget.store.bids.any(
          (bid) =>
              bid.issueId == issue.id &&
              bid.contractorId == widget.store.currentUser!.id,
        );
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
                Text(issue.description),
                const SizedBox(height: 12),
                if (alreadyBid)
                  InfoPill(label: widget.l10n.t('contractor.bidSubmitted'))
                else
                  FilledButton(
                    onPressed: () => _openBidDialog(context, issue),
                    child: Text(widget.l10n.t('contractor.submitBid')),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectsTab(BuildContext context, List<Issue> myProjects) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: myProjects.map((issue) {
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
                Text(widget.l10n.statusLabel(issue.status)),
                const SizedBox(height: 12),
                if (issue.afterImage != null) ...[
                  AppImage(source: issue.afterImage!, height: 140),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => _uploadCompletionProof(issue),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(widget.l10n.t('contractor.uploadCompletion')),
                ),
                const SizedBox(height: 12),
                CommentSection(
                  store: widget.store,
                  l10n: widget.l10n,
                  issue: issue,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfileTab(List<Bid> myBids, List<Issue> myProjects) {
    final user = widget.store.currentUser!;
    final selected = myBids.where((bid) => bid.status == 'selected').length;
    final earnings = myBids
        .where((bid) => bid.status == 'selected')
        .fold<double>(0, (sum, bid) => sum + bid.bidAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: widget.l10n.t('common.projectCount', {
                  'count': myProjects.length,
                }),
                value: '$selected',
                icon: Icons.workspace_premium_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: widget.l10n.t('contractor.estimatedEarnings'),
                value: widget.l10n.rupeesLabel(earnings.toStringAsFixed(0)),
                color: const Color(0xFF166534),
                background: const Color(0xFFDCFCE7),
                icon: Icons.currency_rupee_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(user.fullName),
                subtitle: Text(user.company ?? ''),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.email')),
                subtitle: Text(user.email),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.phone')),
                subtitle: Text(user.phone),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.registration')),
                subtitle: Text(user.registrationId ?? ''),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.rating')),
                subtitle: Text('${user.rating ?? 0}/5'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openBidDialog(BuildContext context, Issue issue) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.l10n.t('contractor.submitBid')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.l10n.t('contractor.bidAmount'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.l10n.t('contractor.proposalNote'),
                ),
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
                if (amount == null) {
                  return;
                }
                final user = widget.store.currentUser!;
                widget.store.addBid(
                  Bid(
                    id: 'bid-${DateTime.now().microsecondsSinceEpoch}',
                    issueId: issue.id,
                    contractorId: user.id,
                    contractorName: user.company ?? user.fullName,
                    bidAmount: amount,
                    proposalNote: noteController.text.trim(),
                    status: 'submitted',
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

  Future<void> _uploadCompletionProof(Issue issue) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    widget.store.updateAfterImage(issue.id, file.path);
  }
}
