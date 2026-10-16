/// Modèles spécifiques au Dashboard Propriétaire
library;

/// Représente une propriété du propriétaire avec ses stats
class PropertyWithStats {
  final int id;
  final String titre;
  final String localisation;
  final double prix;
  final String typeBien;
  final int nombrePieces;
  final bool verified;
  final int candidaturesRecues;
  final int locataireActif;
  final double revenus;
  final double rating;
  final List<String> photos;

  PropertyWithStats({
    required this.id,
    required this.titre,
    required this.localisation,
    required this.prix,
    required this.typeBien,
    required this.nombrePieces,
    required this.verified,
    required this.candidaturesRecues,
    required this.locataireActif,
    required this.revenus,
    required this.rating,
    required this.photos,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'titre': titre,
    'localisation': localisation,
    'prix': prix,
    'typeBien': typeBien,
    'nombrePieces': nombrePieces,
    'verified': verified,
    'candidaturesRecues': candidaturesRecues,
    'locataireActif': locataireActif,
    'revenus': revenus,
    'rating': rating,
    'photos': photos,
  };

  factory PropertyWithStats.fromJson(Map<String, dynamic> json) =>
      PropertyWithStats(
        id: json['id'] ?? 0,
        titre: json['titre'] ?? '',
        localisation: json['localisation'] ?? '',
        prix: (json['prix'] ?? 0).toDouble(),
        typeBien: json['typeBien'] ?? '',
        nombrePieces: json['nombrePieces'] ?? 0,
        verified: json['verified'] ?? false,
        candidaturesRecues: json['candidaturesRecues'] ?? 0,
        locataireActif: json['locataireActif'] ?? 0,
        revenus: (json['revenus'] ?? 0).toDouble(),
        rating: (json['rating'] ?? 0).toDouble(),
        photos: List<String>.from(json['photos'] ?? []),
      );
}

/// Candidature reçue pour une propriété
class CandidatureRecue {
  final int id;
  final int propertyId;
  final int locataireId;
  final String locataireName;
  final String email;
  final String telephone;
  final String message;
  final String statut; // en_attente, acceptée, rejetée
  final DateTime dateCandidat;
  final String? motifRejet;

  CandidatureRecue({
    required this.id,
    required this.propertyId,
    required this.locataireId,
    required this.locataireName,
    required this.email,
    required this.telephone,
    required this.message,
    required this.statut,
    required this.dateCandidat,
    this.motifRejet,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'propertyId': propertyId,
    'locataireId': locataireId,
    'locataireName': locataireName,
    'email': email,
    'telephone': telephone,
    'message': message,
    'statut': statut,
    'dateCandidat': dateCandidat.toIso8601String(),
    'motifRejet': motifRejet,
  };

  factory CandidatureRecue.fromJson(Map<String, dynamic> json) =>
      CandidatureRecue(
        id: json['id'] ?? 0,
        propertyId: json['propertyId'] ?? 0,
        locataireId: json['locataireId'] ?? 0,
        locataireName: json['locataireName'] ?? '',
        email: json['email'] ?? '',
        telephone: json['telephone'] ?? '',
        message: json['message'] ?? '',
        statut: json['statut'] ?? 'en_attente',
        dateCandidat: DateTime.tryParse(json['dateCandidat'] ?? '') ?? DateTime.now(),
        motifRejet: json['motifRejet'],
      );
}

/// Locataire actif avec ses infos de paiement
class LocataireActif {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final int propertyId;
  final double loyer;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String statutPaiement; // a_jour, retard, paye
  final double rating;
  final bool verified;

  LocataireActif({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.propertyId,
    required this.loyer,
    required this.dateDebut,
    this.dateFin,
    required this.statutPaiement,
    required this.rating,
    required this.verified,
  });

  String get displayName => '$prenom $nom';

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'email': email,
    'telephone': telephone,
    'propertyId': propertyId,
    'loyer': loyer,
    'dateDebut': dateDebut.toIso8601String(),
    'dateFin': dateFin?.toIso8601String(),
    'statutPaiement': statutPaiement,
    'rating': rating,
    'verified': verified,
  };

  factory LocataireActif.fromJson(Map<String, dynamic> json) =>
      LocataireActif(
        id: json['id'] ?? 0,
        nom: json['nom'] ?? '',
        prenom: json['prenom'] ?? '',
        email: json['email'] ?? '',
        telephone: json['telephone'] ?? '',
        propertyId: json['propertyId'] ?? 0,
        loyer: (json['loyer'] ?? 0).toDouble(),
        dateDebut: DateTime.tryParse(json['dateDebut'] ?? '') ?? DateTime.now(),
        dateFin: json['dateFin'] != null ? DateTime.tryParse(json['dateFin']) : null,
        statutPaiement: json['statutPaiement'] ?? 'a_jour',
        rating: (json['rating'] ?? 0).toDouble(),
        verified: json['verified'] ?? false,
      );
}

/// Transaction ou paiement reçu
class Transaction {
  final int id;
  final int propertyId;
  final int locataireId;
  final double montant;
  final DateTime date;
  final String type; // loyer, depot, remboursement
  final String description;
  final String statut; // confirmé, en_attente, échoué

  Transaction({
    required this.id,
    required this.propertyId,
    required this.locataireId,
    required this.montant,
    required this.date,
    required this.type,
    required this.description,
    required this.statut,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'propertyId': propertyId,
    'locataireId': locataireId,
    'montant': montant,
    'date': date.toIso8601String(),
    'type': type,
    'description': description,
    'statut': statut,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      Transaction(
        id: json['id'] ?? 0,
        propertyId: json['propertyId'] ?? 0,
        locataireId: json['locataireId'] ?? 0,
        montant: (json['montant'] ?? 0).toDouble(),
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
        type: json['type'] ?? 'loyer',
        description: json['description'] ?? '',
        statut: json['statut'] ?? 'confirmé',
      );
}

/// Document ou pièce justificative
class Document {
  final int id;
  final int locataireId;
  final String type; // contrat, depot_garantie, quittance
  final String url;
  final DateTime dateUpload;
  final bool verified;

  Document({
    required this.id,
    required this.locataireId,
    required this.type,
    required this.url,
    required this.dateUpload,
    required this.verified,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'locataireId': locataireId,
    'type': type,
    'url': url,
    'dateUpload': dateUpload.toIso8601String(),
    'verified': verified,
  };

  factory Document.fromJson(Map<String, dynamic> json) =>
      Document(
        id: json['id'] ?? 0,
        locataireId: json['locataireId'] ?? 0,
        type: json['type'] ?? '',
        url: json['url'] ?? '',
        dateUpload: DateTime.tryParse(json['dateUpload'] ?? '') ?? DateTime.now(),
        verified: json['verified'] ?? false,
      );
}

/// Problème ou litige avec un locataire
class LitigeLocataire {
  final int id;
  final int propertyId;
  final int locataireId;
  final String titre;
  final String description;
  final String statut; // signalé, en_cours, résolu
  final String priorite; // basse, moyenne, haute, critique
  final DateTime dateSignalement;
  final DateTime? dateResolution;

  LitigeLocataire({
    required this.id,
    required this.propertyId,
    required this.locataireId,
    required this.titre,
    required this.description,
    required this.statut,
    required this.priorite,
    required this.dateSignalement,
    this.dateResolution,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'propertyId': propertyId,
    'locataireId': locataireId,
    'titre': titre,
    'description': description,
    'statut': statut,
    'priorite': priorite,
    'dateSignalement': dateSignalement.toIso8601String(),
    'dateResolution': dateResolution?.toIso8601String(),
  };

  factory LitigeLocataire.fromJson(Map<String, dynamic> json) =>
      LitigeLocataire(
        id: json['id'] ?? 0,
        propertyId: json['propertyId'] ?? 0,
        locataireId: json['locataireId'] ?? 0,
        titre: json['titre'] ?? '',
        description: json['description'] ?? '',
        statut: json['statut'] ?? 'signalé',
        priorite: json['priorite'] ?? 'moyenne',
        dateSignalement: DateTime.tryParse(json['dateSignalement'] ?? '') ?? DateTime.now(),
        dateResolution: json['dateResolution'] != null ? DateTime.tryParse(json['dateResolution']) : null,
      );
}
