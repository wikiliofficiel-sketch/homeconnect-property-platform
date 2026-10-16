import 'package:flutter/foundation.dart';
import '../models/proprietaire_models.dart';
import '../services/database_helper.dart';

/// Provider pour la gestion du Dashboard Propriétaire
class ProprietaireProvider extends ChangeNotifier {
  final List<PropertyWithStats> _properties = [];
  final List<CandidatureRecue> _candidatures = [];
  final List<LocataireActif> _locatairesActifs = [];
  final List<Transaction> _transactions = [];
  final List<LitigeLocataire> _litiges = [];

  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  // Getters
  List<PropertyWithStats> get properties => _properties;
  List<CandidatureRecue> get candidatures => _candidatures;
  List<LocataireActif> get locatairesActifs => _locatairesActifs;
  List<Transaction> get transactions => _transactions;
  List<LitigeLocataire> get litiges => _litiges;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  // Calculs des stats
  int get totalBiens => _properties.length;
  int get candidaturesTotal => _candidatures.where((c) => c.statut == 'en_attente').length;
  double get revenusTotal => _transactions.where((t) => t.statut == 'confirmé').fold(0, (sum, t) => sum + t.montant);
  double get ratingMoyen => _properties.isEmpty ? 0 : _properties.fold(0.0, (sum, p) => sum + p.rating) / _properties.length;

  /// Charge tous les biens du propriétaire
  Future<void> loadProprietaireBiens(int proprietaireId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      final biens = await db.getPropertiesForOwner(proprietaireId);

      _properties.clear();
      for (final bien in biens) {
        _properties.add(PropertyWithStats.fromJson(bien));
      }

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement biens: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les candidatures reçues
  Future<void> loadCandidatures() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      final rawCandidatures = await db.getList('candidatures_recues');

      _candidatures.clear();
      for (final raw in rawCandidatures) {
        _candidatures.add(CandidatureRecue.fromJson(raw));
      }

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement candidatures: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Accepte une candidature
  Future<void> accepterCandidature(int candidatureId) async {
    try {
      final db = DatabaseHelper();
      final candidatures = await db.getList('candidatures_recues');
      
      final idx = candidatures.indexWhere((c) => c['id'] == candidatureId);
      if (idx != -1) {
        candidatures[idx]['statut'] = 'acceptée';
        await db.setList('candidatures_recues', candidatures);
        
        final cand = _candidatures.firstWhere((c) => c.id == candidatureId);
        final updatedCand = CandidatureRecue(
          id: cand.id,
          propertyId: cand.propertyId,
          locataireId: cand.locataireId,
          locataireName: cand.locataireName,
          email: cand.email,
          telephone: cand.telephone,
          message: cand.message,
          statut: 'acceptée',
          dateCandidat: cand.dateCandidat,
        );
        
        final candIdx = _candidatures.indexWhere((c) => c.id == candidatureId);
        if (candIdx != -1) {
          _candidatures[candIdx] = updatedCand;
        }
        
        _successMessage = 'Candidature acceptée ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur acceptation: $e';
      notifyListeners();
    }
  }

  /// Rejette une candidature
  Future<void> rejeterCandidature(int candidatureId, String motif) async {
    try {
      final db = DatabaseHelper();
      final candidatures = await db.getList('candidatures_recues');
      
      final idx = candidatures.indexWhere((c) => c['id'] == candidatureId);
      if (idx != -1) {
        candidatures[idx]['statut'] = 'rejetée';
        candidatures[idx]['motifRejet'] = motif;
        await db.setList('candidatures_recues', candidatures);
        
        final cand = _candidatures.firstWhere((c) => c.id == candidatureId);
        final updatedCand = CandidatureRecue(
          id: cand.id,
          propertyId: cand.propertyId,
          locataireId: cand.locataireId,
          locataireName: cand.locataireName,
          email: cand.email,
          telephone: cand.telephone,
          message: cand.message,
          statut: 'rejetée',
          dateCandidat: cand.dateCandidat,
          motifRejet: motif,
        );
        
        final candIdx = _candidatures.indexWhere((c) => c.id == candidatureId);
        if (candIdx != -1) {
          _candidatures[candIdx] = updatedCand;
        }
        
        _successMessage = 'Candidature rejetée';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur rejet: $e';
      notifyListeners();
    }
  }

  /// Charge les locataires actifs
  Future<void> loadLocatairesActifs() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      final rawLocataires = await db.getList('locataires_actifs');

      _locatairesActifs.clear();
      for (final raw in rawLocataires) {
        _locatairesActifs.add(LocataireActif.fromJson(raw));
      }

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement locataires: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les transactions/paiements
  Future<void> loadTransactions() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      final rawTransactions = await db.getList('transactions');

      _transactions.clear();
      for (final raw in rawTransactions) {
        _transactions.add(Transaction.fromJson(raw));
      }

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement transactions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les litiges/signalements
  Future<void> loadLitiges() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      final rawLitiges = await db.getList('litiges_locataires');

      _litiges.clear();
      for (final raw in rawLitiges) {
        _litiges.add(LitigeLocataire.fromJson(raw));
      }

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement litiges: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Termine un litige
  Future<void> terminerLitige(int litigeId) async {
    try {
      final db = DatabaseHelper();
      final litiges = await db.getList('litiges_locataires');
      
      final idx = litiges.indexWhere((l) => l['id'] == litigeId);
      if (idx != -1) {
        litiges[idx]['statut'] = 'résolu';
        litiges[idx]['dateResolution'] = DateTime.now().toIso8601String();
        await db.setList('litiges_locataires', litiges);
        
        final litige = _litiges.firstWhere((l) => l.id == litigeId);
        final updatedLitige = LitigeLocataire(
          id: litige.id,
          propertyId: litige.propertyId,
          locataireId: litige.locataireId,
          titre: litige.titre,
          description: litige.description,
          statut: 'résolu',
          priorite: litige.priorite,
          dateSignalement: litige.dateSignalement,
          dateResolution: DateTime.now(),
        );
        
        final litigesIdx = _litiges.indexWhere((l) => l.id == litigeId);
        if (litigesIdx != -1) {
          _litiges[litigesIdx] = updatedLitige;
        }
        
        _successMessage = 'Litige résolu ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur résolution: $e';
      notifyListeners();
    }
  }

  /// Crée un nouveau bien
  Future<void> creerBien({
    required String titre,
    required String localisation,
    required double prix,
    required String typeBien,
    required int nombrePieces,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newProperty = PropertyWithStats(
        id: DateTime.now().millisecondsSinceEpoch,
        titre: titre,
        localisation: localisation,
        prix: prix,
        typeBien: typeBien,
        nombrePieces: nombrePieces,
        verified: false,
        candidaturesRecues: 0,
        locataireActif: 0,
        revenus: 0,
        rating: 0,
        photos: [],
      );

      final db = DatabaseHelper();
      final props = await db.getList('proprietaire_biens');
      props.add(newProperty.toJson());
      await db.setList('proprietaire_biens', props);

      _properties.add(newProperty);
      _successMessage = 'Bien créé avec succès ✅';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur création: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Nettoie les messages
  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
