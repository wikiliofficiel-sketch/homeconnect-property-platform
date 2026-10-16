import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  Map<String, dynamic>? _current;
  List<dynamic> _plans = [];
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  Map<String, dynamic>? get current => _current;
  List<dynamic> get plans => _plans;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  // Accès rapides
  String get planKey => _current?['plan'] as String? ?? 'free';
  String get planLabel => _current?['planLabel'] as String? ?? 'Gratuit';
  int? get maxProperties => _current?['maxProperties'] as int?;
  bool get canPublishMore => _current?['canPublishMore'] as bool? ?? false;
  bool? get canAdd => _current?['canAdd'] as bool?;
  int? get remainingSlots => _current?['remainingSlots'] as int?;
  int get publishedCount => _current?['publishedCount'] as int? ?? 0;
  bool get isFree => planKey == 'free';
  bool get isStarter => planKey == 'starter';
  bool get isPro => planKey == 'pro';
  String? get nextPlan => _current?['nextPlan'] as String?;
  String? get nextPlanLabel => _current?['nextPlanLabel'] as String?;
  int? get nextPlanPrice => _current?['nextPlanPrice'] as int?;

  // Alias rétro-compat
  Map<String, dynamic>? get currentSubscription => _current;
  bool get isPremiumActive => !isFree && (_current?['isActive'] as bool? ?? false);
  int get daysRemaining {
    final exp = _current?['dateExpiration'] as String?;
    if (exp == null) return 0;
    try {
      final d = DateTime.parse(exp).difference(DateTime.now()).inDays;
      return d > 0 ? d : 0;
    } catch (_) { return 0; }
  }

  /// Charger depuis l'API (même BDD que le web)
  Future<void> loadCurrentSubscription([int? userId]) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _current = await ApiService.getCurrentSubscription();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement abonnement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlans() async {
    try {
      _plans = await ApiService.getSubscriptionPlans();
      notifyListeners();
    } catch (e) {
      debugPrint('loadPlans error: $e');
    }
  }

  /// Passer au plan supérieur
  Future<Map<String, dynamic>?> upgrade({
    required String plan,
    int months = 1,
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.upgradeSubscription(
          plan: plan, months: months);
      if (result != null) {
        if (result['success'] == true) {
          _current = result['subscription'] as Map<String, dynamic>?;
          _successMessage = result['message'] as String? ?? 'Abonnement activé !';
        }
        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = 'Erreur lors de la mise à niveau.';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Erreur: $e';
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
