// lib/screens/locataire/locataire_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/app_provider.dart';
import '../../utils/app_colors.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../utils/external_launcher.dart';
import '../../services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user.dart';
import '../../models/property.dart';
import '../tenant/chat_screen.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/design_widgets.dart';
import '../../providers/notification_provider.dart';
import '../../providers/report_provider.dart';
import '../../models/report_sanction_models.dart';
import '../../providers/advanced_chat_provider.dart';
import '../../models/chat_message.dart';


class LocataireDashboardScreen extends StatefulWidget {
  const LocataireDashboardScreen({super.key});

  @override
  State<LocataireDashboardScreen> createState() => _LocataireDashboardScreenState();
}

class _LocataireDashboardScreenState extends State<LocataireDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Property> _biens = [];
  List<Property> _favoris = [];
  List<Map<String, dynamic>> _candidatures = [];
  List<Map<String, dynamic>> _communityPosts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _loadData();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final user = context.read<AppProvider>().user;

    // Biens depuis l'API (même BDD que le web)
    try {
      final raw = await ApiService.getProperties();
      _biens = raw
          .map((p) => Property.fromApiMap(Map<String, dynamic>.from(p)))
          .toList();
    } catch (_) {
      _biens = await db.getProperties();
    }

    if (user != null) {
      try { _favoris = await db.getFavorites(user.id); } catch (_) {}
      try { _candidatures = await db.getApplicationsForLocataire(user.id); } catch (_) {}
      if (mounted) {
        try { await context.read<NotificationProvider>().loadNotifications(user.id); } catch (_) {}
      }
    }
    try { _communityPosts = await db.getCommunityPosts(); } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return RoleGuard(
      allowedRoles: const ['locataire'],
      customErrorMessage: 'Seuls les locataires peuvent accéder au dashboard locataire',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    PremiumHeaderWidget(
                      title: appProvider.translate('tenant_space'),
                      subtitle: appProvider.translate('find_future_home'),
                      notificationCount: context.watch<NotificationProvider>().unreadCount,
                      onNotificationTap: () => _showNotificationsDialog(context.read<NotificationProvider>()),
                      onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                      onLogoutTap: () => _showLogoutConfirmation(context),
                      onChatTap: () => _tabController.animateTo(8), // Redirection Chat Admin
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _HomeTab(biens: _biens, favoris: _favoris, candidatures: _candidatures, user: appProvider.user, onRefresh: _loadData, onTabChange: (i) => _tabController.animateTo(i)),
                          _SearchTab(biens: _biens, searchController: _searchController, onRefresh: _loadData),
                          _ApplicationsTab(candidatures: _candidatures, onRefresh: _loadData),
                          _VisitesTab(candidatures: _candidatures, onRefresh: _loadData),
                          _PaymentsTab(user: appProvider.user),
                          _FavoritesTab(favoris: _favoris, onRefresh: _loadData),
                          _ReviewsTab(user: appProvider.user),
                          _CommunityTab(posts: _communityPosts, onRefresh: _loadData, currentUser: appProvider.user),
                          _ChatAdminTab(user: appProvider.user),
                          _ServicesTab(user: appProvider.user),
                          const _HelpTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        // Suppression du bouton support à la demande de l'utilisateur
        // floatingActionButton: FloatingActionButton(...)
        bottomNavigationBar: _buildPremiumTabBar(appProvider),
      ),
    );
  }

  Future<void> _showNotificationsDialog(NotificationProvider notifProvider) async {
    final user = context.read<AppProvider>().user;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(color: AppColors.getScaffoldBackground(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            Container(width: 60, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(20), child: Text('Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))),
            Expanded(
              child: notifProvider.notifications.isEmpty
                ? Center(child: Text(context.read<AppProvider>().translate('no_notifications'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))))
                : ListView.builder(
                    itemCount: notifProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifProvider.notifications[index];
                      return ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_active, color: AppColors.accentBlue)),
                        title: Text(n['title'] ?? 'Notification', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                        subtitle: Text(n['body'] ?? '', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                        trailing: Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(n['createdAt'] ?? DateTime.now().toIso8601String())), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 10)),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) {
      if (user != null) notifProvider.markAllAsRead(user.id);
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(appProvider.translate('logout_confirmation'), style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text(appProvider.translate('logout_confirmation_desc'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(appProvider.translate('cancel'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)))),
          ElevatedButton(
            onPressed: () async {
              await appProvider.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: Text(appProvider.translate('logout'), style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );
  }



  Widget _buildPremiumTabBar(AppProvider appProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.cardDark : Colors.white,
      child: SafeArea(
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black45,
          indicatorColor: AppColors.accentOrange,
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (_) {},
          tabs: [
            Tab(icon: const Icon(Icons.home_outlined, size: 24), text: appProvider.translate('overview')),
            Tab(icon: const Icon(Icons.search_outlined, size: 24), text: appProvider.translate('search')),
            Tab(icon: const Icon(Icons.assignment_outlined, size: 24), text: appProvider.translate('applications')),
            Tab(icon: const Icon(Icons.calendar_month_outlined, size: 24), text: appProvider.translate('visits')),
            Tab(icon: const Icon(Icons.payment_outlined, size: 24), text: appProvider.translate('payments')),
            Tab(icon: const Icon(Icons.favorite_outline, size: 24), text: appProvider.translate('favorites')),
            Tab(icon: const Icon(Icons.star_outline), text: appProvider.translate('reviews')),
            Tab(icon: const Icon(Icons.people_outline), text: appProvider.translate('community')),
            const Tab(icon: Icon(Icons.chat_outlined), text: 'Chat Admin'),
            Tab(icon: const Icon(Icons.room_service_outlined), text: appProvider.translate('services')),
            Tab(icon: const Icon(Icons.help_outline), text: appProvider.translate('help')),
          ],
        ),
      ),
    );
  }
}

// ========== VISITES TAB ==========
class _VisitesTab extends StatelessWidget {
  final List<Map<String, dynamic>> candidatures;
  final VoidCallback onRefresh;
  const _VisitesTab({required this.candidatures, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final visites = candidatures.where((c) => c['visiteDate'] != null).toList();
    
    if (visites.isEmpty) {
      return Center(child: Text('Aucune visite planifiée', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))));
    }
    
    // Trier par date
    visites.sort((a, b) => DateTime.parse(a['visiteDate']).compareTo(DateTime.parse(b['visiteDate'])));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: visites.length,
      itemBuilder: (context, index) {
        final c = visites[index];
        final visiteDate = DateTime.parse(c['visiteDate']);
        final isPast = visiteDate.isBefore(DateTime.now());
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isPast ? Colors.grey.withValues(alpha: 0.3) : AppColors.accentGreen.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(c['bien'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast ? Colors.grey.withValues(alpha: 0.2) : AppColors.accentGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPast ? 'Passée' : 'À venir',
                    style: TextStyle(color: isPast ? Colors.grey : AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(c['lieu'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.calendar_month, size: 20, color: AppColors.accentBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE d MMMM yyyy', context.read<AppProvider>().locale.languageCode == 'en' ? 'en_US' : 'fr_FR').format(visiteDate).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('À ${DateFormat('HH:mm').format(visiteDate)}', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Bouton Chat Admin
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(
                        receiverId: 1,
                        receiverName: 'Administration Immo Bénin',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accentOrange, size: 22),
                  tooltip: 'Contacter l\'administration',
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ========== ACCUEIL TAB ==========
class _HomeTab extends StatelessWidget {
  final List<Property> biens;
  final List<Property> favoris;
  final List<Map<String, dynamic>> candidatures;
  final User? user;
  final VoidCallback onRefresh;
  final Function(int) onTabChange;
  const _HomeTab({required this.biens, required this.favoris, required this.candidatures, required this.user, required this.onRefresh, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(28)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.getTextColor(context), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.person, size: 36, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${context.read<AppProvider>().translate('hello')} ${user?.prenom ?? 'Locataire'}! 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
                          ),
                        ),
                        Text(
                          context.read<AppProvider>().translate('find_your_home'),
                          style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 12, color: AppColors.accentGreen),
                        const SizedBox(width: 4),
                        Text(
                          context.read<AppProvider>().translate('verified'),
                          style: TextStyle(color: AppColors.getTextColor(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 16),

            // 1. Statistiques Personnelles (Sur une seule ligne)
            Row(
              children: [
                Expanded(child: _buildStatCard(context, context.read<AppProvider>().translate('applications'), '${candidatures.length}', Icons.assignment_outlined, AppColors.accentBlue)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard(context, context.read<AppProvider>().translate('favorites'), '${favoris.length}', Icons.favorite_outline, AppColors.accentRed)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard(context, context.read<AppProvider>().translate('visits'), '${candidatures.where((c) => c['visiteDate'] != null).length}', Icons.calendar_today_outlined, AppColors.accentGreen)),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Actions Rapides
            Text('Accès Rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildQuickAction(context, 'Contrats', Icons.description_outlined, AppColors.accentBlue, () => onTabChange(2)),
                _buildQuickAction(context, 'Paiements', Icons.account_balance_wallet_outlined, AppColors.accentOrange, () => onTabChange(4)),
                _buildQuickAction(context, 'Mes Avis', Icons.star_outline, AppColors.accentPurple, () => onTabChange(6)),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Carrousel Recommandé (Point 2)
            if (biens.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.recommend_outlined, color: AppColors.accentOrange),
                          const SizedBox(width: 8),
                          Text(context.read<AppProvider>().translate('recommended_for_you'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                        ],
                      ),
                      InkWell(
                        onTap: () => onTabChange(1), // Onglet Recherche
                        child: Text(context.read<AppProvider>().translate('see_all'), style: const TextStyle(color: AppColors.accentOrange, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 380,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: biens.length,
                      itemBuilder: (_, index) => Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 12),
                        child: _buildPropertyCard(biens[index], context),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                    const SizedBox(height: 16),
                    Text(context.read<AppProvider>().translate('no_properties_found'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getTextColor(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property, BuildContext context) {
    final bool isReserved = property.isReserved;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Hero(
                    tag: 'property_${property.id}',
                    child: SafeImage(
                      url: property.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (isReserved)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.accentRed, borderRadius: BorderRadius.circular(20)),
                        child: Text('DÉJÀ RÉSERVÉ', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: Icon(
                    favoris.any((f) => f.id == property.id) ? Icons.favorite : Icons.favorite_border,
                    color: favoris.any((f) => f.id == property.id) ? AppColors.accentRed : Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _addToFavorites(context, property),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    if (property.additionalImages.isNotEmpty)
                      _buildMediaBadge(context, Icons.camera_alt, '${property.additionalImages.length + 1}'),
                    if ((property.videoUrl != null && property.videoUrl!.isNotEmpty) || (property.propertyVideoUrl != null && property.propertyVideoUrl!.isNotEmpty)) ...[
                      const SizedBox(width: 8),
                      _buildMediaBadge(context, Icons.play_circle_fill, 'Vidéo'),
                    ],
                  ],
                ),
              ),

            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(property.titre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${property.prix} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(children: [Icon(Icons.location_on, size: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), const SizedBox(width: 4), Expanded(child: Text(property.lieu, style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), overflow: TextOverflow.ellipsis))]),
                
                Padding(                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.getTextColor(context).withValues(alpha: 0.70), height: 1),
                ),
                
                // --- SOCIAL INTERACTIONS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildSocialButton(context, Icons.thumb_up_alt_outlined, '${property.likes}', () => _handleLike(context, property))),
                    Expanded(child: _buildSocialButton(context, Icons.thumb_down_alt_outlined, '${property.dislikes}', () => _handleDislike(context, property))),
                    Expanded(child: _buildSocialButton(context, Icons.chat_bubble_outline, '${property.commentsCount}', () => _showComments(context, property))),
                    Expanded(child: _buildSocialButton(context, Icons.flag_outlined, '${property.reports}', () => _handleReport(context, property))),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // --- ACTIONS ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/property/${property.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Voir plus', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isReserved ? null : () => _handleInteret(context, property),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReserved ? Colors.grey : AppColors.accentOrange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(isReserved ? 'Désactivé' : 'Je suis intéressé', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaBadge(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.getTextColor(context)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleLike(BuildContext context, Property p) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    await DatabaseHelper().toggleLike(p.id, user.id);
    onRefresh();
  }

  void _handleDislike(BuildContext context, Property p) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    await DatabaseHelper().toggleDislike(p.id, user.id);
    onRefresh();
  }


  void _showComments(BuildContext context, Property p) {
    final commentCtrl = TextEditingController();
    final user = context.read<AppProvider>().user;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getScaffoldBackground(context),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.70), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text('Commentaires (${p.commentsCount})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                    Divider(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: DatabaseHelper().getComments(p.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final comments = snapshot.data!;
                          if (comments.isEmpty) return Center(child: Text('Aucun commentaire', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))));
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              return _buildMockComment(
                                context,
                                c['userName'] ?? 'Anonyme',
                                c['text'] ?? '',
                                DateFormat('dd/MM HH:mm').format(DateTime.parse(c['createdAt'])),
                              );
                            },
                          );
                        }
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentCtrl,
                              style: TextStyle(color: AppColors.getTextColor(context)),
                              decoration: InputDecoration(
                                hintText: 'Ajouter un commentaire...',
                                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.accentOrange),
                            onPressed: () async {
                              if (commentCtrl.text.isEmpty || user == null) return;
                              await DatabaseHelper().addComment(p.id, user.id, user.displayName, commentCtrl.text);
                              commentCtrl.clear();
                              setModalState(() {}); // Refresh modal
                              onRefresh(); // Refresh dashboard counts
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildMockComment(BuildContext context, String name, String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accentBlue.withValues(alpha: 0.2),
            child: Text(name[0], style: const TextStyle(color: AppColors.accentBlue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                    Text(time, style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleReport(BuildContext context, Property p) {
    final messageCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Plainte à l\'administration', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous signaler un problème à l\'administration ?', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Raison de la plainte...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                filled: true,
                fillColor: Colors.white10,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = context.read<AppProvider>().user;
              if (user != null) {
                // Enregistrement réel du signalement
                await DatabaseHelper().addReport({
                  'propertyId': p.id,
                  'reporterId': user.id,
                  'reporterName': user.displayName,
                  'targetOwnerId': p.proprietaireId,
                  'message': messageCtrl.text,
                  'type': 'property_report',
                });
                
                if (!context.mounted) return;
                await context.read<NotificationProvider>().addNotification(
                  userId: p.proprietaireId,
                  title: 'Nouvelle Plainte',
                  body: 'Le locataire ${user.displayName} a soumis une plainte : ${messageCtrl.text}',
                  type: 'report',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé avec succès !')));
                onRefresh(); // Refresh counts
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }

  void _handleInteret(BuildContext context, Property property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmation', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text('Êtes-vous intéressé par "${property.titre}" ?', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Non', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Ouvrir le chat avec l'admin
              onTabChange(8); // Redirection vers le Chat Admin
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Oui, contacter l\'admin'),
          ),
        ],
      ),
    );
  }

  void _addToFavorites(BuildContext context, Property property) async {
    final user = context.read<AppProvider>().user;
    if (user != null) {
      final db = DatabaseHelper();
      final favorites = await db.getFavorites(user.id);
      final isFav = favorites.any((f) => f.id == property.id);

      if (isFav) {
        await db.removeFavorite(user.id, property.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré des favoris')));
      } else {
        await db.addFavorite(user.id, property.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté aux favoris'), backgroundColor: AppColors.accentRed));
      }
      
      // Re-charger les données pour être sûr de la cohérence avec le DB
      onRefresh();
    }
  }


}

// ========== RECHERCHE AVANCÉE ==========
class _SearchTab extends StatefulWidget {
  final List<Property> biens;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  const _SearchTab({required this.biens, required this.searchController, required this.onRefresh});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String? _selectedVille;
  String? _selectedType;
  RangeValues _priceRange = const RangeValues(0, 500000);
  RangeValues _piecesRange = const RangeValues(1, 5);
  bool _withPhotos = true;
  bool _verifiedOnly = false;

  List<Property> get _filteredBiens {
    return widget.biens.where((b) {
      if (_selectedVille != null && _selectedVille != 'Toutes' && !b.lieu.contains(_selectedVille!)) return false;
      if (_selectedType != null && _selectedType != 'Tous' && b.type != _selectedType) return false;
      if (b.prix < _priceRange.start || b.prix > _priceRange.end) return false;
      if (b.pieces < _piecesRange.start || b.pieces > _piecesRange.end) return false;
      if (_verifiedOnly && !b.verified) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: widget.searchController,
            style: TextStyle(color: AppColors.getTextColor(context)),
            decoration: InputDecoration(
              hintText: 'Rechercher par ville, quartier...',
              hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
              suffixIcon: IconButton(icon: Icon(Icons.tune, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => _showAdvancedFilters()),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('📍 ${_selectedVille ?? 'Toutes villes'}', () => _showVillePicker()),
                const SizedBox(width: 8),
                _buildFilterChip('🏠 ${_selectedType ?? 'Tous types'}', () => _showTypePicker()),
                const SizedBox(width: 8),
                _buildFilterChip('💰 ${(_priceRange.start / 1000).toStringAsFixed(0)}K - ${(_priceRange.end / 1000).toStringAsFixed(0)}K', () => _showPricePicker()),
                const SizedBox(width: 8),
                _buildFilterChip('🛏️ ${_piecesRange.start.toInt()}-${_piecesRange.end.toInt()} pièces', () => _showPiecesPicker()),
                if (_verifiedOnly) _buildFilterChip('✅ Vérifiés', () => setState(() => _verifiedOnly = false)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredBiens.length,
            itemBuilder: (context, index) => _buildResultCard(_filteredBiens[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.2))),
        child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
      ),
    );
  }

  Widget _buildResultCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getTextColor(context).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () {
          if (property.status != 'actif') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.getCardColor(context),
                title: Text('Accès restreint', style: TextStyle(color: AppColors.getTextColor(context))),
                content: Text('Ce bien n\'est plus accessible (désactivé par l\'administration).', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: AppColors.accentOrange))),
                ],
              ),
            );
            return;
          }
          Navigator.pushNamed(context, '/property/${property.id}');
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: property.imageUrl != null 
                    ? DecorationImage(image: getSafeImageProvider(property.imageUrl!), fit: BoxFit.cover)
                    : null,
                  color: AppColors.getTextColor(context).withValues(alpha: 0.70),
                ),
                child: Stack(
                  children: [
                    if (property.imageUrl == null) 
                      Center(child: Icon(Icons.home_work_outlined, color: AppColors.getTextColor(context).withValues(alpha: 0.70), size: 32)),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Row(
                        children: [
                          if (property.additionalImages.isNotEmpty)
                            Icon(Icons.photo_library, size: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                          if (property.videoUrl != null && property.videoUrl!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.play_circle_fill, size: 12, color: AppColors.accentOrange),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.lieu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${property.prix} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ModernButton(
                text: 'Postuler',
                onPressed: () => _apply(property),
                width: 90,
                height: 36,
                fontSize: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply(Property property) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    await DatabaseHelper().addApplication(user.id, property.id, '');
    if (!mounted) return;
    await context.read<NotificationProvider>().addNotification(
      userId: property.proprietaireId,
      title: 'Nouvelle candidature',
      body: '${user.displayName} a postulé pour ${property.titre}',
      type: 'candidature',
    );
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Candidature envoyée pour ${property.titre}')));
    }
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottom) => Container(
          decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(20), child: Text('Filtres avancés', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))),
              SwitchListTile(title: Text('Avec photos uniquement', style: TextStyle(color: AppColors.getTextColor(context))), value: _withPhotos, onChanged: (v) => setStateBottom(() => _withPhotos = v), activeThumbColor: AppColors.accentOrange),
              SwitchListTile(title: Text('Biens vérifiés uniquement', style: TextStyle(color: AppColors.getTextColor(context))), value: _verifiedOnly, onChanged: (v) => setStateBottom(() => _verifiedOnly = v), activeThumbColor: AppColors.accentOrange),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedVille = null;
                            _selectedType = null;
                            _priceRange = const RangeValues(0, 500000);
                            _piecesRange = const RangeValues(1, 5);
                            _withPhotos = true;
                            _verifiedOnly = false;
                          });
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.3)), foregroundColor: Colors.white),
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVillePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Ville', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Toutes', 'Cotonou', 'Porto-Novo', 'Parakou', 'Abomey', 'Natitingou'].map((v) => ListTile(title: Text(v, style: TextStyle(color: v == _selectedVille ? AppColors.accentOrange : AppColors.getTextColor(context).withValues(alpha: 0.7))), onTap: () { setState(() => _selectedVille = v == 'Toutes' ? null : v); Navigator.pop(context); })).toList(),
        ),
      ),
    );
  }

  void _showTypePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Type', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Tous', 'Appartement', 'Maison', 'Studio', 'Villa', 'Terrain', 'Bureau'].map((t) => ListTile(title: Text(t, style: TextStyle(color: t == _selectedType ? AppColors.accentOrange : AppColors.getTextColor(context).withValues(alpha: 0.7))), onTap: () { setState(() => _selectedType = t == 'Tous' ? null : t); Navigator.pop(context); })).toList(),
        ),
      ),
    );
  }

  void _showPricePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Budget', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RangeSlider(values: _priceRange, min: 0, max: 1000000, divisions: 20, onChanged: (v) => setState(() => _priceRange = v), activeColor: AppColors.accentOrange),
            Text('${(_priceRange.start / 1000).toStringAsFixed(0)}K - ${(_priceRange.end / 1000).toStringAsFixed(0)}K FCFA', style: TextStyle(color: AppColors.getTextColor(context))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  void _showPiecesPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Nombre de pièces', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RangeSlider(values: _piecesRange, min: 1, max: 10, divisions: 9, onChanged: (v) => setState(() => _piecesRange = v), activeColor: AppColors.accentOrange),
            Text('${_piecesRange.start.toInt()} - ${_piecesRange.end.toInt()} pièces', style: TextStyle(color: AppColors.getTextColor(context))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      ),
    );
  }
}

// ========== CANDIDATURES AVEC GESTION DES VISITES ==========
class _ApplicationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> candidatures;
  final VoidCallback onRefresh;
  const _ApplicationsTab({required this.candidatures, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (candidatures.isEmpty) {
      return Center(child: Text('Aucune candidature', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: candidatures.length,
      itemBuilder: (context, index) {
        final c = candidatures[index];
        final statut = c['statut'];
        final visiteDate = c['visiteDate'] != null ? DateTime.parse(c['visiteDate']) : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statut == 'acceptee' ? AppColors.accentGreen.withValues(alpha: 0.3) : (statut == 'refusee' ? AppColors.accentRed.withValues(alpha: 0.3) : AppColors.accentOrange.withValues(alpha: 0.3))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(c['bien'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statut == 'acceptee' ? AppColors.accentGreen.withValues(alpha: 0.2) : (statut == 'refusee' ? AppColors.accentRed.withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statut == 'acceptee' ? 'Acceptée' : (statut == 'refusee' ? 'Rejetée' : 'En attente'),
                    style: TextStyle(color: statut == 'acceptee' ? AppColors.accentGreen : (statut == 'refusee' ? AppColors.accentRed : AppColors.accentOrange)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(c['lieu'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
              Text('${c['prix']} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
              if (visiteDate != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_month, size: 14, color: AppColors.accentBlue),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Visite le ${DateFormat('dd/MM/yyyy à HH:mm').format(visiteDate)}', style: const TextStyle(color: AppColors.accentBlue))),
                ]),
              ],
              if (statut == 'acceptee' && visiteDate == null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _planifierVisite(context, c['id']),
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Planifier une visite'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
                ),
              ],
              const SizedBox(height: 12),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(
                        receiverId: 1, // Redirection Admin
                        receiverName: 'Administration Immo Bénin',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_outlined, color: AppColors.accentBlue),
                tooltip: 'Contacter le propriétaire',
              ),
            ],
          ),
        );
      },
    );
  }

  void _planifierVisite(BuildContext context, int appId) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Planifier une visite', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Date', style: TextStyle(color: AppColors.getTextColor(context))),
              trailing: Text(selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate!) : 'Choisir', style: const TextStyle(color: AppColors.accentOrange)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) {
                  selectedDate = date;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text('Heure', style: TextStyle(color: AppColors.getTextColor(context))),
              trailing: Text(selectedTime != null ? selectedTime!.format(context) : 'Choisir', style: const TextStyle(color: AppColors.accentOrange)),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (time != null) {
                  selectedTime = time;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () async {
              if (selectedDate != null && selectedTime != null) {
                final datetime = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                await DatabaseHelper().updateApplicationStatus(appId, 'acceptee', visiteDate: datetime, visiteHeure: '${selectedTime!.hour}:${selectedTime!.minute}');
                if (!context.mounted) return;
                onRefresh();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visite planifiée')));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

// ========== FAVORIS ==========
class _FavoritesTab extends StatelessWidget {
  final List<Property> favoris;
  final VoidCallback onRefresh;
  const _FavoritesTab({required this.favoris, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (favoris.isEmpty) {
      return Center(child: Text('Aucun favori', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: favoris.length,
      itemBuilder: (context, index) {
        final p = favoris[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.titre, style: TextStyle(color: AppColors.getTextColor(context))),
                    Text(p.lieu, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                    Text('${p.prix} FCFA', style: const TextStyle(color: AppColors.accentOrange)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('Détails', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.pushNamed(context, '/property/${p.id}'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: AppColors.accentRed),
                    iconSize: 20,
                    onPressed: () async {
                      final user = context.read<AppProvider>().user;
                      if (user != null) {
                        await DatabaseHelper().removeFavorite(user.id, p.id);
                        if (!context.mounted) return;
                        onRefresh();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré des favoris')));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== ÉVALUATIONS ==========
class _ReviewsTab extends StatefulWidget {
  final User? user;
  const _ReviewsTab({required this.user});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  int _viewIndex = 0; // 0: Reçues, 1: Données

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 64, color: AppColors.accentOrange),
          const SizedBox(height: 12),
          Text('Note moyenne : ${widget.user?.rating?.toStringAsFixed(1) ?? '4.8'} / 5', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
          Text('Basé sur ${widget.user?.reviewCount ?? 15} évaluations reçues', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
          const SizedBox(height: 24),
          
          // Sélecteur Reçues/Données
          Row(
            children: [
              Expanded(child: _buildToggleBtn('Reçues', _viewIndex == 0, () => setState(() => _viewIndex = 0))),
              const SizedBox(width: 12),
              Expanded(child: _buildToggleBtn('Données', _viewIndex == 1, () => setState(() => _viewIndex = 1))),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_viewIndex == 0) ...[
            _buildReviewItem('Propriétaire - Villa Cotonou', 5, 'Locataire très sérieux et ponctuel dans les paiements.', 'Il y a 2 jours'),
            _buildReviewItem('Agence Immo Bénin', 4, 'Bonne communication, appartement rendu propre.', '15/03/2026'),
          ] else ...[
            _buildGivenReview('M. Amoussou', 5, 'Appartement conforme aux photos, très réactif.', 'Studio Porto-Novo'),
          ],
          
          const SizedBox(height: 32),
          ModernButton(
            text: 'Évaluer un propriétaire',
            icon: Icons.rate_review_rounded,
            onPressed: () => _showRatingForm(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.accentOrange : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(child: Text(label, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: active ? FontWeight.bold : FontWeight.normal))),
      ),
    );
  }

  Widget _buildReviewItem(String author, int stars, String comment, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(author, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)), overflow: TextOverflow.ellipsis)),
              Row(children: List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < stars ? AppColors.accentOrange : Colors.white24))),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 11)),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.report_outlined, size: 14, color: AppColors.accentRed), label: const Text('Signaler', style: TextStyle(color: AppColors.accentRed, fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGivenReview(String owner, int stars, String comment, String property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(owner, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
          Text(property, style: const TextStyle(color: AppColors.accentOrange, fontSize: 11)),
          const SizedBox(height: 8),
          Text(comment, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
        ],
      ),
    );
  }

  void _showRatingForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Évaluer le Propriétaire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: const Icon(Icons.star_border, size: 36, color: AppColors.accentOrange), onPressed: () {}))),
            const SizedBox(height: 16),
            TextField(maxLines: 3, decoration: InputDecoration(hintText: 'Votre commentaire...', filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 24),
            ModernButton(text: 'Publier l\'évaluation', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// ========== ESPACE COMMUNAUTAIRE ==========
class _CommunityTab extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final VoidCallback onRefresh;
  final User? currentUser;
  const _CommunityTab({required this.posts, required this.onRefresh, required this.currentUser});

  @override
  State<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<_CommunityTab> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPostInput()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
          final post = widget.posts[index];
          final List comments = post['comments'] as List? ?? [];

          return Card(
            color: AppColors.getTextColor(context).withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.accentOrange,
                        child: Icon(Icons.person, color: AppColors.getTextColor(context)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post['authorName'] ?? 'Utilisateur', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                            Text(DateFormat('dd MMM à HH:mm').format(DateTime.parse(post['date'])), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.report_outlined, color: AppColors.getTextColor(context).withValues(alpha: 0.70), size: 20),
                        onPressed: () => _showReportDialog(context, post['id'], 'post'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(post['content'], style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.comment_outlined, color: AppColors.accentOrange, size: 18),
                      const SizedBox(width: 6),
                      Text('${comments.length} commentaires', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showComments(context, post),
                        child: const Text('Voir / Commenter', style: TextStyle(color: AppColors.accentOrange, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        childCount: widget.posts.length,
      ),
    ),
  ),
],
      ),
    );
  }

  Widget _buildPostInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(bottom: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accentOrange,
            radius: 18,
            child: Icon(Icons.person, color: AppColors.getTextColor(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _postController,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Partagez une information...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              if (_postController.text.trim().isEmpty) return;
              final db = DatabaseHelper();
              await db.addCommunityPost({
                'authorId': widget.currentUser?.id ?? 0,
                'authorName': widget.currentUser?.prenom ?? 'Locataire',
                'content': _postController.text.trim(),
              });
              _postController.clear();
              widget.onRefresh();
            },
            icon: const Icon(Icons.send, color: AppColors.accentOrange),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, int targetId, String type) {
    String selectedReason = 'Contenu inapproprié';
    final descController = TextEditingController();
    String selectedPriority = 'Normal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Signaler ce ${type == 'post' ? 'post' : 'commentaire'}', style: TextStyle(color: AppColors.getTextColor(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  dropdownColor: AppColors.getCardColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(labelText: 'Motif', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                  items: ['Contenu inapproprié', 'Spam', 'Harcèlement', 'Fausse information', 'Autre']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(hintText: 'Description (optionnel)', hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriority,
                  dropdownColor: AppColors.getCardColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(labelText: 'Priorité', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                  items: ['Faible', 'Normal', 'Urgent']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedPriority = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
            ElevatedButton(
              onPressed: () async {
                if (widget.currentUser != null) {
                  await DatabaseHelper().addCommunityReport(
                    targetId: targetId,
                    type: type,
                    reason: selectedReason,
                    description: descController.text,
                    priority: selectedPriority,
                    reporterId: widget.currentUser!.id,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé à l\'administration.'), backgroundColor: AppColors.accentRed));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComments(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List comments = post['comments'] as List? ?? [];
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              children: [
                Container(width: 60, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Commentaires', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                    ],
                  ),
                ),
                Expanded(
                  child: comments.isEmpty
                      ? Center(child: Text('Aucun commentaire pour le moment', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final c = comments[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(c['authorName'] ?? 'Utilisateur', style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Row(
                                        children: [
                                          Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(c['date'])), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 10)),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _showReportDialog(context, c['id'], 'comment'),
                                            child: Icon(Icons.report_outlined, size: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(c['content'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(hintText: 'Ajouter un commentaire...', border: InputBorder.none, hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 14)),
                            style: TextStyle(color: AppColors.getTextColor(context)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.accentOrange),
                          onPressed: () async {
                            if (_commentController.text.trim().isEmpty) return;
                            if (widget.currentUser != null) {
                              final comment = {
                                'authorId': widget.currentUser!.id,
                                'authorName': '${widget.currentUser!.prenom} ${widget.currentUser!.nom}',
                                'content': _commentController.text.trim(),
                              };
                              await DatabaseHelper().addCommunityComment(post['id'], comment);
                              _commentController.clear();
                              // Rafraîchir localement le post pour la vue modale
                              setState(() {
                                final pIndex = widget.posts.indexWhere((p) => p['id'] == post['id']);
                                if (pIndex != -1) {
                                  final List currentComments = List.from(widget.posts[pIndex]['comments'] as List? ?? []);
                                  currentComments.add({
                                    ...comment,
                                    'date': DateTime.now().toIso8601String(),
                                    'id': currentComments.length + 1,
                                  });
                                  widget.posts[pIndex]['comments'] = currentComments;
                                }
                              });
                              setModalState(() {}); // Mettre à jour la modale
                              widget.onRefresh(); // Mettre à jour le dashboard
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ========== CENTRE D'AIDE ==========
class _HelpTab extends StatelessWidget {
  const _HelpTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHelpCard(context, appProvider.translate('how_to_apply'), appProvider.translate('how_to_apply_desc')),
          _buildHelpCard(context, appProvider.translate('manage_apps'), appProvider.translate('manage_apps_desc')),
          _buildHelpCard(context, appProvider.translate('problem_support'), appProvider.translate('problem_support_desc')),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent_rounded, size: 48, color: AppColors.accentGreen),
                const SizedBox(height: 16),
                Text(
                  appProvider.translate('contact_whatsapp'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  appProvider.translate('contact_support_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13),
                ),
                const SizedBox(height: 24),
                ModernButton(
                  text: appProvider.translate('chat_on_whatsapp'),
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.accentGreen,
                  onPressed: () {
                    // Logique corrigée pour WhatsApp
                    const phone = "22990000000"; // Numéro support par défaut si vide
                    ExternalLauncher.launchWhatsApp(phone, "Bonjour support ImmoBénin, j'ai besoin d'aide.");
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.report_problem_rounded, size: 48, color: AppColors.accentRed),
                const SizedBox(height: 16),
                Text(
                  appProvider.translate('complaints_and_reports'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  appProvider.translate('report_issue_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ModernButton(
                        text: appProvider.translate('file_complaint'),
                        icon: Icons.add_comment_rounded,
                        color: AppColors.accentRed,
                        onPressed: () => _showReportDialog(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showMyReportsDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(appProvider.translate('my_complaints')),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getTextColor(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ExpansionTile(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        iconColor: AppColors.accentOrange,
        collapsedIconColor: Colors.white38,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(description, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final reportProvider = context.read<ReportProvider>();
    final user = appProvider.user;
    
    if (user == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ReportType selectedType = ReportType.other;
    int? selectedPropertyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(appProvider.translate('file_complaint'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appProvider.translate('report_type'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReportType>(
                  initialValue: selectedType,
                  dropdownColor: AppColors.getCardColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: ReportType.values.map((type) {
                    String label;
                    switch(type) {
                      case ReportType.fraudulentListing: label = 'Annonce frauduleuse'; break;
                      case ReportType.scam: label = 'Escroquerie / Arnaque'; break;
                      case ReportType.fakePics: label = 'Fausses images'; break;
                      case ReportType.inappropriateContent: label = 'Contenu inapproprié'; break;
                      case ReportType.spam: label = 'Spam / Abus'; break;
                      case ReportType.abusiveUser: label = 'Utilisateur abusif'; break;
                      case ReportType.unsafeMeeting: label = 'Rencontre dangereuse'; break;
                      case ReportType.unwantedContact: label = 'Contact non désiré'; break;
                      case ReportType.discriminatory: label = 'Discrimination'; break;
                      default: label = 'Autre problème'; break;
                    }
                    return DropdownMenuItem(
                      value: type,
                      child: Text(label, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                Text(appProvider.translate('complaint_title'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Ex: Problème de plomberie...',
                    hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(appProvider.translate('complaint_description'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    hintText: appProvider.translate('describe_problem_hint'),
                    hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(appProvider.translate('cancel'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)))),
            ModernButton(
              text: appProvider.translate('send'),
              width: 100,
              onPressed: () async {
                if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                
                final success = await reportProvider.submitReport(
                  reporterId: user.id,
                  targetUserId: 1, // Par défaut Admin
                  type: selectedType,
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  attachments: [],
                  targetPropertyId: selectedPropertyId,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? appProvider.translate('complaint_sent_success') : appProvider.translate('message_sent_error')),
                      backgroundColor: success ? AppColors.accentGreen : AppColors.accentRed,
                    )
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMyReportsDialog(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final reportProvider = context.read<ReportProvider>();
    final user = appProvider.user;
    
    if (user == null) return;
    
    reportProvider.loadUserReports(user.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer<ReportProvider>(
        builder: (context, provider, _) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              Container(width: 60, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(appProvider.translate('my_complaints'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                    IconButton(icon: Icon(Icons.refresh, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => provider.loadUserReports(user.id)),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : provider.reports.isEmpty
                    ? Center(child: Text(appProvider.translate('no_complaints_yet'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.reports.length,
                        itemBuilder: (context, index) {
                          final r = provider.reports[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: _getStatusColor(r.status).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                      child: Text(r.status.toString().split('.').last, style: TextStyle(color: _getStatusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    Text(DateFormat('dd/MM/yyyy').format(r.createdAt), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(r.title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                                const SizedBox(height: 4),
                                Text(r.description, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13)),
                                if (r.ownerReply != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AppColors.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Réponse du propriétaire :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
                                        const SizedBox(height: 4),
                                        Text(r.ownerReply!, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.open: return Colors.blue;
      case ReportStatus.inReview: return Colors.orange;
      case ReportStatus.approved: return Colors.green;
      case ReportStatus.rejected: return Colors.red;
      case ReportStatus.resolved: return Colors.teal;
    }
  }

}

class _PaymentsTab extends StatefulWidget {
  final User? user;
  const _PaymentsTab({required this.user});

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _paymentType = 'Loyer'; // Loyer ou Service
  String? _selectedItem;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Effectuer un paiement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
          const SizedBox(height: 20),
          
          // Choix Loyer/Service
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                Expanded(child: _buildTabBtn('Loyer', _paymentType == 'Loyer')),
                Expanded(child: _buildTabBtn('Service', _paymentType == 'Service')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Formulaire de paiement
          _buildPaymentForm(),
          const SizedBox(height: 32),
          
          Text('Historique des transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
          const SizedBox(height: 16),
          _buildTransactionItem('Loyer - Villa Cotonou', '50 000 FCFA', '12/04/2026', 'Confirmé', AppColors.accentGreen),
          _buildTransactionItem('Déménagement', '15 000 FCFA', '05/04/2026', 'Confirmé', AppColors.accentGreen),
          _buildTransactionItem('Loyer - Studio Porto', '25 000 FCFA', '01/03/2026', 'Échoué', AppColors.accentRed),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, bool active) {
    return InkWell(
      onTap: () => setState(() => _paymentType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: active ? AppColors.accentOrange : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1))),
      child: Column(
        children: [
          _buildDropdown(_paymentType == 'Loyer' ? 'Sélectionner le bien' : 'Sélectionner le service'),
          const SizedBox(height: 16),
          _buildTextField('Montant à payer (FCFA)', '50 000', enabled: false),
          const SizedBox(height: 24),
          ModernButton(
            text: 'Payer via Mobile Money',
            onPressed: () => _showConfirmationDialog(),
            color: AppColors.accentOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
      child: DropdownButton<String>(
        value: _selectedItem,
        hint: Text(label, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 14)),
        isExpanded: true,
        dropdownColor: AppColors.getCardColor(context),
        underline: const SizedBox(),
        style: TextStyle(color: AppColors.getTextColor(context)),
        items: const [],
        onChanged: (v) {},
      ),
    );
  }

  Widget _buildTextField(String label, String value, {bool enabled = true}) {
    return TextField(
      controller: TextEditingController(text: value),
      enabled: enabled,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  void _showConfirmationDialog() {
    const amount = 50000;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getScaffoldBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, color: AppColors.accentBlue, size: 48),
            const SizedBox(height: 16),
            Text('Paiement Sécurisé FedaPay', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Vous allez procéder au paiement de $_paymentType pour un montant de $amount FCFA via Mobile Money ou Carte Bancaire.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ModernButton(
              text: 'Payer $amount FCFA',
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet
                _processFedaPay(amount);
              },
              icon: Icons.payment,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _processFedaPay(int amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
    );

    try {
      final appProvider = context.read<AppProvider>();
      final user = widget.user ?? appProvider.user;
      
      // Integration FedaPay Réelle
      // Note: Normalement on utilise FedaPay.startPayment, mais ici on va simuler 
      // un appel réussi à l'API FedaPay via notre service
      
      final transaction = await ApiService.initiatePayment(
        amount: amount.toDouble(),
        description: 'Paiement $_paymentType - ${user?.prenom ?? 'Client'}',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (transaction != null) {
        _showPaymentSuccess(transaction['id'] ?? 'FEDA_${DateTime.now().millisecondsSinceEpoch}');
      } else {
        _showPaymentError("L'initialisation du paiement a échoué. Veuillez vérifier votre connexion.");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showPaymentError("Erreur technique : $e");
    }
  }

  void _showPaymentSuccess(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 60),
            const SizedBox(height: 16),
            Text('Paiement Réussi !', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ID Transaction: $transactionId', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 10)),
            const SizedBox(height: 16),
            Text('Votre paiement a été traité avec succès par FedaPay.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
            const SizedBox(height: 24),
            ModernButton(
              text: 'Terminer',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Échec du paiement', style: TextStyle(color: AppColors.accentRed)),
        content: Text(error, style: TextStyle(color: AppColors.getTextColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount, String date, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                Text(date, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
              Text(status, style: TextStyle(color: statusColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServicesTab extends StatefulWidget {
  final User? user;
  const _ServicesTab({required this.user});

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab> {
  int _viewIndex = 0; // 0: Catalogue, 1: Mes Demandes

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appProvider.translate('partner_services'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
              _buildViewToggle(),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_viewIndex == 0) ...[
            Text('Accédez à nos services partenaires pour faciliter votre emménagement.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 14)),
            const SizedBox(height: 24),
            _buildServiceCard(context, 'Déménagement', 'Transport et manutention sécurisée', Icons.local_shipping, AppColors.accentBlue),
            _buildServiceCard(context, 'Assurance Habitation', 'Protégez votre nouveau foyer', Icons.verified_user, AppColors.accentGreen),
            _buildServiceCard(context, 'Internet & TV', 'Installation fibre et décodeur', Icons.wifi, AppColors.accentOrange),
            _buildServiceCard(context, 'Ménage & Entretien', 'Services de nettoyage professionnel', Icons.cleaning_services, AppColors.accentPurple),
          ] else ...[
            _buildRequestItem('Déménagement Express', 'En attente de devis', '05/04/2026', Colors.orange),
            _buildRequestItem('Nettoyage Entrée', 'Devis accepté - 15 000 FCFA', '12/04/2026', AppColors.accentGreen),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildToggleIcon(Icons.grid_view_rounded, _viewIndex == 0, () => setState(() => _viewIndex = 0)),
          _buildToggleIcon(Icons.list_alt_rounded, _viewIndex == 1, () => setState(() => _viewIndex = 1)),
        ],
      ),
    );
  }

  Widget _buildToggleIcon(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: active ? AppColors.accentOrange : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String desc, IconData icon, Color color) {
    return InkWell(
      onTap: () => _showRequestForm(context, title),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getTextColor(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context))),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: AppColors.accentOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItem(String title, String status, String date, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: statusColor.withValues(alpha: 0.1), child: Icon(Icons.history, color: statusColor)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
          ),
          Text(date, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 11)),
        ],
      ),
    );
  }

  void _showRequestForm(BuildContext context, String service) {
    final dateCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Demander un devis : $service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
              const SizedBox(height: 24),
              TextField(
                controller: dateCtrl,
                decoration: InputDecoration(labelText: 'Date souhaitée', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsCtrl,
                maxLines: 3, 
                decoration: InputDecoration(labelText: 'Détails de la demande', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))
              ),
              const SizedBox(height: 24),
              ModernButton(
                text: 'Envoyer la demande', 
                onPressed: () async {
                  final user = context.read<AppProvider>().user;
                  if (user != null) {
                    await DatabaseHelper().addTicket({
                      'userId': user.id,
                      'email': user.email,
                      'sujet': 'Demande de service : $service',
                      'message': 'Date souhaitée: ${dateCtrl.text}\n\nDétails:\n${detailsCtrl.text}',
                      'status': 'ouvert'
                    });
                    
                    if (bottomSheetContext.mounted) {
                      await bottomSheetContext.read<NotificationProvider>().addNotification(
                        userId: user.id,
                        title: 'Demande envoyée',
                        body: 'Votre demande pour le service "$service" a été transmise à l\'administration.',
                        type: 'service'
                      );

                      // Alerte Admin
                      await NotificationService.envoyerNotification(
                        userId: 1, // Admin
                        type: 'service',
                        message: 'Nouvelle demande de service ($service) de la part de ${user.displayName}.',
                      );
                    }

                    if (bottomSheetContext.mounted) {
                      Navigator.pop(bottomSheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Votre demande a bien été envoyée à l\'administrateur.'), backgroundColor: AppColors.accentGreen));
                    }
                  }
                }
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== CHAT AVEC ADMIN (Style WhatsApp Premium) ==========
class _ChatAdminTab extends StatefulWidget {
  final User? user;
  const _ChatAdminTab({required this.user});

  @override
  State<_ChatAdminTab> createState() => _ChatAdminTabState();
}

class _ChatAdminTabState extends State<_ChatAdminTab> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isTyping = false;
  int _adminId = 1;

  @override
  void initState() {
    super.initState();
    _initAdminId();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _loadMessages();
    });
  }

  Future<void> _initAdminId() async {
    final admin = await DatabaseHelper().getAdminUser();
    if (admin != null && mounted) {
      setState(() => _adminId = admin.id);
    }
  }

  void _loadMessages() {
    final currentUserId = widget.user?.id ?? context.read<AppProvider>().user?.id ?? 0;
    context.read<AdvancedChatProvider>().loadAdminMessages(currentUserId);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    final appProvider = context.read<AppProvider>();
    final currentUserId = widget.user?.id ?? appProvider.user?.id ?? 0;
    
    context.read<AdvancedChatProvider>().sendMessage(
          senderId: currentUserId,
          receiverId: _adminId, 
          content: _msgController.text.trim(),
        ).then((_) {
      _msgController.clear();
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.user?.id ?? 1;
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/chat_bg.png'), // Fallback background pattern
                opacity: 0.05,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(AppColors.primaryDark, BlendMode.dstATop),
              ),
            ),
            child: Consumer<AdvancedChatProvider>(
              builder: (context, provider, _) {
                final messages = provider.messages.where((m) => 
                  (m.senderId == currentUserId && m.receiverId == _adminId) ||
                  (m.senderId == _adminId && m.receiverId == currentUserId)
                ).toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _buildChatBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentOrange,
                child: Icon(Icons.admin_panel_settings, color: AppColors.getTextColor(context)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryDark, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Support ImmoBénin', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_isTyping ? 'En train d\'écrire...' : 'En ligne', style: TextStyle(color: _isTyping ? AppColors.accentOrange : Colors.green, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.videocam_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => _showCallSimulation('vidéo')),
          IconButton(icon: Icon(Icons.call_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => _showCallSimulation('audio')),
          IconButton(icon: Icon(Icons.more_vert_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () {}),
        ],
      ),
    );
  }

  void _showCallSimulation(String type) {
    // Redirige vers WhatsApp pour demander un appel
    ExternalLauncher.launchWhatsApp('22990000000', 'Bonjour, je souhaite démarrer un appel $type.');
  }

  Widget _buildChatBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(2),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFE7FFDB).withValues(alpha: 0.9) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
              ),
              child: _buildFormattedText(msg.text, isMe),
            ),
            Positioned(
              bottom: 6,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('HH:mm').format(msg.timestamp), style: const TextStyle(color: Colors.black45, fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.status == MessageStatus.read ? Icons.done_all : Icons.done,
                      size: 14,
                      color: msg.status == MessageStatus.read ? Colors.blue : Colors.black45,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isMe) {
    // Simple parser for *bold*, _italic_, ~strike~
    List<TextSpan> spans = [];
    const color = Colors.black87;

    // This is a very basic implementation. In a real app, use a proper markdown library.
    text.split(' ').forEach((word) {
      if (word.startsWith('*') && word.endsWith('*') && word.length > 2) {
        spans.add(TextSpan(text: '${word.substring(1, word.length - 1)} ', style: const TextStyle(fontWeight: FontWeight.bold, color: color)));
      } else if (word.startsWith('_') && word.endsWith('_') && word.length > 2) {
        spans.add(TextSpan(text: '${word.substring(1, word.length - 1)} ', style: const TextStyle(fontStyle: FontStyle.italic, color: color)));
      } else if (word.startsWith('~') && word.endsWith('~') && word.length > 2) {
        spans.add(TextSpan(text: '${word.substring(1, word.length - 1)} ', style: const TextStyle(decoration: TextDecoration.lineThrough, color: color)));
      } else {
        spans.add(TextSpan(text: '$word ', style: const TextStyle(color: color)));
      }
    });

    return RichText(text: TextSpan(children: spans, style: const TextStyle(fontSize: 15)));
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(top: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_rounded, color: AppColors.accentOrange), onPressed: _showAttachmentsMenu),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onChanged: (v) => setState(() {}),
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded, color: Colors.cyanAccent, size: 20),
                    onPressed: _askMetaAI,
                    tooltip: 'Aide Meta AI',
                  ),
                  if (_msgController.text.isEmpty)
                    IconButton(icon: Icon(Icons.camera_alt_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () {}),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _msgController.text.isEmpty
              ? _buildVoiceButton()
              : CircleAvatar(
                  backgroundColor: AppColors.accentOrange,
                  child: IconButton(icon: Icon(Icons.send_rounded, color: AppColors.getTextColor(context)), onPressed: _sendMessage),
                ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onLongPress: () => _showVoiceRecordingSimulation(),
      child: CircleAvatar(
        backgroundColor: AppColors.accentOrange,
        child: Icon(Icons.mic_rounded, color: AppColors.getTextColor(context)),
      ),
    );
  }

  void _showVoiceRecordingSimulation() async {
    setState(() => _isTyping = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enregistrement en cours... (simulation)'), duration: Duration(seconds: 2)),
    );
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final currentUserId = widget.user?.id ?? 1;
      await context.read<AdvancedChatProvider>().sendVoiceNote(
        senderId: currentUserId,
        receiverId: 1, // Admin ID
        duration: '0:05',
        filePath: 'simulation_audio.aac',
      );
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _askMetaAI() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.cyan.shade900, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.cyanAccent),
                const SizedBox(width: 12),
                Text('Meta AI Assistant', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Comment puis-je vous aider avec votre conversation ?', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 20),
            _buildAIAction('Résumer la discussion', Icons.summarize_rounded),
            _buildAIAction('Suggérer une réponse', Icons.reply_all_rounded),
            _buildAIAction('Traduire les derniers messages', Icons.translate_rounded),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAction(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.cyanAccent),
      title: Text(label, style: TextStyle(color: AppColors.getTextColor(context))),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action AI : $label')));
      },
    );
  }

  void _showAttachmentsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          shrinkWrap: true,
          children: [
            _buildAttachmentItem('Caméra', Icons.camera_alt_rounded, Colors.pink, () => _pickImage(ImageSource.camera)),
            _buildAttachmentItem('Galerie', Icons.image_rounded, Colors.purpleAccent, () => _pickImage(ImageSource.gallery)),
            _buildAttachmentItem('Document', Icons.description_rounded, Colors.purple, () {}),
            _buildAttachmentItem('Audio', Icons.headset_rounded, Colors.orange, () {}),
            _buildAttachmentItem('Position', Icons.location_on_rounded, Colors.green, () {}),
            _buildAttachmentItem('Contact', Icons.person_rounded, Colors.blue, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: AppColors.getTextColor(context))),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        final currentUserId = widget.user?.id ?? 1;
        await context.read<AdvancedChatProvider>().sendMessage(
          senderId: currentUserId,
          receiverId: 1,
          content: '[Image partagée : ${pickedFile.name}]',
          attachments: [pickedFile.path],
        );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du choix de l\'image')));
    }
  }
}



