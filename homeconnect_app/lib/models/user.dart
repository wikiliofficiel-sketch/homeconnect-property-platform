class User {
  // Core identifiers
  final int id;
  final String? name; // full name (can be used as displayName)
  final String email;

  // Additional profile fields used throughout the app
  final String? nom; // last name
  final String? prenom; // first name
  final String? password;
  final String? telephone;
  final String? role; // admin, proprietaire, locataire, etc.
  final String? verificationStatus; // e.g., 'verified', 'non_verifie'
  final String? verificationDocument;
  final String? verificationDocumentAddress;
  final String? verificationDocumentProperty;
  final String? verificationDocumentType;
  final String? verificationRejectionReason;
  final DateTime? verificationApprovedAt;
  final String? verificationApprovedBy;
  final String? subscriptionType; // e.g., 'premium_plus'
  final bool? isSubscriptionActive;
  final DateTime? subscriptionExpiry;
  final double? rating;
  final int? reviewCount;
  final String? cniNumber;
  final DateTime? documentExpiryDate;
  final bool? kycBadgeVisible;

  User({
    required this.id,
    this.name,
    required this.email,
    this.nom,
    this.prenom,
    this.password,
    this.telephone,
    this.role,
    this.verificationStatus,
    this.verificationDocument,
    this.verificationDocumentAddress,
    this.verificationDocumentProperty,
    this.verificationDocumentType,
    this.verificationRejectionReason,
    this.verificationApprovedAt,
    this.verificationApprovedBy,
    this.subscriptionType,
    this.isSubscriptionActive,
    this.subscriptionExpiry,
    this.rating,
    this.reviewCount,
    this.cniNumber,
    this.documentExpiryDate,
    this.kycBadgeVisible,
  });

  // Convenience getters used in UI
  String get displayName => name ?? '${prenom ?? ''} ${nom ?? ''}'.trim();
  bool get isVerified =>
      verificationStatus == 'certifie' ||   // backend Symfony
      verificationStatus == 'verifie'   ||   // ancienne valeur
      verificationStatus == 'verified';      // valeur anglaise

  // Factory constructor — robuste à tous les types (int/String/null)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: _parseInt(map['id']) ?? 0,
      name: map['name']?.toString(),
      email: map['email']?.toString() ?? '',
      nom: map['nom']?.toString(),
      prenom: map['prenom']?.toString(),
      password: map['password']?.toString(),
      telephone: map['telephone']?.toString(),
      role: map['role']?.toString(),
      verificationStatus: map['verificationStatus']?.toString(),
      verificationDocument: map['verificationDocument']?.toString(),
      verificationDocumentAddress: map['verificationDocumentAddress']?.toString(),
      verificationDocumentProperty: map['verificationDocumentProperty']?.toString(),
      verificationDocumentType: map['verificationDocumentType']?.toString(),
      verificationRejectionReason: map['verificationRejectionReason']?.toString(),
      verificationApprovedAt: map['verificationApprovedAt'] != null
          ? DateTime.tryParse(map['verificationApprovedAt'].toString())
          : null,
      verificationApprovedBy: map['verificationApprovedBy']?.toString(),
      subscriptionType: map['subscriptionType']?.toString(),
      isSubscriptionActive: map['isSubscriptionActive'] == 1 || map['isSubscriptionActive'] == true,
      subscriptionExpiry: map['subscriptionExpiry'] != null
          ? DateTime.tryParse(map['subscriptionExpiry'].toString())
          : null,
      rating: _parseDouble(map['rating']),
      reviewCount: _parseInt(map['reviewCount']),
      cniNumber: map['cniNumber']?.toString(),
      documentExpiryDate: map['documentExpiryDate'] != null
          ? DateTime.tryParse(map['documentExpiryDate'].toString())
          : null,
      kycBadgeVisible: map['kycBadgeVisible'] == 1 || map['kycBadgeVisible'] == true,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // Convert to map for SQLite helper
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'password': password,
      'telephone': telephone,
      'role': role,
      'verificationStatus': verificationStatus,
      'verificationDocument': verificationDocument,
      'verificationDocumentAddress': verificationDocumentAddress,
      'verificationDocumentProperty': verificationDocumentProperty,
      'verificationDocumentType': verificationDocumentType,
      'verificationRejectionReason': verificationRejectionReason,
      'verificationApprovedAt': verificationApprovedAt?.toIso8601String(),
      'verificationApprovedBy': verificationApprovedBy,
      'subscriptionType': subscriptionType,
      'isSubscriptionActive': isSubscriptionActive == true ? 1 : 0,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'rating': rating,
      'reviewCount': reviewCount,
      'cniNumber': cniNumber,
      'documentExpiryDate': documentExpiryDate?.toIso8601String(),
      'kycBadgeVisible': kycBadgeVisible == true ? 1 : 0,
    };
  }

  // Copy with pattern for updates
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? nom,
    String? prenom,
    String? password,
    String? telephone,
    String? role,
    String? verificationStatus,
    String? verificationDocument,
    String? verificationDocumentAddress,
    String? verificationDocumentProperty,
    String? verificationDocumentType,
    String? verificationRejectionReason,
    DateTime? verificationApprovedAt,
    String? verificationApprovedBy,
    String? subscriptionType,
    bool? isSubscriptionActive,
    DateTime? subscriptionExpiry,
    double? rating,
    int? reviewCount,
    String? cniNumber,
    DateTime? documentExpiryDate,
    bool? kycBadgeVisible,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      password: password ?? this.password,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationDocument: verificationDocument ?? this.verificationDocument,
      verificationDocumentAddress: verificationDocumentAddress ?? this.verificationDocumentAddress,
      verificationDocumentProperty: verificationDocumentProperty ?? this.verificationDocumentProperty,
      verificationDocumentType: verificationDocumentType ?? this.verificationDocumentType,
      verificationRejectionReason: verificationRejectionReason ?? this.verificationRejectionReason,
      verificationApprovedAt: verificationApprovedAt ?? this.verificationApprovedAt,
      verificationApprovedBy: verificationApprovedBy ?? this.verificationApprovedBy,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      cniNumber: cniNumber ?? this.cniNumber,
      documentExpiryDate: documentExpiryDate ?? this.documentExpiryDate,
      kycBadgeVisible: kycBadgeVisible ?? this.kycBadgeVisible,
    );
  }
}
