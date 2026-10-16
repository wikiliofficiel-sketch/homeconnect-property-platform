/// Modèles pour Know Your Customer (KYC) - Vérification d'identité avancée
library;

/// Statut de vérification KYC
enum KYCStatus { pending, verified, rejected, expired, needsReview }

/// Type de document d'identité
enum DocumentType {
  passport,
  nationalId,
  drivingLicense,
  votersCard,
  businessLicense,
  taxId,
}

/// Type de vérification de selfie
enum SelfieVerificationType {
  facialRecognition,
  liveness,
  qualityCheck,
  approved,
  rejected,
}

/// Document d'identité fourni par l'utilisateur
class KYCDocument {
  final int id;
  final int userId;
  final DocumentType type;
  final String documentNumber;
  final String frontImageUrl; // Photo recto
  final String backImageUrl; // Photo verso (si applicable)
  final DateTime issueDate;
  final DateTime expiryDate;
  final String issuingCountry;
  final String fullName; // Nom complet depuis le document
  final DateTime uploadedAt;
  final String? verificationNotes;
  final bool isExpired;

  KYCDocument({
    required this.id,
    required this.userId,
    required this.type,
    required this.documentNumber,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.issueDate,
    required this.expiryDate,
    required this.issuingCountry,
    required this.fullName,
    required this.uploadedAt,
    this.verificationNotes,
    required this.isExpired,
  });

  /// Vérifier si le document est valide
  bool get isValid => !isExpired && expiryDate.isAfter(DateTime.now());

  /// Obtenir le statut du document pour l'affichage (compatible avec admin screens)
  String get status {
    if (isExpired) return 'rejetee';
    if (verificationNotes != null && verificationNotes!.isNotEmpty) {
      if (verificationNotes!.toLowerCase().contains('rejected')) {
        return 'rejetee';
      }
      if (verificationNotes!.toLowerCase().contains('approved')) {
        return 'verifiee';
      }
    }
    return 'en_attente';
  }

  /// Obtenir jours avant expiration
  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.toString(),
        'documentNumber': documentNumber,
        'frontImageUrl': frontImageUrl,
        'backImageUrl': backImageUrl,
        'issueDate': issueDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'issuingCountry': issuingCountry,
        'fullName': fullName,
        'uploadedAt': uploadedAt.toIso8601String(),
        'verificationNotes': verificationNotes,
        'isExpired': isExpired,
      };

  factory KYCDocument.fromJson(Map<String, dynamic> json) => KYCDocument(
        id: json['id'],
        userId: json['userId'],
        type:
            DocumentType.values.firstWhere((e) => e.toString() == json['type']),
        documentNumber: json['documentNumber'],
        frontImageUrl: json['frontImageUrl'],
        backImageUrl: json['backImageUrl'],
        issueDate: DateTime.parse(json['issueDate']),
        expiryDate: DateTime.parse(json['expiryDate']),
        issuingCountry: json['issuingCountry'],
        fullName: json['fullName'],
        uploadedAt: DateTime.parse(json['uploadedAt']),
        verificationNotes: json['verificationNotes'],
        isExpired: json['isExpired'],
      );
}

/// Vérification de selfie avec reconnaissance faciale
class SelfieVerification {
  final int id;
  final int userId;
  final String imageUrl;
  final DateTime uploadedAt;
  final SelfieVerificationType verificationType;
  final double? livenessScore; // 0.0 - 1.0
  final double? faceDetectionScore; // 0.0 - 1.0
  final double? qualityScore; // 0.0 - 1.0
  final bool? faceMatched; // Correspond au document
  final String? verificationNotes;
  final bool isApproved;

  SelfieVerification({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.uploadedAt,
    required this.verificationType,
    this.livenessScore,
    this.faceDetectionScore,
    this.qualityScore,
    this.faceMatched,
    this.verificationNotes,
    required this.isApproved,
  });

  /// Calculer score global (moyenne des scores)
  double get overallScore {
    final scores = <double>[
      livenessScore ?? 0,
      faceDetectionScore ?? 0,
      qualityScore ?? 0,
    ].where((s) => s > 0).toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'imageUrl': imageUrl,
        'uploadedAt': uploadedAt.toIso8601String(),
        'verificationType': verificationType.toString(),
        'livenessScore': livenessScore,
        'faceDetectionScore': faceDetectionScore,
        'qualityScore': qualityScore,
        'faceMatched': faceMatched,
        'verificationNotes': verificationNotes,
        'isApproved': isApproved,
      };

  factory SelfieVerification.fromJson(Map<String, dynamic> json) =>
      SelfieVerification(
        id: json['id'],
        userId: json['userId'],
        imageUrl: json['imageUrl'],
        uploadedAt: DateTime.parse(json['uploadedAt']),
        verificationType: SelfieVerificationType.values
            .firstWhere((e) => e.toString() == json['verificationType']),
        livenessScore: json['livenessScore']?.toDouble(),
        faceDetectionScore: json['faceDetectionScore']?.toDouble(),
        qualityScore: json['qualityScore']?.toDouble(),
        faceMatched: json['faceMatched'],
        verificationNotes: json['verificationNotes'],
        isApproved: json['isApproved'],
      );
}

/// Vérification KYC complète d'un utilisateur
class KYCVerification {
  final int id;
  final int userId;
  final String userEmail;
  final String? userPhoneNumber;
  final KYCStatus status;
  final List<KYCDocument> documents;
  final List<SelfieVerification> selfies;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt; // Expiration de la vérification
  final int? reviewedBy; // ID de l'admin qui a revu
  final String? rejectionReason;
  final int attemptCount; // Nombre de tentatives

  KYCVerification({
    required this.id,
    required this.userId,
    required this.userEmail,
    this.userPhoneNumber,
    required this.status,
    required this.documents,
    required this.selfies,
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
    this.reviewedBy,
    this.rejectionReason,
    required this.attemptCount,
  });

  /// Vérifier si KYC est valide et non expiré
  bool get isValid =>
      status == KYCStatus.verified &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// Obtenir du statut lisible
  String get statusLabel {
    switch (status) {
      case KYCStatus.pending:
        return 'En attente';
      case KYCStatus.verified:
        return 'Vérifié';
      case KYCStatus.rejected:
        return 'Rejeté';
      case KYCStatus.expired:
        return 'Expiré';
      case KYCStatus.needsReview:
        return 'Besoin de révision';
    }
  }

  /// Pourcentage de complétion
  double get completionPercentage {
    double score = 0;
    if (documents.isNotEmpty) score += 50;
    if (selfies.isNotEmpty && selfies.any((s) => s.isApproved)) score += 50;
    return score;
  }

  /// Score de vérification global
  double get verificationScore {
    final scores = <double>[];

    // Score documents
    for (var doc in documents) {
      scores.add(doc.isValid ? 100 : 50);
    }

    // Score selfies
    for (var selfie in selfies) {
      scores.add(selfie.overallScore * 100);
    }

    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userEmail': userEmail,
        'userPhoneNumber': userPhoneNumber,
        'status': status.toString(),
        'documents': documents.map((d) => d.toJson()).toList(),
        'selfies': selfies.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'rejectionReason': rejectionReason,
        'attemptCount': attemptCount,
      };

  factory KYCVerification.fromJson(Map<String, dynamic> json) =>
      KYCVerification(
        id: json['id'],
        userId: json['userId'],
        userEmail: json['userEmail'],
        userPhoneNumber: json['userPhoneNumber'],
        status:
            KYCStatus.values.firstWhere((e) => e.toString() == json['status']),
        documents: List<KYCDocument>.from(
            (json['documents'] as List).map((d) => KYCDocument.fromJson(d))),
        selfies: List<SelfieVerification>.from((json['selfies'] as List)
            .map((s) => SelfieVerification.fromJson(s))),
        createdAt: DateTime.parse(json['createdAt']),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'])
            : null,
        reviewedBy: json['reviewedBy'],
        rejectionReason: json['rejectionReason'],
        attemptCount: json['attemptCount'],
      );
}

/// Revue d'une vérification KYC par un administrateur
class KYCReview {
  final int id;
  final int verificationId;
  final int reviewedBy; // Admin ID
  final DateTime reviewedAt;
  final bool approved;
  final String? notes;
  final String? requestedDocuments; // Demander plus de docs
  final int retryAttemptsAllowed;

  KYCReview({
    required this.id,
    required this.verificationId,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.approved,
    this.notes,
    this.requestedDocuments,
    required this.retryAttemptsAllowed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'verificationId': verificationId,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt.toIso8601String(),
        'approved': approved,
        'notes': notes,
        'requestedDocuments': requestedDocuments,
        'retryAttemptsAllowed': retryAttemptsAllowed,
      };

  factory KYCReview.fromJson(Map<String, dynamic> json) => KYCReview(
        id: json['id'],
        verificationId: json['verificationId'],
        reviewedBy: json['reviewedBy'],
        reviewedAt: DateTime.parse(json['reviewedAt']),
        approved: json['approved'],
        notes: json['notes'],
        requestedDocuments: json['requestedDocuments'],
        retryAttemptsAllowed: json['retryAttemptsAllowed'],
      );
}
