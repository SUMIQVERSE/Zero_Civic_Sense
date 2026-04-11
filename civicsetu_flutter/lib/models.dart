import 'dart:io';

enum UserRole { citizen, authority, contractor, ngo }

enum AppAuthMode { demo, supabase }

enum IssueCategory { road, water, electricity, sanitation }

enum IssueStatus {
  openForBidding,
  inProgress,
  awaitingCitizenVerification,
  resolved,
}

enum VoteType { upvote, downvote }

enum UrgencyTag { high, medium, low }

enum AppLanguage { en, hi, ta, mr, kn }

extension UserRoleX on UserRole {
  String get key => switch (this) {
        UserRole.citizen => 'citizen',
        UserRole.authority => 'authority',
        UserRole.contractor => 'contractor',
        UserRole.ngo => 'ngo',
      };
}

extension IssueCategoryX on IssueCategory {
  String get key => switch (this) {
        IssueCategory.road => 'road',
        IssueCategory.water => 'water',
        IssueCategory.electricity => 'electricity',
        IssueCategory.sanitation => 'sanitation',
      };
}

extension IssueStatusX on IssueStatus {
  String get key => switch (this) {
        IssueStatus.openForBidding => 'open_for_bidding',
        IssueStatus.inProgress => 'in_progress',
        IssueStatus.awaitingCitizenVerification =>
          'awaiting_citizen_verification',
        IssueStatus.resolved => 'resolved',
      };
}

extension VoteTypeX on VoteType {
  String get key => switch (this) {
        VoteType.upvote => 'upvote',
        VoteType.downvote => 'downvote',
      };
}

extension UrgencyTagX on UrgencyTag {
  String get key => switch (this) {
        UrgencyTag.high => 'high',
        UrgencyTag.medium => 'medium',
        UrgencyTag.low => 'low',
      };
}

extension AppLanguageX on AppLanguage {
  String get code => switch (this) {
        AppLanguage.en => 'en',
        AppLanguage.hi => 'hi',
        AppLanguage.ta => 'ta',
        AppLanguage.mr => 'mr',
        AppLanguage.kn => 'kn',
      };

  String get label => switch (this) {
        AppLanguage.en => 'EN',
        AppLanguage.hi => 'हि',
        AppLanguage.ta => 'த',
        AppLanguage.mr => 'म',
        AppLanguage.kn => 'ಕ',
      };

  String get speechLocale => switch (this) {
        AppLanguage.en => 'en_IN',
        AppLanguage.hi => 'hi_IN',
        AppLanguage.ta => 'ta_IN',
        AppLanguage.mr => 'mr_IN',
        AppLanguage.kn => 'kn_IN',
      };

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.en,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.trustCode,
    this.company,
    this.ngoName,
    this.state,
    this.city,
    this.address,
    this.registrationId,
    this.rating,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? trustCode;
  final String? company;
  final String? ngoName;
  final String? state;
  final String? city;
  final String? address;
  final String? registrationId;
  final double? rating;

  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? trustCode,
    String? company,
    String? ngoName,
    String? state,
    String? city,
    String? address,
    String? registrationId,
    double? rating,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      trustCode: trustCode ?? this.trustCode,
      company: company ?? this.company,
      ngoName: ngoName ?? this.ngoName,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      registrationId: registrationId ?? this.registrationId,
      rating: rating ?? this.rating,
    );
  }
}

class ProfileSetupDraft {
  const ProfileSetupDraft({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.role,
    this.state = '',
    this.city = '',
    this.address = '',
    this.organizationName = '',
    this.registrationId = '',
  });

  final String fullName;
  final String email;
  final String phone;
  final UserRole? role;
  final String state;
  final String city;
  final String address;
  final String organizationName;
  final String registrationId;

  ProfileSetupDraft copyWith({
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? state,
    String? city,
    String? address,
    String? organizationName,
    String? registrationId,
  }) {
    return ProfileSetupDraft(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      organizationName: organizationName ?? this.organizationName,
      registrationId: registrationId ?? this.registrationId,
    );
  }

  bool get needsOrganizationName =>
      role == UserRole.contractor || role == UserRole.ngo;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      role != null &&
      state.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      (!needsOrganizationName || organizationName.trim().isNotEmpty);
}

class IssueReviewEvent {
  const IssueReviewEvent({
    required this.id,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final VoteType type;
  final DateTime createdAt;
}

class FlaggedReviewBatch {
  const FlaggedReviewBatch({
    required this.id,
    required this.reviewIds,
    required this.windowStartedAt,
    required this.windowEndedAt,
    required this.reviewsInBatch,
    required this.expectedDailyReviews,
    required this.triggerThreshold,
    required this.frozenScore,
  });

  final String id;
  final List<String> reviewIds;
  final DateTime windowStartedAt;
  final DateTime windowEndedAt;
  final int reviewsInBatch;
  final double expectedDailyReviews;
  final int triggerThreshold;
  final double frozenScore;

  FlaggedReviewBatch copyWith({
    String? id,
    List<String>? reviewIds,
    DateTime? windowStartedAt,
    DateTime? windowEndedAt,
    int? reviewsInBatch,
    double? expectedDailyReviews,
    int? triggerThreshold,
    double? frozenScore,
  }) {
    return FlaggedReviewBatch(
      id: id ?? this.id,
      reviewIds: reviewIds ?? this.reviewIds,
      windowStartedAt: windowStartedAt ?? this.windowStartedAt,
      windowEndedAt: windowEndedAt ?? this.windowEndedAt,
      reviewsInBatch: reviewsInBatch ?? this.reviewsInBatch,
      expectedDailyReviews: expectedDailyReviews ?? this.expectedDailyReviews,
      triggerThreshold: triggerThreshold ?? this.triggerThreshold,
      frozenScore: frozenScore ?? this.frozenScore,
    );
  }
}

class Issue {
  const Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.state,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
    required this.createdBy,
    required this.assignedContractor,
    required this.assignedNgo,
    required this.beforeImage,
    required this.afterImage,
    required this.urgencyTag,
    required this.upvotes,
    required this.downvotes,
    required this.overallRatingScore,
    required this.isRatingFrozen,
    required this.flaggedReviewBatch,
    required this.reviewEvents,
    required this.duplicateCount,
    required this.isSuspicious,
    required this.isDuplicate,
    required this.contractorRating,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final IssueCategory category;
  final IssueStatus status;
  final String state;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;
  final String createdBy;
  final String? assignedContractor;
  final String? assignedNgo;
  final String beforeImage;
  final String? afterImage;
  final UrgencyTag urgencyTag;
  final int upvotes;
  final int downvotes;
  final double overallRatingScore;
  final bool isRatingFrozen;
  final FlaggedReviewBatch? flaggedReviewBatch;
  final List<IssueReviewEvent> reviewEvents;
  final int duplicateCount;
  final bool isSuspicious;
  final bool isDuplicate;
  final double? contractorRating;
  final DateTime createdAt;

  Issue copyWith({
    String? id,
    String? title,
    String? description,
    IssueCategory? category,
    IssueStatus? status,
    String? state,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    String? createdBy,
    String? assignedContractor,
    String? assignedNgo,
    String? beforeImage,
    String? afterImage,
    UrgencyTag? urgencyTag,
    int? upvotes,
    int? downvotes,
    double? overallRatingScore,
    bool? isRatingFrozen,
    FlaggedReviewBatch? flaggedReviewBatch,
    List<IssueReviewEvent>? reviewEvents,
    int? duplicateCount,
    bool? isSuspicious,
    bool? isDuplicate,
    double? contractorRating,
    DateTime? createdAt,
    bool clearFlaggedBatch = false,
    bool clearAfterImage = false,
  }) {
    return Issue(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      assignedContractor: assignedContractor ?? this.assignedContractor,
      assignedNgo: assignedNgo ?? this.assignedNgo,
      beforeImage: beforeImage ?? this.beforeImage,
      afterImage: clearAfterImage ? null : afterImage ?? this.afterImage,
      urgencyTag: urgencyTag ?? this.urgencyTag,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      overallRatingScore: overallRatingScore ?? this.overallRatingScore,
      isRatingFrozen: isRatingFrozen ?? this.isRatingFrozen,
      flaggedReviewBatch: clearFlaggedBatch
          ? null
          : flaggedReviewBatch ?? this.flaggedReviewBatch,
      reviewEvents: reviewEvents ?? this.reviewEvents,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      isSuspicious: isSuspicious ?? this.isSuspicious,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      contractorRating: contractorRating ?? this.contractorRating,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Bid {
  const Bid({
    required this.id,
    required this.issueId,
    required this.contractorId,
    required this.contractorName,
    required this.bidAmount,
    required this.proposalNote,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final String contractorId;
  final String contractorName;
  final double bidAmount;
  final String proposalNote;
  final String status;
  final DateTime createdAt;

  Bid copyWith({
    String? id,
    String? issueId,
    String? contractorId,
    String? contractorName,
    double? bidAmount,
    String? proposalNote,
    String? status,
    DateTime? createdAt,
  }) {
    return Bid(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      contractorId: contractorId ?? this.contractorId,
      contractorName: contractorName ?? this.contractorName,
      bidAmount: bidAmount ?? this.bidAmount,
      proposalNote: proposalNote ?? this.proposalNote,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NgoRequest {
  const NgoRequest({
    required this.id,
    required this.issueId,
    required this.ngoId,
    required this.ngoName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final String ngoId;
  final String ngoName;
  final String status;
  final DateTime createdAt;

  NgoRequest copyWith({
    String? id,
    String? issueId,
    String? ngoId,
    String? ngoName,
    String? status,
    DateTime? createdAt,
  }) {
    return NgoRequest(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      ngoId: ngoId ?? this.ngoId,
      ngoName: ngoName ?? this.ngoName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Donation {
  const Donation({
    required this.id,
    required this.ngoId,
    required this.donorName,
    required this.amount,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String ngoId;
  final String donorName;
  final double amount;
  final String message;
  final DateTime createdAt;
}

class IssueComment {
  const IssueComment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
}

class AddIssueResult {
  const AddIssueResult({
    required this.duplicateCount,
    required this.issueId,
    required this.merged,
  });

  final int duplicateCount;
  final String issueId;
  final bool merged;
}

class StateQualityRating {
  const StateQualityRating({
    required this.state,
    required this.totalIssues,
    required this.resolvedIssues,
    required this.unresolvedIssues,
    required this.awaitingVerificationIssues,
    required this.suspiciousIssues,
    required this.averageRating,
    required this.resolutionRate,
    required this.trustRate,
    required this.qualityScore,
    required this.qualityBand,
  });

  final String state;
  final int totalIssues;
  final int resolvedIssues;
  final int unresolvedIssues;
  final int awaitingVerificationIssues;
  final int suspiciousIssues;
  final double averageRating;
  final double resolutionRate;
  final double trustRate;
  final double qualityScore;
  final String qualityBand;
}

class PendingComplaintCapture {
  const PendingComplaintCapture({
    required this.imagePath,
    required this.locationDraft,
  });

  final String imagePath;
  final LocationDraft? locationDraft;
}

class LocationDraft {
  const LocationDraft({
    required this.latitude,
    required this.longitude,
    required this.state,
    required this.city,
    required this.address,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final String state;
  final String city;
  final String address;
  final double accuracyMeters;
}

double roundToSingleDecimal(double value) => (value * 10).round() / 10;

double calculateIssueRatingScore(int upvotes, int downvotes) {
  final totalVotes = upvotes + downvotes;
  if (totalVotes == 0) {
    return 0;
  }
  return roundToSingleDecimal((upvotes / totalVotes) * 5);
}

IssueCategory issueCategoryFromKey(String value) {
  switch (value.trim().toLowerCase()) {
    case 'road':
      return IssueCategory.road;
    case 'water':
      return IssueCategory.water;
    case 'electricity':
      return IssueCategory.electricity;
    case 'sanitation':
      return IssueCategory.sanitation;
    default:
      return IssueCategory.road;
  }
}

IssueStatus issueStatusFromKey(String value) {
  switch (value.trim().toLowerCase()) {
    case 'in_progress':
      return IssueStatus.inProgress;
    case 'awaiting_citizen_verification':
      return IssueStatus.awaitingCitizenVerification;
    case 'resolved':
      return IssueStatus.resolved;
    case 'open_for_bidding':
    default:
      return IssueStatus.openForBidding;
  }
}

UserRole? userRoleFromKey(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'citizen':
      return UserRole.citizen;
    case 'authority':
      return UserRole.authority;
    case 'contractor':
      return UserRole.contractor;
    case 'ngo':
      return UserRole.ngo;
    default:
      return null;
  }
}

UrgencyTag urgencyTagFromKey(String value) {
  switch (value.trim().toLowerCase()) {
    case 'low':
      return UrgencyTag.low;
    case 'medium':
      return UrgencyTag.medium;
    case 'high':
    default:
      return UrgencyTag.high;
  }
}

bool isNetworkResource(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

bool isLocalFileResource(String value) =>
    !isNetworkResource(value) && File(value).existsSync();

String formatShortDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';
