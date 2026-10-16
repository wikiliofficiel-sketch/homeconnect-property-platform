import 'dart:convert';

class Property {
  final int id;
  final String titre;
  final String lieu;
  final int prix;
  final int pieces;
  final String type;
  final int proprietaireId;
  final String status;
  final bool verified;
  final int views;
  final int reports;
  final bool isHighlighted;
  final DateTime? highlightedUntil;
  final DateTime? createdAt;
  final double rating;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? description;

  final int likes;
  final int dislikes;
  final int commentsCount;
  final bool isReserved;
  final String? videoUrl;
  final List<String> additionalImages;
  final String? descriptionDetaillee;
  final String? propertyVideoUrl;

  // New fields from 2026-04-28 request
  final String statutAnnonce; // 'À louer' / 'À vendre' / 'Les deux'
  final double superficie;
  final String ville;
  final String? codePostal;
  final int? prixVente;
  final bool chargesComprises;
  final int? montantCharges;
  final int? depotGarantie;
  final int? fraisAgence;
  final int nbChambres;
  final int nbSalons;
  final int nbSallesDeBain;
  final int nbToilettes;
  final String typeCuisine;
  final int? etage;
  final bool hasAscenseur;
  final bool hasParking;
  final int parkingPlaces;
  final bool hasJardin;
  final bool hasBalcon;
  final List<String> equipements;
  final String? planUrl;
  final bool animauxAcceptes;
  final bool fumeursAcceptes;
  final int? dureeMinLocation;
  final int? preavis;
  final DateTime? disponibilite;

  Property({
    required this.id,
    required this.titre,
    required this.lieu,
    required this.prix,
    this.pieces = 0,
    this.type = 'Appartement',
    required this.proprietaireId,
    this.status = 'en_attente',
    this.verified = false,
    this.views = 0,
    this.reports = 0,
    this.isHighlighted = false,
    this.highlightedUntil,
    this.createdAt,
    this.rating = 0.0,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.description,
    this.likes = 0,
    this.dislikes = 0,
    this.commentsCount = 0,
    this.isReserved = false,
    this.videoUrl,
    this.additionalImages = const [],
    this.descriptionDetaillee,
    
    // New fields defaults
    this.statutAnnonce = 'À louer',
    this.superficie = 0.0,
    this.ville = '',
    this.codePostal,
    this.prixVente,
    this.chargesComprises = false,
    this.montantCharges,
    this.depotGarantie,
    this.fraisAgence,
    this.nbChambres = 0,
    this.nbSalons = 0,
    this.nbSallesDeBain = 0,
    this.nbToilettes = 0,
    this.typeCuisine = 'Non équipée',
    this.etage,
    this.hasAscenseur = false,
    this.hasParking = false,
    this.parkingPlaces = 0,
    this.hasJardin = false,
    this.hasBalcon = false,
    this.equipements = const [],
    this.planUrl,
    this.animauxAcceptes = false,
    this.fumeursAcceptes = false,
    this.dureeMinLocation,
    this.preavis,
    this.disponibilite,
    this.propertyVideoUrl,
  });

  factory Property.fromMap(Map<String, dynamic> map) {
    bool toBool(dynamic v) => v == 1 || v == true || v == '1' || v == 'true';
    // Handles both List and JSON-encoded String (MySQL stores JSON arrays as strings)
    List<String> toStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) {
        try {
          final parsed = jsonDecode(v);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }
    
    return Property(
      id: (map['id'] as num?)?.toInt() ?? 0,
      titre: map['titre'] as String? ?? '',
      lieu: map['lieu'] as String? ?? '',
      prix: (map['prix'] as num?)?.toInt() ?? 0,
      pieces: (map['pieces'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? 'Appartement',
      proprietaireId: (map['proprietaireId'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'en_attente',
      verified: toBool(map['verified']),
      views: (map['views'] as num?)?.toInt() ?? 0,
      reports: (map['reports'] as num?)?.toInt() ?? 0,
      isHighlighted: toBool(map['isHighlighted']),
      highlightedUntil: map['highlightedUntil'] != null 
          ? DateTime.tryParse(map['highlightedUntil'].toString()) 
          : null,
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt'].toString()) 
          : null,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] as String?,
      description: map['description'] as String?,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      dislikes: (map['dislikes'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      isReserved: toBool(map['isReserved']),
      videoUrl: map['videoUrl'] as String?,
      additionalImages: toStringList(map['additionalImages']),
      descriptionDetaillee: map['descriptionDetaillee'] as String?,
      propertyVideoUrl: map['propertyVideoUrl'] as String?,

      // New fields from map
      statutAnnonce: map['statutAnnonce'] as String? ?? 'À louer',
      superficie: (map['superficie'] as num?)?.toDouble() ?? 0.0,
      ville: map['ville'] as String? ?? '',
      codePostal: map['codePostal'] as String?,
      prixVente: (map['prixVente'] as num?)?.toInt(),
      chargesComprises: toBool(map['chargesComprises']),
      montantCharges: (map['montantCharges'] as num?)?.toInt(),
      depotGarantie: (map['depotGarantie'] as num?)?.toInt(),
      fraisAgence: (map['fraisAgence'] as num?)?.toInt(),
      nbChambres: (map['nbChambres'] as num?)?.toInt() ?? 0,
      nbSalons: (map['nbSalons'] as num?)?.toInt() ?? 0,
      nbSallesDeBain: (map['nbSallesDeBain'] as num?)?.toInt() ?? 0,
      nbToilettes: (map['nbToilettes'] as num?)?.toInt() ?? 0,
      typeCuisine: map['typeCuisine'] as String? ?? 'Non équipée',
      etage: (map['etage'] as num?)?.toInt(),
      hasAscenseur: toBool(map['hasAscenseur']),
      hasParking: toBool(map['hasParking']),
      parkingPlaces: (map['parkingPlaces'] as num?)?.toInt() ?? 0,
      hasJardin: toBool(map['hasJardin']),
      hasBalcon: toBool(map['hasBalcon']),
      equipements: toStringList(map['equipements']),
      planUrl: map['planUrl'] as String?,
      animauxAcceptes: toBool(map['animauxAcceptes']),
      fumeursAcceptes: toBool(map['fumeursAcceptes']),
      dureeMinLocation: (map['dureeMinLocation'] as num?)?.toInt(),
      preavis: (map['preavis'] as num?)?.toInt(),
      disponibilite: map['disponibilite'] != null ? DateTime.tryParse(map['disponibilite'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'lieu': lieu,
      'prix': prix,
      'pieces': pieces,
      'type': type,
      'proprietaireId': proprietaireId,
      'status': status,
      'verified': verified ? 1 : 0,
      'views': views,
      'reports': reports,
      'isHighlighted': isHighlighted ? 1 : 0,
      'highlightedUntil': highlightedUntil?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'description': description,
      'likes': likes,
      'dislikes': dislikes,
      'commentsCount': commentsCount,
      'isReserved': isReserved ? 1 : 0,
      'videoUrl': videoUrl,
      'additionalImages': additionalImages,
      'descriptionDetaillee': descriptionDetaillee,
      'propertyVideoUrl': propertyVideoUrl,

      // New fields to map
      'statutAnnonce': statutAnnonce,
      'superficie': superficie,
      'ville': ville,
      'codePostal': codePostal,
      'prixVente': prixVente,
      'chargesComprises': chargesComprises ? 1 : 0,
      'montantCharges': montantCharges,
      'depotGarantie': depotGarantie,
      'fraisAgence': fraisAgence,
      'nbChambres': nbChambres,
      'nbSalons': nbSalons,
      'nbSallesDeBain': nbSallesDeBain,
      'nbToilettes': nbToilettes,
      'typeCuisine': typeCuisine,
      'etage': etage,
      'hasAscenseur': hasAscenseur ? 1 : 0,
      'hasParking': hasParking ? 1 : 0,
      'parkingPlaces': parkingPlaces,
      'hasJardin': hasJardin ? 1 : 0,
      'hasBalcon': hasBalcon ? 1 : 0,
      'equipements': equipements,
      'planUrl': planUrl,
      'animauxAcceptes': animauxAcceptes ? 1 : 0,
      'fumeursAcceptes': fumeursAcceptes ? 1 : 0,
      'dureeMinLocation': dureeMinLocation,
      'preavis': preavis,
      'disponibilite': disponibilite?.toIso8601String(),
    };
  }

  Property copyWith({
    int? id,
    String? titre,
    String? lieu,
    int? prix,
    int? pieces,
    String? type,
    int? proprietaireId,
    String? status,
    bool? verified,
    int? views,
    int? reports,
    bool? isHighlighted,
    DateTime? highlightedUntil,
    DateTime? createdAt,
    double? rating,
    double? latitude,
    double? longitude,
    bool? isReserved,
    String? videoUrl,
    List<String>? additionalImages,
    String? descriptionDetaillee,
    
    String? statutAnnonce,
    double? superficie,
    String? ville,
    String? codePostal,
    int? prixVente,
    bool? chargesComprises,
    int? montantCharges,
    int? depotGarantie,
    int? fraisAgence,
    int? nbChambres,
    int? nbSalons,
    int? nbSallesDeBain,
    int? nbToilettes,
    String? typeCuisine,
    int? etage,
    bool? hasAscenseur,
    bool? hasParking,
    int? parkingPlaces,
    bool? hasJardin,
    bool? hasBalcon,
    List<String>? equipements,
    String? planUrl,
    bool? animauxAcceptes,
    bool? fumeursAcceptes,
    int? dureeMinLocation,
    int? preavis,
    DateTime? disponibilite,
    String? propertyVideoUrl,
  }) {
    return Property(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      lieu: lieu ?? this.lieu,
      prix: prix ?? this.prix,
      pieces: pieces ?? this.pieces,
      type: type ?? this.type,
      proprietaireId: proprietaireId ?? this.proprietaireId,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      views: views ?? this.views,
      reports: reports ?? this.reports,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      highlightedUntil: highlightedUntil ?? this.highlightedUntil,
      createdAt: createdAt ?? this.createdAt,
      rating: rating ?? this.rating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isReserved: isReserved ?? this.isReserved,
      videoUrl: videoUrl ?? this.videoUrl,
      additionalImages: additionalImages ?? this.additionalImages,
      descriptionDetaillee: descriptionDetaillee ?? this.descriptionDetaillee,
      
      statutAnnonce: statutAnnonce ?? this.statutAnnonce,
      superficie: superficie ?? this.superficie,
      ville: ville ?? this.ville,
      codePostal: codePostal ?? this.codePostal,
      prixVente: prixVente ?? this.prixVente,
      chargesComprises: chargesComprises ?? this.chargesComprises,
      montantCharges: montantCharges ?? this.montantCharges,
      depotGarantie: depotGarantie ?? this.depotGarantie,
      fraisAgence: fraisAgence ?? this.fraisAgence,
      nbChambres: nbChambres ?? this.nbChambres,
      nbSalons: nbSalons ?? this.nbSalons,
      nbSallesDeBain: nbSallesDeBain ?? this.nbSallesDeBain,
      nbToilettes: nbToilettes ?? this.nbToilettes,
      typeCuisine: typeCuisine ?? this.typeCuisine,
      etage: etage ?? this.etage,
      hasAscenseur: hasAscenseur ?? this.hasAscenseur,
      hasParking: hasParking ?? this.hasParking,
      parkingPlaces: parkingPlaces ?? this.parkingPlaces,
      hasJardin: hasJardin ?? this.hasJardin,
      hasBalcon: hasBalcon ?? this.hasBalcon,
      equipements: equipements ?? this.equipements,
      planUrl: planUrl ?? this.planUrl,
      animauxAcceptes: animauxAcceptes ?? this.animauxAcceptes,
      fumeursAcceptes: fumeursAcceptes ?? this.fumeursAcceptes,
      dureeMinLocation: dureeMinLocation ?? this.dureeMinLocation,
      preavis: preavis ?? this.preavis,
      disponibilite: disponibilite ?? this.disponibilite,
    );
  }

  /// Convertit une réponse JSON de l'API Symfony (champs anglais) en Property
  factory Property.fromApiMap(Map<String, dynamic> api) {
    List<String> toList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) {
        try { final p = jsonDecode(v); if (p is List) return p.map((e) => e.toString()).toList(); } catch (_) {}
      }
      return [];
    }
    bool toBool(dynamic v) => v == true || v == 1 || v == '1';
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    // L'API Symfony retourne : title, address, city, pricePerMonth, bedrooms, surface, type, statut...
    final proprietaire = api['proprietaire'] as Map<String, dynamic>?;
    return Property(
      id:               (api['id'] as num?)?.toInt() ?? 0,
      titre:            api['title'] as String? ?? api['titre'] as String? ?? '',
      lieu:             api['address'] as String? ?? api['lieu'] as String? ?? '',
      ville:            api['city'] as String? ?? api['ville'] as String? ?? '',
      prix:             toInt(api['pricePerMonth']) ?? toInt(api['prix']) ?? 0,
      pieces:           (api['rooms'] as num?)?.toInt() ?? (api['pieces'] as num?)?.toInt() ?? 0,
      type:             api['type'] as String? ?? 'Appartement',
      status:           api['statut'] as String? ?? api['status'] as String? ?? 'active',
      verified:         toBool(api['verified'] ?? api['isVerified']),
      views:            (api['views'] as num?)?.toInt() ?? 0,
      reports:          0,
      isHighlighted:    toBool(api['isHighlighted']),
      highlightedUntil: null,
      createdAt:        api['createdAt'] != null ? DateTime.tryParse(api['createdAt'].toString()) : null,
      rating:           (api['rating'] as num?)?.toDouble() ?? 0.0,
      latitude:         null,
      longitude:        null,
      imageUrl:         toList(api['images']).isNotEmpty
                          ? toList(api['images']).first
                          : (api['imageUrl'] as String?),
      additionalImages: toList(api['images']).length > 1 ? toList(api['images']).sublist(1) : [],
      description:      api['description'] as String? ?? '',
      likes:            (api['likesCount'] as num?)?.toInt() ?? 0,
      dislikes:         (api['dislikesCount'] as num?)?.toInt() ?? 0,
      commentsCount:    (api['commentsCount'] as num?)?.toInt() ?? 0,
      isReserved:       toBool(api['isReserved']),
      videoUrl:         api['videoUrl'] as String?,
      descriptionDetaillee: null,
      propertyVideoUrl: null,
      proprietaireId:   (proprietaire?['id'] as num?)?.toInt() ?? (api['proprietaireId'] as num?)?.toInt() ?? 0,
      statutAnnonce:    api['statutAnnonce'] as String? ?? 'À louer',
      superficie:       (api['surface'] as num?)?.toDouble() ?? 0.0,
      codePostal:       null,
      prixVente:        null,
      chargesComprises: toBool(api['chargesComprises']),
      montantCharges:   null,
      depotGarantie:    null,
      fraisAgence:      null,
      nbChambres:       (api['bedrooms'] as num?)?.toInt() ?? 0,
      nbSalons:         0,
      nbSallesDeBain:   0,
      nbToilettes:      0,
      typeCuisine:      'Standard',
      etage:            null,
      hasAscenseur:     false,
      hasParking:       toBool(api['hasParking']),
      parkingPlaces:    0,
      hasJardin:        false,
      hasBalcon:        false,
      equipements:      [],
      planUrl:          null,
      animauxAcceptes:  false,
      fumeursAcceptes:  false,
      dureeMinLocation: null,
      preavis:          null,
      disponibilite:    null,
    );
  }
}