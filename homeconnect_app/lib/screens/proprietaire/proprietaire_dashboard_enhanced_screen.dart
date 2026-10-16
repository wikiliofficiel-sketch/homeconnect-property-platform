import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/property_provider.dart';
import '../../providers/application_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/evaluation_provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/report_provider.dart';
import '../../models/report_sanction_models.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../models/property.dart';
import 'package:intl/intl.dart';

class ProprietaireDashboardEnhancedScreen extends StatefulWidget {
  const ProprietaireDashboardEnhancedScreen({super.key});

  @override
  State<ProprietaireDashboardEnhancedScreen> createState() =>
      _ProprietaireDashboardEnhancedScreenState();
}

class _ProprietaireDashboardEnhancedScreenState
    extends State<ProprietaireDashboardEnhancedScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    
    // Charger les données à l'initialisation
    Future.microtask(() async {
      if (!mounted) return;
      final appProvider = context.read<AppProvider>();
      await appProvider.checkAuthStatus();
      if (!mounted) return;
      final user = appProvider.user;
      if (user != null) {
        context.read<PropertyProvider>().loadPropertiesByOwner(user.id);
        context.read<ApplicationProvider>().loadApplicationsByProperty(1);
        context.read<SubscriptionProvider>().loadCurrentSubscription(user.id);
        context.read<EvaluationProvider>().loadEvaluationsReceived(user.id);
        context.read<NotificationProvider>().loadNotifications(user.id);
        context.read<ReportProvider>().loadReportsAgainstOwner(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: AppBar(
        title: Text(appProvider.translate('dashboard'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: AppColors.getTextColor(context)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications : voir profil ou utiliser le panel admin pour le moment')));
                    },
                  ),
                  if (notifProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('${notifProvider.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(appProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppColors.getTextColor(context)),
            onPressed: () => appProvider.toggleDarkMode(),
          ),
          _buildLanguagePicker(context, appProvider),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: AppColors.getTextColor(context).withValues(alpha: 0.5),
          indicatorColor: AppColors.accentOrange,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard), text: appProvider.translate('overview')),
            Tab(icon: const Icon(Icons.domain), text: appProvider.translate('properties')),
            Tab(icon: const Icon(Icons.mail), text: appProvider.translate('applications')),
            Tab(icon: const Icon(Icons.description), text: appProvider.translate('contracts')),
            Tab(icon: const Icon(Icons.card_membership), text: appProvider.translate('subscriptions')),
            Tab(icon: const Icon(Icons.handshake), text: appProvider.translate('partner_services')),
            Tab(icon: const Icon(Icons.report_problem), text: appProvider.translate('complaints')),
          ],
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _PropertiesTab(),
          _ApplicationsTab(),
          _ContractsTab(),
          _SubscriptionTab(),
          _PartnersTab(),
          _ReportsTab(),
        ],
      ),
    );
  }

  Widget _buildLanguagePicker(BuildContext context, AppProvider provider) {
    return PopupMenuButton<Locale>(
      icon: Icon(Icons.language, color: AppColors.getTextColor(context)),
      onSelected: (locale) => provider.setLocale(locale),
      itemBuilder: (context) => [
        const PopupMenuItem(value: Locale('fr'), child: Text('Français')),
        const PopupMenuItem(value: Locale('en'), child: Text('English')),
        const PopupMenuItem(value: Locale('fon'), child: Text('Fon')),
      ],
    );
  }
}

// ============================================================
// TAB 1: APERÇU (Overview)
// ============================================================
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KYC Verification Card
          if (user != null && user.role == 'proprietaire') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: user.isVerified ? AppColors.accentGreen.withValues(alpha: 0.1) : AppColors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: user.isVerified ? AppColors.accentGreen.withValues(alpha: 0.3) : AppColors.accentOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user.isVerified ? Icons.verified_rounded : Icons.warning_amber_rounded,
                        color: user.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.isVerified ? appProvider.translate('certified_account') : appProvider.translate('certification_required'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: user.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.isVerified
                        ? appProvider.translate('identity_verified_desc')
                        : appProvider.translate('identity_not_verified_desc'),
                    style: TextStyle(
                      color: AppColors.getTextColor(context).withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/verification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(user.isVerified ? appProvider.translate('see_kyc_folder') : appProvider.translate('add_kyc_folder')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Cartes de statistiques
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.home,
                label: appProvider.translate('total_properties'),
                value: context.watch<PropertyProvider>().properties.length.toString(),
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.check_circle,
                label: appProvider.translate('active_properties'),
                value: context.watch<PropertyProvider>().totalActiveProperties.toString(),
                color: Colors.green,
              ),
              _StatCard(
                icon: Icons.person,
                label: appProvider.translate('applications'),
                value: context.watch<ApplicationProvider>().applications.length.toString(),
                color: Colors.orange,
              ),
              _StatCard(
                icon: Icons.visibility,
                label: appProvider.translate('total_views'),
                value: context.watch<PropertyProvider>().totalViews.toString(),
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Évaluation utilisateur
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.read<AppProvider>().translate('trust_rating'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context
                              .watch<EvaluationProvider>()
                              .getAverageRating(1)
                              .toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        Text(
                          '${context.watch<EvaluationProvider>().getRatingCount(1)} ${appProvider.translate('evaluations')}', style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Abonnement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.read<AppProvider>().translate('subscription_status'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                if (context.watch<SubscriptionProvider>().isPremiumActive)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Chip(
                        label: Text('Premium+'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.watch<SubscriptionProvider>().daysRemaining} ${appProvider.translate('days_remaining')}', style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(context.read<AppProvider>().translate('free_plan')),
                        backgroundColor: Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _showUpgradeDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        child: Text(appProvider.translate('upgrade_premium')),
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

  void _showUpgradeDialog(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appProvider.translate('upgrade_premium')),
        content: const Text(
          'Obtenez une mise en avant illimitée, des statistiques avancées et une commission réduite à 3%.\n\n25 000 FCFA/mois',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appProvider.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text(appProvider.translate('subscribe')),
          ),
        ],
      ),
    );
  }
}

// Bannière de limite d'abonnement (partagée entre les onglets)
Widget _buildSubscriptionBanner(
  BuildContext context,
  String planKey,
  int published,
  int? maxBiens,
  bool canAdd,
) {
  final planLabels = {'free': 'Gratuit', 'starter': 'Starter', 'pro': 'Pro'};
  final planLabel = planLabels[planKey] ?? planKey;
  final isPro = planKey == 'pro';
  final progressValue = (isPro || maxBiens == null) ? 1.0 : (published / maxBiens).clamp(0.0, 1.0);
  final progressColor = canAdd ? AppColors.accentGreen : AppColors.accentRed;

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.getCardColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: canAdd ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.accentOrange.withValues(alpha: 0.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(Icons.card_membership_rounded,
                  size: 16,
                  color: isPro ? AppColors.accentPurple : AppColors.accentBlue),
              const SizedBox(width: 6),
              Text('Plan $planLabel',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                      fontSize: 13)),
            ]),
            if (!isPro)
              Text(
                '$published / ${maxBiens ?? "∞"} biens',
                style: TextStyle(
                    color: AppColors.getTextColor(context).withValues(alpha: 0.6),
                    fontSize: 12),
              ),
          ],
        ),
        if (!isPro && maxBiens != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: AppColors.getTextColor(context).withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
        ],
        if (!canAdd) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              icon: const Icon(Icons.upgrade_rounded, size: 16),
              label: const Text('Passer au plan supérieur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// ============================================================
// TAB 2: BIENS (Properties)
// ============================================================
class _PropertiesTab extends StatelessWidget {
  const _PropertiesTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final properties = context.watch<PropertyProvider>().properties;
    final sub = context.watch<SubscriptionProvider>();
    final published = properties.length;
    final maxBiens = sub.maxProperties;
    final canAdd = sub.canAdd ?? true;
    final planKey = sub.planKey;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carte limite abonnement
          _buildSubscriptionBanner(context, planKey, published, maxBiens, canAdd),
          const SizedBox(height: 12),

          // Bouton Ajouter bien
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final user = context.read<AppProvider>().user;
                Navigator.pushNamed(context, '/add-property').then((_) {
                  if (context.mounted && user != null) {
                    context.read<PropertyProvider>().loadPropertiesByOwner(user.id);
                  }
                });
              },
              icon: const Icon(Icons.add),
              label: Text(appProvider.translate('add_property_btn')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: canAdd ? Colors.orange : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Liste des propriétés
          if (properties.isEmpty)
            Center(
              child: Text(
                appProvider.translate('no_properties_published'),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                return _PropertyCard(property: property);
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 3: CANDIDATURES (Applications)
// ============================================================
class _ApplicationsTab extends StatelessWidget {
  const _ApplicationsTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final applications = context.watch<ApplicationProvider>().applications;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filtres
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _FilterChip(
                label: appProvider.translate('pending'),
                count: context
                    .watch<ApplicationProvider>()
                    .applications
                    .where((a) => a.status == 'pending')
                    .length,
              ),
              _FilterChip(
                label: appProvider.translate('approved'),
                count: context
                    .watch<ApplicationProvider>()
                    .applications
                    .where((a) => a.status == 'approved')
                    .length,
              ),
              _FilterChip(
                label: appProvider.translate('rejected'),
                count: context
                    .watch<ApplicationProvider>()
                    .applications
                    .where((a) => a.status == 'rejected')
                    .length,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Liste des candidatures
          if (applications.isEmpty)
            Center(
              child: Text(appProvider.translate('no_notifications'))
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return _ApplicationCard(application: app);
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 4: CONTRATS (Contracts)
// ============================================================
class _ContractsTab extends StatelessWidget {
  const _ContractsTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appProvider.translate('contract_management'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.blue),
                  title: Text(appProvider.translate('generate_contract')),
                  subtitle: Text(appProvider.translate('create_pdf_contract')),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => _showContractDialog(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.assignment, color: Colors.green),
                  title: Text(appProvider.translate('inventory')),
                  subtitle: Text(appProvider.translate('inventory_desc')),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${appProvider.translate('active_contracts')}: 0', style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showContractDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<AppProvider>().translate('generate_contract')),
        content: Text(
          context.read<AppProvider>().translate('select_property_contract'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.read<AppProvider>().translate('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(context.read<AppProvider>().translate('generate')),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 5: ABONNEMENT (Subscription)
// ============================================================
class _SubscriptionTab extends StatelessWidget {
  const _SubscriptionTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final subscription = context.watch<SubscriptionProvider>().currentSubscription;
    final isPremium = context.watch<SubscriptionProvider>().isPremiumActive;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan actuel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPremium ? Colors.amber : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPremium ? 'Premium+' : 'Plan Gratuit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text(isPremium ? appProvider.translate('active') : appProvider.translate('inactive')),
                      backgroundColor: isPremium ? Colors.green : Colors.grey,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isPremium && subscription != null) ...[
                  Text(
                    '${context.watch<SubscriptionProvider>().daysRemaining} ${appProvider.translate('days_remaining')}',
                    style: const TextStyle(fontSize: 14, color: Colors.amber),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (context.watch<SubscriptionProvider>().daysRemaining / 30).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ] else
                  Text(
                    appProvider.translate('basic_features_access'),
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Avantages
          Text(
            appProvider.translate('premium_advantages'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _AdvantageItem(
            icon: Icons.star,
            title: appProvider.translate('unlimited_highlight'),
            description: appProvider.translate('highlight_visibility_desc'),
          ),
          _AdvantageItem(
            icon: Icons.bar_chart,
            title: appProvider.translate('advanced_stats'),
            description: appProvider.translate('advanced_stats_desc'),
          ),
          _AdvantageItem(
            icon: Icons.percent,
            title: appProvider.translate('reduced_commission'),
            description: appProvider.translate('commission_desc'),
          ),
          _AdvantageItem(
            icon: Icons.headset_mic,
            title: appProvider.translate('priority_support'),
            description: appProvider.translate('priority_support_desc'),
          ),
          const SizedBox(height: 24),

          // Bouton d'action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPremium
                  ? () => _showRenewDialog(context)
                  : () => _showUpgradeDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.all(16),
              ),
              child: Text(isPremium ? appProvider.translate('renew') : appProvider.translate('upgrade_premium')),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<AppProvider>().translate('upgrade_premium')),
        content: const Text(
          '25 000 FCFA/mois\n\n'
          '✓ Mise en avant illimitée\n'
          '✓ Statistiques avancées\n'
          '✓ Commission réduite (3%)\n'
          '✓ Support prioritaire',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.read<AppProvider>().translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text(context.read<AppProvider>().translate('subscribe')),
          ),
        ],
      ),
    );
  }

  void _showRenewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<AppProvider>().translate('renew_subscription')),
        content: Text(context.read<AppProvider>().translate('renew_one_month_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.read<AppProvider>().translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text(context.read<AppProvider>().translate('renew')),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 6: PARTENAIRES (Partners)
// ============================================================
class _PartnersTab extends StatelessWidget {
  const _PartnersTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appProvider.translate('partner_services'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appProvider.translate('access_verified_services'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _PartnerServiceItem(
            icon: Icons.local_shipping,
            title: appProvider.translate('moving_transport'),
            subtitle: appProvider.translate('secure_moving_desc'),
          ),
          _PartnerServiceItem(
            icon: Icons.credit_card,
            title: appProvider.translate('secure_payments'),
            subtitle: appProvider.translate('rent_management_desc'),
          ),
          _PartnerServiceItem(
            icon: Icons.balance,
            title: appProvider.translate('legal_services'),
            subtitle: appProvider.translate('legal_advice_desc'),
          ),
          _PartnerServiceItem(
            icon: Icons.handyman,
            title: appProvider.translate('handyman_platform'),
            subtitle: appProvider.translate('small_works_desc'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGETS RÉUTILISABLES
// ============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image removed as requested by user
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        property.titre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${property.prix} FCFA',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      property.lieu,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${property.views} vues', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          onPressed: () => Navigator.pushNamed(context, '/property/${property.id}'),
                          color: AppColors.accentBlue,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.delete_outline,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer'),
                                content: const Text('Voulez-vous vraiment supprimer ce bien ?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              context.read<PropertyProvider>().deleteProperty(property.id);
                            }
                          },
                          color: AppColors.accentRed,
                        ),
                      ],
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({required this.icon, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final dynamic application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Candidature #ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text(application.status ?? 'pending'),
                backgroundColor: _getStatusColor(application.status),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (application.status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  child: Text(context.read<AppProvider>().translate('reject')),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(context.read<AppProvider>().translate('approve')),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;

  const _FilterChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label ($count)'),
      onSelected: (_) {},
      labelStyle: const TextStyle(fontSize: 11),
    );
  }
}

class _AdvantageItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AdvantageItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerServiceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PartnerServiceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward, size: 16),
        onTap: () {},
      ),
    );
  }
}
// ============================================================
// TAB 7: SIGNALEMENTS (Reports)
// ============================================================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: Text('Veuillez vous connecter'));

    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        
        final reports = provider.reports;
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.accentGreen.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                const Text('Aucune plainte à signaler', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadReportsAgainstOwner(user.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final r = reports[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: r.ownerReply == null ? AppColors.accentRed.withValues(alpha: 0.3) : AppColors.borderColor),
                ),
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
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(r.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    if (r.ownerReply != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.accentGreen.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.1))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Votre réponse :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                            const SizedBox(height: 4),
                            Text(r.ownerReply!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _showReplyDialog(context, r.id, provider),
                        icon: const Icon(Icons.reply, size: 16),
                        label: const Text('Répondre à cette plainte'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
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

  void _showReplyDialog(BuildContext context, int reportId, ReportProvider provider) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Répondre à la plainte', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: replyCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Votre explication ou solution...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.isEmpty) return;
              final success = await provider.addOwnerReply(reportId, replyCtrl.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Réponse envoyée' : 'Erreur lors de l\'envoi')));
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}