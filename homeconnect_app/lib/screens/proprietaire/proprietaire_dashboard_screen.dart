// lib/screens/proprietaire/proprietaire_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/property.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../providers/app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/property_provider.dart';
import '../../utils/app_colors.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../providers/report_provider.dart';
import '../../models/report_sanction_models.dart';
import '../tenant/chat_screen.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/design_widgets.dart';
import '../../providers/support_provider.dart';
// Note: locataire_models.dart removed - Report class comes from report_sanction_models.dart
import '../../models/locataire_models.dart';
import '../../utils/external_launcher.dart';
import '../../utils/pdf_generator.dart';
import '../../providers/advanced_chat_provider.dart';
import '../../models/chat_message.dart';
import '../../services/notification_service.dart';
import 'add_property_screen.dart';

class ProprietaireDashboardScreen extends StatefulWidget {
  const ProprietaireDashboardScreen({super.key});

  @override
  State<ProprietaireDashboardScreen> createState() => _ProprietaireDashboardScreenState();
}

class _ProprietaireDashboardScreenState extends State<ProprietaireDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  List<Property> _properties = [];
  List<Map<String, dynamic>> _candidatures = [];
  List<Map<String, dynamic>> _contracts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      await appProvider.checkAuthStatus();
      final db = DatabaseHelper();
      final user = appProvider.user;
      if (user != null) {
        // Charger depuis l'API pour avoir les vrais IDs serveur + images uploadées
        try {
          final list = await ApiService.getOwnerProperties();
          if (list.isNotEmpty) {
            _properties = list
                .map((p) => Property.fromApiMap(Map<String, dynamic>.from(p as Map)))
                .toList();
          } else {
            final data = await db.getPropertiesForOwner(user.id);
            _properties = data.map((e) => Property.fromMap(e)).toList();
          }
        } catch (_) {
          final data = await db.getPropertiesForOwner(user.id);
          _properties = data.map((e) => Property.fromMap(e)).toList();
        }
        // Candidatures depuis l'API (source de vérité)
        try {
          final rawApps = await ApiService.getOwnerApplications();
          _candidatures = rawApps.cast<Map<String, dynamic>>();
        } catch (_) {
          _candidatures = await db.getApplicationsForProprietaire(user.id);
        }
        _contracts = await db.getContractsForOwner(user.id);
        
        if (!mounted) return;
        // Load reports
        await context.read<ReportProvider>().loadReportsAgainstOwner(user.id);
        if (!mounted) return;
        // Load notifications via Provider
        await context.read<NotificationProvider>().loadNotifications(user.id);
      }
    } catch (e) {
      debugPrint('❌ Erreur dashboard propriétaire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isVerified = appProvider.user?.verificationStatus == 'certifie';

    final kycStatus = appProvider.user?.verificationStatus;
    final isBlocked = kycStatus != 'certifie'; // bloqué si pas encore certifié

    return RoleGuard(
      allowedRoles: const ['proprietaire'],
      customErrorMessage: 'Seuls les propriétaires peuvent accéder au dashboard propriétaire',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        body: _isLoading
            ? const Center(child: LoadingWidget(message: 'Chargement de votre espace...'))
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.getBackgroundGradient(context),
                ),
                child: SafeArea(
                  child: Column(
                  children: [
                    PremiumHeaderWidget(
                      title: 'HomeConnect',
                      subtitle: 'Espace Propriétaire',
                      notificationCount: context.watch<NotificationProvider>().unreadCount,
                      onNotificationTap: () => _showNotificationsDialog(context.read<NotificationProvider>()),
                      onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                      onLogoutTap: () => _showLogoutConfirmation(context),
                      onChatTap: () => setState(() { _selectedIndex = 6; _tabController.animateTo(6); }),
                      onSyncTap: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Synchronisation en cours...'), duration: Duration(seconds: 1)),
                        );
                        await context.read<PropertyProvider>().syncData(appProvider.user?.id);
                        await _loadData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Synchronisation terminée'), backgroundColor: Colors.green),
                        );
                      },
                    ),

                    // ── Bannière KYC globale ─────────────────────────────
                    if (isBlocked)
                      _buildKycBlockBanner(context, kycStatus),

                    Expanded(
                      child: isBlocked
                          // Compte non certifié → page de blocage
                          ? _buildKycBlockedContent(context, kycStatus)
                          // Compte certifié → dashboard normal
                          : IndexedStack(
                              index: _selectedIndex,
                              children: [
                                _OverviewTab(properties: _properties, candidatures: _candidatures, user: appProvider.user, onQuickAction: (i) => setState(() { _selectedIndex = i; _tabController.animateTo(i); }), onRefresh: _loadData),
                                _PropertiesTab(properties: _properties, onRefresh: _loadData),
                                _ApplicationsTab(candidatures: _candidatures, onRefresh: _loadData),
                                _ContractsTab(
                                  properties: _properties,
                                  candidatures: _candidatures,
                                  contracts: _contracts,
                                  onRefresh: _loadData
                                ),
                                _SubscriptionTab(user: appProvider.user, onRefresh: _loadData),
                                _PartnersTab(userId: appProvider.user?.id ?? 0),
                                _ChatAdminProprietaireTab(user: appProvider.user),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              ),
        floatingActionButton: !isBlocked && _selectedIndex == 1 ? _buildFAB(isVerified) : null,
        bottomNavigationBar: !isBlocked ? _buildTabBar(appProvider) : null,
      ),
    );
  }

  // ── Bannière KYC (bande colorée en haut) ───────────────────────────────────
  Widget _buildKycBlockBanner(BuildContext context, String? status) {
    final isPending  = status == 'en_attente';
    final isRejected = status == 'rejete' || status == 'rejet';
    final color = isPending ? Colors.orange : isRejected ? Colors.red : Colors.grey;
    final icon  = isPending ? Icons.hourglass_top : isRejected ? Icons.cancel : Icons.warning_amber;
    final text  = isPending
        ? 'Vérification en cours — compte en attente de certification'
        : isRejected
            ? 'Dossier KYC rejeté — contactez l\'administration'
            : 'Compte non certifié — soumettez vos documents';
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ── Contenu bloqué (remplace les tabs quand non certifié) ─────────────────
  Widget _buildKycBlockedContent(BuildContext context, String? status) {
    final isPending  = status == 'en_attente';
    final isRejected = status == 'rejete' || status == 'rejet';
    final user       = context.read<AppProvider>().user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 50,
            backgroundColor: (isPending ? Colors.orange : isRejected ? Colors.red : Colors.grey).withValues(alpha: 0.15),
            child: Icon(
              isPending ? Icons.hourglass_empty : isRejected ? Icons.cancel : Icons.lock,
              size: 48,
              color: isPending ? Colors.orange : isRejected ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isPending ? 'Compte en attente de certification'
                : isRejected ? 'Dossier KYC rejeté'
                : 'Compte non certifié',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isPending
                ? 'Vos documents KYC ont été soumis et sont en cours d\'examen par l\'administrateur.\n\nVous serez notifié dès que votre compte sera certifié (généralement sous 24–48h).'
                : isRejected
                    ? 'Votre dossier KYC a été rejeté.\nMotif : ${user?.verificationRejectionReason ?? "Non précisé"}\n\nVeuillez contacter l\'administration pour renvoyer vos documents.'
                    : 'Votre compte propriétaire n\'est pas encore certifié.\nVeuillez soumettre vos documents KYC pour accéder à la plateforme.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Seule action autorisée : messagerie avec admin
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/messages'),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contacter l\'administration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          // Bouton déconnexion
          TextButton.icon(
            onPressed: () => _showLogoutConfirmation(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Se déconnecter'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text('Voulez-vous vraiment vous déconnecter ?', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: Text('Se déconnecter', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppProvider>().logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _showNotificationsDialog(NotificationProvider notifProvider) async {
    final user = context.read<AppProvider>().user;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getScaffoldBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 60, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.read<AppProvider>().translate('notifications'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                  if (notifProvider.notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        if (user != null) notifProvider.markAllAsRead(user.id);
                      },
                      child: const Text('Tout lire', style: TextStyle(color: AppColors.accentBlue)),
                    ),
                ],
              ),
            ),
            if (notifProvider.notifications.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text(context.read<AppProvider>().translate('no_notifications'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))))
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifProvider.notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifProvider.notifications[index];
                    final isUnread = n['read'] != true;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: (isUnread ? AppColors.accentOrange : AppColors.accentBlue).withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(12)
                        ), 
                        child: Icon(
                          isUnread ? Icons.notification_important_rounded : Icons.notifications_none_rounded, 
                          color: isUnread ? AppColors.accentOrange : AppColors.accentBlue
                        )
                      ),
                      title: Text(n['title'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(n['body'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                      trailing: Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(n['createdAt'])), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(AppProvider appProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.cardDark : Colors.white,
      child: SafeArea(
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: AppColors.getTextColor(context).withValues(alpha: 0.5),
          indicatorColor: AppColors.accentOrange,
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) => setState(() => _selectedIndex = index),
          tabs: [
            Tab(icon: const Icon(Icons.dashboard_outlined, size: 24), text: appProvider.translate('overview')),
            Tab(icon: const Icon(Icons.home_work_outlined, size: 24), text: appProvider.translate('my_properties')),
            Tab(icon: const Icon(Icons.assignment_outlined, size: 24), text: appProvider.translate('applications')),
            const Tab(icon: Icon(Icons.description_outlined, size: 24), text: 'Contrats'),
            const Tab(icon: Icon(Icons.card_membership_outlined, size: 24), text: 'Premium+'),
            const Tab(icon: Icon(Icons.handshake_outlined, size: 24), text: 'Partenaires'),
            const Tab(icon: Icon(Icons.chat_outlined, size: 24), text: 'Chat Admin'),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(bool isVerified) {
    return FloatingActionButton.extended(
      onPressed: () {
        if (isVerified) {
          Navigator.pushNamed(context, '/add-property').then((_) => _loadData());
        } else {
          _showKYCLockedDialog();
        }
      },
      backgroundColor: isVerified ? AppColors.accentOrange : Colors.grey.shade700,
      icon: Icon(isVerified ? Icons.add : Icons.lock, color: AppColors.getTextColor(context)),
      label: Text(context.read<AppProvider>().translate('add_property'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.w600)),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  void _showKYCLockedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.accentOrange),
            const SizedBox(width: 10),
            Text('Accès restreint', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18)),
          ],
        ),
        content: Text(
          'Votre compte n\'est pas encore certifié.\n\nL\'administrateur doit vérifier vos documents (KYC) avant que vous ne puissiez ajouter des biens immobiliers.',
          style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Fermer', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/verification');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Aller à la vérification'),
          ),
        ],
      ),
    );
  }
}

// ========== APERÇU TAB ==========
class _OverviewTab extends StatelessWidget {
  final List<Property> properties;
  final List<Map<String, dynamic>> candidatures;
  final User? user;
  final void Function(int) onQuickAction;
  final VoidCallback onRefresh;
  const _OverviewTab({
    required this.properties,
    required this.candidatures,
    required this.user,
    required this.onQuickAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final actifs = properties.where((p) => p.status == 'actif').length;
    final enAttente = properties.where((p) => p.status == 'en_attente').length;
    final totalVues = properties.fold(0, (sum, p) => sum + p.views);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(28)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.getTextColor(context), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.business_center, size: 36, color: AppColors.primaryDark)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour ${user?.prenom ?? appProvider.translate('profile')} 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                        Text(appProvider.translate('dashboard'), style: TextStyle(fontSize: 13, color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildCertificationBanner(context),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildKpiCard(context, '${properties.length}', 'Biens total', Icons.home, AppColors.accentBlue),
                _buildKpiCard(context, '$actifs', 'Actifs', Icons.check_circle, AppColors.accentGreen),
                _buildKpiCard(context, '$enAttente', 'En attente', Icons.pending, AppColors.accentOrange),
                _buildKpiCard(context, '${candidatures.length}', 'Candidatures', Icons.people, AppColors.accentPurple),
              ],
            ),
            const SizedBox(height: 24),
            if (properties.isNotEmpty) ...[
              SectionHeaderWidget(title: 'Vos Biens', actionText: 'Voir tout', onAction: () => onQuickAction(1)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final p = properties[index];
                    return InkWell(
                      onTap: () => Navigator.pushNamed(context, '/property/${p.id}'),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: DecorationImage(
                            image: getSafeImageProvider(p.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('${p.prix} FCFA/mois', style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (properties.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility, color: AppColors.accentTeal),
                    const SizedBox(width: 12),
                    Text('$totalVues vues sur vos biens', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── Bloc statistiques avancées ──────────────────────────────
            FutureBuilder<Map<String, dynamic>?>(
              future: ApiService.getOwnerStatistics(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange)),
                  );
                }
                final s = snap.data;
                if (s == null) return const SizedBox.shrink();

                final convRate   = (s['conversionRate'] as num?)?.toDouble() ?? 0.0;
                final revenue    = (s['totalMonthlyRevenue'] as num?)?.toDouble() ?? 0.0;
                final commRate   = (s['commissionRate'] as num?)?.toDouble() ?? 5.0;
                final accepted   = (s['acceptedCount'] as int?) ?? 0;
                final plan       = (s['plan'] as String?) ?? 'free';
                final isDark     = Theme.of(context).brightness == Brightness.dark;
                final surfaceColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.bar_chart_rounded, color: AppColors.accentOrange, size: 20),
                        const SizedBox(width: 8),
                        Text('Performances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextColor(context))),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _buildStatItem(context, '$convRate%', 'Taux conversion', Icons.trending_up, AppColors.accentGreen)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatItem(context, '$accepted', 'Acceptées', Icons.check_circle_outline, AppColors.accentBlue)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildStatItem(context,
                          revenue > 0 ? '${revenue.toStringAsFixed(0)} F' : '—',
                          'Revenus/mois', Icons.payments_outlined, AppColors.accentPurple)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatItem(context,
                          '$commRate%',
                          'Commission HC',
                          Icons.percent,
                          plan == 'free' ? AppColors.accentOrange : AppColors.accentTeal,
                        )),
                      ]),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appProvider.translate('settings'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionButton(appProvider.translate('my_properties'), Icons.home_work, AppColors.accentBlue, () => onQuickAction(1)),
                      _buildActionButton(appProvider.translate('applications'), Icons.assignment, AppColors.accentOrange, () => onQuickAction(2)),
                      _buildActionButton('Statistiques', Icons.analytics, AppColors.accentGreen, () => onQuickAction(3)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis)
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: isDark ? 0.55 : 0.6)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationBanner(BuildContext context) {
    final status = user?.verificationStatus ?? 'non_verifie';
    
    Color bannerColor;
    IconData icon;
    String title;
    String message;

    if (status == 'certifie') {
      bannerColor = AppColors.accentGreen;
      icon = Icons.verified_user_rounded;
      title = 'Compte Certifié';
      message = 'Votre compte est vérifié. Vous avez accès à toutes les fonctionnalités.';
    } else if (status == 'en_attente') {
      bannerColor = AppColors.accentBlue;
      icon = Icons.hourglass_empty_rounded;
      title = 'Vérification en cours';
      message = 'Vos documents sont en cours de vérification par l\'administration.';
    } else if (status == 'rejet') {
      bannerColor = AppColors.accentRed;
      icon = Icons.error_outline_rounded;
      title = 'Certification Rejetée';
      message = user?.verificationRejectionReason ?? 'Vos documents n\'ont pas été validés. Veuillez les soumettre à nouveau.';
    } else {
      bannerColor = AppColors.accentOrange;
      icon = Icons.warning_amber_rounded;
      title = 'Compte Non Certifié';
      message = 'Veuillez soumettre vos documents pour publier des biens.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bannerColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: bannerColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: bannerColor, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          if (status == 'non_verifie' || status == 'rejet')
            IconButton(
              icon: Icon(Icons.arrow_forward_ios_rounded, color: bannerColor, size: 16),
              onPressed: () => Navigator.pushNamed(context, '/verification'),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

// ========== BIENS TAB ==========
class _PropertiesTab extends StatelessWidget {
  final List<Property> properties;
  final VoidCallback onRefresh;
  const _PropertiesTab({required this.properties, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text('Aucun bien publié', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 18)),
            const SizedBox(height: 8),
            Text('Appuyez sur + pour ajouter votre premier bien', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.3), fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: properties.length,
      itemBuilder: (context, index) => _buildPropertyCard(context, properties[index]),
    );
  }

  bool _checkCertification(BuildContext context) {
    return context.read<AppProvider>().user?.verificationStatus == 'certifie';
  }

  void _showUncertifiedMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Certification requise', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text('Votre compte doit être certifié par l\'administration avant de pouvoir effectuer cette action.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: AppColors.accentOrange))),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02), Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image removed as requested by user
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(property.titre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: property.status == 'actif' ? AppColors.successGradient : (property.status == 'suspendu' ? AppColors.dangerGradient : AppColors.warningGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  property.status == 'actif' ? 'Actif' : (property.status == 'suspendu' ? 'Suspendu' : 'En attente'),
                  style: TextStyle(color: AppColors.getTextColor(context), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (property.isHighlighted) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text('Bien mis en avant', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(property.lieu, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${property.prix} FCFA / mois', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange, fontSize: 16)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('${property.pieces} pièces · ${property.type}', style: const TextStyle(fontSize: 11, color: AppColors.accentBlue)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.visibility, size: 14, color: AppColors.textMedium),
              const SizedBox(width: 4),
              Text('${property.views} vues', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              const SizedBox(width: 16),
              const Icon(Icons.thumb_up_alt_outlined, size: 14, color: AppColors.textMedium),
              const SizedBox(width: 4),
              Text('${property.likes}', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textMedium),
              const SizedBox(width: 4),
              Text('${property.commentsCount}', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/property/${property.id}'),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Détails'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.accentBlue, side: const BorderSide(color: AppColors.accentBlue)),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  if (_checkCertification(context)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddPropertyScreen(property: property),
                      ),
                    ).then((_) => onRefresh());
                  } else {
                    _showUncertifiedMessage(context);
                  }
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.accentOrange, side: const BorderSide(color: AppColors.accentOrange)),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final isSuspending = property.status == 'actif';
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.getCardColor(context),
                      title: Text(isSuspending ? 'Suspendre le bien ?' : 'Activer le bien ?', style: TextStyle(color: AppColors.getTextColor(context))),
                      content: Text(
                        isSuspending 
                          ? 'En suspendant ce bien, il ne sera plus visible par les locataires potentiels. Toutes les candidatures en cours resteront accessibles.'
                          : 'Le bien sera à nouveau visible par tous les locataires.',
                        style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: isSuspending ? AppColors.accentRed : AppColors.accentGreen),
                          child: Text(isSuspending ? 'Suspendre' : 'Activer'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    if (!context.mounted) return;
                    if (!_checkCertification(context)) {
                      _showUncertifiedMessage(context);
                      return;
                    }
                    final newStatus = isSuspending ? 'suspendu' : 'actif';
                    await DatabaseHelper().updateProperty(property.id, {'status': newStatus});
                    if (!context.mounted) return;
                    onRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bien ${newStatus == 'actif' ? 'activé' : 'suspendu'}')));
                  }
                },
                icon: Icon(property.status == 'actif' ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 16),
                label: Text(property.status == 'actif' ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: property.status == 'actif' ? AppColors.accentRed : AppColors.accentGreen,
                  side: BorderSide(color: property.status == 'actif' ? AppColors.accentRed : AppColors.accentGreen),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!_checkCertification(context)) {
                    _showUncertifiedMessage(context);
                    return;
                  }
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.getCardColor(context),
                      title: Text('Supprimer', style: TextStyle(color: AppColors.getTextColor(context))),
                      content: Text('Supprimer "${property.titre}" définitivement ?', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: AppColors.accentRed))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await DatabaseHelper().deleteProperty(property.id);
                    if (!context.mounted) return;
                    onRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bien supprimé')));
                  }
                },
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.accentRed, side: const BorderSide(color: AppColors.accentRed)),
              ),
              if (context.read<AppProvider>().user?.isSubscriptionActive == true)
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!_checkCertification(context)) {
                      _showUncertifiedMessage(context);
                      return;
                    }
                    final newStatus = !property.isHighlighted;
                    await DatabaseHelper().updateProperty(property.id, {'isHighlighted': newStatus ? 1 : 0});
                    if (!context.mounted) return;
                    onRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus ? 'Bien mis en avant !' : 'Mise en avant retirée')));
                  },
                  icon: Icon(property.isHighlighted ? Icons.star : Icons.star_border, size: 16),
                  label: Text(property.isHighlighted ? 'Retirer' : 'Mettre en avant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

}

// ========== CANDIDATURES TAB ==========
class _ApplicationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> candidatures;
  final VoidCallback onRefresh;
  const _ApplicationsTab({required this.candidatures, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (candidatures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('Aucune candidature reçue', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: candidatures.length,
      itemBuilder: (context, index) {
        final c = candidatures[index];
        final statut = c['statut'];
        final dateCandidature = c['date'] != null ? DateTime.parse(c['date']) : DateTime.now();
        final visiteDate = c['visiteDate'] != null ? DateTime.parse(c['visiteDate']) : null;
        final locataireNom = '${c['locataireNom'] ?? 'Locataire'} ${c['locatairePrenom'] ?? ''}';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statut == 'acceptee' ? AppColors.accentGreen.withValues(alpha: 0.3) 
                   : (statut == 'refusee' ? AppColors.accentRed.withValues(alpha: 0.3) 
                   : Colors.white.withValues(alpha: 0.1)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Status
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accentOrange.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppColors.accentOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(locataireNom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context))),
                          Text(
                            'Candidat pour : ${c['bien']}',
                            style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(statut),
                  ],
                ),
              ),
              
              Divider(height: 1, color: AppColors.getTextColor(context).withValues(alpha: 0.10)),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.38)),
                        const SizedBox(width: 6),
                        Text(
                          'Reçue le ${DateFormat('dd/MM/yyyy').format(dateCandidature)}', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38), fontSize: 12),
                        ),
                      ],
                    ),
                    if (c['message'] != null && c['message'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '"${c['message']}"',
                          style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],

                    // Visit Info
                    if (visiteDate != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available, size: 18, color: AppColors.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Visite planifiée : ${DateFormat('dd MMMM à HH:mm', 'fr_FR').format(visiteDate)}', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    if (statut == 'en_attente') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ActionButtonWidget(
                              label: 'Accepter',
                              icon: Icons.check_circle_outline,
                              variant: ButtonVariant.primary,
                              onPressed: () async {
                                await DatabaseHelper().updateApplicationStatus(c['id'], 'acceptee');
                                await NotificationService.envoyerNotification(
                                  userId: c['locataireId'],
                                  type: 'candidature',
                                  message: 'Votre candidature pour le bien "${c['bien']}" a été ACCEPTEE !',
                                );
                                if (!context.mounted) return;
                                onRefresh();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Candidature acceptée. Vous pouvez maintenant planifier une visite.'), backgroundColor: AppColors.accentGreen),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ActionButtonWidget(
                              label: 'Refuser',
                              icon: Icons.highlight_off,
                              variant: ButtonVariant.danger,
                              onPressed: () async {
                                await DatabaseHelper().updateApplicationStatus(c['id'], 'refusee');
                                await NotificationService.envoyerNotification(
                                  userId: c['locataireId'],
                                  type: 'candidature',
                                  message: 'Votre candidature pour le bien "${c['bien']}" a été refusée.',
                                );
                                if (!context.mounted) return;
                                onRefresh();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidature refusée')));
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else if (statut == 'acceptee') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ActionButtonWidget(
                              label: visiteDate == null ? 'Planifier une visite' : 'Modifier la visite',
                              icon: Icons.calendar_month_rounded,
                              variant: ButtonVariant.secondary,
                              onPressed: () => _planifierVisite(context, c['id']),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildChatButton(context, c),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildChatButton(context, c),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String statut) {
    Color color;
    String label;
    IconData icon;

    switch (statut) {
      case 'acceptee':
        color = AppColors.accentGreen;
        label = 'Acceptée';
        icon = Icons.check_circle;
        break;
      case 'refusee':
        color = AppColors.accentRed;
        label = 'Refusée';
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.accentOrange;
        label = 'En attente';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChatButton(BuildContext context, Map<String, dynamic> c) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    receiverId: c['locataireId'],
                    receiverName: '${c['locataireNom']} ${c['locatairePrenom']}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accentBlue, size: 20),
            tooltip: 'Contacter le candidat',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(
                    receiverId: 1,
                    receiverName: 'Administration',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.accentOrange, size: 20),
            tooltip: 'Contacter l\'admin',
          ),
        ),
      ],
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
                
                // Récupérer les infos de la candidature pour le message
                final cand = candidatures.firstWhere((c) => c['id'] == appId);
                await NotificationService.envoyerNotification(
                  userId: cand['locataireId'],
                  type: 'candidature',
                  message: 'Une visite a été planifiée pour "${cand['bien']}" le ${DateFormat('dd/MM à HH:mm').format(datetime)}.',
                );

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

// ========== CONTRATS & ÉTATS DES LIEUX ==========
class _ContractsTab extends StatefulWidget {
  final List<Property> properties;
  final List<Map<String, dynamic>> candidatures;
  final List<Map<String, dynamic>> contracts;
  final VoidCallback onRefresh;

  const _ContractsTab({
    required this.properties,
    required this.candidatures,
    required this.contracts,
    required this.onRefresh,
  });

  @override
  State<_ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<_ContractsTab> {
  Property? _selectedProperty;
  Map<String, dynamic>? _selectedCandidature;

  void _showDocumentTypeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Que souhaitez-vous créer ?', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.description_rounded, color: AppColors.accentOrange),
              ),
              title: Text('Contrat de Bail', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
              subtitle: Text('Générer un PDF avec les infos du bien et du locataire', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showContractForm();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.checklist_rounded, color: AppColors.accentBlue),
              ),
              title: Text('État des Lieux', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
              subtitle: Text('Évaluation pièce par pièce avec photos', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showEtatDesLieuxForm();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showContractForm() {
    final acceptedCandidatures = widget.candidatures.where((c) => c['statut'] == 'acceptee').toList();

    if (widget.properties.isEmpty) {
      _showErrorSnackBar('Vous n\'avez aucun bien publié.');
      return;
    }
    if (acceptedCandidatures.isEmpty) {
      _showErrorSnackBar('Aucune candidature n\'a été acceptée pour générer un contrat.');
      return;
    }

    _selectedProperty = null;
    _selectedCandidature = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Générer un contrat', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Property>(
                initialValue: _selectedProperty,
                hint: Text('Choisir le bien', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 14)),
                dropdownColor: AppColors.getCardColor(context),
                style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14),
                isExpanded: true,
                items: widget.properties.map((p) => DropdownMenuItem(value: p, child: Text(p.titre, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setDialogState(() => _selectedProperty = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.home_work_outlined, color: AppColors.accentOrange, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: _selectedCandidature,
                hint: Text('Choisir le locataire', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 14)),
                dropdownColor: AppColors.getCardColor(context),
                style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14),
                isExpanded: true,
                items: acceptedCandidatures.map((c) => DropdownMenuItem(
                  value: c, 
                  child: Text('${c['locataireNom']} ${c['locatairePrenom']}', overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (v) => setDialogState(() => _selectedCandidature = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.accentOrange, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
            ElevatedButton(
              onPressed: (_selectedProperty != null && _selectedCandidature != null) 
                ? () => _previewAndGenerateContract() 
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Suivant'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.accentRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _previewAndGenerateContract() {
    Navigator.pop(context); // Close selection dialog
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        insetPadding: const EdgeInsets.all(20),
        title: Text('Aperçu du Contrat', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.getTextColor(context), borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text('CONTRAT DE BAIL À USAGE D\'HABITATION', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
                const SizedBox(height: 20),
                const Text('ENTRE LES SOUSSIGNÉS :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('LE BAILLEUR: ${context.read<AppProvider>().user?.displayName ?? 'Propriétaire'}'),
                const SizedBox(height: 10),
                Text('LE PRENEUR: ${_selectedCandidature!['locataireNom']} ${_selectedCandidature!['locatairePrenom']}'),
                const SizedBox(height: 20),
                const Text('OBJET DU CONTRAT :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const Text('Le présent contrat a pour objet la location du bien suivant :'),
                Text('- Titre: ${_selectedProperty!.titre}'),
                Text('- Adresse: ${_selectedProperty!.lieu}'),
                Text('- Loyer: ${_selectedProperty!.prix} FCFA / mois'),
                const SizedBox(height: 20),
                const Text('DURÉE :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const Text('Le présent bail est conclu pour une durée indéterminée avec un préavis de 3 mois.'),
                const SizedBox(height: 30),
                Center(child: Text('Fait à Cotonou, le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 10))),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Signature Billeur', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
                    Text('Signature Preneur', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              
              // Générer le PDF réel
              await PdfGenerator.generateContractPdf(
                ownerName: context.read<AppProvider>().user?.displayName ?? 'Propriétaire',
                tenantName: '${_selectedCandidature!['locataireNom']} ${_selectedCandidature!['locatairePrenom']}',
                propertyTitle: _selectedProperty!.titre,
                propertyAddress: _selectedProperty!.lieu,
                price: _selectedProperty!.prix.toString(),
              );

              _saveDocument('Contrat de Bail', {
                'propertyId': _selectedProperty!.id,
                'propertyName': _selectedProperty!.titre,
                'locataireId': _selectedCandidature!['locataireId'],
                'locataireName': '${_selectedCandidature!['locataireNom']} ${_selectedCandidature!['locatairePrenom']}',
                'price': _selectedProperty!.prix,
                'lieu': _selectedProperty!.lieu,
              });
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Générer PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGreen),
          ),
        ],
      ),
    );
  }

  void _showEtatDesLieuxForm() {
    final Map<String, String> evals = {
      'Salon': 'Bon état',
      'Cuisine': 'Bon état',
      'Chambres': 'Bon état',
      'Salle de bain': 'Bon état',
      'WC': 'Bon état',
      'Jardin': 'Bon état',
    };
    final Map<String, bool> photos = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          insetPadding: const EdgeInsets.all(10),
          title: Text('État des lieux numérique', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Property>(
                    initialValue: _selectedProperty,
                    hint: Text('Sélectionner le bien', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 14)),
                    dropdownColor: AppColors.getCardColor(context),
                    style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14),
                    items: widget.properties.map((p) => DropdownMenuItem(value: p, child: Text(p.titre, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDialogState(() => _selectedProperty = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.home_work_outlined, color: AppColors.accentBlue, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...evals.keys.map((room) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: evals[room],
                                items: const ['Excellent', 'Très bon état', 'Bon état', 'À vérifier', 'À réparer']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context))))).toList(),
                                onChanged: (v) { if (v != null) setDialogState(() => evals[room] = v); },
                                decoration: InputDecoration(
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                                ),
                                style: TextStyle(color: AppColors.getTextColor(context)),
                                dropdownColor: AppColors.getCardColor(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                photos[room] == true ? Icons.check_circle : Icons.add_a_photo_rounded, 
                                color: photos[room] == true ? AppColors.accentGreen : AppColors.accentBlue,
                                size: 28,
                              ),
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                                if (photo != null) {
                                  setDialogState(() => photos[room] = true);
                                }
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
            ElevatedButton(
              onPressed: _selectedProperty != null ? () async {
                Navigator.pop(context);
                
                // Générer le PDF de l'état des lieux
                await PdfGenerator.generateEtatDesLieuxPdf(
                  propertyTitle: _selectedProperty!.titre,
                  evaluations: evals,
                );

                _saveDocument('État des lieux', {
                  'propertyId': _selectedProperty!.id,
                  'propertyName': _selectedProperty!.titre,
                  'evaluations': evals,
                });
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enregistrer & PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDocument(String type, Map<String, dynamic> extra) async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;

    await DatabaseHelper().addContract({
      'type': type,
      'proprietaireId': user.id,
      'status': 'Terminé',
      ...extra,
    });

    // Alerte Admin
    await NotificationService.envoyerNotification(
      userId: 1, // Admin
      type: 'report',
      message: 'Un nouveau document ($type) a été généré par ${user.displayName} pour le bien "${extra['propertyName']}".',
    );
    
    if (!mounted) return;
    widget.onRefresh();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type enregistré dans l\'historique'), backgroundColor: AppColors.accentGreen));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: ActionButtonWidget(
            label: 'Nouveau Document',
            icon: Icons.add_circle_outline_rounded,
            variant: ButtonVariant.primary,
            isFullWidth: true,
            onPressed: _showDocumentTypeSelection,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Historique des documents', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: widget.contracts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('Aucun document enregistré', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.24))),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.contracts.length,
                itemBuilder: (context, index) {
                  final doc = widget.contracts.reversed.toList()[index];
                  final isContrat = doc['type'].toString().contains('Contrat');
                  final date = DateTime.parse(doc['date']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getCardColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: NetworkImage(
                              widget.properties.firstWhere((p) => p.id == doc['propertyId'], orElse: () => widget.properties.first).imageUrl ?? 'https://via.placeholder.com/150'
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(doc['type'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc['propertyName'] ?? 'Bien inconnu', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38), fontSize: 11)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_red_eye_outlined, color: AppColors.getTextColor(context).withValues(alpha: 0.54), size: 20),
                            onPressed: () => _viewDocDetails(doc),
                            tooltip: 'Voir détails',
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: AppColors.accentGreen, size: 20),
                            onPressed: () async {
                              if (isContrat) {
                                await PdfGenerator.generateContractPdf(
                                  ownerName: context.read<AppProvider>().user?.displayName ?? 'Propriétaire',
                                  tenantName: doc['locataireName'] ?? 'Locataire',
                                  propertyTitle: doc['propertyName'],
                                  propertyAddress: doc['lieu'] ?? 'Cotonou, Bénin',
                                  price: (doc['price'] ?? 0).toString(),
                                );
                              } else {
                                await PdfGenerator.generateEtatDesLieuxPdf(
                                  propertyTitle: doc['propertyName'],
                                  evaluations: Map<String, String>.from(doc['evaluations'] ?? {}),
                                );
                              }
                            },
                            tooltip: 'Télécharger PDF',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  void _viewDocDetails(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text(doc['type'], style: TextStyle(color: AppColors.getTextColor(context))),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text('Bien : ${doc['propertyName']}', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.9), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (doc['locataireName'] != null)
                Text('Locataire : ${doc['locataireName']}', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              if (doc['evaluations'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Détails de l\'état des lieux :', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(doc['evaluations'] as Map).entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key.toString(), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 13)),
                            Text(e.value.toString(), style: const TextStyle(color: AppColors.accentBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
        ],
      ),
    );
  }
}

// ========== ABONNEMENT PREMIUM (CORRIGÉ) ==========
// ========== ABONNEMENT PREMIUM+ (OPTIMISÉ) ==========
class _SubscriptionTab extends StatelessWidget {
  final User? user;
  final VoidCallback onRefresh;
  const _SubscriptionTab({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();
    
    final bool isPremium = user!.subscriptionType == 'premium_plus';
    final DateTime? expiry = user!.subscriptionExpiry;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statut Actuel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: isPremium 
                ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF000000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: (isPremium ? Colors.orange : Colors.black).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(isPremium ? Icons.workspace_premium_rounded : Icons.star_outline_rounded, size: 48, color: AppColors.getTextColor(context)),
                ),
                const SizedBox(height: 20),
                Text(
                  isPremium ? 'PROPRIÉTAIRE PREMIUM+' : 'PACK GRATUIT', 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), letterSpacing: 1.2)
                ),
                if (isPremium && expiry != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'Expire le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(expiry)}', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  )
                ],
                if (!isPremium) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _showUpgradeDialog(context, user!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                    ),
                    child: const Text('Passer à Premium+ (25 000 FCFA)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Liste des avantages
          Text('Vos avantages exclusifs', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          _buildBenefitCard(
            context,
            'Mise en avant illimitée',
            'Vos biens apparaissent en tête des résultats de recherche pour attirer plus de locataires.',
            Icons.trending_up_rounded,
            AppColors.accentOrange,
          ),
          _buildBenefitCard(
            context,
            'Statistiques avancées',
            'Visualisez l\'évolution des vues et des candidatures sur vos biens avec des graphiques détaillés.',
            Icons.analytics_rounded,
            AppColors.accentBlue,
          ),
          _buildBenefitCard(
            context,
            'Support Prioritaire',
            'Vos demandes sont traitées en priorité par notre équipe technique 24h/24.',
            Icons.support_agent_rounded,
            AppColors.accentPurple,
          ),
          _buildBenefitCard(
            context,
            'Commission Réduite',
            'Bénéficiez d\'une commission de seulement 3% (au lieu de 5%) sur toutes vos transactions.',
            Icons.savings_rounded,
            AppColors.accentGreen,
          ),

          const SizedBox(height: 32),
          
          if (isPremium)
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Votre abonnement est géré par l\'administration.'))),
              icon: const Icon(Icons.info_outline),
              label: const Text('Gérer mon abonnement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.24)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(BuildContext context, String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, User currentUser) {
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
            Text(
              'Paiement Sécurisé FedaPay',
              style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Vous allez procéder au paiement de votre abonnement Premium+ pour un montant de 25 000 FCFA via Mobile Money ou Carte Bancaire.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Fermer le bottom sheet
                _processPremiumPayment(context, currentUser);
              },
              icon: const Icon(Icons.payment),
              label: const Text('Payer 25 000 FCFA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _processPremiumPayment(BuildContext context, User currentUser) {
    // Afficher l'indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
    );

    Future.delayed(const Duration(seconds: 3), () async {
      if (!context.mounted) return;
      Navigator.pop(context); // Fermer le chargement

      // Mettre à jour la base de données
      await DatabaseHelper().upgradeSubscription(currentUser.id, 'premium_plus', 1);
      
      // Ajouter dans les revenus globaux
      await DatabaseHelper().addCommission({
        'type': 'Abonnement',
        'montant': 25000,
        'description': 'Abonnement Premium+ Propriétaire #${currentUser.id}',
      });

      onRefresh(); // Rafraîchir l'écran

      if (!context.mounted) return;
      
      // Afficher le dialogue de succès
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 60),
              const SizedBox(height: 16),
              Text('Bienvenue dans Premium+', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Votre abonnement a été activé avec succès. Vous bénéficiez désormais de tous les avantages Premium+.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
                child: const Text('Super !'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ========== SERVICES PARTENAIRES ==========
// ========== SERVICES PARTENAIRES (AMÉLIORÉ) ==========
class _PartnersTab extends StatefulWidget {
  final int userId;
  const _PartnersTab({required this.userId});

  @override
  State<_PartnersTab> createState() => _PartnersTabState();
}

class _PartnersTabState extends State<_PartnersTab> {
  int _activeSubTab = 0; // 0: Annuaire, 1: Mes Demandes

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sous-navigation
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _buildSubTabButton(0, 'Annuaire', Icons.contact_phone_rounded),
              const SizedBox(width: 12),
              _buildSubTabButton(1, 'Mes Demandes', Icons.history_rounded),
            ],
          ),
        ),
        
        Expanded(
          child: _activeSubTab == 0 ? _buildDirectory() : _buildMyRequests(),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isActive = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentOrange : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? AppColors.accentOrange : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white54),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getAllPartners(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final partners = snapshot.data!.cast<Map<String, dynamic>>();
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: partners.length,
          itemBuilder: (context, index) {
            final p = partners[index];
            return _buildPartnerCard(p);
          },
        );
      },
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> p) {
    final IconData categoryIcon = _getIconForType(p['type']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(categoryIcon, color: AppColors.accentBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(p['service'], style: const TextStyle(color: AppColors.accentOrange, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(p['description'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ActionButtonWidget(
                  label: 'Contacter',
                  icon: Icons.chat_outlined,
                  variant: ButtonVariant.secondary,
                  onPressed: () => _showContactOptions(p),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionButtonWidget(
                  label: 'Demander',
                  icon: Icons.send_rounded,
                  variant: ButtonVariant.primary,
                  onPressed: () => _showServiceRequestForm(p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getServiceRequestsForUser(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!;
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu_rounded, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text('Aucune demande effectuée', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests.reversed.toList()[index];
            final status = r['status'] ?? 'en_attente';
            final color = status == 'acceptee' ? AppColors.accentGreen : (status == 'refusee' ? AppColors.accentRed : AppColors.accentOrange);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.getCardColor(context), borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r['partnerName'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['serviceType'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(r['date'])), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38), fontSize: 11)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
                  child: Text(
                    status == 'acceptee' ? 'Acceptée' : (status == 'refusee' ? 'Refusée' : 'En attente'),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'moving': return Icons.local_shipping_rounded;
      case 'legal': return Icons.gavel_rounded;
      case 'craft': return Icons.handyman_rounded;
      case 'payment': return Icons.payments_rounded;
      default: return Icons.business_center_rounded;
    }
  }

  void _showContactOptions(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contacter ${p['name']}', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.accentGreen),
              title: Text('Appeler', style: TextStyle(color: AppColors.getTextColor(context))),
              subtitle: Text(p['contact'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
              onTap: () {
                Navigator.pop(context);
                ExternalLauncher.launchCall(p['contact']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accentBlue),
              title: Text('WhatsApp', style: TextStyle(color: AppColors.getTextColor(context))),
              onTap: () {
                Navigator.pop(context);
                ExternalLauncher.launchWhatsApp(p['contact'], 'Bonjour ${p['name']}, je vous contacte via HomeConnect pour vos services.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.accentOrange),
              title: Text('Email', style: TextStyle(color: AppColors.getTextColor(context))),
              subtitle: Text(p['email'] ?? ''),
              onTap: () {
                Navigator.pop(context);
                ExternalLauncher.launchEmail(p['email'] ?? '', subject: 'Demande de service via HomeConnect');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceRequestForm(Map<String, dynamic> p) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Demande de service : ${p['name']}', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Décrivez brièvement votre besoin (devis, réparation, etc.)', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Ex: Je souhaite un devis pour un déménagement de Cotonou à Porto-Novo...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.2), fontSize: 13),
                fillColor: Colors.white.withValues(alpha: 0.05),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54)))),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty) return;
              await DatabaseHelper().addServiceRequest({
                'userId': widget.userId,
                'partnerId': p['id'],
                'partnerName': p['name'],
                'serviceType': p['service'],
                'message': messageController.text,
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée avec succès !'), backgroundColor: AppColors.accentGreen));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}

// ========== REPORTS TAB (PLAINTES) ==========
class _ReportsTab extends StatefulWidget {
  final User? user;
  const _ReportsTab({required this.user});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
        }

        final reports = provider.reports;

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 80, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text('Aucune plainte', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Vous n\'avez aucun litige en cours.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadReportsAgainstOwner(widget.user!.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(context, report, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildReportCard(BuildContext context, Report report, ReportProvider provider) {
    final statusColor = report.status == ReportStatus.open ? AppColors.accentRed :
                        report.status == ReportStatus.inReview ? AppColors.accentOrange : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(report.status.toString().split('.').last.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(report.title, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Motif: ${report.typeLabel}', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Text(report.description, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60), fontSize: 14)),
          const SizedBox(height: 16),
          
          if (report.ownerReply == null && report.status != ReportStatus.resolved)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReplyDialog(context, report, provider),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('Répondre à la plainte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (report.ownerReply != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.format_quote, color: AppColors.accentOrange, size: 16), SizedBox(width: 8), Text('Votre réponse :', style: TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 12))]),
                  const SizedBox(height: 8),
                  Text(report.ownerReply!, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context, Report report, ReportProvider provider) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Votre réponse', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cette réponse sera visible par l\'équipe de modération.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              maxLines: 4,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Expliquez votre version des faits...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.30)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54)))),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;
              Navigator.pop(context);
              final success = await provider.addOwnerReply(report.id, replyController.text.trim());
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Réponse envoyée avec succès', style: TextStyle(color: AppColors.getTextColor(context))), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: Text('Envoyer', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );
  }
}

// ========== AIDE TAB ==========
class _AideTab extends StatefulWidget {
  const _AideTab();

  @override
  State<_AideTab> createState() => _AideTabState();
}

class _AideTabState extends State<_AideTab> {
  final _emailCtrl = TextEditingController();
  final _sujetCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sujetCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportProvider = context.watch<SupportProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support & Assistance',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Besoin d\'aide pour gérer vos biens ou vos documents ? Nos experts sont là.',
            style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // FAQ Sections
          ...supportProvider.categories.map((cat) => _buildCategory(cat)),
          
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contactez l\'administration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
              ),
              ElevatedButton.icon(
                onPressed: () => ExternalLauncher.launchWhatsApp('22990000000', 'Bonjour, j\'ai besoin d\'aide depuis mon espace Propriétaire.'),
                icon: const Icon(Icons.chat_bubble, size: 16),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Couleur WhatsApp
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildTextField(_emailCtrl, 'Votre email de contact', Icons.email_outlined),
                const SizedBox(height: 12),
                _buildTextField(_sujetCtrl, 'Sujet du message', Icons.topic_outlined),
                const SizedBox(height: 12),
                _buildTextField(_messageCtrl, 'Décrivez votre demande...', Icons.message_outlined, maxLines: 4),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: supportProvider.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: supportProvider.isLoading
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTextColor(context)))
                        : Text('Envoyer le message', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.accentOrange),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.white70,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildCategory(HelpCategory cat) {
    return ExpansionTile(
      title: Text(cat.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(cat.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      children: cat.items.map((item) => _buildFAQItem(item)).toList(),
    );
  }

  Widget _buildFAQItem(FAQItem item) {
    return ListTile(
      title: Text(item.question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(item.reponse, style: const TextStyle(fontSize: 13, color: Colors.grey)),
    );
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.isEmpty || _sujetCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs')));
      return;
    }

    final success = await context.read<SupportProvider>().submitContact(
      email: _emailCtrl.text.trim(),
      sujet: _sujetCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      userRole: 'proprietaire',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<SupportProvider>().successMessage), backgroundColor: AppColors.accentGreen),
      );
      _emailCtrl.clear();
      _sujetCtrl.clear();
      _messageCtrl.clear();
    }
  }
}

// ========== CHAT AVEC ADMIN (Style WhatsApp Premium) ==========
class _ChatAdminProprietaireTab extends StatefulWidget {
  final User? user;
  const _ChatAdminProprietaireTab({required this.user});

  @override
  State<_ChatAdminProprietaireTab> createState() => _ChatAdminProprietaireTabState();
}

class _ChatAdminProprietaireTabState extends State<_ChatAdminProprietaireTab> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _chatRefreshTimer;
  bool _chatIsTyping = false;
  int _adminId = 1;

  @override
  void initState() {
    super.initState();
    _initAdminId();
    _loadMessages();
    _chatRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
    final currentUserId = widget.user?.id ?? 0;
    if (currentUserId == 0) return;
    context.read<AdvancedChatProvider>().loadAdminMessages(currentUserId);
  }

  @override
  void dispose() {
    _chatRefreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    final currentUserId = widget.user?.id ?? 0;
    if (currentUserId == 0) return;
    
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
    final currentUserId = widget.user?.id ?? 0;
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/chat_bg.png'), 
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

                if (messages.isEmpty) {
                  return Center(child: Text('Aucun message. Commencez la discussion avec l\'admin.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38))));
                }

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
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentOrange,
                child: Icon(Icons.admin_panel_settings, color: AppColors.accentOrange),
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
                Text(_chatIsTyping ? 'En train d\'écrire...' : 'En ligne', style: TextStyle(color: _chatIsTyping ? AppColors.accentOrange : Colors.green, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.videocam_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => _showCallSimulation('vidéo')),
          IconButton(icon: Icon(Icons.call_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.70)), onPressed: () => _showCallSimulation('audio')),
        ],
      ),
    );
  }

  void _showCallSimulation(String type) {
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
    List<TextSpan> spans = [];
    const color = Colors.black87;
    text.split(' ').forEach((word) {
      if (word.startsWith('*') && word.endsWith('*') && word.length > 2) {
        spans.add(TextSpan(text: '${word.substring(1, word.length - 1)} ', style: const TextStyle(fontWeight: FontWeight.bold, color: color)));
      } else if (word.startsWith('_') && word.endsWith('_') && word.length > 2) {
        spans.add(TextSpan(text: '${word.substring(1, word.length - 1)} ', style: const TextStyle(fontStyle: FontStyle.italic, color: color)));
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
              child: TextField(
                controller: _msgController,
                onChanged: (v) => setState(() {}),
                style: TextStyle(color: AppColors.getTextColor(context)),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38)),
                  border: InputBorder.none,
                ),
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
    setState(() => _chatIsTyping = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enregistrement en cours... (simulation)'), duration: Duration(seconds: 2)),
    );
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final currentUserId = widget.user?.id ?? 0;
      if (currentUserId == 0) return;
      await context.read<AdvancedChatProvider>().sendVoiceNote(
        senderId: currentUserId,
        receiverId: 1, // Admin ID
        duration: '0:05',
        filePath: 'simulation_audio.aac',
      );
      setState(() => _chatIsTyping = false);
      _scrollToBottom();
    }
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
        final currentUserId = widget.user?.id ?? 0;
        if (currentUserId == 0) return;
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