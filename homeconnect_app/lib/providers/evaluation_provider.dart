import 'package:flutter/foundation.dart';
import '../models/extended_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class EvaluationProvider extends ChangeNotifier {
  List<Evaluation> _evaluationsReceived = [];
  List<Evaluation> _evaluationsGiven = [];
  final Map<int, double> _averageRatings = {}; // userId -> average rating
  final Map<int, int> _ratingCounts = {}; // userId -> count
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<Evaluation> get evaluationsReceived => _evaluationsReceived;
  List<Evaluation> get evaluationsGiven => _evaluationsGiven;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;
  Map<int, double> get averageRatings => _averageRatings;
  Map<int, int> get ratingCounts => _ratingCounts;

  /// Charger les évaluations reçues par un utilisateur
  Future<void> loadEvaluationsReceived(int userId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawEvals = await db.getEvaluationsReceived(userId);
      
      _evaluationsReceived = rawEvals
          .map((e) => Evaluation.fromJson(e))
          .toList();

      // Calculer la moyenne
      _calculateAverageRating(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les évaluations données par un utilisateur
  Future<void> loadEvaluationsGiven(int userId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawEvals = await db.getEvaluationsGiven(userId);
      
      _evaluationsGiven = rawEvals
          .map((e) => Evaluation.fromJson(e))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajouter une évaluation
  Future<bool> addEvaluation({
    required int evaluatorId,
    required int evaluatedId,
    int? propertyId,
    required double rating,
    String? comment,
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      // Vérifier que la note est valide (1-5)
      if (rating < 1 || rating > 5) {
        _error = 'La note doit être entre 1 et 5';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Vérifier qu'il n'existe pas déjà une évaluation pour ce contrat/bien si spécifié
      // Sinon vérifier par utilisateur
      bool alreadyRated = false;
      if (propertyId != null) {
        alreadyRated = _evaluationsGiven.any((e) => 
          e.evaluateurId == evaluatorId && e.evaluId == evaluatedId && e.propertyId == propertyId
        );
      } else {
        alreadyRated = _evaluationsGiven.any((e) => 
          e.evaluateurId == evaluatorId && e.evaluId == evaluatedId
        );
      }

      if (alreadyRated) {
        _error = 'Vous avez déjà évalué cet utilisateur pour ce bien';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newEvaluation = Evaluation(
        id: DateTime.now().millisecondsSinceEpoch,
        evaluateurId: evaluatorId,
        evaluId: evaluatedId,
        propertyId: propertyId,
        note: rating,
        commentaire: comment,
        dateCreation: DateTime.now(),
      );

      final db = DatabaseHelper();
      await db.addEvaluation(newEvaluation);

      _evaluationsGiven.add(newEvaluation);
      _calculateAverageRating(evaluatedId);

      _successMessage = 'Évaluation enregistrée avec succès';
      _isLoading = false;
      notifyListeners();
      
      // 🔔 Envoyer une notification automatique à l'utilisateur évalué
      await NotificationService.addNotification(
        userId: evaluatedId,
        title: 'Nouvelle évaluation reçue',
        body: 'Vous avez reçu une nouvelle évaluation de ${rating.toStringAsFixed(1)}/5 étoiles.',
        type: 'evaluation_received',
      );
      
      return true;
    } catch (e) {
      _error = 'Erreur lors de l\'enregistrement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calculer la moyenne des notes
  void _calculateAverageRating(int userId) {
    if (_evaluationsReceived.isEmpty && userId != 0) {
      // On ne peut pas calculer si on n'a pas les evals reçues pour cet utilisateur
      // Si on vient de charger les evals reçues de cet utilisateur, _evaluationsReceived les contient
    }

    final userEvals = _evaluationsReceived.where((e) => e.evaluId == userId).toList();
    if (userEvals.isEmpty) {
      _averageRatings[userId] = 0.0;
      _ratingCounts[userId] = 0;
      return;
    }

    final sum = userEvals.fold(0.0, (prev, e) => prev + e.note);
    final average = sum / userEvals.length;

    _averageRatings[userId] = double.parse(average.toStringAsFixed(1));
    _ratingCounts[userId] = userEvals.length;
  }

  /// Obtenir la note moyenne d'un utilisateur
  double getAverageRating(int userId) {
    return _averageRatings[userId] ?? 0.0;
  }

  /// Obtenir le nombre d'évaluations
  int getRatingCount(int userId) {
    return _ratingCounts[userId] ?? 0;
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
