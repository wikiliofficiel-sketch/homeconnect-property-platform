import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/application_provider.dart';
import '../../providers/locataire_provider.dart';
import '../../providers/evaluation_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/support_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/design_widgets.dart';
import '../../models/extended_models.dart';
import '../../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LocataireDashboardEnhancedScreen extends StatefulWidget {
  const LocataireDashboardEnhancedScreen({super.key});

  @override
  State<LocataireDashboardEnhancedScreen> createState() =>
      _LocataireDashboardEnhancedScreenState();
}

class _LocataireDashboardEnhancedScreenState extends State<LocataireDashboardEnhancedScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      context.read<CommunityProvider>().loadPosts();
      context.read<SupportProvider>().loadSupportContent(role: 'locataire');
      context.read<AppProvider>().refreshProperties();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppProvider>().refreshProperties();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.white)),
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

  Future<void> _showNotificationsDialog(BuildContext context, NotificationProvider notifProvider) async {
    final user = context.read<AppProvider>().user;
    if (user != null) {
      await notifProvider.markAllAsRead(user.id);
    }
    if (!context.mounted) return;
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
            Padding(padding: const EdgeInsets.all(20), child: Text(context.read<AppProvider>().translate('notifications'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))),
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
                    return ListTile(
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_active, color: AppColors.accentBlue)),
                      title: Text(n['title'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
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
          IconButton(
            icon: Icon(appProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppColors.getTextColor(context)),
            onPressed: () => appProvider.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.getTextColor(context),
            onPressed: () => _showNotificationsDialog(context, context.read<NotificationProvider>()),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            color: AppColors.getTextColor(context),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.accentRed),
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: AppColors.getTextColor(context).withValues(alpha: 0.5),
          indicatorColor: AppColors.accentOrange,
          tabs: [
            Tab(icon: const Icon(Icons.home), text: appProvider.translate('overview')),
            Tab(icon: const Icon(Icons.search), text: appProvider.translate('search')),
            Tab(icon: const Icon(Icons.mail), text: appProvider.translate('applications')),
            Tab(icon: const Icon(Icons.calendar_month), text: appProvider.translate('visits')),
            Tab(icon: const Icon(Icons.favorite), text: appProvider.translate('favorites')),
            Tab(icon: const Icon(Icons.payments), text: appProvider.translate('payments')),
            Tab(icon: const Icon(Icons.star), text: appProvider.translate('evaluations')),
            Tab(icon: const Icon(Icons.forum), text: appProvider.translate('community')),
            Tab(icon: const Icon(Icons.help), text: appProvider.translate('help')),
          ],
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AccueilTab(),
          _RechercheTab(),
          _CandidaturesTab(),
          _VisitesTab(),
          _FavorisTab(),
          _PaiementsTab(),
          _EvaluationsTab(),
          _CommunauteTab(),
          _AideTab(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: ACCUEIL
// ============================================================
class _AccueilTab extends StatelessWidget {
  const _AccueilTab();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            '${appProvider.translate('welcome')}!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
          ),
          const SizedBox(height: 4),
          Text(
            appProvider.translate('search_placeholder'),
            style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Stats Cards
          _buildStatsGrid(context),
          const SizedBox(height: 24),

          // Biens Recommandés
          Text(
            appProvider.translate('recommended_properties'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
          ),
          const SizedBox(height: 12),
          _buildPropertyCarousel(context),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer2<ApplicationProvider, AppProvider>(
      builder: (context, applicationProvider, appState, _) {
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          childAspectRatio: 1.5,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCardSmall(
              label: appState.translate('applications'),
              value: '${applicationProvider.applications.length}',
              color: AppColors.accentBlue,
            ),
            _StatCardSmall(
              label: appState.translate('favorites'),
              value: '${appState.favorites.length}',
              color: AppColors.accentRed,
            ),
            _StatCardSmall(
              label: appState.translate('visits'),
              value: '${applicationProvider.scheduledVisits.length}',
              color: AppColors.accentGreen,
            ),
            _StatCardSmall(
              label: appState.translate('confidence'),
              value: '★ 4.5',
              color: AppColors.accentYellow,
            ),
          ],
        );
      },
    );
  }


  Widget _buildPropertyCarousel(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          final properties = appProvider.properties.take(5).toList();
          if (properties.isEmpty) {
            return const Center(child: Text('Aucun bien disponible'));
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final prop = properties[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: SafeImage(
                            url: prop.imageUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              height: 100,
                              color: AppColors.accentOrange.withValues(alpha: 0.2),
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  prop.titre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${prop.prix} FCFA',
                                style: const TextStyle(
                                  color: AppColors.accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Consumer<AppProvider>(
                        builder: (context, provider, _) {
                          final isFavorite = provider.favorites.any((f) => f.id == prop.id);
                          return GestureDetector(
                            onTap: () async {
                              if (isFavorite) {
                                await provider.removeFavorite(prop.id);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré des favoris')));
                              } else {
                                await provider.addFavorite(prop);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté aux favoris'), backgroundColor: AppColors.accentRed));
                              }
                            },
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? AppColors.accentRed : Colors.white,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCardSmall extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCardSmall({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: RECHERCHE
// ============================================================
class _RechercheTab extends StatefulWidget {
  const _RechercheTab();

  @override
  State<_RechercheTab> createState() => _RechercheTabState();
}

class _RechercheTabState extends State<_RechercheTab> {
  late SearchProvider _searchProvider;
  String? _selectedVille;
  String? _selectedType;
  RangeValues _priceRange = const RangeValues(0, 10000000);
  RangeValues _piecesRange = const RangeValues(0, 10);
  bool _verifiedOnly = false;
  bool _photosOnly = false;

  @override
  void initState() {
    super.initState();
    _searchProvider = context.read<SearchProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres
          const Text(
            'Filtres de recherche',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Ville
          _buildDropdown(
            'Ville',
            _selectedVille,
            _searchProvider.villes,
            (value) {
              setState(() => _selectedVille = value);
            },
          ),
          const SizedBox(height: 16),

          // Type de bien
          _buildDropdown(
            'Type de bien',
            _selectedType,
            _searchProvider.typesBien,
            (value) {
              setState(() => _selectedType = value);
            },
          ),
          const SizedBox(height: 16),

          // Price Range
          _buildRangeSlider(
            'Budget: ${(_priceRange.start / 1000000).toStringAsFixed(1)}M - ${(_priceRange.end / 1000000).toStringAsFixed(1)}M FCFA',
            _priceRange,
            0,
            10000000,
            (range) {
              setState(() => _priceRange = range);
            },
          ),
          const SizedBox(height: 16),

          // Pieces Range
          _buildRangeSlider(
            'Pièces: ${_piecesRange.start.toInt()} - ${_piecesRange.end.toInt()}',
            _piecesRange,
            0,
            10,
            (range) {
              setState(() => _piecesRange = range);
            },
          ),
          const SizedBox(height: 16),

          // Checkboxes
          CheckboxListTile(
            title: const Text('Biens vérifiés uniquement'),
            value: _verifiedOnly,
            onChanged: (value) {
              setState(() => _verifiedOnly = value ?? false);
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: const Text('Avec photos uniquement'),
            value: _photosOnly,
            onChanged: (value) {
              setState(() => _photosOnly = value ?? false);
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedVille = null;
                      _selectedType = null;
                      _priceRange = const RangeValues(0, 10000000);
                      _piecesRange = const RangeValues(0, 10);
                      _verifiedOnly = false;
                      _photosOnly = false;
                    });
                    _searchProvider.resetFilters();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _searchProvider.searchProperties(
                      ville: _selectedVille,
                      typeBien: _selectedType,
                      prixMin: _priceRange.start.toInt(),
                      prixMax: _priceRange.end.toInt(),
                      piecesMin: _piecesRange.start.toInt(),
                      piecesMax: _piecesRange.end.toInt(),
                      verifiedOnly: _verifiedOnly,
                      photosOnly: _photosOnly,
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Results
          Consumer<SearchProvider>(
            builder: (context, searchProvider, _) {
              if (searchProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (searchProvider.searchResults.isEmpty) {
                return const Center(child: Text('Aucun résultat'));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchProvider.searchResults.length,
                itemBuilder: (context, index) {
                  final prop = searchProvider.searchResults[index];
                  return _PropertySearchItem(property: prop);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            hint: const Text('Sélectionner...'),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSlider(
    String label,
    RangeValues values,
    double min,
    double max,
    Function(RangeValues) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.accentOrange,
        ),
      ],
    );
  }
}

class _PropertySearchItem extends StatelessWidget {
  final dynamic property;

  const _PropertySearchItem({required this.property});

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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SafeImage(
              url: property.imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorWidget: Container(
                width: 80,
                height: 80,
                color: AppColors.accentOrange.withValues(alpha: 0.2),
                child: const Icon(Icons.image, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  property.lieu,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${property.prix} FCFA',
                      style: const TextStyle(
                        color: AppColors.accentOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${property.pieces} pièces', style: const TextStyle(fontSize: 11)),
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

// ============================================================
// TAB 3: CANDIDATURES
// ============================================================
class _CandidaturesTab extends StatelessWidget {
  const _CandidaturesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          if (appProvider.applications.isEmpty) {
            return const Center(child: Text('Aucune candidature'));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appProvider.applications.length,
            itemBuilder: (context, index) {
              final app = appProvider.applications[index];
              return _ApplicationStatusCard(application: app);
            },
          );
        },
      ),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  final dynamic application;

  const _ApplicationStatusCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final statusColor = application.status == 'approved'
        ? Colors.green
        : application.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Application', style: TextStyle(fontWeight: FontWeight.bold)),
              Chip(
                label: Text(application.status),
                backgroundColor: statusColor,
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (application.status == 'approved')
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today),
              label: const Text('Planifier une visite'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB: VISITES
// ============================================================
class _VisitesTab extends StatelessWidget {
  const _VisitesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          final visits = appProvider.scheduledVisits;
          
          if (visits.isEmpty) {
            return Center(child: Text('Aucune visite planifiée', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))));
          }

          final sortedVisits = List<ScheduledVisit>.from(visits);
          sortedVisits.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedVisits.length,
            itemBuilder: (context, index) {
              final v = sortedVisits[index];
              final visiteDate = v.scheduledDate;
              final isPast = visiteDate.isBefore(DateTime.now());
              
              // Trouver le titre du bien via AppProvider
              final properties = context.read<AppProvider>().properties;
              final matchingProps = properties.where((p) => p.id == v.propertyId);
              final propTitre = matchingProps.isNotEmpty ? matchingProps.first.titre : 'Bien inconnu';
              final propLieu = matchingProps.isNotEmpty ? matchingProps.first.lieu : '';
              
              final bienTitle = propTitre;
              final lieu = propLieu;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPast ? Colors.grey.withValues(alpha: 0.3) : AppColors.accentGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(bienTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
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
                    if (lieu.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(lieu, style: const TextStyle(color: Colors.grey)),
                    ],
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
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// TAB 4: FAVORIS
// ============================================================
class _FavorisTab extends StatelessWidget {
  const _FavorisTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          if (appProvider.favorites.isEmpty) {
            return const Center(child: Text('Aucun favori'));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appProvider.favorites.length,
            itemBuilder: (context, index) {
              final prop = appProvider.favorites[index];
              return _FavoritePropertyCard(property: prop);
            },
          );
        },
      ),
    );
  }
}

class _FavoritePropertyCard extends StatelessWidget {
  final dynamic property;

  const _FavoritePropertyCard({required this.property});

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
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(property.lieu, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                Text('${property.prix} FCFA',
                    style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () {
              context.read<AppProvider>().removeFavorite(property.id);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 5: PAIEMENTS
// ============================================================
class _PaiementsTab extends StatefulWidget {
  const _PaiementsTab();

  @override
  State<_PaiementsTab> createState() => _PaiementsTabState();
}

class _PaiementsTabState extends State<_PaiementsTab> {
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final user = context.read<AppProvider>().user;
      if (user != null) {
        context.read<TransactionProvider>().loadTransactions(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final transProvider = context.watch<TransactionProvider>();
    final user = app.user;

    if (user == null) return const Center(child: Text('Veuillez vous connecter'));

    final filteredTransactions = _filterType == 'all'
        ? transProvider.transactions
        : transProvider.transactions.where((t) => t.type == _filterType).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _PaymentActionCard(
                  title: app.translate('pay_rent'),
                  icon: Icons.home_work_outlined,
                  color: AppColors.accentOrange,
                  onTap: () => _showPaymentDialog(context, 'loyer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentActionCard(
                  title: app.translate('pay_service'),
                  icon: Icons.build_outlined,
                  color: AppColors.accentBlue,
                  onTap: () => _showPaymentDialog(context, 'service'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // History Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                app.translate('transaction_history'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _buildFilterChips(app),
            ],
          ),
          const SizedBox(height: 16),

          // History List
          if (transProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (filteredTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucune transaction trouvée',
                  style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                return _TransactionCard(transaction: filteredTransactions[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppProvider app) {
    return Row(
      children: [
        _FilterChip(
          label: app.translate('all'),
          isSelected: _filterType == 'all',
          onTap: () => setState(() => _filterType = 'all'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: app.translate('rent'),
          isSelected: _filterType == 'loyer',
          onTap: () => setState(() => _filterType = 'loyer'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: app.translate('service'),
          isSelected: _filterType == 'service',
          onTap: () => setState(() => _filterType = 'service'),
        ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, String type) async {
    final app = context.read<AppProvider>();
    final user = app.user;
    if (user == null) return;

    // Fetch relevant data (contracts for rent, service requests for service)
    final db = DatabaseHelper();
    List<Map<String, dynamic>> options = [];
    if (type == 'loyer') {
      options = await db.getContractsByTenant(user.id);
    } else {
      // Mock some service requests
      options = [
        {'id': 1, 'name': 'Déménagement Express', 'amount': 25000.0},
        {'id': 2, 'name': 'Réparation Plomberie', 'amount': 15000.0},
      ];
    }

    if (!context.mounted) return;
    if (options.isEmpty && type == 'loyer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun contrat de location actif trouvé.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _PaymentProcessDialog(type: type, options: options),
    );
  }
}

class _PaymentActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaymentActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentOrange : AppColors.getTextColor(context).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : AppColors.getTextColor(context).withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final isRent = transaction.type == 'loyer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isRent ? AppColors.accentOrange : AppColors.accentBlue).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRent ? Icons.home_work_outlined : Icons.build_outlined,
              color: isRent ? AppColors.accentOrange : AppColors.accentBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRent ? app.translate('rent') : app.translate('service'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Réf: ${transaction.reference}',
                  style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.4)),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateCreation),
                  style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.montant.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              _buildStatusBadge(context, app),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, AppProvider app) {
    Color color;
    String label;

    switch (transaction.statut) {
      case 'confirme':
        color = Colors.green;
        label = app.translate('confirmed');
        break;
      case 'en_attente':
        color = Colors.orange;
        label = app.translate('pending');
        break;
      case 'echoue':
        color = Colors.red;
        label = app.translate('failed');
        break;
      case 'rembourse':
        color = Colors.blue;
        label = app.translate('refunded');
        break;
      default:
        color = Colors.grey;
        label = transaction.statut;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PaymentProcessDialog extends StatefulWidget {
  final String type;
  final List<Map<String, dynamic>> options;

  const _PaymentProcessDialog({required this.type, required this.options});

  @override
  State<_PaymentProcessDialog> createState() => _PaymentProcessDialogState();
}

class _PaymentProcessDialogState extends State<_PaymentProcessDialog> {
  int? _selectedIndex;
  String _method = 'mobile_money';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final transProvider = context.read<TransactionProvider>();

    return AlertDialog(
      backgroundColor: AppColors.getCardColor(context),
      title: Text(widget.type == 'loyer' ? app.translate('pay_rent') : app.translate('pay_service')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.translate('type'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: _selectedIndex,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('Sélectionner...', style: TextStyle(fontSize: 12)),
                items: List.generate(widget.options.length, (index) {
                  final opt = widget.options[index];
                  final label = widget.type == 'loyer'
                      ? 'Loyer - Bien #${opt['bien_id']}'
                      : opt['name'];
                  return DropdownMenuItem(
                    value: index,
                    child: Text(label, style: const TextStyle(fontSize: 12)),
                  );
                }),
                onChanged: (val) => setState(() => _selectedIndex = val),
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedIndex != null) ...[
              Text(app.translate('amount'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${(widget.type == 'loyer' ? widget.options[_selectedIndex!]['loyer_mensuel'] : widget.options[_selectedIndex!]['amount']).toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
              ),
              const SizedBox(height: 20),
            ],
            Text(app.translate('select_payment_method'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMethodTile('mobile_money', app.translate('mobile_money'), Icons.phone_android),
            _buildMethodTile('carte_bancaire', app.translate('credit_card'), Icons.credit_card),
            _buildMethodTile('virement', app.translate('bank_transfer'), Icons.account_balance),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: (_selectedIndex == null || _isProcessing) ? null : () async {
            setState(() => _isProcessing = true);
            final opt = widget.options[_selectedIndex!];
            final amount = widget.type == 'loyer' ? (opt['loyer_mensuel'] as num).toDouble() : (opt['amount'] as num).toDouble();
            final user = app.user!;
            
            if (widget.type == 'loyer') {
              final rentalId = opt['id']; // On s'assure d'avoir le rentalId
              final paymentUrl = await transProvider.initiateRealPayment(rentalId: rentalId);
              
              if (paymentUrl != null) {
                 final uri = Uri.parse(paymentUrl);
                 if (await canLaunchUrl(uri)) {
                   await launchUrl(uri, mode: LaunchMode.externalApplication);
                   if (!context.mounted) return;
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Redirection vers le portail de paiement sécurisé...'))
                   );
                 } else {
                   if (!context.mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le lien de paiement')));
                 }
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(transProvider.error)));
              }
              setState(() => _isProcessing = false);
              return;
            }

            final success = await transProvider.processPayment(
              locataireId: user.id,
              type: widget.type,
              montant: amount,
              methode: _method,
              bienId: widget.type == 'loyer' ? opt['bien_id'] : null,
              serviceId: widget.type == 'service' ? opt['id'] : null,
            );

            if (!context.mounted) return;
            if (success) {
              Navigator.pop(context);
              _showSuccessDialog(context, amount, transProvider.transactions.first.reference);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(transProvider.error)));
              setState(() => _isProcessing = false);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
          child: _isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(app.translate('confirm_payment')),
        ),
      ],
    );
  }

  Widget _buildMethodTile(String id, String label, IconData icon) {
    final isSelected = _method == id;
    return GestureDetector(
      onTap: () => setState(() => _method = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.accentOrange : AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.accentOrange : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.accentOrange : AppColors.getTextColor(context))),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.accentOrange, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, double amount, String ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Paiement Réussi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Référence: $ref', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant payé', style: TextStyle(fontSize: 12)),
                Text('${amount.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 6: ÉVALUATIONS
// ============================================================
class _EvaluationsTab extends StatefulWidget {
  const _EvaluationsTab();

  @override
  State<_EvaluationsTab> createState() => _EvaluationsTabState();
}

class _EvaluationsTabState extends State<_EvaluationsTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final user = context.read<AppProvider>().user;
      if (user != null) {
        context.read<EvaluationProvider>().loadEvaluationsReceived(user.id);
        context.read<EvaluationProvider>().loadEvaluationsGiven(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final evalProvider = context.watch<EvaluationProvider>();
    final user = appProvider.user;

    if (user == null) return const Center(child: Text('Veuillez vous connecter'));

    final avgRating = evalProvider.getAverageRating(user.id);
    final count = evalProvider.getRatingCount(user.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentOrange, AppColors.accentOrange.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  appProvider.translate('average_rating'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${avgRating > 0 ? avgRating : "0.0"}',
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < avgRating.floor() ? Icons.star : (index < avgRating ? Icons.star_half : Icons.star_border),
                      color: Colors.white,
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count ${appProvider.translate('total_evaluations')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                if (avgRating >= 4) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          appProvider.translate('confidence_badge'),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          ElevatedButton.icon(
            onPressed: () => _showRateLandlordDialog(context),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(appProvider.translate('rate_owner')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),

          // Tab Section
          DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  labelColor: AppColors.accentOrange,
                  unselectedLabelColor: AppColors.getTextColor(context).withValues(alpha: 0.5),
                  indicatorColor: AppColors.accentOrange,
                  tabs: [
                    Tab(text: appProvider.translate('evaluations_received')),
                    Tab(text: appProvider.translate('evaluations_given')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400, // Fixed height for tab content
                  child: TabBarView(
                    children: [
                      _buildReceivedList(evalProvider, appProvider),
                      _buildGivenList(evalProvider, appProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedList(EvaluationProvider provider, AppProvider app) {
    if (provider.evaluationsReceived.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 48, color: AppColors.getTextColor(context).withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              app.translate('no_evaluations'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: provider.evaluationsReceived.length,
      itemBuilder: (context, index) {
        final eval = provider.evaluationsReceived[index];
        return _EvaluationCard(evaluation: eval, isReceived: true);
      },
    );
  }

  Widget _buildGivenList(EvaluationProvider provider, AppProvider app) {
    if (provider.evaluationsGiven.isEmpty) {
      return Center(
        child: Text(
          'Vous n\'avez pas encore donné d\'avis.',
          style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      itemCount: provider.evaluationsGiven.length,
      itemBuilder: (context, index) {
        final eval = provider.evaluationsGiven[index];
        return _EvaluationCard(evaluation: eval, isReceived: false);
      },
    );
  }

  void _showRateLandlordDialog(BuildContext context) async {
    final appProvider = context.read<AppProvider>();
    final user = appProvider.user;
    if (user == null) return;

    // Charger les contrats passés
    final db = DatabaseHelper();
    final contractsRaw = await db.getContractsByTenant(user.id);
    
    // Filtrer les contrats terminés (date fin < now)
    final now = DateTime.now();
    final pastContracts = contractsRaw.where((c) {
      final endDate = DateTime.parse(c['date_fin']);
      return endDate.isBefore(now);
    }).toList();

    if (!context.mounted) return;
    if (pastContracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune location terminée éligible pour évaluation.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _RateLandlordDialog(pastContracts: pastContracts),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final Evaluation evaluation;
  final bool isReceived;

  const _EvaluationCard({required this.evaluation, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mock user info since we don't have owner name here easily without extra fetch
              Text(
                isReceived ? 'Propriétaire' : 'Avis donné',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    color: index < evaluation.note ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (evaluation.commentaire != null && evaluation.commentaire!.isNotEmpty)
            Text(
              evaluation.commentaire!,
              style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7), fontSize: 14),
            ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd/MM/yyyy').format(evaluation.dateCreation),
            style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RateLandlordDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pastContracts;

  const _RateLandlordDialog({required this.pastContracts});

  @override
  State<_RateLandlordDialog> createState() => _RateLandlordDialogState();
}

class _RateLandlordDialogState extends State<_RateLandlordDialog> {
  int? _selectedContractIndex;
  double _rating = 5.0;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    
    return AlertDialog(
      backgroundColor: AppColors.getCardColor(context),
      title: Text(app.translate('rate_owner')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.translate('choose_rental'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: _selectedContractIndex,
                isExpanded: true,
                underline: const SizedBox(),
                items: List.generate(widget.pastContracts.length, (index) {
                  final c = widget.pastContracts[index];
                  return DropdownMenuItem(
                    value: index,
                    child: Text('Bien #${c['bien_id']} - Fin le ${DateFormat('dd/MM/yy').format(DateTime.parse(c['date_fin']))}', style: const TextStyle(fontSize: 12)),
                  );
                }),
                onChanged: (val) => setState(() => _selectedContractIndex = val),
              ),
            ),
            const SizedBox(height: 20),
            Text(app.translate('select_rating'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = index + 1.0),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: app.translate('add_comment_opt'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _selectedContractIndex == null ? null : () async {
            final contract = widget.pastContracts[_selectedContractIndex!];
            final success = await context.read<EvaluationProvider>().addEvaluation(
              evaluatorId: contract['locataire_id'],
              evaluatedId: contract['proprietaire_id'],
              propertyId: contract['bien_id'],
              rating: _rating,
              comment: _commentController.text,
            );

            if (!context.mounted) return;
            if (success) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Merci pour votre avis !')),
              );
            } else {
              final error = context.read<EvaluationProvider>().error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
          child: Text(app.translate('submit_evaluation')),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 6: COMMUNAUTÉ
// ============================================================
class _CommunauteTab extends StatelessWidget {
  const _CommunauteTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Post Button
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _AddPostDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Créer un post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 20),

          // Posts
          Consumer<CommunityProvider>(
            builder: (context, communityProvider, _) {
              if (communityProvider.posts.isEmpty) {
                return const Center(child: Text('Aucun post'));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: communityProvider.posts.length,
                itemBuilder: (context, index) {
                  final post = communityProvider.posts[index];
                  return _CommunityPostCard(post: post);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  final dynamic post;

  const _CommunityPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentOrange,
                child: Text(post.userName[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      post.dateCreation.toString().split(' ')[0],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.contenu),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.thumb_up,
                  size: 16,
                  color: post.liked ? Colors.blue : Colors.grey),
              const SizedBox(width: 4),
              Text('${post.likes}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 16),
              const Icon(Icons.comment, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${post.commentsCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPostDialog extends StatefulWidget {
  @override
  State<_AddPostDialog> createState() => _AddPostDialogState();
}

class _AddPostDialogState extends State<_AddPostDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un post'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'Écrivez votre message...'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              context.read<CommunityProvider>().addPost(
                userId: 1,
                userName: 'Moi',
                userAvatar: 'https://i.pravatar.cc/150',
                contenu: _controller.text,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Poster'),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 7: AIDE
// ============================================================
class _AideTab extends StatefulWidget {
  const _AideTab();

  @override
  State<_AideTab> createState() => _AideTabState();
}

class _AideTabState extends State<_AideTab> {
  int? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FAQ
          const Text(
            'Questions fréquemment posées',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Consumer<SupportProvider>(
            builder: (context, supportProvider, _) {
              final categories = supportProvider.categories;
              return categories.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _buildFAQCategory(category, index);
                      },
                    );
            },
          ),

          const SizedBox(height: 32),

          // Contact Form
          const Text(
            'Nous contacter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildContactForm(context),
        ],
      ),
    );
  }

  Widget _buildFAQCategory(dynamic category, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(category.titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            trailing: Icon(
              _expandedCategory == index ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _expandedCategory = _expandedCategory == index ? null : index;
              });
            },
          ),
          if (_expandedCategory == index)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: category.items
                    .map((item) => _buildFAQItem(item))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(dynamic item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text(item.reponse, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const Divider(color: Colors.grey, height: 16),
        ],
      ),
    );
  }

  Widget _buildContactForm(BuildContext context) {
    final emailCtrl = TextEditingController();
    final sujetCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    return Column(
      children: [
        TextField(
          controller: emailCtrl,
          decoration: InputDecoration(
            hintText: 'Votre email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: sujetCtrl,
          decoration: InputDecoration(
            hintText: 'Sujet',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: messageCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Message...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final success = await context.read<SupportProvider>().submitContact(
                  email: emailCtrl.text,
                  sujet: sujetCtrl.text,
                  message: messageCtrl.text,
                  userRole: 'locataire',
                );

                if (!context.mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.read<SupportProvider>().successMessage),
                      backgroundColor: AppColors.accentGreen,
                    ),
                  );
                  emailCtrl.clear();
                  sujetCtrl.clear();
                  messageCtrl.clear();
                }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: AppColors.accentOrange,
          ),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}