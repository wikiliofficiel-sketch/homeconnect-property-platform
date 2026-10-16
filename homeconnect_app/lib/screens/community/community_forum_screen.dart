import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locataire_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_colors.dart';

/// Écran Forum Communautaire avec fil de posts
class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({super.key});

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  final _postController = TextEditingController();
  final _commentControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    await context.read<CommunityProvider>().loadPosts();
  }

  @override
  void dispose() {
    _postController.dispose();
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: AppColors.accentOrange,
        child: Consumer<CommunityProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.posts.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentOrange),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildNewPostCard(),
                const SizedBox(height: 20),
                if (provider.posts.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun post pour le moment',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Soyez le premier à partager !',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...provider.posts.map((post) => _buildPostCard(post, provider)),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Forum Communautaire'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryMedium],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildNewPostCard() {
    final user = context.read<AppProvider>().user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Utilisateur',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Maintenant',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postController,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Partagez vos expériences, conseils, questions...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: InputBorder.none,
              counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _postController.text.isEmpty
                    ? null
                    : () => _submitPost(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  disabledBackgroundColor:
                      AppColors.accentOrange.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Publier'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post, CommunityProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du post
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Text(
                    post.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDate(post.dateCreation),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Contenu du post
          Text(
            post.contenu,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Actions (likes, commentaires)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => provider.toggleLike(post.id),
                  child: Row(
                    children: [
                      Icon(
                        post.liked ? Icons.favorite : Icons.favorite_outline,
                        size: 16,
                        color: post.liked ? Colors.red : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likes}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.commentsCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Partager',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12),

          // Section commentaires
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...post.comments
                .take(2)
                .map((comment) => _buildCommentItem(comment))
                .toList(),
            if (post.comments.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Voir les ${post.comments.length - 2} autres commentaires',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          // Formulaire ajout commentaire
          _buildAddCommentForm(post, provider),
        ],
      ),
    );
  }

  Widget _buildCommentItem(dynamic comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentBlue.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Text(
                    comment.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      comment.contenu,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddCommentForm(dynamic post, CommunityProvider provider) {
    if (!_commentControllers.containsKey(post.id)) {
      _commentControllers[post.id] = TextEditingController();
    }

    final controller = _commentControllers[post.id]!;
    final user = context.read<AppProvider>().user;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Ajouter un commentaire...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: controller.text.isEmpty
              ? null
              : () => _submitComment(post, provider, user, controller),
          child: Icon(
            Icons.send,
            size: 18,
            color: controller.text.isEmpty
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.accentOrange,
          ),
        ),
      ],
    );
  }

  Future<void> _submitPost() async {
    final user = context.read<AppProvider>().user;
    if (user == null || _postController.text.isEmpty) return;

    await context.read<CommunityProvider>().addPost(
          userId: user.id,
          userName: user.displayName,
          userAvatar: '',
          contenu: _postController.text,
        );

    _postController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post publié avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitComment(
    dynamic post,
    CommunityProvider provider,
    dynamic user,
    TextEditingController controller,
  ) async {
    if (user == null || controller.text.isEmpty) return;

    await provider.addComment(
      postId: post.id,
      userId: user.id,
      userName: user.displayName,
      contenu: controller.text,
    );

    controller.clear();
    setState(() {});
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
