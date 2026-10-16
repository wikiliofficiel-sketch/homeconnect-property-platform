import 'package:flutter/foundation.dart';
import '../models/commission_models.dart';
import '../services/database_helper.dart';

/// Provider pour gérer les commissions et revenus
class CommissionProvider extends ChangeNotifier {
  final db = DatabaseHelper();

  List<CommissionConfig> _configs = [];
  List<CommissionTransaction> _transactions = [];
  List<CommissionReport> _reports = [];
  List<CommissionWithdrawal> _withdrawals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CommissionConfig> get configs => _configs;
  List<CommissionTransaction> get transactions => _transactions;
  List<CommissionReport> get reports => _reports;
  List<CommissionWithdrawal> get withdrawals => _withdrawals;
  List<CommissionTransaction> get commissions =>
      _transactions; // Alias pour compatibilité
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CommissionProvider() {
    _initializeDefaultConfigs();
  }

  /// Initialiser les configurations par défaut
  void _initializeDefaultConfigs() {
    _configs = [
      CommissionConfig(
        type: CommissionType.propertyListing,
        rate: 2.5, // 2.5% du prix de location
        minAmount: 5000,
        maxAmount: 50000,
        description: 'Frais pour lister une propriété',
        isActive: true,
      ),
      CommissionConfig(
        type: CommissionType.applicationFee,
        rate: 0, // Gratuit pour les candidatures
        description: 'Frais candidature',
        isActive: true,
      ),
      CommissionConfig(
        type: CommissionType.transactionFee,
        rate: 1.5, // 1.5% par transaction
        minAmount: 1000,
        description: 'Frais transaction/paiement',
        isActive: true,
      ),
      CommissionConfig(
        type: CommissionType.messagingFee,
        rate: 0,
        description: 'Frais messaging premium',
        isActive: true,
      ),
      CommissionConfig(
        type: CommissionType.withdraw,
        rate: 50, // Frais fixes de retrait
        description: 'Frais retrait',
        isActive: true,
      ),
    ];
  }

  /// Charger les configurations de commission
  Future<void> loadConfigs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('commission_configs');
      if (data.isNotEmpty) {
        _configs = data
            .map((c) => CommissionConfig.fromJson(c as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement configs: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtenir la configuration d'un type de commission
  CommissionConfig? getConfig(CommissionType type) {
    try {
      return _configs.firstWhere((c) => c.type == type);
    } catch (e) {
      return null;
    }
  }

  /// === TRANSACTIONS ===

  /// Créer une transaction de commission
  Future<bool> createTransaction({
    required int userId,
    required CommissionType type,
    required double baseAmount,
    required String description,
    int? relatedPropertyId,
    int? relatedApplicationId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = getConfig(type);
      if (config == null) {
        throw Exception('Configuration non trouvée pour $type');
      }

      // Calculer le montant
      double amount = 0;
      if (config.rate > 0) {
        amount = (baseAmount * config.rate) / 100;
      } else {
        amount = config.rate;
      }

      // Appliquer min/max
      if (config.minAmount != null && amount < config.minAmount!) {
        amount = config.minAmount!;
      }
      if (config.maxAmount != null && amount > config.maxAmount!) {
        amount = config.maxAmount!;
      }

      final transaction = CommissionTransaction(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        type: type,
        status: CommissionStatus.pending,
        amount: amount,
        baseAmount: baseAmount,
        rate: config.rate,
        description: description,
        createdAt: DateTime.now(),
        relatedPropertyId: relatedPropertyId,
        relatedApplicationId: relatedApplicationId,
      );

      _transactions.add(transaction);
      await _saveTransactions();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur création transaction: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les transactions d'un utilisateur
  Future<void> loadUserTransactions(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('commission_transactions');
      final allTransactions = data
          .map((t) =>
              CommissionTransaction.fromJson(t as Map<String, dynamic>))
          .toList();
      _transactions =
          allTransactions.where((t) => t.userId == userId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement transactions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger toutes les transactions
  Future<void> loadAllTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('commission_transactions');
      _transactions = data
          .map((t) =>
              CommissionTransaction.fromJson(t as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// === RAPPORTS ===

  /// Générer un rapport de commission pour une période
  Future<CommissionReport?> generateReport({
    required int userId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      // Charger les transactions de l'utilisateur pour cette période
      await loadUserTransactions(userId);

      final periodTransactions = _transactions
          .where((t) =>
              t.createdAt.isAfter(periodStart) &&
              t.createdAt.isBefore(periodEnd))
          .toList();

      if (periodTransactions.isEmpty) {
        return null;
      }

      // Calculer les totaux
      double totalCommissions = 0;
      double totalBaseAmount = 0;
      final breakdownByType = <CommissionType, double>{};

      for (var transaction in periodTransactions) {
        totalCommissions += transaction.amount;
        totalBaseAmount += transaction.baseAmount;
        breakdownByType[transaction.type] =
            (breakdownByType[transaction.type] ?? 0) + transaction.amount;
      }

      final report = CommissionReport(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        transactions: periodTransactions,
        totalCommissions: totalCommissions,
        totalBaseAmount: totalBaseAmount,
        totalRevenue: totalBaseAmount - totalCommissions,
        breakdownByType: breakdownByType,
        generatedAt: DateTime.now(),
        isPaid: false,
      );

      _reports.add(report);
      await _saveReports();

      return report;
    } catch (e) {
      _errorMessage = 'Erreur génération rapport: $e';
      return null;
    }
  }

  /// Charger tous les rapports d'un utilisateur
  Future<void> loadUserReports(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('commission_reports');
      final allReports = data
          .map((r) => CommissionReport.fromJson(r as Map<String, dynamic>))
          .toList();
      _reports = allReports.where((r) => r.userId == userId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement rapports: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marquer un rapport comme payé
  Future<bool> markReportAsPaid(int reportId, String paymentMethod) async {
    try {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index < 0) return false;

      final oldReport = _reports[index];

      _reports[index] = CommissionReport(
        id: oldReport.id,
        userId: oldReport.userId,
        periodStart: oldReport.periodStart,
        periodEnd: oldReport.periodEnd,
        transactions: oldReport.transactions,
        totalCommissions: oldReport.totalCommissions,
        totalBaseAmount: oldReport.totalBaseAmount,
        totalRevenue: oldReport.totalRevenue,
        breakdownByType: oldReport.breakdownByType,
        generatedAt: oldReport.generatedAt,
        isPaid: true,
        paidAt: DateTime.now(),
        paymentMethod: paymentMethod,
      );

      await _saveReports();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur marquage rapport: $e';
      notifyListeners();
      return false;
    }
  }

  /// === RETRAITS ===

  /// Demander un retrait de commission
  Future<bool> requestWithdrawal({
    required int userId,
    required double amount,
    required String bankAccount,
    required String bankName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Vérifier solde disponible
      await loadUserTransactions(userId);
      final totalAvailable = _transactions
          .where((t) =>
              t.status == CommissionStatus.completed &&
              t.createdAt.isBefore(DateTime.now().subtract(const Duration(days: 7))))
          .fold<double>(0, (sum, t) => sum + t.netAmount);

      if (amount > totalAvailable) {
        throw Exception('Solde insuffisant');
      }

      final withdrawal = CommissionWithdrawal(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        amount: amount,
        bankAccount: bankAccount,
        bankName: bankName,
        requestedAt: DateTime.now(),
        status: 'pending',
      );

      _withdrawals.add(withdrawal);
      await _saveWithdrawals();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur demande retrait: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les retraits d'un utilisateur
  Future<void> loadUserWithdrawals(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('commission_withdrawals');
      final allWithdrawals = data
          .map(
              (w) => CommissionWithdrawal.fromJson(w as Map<String, dynamic>))
          .toList();
      _withdrawals = allWithdrawals.where((w) => w.userId == userId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement retraits: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// === ADMIN ===

  /// Traiter un retrait (marquer comme en traitement)
  Future<bool> processWithdrawal(int withdrawalId) async {
    try {
      final index = _withdrawals.indexWhere((w) => w.id == withdrawalId);
      if (index < 0) return false;

      final oldWithdrawal = _withdrawals[index];

      _withdrawals[index] = CommissionWithdrawal(
        id: oldWithdrawal.id,
        userId: oldWithdrawal.userId,
        amount: oldWithdrawal.amount,
        bankAccount: oldWithdrawal.bankAccount,
        bankName: oldWithdrawal.bankName,
        requestedAt: oldWithdrawal.requestedAt,
        processedAt: DateTime.now(),
        status: 'processing',
      );

      await _saveWithdrawals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur traitement retrait: $e';
      notifyListeners();
      return false;
    }
  }

  /// Compléter un retrait
  Future<bool> completeWithdrawal(
      int withdrawalId, String bankTransactionId) async {
    try {
      final index = _withdrawals.indexWhere((w) => w.id == withdrawalId);
      if (index < 0) return false;

      final oldWithdrawal = _withdrawals[index];

      _withdrawals[index] = CommissionWithdrawal(
        id: oldWithdrawal.id,
        userId: oldWithdrawal.userId,
        amount: oldWithdrawal.amount,
        bankAccount: oldWithdrawal.bankAccount,
        bankName: oldWithdrawal.bankName,
        requestedAt: oldWithdrawal.requestedAt,
        processedAt: oldWithdrawal.processedAt,
        completedAt: DateTime.now(),
        status: 'completed',
        bankTransactionId: bankTransactionId,
      );

      await _saveWithdrawals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur complétude retrait: $e';
      notifyListeners();
      return false;
    }
  }

  /// Rejeter un retrait
  Future<bool> rejectWithdrawal(int withdrawalId, String reason) async {
    try {
      final index = _withdrawals.indexWhere((w) => w.id == withdrawalId);
      if (index < 0) return false;

      final oldWithdrawal = _withdrawals[index];

      _withdrawals[index] = CommissionWithdrawal(
        id: oldWithdrawal.id,
        userId: oldWithdrawal.userId,
        amount: oldWithdrawal.amount,
        bankAccount: oldWithdrawal.bankAccount,
        bankName: oldWithdrawal.bankName,
        requestedAt: oldWithdrawal.requestedAt,
        status: 'failed',
        failureReason: reason,
      );

      await _saveWithdrawals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur rejet retrait: $e';
      notifyListeners();
      return false;
    }
  }

  /// === STATISTIQUES ===

  /// Obtenir le solde total des commissions
  double getTotalCommissions({int? userId}) {
    List<CommissionTransaction> filtered = _transactions;
    if (userId != null) {
      filtered = filtered.where((t) => t.userId == userId).toList();
    }
    return filtered.fold<double>(0, (sum, t) => sum + t.amount);
  }

  /// Obtenir le revenu net total
  double getTotalNetRevenue({int? userId}) {
    List<CommissionTransaction> filtered = _transactions;
    if (userId != null) {
      filtered = filtered.where((t) => t.userId == userId).toList();
    }
    return filtered.fold<double>(0, (sum, t) => sum + t.netAmount);
  }

  /// Charger toutes les commissions (alias)
  Future<void> loadAllCommissions() async {
    return loadAllTransactions();
  }

  /// Créditer une commission
  Future<bool> creditCommission(int commissionId) async {
    try {
      final index = _transactions.indexWhere((t) => t.id == commissionId);
      if (index == -1) return false;

      final transaction = _transactions[index];
      final credited = CommissionTransaction(
        baseAmount: transaction.baseAmount,
        id: transaction.id,
        userId: transaction.userId,
        amount: transaction.amount,
        type: transaction.type,
        status: CommissionStatus.completed,
        description: transaction.description,
        rate: transaction.rate,
        createdAt: transaction.createdAt,
        processedAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      _transactions[index] = credited;
      await _saveTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur crédit commission: $e';
      notifyListeners();
      return false;
    }
  }

  /// Obtenir les statistiques de commission
  Map<String, dynamic> getCommissionStats() {
    final pending =
        _transactions.where((t) => t.status == CommissionStatus.pending).length;
    final completed = _transactions
        .where((t) => t.status == CommissionStatus.completed)
        .length;
    final total = _transactions.length;

    final pendingAmount = _transactions
        .where((t) => t.status == CommissionStatus.pending)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final completedAmount = _transactions
        .where((t) => t.status == CommissionStatus.completed)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    return {
      'total': total,
      'pending': pending,
      'completed': completed,
      'pendingAmount': pendingAmount,
      'completedAmount': completedAmount,
    };
  }

  /// === PRIVÉ ===

  Future<void> _saveTransactions() async {
    await db.setList('commission_transactions',
        _transactions.map((t) => t.toJson()).toList());
  }

  Future<void> _saveReports() async {
    await db.setList(
        'commission_reports', _reports.map((r) => r.toJson()).toList());
  }

  Future<void> _saveWithdrawals() async {
    await db.setList(
        'commission_withdrawals', _withdrawals.map((w) => w.toJson()).toList());
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
