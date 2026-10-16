import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../services/database_helper.dart';
import '../../widgets/role_guard.dart';

class PartenaireDashboardScreen extends StatefulWidget {
  const PartenaireDashboardScreen({super.key});

  @override
  State<PartenaireDashboardScreen> createState() => _PartenaireDashboardScreenState();
}

class _PartenaireDashboardScreenState extends State<PartenaireDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  late Timer _timer;
  String _currentTime = '';
  String _currentDate = '';
  int _unreadNotifications = 0;
  bool _notificationsRead = false;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _updateDateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateDateTime());
    _loadData();
  }

  void _updateDateTime() {
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
      _currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final user = context.read<AppProvider>().user;
    
    if (user != null) {
      _services = await db.getPartnerServices();
      _requests = await db.getServiceRequestsForPartner(user.id);
      _notifications = await db.getNotifications(user.id);
      _unreadNotifications = _notifications.where((n) => n['read'] == false).length;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    
    return RoleGuard(
      allowedRoles: const ['partenaire'],
      customErrorMessage: 'Seuls les partenaires peuvent accéder au dashboard partenaire',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        appBar: _buildAppBar(appProvider),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
            : Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _OverviewTab(
                          services: _services,
                          requests: _requests,
                          user: appProvider.user,
                          onRefresh: _loadData,
                        ),
                        _ServicesTab(services: _services, onRefresh: _loadData),
                        _RequestsTab(requests: _requests, onRefresh: _loadData),
                        _ProfileTab(user: appProvider.user),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomNavBar(),
        floatingActionButton: _selectedIndex == 1 ? _buildFAB() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppProvider appProvider) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.handshake, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Espace Partenaire',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Gérez vos services',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primaryMedium,
              AppColors.primaryLight
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        _buildDateTimeWidget(),
        _buildNotificationWidget(),
        _buildProfileWidget(appProvider),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDateTimeWidget() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(_currentTime, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
          const SizedBox(width: 6),
          Text(_currentDate, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildNotificationWidget() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => _showNotificationsDialog(),
          ),
        ),
        if (!_notificationsRead && _unreadNotifications > 0)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: AppColors.dangerGradient,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_unreadNotifications',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showNotificationsDialog() async {
    setState(() => _notificationsRead = true);
    final db = DatabaseHelper();
    for (var notif in _notifications.where((n) => n['read'] == false)) {
      await db.markNotificationAsRead(notif['id']);
    }
    if (!mounted) return;
    _notifications = await db.getNotifications(context.read<AppProvider>().user!.id);
    _unreadNotifications = 0;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucune notification', style: TextStyle(color: Colors.white54)),
              )
            else
              ..._notifications.map((n) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active, color: AppColors.accentBlue),
                ),
                title: Text(n['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(n['body'], style: const TextStyle(color: Colors.white70)),
                trailing: Text(
                  DateFormat('dd/MM HH:mm').format(DateTime.parse(n['createdAt'])),
                  style: const TextStyle(color: Colors.white54),
                ),
              )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileWidget(AppProvider appProvider) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.primaryDark,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          gradient: AppColors.secondaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              appProvider.userDisplayName.isNotEmpty
                  ? appProvider.userDisplayName[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Mon profil', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: AppColors.accentRed, size: 20),
              SizedBox(width: 12),
              Text('Se déconnecter', style: TextStyle(color: AppColors.accentRed)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (value == 'logout') {
          _showLogoutDialog();
        }
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: AppColors.primaryDark,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: const Text('Se déconnecter', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentOrange),
      ),
    );
    
    await context.read<AppProvider>().logout();
    
    if (mounted) {
      Navigator.pop(context); // Close loading
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentOrange.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) => setState(() => _selectedIndex = index),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Aperçu'),
          Tab(icon: Icon(Icons.build_outlined, size: 20), text: 'Services'),
          Tab(icon: Icon(Icons.assignment_outlined, size: 20), text: 'Demandes'),
          Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.98),
            AppColors.primaryMedium.withValues(alpha: 0.98)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.accentOrange,
        unselectedItemColor: Colors.white60,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _tabController.animateTo(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined, size: 22), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined, size: 22), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined, size: 22), label: 'Demandes'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 22), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddServiceDialog(),
      backgroundColor: AppColors.accentOrange,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Nouveau service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  void _showAddServiceDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Ajouter un service', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField('Nom du service', Icons.build, nameController),
              const SizedBox(height: 12),
              _buildDialogTextField('Catégorie', Icons.category, categoryController),
              const SizedBox(height: 12),
              _buildDialogTextField('Prix (FCFA)', Icons.attach_money, priceController, keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _buildDialogTextField('Description', Icons.description, descController, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = context.read<AppProvider>().user;
              if (user == null) return;
              
              await DatabaseHelper().addPartnerService({
                'name': nameController.text.trim(),
                'category': categoryController.text.trim(),
                'price': int.tryParse(priceController.text) ?? 0,
                'description': descController.text.trim(),
                'partenaireId': user.id,
                'rating': 0.0,
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service ajouté avec succès')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(String label, IconData icon, TextEditingController controller,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(color: AppColors.accentOrange),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

// ========== OVERVIEW TAB ==========
class _OverviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> requests;
  final User? user;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.services,
    required this.requests,
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final pendingRequests = requests.where((r) => r['statut'] == 'en_attente').length;
    final completedRequests = requests.where((r) => r['statut'] == 'termine').length;
    final totalRevenue = requests
        .where((r) => r['statut'] == 'termine')
        .fold(0, (sum, r) => sum + (r['price'] as int? ?? 0));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            _buildStatsGrid(
              totalServices: services.length,
              pendingRequests: pendingRequests,
              completedRequests: completedRequests,
              totalRevenue: totalRevenue,
            ),
            const SizedBox(height: 24),
            _buildRecentRequests(requests.take(5).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.handshake, size: 36, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour ${user?.prenom ?? 'Partenaire'}! 🤝',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Gérez vos services partenaires',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'En ligne',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required int totalServices,
    required int pendingRequests,
    required int completedRequests,
    required int totalRevenue,
  }) {
    final stats = [
      {'title': 'Services', 'value': '$totalServices', 'icon': Icons.build, 'color': AppColors.accentBlue},
      {'title': 'En attente', 'value': '$pendingRequests', 'icon': Icons.pending, 'color': AppColors.accentOrange},
      {'title': 'Terminés', 'value': '$completedRequests', 'icon': Icons.check_circle, 'color': AppColors.accentGreen},
      {'title': 'Revenus', 'value': '${NumberFormat.decimalPattern('fr').format(totalRevenue)} FCFA', 'icon': Icons.monetization_on, 'color': AppColors.accentPurple},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: stats.map((stat) => _buildStatCard(
        title: stat['title'] as String,
        value: stat['value'] as String,
        icon: stat['icon'] as IconData,
        color: stat['color'] as Color,
      )).toList(),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequests(List<Map<String, dynamic>> recentRequests) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppColors.accentOrange),
              SizedBox(width: 10),
              Text(
                'Demandes récentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentRequests.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune demande récente',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            )
          else
            ...recentRequests.map((req) => _buildRequestItem(req)),
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> req) {
    final statusColors = {
      'en_attente': AppColors.accentOrange,
      'en_cours': AppColors.accentBlue,
      'termine': AppColors.accentGreen,
      'annule': AppColors.accentRed,
    };
    final statusLabels = {
      'en_attente': 'En attente',
      'en_cours': 'En cours',
      'termine': 'Terminé',
      'annule': 'Annulé',
    };
    final color = statusColors[req['statut']] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req['service_name'] ?? 'Service',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  req['client_name'] ?? 'Client',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  '${NumberFormat.decimalPattern('fr').format(req['price'] ?? 0)} FCFA', style: const TextStyle(fontSize: 12, color: AppColors.accentOrange),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabels[req['statut']] ?? req['statut'],
              style: TextStyle(fontSize: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== SERVICES TAB ==========
class _ServicesTab extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final VoidCallback onRefresh;

  const _ServicesTab({required this.services, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun service publié',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur + pour ajouter votre premier service',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: services.length,
      itemBuilder: (context, index) => _buildServiceCard(context, services[index]),
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  service['name'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.accentOrange, size: 20),
                onPressed: () => _showEditDialog(context, service),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            service['category'] ?? 'Catégorie',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat.decimalPattern('fr').format(service['price'] ?? 0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange),
          ),
          if (service['description'] != null && service['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              service['description'],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${service['rating']?.toStringAsFixed(1) ?? '0.0'} (${service['reviews'] ?? 0})',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _deleteService(context, service['id']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: const BorderSide(color: AppColors.accentRed),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Supprimer', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> service) {
    // Implementation similar to _showAddServiceDialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité d\'édition à venir')),
    );
  }

  void _deleteService(BuildContext context, int id) async {
    await DatabaseHelper().deletePartnerService(id);
    onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service supprimé')),
      );
    }
  }
}

// ========== REQUESTS TAB ==========
class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRefresh;

  const _RequestsTab({required this.requests, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'Aucune demande de service',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(context, requests[index]),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> req) {
    final statusColors = {
      'en_attente': AppColors.accentOrange,
      'en_cours': AppColors.accentBlue,
      'termine': AppColors.accentGreen,
      'annule': AppColors.accentRed,
    };
    final color = statusColors[req['statut']] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.assignment, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['service_name'] ?? 'Service',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Client: ${req['client_name'] ?? 'Inconnu'}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  req['statut'] ?? 'Inconnu',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (req['message'] != null && req['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                req['message'],
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${NumberFormat.decimalPattern('fr').format(req['price'] ?? 0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange),
              ),
              const Spacer(),
              if (req['statut'] == 'en_attente') ...[
                OutlinedButton.icon(
                  onPressed: () => _updateStatus(context, req['id'], 'en_cours'),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Commencer', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentBlue,
                    side: const BorderSide(color: AppColors.accentBlue),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _updateStatus(context, req['id'], 'termine'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Terminer', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGreen,
                    side: const BorderSide(color: AppColors.accentGreen),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, int requestId, String status) async {
    try {
      await DatabaseHelper().updateServiceRequestStatus(requestId, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour: $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

// ========== PROFILE TAB ==========
class _ProfileTab extends StatelessWidget {
  final User? user;

  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    user!.displayName.isNotEmpty
                        ? user!.displayName[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user!.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user!.email,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: user!.isVerified
                        ? AppColors.accentGreen.withValues(alpha: 0.2)
                        : AppColors.accentOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user!.isVerified ? Icons.verified : Icons.pending,
                        size: 14,
                        color: user!.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user!.isVerified ? 'Certifié ✓' : 'En attente de vérification',
                        style: TextStyle(
                          fontSize: 12,
                          color: user!.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info cards
          _buildInfoCard('Téléphone', user!.telephone ?? 'Non renseigné', Icons.phone),
          _buildInfoCard('Email', user!.email, Icons.email),
          _buildInfoCard('Rôle', _getRoleLabel(user!.role ?? ''), Icons.person),
          
          const SizedBox(height: 24),
          
          // Actions
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context),
            icon: const Icon(Icons.edit),
            label: const Text('Modifier mon profil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentOrange,
              side: const BorderSide(color: AppColors.accentOrange),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentRed,
              side: const BorderSide(color: AppColors.accentRed),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accentBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                ),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'locataire': return 'Locataire';
      case 'proprietaire': return 'Propriétaire';
      case 'admin': return 'Administrateur';
      case 'partenaire': return 'Partenaire';
      default: return role;
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité d\'édition de profil à venir')),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Se déconnecter', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }
}
