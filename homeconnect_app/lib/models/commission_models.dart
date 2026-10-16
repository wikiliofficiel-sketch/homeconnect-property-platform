/// Modèles pour Commissions, Frais et Calculs de revenus
library;

/// Type de commission
enum CommissionType {
  propertyListing, // Frais listing annonce
  applicationFee, // Frais candidature
  transactionFee, // Frais transaction
  messagingFee, // Frais messaging premium
  verificationFee, // Frais vérification KYC
  withdraw, // Frais retrait
  premiumFeature, // Feature premium
}

/// Statut de la commission
enum CommissionStatus {
  pending, // En attente
  processing, // En traitement
  completed, // Complétée
  refunded, // Remboursée
  disputed, // Contestée
}

/// Configuration de commission
class CommissionConfig {
  final CommissionType type;
  final double rate; // Pourcentage ou montant fixe
  final double? maxAmount; // Montant max
  final double? minAmount; // Montant min
  final String description;
  final bool isActive;

  CommissionConfig({
    required this.type,
    required this.rate,
    this.maxAmount,
    this.minAmount,
    required this.description,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'rate': rate,
        'maxAmount': maxAmount,
        'minAmount': minAmount,
        'description': description,
        'isActive': isActive,
      };

  factory CommissionConfig.fromJson(Map<String, dynamic> json) =>
      CommissionConfig(
        type: CommissionType.values
            .firstWhere((e) => e.toString() == json['type']),
        rate: (json['rate'] as num).toDouble(),
        maxAmount: json['maxAmount']?.toDouble(),
        minAmount: json['minAmount']?.toDouble(),
        description: json['description'],
        isActive: json['isActive'],
      );
}

/// Transaction de commission
class CommissionTransaction {
  final int id;
  final int userId; // Propriétaire ou utilisateur
  final CommissionType type;
  final CommissionStatus status;
  final double amount; // Montant de la commission
  final double baseAmount; // Montant de base (avant calcul)
  final double? rate; // Taux appliqué
  final String? description;
  final DateTime createdAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final String? transactionId; // ID externe (payment gateway)
  final int? relatedPropertyId; // Annonce concernée
  final int? relatedApplicationId; // Candidature concernée
  final String? notes; // Notes admin

  CommissionTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.baseAmount,
    this.rate,
    this.description,
    required this.createdAt,
    this.processedAt,
    this.completedAt,
    this.transactionId,
    this.relatedPropertyId,
    this.relatedApplicationId,
    this.notes,
  });

  /// Montant net après commission
  double get netAmount => baseAmount - amount;

  /// Pourcentage appliqué
  double? get appliedPercentage {
    if (baseAmount == 0) return null;
    return (amount / baseAmount) * 100;
  }

  /// Alias pour appliedPercentage (compatible avec admin screens)
  double get percentageApplied {
    if (baseAmount == 0) return 0;
    return (amount / baseAmount) * 100;
  }

  /// Type de commission en string
  String get commissionType {
    switch (type) {
      case CommissionType.propertyListing:
        return 'property_listing';
      case CommissionType.applicationFee:
        return 'application_fee';
      case CommissionType.transactionFee:
        return 'transaction_fee';
      case CommissionType.messagingFee:
        return 'messaging_fee';
      case CommissionType.verificationFee:
        return 'verification_fee';
      case CommissionType.withdraw:
        return 'withdraw';
      case CommissionType.premiumFeature:
        return 'premium_feature';
    }
  }

  /// Date gagnée (alias pour createdAt)
  DateTime get dateEarned => createdAt;

  /// Date créditée (alias pour completedAt ou processedAt)
  DateTime? get dateCredited => completedAt ?? processedAt;

  /// Jours écoulés depuis création
  int get daysCreated => DateTime.now().difference(createdAt).inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.toString(),
        'status': status.toString(),
        'amount': amount,
        'baseAmount': baseAmount,
        'rate': rate,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'processedAt': processedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'transactionId': transactionId,
        'relatedPropertyId': relatedPropertyId,
        'relatedApplicationId': relatedApplicationId,
        'notes': notes,
      };

  factory CommissionTransaction.fromJson(Map<String, dynamic> json) =>
      CommissionTransaction(
        id: json['id'],
        userId: json['userId'],
        type: CommissionType.values
            .firstWhere((e) => e.toString() == json['type']),
        status: CommissionStatus.values
            .firstWhere((e) => e.toString() == json['status']),
        amount: (json['amount'] as num).toDouble(),
        baseAmount: (json['baseAmount'] as num).toDouble(),
        rate: json['rate']?.toDouble(),
        description: json['description'],
        createdAt: DateTime.parse(json['createdAt']),
        processedAt: json['processedAt'] != null
            ? DateTime.parse(json['processedAt'])
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
        transactionId: json['transactionId'],
        relatedPropertyId: json['relatedPropertyId'],
        relatedApplicationId: json['relatedApplicationId'],
        notes: json['notes'],
      );
}

/// Rapport de commissions pour un utilisateur/période
class CommissionReport {
  final int id;
  final int userId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<CommissionTransaction> transactions;
  final double totalCommissions; // Total payé en commissions
  final double totalBaseAmount; // Total montants avant commissions
  final double totalRevenue; // Revenu net (totalBaseAmount - totalCommissions)
  final Map<CommissionType, double> breakdownByType; // Ventilation par type
  final DateTime generatedAt;
  final bool isPaid; // Si versement effectué
  final DateTime? paidAt;
  final String? paymentMethod; // Virement, PayPal, etc

  CommissionReport({
    required this.id,
    required this.userId,
    required this.periodStart,
    required this.periodEnd,
    required this.transactions,
    required this.totalCommissions,
    required this.totalBaseAmount,
    required this.totalRevenue,
    required this.breakdownByType,
    required this.generatedAt,
    required this.isPaid,
    this.paidAt,
    this.paymentMethod,
  });

  /// Taux moyen de commission
  double get averageCommissionRate {
    if (totalBaseAmount == 0) return 0;
    return (totalCommissions / totalBaseAmount) * 100;
  }

  /// Nombre de transactions
  int get transactionCount => transactions.length;

  /// Jours de la période
  int get periodDays => periodEnd.difference(periodStart).inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'totalCommissions': totalCommissions,
        'totalBaseAmount': totalBaseAmount,
        'totalRevenue': totalRevenue,
        'breakdownByType':
            breakdownByType.map((k, v) => MapEntry(k.toString(), v)),
        'generatedAt': generatedAt.toIso8601String(),
        'isPaid': isPaid,
        'paidAt': paidAt?.toIso8601String(),
        'paymentMethod': paymentMethod,
      };

  factory CommissionReport.fromJson(Map<String, dynamic> json) {
    final breakdownMap =
        (json['breakdownByType'] as Map?)?.cast<String, dynamic>() ?? {};
    final breakdown = <CommissionType, double>{};
    breakdownMap.forEach((k, v) {
      final type = CommissionType.values.firstWhere((e) => e.toString() == k,
          orElse: () => CommissionType.withdraw);
      breakdown[type] = (v as num).toDouble();
    });

    return CommissionReport(
      id: json['id'],
      userId: json['userId'],
      periodStart: DateTime.parse(json['periodStart']),
      periodEnd: DateTime.parse(json['periodEnd']),
      transactions: List<CommissionTransaction>.from(
        (json['transactions'] as List).map(
            (t) => CommissionTransaction.fromJson(t as Map<String, dynamic>)),
      ),
      totalCommissions: (json['totalCommissions'] as num).toDouble(),
      totalBaseAmount: (json['totalBaseAmount'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      breakdownByType: breakdown,
      generatedAt: DateTime.parse(json['generatedAt']),
      isPaid: json['isPaid'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      paymentMethod: json['paymentMethod'],
    );
  }
}

/// Retrait de commission (withdrawal)
class CommissionWithdrawal {
  final int id;
  final int userId;
  final double amount;
  final String bankAccount; // IBAN
  final String bankName;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final String status; // pending, processing, completed, failed
  final String? bankTransactionId;
  final String? failureReason;

  CommissionWithdrawal({
    required this.id,
    required this.userId,
    required this.amount,
    required this.bankAccount,
    required this.bankName,
    required this.requestedAt,
    this.processedAt,
    this.completedAt,
    required this.status,
    this.bankTransactionId,
    this.failureReason,
  });

  /// Jours en traitement
  int? get daysProcessing {
    if (processedAt == null) return null;
    return completedAt?.difference(processedAt!).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'bankAccount': bankAccount,
        'bankName': bankName,
        'requestedAt': requestedAt.toIso8601String(),
        'processedAt': processedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'status': status,
        'bankTransactionId': bankTransactionId,
        'failureReason': failureReason,
      };

  factory CommissionWithdrawal.fromJson(Map<String, dynamic> json) =>
      CommissionWithdrawal(
        id: json['id'],
        userId: json['userId'],
        amount: (json['amount'] as num).toDouble(),
        bankAccount: json['bankAccount'],
        bankName: json['bankName'],
        requestedAt: DateTime.parse(json['requestedAt']),
        processedAt: json['processedAt'] != null
            ? DateTime.parse(json['processedAt'])
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
        status: json['status'],
        bankTransactionId: json['bankTransactionId'],
        failureReason: json['failureReason'],
      );
}
