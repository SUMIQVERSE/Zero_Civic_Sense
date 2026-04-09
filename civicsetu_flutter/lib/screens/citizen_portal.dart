import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';
import '../services/auto_report_service.dart';
import '../utils/location_service.dart';
import '../widgets/common_widgets.dart';
import 'complaint_camera_screen.dart';

class CitizenPortalScreen extends StatefulWidget {
  const CitizenPortalScreen({
    super.key,
    required this.store,
    required this.l10n,
  });

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<CitizenPortalScreen> createState() => _CitizenPortalScreenState();
}

class _CitizenPortalScreenState extends State<CitizenPortalScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _chatController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Set<String> _votedIssues = <String>{};
  final AutoReportService _autoReportService = AutoReportService();
  late final TabController _tabController;

  IssueCategory _category = IssueCategory.road;
  UrgencyTag _urgencyTag = UrgencyTag.high;
  bool _isRecording = false;
  bool _detectingLocation = false;
  bool _analyzingAutoReport = false;
  bool _programmaticDraftUpdate = false;
  String? _imagePath;
  String? _analysisError;
  AutoReportDraft? _autoReportDraft;
  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  int? _autoSubmitCountdown;
  int _tabIndex = 0;
  int _analysisToken = 0;
  Timer? _autoSubmitTimer;

  bool get _isAutoSubmitArmed =>
      _autoSubmitTimer != null && (_autoSubmitCountdown ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    final user = widget.store.currentUser;
    _stateController.text = user?.state ?? '';
    _cityController.text = user?.city ?? '';
    for (final controller in [
      _titleController,
      _descriptionController,
      _stateController,
      _cityController,
      _addressController,
    ]) {
      controller.addListener(_handleManualDraftEdit);
    }
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _chatController.dispose();
    _tabController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser!;
    final myIssues = widget.store.issues
        .where((issue) => issue.createdBy == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PortalScaffold(
      store: widget.store,
      l10n: widget.l10n,
      title: widget.l10n.t('citizen.title'),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openComplaintCamera,
        backgroundColor: const Color(0xFFE8821C),
        foregroundColor: Colors.white,
        tooltip: widget.l10n.t('camera.open'),
        child: const Icon(Icons.photo_camera_rounded, size: 34),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            onTap: (value) => setState(() => _tabIndex = value),
            isScrollable: true,
            tabs: [
              Tab(text: widget.l10n.t('citizen.issues')),
              Tab(text: widget.l10n.t('citizen.report')),
              Tab(text: widget.l10n.t('citizen.chat')),
              Tab(text: widget.l10n.t('citizen.profile')),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIssuesTab(context, myIssues),
                _buildReportTab(context),
                _buildChatTab(),
                _buildProfileTab(context, myIssues.length),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesTab(BuildContext context, List<Issue> myIssues) {
    if (myIssues.isEmpty) {
      return Center(child: Text(widget.l10n.t('citizen.noIssues')));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: myIssues.length,
      itemBuilder: (context, index) {
        final issue = myIssues[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppImage(source: issue.beforeImage, height: 160),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoPill(
                      label: widget.l10n.statusLabel(issue.status),
                      color: const Color(0xFF0F766E),
                      background: const Color(0xFFDCFCE7),
                    ),
                    InfoPill(
                      label: widget.l10n.categoryLabel(issue.category),
                      color: const Color(0xFF1D4ED8),
                      background: const Color(0xFFE0E7FF),
                    ),
                    InfoPill(
                      label: widget.l10n.urgencyLabel(issue.urgencyTag),
                      color: const Color(0xFFB91C1C),
                      background: const Color(0xFFFEE2E2),
                    ),
                    if (issue.duplicateCount > 1)
                      InfoPill(
                        label: widget.l10n.t('common.raisedCount', {
                          'count': issue.duplicateCount,
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  issue.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(issue.description),
                const SizedBox(height: 12),
                Text(
                  '${issue.city}, ${widget.l10n.stateName(issue.state)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (issue.isRatingFrozen &&
                    issue.flaggedReviewBatch != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.l10n.t('citizen.ratingFrozenSummary', {
                      'score': issue.flaggedReviewBatch!.frozenScore,
                      'count': issue.flaggedReviewBatch!.reviewsInBatch,
                    }),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _votedIssues.contains(issue.id)
                            ? null
                            : () {
                                widget.store.voteOnIssue(
                                  issue.id,
                                  VoteType.upvote,
                                );
                                setState(() => _votedIssues.add(issue.id));
                              },
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        label: Text(
                          '${widget.l10n.t('common.up')} ${issue.upvotes}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _votedIssues.contains(issue.id)
                            ? null
                            : () {
                                widget.store.voteOnIssue(
                                  issue.id,
                                  VoteType.downvote,
                                );
                                setState(() => _votedIssues.add(issue.id));
                              },
                        icon: const Icon(Icons.thumb_down_alt_outlined),
                        label: Text(
                          '${widget.l10n.t('common.down')} ${issue.downvotes}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => _showIssueDetails(context, issue),
                    child: Text(widget.l10n.t('common.viewDetails')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportTab(BuildContext context) {
    final autoReportCard = _buildAutoReportReviewCard();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(
          widget.l10n.t('citizen.newIssue'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: widget.l10n.t('citizen.issueTitle'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<IssueCategory>(
          initialValue: _category,
          decoration: InputDecoration(
            labelText: widget.l10n.t('common.category'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          items: IssueCategory.values
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(widget.l10n.categoryLabel(category)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              if (_isAutoSubmitArmed && !_programmaticDraftUpdate) {
                _pauseAutoSubmit();
              }
              setState(() => _category = value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.l10n.t('citizen.description'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _toggleVoiceRecording,
              icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_none),
              label: Text(
                _isRecording
                    ? widget.l10n.t('citizen.stopRecording')
                    : widget.l10n.t('citizen.startRecording'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.my_location),
              label: Text(widget.l10n.t('citizen.useCurrentLocation')),
            ),
            OutlinedButton.icon(
              onPressed: _openComplaintCamera,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(widget.l10n.t('camera.open')),
            ),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(widget.l10n.t('common.pickImage')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isRecording)
          Text(widget.l10n.t('citizen.recording'))
        else if (_detectingLocation)
          Text(widget.l10n.t('citizen.detectingLocation'))
        else if (_imagePath != null)
          Text(
            widget.l10n.t('camera.photoAttached'),
            style: const TextStyle(color: Color(0xFF0F766E)),
          )
        else if (_latitude != null && _longitude != null)
          Text(
            '${widget.l10n.t('citizen.locationReady')} (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})',
          ),
        if (autoReportCard != null) ...[
          const SizedBox(height: 16),
          autoReportCard,
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _stateController,
          decoration: _fieldDecoration(widget.l10n.t('common.state')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityController,
          decoration: _fieldDecoration(widget.l10n.t('common.city')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: _fieldDecoration(widget.l10n.t('common.address')),
        ),
        const SizedBox(height: 16),
        if (_imagePath != null) ...[
          AppImage(source: _imagePath!, height: 180),
          const SizedBox(height: 16),
        ],
        if (_latitude != null && _longitude != null)
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_latitude!, _longitude!),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.civicsetu.mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_latitude!, _longitude!),
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFE11D48),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_accuracyMeters != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.l10n.t('citizen.accuracyMeters', {
              'meters': _accuracyMeters!.round(),
            }),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _submitIssue,
          icon: const Icon(Icons.send_rounded),
          label: Text(widget.l10n.t('citizen.submitIssue')),
        ),
      ],
    );
  }

  Widget? _buildAutoReportReviewCard() {
    final shouldShowFallbackCard = _imagePath != null &&
        !_autoReportService.isConfigured &&
        !_analyzingAutoReport &&
        _analysisError == null &&
        _autoReportDraft == null;
    final shouldShow = shouldShowFallbackCard ||
        _analyzingAutoReport ||
        _analysisError != null ||
        _autoReportDraft != null;
    if (!shouldShow) {
      return null;
    }

    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.l10n.t('citizen.aiReady'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_analyzingAutoReport) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(widget.l10n.t('citizen.aiAnalyzing')),
            ] else if (shouldShowFallbackCard) ...[
              Text(widget.l10n.t('citizen.aiUnavailable')),
            ] else if (_analysisError != null) ...[
              Text(
                _analysisError!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _retryAutoReportAnalysis,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(widget.l10n.t('citizen.aiRetry')),
              ),
            ] else if (_autoReportDraft != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(
                    label:
                        '${widget.l10n.t('citizen.aiConfidence')} ${(100 * _autoReportDraft!.confidence).round()}%',
                    color: const Color(0xFF0F766E),
                    background: const Color(0xFFDCFCE7),
                  ),
                  InfoPill(
                    label: widget.l10n.urgencyLabel(_autoReportDraft!.urgency),
                    color: const Color(0xFFB91C1C),
                    background: const Color(0xFFFEE2E2),
                  ),
                  InfoPill(
                    label: _autoReportDraft!.providerLabel,
                    color: const Color(0xFF1D4ED8),
                    background: const Color(0xFFE0E7FF),
                  ),
                  InfoPill(
                    label: widget.l10n.issueTypeLabel(
                      _autoReportDraft!.specificIssueType,
                    ),
                    color: const Color(0xFF4C1D95),
                    background: const Color(0xFFF3E8FF),
                  ),
                  if (_autoSubmitCountdown != null)
                    InfoPill(
                      label: widget.l10n.t('citizen.aiAutoSubmitIn', {
                        'seconds': _autoSubmitCountdown,
                      }),
                      color: const Color(0xFF92400E),
                      background: const Color(0xFFFEF3C7),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.l10n.t('citizen.aiSummary'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(_autoReportDraft!.summary),
              const SizedBox(height: 12),
              if (!_autoReportDraft!.isCivicIssue) ...[
                Text(
                  widget.l10n.t('citizen.aiNotCivic'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.l10n.t('citizen.aiNeedClearPhoto')),
                const SizedBox(height: 12),
              ],
              Text(
                widget.l10n.t('citizen.aiReasoning'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(_autoReportDraft!.reasoning),
              if (_autoReportDraft!.detectedObjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.l10n.t('citizen.aiObjects'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _autoReportDraft!.detectedObjects
                      .map((object) => InfoPill(label: object))
                      .toList(),
                ),
              ],
              if (_autoReportDraft!.needsManualReview) ...[
                const SizedBox(height: 12),
                Text(
                  widget.l10n.t('citizen.aiManualReview'),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_isAutoSubmitArmed)
                    OutlinedButton.icon(
                      onPressed: _pauseAutoSubmit,
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(widget.l10n.t('citizen.aiEditBeforeSubmit')),
                    ),
                  if (_autoReportDraft!.isCivicIssue)
                    FilledButton.icon(
                      onPressed: () => _submitIssue(),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(widget.l10n.t('citizen.aiSubmitNow')),
                    ),
                  OutlinedButton.icon(
                    onPressed: _retryAutoReportAnalysis,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(widget.l10n.t('citizen.aiRetry')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final youLabel = widget.l10n.t('common.you');
    final supportLabel = widget.l10n.t('citizen.chatSupport');
    final bubbles = [
      (
        supportLabel,
        widget.l10n.t('citizen.chatWelcome'),
      ),
      (youLabel, widget.l10n.t('citizen.chatQuestionVerification')),
      (
        supportLabel,
        widget.l10n.t('citizen.chatAnswerVerification'),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        ...bubbles.map(
          (bubble) => Align(
            alignment: bubble.$1 == youLabel
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color:
                    bubble.$1 == youLabel
                        ? const Color(0xFF0B1C2D)
                        : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                bubble.$2,
                style: TextStyle(
                  color: bubble.$1 == youLabel
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _chatController,
          decoration: InputDecoration(
            hintText: widget.l10n.t('citizen.messagePlaceholder'),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.send_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context, int issueCount) {
    final user = widget.store.currentUser!;
    final resolvedCount = widget.store.issues
        .where(
          (issue) =>
              issue.createdBy == user.id &&
              issue.status == IssueStatus.resolved,
        )
        .length;
    final activeCount = widget.store.issues
        .where(
          (issue) =>
              issue.createdBy == user.id &&
              issue.status != IssueStatus.resolved,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        StatCard(
          label: widget.l10n.t('common.issueCount', {'count': issueCount}),
          value: '$issueCount',
          icon: Icons.report_problem_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: widget.l10n.t('common.resolved'),
                value: '$resolvedCount',
                background: const Color(0xFFDCFCE7),
                color: const Color(0xFF166534),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: widget.l10n.t('common.active'),
                value: '$activeCount',
                background: const Color(0xFFE0E7FF),
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: Text(
              user.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${user.city}, ${widget.l10n.stateName(user.state ?? '')}',
            ),
            trailing: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF0F766E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(widget.l10n.t('common.email')),
                subtitle: Text(user.email),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.phone')),
                subtitle: Text(user.phone),
              ),
              ListTile(
                title: Text(widget.l10n.t('common.trustCode')),
                subtitle: Text(
                  user.trustCode ?? widget.l10n.t('common.notAvailable'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _openComplaintCamera() async {
    final result = await Navigator.of(context).push<ComplaintCameraResult>(
      MaterialPageRoute(
        builder: (context) => ComplaintCameraScreen(l10n: widget.l10n),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await _handleSelectedImage(
      imagePath: result.imagePath,
      locationDraft: result.locationDraft,
    );
  }

  void _goToReportTab() {
    setState(() => _tabIndex = 1);
    _tabController.animateTo(1);
  }

  void _handleManualDraftEdit() {
    if (_programmaticDraftUpdate || !_isAutoSubmitArmed) {
      return;
    }
    _pauseAutoSubmit();
  }

  void _applyLocationDraft(
    LocationDraft draft, {
    bool pauseAutoSubmit = false,
  }) {
    if (pauseAutoSubmit && _isAutoSubmitArmed) {
      _pauseAutoSubmit();
    }
    _programmaticDraftUpdate = true;
    setState(() {
      _latitude = draft.latitude;
      _longitude = draft.longitude;
      _accuracyMeters = draft.accuracyMeters;
      if (draft.state.isNotEmpty) {
        _stateController.text = draft.state;
      }
      if (draft.city.isNotEmpty) {
        _cityController.text = draft.city;
      }
      if (draft.address.isNotEmpty) {
        _addressController.text = draft.address;
      }
    });
    _programmaticDraftUpdate = false;
  }

  LocationDraft? _currentLocationDraft() {
    if (_latitude == null || _longitude == null) {
      return null;
    }
    return LocationDraft(
      latitude: _latitude!,
      longitude: _longitude!,
      state: _stateController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      accuracyMeters: _accuracyMeters ?? 0,
    );
  }

  Future<void> _handleSelectedImage({
    required String imagePath,
    LocationDraft? locationDraft,
  }) async {
    _cancelAutoSubmit(clearDraft: true);
    if (locationDraft != null) {
      _applyLocationDraft(locationDraft);
    }
    setState(() {
      _imagePath = imagePath;
      _analysisError = null;
      _autoReportDraft = null;
      _analyzingAutoReport = _autoReportService.isConfigured;
      _urgencyTag = UrgencyTag.high;
    });
    _goToReportTab();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
        SnackBar(content: Text(widget.l10n.t('camera.photoAttached'))));
    if (_autoReportService.isConfigured) {
      await _runAutoReportAnalysis();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result == null) {
      return;
    }
    await _handleSelectedImage(imagePath: result.path);
  }

  Future<void> _retryAutoReportAnalysis() async {
    if (_imagePath == null) {
      return;
    }
    await _runAutoReportAnalysis();
  }

  Future<void> _runAutoReportAnalysis() async {
    final imagePath = _imagePath;
    final user = widget.store.currentUser;
    if (imagePath == null || user == null) {
      return;
    }

    final currentToken = ++_analysisToken;
    _cancelAutoSubmit(clearDraft: true);
    setState(() {
      _analyzingAutoReport = true;
      _analysisError = null;
    });

    try {
      final draft = await _autoReportService.analyzeComplaintCapture(
        imagePath: imagePath,
        language: widget.store.language,
        user: user,
        locationDraft: _currentLocationDraft(),
      );
      if (!mounted || currentToken != _analysisToken) {
        return;
      }
      _applyAutoReportDraft(draft);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.l10n.t('citizen.aiReady'))));
    } catch (error) {
      if (!mounted || currentToken != _analysisToken) {
        return;
      }
      setState(() {
        _analysisError = '$error';
      });
    } finally {
      if (mounted && currentToken == _analysisToken) {
        setState(() => _analyzingAutoReport = false);
      }
    }
  }

  void _applyAutoReportDraft(AutoReportDraft draft) {
    _programmaticDraftUpdate = true;
    if (draft.isCivicIssue) {
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
    }
    setState(() {
      if (draft.shouldUpdateCategory) {
        _category = draft.category;
      }
      _urgencyTag = draft.urgency;
      _analysisError = null;
      _autoReportDraft = draft;
    });
    _programmaticDraftUpdate = false;

    if (draft.autoSubmitRecommended &&
        !draft.needsManualReview &&
        draft.reviewWindowSeconds > 0) {
      _startAutoSubmitCountdown(draft.reviewWindowSeconds);
    }
  }

  void _startAutoSubmitCountdown(int seconds) {
    _cancelAutoSubmit(showMessage: false);
    if (seconds <= 0) {
      _submitIssue(autoSubmitted: true);
      return;
    }

    setState(() => _autoSubmitCountdown = seconds);
    _autoSubmitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_autoSubmitCountdown ?? 0) - 1;
      if (next <= 0) {
        timer.cancel();
        _autoSubmitTimer = null;
        _submitIssue(autoSubmitted: true);
        return;
      }
      setState(() => _autoSubmitCountdown = next);
    });
  }

  void _pauseAutoSubmit() {
    final hadCountdown = _isAutoSubmitArmed;
    _cancelAutoSubmit(showMessage: false);
    if (!hadCountdown || !mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.l10n.t('citizen.aiPaused'))));
  }

  void _cancelAutoSubmit({
    bool showMessage = false,
    bool clearDraft = false,
  }) {
    _autoSubmitTimer?.cancel();
    _autoSubmitTimer = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _autoSubmitCountdown = null;
      if (clearDraft) {
        _autoReportDraft = null;
      }
    });
    if (showMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text(widget.l10n.t('citizen.aiPaused'))));
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _speech.stop();
      setState(() => _isRecording = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.t('citizen.voiceFailed'))),
      );
      return;
    }
    setState(() => _isRecording = true);
    await _speech.listen(
      localeId: widget.store.language.speechLocale,
      onResult: (result) {
        _programmaticDraftUpdate = true;
        setState(() {
          _descriptionController.text = result.recognizedWords;
        });
        _programmaticDraftUpdate = false;
      },
    );
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final draft = await resolveCurrentLocation(
        permissionDeniedMessage: widget.l10n.t('msg.permissionDenied'),
        locationUnavailableMessage: widget.l10n.t('msg.locationUnavailable'),
        serviceDisabledMessage: widget.l10n.t('msg.locationServiceDisabled'),
        userAgent: 'com.civicsetu.mobile',
      );
      _applyLocationDraft(draft, pauseAutoSubmit: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  void _submitIssue({bool autoSubmitted = false}) {
    final user = widget.store.currentUser!;
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.t('citizen.requiredFields'))),
      );
      return;
    }
    final issue = Issue(
      id: 'issue-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      status: IssueStatus.openForBidding,
      state: _stateController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      createdBy: user.id,
      assignedContractor: null,
      assignedNgo: null,
      beforeImage: _imagePath ?? _sampleImageFor(_category),
      afterImage: null,
      urgencyTag: _urgencyTag,
      upvotes: 0,
      downvotes: 0,
      overallRatingScore: 0,
      isRatingFrozen: false,
      flaggedReviewBatch: null,
      reviewEvents: const [],
      duplicateCount: 1,
      isSuspicious: false,
      isDuplicate: false,
      contractorRating: null,
      createdAt: DateTime.now(),
    );
    final result = widget.store.addIssue(issue);
    final message = result.merged
        ? widget.l10n.t('citizen.duplicateMerged', {
            'count': result.duplicateCount,
          })
        : autoSubmitted
            ? widget.l10n.t('citizen.autoSubmitted')
            : widget.l10n.t('citizen.submitted');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    _cancelAutoSubmit(clearDraft: true);
    _analysisError = null;
    _analyzingAutoReport = false;
    _urgencyTag = UrgencyTag.high;
    _titleController.clear();
    _descriptionController.clear();
    _addressController.clear();
    setState(() {
      _imagePath = null;
      _latitude = null;
      _longitude = null;
      _accuracyMeters = null;
      _tabIndex = 0;
    });
    _tabController.animateTo(0);
  }

  String _sampleImageFor(IssueCategory category) {
    return switch (category) {
      IssueCategory.road =>
        'https://images.unsplash.com/photo-1709934730506-fba12664d4e4?w=800&q=80',
      IssueCategory.water =>
        'https://images.unsplash.com/photo-1639335875048-a14e75abc083?w=800&q=80',
      IssueCategory.electricity =>
        'https://images.unsplash.com/photo-1640362790728-c2bd0dfa9f33?w=800&q=80',
      IssueCategory.sanitation =>
        'https://images.unsplash.com/photo-1762805544399-7cdf748371e0?w=800&q=80',
    };
  }

  Future<void> _showIssueDetails(BuildContext context, Issue issue) async {
    final ratingValue = ValueNotifier<double>(issue.contractorRating ?? 4);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final currentIssue = widget.store.issues.firstWhere(
              (entry) => entry.id == issue.id,
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
                      currentIssue.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(currentIssue.description),
                    const SizedBox(height: 12),
                    AppImage(source: currentIssue.beforeImage),
                    const SizedBox(height: 12),
                    if (currentIssue.afterImage != null) ...[
                      Text(
                        widget.l10n.t('common.resolutionProof'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      AppImage(source: currentIssue.afterImage!),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${widget.l10n.t('common.communityRating')}: ${currentIssue.overallRatingScore}/5',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (currentIssue.isRatingFrozen &&
                        currentIssue.flaggedReviewBatch != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.l10n.t('citizen.ratingFrozenAfter', {
                          'count':
                              currentIssue.flaggedReviewBatch!.reviewsInBatch,
                        }),
                        style: const TextStyle(color: Color(0xFF92400E)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (currentIssue.status ==
                        IssueStatus.awaitingCitizenVerification) ...[
                      FilledButton(
                        onPressed: () {
                          widget.store.verifyIssueResolution(
                            currentIssue.id,
                            true,
                          );
                          Navigator.pop(context);
                        },
                        child: Text(widget.l10n.t('citizen.verifyClose')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          widget.store.verifyIssueResolution(
                            currentIssue.id,
                            false,
                          );
                          Navigator.pop(context);
                        },
                        child: Text(widget.l10n.t('citizen.notSolved')),
                      ),
                    ],
                    if (currentIssue.status == IssueStatus.resolved &&
                        currentIssue.assignedContractor != null) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<double>(
                        valueListenable: ratingValue,
                        builder: (context, value, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.l10n.t('citizen.rateExperience')),
                              Slider(
                                value: value,
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: value.toStringAsFixed(0),
                                onChanged: (next) => ratingValue.value = next,
                              ),
                              FilledButton(
                                onPressed: () => widget.store.rateContractor(
                                  currentIssue.id,
                                  value,
                                ),
                                child: Text(
                                  widget.l10n.t('citizen.saveRating'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    CommentSection(
                      store: widget.store,
                      l10n: widget.l10n,
                      issue: currentIssue,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
