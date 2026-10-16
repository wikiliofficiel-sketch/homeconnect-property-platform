import 'package:flutter/foundation.dart';
import '../models/property.dart';
import '../models/extended_models.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

class PropertyProvider extends ChangeNotifier {
  List<Property> _properties = [];
  final List<PropertyStats> _propertyStats = [];
  Property? _currentProperty;
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<Property> get properties => _properties;
  List<PropertyStats> get propertyStats => _propertyStats;
  Property? get currentProperty => _currentProperty;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  int get totalActiveProperties => _properties.where((p) => p.status == 'active' || p.status == 'actif').length;
  int get totalPendingProperties => _properties.where((p) => p.status == 'pending' || p.status == 'en_attente').length;
  int get totalViews => _properties.fold(0, (sum, p) => sum + p.views);

  Future<void> syncData([int? ownerId]) async {
    if (ownerId != null) {
      await loadPropertiesByOwner(ownerId);
    } else {
      await loadAllProperties();
    }
  }

  /// Charger TOUS les biens disponibles (pour locataire / admin) depuis l'API
  Future<void> loadAllProperties() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final raw = await ApiService.getProperties();
      _properties = raw.map((p) => Property.fromApiMap(Map<String, dynamic>.from(p))).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les biens d'un propriétaire depuis l'API
  Future<void> loadPropertiesByOwner(int ownerId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final raw = await ApiService.getOwnerProperties();
      _properties = raw.map((p) => Property.fromApiMap(Map<String, dynamic>.from(p))).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Fallback sur la cache locale
      debugPrint('API loadPropertiesByOwner error: $e — fallback local');
      try {
        final db = DatabaseHelper();
        final rawLocal = await db.getAllProperties();
        _properties = rawLocal
            .where((p) => p['proprietaireId'] == ownerId)
            .map((p) => Property.fromMap(p))
            .toList();
      } catch (_) {}
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une propriété via l'API
  Future<bool> createProperty({
    required String title,
    required String location,
    required int price,
    required int rooms,
    required String type,
    required int ownerId,
    String? description,
    List<String>? photos,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      final ok = await ApiService.createProperty({
        'title':        title,
        'address':      location,
        'city':         location,
        'pricePerMonth': price,
        'rooms':        rooms,
        'bedrooms':     rooms,
        'surface':      0,
        'type':         type,
        'description':  description ?? '',
        'images':       photos ?? [],
      });

      if (ok) {
        _successMessage = 'Bien soumis pour validation. Visible après approbation admin.';
        await loadPropertiesByOwner(ownerId);
      } else {
        _error = 'Erreur lors de la création du bien.';
      }

      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = 'Erreur: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProperty({required int propertyId, String? title, String? location, int? price}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ok = await ApiService.post('/api/properties/$propertyId/edit', {
        if (title != null)    'title': title,
        if (location != null) 'address': location,
        if (price != null)    'pricePerMonth': price,
      });
      if (ok != null) {
        _successMessage = 'Propriété mise à jour';
        final idx = _properties.indexWhere((p) => p.id == propertyId);
        if (idx != -1) notifyListeners();
      } else {
        _error = 'Mise à jour échouée';
      }
      _isLoading = false;
      notifyListeners();
      return ok != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProperty(int propertyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ok = await ApiService.post('/api/properties/$propertyId/delete', {});
      _properties.removeWhere((p) => p.id == propertyId);
      _isLoading = false;
      notifyListeners();
      return ok != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> incrementPropertyViews(int propertyId) async {
    try {
      await ApiService.post('/api/properties/$propertyId/view', {});
      final idx = _properties.indexWhere((p) => p.id == propertyId);
      if (idx != -1) {
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Méthodes additionnelles utilisées dans les écrans ─────────────────────

  /// Récupère une propriété par ID depuis la liste en mémoire
  Property? getProperty(int propertyId) {
    try {
      return _properties.firstWhere((p) => p.id == propertyId);
    } catch (_) {
      return null;
    }
  }

  /// Stats d'une propriété (vues, likes, etc.)
  PropertyStats? getPropertyStats(int propertyId) {
    try {
      return _propertyStats.firstWhere((s) => s.propertyId == propertyId);
    } catch (_) {
      return null;
    }
  }

  /// Mettre en avant un bien pendant N jours
  Future<bool> highlightProperty(int propertyId, int days) async {
    try {
      final ok = await ApiService.post('/api/properties/$propertyId/highlight', {'days': days});
      if (ok != null) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
