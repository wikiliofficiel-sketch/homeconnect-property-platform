// ============================================================
// MODÈLES COMPLÉMENTAIRES POUR LOCATAIRE
// ============================================================

class CommunityPost {
  final int id;
  final int userId;
  final String userName;
  final String userAvatar;
  final String contenu;
  final DateTime dateCreation;
  final int likes;
  final int commentsCount;
  final bool liked;
  final List<CommentItem> comments;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.contenu,
    required this.dateCreation,
    required this.likes,
    required this.commentsCount,
    required this.liked,
    required this.comments,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id'],
    userId: json['user_id'],
    userName: json['user_name'],
    userAvatar: json['user_avatar'],
    contenu: json['contenu'],
    dateCreation: DateTime.parse(json['created_at']),
    likes: json['likes'] ?? 0,
    commentsCount: json['comments_count'] ?? 0,
    liked: json['liked'] ?? false,
    comments: (json['comments'] as List?)
        ?.map((c) => CommentItem.fromJson(c))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'user_avatar': userAvatar,
    'contenu': contenu,
    'created_at': dateCreation.toIso8601String(),
    'likes': likes,
    'comments_count': commentsCount,
    'liked': liked,
    'comments': comments.map((c) => c.toJson()).toList(),
  };
}

class CommentItem {
  final int id;
  final int userId;
  final String userName;
  final String contenu;
  final DateTime dateCreation;

  const CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.contenu,
    required this.dateCreation,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
    id: json['id'],
    userId: json['user_id'],
    userName: json['user_name'],
    contenu: json['contenu'],
    dateCreation: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'contenu': contenu,
    'created_at': dateCreation.toIso8601String(),
  };
}

// Report class moved to report_sanction_models.dart

class HelpCategory {
  final int id;
  final String titre;
  final String description;
  final String? icon; // Nom de l'icône Material ou emoji
  final List<FAQItem> items;

  const HelpCategory({
    required this.id,
    required this.titre,
    required this.description,
    this.icon,
    required this.items,
  });
}

class Tutorial {
  final int id;
  final String titre;
  final String categorie;
  final List<TutorialStep> steps;

  const Tutorial({
    required this.id,
    required this.titre,
    required this.categorie,
    required this.steps,
  });
}

class TutorialStep {
  final String action;
  final String description;

  const TutorialStep({
    required this.action,
    required this.description,
  });
}

class FAQItem {
  final int id;
  final String question;
  final String reponse;

  const FAQItem({
    required this.id,
    required this.question,
    required this.reponse,
  });
}

class SearchFilter {
  final String? ville;
  final String? typeBien;
  final int? prixMin;
  final int? prixMax;
  final int? piecesMin;
  final int? piecesMax;
  final bool verifiedOnly;
  final bool photosOnly;

  const SearchFilter({
    this.ville,
    this.typeBien,
    this.prixMin,
    this.prixMax,
    this.piecesMin,
    this.piecesMax,
    this.verifiedOnly = false,
    this.photosOnly = false,
  });

  Map<String, dynamic> toJson() => {
    'ville': ville,
    'type_bien': typeBien,
    'prix_min': prixMin,
    'prix_max': prixMax,
    'pieces_min': piecesMin,
    'pieces_max': piecesMax,
    'verified_only': verifiedOnly,
    'photos_only': photosOnly,
  };
}
