import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;

  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
  });
}

// Scénario : Traiter paiement
class ProcessPaymentRequest {
  final int userId;
  final String authToken;
  final int amount;
  final String description;
  final String provider; // mtn, celtis, stripe

  ProcessPaymentRequest({
    required this.userId,
    required this.authToken,
    required this.amount,
    required this.description,
    required this.provider,
  });
}

abstract class BasePaymentService {
  Future<bool> initiatePayment({
    required String amount,
    required String currency,
    required String provider, // 'mtn', 'moov', 'stripe'
    required String phoneNumber,
  });
}

class MockPaymentService implements BasePaymentService {
  @override
  Future<bool> initiatePayment({
    required String amount,
    required String currency,
    required String provider,
    required String phoneNumber,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('[Payment] simulé: $amount $currency via $provider → $phoneNumber');
    return true; // Simuler succès
  }
}

class PaymentService {
  static Future<PaymentResult> payWithMtn({
    required String telephone,
    required int amount,
    required String description,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return PaymentResult(
        success: true,
        message: 'Paiement MTN réussi de ${amount}F',
        transactionId: 'MTN_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Erreur de paiement MTN: $e',
      );
    }
  }

  static Future<PaymentResult> payWithCeltis({
    required String account,
    required int amount,
    required String description,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return PaymentResult(
        success: true,
        message: 'Paiement Celtis réussi de ${amount}F',
        transactionId: 'CELTIS_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Erreur de paiement Celtis: $e',
      );
    }
  }

  static Future<PaymentResult> payWithKidaap({
    required int amount,
    required String description,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return PaymentResult(
        success: true,
        message: 'Paiement KIDAPP (HomeConnect) réussi: ${amount}F',
        transactionId: 'KIDAAP_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return PaymentResult(success: false, message: 'Erreur KIDAPP: $e');
    }
  }

  static Future<PaymentResult> payWithFidaap({
    required int amount,
    required String description,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return PaymentResult(
        success: true,
        message: 'Paiement FIDAPP réussi: ${amount}F',
        transactionId: 'FIDAAP_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return PaymentResult(success: false, message: 'Erreur FIDAPP: $e');
    }
  }

  /// MÉTHODE PRINCIPALE : Traiter paiement
  static Future<PaymentResult> traiterPaiement(ProcessPaymentRequest request) async {
    // 1. Vérification de l'authentification (Simulation)
    if (request.authToken.isEmpty || request.authToken == 'invalid') {
      return PaymentResult(success: false, message: 'Erreur d\'authentification : Action refusée.');
    }

    // 2. Traitement selon le fournisseur
    PaymentResult result;
    if (request.provider == 'mtn') {
      result = await payWithMtn(telephone: '00229...', amount: request.amount, description: request.description);
    } else if (request.provider == 'celtis') {
      result = await payWithCeltis(account: '00229...', amount: request.amount, description: request.description);
    } else if (request.provider == 'kidaap') {
      result = await payWithKidaap(amount: request.amount, description: request.description);
    } else if (request.provider == 'fidaap') {
      result = await payWithFidaap(amount: request.amount, description: request.description);
    } else {
      result = PaymentResult(success: false, message: 'Fournisseur de paiement non supporté.');
    }

    // 3. Journalisation (Logs système)
    final db = DatabaseHelper();
    if (result.success) {
      await db.addLog(
        userId: request.userId,
        action: 'Traitement Paiement',
        details: 'Paiement réussi de ${request.amount} FCFA via ${request.provider}. ID: ${result.transactionId}',
        type: 'financial',
      );
      
      // Enregistrer dans les commissions si applicable
      await db.addCommission({
        'amount': request.amount,
        'commission': (request.amount * 0.1).toInt(), // 10% par défaut
        'date': DateTime.now().toIso8601String(),
        'property_title': request.description,
      });
    } else {
      await db.addLog(
        userId: request.userId,
        action: 'Échec Paiement',
        details: 'Échec de paiement de ${request.amount} FCFA. Raison: ${result.message}',
        type: 'security',
      );
    }

    return result;
  }
}