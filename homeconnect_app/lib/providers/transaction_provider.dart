import 'package:flutter/foundation.dart';
import '../models/extended_models.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  Future<void> loadTransactions(int userId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final raw = await db.getTransactionsByLocataire(userId);
      _transactions = raw.map((e) => Transaction.fromJson(e)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement transactions: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> processPayment({
    required int locataireId,
    required String type,
    required double montant,
    required String methode,
    int? bienId,
    int? serviceId,
    bool? isPremiumPlusOverride, // Optionnel pour forcer (ex: services)
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      
      // Déterminer le taux de commission
      double commissionRate = 0.05; // Défaut 5%
      
      if (type == 'loyer' && bienId != null) {
        // Chercher le propriétaire du bien
        final allProps = await db.getProperties(status: null);
        final prop = allProps.firstWhere((p) => p.id == bienId);
        final owner = await db.getUserById(prop.proprietaireId);
        
        if (owner != null && owner.subscriptionType == 'premium_plus' && owner.isSubscriptionActive == true) {
          commissionRate = 0.03; // Taux réduit 3%
        }
      } else if (isPremiumPlusOverride == true) {
        commissionRate = 0.03;
      }

      // Délai de simulation retiré — le vrai paiement se fait via FedaPay

      final reference = 'TRX-${DateTime.now().millisecondsSinceEpoch}';
      
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch,
        locataireId: locataireId,
        type: type,
        montant: montant,
        reference: reference,
        statut: 'confirme',
        methodePaiement: methode,
        bienId: bienId,
        serviceId: serviceId,
        dateCreation: DateTime.now(),
      );

      await db.addTransaction(transaction);
      
      // Enregistrer la commission pour l'admin
      final commissionAmount = montant * commissionRate;
      final description = type == 'loyer' 
          ? 'Commission sur loyer – Bien #$bienId' 
          : 'Commission sur service – #$serviceId';
      
      await db.addCommission({
        'montant': commissionAmount,
        'description': description,
        'type': type,
        'transaction_id': transaction.id,
        'locataire_id': locataireId,
        'taux_applique': commissionRate,
      });

      _transactions.insert(0, transaction);
      _successMessage = 'Paiement simulé – transaction enregistrée';
      
      // Notification
      await NotificationService.addNotification(
        userId: locataireId,
        title: 'Paiement réussi',
        body: 'Votre paiement de ${montant.toStringAsFixed(0)} FCFA a été confirmé. Réf: $reference',
        type: 'payment_success',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors du paiement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> initiateRealPayment({
    required int rentalId,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await ApiService.post('/payments/initiate/$rentalId', {});
      if (response != null && response['payment_url'] != null) {
        _isLoading = false;
        notifyListeners();
        return response['payment_url'];
      } else {
        _error = 'Erreur initialisation paiement serveur';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Erreur réseau: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
