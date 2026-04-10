import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _languageStorageKey = 'civicsetu.language';
const _themeStorageKey = 'civicsetu.darkMode';
const _alertsStorageKey = 'civicsetu.alerts';
const _autoLocationStorageKey = 'civicsetu.autoLocation';
const _aiAssistStorageKey = 'civicsetu.aiAssist';

String _newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

DateTime _d(int month, int day, [int hour = 10, int minute = 0]) {
  return DateTime(2026, month, day, hour, minute);
}

String _normalize(String value) {
  final cleaned = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Set<String> _tokens(String value) =>
    _normalize(value).split(' ').where((part) => part.length > 2).toSet();

double _similarity(String left, String right) {
  final a = _tokens(left);
  final b = _tokens(right);
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  final intersection = a.where(b.contains).length;
  final union = {...a, ...b}.length;
  return union == 0 ? 0 : intersection / union;
}

double _rad(double value) => value * (pi / 180);

double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final deltaLat = _rad(lat2 - lat1);
  final deltaLng = _rad(lng2 - lng1);
  final haversine = sin(deltaLat / 2) * sin(deltaLat / 2) +
      sin(deltaLng / 2) * sin(deltaLng / 2) * cos(_rad(lat1)) * cos(_rad(lat2));
  return 2 * earthRadiusKm * atan2(sqrt(haversine), sqrt(1 - haversine));
}

bool _sameLocation(Issue a, Issue b) {
  if (_normalize(a.state) != _normalize(b.state) ||
      _normalize(a.city) != _normalize(b.city)) {
    return false;
  }
  if (a.latitude != null &&
      a.longitude != null &&
      b.latitude != null &&
      b.longitude != null &&
      _distanceKm(a.latitude!, a.longitude!, b.latitude!, b.longitude!) <=
          0.35) {
    return true;
  }
  return _similarity(a.address, b.address) >= 0.6;
}

Issue? _findDuplicate(List<Issue> issues, Issue incoming) {
  Issue? best;
  var bestScore = 0.0;
  for (final issue in issues) {
    if (issue.status == IssueStatus.resolved ||
        issue.category != incoming.category ||
        !_sameLocation(issue, incoming)) {
      continue;
    }
    final score = _similarity(
      '${issue.title} ${issue.description}',
      '${incoming.title} ${incoming.description}',
    );
    if (score >= 0.65 && score > bestScore) {
      best = issue;
      bestScore = score;
    }
  }
  return best;
}

class _SpikeMetrics {
  const _SpikeMetrics({
    required this.events,
    required this.count,
    required this.expectedDailyReviews,
    required this.threshold,
    required this.shouldFreeze,
  });

  final List<IssueReviewEvent> events;
  final int count;
  final double expectedDailyReviews;
  final int threshold;
  final bool shouldFreeze;
}

_SpikeMetrics _spikeMetrics(
  Issue issue,
  List<IssueReviewEvent> reviewEvents,
  int nextUpvotes,
  int nextDownvotes,
  DateTime now,
) {
  const hourMs = 60 * 60 * 1000;
  const dayMs = 24 * 60 * 60 * 1000;
  final recent = reviewEvents
      .where(
        (event) =>
            now.millisecondsSinceEpoch -
                event.createdAt.millisecondsSinceEpoch <=
            hourMs,
      )
      .toList();
  final totalReviews = nextUpvotes + nextDownvotes;
  final ageMs = max(
    now.millisecondsSinceEpoch - issue.createdAt.millisecondsSinceEpoch,
    dayMs,
  );
  final historicalDays = max(((ageMs - hourMs) / dayMs).round(), 1);
  final historicalReviews = max(totalReviews - recent.length, 0);
  final expectedDailyReviews = historicalReviews / historicalDays;
  final threshold = max(20, (max(expectedDailyReviews, 1) * 10).ceil());
  return _SpikeMetrics(
    events: recent,
    count: recent.length,
    expectedDailyReviews: roundToSingleDecimal(expectedDailyReviews),
    threshold: threshold,
    shouldFreeze: recent.length >= threshold,
  );
}

class AppStore extends ChangeNotifier {
  AppStore()
      : _users = _usersSeed,
        _issues = _issuesSeed,
        _bids = _bidsSeed,
        _ngoRequests = _ngoRequestsSeed,
        _donations = _donationsSeed,
        _comments = _commentsSeed;

  final List<AppUser> _users;
  List<Issue> _issues;
  List<Bid> _bids;
  List<NgoRequest> _ngoRequests;
  List<Donation> _donations;
  List<IssueComment> _comments;

  AppUser? _currentUser;
  AppLanguage _language = AppLanguage.en;
  bool _isDarkMode = false;
  bool _alertsEnabled = true;
  bool _autoLocationEnabled = true;
  bool _aiAssistEnabled = true;
  int _citizenInitialTabIndex = 0;
  PendingComplaintCapture? _pendingComplaintCapture;

  List<AppUser> get users => List.unmodifiable(_users);
  List<Issue> get issues => List.unmodifiable(_issues);
  List<Bid> get bids => List.unmodifiable(_bids);
  List<NgoRequest> get ngoRequests => List.unmodifiable(_ngoRequests);
  List<Donation> get donations => List.unmodifiable(_donations);
  List<IssueComment> get comments => List.unmodifiable(_comments);
  AppUser? get currentUser => _currentUser;
  AppLanguage get language => _language;
  bool get isDarkMode => _isDarkMode;
  bool get alertsEnabled => _alertsEnabled;
  bool get autoLocationEnabled => _autoLocationEnabled;
  bool get aiAssistEnabled => _aiAssistEnabled;
  int get citizenInitialTabIndex => _citizenInitialTabIndex;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageStorageKey);
    var changed = false;
    if (stored != null) {
      _language = AppLanguageX.fromCode(stored);
      changed = true;
    }
    _isDarkMode = prefs.getBool(_themeStorageKey) ?? _isDarkMode;
    _alertsEnabled = prefs.getBool(_alertsStorageKey) ?? _alertsEnabled;
    _autoLocationEnabled =
        prefs.getBool(_autoLocationStorageKey) ?? _autoLocationEnabled;
    _aiAssistEnabled = prefs.getBool(_aiAssistStorageKey) ?? _aiAssistEnabled;
    if (changed || stored == null) {
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageStorageKey, language.code);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeStorageKey, value);
    notifyListeners();
  }

  Future<void> setAlertsEnabled(bool value) async {
    _alertsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertsStorageKey, value);
    notifyListeners();
  }

  Future<void> setAutoLocationEnabled(bool value) async {
    _autoLocationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLocationStorageKey, value);
    notifyListeners();
  }

  Future<void> setAiAssistEnabled(bool value) async {
    _aiAssistEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiAssistStorageKey, value);
    notifyListeners();
  }

  void loginAs(UserRole role, {int citizenInitialTabIndex = 0}) {
    _currentUser = _users.firstWhere((user) => user.role == role);
    _citizenInitialTabIndex =
        role == UserRole.citizen ? citizenInitialTabIndex : 0;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _citizenInitialTabIndex = 0;
    _pendingComplaintCapture = null;
    notifyListeners();
  }

  void stageComplaintCapture(PendingComplaintCapture capture) {
    _pendingComplaintCapture = capture;
  }

  PendingComplaintCapture? takePendingComplaintCapture() {
    final capture = _pendingComplaintCapture;
    _pendingComplaintCapture = null;
    return capture;
  }

  AddIssueResult addIssue(Issue issue) {
    final duplicate = _findDuplicate(_issues, issue);
    if (duplicate == null) {
      _issues = [issue, ..._issues];
      notifyListeners();
      return AddIssueResult(
        duplicateCount: issue.duplicateCount,
        issueId: issue.id,
        merged: false,
      );
    }
    final raised = duplicate.duplicateCount + 1;
    _issues = _issues.map((existing) {
      if (existing.id != duplicate.id) {
        return existing;
      }
      return existing.copyWith(
        duplicateCount: raised,
        isDuplicate: true,
        address: existing.address.length >= issue.address.length
            ? existing.address
            : issue.address,
        latitude: existing.latitude ?? issue.latitude,
        longitude: existing.longitude ?? issue.longitude,
      );
    }).toList();
    notifyListeners();
    return AddIssueResult(
      duplicateCount: raised,
      issueId: duplicate.id,
      merged: true,
    );
  }

  void updateAfterImage(String issueId, String imagePath) {
    _issues = _issues
        .map(
          (issue) => issue.id == issueId
              ? issue.copyWith(afterImage: imagePath)
              : issue,
        )
        .toList();
    notifyListeners();
  }

  void submitResolutionProof(String issueId, String imagePath) {
    _issues = _issues
        .map(
          (issue) => issue.id == issueId
              ? issue.copyWith(
                  afterImage: imagePath,
                  status: IssueStatus.awaitingCitizenVerification,
                )
              : issue,
        )
        .toList();
    notifyListeners();
  }

  void verifyIssueResolution(String issueId, bool isVerified) {
    _issues = _issues
        .map(
          (issue) => issue.id == issueId
              ? issue.copyWith(
                  status: isVerified
                      ? IssueStatus.resolved
                      : IssueStatus.inProgress,
                )
              : issue,
        )
        .toList();
    notifyListeners();
  }

  void addBid(Bid bid) {
    _bids = [bid, ..._bids];
    notifyListeners();
  }

  void selectBid(String bidId, String issueId, String contractorId) {
    _bids = _bids
        .map(
          (bid) => bid.issueId == issueId
              ? bid.copyWith(status: bid.id == bidId ? 'selected' : 'rejected')
              : bid,
        )
        .toList();
    _issues = _issues
        .map(
          (issue) => issue.id == issueId
              ? issue.copyWith(
                  status: IssueStatus.inProgress,
                  assignedContractor: contractorId,
                )
              : issue,
        )
        .toList();
    notifyListeners();
  }

  void addNgoRequest(NgoRequest request) {
    _ngoRequests = [request, ..._ngoRequests];
    notifyListeners();
  }

  void updateNgoRequest(
    String requestId,
    String ngoId,
    String issueId,
    String status,
  ) {
    _ngoRequests = _ngoRequests
        .map(
          (request) => request.id == requestId
              ? request.copyWith(status: status)
              : request,
        )
        .toList();
    if (status == 'approved') {
      _issues = _issues
          .map(
            (issue) => issue.id == issueId
                ? issue.copyWith(
                    assignedNgo: ngoId,
                    status: IssueStatus.inProgress,
                  )
                : issue,
          )
          .toList();
    }
    notifyListeners();
  }

  void voteOnIssue(String issueId, VoteType voteType) {
    _issues = _issues.map((issue) {
      if (issue.id != issueId) {
        return issue;
      }
      final now = DateTime.now();
      final review = IssueReviewEvent(
        id: _newId('review'),
        type: voteType,
        createdAt: now,
      );
      final nextUpvotes =
          voteType == VoteType.upvote ? issue.upvotes + 1 : issue.upvotes;
      final nextDownvotes =
          voteType == VoteType.downvote ? issue.downvotes + 1 : issue.downvotes;
      final nextEvents = [...issue.reviewEvents, review];
      final suspicious = nextDownvotes >= 6;

      if (issue.isRatingFrozen && issue.flaggedReviewBatch != null) {
        final ids = issue.flaggedReviewBatch!.reviewIds.contains(review.id)
            ? issue.flaggedReviewBatch!.reviewIds
            : [...issue.flaggedReviewBatch!.reviewIds, review.id];
        return issue.copyWith(
          upvotes: nextUpvotes,
          downvotes: nextDownvotes,
          isSuspicious: suspicious,
          reviewEvents: nextEvents,
          flaggedReviewBatch: issue.flaggedReviewBatch!.copyWith(
            reviewIds: ids,
            reviewsInBatch: ids.length,
            windowEndedAt: now,
          ),
        );
      }

      final metrics = _spikeMetrics(
        issue,
        nextEvents,
        nextUpvotes,
        nextDownvotes,
        now,
      );
      if (metrics.shouldFreeze) {
        return issue.copyWith(
          upvotes: nextUpvotes,
          downvotes: nextDownvotes,
          isSuspicious: suspicious,
          isRatingFrozen: true,
          reviewEvents: nextEvents,
          flaggedReviewBatch: FlaggedReviewBatch(
            id: _newId('batch-${issue.id}'),
            reviewIds: metrics.events.map((event) => event.id).toList(),
            windowStartedAt:
                metrics.events.isEmpty ? now : metrics.events.first.createdAt,
            windowEndedAt: now,
            reviewsInBatch: metrics.count,
            expectedDailyReviews: metrics.expectedDailyReviews,
            triggerThreshold: metrics.threshold,
            frozenScore: issue.overallRatingScore,
          ),
        );
      }

      return issue.copyWith(
        upvotes: nextUpvotes,
        downvotes: nextDownvotes,
        isSuspicious: suspicious,
        reviewEvents: nextEvents,
        overallRatingScore: calculateIssueRatingScore(
          nextUpvotes,
          nextDownvotes,
        ),
      );
    }).toList();
    notifyListeners();
  }

  void reviewFlaggedBatch(String issueId, String decision) {
    _issues = _issues.map((issue) {
      if (issue.id != issueId || issue.flaggedReviewBatch == null) {
        return issue;
      }
      if (decision == 'approve') {
        return issue.copyWith(
          isRatingFrozen: false,
          overallRatingScore: calculateIssueRatingScore(
            issue.upvotes,
            issue.downvotes,
          ),
          clearFlaggedBatch: true,
        );
      }
      final flaggedIds = issue.flaggedReviewBatch!.reviewIds.toSet();
      final removed =
          issue.reviewEvents.where((e) => flaggedIds.contains(e.id)).toList();
      final remaining =
          issue.reviewEvents.where((e) => !flaggedIds.contains(e.id)).toList();
      final upRemoved = removed.where((e) => e.type == VoteType.upvote).length;
      final downRemoved =
          removed.where((e) => e.type == VoteType.downvote).length;
      final nextUpvotes = max(0, issue.upvotes - upRemoved);
      final nextDownvotes = max(0, issue.downvotes - downRemoved);
      return issue.copyWith(
        upvotes: nextUpvotes,
        downvotes: nextDownvotes,
        isSuspicious: nextDownvotes >= 6,
        overallRatingScore: calculateIssueRatingScore(
          nextUpvotes,
          nextDownvotes,
        ),
        isRatingFrozen: false,
        reviewEvents: remaining,
        clearFlaggedBatch: true,
      );
    }).toList();
    notifyListeners();
  }

  void addComment(IssueComment comment) {
    _comments = [..._comments, comment];
    notifyListeners();
  }

  void addDonation(Donation donation) {
    _donations = [donation, ..._donations];
    notifyListeners();
  }

  void rateContractor(String issueId, double rating) {
    _issues = _issues
        .map(
          (issue) => issue.id == issueId
              ? issue.copyWith(contractorRating: rating)
              : issue,
        )
        .toList();
    notifyListeners();
  }

  List<IssueComment> commentsFor(String issueId) =>
      _comments.where((comment) => comment.issueId == issueId).toList();

  List<Bid> bidsFor(String issueId) =>
      _bids.where((bid) => bid.issueId == issueId).toList();

  List<StateQualityRating> get stateQualityRatings {
    final grouped = <String, List<Issue>>{};
    for (final issue in _issues) {
      grouped.putIfAbsent(issue.state, () => []).add(issue);
    }
    final ratings = grouped.entries.map((entry) {
      final issues = entry.value;
      final total = issues.length;
      final resolved =
          issues.where((issue) => issue.status == IssueStatus.resolved).length;
      final awaiting = issues
          .where(
            (issue) => issue.status == IssueStatus.awaitingCitizenVerification,
          )
          .length;
      final suspicious = issues.where((issue) => issue.isSuspicious).length;
      final ratingPool = issues
          .where((issue) => issue.status == IssueStatus.resolved)
          .toList();
      final source = ratingPool.isEmpty ? issues : ratingPool;
      final avg = source.isEmpty
          ? 0.0
          : source
                  .map(
                    (issue) =>
                        issue.contractorRating ?? issue.overallRatingScore,
                  )
                  .reduce((a, b) => a + b) /
              source.length;
      final resolutionRate = total == 0 ? 0.0 : resolved / total;
      final trustRate = total == 0 ? 1.0 : max(0.0, 1 - suspicious / total);
      final waitPenalty = total == 0 ? 0.0 : awaiting / total;
      final quality = roundToSingleDecimal(
        ((resolutionRate * 0.5) +
                    ((avg / 5).clamp(0, 1) * 0.25) +
                    (trustRate * 0.15) +
                    ((1 - waitPenalty) * 0.1)) *
                100 *
                min(1.0, total / 4) +
            50 * (1 - min(1.0, total / 4)),
      );
      final band = quality >= 85
          ? 'Excellent'
          : quality >= 70
              ? 'Strong'
              : quality >= 55
                  ? 'Fair'
                  : 'Needs Attention';
      return StateQualityRating(
        state: entry.key,
        totalIssues: total,
        resolvedIssues: resolved,
        unresolvedIssues: total - resolved,
        awaitingVerificationIssues: awaiting,
        suspiciousIssues: suspicious,
        averageRating: roundToSingleDecimal(avg),
        resolutionRate: roundToSingleDecimal(resolutionRate * 100),
        trustRate: roundToSingleDecimal(trustRate * 100),
        qualityScore: quality,
        qualityBand: band,
      );
    }).toList();
    ratings.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return ratings;
  }
}

const _imgPothole =
    'https://images.unsplash.com/photo-1709934730506-fba12664d4e4?w=800&q=80';
const _imgWater =
    'https://images.unsplash.com/photo-1639335875048-a14e75abc083?w=800&q=80';
const _imgLight =
    'https://images.unsplash.com/photo-1640362790728-c2bd0dfa9f33?w=800&q=80';
const _imgGarbage =
    'https://images.unsplash.com/photo-1762805544399-7cdf748371e0?w=800&q=80';
const _imgRoadAfter =
    'https://images.unsplash.com/photo-1645698406985-20f411b4937d?w=800&q=80';
const _imgWaterAfter =
    'https://images.unsplash.com/photo-1769263092692-8bdce7a125de?w=800&q=80';
const _imgLightAfter =
    'https://images.unsplash.com/photo-1694408614727-0a05c1019777?w=800&q=80';

final List<AppUser> _usersSeed = [
  const AppUser(
    id: 'u1',
    fullName: 'Ramesh Kumar',
    email: 'ramesh@example.com',
    phone: '+91 98765 43210',
    role: UserRole.citizen,
    trustCode: 'JM-CIT-2026-001',
    state: 'Delhi',
    city: 'New Delhi',
  ),
  const AppUser(
    id: 'u2',
    fullName: 'Priya Sharma',
    email: 'priya@dmc.gov.in',
    phone: '+91 11 2345 6789',
    role: UserRole.authority,
    state: 'Delhi',
    city: 'New Delhi',
  ),
  const AppUser(
    id: 'u3',
    fullName: 'Suresh Patel',
    email: 'suresh@buildtech.com',
    phone: '+91 99001 12345',
    role: UserRole.contractor,
    company: 'BuildTech Solutions Pvt. Ltd.',
    registrationId: 'CON-2026-BT-0042',
    rating: 4.3,
    state: 'Delhi',
    city: 'New Delhi',
  ),
  const AppUser(
    id: 'u4',
    fullName: 'Meena Joshi',
    email: 'meena@greenindia.org',
    phone: '+91 80 4567 8901',
    role: UserRole.ngo,
    ngoName: 'Green India Foundation',
    registrationId: 'NGO-REG-2026-0077',
    rating: 4.7,
    state: 'Karnataka',
    city: 'Bangalore',
  ),
];

final List<Issue> _issuesSeed = [
  Issue(
    id: 'i1',
    title: 'Deep Pothole on MG Road',
    description: 'Large pothole near Connaught Place causing accidents.',
    category: IssueCategory.road,
    status: IssueStatus.resolved,
    state: 'Delhi',
    city: 'New Delhi',
    address: 'MG Road, near Connaught Place',
    createdBy: 'u1',
    assignedContractor: 'u3',
    assignedNgo: null,
    beforeImage: _imgPothole,
    afterImage: _imgRoadAfter,
    urgencyTag: UrgencyTag.high,
    upvotes: 34,
    downvotes: 2,
    overallRatingScore: calculateIssueRatingScore(34, 2),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: 4,
    createdAt: _d(1, 15),
  ),
  Issue(
    id: 'i2',
    title: 'Garbage Pile at Dadar Market',
    description: 'Garbage accumulation near Dadar vegetable market.',
    category: IssueCategory.sanitation,
    status: IssueStatus.resolved,
    state: 'Maharashtra',
    city: 'Mumbai',
    address: 'Near Dadar Vegetable Market, Dadar West',
    createdBy: 'u1',
    assignedContractor: null,
    assignedNgo: 'u4',
    beforeImage: _imgGarbage,
    afterImage: _imgWaterAfter,
    urgencyTag: UrgencyTag.high,
    upvotes: 28,
    downvotes: 1,
    overallRatingScore: calculateIssueRatingScore(28, 1),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: 5,
    createdAt: _d(1, 20, 8, 30),
  ),
  Issue(
    id: 'i3',
    title: 'Water Pipe Burst near Whitefield Metro',
    description: 'Burst water pipe causing waterlogging and disruption.',
    category: IssueCategory.water,
    status: IssueStatus.resolved,
    state: 'Karnataka',
    city: 'Bangalore',
    address: 'Near Whitefield Metro Station, Whitefield',
    createdBy: 'u1',
    assignedContractor: 'u3',
    assignedNgo: null,
    beforeImage: _imgWater,
    afterImage: _imgWaterAfter,
    urgencyTag: UrgencyTag.high,
    upvotes: 45,
    downvotes: 0,
    overallRatingScore: calculateIssueRatingScore(45, 0),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: 4,
    createdAt: _d(1, 25, 12),
  ),
  Issue(
    id: 'i4',
    title: 'Broken Streetlight at Anna Nagar',
    description: 'Streetlights are not working for two weeks.',
    category: IssueCategory.electricity,
    status: IssueStatus.resolved,
    state: 'Tamil Nadu',
    city: 'Chennai',
    address: '2nd Main Road, Anna Nagar West',
    createdBy: 'u1',
    assignedContractor: 'u3',
    assignedNgo: null,
    beforeImage: _imgLight,
    afterImage: _imgLightAfter,
    urgencyTag: UrgencyTag.medium,
    upvotes: 19,
    downvotes: 1,
    overallRatingScore: calculateIssueRatingScore(19, 1),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: 5,
    createdAt: _d(2, 1, 9),
  ),
  Issue(
    id: 'i5',
    title: 'Large Pothole on NH-48 Expressway',
    description: 'Critical pothole on NH-48 within Pune city limits.',
    category: IssueCategory.road,
    status: IssueStatus.inProgress,
    state: 'Maharashtra',
    city: 'Pune',
    address: 'NH-48, near Hinjewadi Junction, Pune',
    createdBy: 'u1',
    assignedContractor: 'u3',
    assignedNgo: null,
    beforeImage: _imgPothole,
    afterImage: null,
    urgencyTag: UrgencyTag.high,
    upvotes: 67,
    downvotes: 4,
    overallRatingScore: calculateIssueRatingScore(67, 4),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: null,
    createdAt: _d(2, 15, 10, 30),
  ),
  Issue(
    id: 'i6',
    title: 'Garbage Dumping near Begumpet Hospital',
    description: 'Unauthorized garbage dump near hospital zone.',
    category: IssueCategory.sanitation,
    status: IssueStatus.inProgress,
    state: 'Telangana',
    city: 'Hyderabad',
    address: 'Near Begumpet Hospital, Secunderabad',
    createdBy: 'u1',
    assignedContractor: null,
    assignedNgo: 'u4',
    beforeImage: _imgGarbage,
    afterImage: null,
    urgencyTag: UrgencyTag.high,
    upvotes: 112,
    downvotes: 5,
    overallRatingScore: calculateIssueRatingScore(112, 5),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: null,
    createdAt: _d(2, 22, 9, 15),
  ),
  Issue(
    id: 'i7',
    title: 'Major Pothole near Rajiv Chowk Metro',
    description: 'Deep pothole near Rajiv Chowk Metro exit.',
    category: IssueCategory.road,
    status: IssueStatus.openForBidding,
    state: 'Delhi',
    city: 'New Delhi',
    address: 'Near Rajiv Chowk Metro Exit 5, Connaught Place',
    createdBy: 'u1',
    assignedContractor: null,
    assignedNgo: null,
    beforeImage: _imgPothole,
    afterImage: null,
    urgencyTag: UrgencyTag.high,
    upvotes: 145,
    downvotes: 2,
    overallRatingScore: calculateIssueRatingScore(145, 2),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: null,
    createdAt: _d(3, 1, 9),
  ),
  Issue(
    id: 'i8',
    title: 'Broken Electricity Pole near BTM School',
    description: 'Damaged high tension pole near school footpath.',
    category: IssueCategory.electricity,
    status: IssueStatus.openForBidding,
    state: 'Karnataka',
    city: 'Bangalore',
    address: 'BTM Layout 2nd Stage, near BTM School',
    createdBy: 'u1',
    assignedContractor: null,
    assignedNgo: null,
    beforeImage: _imgLight,
    afterImage: null,
    urgencyTag: UrgencyTag.high,
    upvotes: 203,
    downvotes: 1,
    overallRatingScore: calculateIssueRatingScore(203, 1),
    isRatingFrozen: false,
    flaggedReviewBatch: null,
    reviewEvents: const [],
    duplicateCount: 1,
    isSuspicious: false,
    isDuplicate: false,
    contractorRating: null,
    createdAt: _d(3, 10, 8),
  ),
];

final List<Bid> _bidsSeed = [
  Bid(
    id: 'b1',
    issueId: 'i1',
    contractorId: 'u3',
    contractorName: 'BuildTech Solutions',
    bidAmount: 50000,
    proposalNote: 'Will repair using M30 grade concrete and drainage.',
    status: 'selected',
    createdAt: _d(1, 16, 10),
  ),
  Bid(
    id: 'b2',
    issueId: 'i5',
    contractorId: 'u3',
    contractorName: 'BuildTech Solutions',
    bidAmount: 75000,
    proposalNote: 'Full road patch repair within 3 days.',
    status: 'selected',
    createdAt: _d(2, 17, 11),
  ),
  Bid(
    id: 'b3',
    issueId: 'i7',
    contractorId: 'u3',
    contractorName: 'BuildTech Solutions',
    bidAmount: 120000,
    proposalNote: 'Comprehensive pothole and surface repair.',
    status: 'submitted',
    createdAt: _d(3, 2, 10),
  ),
];

final List<NgoRequest> _ngoRequestsSeed = [
  NgoRequest(
    id: 'nr1',
    issueId: 'i2',
    ngoId: 'u4',
    ngoName: 'Green India Foundation',
    status: 'approved',
    createdAt: _d(1, 21, 9),
  ),
  NgoRequest(
    id: 'nr2',
    issueId: 'i6',
    ngoId: 'u4',
    ngoName: 'Green India Foundation',
    status: 'approved',
    createdAt: _d(2, 23, 8),
  ),
  NgoRequest(
    id: 'nr3',
    issueId: 'i8',
    ngoId: 'u4',
    ngoName: 'Green India Foundation',
    status: 'pending',
    createdAt: _d(3, 16, 10),
  ),
];

final List<Donation> _donationsSeed = [
  Donation(
    id: 'd1',
    ngoId: 'u4',
    donorName: 'Anonymous',
    amount: 25000,
    message: 'Keep up the great work for our community.',
    createdAt: _d(2, 1, 10),
  ),
  Donation(
    id: 'd2',
    ngoId: 'u4',
    donorName: 'Ratan Patel',
    amount: 50000,
    message: 'Proud to support Green India Foundation.',
    createdAt: _d(2, 10, 14),
  ),
  Donation(
    id: 'd3',
    ngoId: 'u4',
    donorName: 'Infosys CSR Fund',
    amount: 100000,
    message: 'CSR support for urban civic improvement.',
    createdAt: _d(3, 1, 11),
  ),
];

final List<IssueComment> _commentsSeed = [
  IssueComment(
    id: 'c1',
    issueId: 'i7',
    userId: 'u1',
    userName: 'Ramesh Kumar',
    content: 'I hit my scooter in this pothole yesterday.',
    createdAt: _d(3, 2, 8),
  ),
  IssueComment(
    id: 'c2',
    issueId: 'i7',
    userId: 'u2',
    userName: 'Authority Office',
    content: 'We have sent this issue for bidding today.',
    createdAt: _d(3, 2, 11),
  ),
  IssueComment(
    id: 'c3',
    issueId: 'i8',
    userId: 'u1',
    userName: 'Ramesh Kumar',
    content: 'This is extremely dangerous for children.',
    createdAt: _d(3, 10, 9),
  ),
  IssueComment(
    id: 'c4',
    issueId: 'i8',
    userId: 'u2',
    userName: 'Authority Office',
    content: 'Safety barrier placed and repair team dispatched.',
    createdAt: _d(3, 10, 14),
  ),
];
