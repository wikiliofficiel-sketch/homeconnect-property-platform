// ============================================================
// lib/models/user.dart
// ============================================================
class User {
  final int id;
  final String telephone;
  final String? email;
  final String nom;
  final String prenom;
  final String nomComplet;
  final String role;
  final String? photoProfil;
  final bool isVerified;
  final String verificationStatus;
  final String abonnementType;
  final bool abonnementActif;
  final String? ville;
  final double noteMoyenne;
  final int nbEvaluations;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.telephone,
    this.email,
    required this.nom,
    required this.prenom,
    required this.nomComplet,
    required this.role,
    this.photoProfil,
    required this.isVerified,
    required this.verificationStatus,
    required this.abonnementType,
    required this.abonnementActif,
    this.ville,
    required this.noteMoyenne,
    required this.nbEvaluations,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        telephone: json['telephone'],
        email: json['email'],
        nom: json['nom'],
        prenom: json['prenom'],
        nomComplet: json['nom_complet'] ?? '${json['prenom']} ${json['nom']}',
        role: json['role'],
        photoProfil: json['photo_profil'],
        isVerified: json['is_verified'] ?? false,
        verificationStatus: json['verification_status'] ?? 'en_attente',
        abonnementType: json['abonnement_type'] ?? 'gratuit',
        abonnementActif: json['abonnement_actif'] ?? false,
        ville: json['ville'],
        noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
        nbEvaluations: json['nb_evaluations'] ?? 0,
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get isProprietaire => role == 'proprietaire';
  bool get isLocataire => role == 'locataire';
  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'id': id,
        'telephone': telephone,
        'email': email,
        'nom': nom,
        'prenom': prenom,
        'nom_complet': nomComplet,
        'role': role,
        'photo_profil': photoProfil,
        'is_verified': isVerified,
        'verification_status': verificationStatus,
        'abonnement_type': abonnementType,
        'abonnement_actif': abonnementActif,
        'ville': ville,
        'note_moyenne': noteMoyenne,
        'nb_evaluations': nbEvaluations,
        'created_at': createdAt.toIso8601String(),
      };
}

// ============================================================
// lib/models/bien.dart
// ============================================================
class Bien {
  final int id;
  final String reference;
  final String titre;
  final String? description;
  final String typeBien;
  final String ville;
  final String commune;
  final String quartier;
  final String? adresse;
  final double? latitude;
  final double? longitude;
  final int loyerMensuel;
  final int? caution;
  final int charges;
  final bool negociable;
  final int? nbChambres;
  final int? nbPieces;
  final double? surface;
  final bool meuble;
  final String statut;
  final bool isFeatured;
  final int nbVues;
  final String? imagePrincipale;
  final List<BienImage> images;
  final Equipements? equipements;
  final UserMinimal? proprietaire;
  final DateTime createdAt;

  const Bien({
    required this.id,
    required this.reference,
    required this.titre,
    this.description,
    required this.typeBien,
    required this.ville,
    required this.commune,
    required this.quartier,
    this.adresse,
    this.latitude,
    this.longitude,
    required this.loyerMensuel,
    this.caution,
    required this.charges,
    required this.negociable,
    this.nbChambres,
    this.nbPieces,
    this.surface,
    required this.meuble,
    required this.statut,
    required this.isFeatured,
    required this.nbVues,
    this.imagePrincipale,
    this.images = const [],
    this.equipements,
    this.proprietaire,
    required this.createdAt,
  });

  factory Bien.fromJson(Map<String, dynamic> json) => Bien(
        id: json['id'],
        reference: json['reference'] ?? '',
        titre: json['titre'],
        description: json['description'],
        typeBien: json['type_bien'],
        ville: json['ville'],
        commune: json['commune'],
        quartier: json['quartier'],
        adresse: json['adresse'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        loyerMensuel: json['loyer_mensuel'],
        caution: json['caution'],
        charges: json['charges'] ?? 0,
        negociable: json['negociable'] ?? false,
        nbChambres: json['nb_chambres'],
        nbPieces: json['nb_pieces'],
        surface: json['surface']?.toDouble(),
        meuble: json['meuble'] ?? false,
        statut: json['statut'] ?? 'actif',
        isFeatured: json['is_featured'] ?? false,
        nbVues: json['nb_vues'] ?? 0,
        imagePrincipale: json['image_principale'],
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => BienImage.fromJson(e))
            .toList(),
        equipements: json['equipements'] != null
            ? Equipements.fromJson(json['equipements'])
            : null,
        proprietaire: json['proprietaire'] != null
            ? UserMinimal.fromJson(json['proprietaire'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );

  String get loyerFormate => '${_formatMontant(loyerMensuel)} FCFA/mois';
  String get cautionFormatee =>
      caution != null ? '${_formatMontant(caution!)} FCFA' : 'Aucune';

  static String _formatMontant(int montant) {
    return montant.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}

class BienImage {
  final int id;
  final String url;
  final int ordre;
  final bool estPrincipale;

  const BienImage(
      {required this.id,
      required this.url,
      required this.ordre,
      required this.estPrincipale});

  factory BienImage.fromJson(Map<String, dynamic> json) => BienImage(
        id: json['id'],
        url: json['url'],
        ordre: json['ordre'] ?? 0,
        estPrincipale: json['est_principale'] ?? false,
      );
}

class Equipements {
  final bool eauCourante;
  final bool electricite;
  final bool climatisation;
  final bool wifi;
  final bool parking;
  final bool gardien;
  final bool groupeElectrogene;

  const Equipements({
    required this.eauCourante,
    required this.electricite,
    required this.climatisation,
    required this.wifi,
    required this.parking,
    required this.gardien,
    required this.groupeElectrogene,
  });

  factory Equipements.fromJson(Map<String, dynamic> json) => Equipements(
        eauCourante: json['eau_courante'] ?? false,
        electricite: json['electricite'] ?? false,
        climatisation: json['climatisation'] ?? false,
        wifi: json['wifi'] ?? false,
        parking: json['parking'] ?? false,
        gardien: json['gardien'] ?? false,
        groupeElectrogene: json['groupe_electrogene'] ?? false,
      );
}

class UserMinimal {
  final int id;
  final String nomComplet;
  final String? photoProfil;
  final double noteMoyenne;
  final int nbEvaluations;
  final bool isVerified;

  const UserMinimal({
    required this.id,
    required this.nomComplet,
    this.photoProfil,
    required this.noteMoyenne,
    required this.nbEvaluations,
    required this.isVerified,
  });

  factory UserMinimal.fromJson(Map<String, dynamic> json) => UserMinimal(
        id: json['id'],
        nomComplet: json['nom_complet'],
        photoProfil: json['photo_profil'],
        noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
        nbEvaluations: json['nb_evaluations'] ?? 0,
        isVerified: json['is_verified'] ?? false,
      );
}

// ============================================================
// lib/models/rendez_vous.dart
// ============================================================
class RendezVous {
  final int id;
  final String statut;
  final DateTime dateVisite;
  final String? message;
  final String? notes;
  final Map<String, dynamic> bien;
  final Map<String, dynamic> locataire;
  final DateTime createdAt;

  const RendezVous({
    required this.id,
    required this.statut,
    required this.dateVisite,
    this.message,
    this.notes,
    required this.bien,
    required this.locataire,
    required this.createdAt,
  });

  factory RendezVous.fromJson(Map<String, dynamic> json) => RendezVous(
        id: json['id'],
        statut: json['statut'],
        dateVisite: DateTime.parse(json['date_visite']),
        message: json['message'],
        notes: json['notes'],
        bien: Map<String, dynamic>.from(json['bien'] ?? {}),
        locataire: Map<String, dynamic>.from(json['locataire'] ?? {}),
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get enAttente => statut == 'en_attente';
  bool get confirme => statut == 'confirme';
  bool get annule => statut == 'annule';
}

// ============================================================
// lib/models/notification.dart
// ============================================================
class AppNotification {
  final int id;
  final String type;
  final String titre;
  final String message;
  final Map<String, dynamic>? data;
  final bool estLue;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    this.data,
    required this.estLue,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        type: json['type'],
        titre: json['titre'],
        message: json['message'],
        data: json['data'] != null
            ? Map<String, dynamic>.from(json['data'])
            : null,
        estLue: json['est_lue'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );
}
