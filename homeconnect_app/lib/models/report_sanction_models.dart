/// Modèles pour Signalements et Sanctions utilisateurs/propriétés
library;

/// Type de signalement
enum ReportType {
  fraudulentListing, // Annonce frauduleuse
  inappropriateContent, // Contenu inapproprié
  abusiveUser, // Utilisateur abusif
  fakePics, // Fausses images
  scam, // Escroquerie
  spam, // Spam
  unsafeMeeting, // Rencontre dangereuse
  unwantedContact, // Contact non désiré
  discriminatory, // Discrimination
  other, // Autre
}

/// Priorité du signalement
enum ReportPriority { low, medium, high, critical }

/// Statut du signalement
enum ReportStatus {
  open, // Ouvert
  inReview, // En révision
  approved, // Approuvé
  rejected, // Rejeté
  resolved, // Résolu
}

/// Sanction appliquée
enum SanctionType {
  warning, // Avertissement
  suspension3Days, // Suspension 3 jours
  suspension7Days, // Suspension 7 jours
  suspension30Days, // Suspension 30 jours
  banned, // Banni permanemment
}

/// Signalement d'un utilisateur ou propriété
class Report {
  final int id;
  final int reporterId; // Qui signale
  final int targetUserId; // Utilisateur signalé
  final int? targetPropertyId; // Propriété signalée (optionnel)
  final ReportType type;
  final ReportPriority priority;
  final ReportStatus status;
  final String title;
  final String description;
  final List<String> attachmentUrls; // Photos/preuves
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int? reviewedBy; // Admin qui a revu
  final String? reviewNotes;
  final bool hasEscalated; // Escaladé à modération
  final String? ownerReply; // Réponse du propriétaire ciblé
  final DateTime? ownerReplyAt; // Date de la réponse

  Report({
    required this.id,
    required this.reporterId,
    required this.targetUserId,
    this.targetPropertyId,
    required this.type,
    required this.priority,
    required this.status,
    required this.title,
    required this.description,
    required this.attachmentUrls,
    required this.createdAt,
    this.resolvedAt,
    this.reviewedBy,
    this.reviewNotes,
    required this.hasEscalated,
    this.ownerReply,
    this.ownerReplyAt,
  });

  /// Obtenir label du type lisible
  String get typeLabel {
    switch (type) {
      case ReportType.fraudulentListing:
        return 'Annonce frauduleuse';
      case ReportType.inappropriateContent:
        return 'Contenu inapproprié';
      case ReportType.abusiveUser:
        return 'Utilisateur abusif';
      case ReportType.fakePics:
        return 'Fausses images';
      case ReportType.scam:
        return 'Escroquerie';
      case ReportType.spam:
        return 'Spam';
      case ReportType.unsafeMeeting:
        return 'Rencontre dangereuse';
      case ReportType.unwantedContact:
        return 'Contact non désiré';
      case ReportType.discriminatory:
        return 'Discrimination';
      case ReportType.other:
        return 'Autre';
    }
  }

  /// Obtenir couleur priorité
  String get priorityColor {
    switch (priority) {
      case ReportPriority.low:
        return '#4CAF50'; // Green
      case ReportPriority.medium:
        return '#FFC107'; // Amber
      case ReportPriority.high:
        return '#FF9800'; // Orange
      case ReportPriority.critical:
        return '#F44336'; // Red
    }
  }

  /// Jours écoulés depuis le signalement
  int get daysSinceReport {
    return DateTime.now().difference(createdAt).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterId': reporterId,
        'targetUserId': targetUserId,
        'targetPropertyId': targetPropertyId,
        'type': type.toString(),
        'priority': priority.toString(),
        'status': status.toString(),
        'title': title,
        'description': description,
        'attachmentUrls': attachmentUrls,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
        'hasEscalated': hasEscalated,
        'ownerReply': ownerReply,
        'ownerReplyAt': ownerReplyAt?.toIso8601String(),
      };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'],
        reporterId: json['reporterId'],
        targetUserId: json['targetUserId'],
        targetPropertyId: json['targetPropertyId'],
        type: ReportType.values.firstWhere((e) => e.toString() == json['type']),
        priority: ReportPriority.values
            .firstWhere((e) => e.toString() == json['priority']),
        status: ReportStatus.values
            .firstWhere((e) => e.toString() == json['status']),
        title: json['title'],
        description: json['description'],
        attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
        createdAt: DateTime.parse(json['createdAt']),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'])
            : null,
        reviewedBy: json['reviewedBy'],
        reviewNotes: json['reviewNotes'],
        hasEscalated: json['hasEscalated'] ?? false,
        ownerReply: json['ownerReply'],
        ownerReplyAt: json['ownerReplyAt'] != null
            ? DateTime.parse(json['ownerReplyAt'])
            : null,
      );
}

/// Sanction appliquée à un utilisateur
class Sanction {
  final int id;
  final int userId;
  final SanctionType type;
  final String reason; // Raison de la sanction
  final DateTime appliedAt;
  final DateTime? expiresAt; // Null si permanent
  final int appliedBy; // Admin ID
  final String? notes;
  final bool isActive;
  final int? reportsCount; // Nombre de rapports ayant mené à cette sanction
  final String? appealReason; // Raison d'appel si en appel
  final bool? appealApproved; // Appel approuvé?

  Sanction({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    required this.appliedAt,
    this.expiresAt,
    required this.appliedBy,
    this.notes,
    required this.isActive,
    this.reportsCount,
    this.appealReason,
    this.appealApproved,
  });

  /// Vérifier si la sanction est toujours active
  bool get isCurrentlyActive {
    if (!isActive) return false;
    if (expiresAt == null) return true; // Permanent
    return expiresAt!.isAfter(DateTime.now());
  }

  /// Obtenir durée restante (jours)
  int? get daysRemaining {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Obtenir label sanction lisible
  String get typeLabel {
    switch (type) {
      case SanctionType.warning:
        return 'Avertissement';
      case SanctionType.suspension3Days:
        return 'Suspension 3 jours';
      case SanctionType.suspension7Days:
        return 'Suspension 7 jours';
      case SanctionType.suspension30Days:
        return 'Suspension 30 jours';
      case SanctionType.banned:
        return 'Banni permanent';
    }
  }

  /// Obtenir durée sanction en jours
  int get durationDays {
    switch (type) {
      case SanctionType.warning:
        return 0;
      case SanctionType.suspension3Days:
        return 3;
      case SanctionType.suspension7Days:
        return 7;
      case SanctionType.suspension30Days:
        return 30;
      case SanctionType.banned:
        return 36500; // ~100 ans
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.toString(),
        'reason': reason,
        'appliedAt': appliedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'appliedBy': appliedBy,
        'notes': notes,
        'isActive': isActive,
        'reportsCount': reportsCount,
        'appealReason': appealReason,
        'appealApproved': appealApproved,
      };

  factory Sanction.fromJson(Map<String, dynamic> json) => Sanction(
        id: json['id'],
        userId: json['userId'],
        type:
            SanctionType.values.firstWhere((e) => e.toString() == json['type']),
        reason: json['reason'],
        appliedAt: DateTime.parse(json['appliedAt']),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'])
            : null,
        appliedBy: json['appliedBy'],
        notes: json['notes'],
        isActive: json['isActive'],
        reportsCount: json['reportsCount'],
        appealReason: json['appealReason'],
        appealApproved: json['appealApproved'],
      );
}

/// Appel contre une sanction
class SanctionAppeal {
  final int id;
  final int sanctionId;
  final int userId;
  final String reason;
  final DateTime appealedAt;
  final DateTime? reviewedAt;
  final int? reviewedBy; // Admin
  final bool? approved;
  final String? adminNotes;

  SanctionAppeal({
    required this.id,
    required this.sanctionId,
    required this.userId,
    required this.reason,
    required this.appealedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.approved,
    this.adminNotes,
  });

  /// Getter pour le statut de l'appel
  String get status {
    if (approved == null) return 'pending';
    return approved! ? 'approved' : 'rejected';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sanctionId': sanctionId,
        'userId': userId,
        'reason': reason,
        'appealedAt': appealedAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'approved': approved,
        'adminNotes': adminNotes,
      };

  factory SanctionAppeal.fromJson(Map<String, dynamic> json) => SanctionAppeal(
        id: json['id'],
        sanctionId: json['sanctionId'],
        userId: json['userId'],
        reason: json['reason'],
        appealedAt: DateTime.parse(json['appealedAt']),
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'])
            : null,
        reviewedBy: json['reviewedBy'],
        approved: json['approved'],
        adminNotes: json['adminNotes'],
      );
}
