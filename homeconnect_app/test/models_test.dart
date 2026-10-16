import 'package:flutter_test/flutter_test.dart';
import 'package:homeconnect/models/locataire_models.dart';

void main() {
  group('CommunityPost', () {
    final sampleJson = {
      'id': 1,
      'user_id': 42,
      'user_name': 'Jean Dupont',
      'user_avatar': '',
      'contenu': 'Super appartement trouvé !',
      'created_at': '2025-01-15T10:00:00.000',
      'likes': 5,
      'comments_count': 2,
      'liked': false,
      'comments': [],
    };

    test('fromJson crée correctement un post', () {
      final post = CommunityPost.fromJson(sampleJson);
      expect(post.id, 1);
      expect(post.userId, 42);
      expect(post.userName, 'Jean Dupont');
      expect(post.contenu, 'Super appartement trouvé !');
      expect(post.likes, 5);
      expect(post.commentsCount, 2);
      expect(post.liked, false);
      expect(post.comments, isEmpty);
    });

    test('toJson produit les bonnes clés', () {
      final post = CommunityPost.fromJson(sampleJson);
      final json = post.toJson();
      expect(json['id'], 1);
      expect(json['user_id'], 42);
      expect(json['user_name'], 'Jean Dupont');
      expect(json['likes'], 5);
    });

    test('fromJson → toJson est idempotent', () {
      final post = CommunityPost.fromJson(sampleJson);
      final json = post.toJson();
      final post2 = CommunityPost.fromJson(json);
      expect(post2.id, post.id);
      expect(post2.contenu, post.contenu);
      expect(post2.likes, post.likes);
    });

    test('likes par défaut à 0 si absent', () {
      final json = Map<String, dynamic>.from(sampleJson)..remove('likes');
      final post = CommunityPost.fromJson(json);
      expect(post.likes, 0);
    });

    test('comments null traité comme liste vide', () {
      final json = Map<String, dynamic>.from(sampleJson)..['comments'] = null;
      final post = CommunityPost.fromJson(json);
      expect(post.comments, isEmpty);
    });
  });

  group('CommentItem', () {
    final sampleJson = {
      'id': 10,
      'user_id': 7,
      'user_name': 'Marie',
      'contenu': 'Bonne adresse !',
      'created_at': '2025-01-16T08:30:00.000',
    };

    test('fromJson crée correctement un commentaire', () {
      final comment = CommentItem.fromJson(sampleJson);
      expect(comment.id, 10);
      expect(comment.userId, 7);
      expect(comment.userName, 'Marie');
      expect(comment.contenu, 'Bonne adresse !');
    });

    test('toJson contient toutes les clés', () {
      final comment = CommentItem.fromJson(sampleJson);
      final json = comment.toJson();
      expect(json.containsKey('id'), true);
      expect(json.containsKey('user_id'), true);
      expect(json.containsKey('user_name'), true);
      expect(json.containsKey('contenu'), true);
      expect(json.containsKey('created_at'), true);
    });
  });

  group('SearchFilter', () {
    test('constructeur const par défaut', () {
      const filter = SearchFilter();
      expect(filter.ville, isNull);
      expect(filter.typeBien, isNull);
      expect(filter.prixMin, isNull);
      expect(filter.prixMax, isNull);
    });
  });
}
