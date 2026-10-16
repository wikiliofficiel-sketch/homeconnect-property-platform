// ============================================================
// lib/models/extended_models.dart
// ============================================================

class Candidature {
  final int id;
  final int bienId;
  final int locataireId;
  final String statut;
  final String? lettreCandidature;
  final DateTime dateCreation;
  final DateTime? dateTraitement;

  const Candidature({
    required this.id,
    required this.bienId,
    required this.locataireId,
    required this.statut,
    this.lettreCandidature,
    required this.dateCreation,
    this.dateTraitement,
  });

  factory Candidature.fromJson(Map<String, dynamic> json) => Candidature(
    id: json['id'],
    bienId: json['bien_id'],
    locataireId: json['locataire_id'],
    statut: json['statut'],
    lettreCandidature: json['lettre_candidature'],
    dateCreation: DateTime.parse(json['created_at']),
    dateTraitement: json['date_traitement'] != null ? DateTime.parse(json['date_traitement']) : null,
  );
}

class RendezVous {
  final int id;
  final int bienId;
  final int locataireId;
  final DateTime dateHeure;
  final String statut;
  final String? notes;

  const RendezVous({
    required this.id,
    required this.bienId,
    required this.locataireId,
    required this.dateHeure,
    required this.statut,
    this.notes,
  });

  factory RendezVous.fromJson(Map<String, dynamic> json) => RendezVous(
    id: json['id'],
    bienId: json['bien_id'],
    locataireId: json['locataire_id'],
    dateHeure: DateTime.parse(json['date_heure']),
    statut: json['statut'],
    notes: json['notes'],
  );
}

class Evaluation {
  final int id;
  final int evaluateurId;
  final int evaluId;
  final int? propertyId; // Propriété concernée
  final double note;
  final String? commentaire;
  final DateTime dateCreation;

  const Evaluation({
    required this.id,
    required this.evaluateurId,
    required this.evaluId,
    this.propertyId,
    required this.note,
    this.commentaire,
    required this.dateCreation,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) => Evaluation(
    id: json['id'],
    evaluateurId: json['evaluateur_id'],
    evaluId: json['evalu_id'],
    propertyId: json['property_id'],
    note: (json['note'] ?? 0.0).toDouble(),
    commentaire: json['commentaire'],
    dateCreation: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'evaluateur_id': evaluateurId,
    'evalu_id': evaluId,
    'property_id': propertyId,
    'note': note,
    'commentaire': commentaire,
    'created_at': dateCreation.toIso8601String(),
  };
}

class ServicePartenaire {
  final int id;
  final String nom;
  final String email;
  final String telephone;
  final String domaine;
  final List<String> specialites;
  final double noteMoyenne;
  final String? logo;
  final String? description;
  final bool verifiee;

  const ServicePartenaire({
    required this.id,
    required this.nom,
    required this.email,
    required this.telephone,
    required this.domaine,
    required this.specialites,
    required this.noteMoyenne,
    this.logo,
    this.description,
    required this.verifiee,
  });

  factory ServicePartenaire.fromJson(Map<String, dynamic> json) => ServicePartenaire(
    id: json['id'],
    nom: json['nom'],
    email: json['email'],
    telephone: json['telephone'],
    domaine: json['domaine'],
    specialites: List<String>.from(json['specialites'] ?? []),
    noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
    logo: json['logo'],
    description: json['description'],
    verifiee: json['verifiee'] ?? false,
  );
}

class Notification {
  final int id;
  final int userId;
  final String titre;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool lue;
  final DateTime dateCreation;

  const Notification({
    required this.id,
    required this.userId,
    required this.titre,
    required this.message,
    required this.type,
    this.data,
    required this.lue,
    required this.dateCreation,
  });

  factory Notification.fromJson(Map<String, dynamic> json) => Notification(
    id: json['id'],
    userId: json['user_id'],
    titre: json['titre'],
    message: json['message'],
    type: json['type'],
    data: json['data'],
    lue: json['lue'] ?? false,
    dateCreation: DateTime.parse(json['created_at']),
  );
}

class Transaction {
  final int id;
  final int locataireId;
  final String type; // 'loyer', 'service'
  final double montant;
  final String reference;
  final String statut; // 'en_attente', 'confirme', 'echoue', 'rembourse'
  final String methodePaiement; // 'mobile_money', 'carte_bancaire', 'virement'
  final int? bienId; // Si type == 'loyer'
  final int? serviceId; // Si type == 'service'
  final DateTime dateCreation;

  const Transaction({
    required this.id,
    required this.locataireId,
    required this.type,
    required this.montant,
    required this.reference,
    required this.statut,
    required this.methodePaiement,
    this.bienId,
    this.serviceId,
    required this.dateCreation,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    locataireId: json['locataire_id'],
    type: json['type'],
    montant: (json['montant'] ?? 0.0).toDouble(),
    reference: json['reference'],
    statut: json['statut'],
    methodePaiement: json['methode_paiement'] ?? 'mobile_money',
    bienId: json['bien_id'],
    serviceId: json['service_id'],
    dateCreation: DateTime.parse(json['date_creation']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'locataire_id': locataireId,
    'type': type,
    'montant': montant,
    'reference': reference,
    'statut': statut,
    'methode_paiement': methodePaiement,
    'bien_id': bienId,
    'service_id': serviceId,
    'date_creation': dateCreation.toIso8601String(),
  };
}

class Contrat {
  final int id;
  final int bienId;
  final int proprietaireId;
  final int locataireId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double loyerMensuel;
  final double? caution;
  final String? contratPdf;
  final DateTime dateCreation;

  const Contrat({
    required this.id,
    required this.bienId,
    required this.proprietaireId,
    required this.locataireId,
    required this.dateDebut,
    required this.dateFin,
    required this.loyerMensuel,
    this.caution,
    this.contratPdf,
    required this.dateCreation,
  });

  factory Contrat.fromJson(Map<String, dynamic> json) => Contrat(
    id: json['id'],
    bienId: json['bien_id'],
    proprietaireId: json['proprietaire_id'],
    locataireId: json['locataire_id'],
    dateDebut: DateTime.parse(json['date_debut']),
    dateFin: DateTime.parse(json['date_fin']),
    loyerMensuel: (json['loyer_mensuel'] ?? 0.0).toDouble(),
    caution: json['caution']?.toDouble(),
    contratPdf: json['contrat_pdf'],
    dateCreation: DateTime.parse(json['created_at']),
  );
}

class SignalementAbusif {
  final int id;
  final int signalateurId;
  final int bienId;
  final String motif;
  final String? description;
  final List<String>? preuves;
  final String statut;
  final DateTime dateCreation;

  const SignalementAbusif({
    required this.id,
    required this.signalateurId,
    required this.bienId,
    required this.motif,
    this.description,
    this.preuves,
    required this.statut,
    required this.dateCreation,
  });

  factory SignalementAbusif.fromJson(Map<String, dynamic> json) => SignalementAbusif(
    id: json['id'],
    signalateurId: json['signataire_id'],
    bienId: json['bien_id'],
    motif: json['motif'],
    description: json['description'],
    preuves: List<String>.from(json['preuves'] ?? []),
    statut: json['statut'],
    dateCreation: DateTime.parse(json['created_at']),
  );
}

// Models for Phase 2 are now in:
// - lib/models/kyc_models.dart
// - lib/models/report_sanction_models.dart
// - lib/models/commission_models.dart

class AdminSanction {
  final int id;
  final int userId;
  final String sanctionType;
  final String reason;
  final String? details;
  final int? reportId;
  final int appliedBy;
  final DateTime appliedAt;
  final Duration? duration;
  final DateTime? expiresAt;
  final bool isActive;

  AdminSanction({
    required this.id,
    required this.userId,
    required this.sanctionType,
    required this.reason,
    this.details,
    this.reportId,
    required this.appliedBy,
    required this.appliedAt,
    this.duration,
    this.expiresAt,
    required this.isActive,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory AdminSanction.fromJson(Map<String, dynamic> json) => AdminSanction(
    id: json['id'],
    userId: json['userId'] ?? json['user_id'],
    sanctionType: json['sanctionType'] ?? json['sanction_type'],
    reason: json['reason'],
    details: json['details'],
    reportId: json['reportId'] ?? json['report_id'],
    appliedBy: json['appliedBy'] ?? json['applied_by'],
    appliedAt: DateTime.parse(json['appliedAt'] ?? json['applied_at']),
    duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
    expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    isActive: json['isActive'] ?? json['is_active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'sanctionType': sanctionType,
    'reason': reason,
    'details': details,
    'reportId': reportId,
    'appliedBy': appliedBy,
    'appliedAt': appliedAt.toIso8601String(),
    'duration': duration?.inSeconds,
    'expiresAt': expiresAt?.toIso8601String(),
    'isActive': isActive,
  };
}


// ============================================================
// PHASE 2: Candidatures, Visites, État des lieux, Abonnements
// ============================================================

/// Application (candidature améliorée)
class Application {
  final int id;
  final int propertyId;
  final int tenantId;
  final String status; // 'pending', 'approved', 'rejected', 'withdrawn'
  final String? coverLetter;
  final List<String>? documents; // URLs de documents
  final double? proposedRent; // Si différent du prix du bien
  final DateTime dateCreation;
  final DateTime? dateProcessed;
  final int? processedBy; // ID du propriétaire
  final String? rejectionReason;

  const Application({
    required this.id,
    required this.propertyId,
    required this.tenantId,
    required this.status,
    this.coverLetter,
    this.documents,
    this.proposedRent,
    required this.dateCreation,
    this.dateProcessed,
    this.processedBy,
    this.rejectionReason,
  });

  factory Application.fromJson(Map<String, dynamic> json) => Application(
    id: json['id'],
    propertyId: json['property_id'],
    tenantId: json['tenant_id'],
    status: json['status'],
    coverLetter: json['cover_letter'],
    documents: List<String>.from(json['documents'] ?? []),
    proposedRent: (json['proposed_rent'] ?? 0.0).toDouble(),
    dateCreation: DateTime.parse(json['created_at']),
    dateProcessed: json['date_processed'] != null 
        ? DateTime.tryParse(json['date_processed']) 
        : null,
    processedBy: json['processed_by'],
    rejectionReason: json['rejection_reason'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'property_id': propertyId,
    'tenant_id': tenantId,
    'status': status,
    'cover_letter': coverLetter,
    'documents': documents,
    'proposed_rent': proposedRent,
    'created_at': dateCreation.toIso8601String(),
    'date_processed': dateProcessed?.toIso8601String(),
    'processed_by': processedBy,
    'rejection_reason': rejectionReason,
  };
}

/// Visite planifiée
class ScheduledVisit {
  final int id;
  final int applicationId;
  final int propertyId;
  final int tenantId;
  final int? ownerId;
  final DateTime scheduledDate;
  final String? notes;
  final String status; // 'scheduled', 'completed', 'cancelled', 'no_show'
  final DateTime? completedAt;
  final DateTime dateCreation;

  const ScheduledVisit({
    required this.id,
    required this.applicationId,
    required this.propertyId,
    required this.tenantId,
    this.ownerId,
    required this.scheduledDate,
    this.notes,
    required this.status,
    this.completedAt,
    required this.dateCreation,
  });

  factory ScheduledVisit.fromJson(Map<String, dynamic> json) => ScheduledVisit(
    id: json['id'],
    applicationId: json['application_id'],
    propertyId: json['property_id'],
    tenantId: json['tenant_id'],
    ownerId: json['owner_id'],
    scheduledDate: DateTime.parse(json['scheduled_date']),
    notes: json['notes'],
    status: json['status'],
    completedAt: json['completed_at'] != null 
        ? DateTime.tryParse(json['completed_at']) 
        : null,
    dateCreation: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'application_id': applicationId,
    'property_id': propertyId,
    'tenant_id': tenantId,
    'owner_id': ownerId,
    'scheduled_date': scheduledDate.toIso8601String(),
    'notes': notes,
    'status': status,
    'completed_at': completedAt?.toIso8601String(),
    'created_at': dateCreation.toIso8601String(),
  };

  bool get isPast => scheduledDate.isBefore(DateTime.now());
}

/// Inspection des locaux (état des lieux)
class UtilityInspection {
  final int id;
  final int contractId;
  final String inspectionType; // 'entry', 'exit', 'maintenance'
  final Map<String, RoomInspection> rooms; // Pièce -> inspection
  final String? overallCondition; // 'excellent', 'good', 'fair', 'poor'
  final List<String>? issues;
  final List<String>? photos;
  final String? inspectorNotes;
  final int? inspectorId;
  final DateTime dateInspection;

  const UtilityInspection({
    required this.id,
    required this.contractId,
    required this.inspectionType,
    required this.rooms,
    this.overallCondition,
    this.issues,
    this.photos,
    this.inspectorNotes,
    this.inspectorId,
    required this.dateInspection,
  });

  factory UtilityInspection.fromJson(Map<String, dynamic> json) => UtilityInspection(
    id: json['id'],
    contractId: json['contract_id'],
    inspectionType: json['inspection_type'],
    rooms: (json['rooms'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, RoomInspection.fromJson(v)),
    ) ?? {},
    overallCondition: json['overall_condition'],
    issues: List<String>.from(json['issues'] ?? []),
    photos: List<String>.from(json['photos'] ?? []),
    inspectorNotes: json['inspector_notes'],
    inspectorId: json['inspector_id'],
    dateInspection: DateTime.parse(json['date_inspection']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contract_id': contractId,
    'inspection_type': inspectionType,
    'rooms': rooms.map((k, v) => MapEntry(k, v.toJson())),
    'overall_condition': overallCondition,
    'issues': issues,
    'photos': photos,
    'inspector_notes': inspectorNotes,
    'inspector_id': inspectorId,
    'date_inspection': dateInspection.toIso8601String(),
  };
}

/// Inspection d'une pièce
class RoomInspection {
  final String roomName;
  final String condition; // 'excellent', 'good', 'fair', 'poor'
  final List<String>? damages;
  final List<String>? photos;

  const RoomInspection({
    required this.roomName,
    required this.condition,
    this.damages,
    this.photos,
  });

  factory RoomInspection.fromJson(Map<String, dynamic> json) => RoomInspection(
    roomName: json['room_name'],
    condition: json['condition'],
    damages: List<String>.from(json['damages'] ?? []),
    photos: List<String>.from(json['photos'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'room_name': roomName,
    'condition': condition,
    'damages': damages,
    'photos': photos,
  };
}

/// Abonnement Premium+
class Subscription {
  final int id;
  final int userId;
  final String plan; // 'free', 'premium_plus'
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? monthlyPrice; // En FCFA
  final String? paymentMethod;
  final DateTime dateCreation;
  final DateTime? dateCancelled;

  const Subscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.monthlyPrice,
    this.paymentMethod,
    required this.dateCreation,
    this.dateCancelled,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'],
    userId: json['user_id'],
    plan: json['plan'],
    isActive: json['is_active'] ?? false,
    startDate: json['start_date'] != null 
        ? DateTime.tryParse(json['start_date']) 
        : null,
    endDate: json['end_date'] != null 
        ? DateTime.tryParse(json['end_date']) 
        : null,
    monthlyPrice: (json['monthly_price'] ?? 0.0).toDouble(),
    paymentMethod: json['payment_method'],
    dateCreation: DateTime.parse(json['created_at']),
    dateCancelled: json['date_cancelled'] != null 
        ? DateTime.tryParse(json['date_cancelled']) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'plan': plan,
    'is_active': isActive,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'monthly_price': monthlyPrice,
    'payment_method': paymentMethod,
    'created_at': dateCreation.toIso8601String(),
    'date_cancelled': dateCancelled?.toIso8601String(),
  };

  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());
  int get daysRemaining {
    if (endDate == null) return -1;
    return endDate!.difference(DateTime.now()).inDays;
  }
}

/// Statistiques de propriété
class PropertyStats {
  final int propertyId;
  final int totalViews;
  final int thisMonthViews;
  final int applicationCount;
  final int activeApplicationCount;
  final double averageRating;
  final int ratingCount;
  final DateTime? lastUpdated;

  const PropertyStats({
    required this.propertyId,
    required this.totalViews,
    required this.thisMonthViews,
    required this.applicationCount,
    required this.activeApplicationCount,
    required this.averageRating,
    required this.ratingCount,
    this.lastUpdated,
  });

  factory PropertyStats.fromJson(Map<String, dynamic> json) => PropertyStats(
    propertyId: json['property_id'],
    totalViews: json['total_views'] ?? 0,
    thisMonthViews: json['this_month_views'] ?? 0,
    applicationCount: json['application_count'] ?? 0,
    activeApplicationCount: json['active_application_count'] ?? 0,
    averageRating: (json['average_rating'] ?? 0.0).toDouble(),
    ratingCount: json['rating_count'] ?? 0,
    lastUpdated: json['last_updated'] != null 
        ? DateTime.tryParse(json['last_updated']) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'property_id': propertyId,
    'total_views': totalViews,
    'this_month_views': thisMonthViews,
    'application_count': applicationCount,
    'active_application_count': activeApplicationCount,
    'average_rating': averageRating,
    'rating_count': ratingCount,
    'last_updated': lastUpdated?.toIso8601String(),
  };
}
