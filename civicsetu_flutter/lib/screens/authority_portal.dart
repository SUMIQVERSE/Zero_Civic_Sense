import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class AuthorityPortalScreen extends StatefulWidget {
  const AuthorityPortalScreen({
    super.key,
    required this.store,
    required this.l10n,
  });

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<AuthorityPortalScreen> createState() => _AuthorityPortalScreenState();
}

class _AuthorityPortalScreenState extends State<AuthorityPortalScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final issues = widget.store.issues;
    final awaitingVerification = issues
        .where(
          (issue) => issue.status == IssueStatus.awaitingCitizenVerification,
        )
        .length;
    final topStates = widget.store.stateQualityRatings.take(5).toList();

    return DefaultTabController(
      length: 4,
      initialIndex: _tabIndex,
      child: PortalScaffold(
        store: widget.store,
        l10n: widget.l10n,
        title: widget.l10n.t('authority.title'),
        child: Column(
          children: [
            TabBar(
              onTap: (value) => setState(() => _tabIndex = value),
              isScrollable: true,
              tabs: [
                Tab(text: widget.l10n.t('authority.dashboard')),
                Tab(text: widget.l10n.t('authority.issues')),
                Tab(text: widget.l10n.t('authority.bids')),
                Tab(text: widget.l10n.t('authority.ngo')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          StatCard(
                            label: widget.l10n.t('common.total'),
                            value: '${issues.length}',
                            icon: Icons.assignment_outlined,
                          ),
                          StatCard(
                            label: widget.l10n.t('common.active'),
                            value:
                                '${issues.where((i) => i.status != IssueStatus.resolved).length}',
                            color: const Color(0xFF1D4ED8),
                            background: const Color(0xFFE0E7FF),
                            icon: Icons.sync_rounded,
                          ),
                          StatCard(
                            label: widget.l10n.t('common.resolved'),
                            value:
                                '${issues.where((i) => i.status == IssueStatus.resolved).length}',
                            color: const Color(0xFF166534),
                            background: const Color(0xFFDCFCE7),
                            icon: Icons.check_circle_outline,
                          ),
                          StatCard(
                            label: widget.l10n.statusLabel(
                              IssueStatus.awaitingCitizenVerification,
                            ),
                            value: '$awaitingVerification',
                            color: const Color(0xFFB45309),
                            background: const Color(0xFFFFEDD5),
                            icon: Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.l10n.t('authority.quality'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...topStates.map((rating) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(widget.l10n.stateName(rating.state)),
                            subtitle: Text(
                              widget.l10n.t(
                                'authority.resolutionTrustSummary',
                                {
                                  'resolved': rating.resolutionRate,
                                  'trust': rating.trustRate,
                                },
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${rating.qualityScore}/100',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  widget.l10n.qualityBandLabel(
                                    rating.qualityBand,
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  _buildIssuesTab(context),
                  _buildBidsTab(context),
                  _buildNgoTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesTab(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.store.issues.length,
      itemBuilder: (context, index) {
        final issue = widget.store.issues[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _openIssueSheet(context, issue),
            title: Text(
              issue.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${widget.l10n.categoryLabel(issue.category)} - ${widget.l10n.statusLabel(issue.status)}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        );
      },
    );
  }

  Widget _buildBidsTab(BuildContext context) {
    final openIssues = widget.store.issues
        .where((issue) => issue.status == IssueStatus.openForBidding)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: openIssues.map((issue) {
        final bids = widget.store.bidsFor(issue.id);
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
                if (bids.isEmpty)
                  Text(widget.l10n.t('authority.noBidsYet'))
                else
                  ...bids.map(
                    (bid) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${bid.contractorName} - ${widget.l10n.rupeesLabel(bid.bidAmount.toStringAsFixed(0))}',
                      ),
                      subtitle: Text(bid.proposalNote),
                      trailing: bid.status == 'submitted'
                          ? FilledButton(
                              onPressed: () => widget.store.selectBid(
                                bid.id,
                                issue.id,
                                bid.contractorId,
                              ),
                              child: Text(widget.l10n.t('authority.selectBid')),
                            )
                          : Text(widget.l10n.workflowStatusLabel(bid.status)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNgoTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: widget.store.ngoRequests.map((request) {
        final issue = widget.store.issues.firstWhere(
          (entry) => entry.id == request.issueId,
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
                const SizedBox(height: 6),
                Text(request.ngoName),
                const SizedBox(height: 12),
                if (request.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => widget.store.updateNgoRequest(
                            request.id,
                            request.ngoId,
                            request.issueId,
                            'approved',
                          ),
                          child: Text(widget.l10n.t('common.approved')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => widget.store.updateNgoRequest(
                            request.id,
                            request.ngoId,
                            request.issueId,
                            'rejected',
                          ),
                          child: Text(widget.l10n.t('common.rejected')),
                        ),
                      ),
                    ],
                  )
                else
                  InfoPill(
                    label: widget.l10n.workflowStatusLabel(request.status),
                    color: request.status == 'approved'
                        ? const Color(0xFF166534)
                        : const Color(0xFFB91C1C),
                    background: request.status == 'approved'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openIssueSheet(BuildContext context, Issue issue) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AuthorityIssueSheet(
          store: widget.store,
          l10n: widget.l10n,
          issueId: issue.id,
        );
      },
    );
  }
}

class _AuthorityIssueSheet extends StatefulWidget {
  const _AuthorityIssueSheet({
    required this.store,
    required this.l10n,
    required this.issueId,
  });

  final AppStore store;
  final AppLocalizations l10n;
  final String issueId;

  @override
  State<_AuthorityIssueSheet> createState() => _AuthorityIssueSheetState();
}

class _AuthorityIssueSheetState extends State<_AuthorityIssueSheet> {
  String? _proofPath;

  @override
  Widget build(BuildContext context) {
    final issue = widget.store.issues.firstWhere(
      (entry) => entry.id == widget.issueId,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              issue.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(issue.description),
            const SizedBox(height: 12),
            AppImage(source: issue.beforeImage),
            const SizedBox(height: 12),
            if (issue.afterImage != null) ...[
              Text(widget.l10n.t('common.resolutionProof')),
              const SizedBox(height: 8),
              AppImage(source: issue.afterImage!),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoPill(label: widget.l10n.statusLabel(issue.status)),
                InfoPill(label: widget.l10n.categoryLabel(issue.category)),
                if (issue.duplicateCount > 1)
                  InfoPill(
                    label: widget.l10n.t('common.raisedCount', {
                      'count': issue.duplicateCount,
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(widget.l10n.t('authority.uploadProof')),
            ),
            if (_proofPath != null) ...[
              const SizedBox(height: 12),
              AppImage(source: _proofPath!, height: 160),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  widget.store.submitResolutionProof(issue.id, _proofPath!);
                  Navigator.pop(context);
                },
                child: Text(
                  widget.l10n.t('authority.sendForCitizenVerification'),
                ),
              ),
            ],
            if (issue.isRatingFrozen && issue.flaggedReviewBatch != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.l10n.t('authority.ratingFrozenSummary', {
                  'count': issue.flaggedReviewBatch!.reviewsInBatch,
                }),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.store.reviewFlaggedBatch(issue.id, 'approve');
                        Navigator.pop(context);
                      },
                      child: Text(widget.l10n.t('authority.freezeApprove')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.store.reviewFlaggedBatch(issue.id, 'reject');
                        Navigator.pop(context);
                      },
                      child: Text(widget.l10n.t('authority.freezeReject')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            CommentSection(
              store: widget.store,
              l10n: widget.l10n,
              issue: issue,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    setState(() => _proofPath = file.path);
  }
}
