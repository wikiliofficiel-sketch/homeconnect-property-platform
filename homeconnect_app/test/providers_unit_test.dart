import 'package:flutter_test/flutter_test.dart';
import 'package:homeconnect/providers/locataire_provider.dart';
import 'package:homeconnect/models/locataire_models.dart';

void main() {
  // ─── SearchProvider ────────────────────────────────────────────────────────

  group('SearchProvider', () {
    test('état initial : résultats vides, pas de chargement', () {
      final provider = SearchProvider();
      expect(provider.searchResults, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, '');
    });

    test('listes de référence non vides', () {
      final provider = SearchProvider();
      expect(provider.villes, isNotEmpty);
      expect(provider.typesBien, isNotEmpty);
    });

    test('villes contient Cotonou', () {
      final provider = SearchProvider();
      expect(provider.villes, contains('Cotonou'));
    });

    test('resetFilters vide les résultats', () {
      final provider = SearchProvider();
      provider.resetFilters();
      expect(provider.searchResults, isEmpty);
    });
  });

  // ─── CommunityProvider ─────────────────────────────────────────────────────

  group('CommunityProvider', () {
    test('état initial : posts vides, pas de chargement', () {
      final provider = CommunityProvider();
      expect(provider.posts, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, '');
      expect(provider.successMessage, '');
    });

    test('toggleLike sur post inexistant ne crashe pas', () async {
      final provider = CommunityProvider();
      await expectLater(provider.toggleLike(9999), completes);
    });

    test('addComment sur post inexistant ne crashe pas', () async {
      final provider = CommunityProvider();
      await expectLater(
        provider.addComment(
          postId: 9999,
          userId: 1,
          userName: 'Test',
          contenu: 'Commentaire test',
        ),
        completes,
      );
    });

    test('toggleLike change le compteur likes sur un post existant', () async {
      final provider = CommunityProvider();
      // Injecter un post directement via le mécanisme interne
      // (simulation sans base de données)
      final post = CommunityPost(
        id: 1,
        userId: 1,
        userName: 'Alice',
        userAvatar: '',
        contenu: 'Test post',
        dateCreation: DateTime.now(),
        likes: 3,
        commentsCount: 0,
        liked: false,
        comments: [],
      );
      provider.posts.add(post);
      await provider.toggleLike(1);
      expect(provider.posts.first.likes, 4);
      expect(provider.posts.first.liked, true);
    });

    test('toggleLike retire un like si déjà liké', () async {
      final provider = CommunityProvider();
      final post = CommunityPost(
        id: 2,
        userId: 1,
        userName: 'Bob',
        userAvatar: '',
        contenu: 'Test',
        dateCreation: DateTime.now(),
        likes: 5,
        commentsCount: 0,
        liked: true,
        comments: [],
      );
      provider.posts.add(post);
      await provider.toggleLike(2);
      expect(provider.posts.first.likes, 4);
      expect(provider.posts.first.liked, false);
    });
  });

  // ─── TenantReportProvider ──────────────────────────────────────────────────

  group('TenantReportProvider', () {
    test('état initial : liste vide, pas de chargement', () {
      final provider = TenantReportProvider();
      expect(provider.reports, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, '');
      expect(provider.successMessage, '');
    });
  });
}
