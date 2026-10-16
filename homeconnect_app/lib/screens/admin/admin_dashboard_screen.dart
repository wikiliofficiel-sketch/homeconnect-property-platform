// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import '../../providers/app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../models/user.dart';
import '../../models/property.dart';
import '../../models/report_sanction_models.dart';
import '../../providers/report_provider.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/design_widgets.dart';
import 'user_detail_screen.dart';
import 'kyc_management_screen.dart';
import '../tenant/chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  List<User> _users = [];
  List<Property> _properties = [];
  List<Map<String, dynamic>> _commissions = [];
  List<User> _subscribedUsers = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _settings = [];
  List<Map<String, dynamic>> _tickets = [];

  int _totalUsers = 0;
  int _proprietairesCount = 0;
  int _locatairesCount = 0;
  int _activeProperties = 0;
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

    // ── Tous les biens depuis l'API admin (pending + active + suspended) ────
    try {
      final rawProps = await ApiService.getAdminProperties();
      _properties = rawProps
          .map((p) => Property.fromApiMap(Map<String, dynamic>.from(p)))
          .toList();
      _activeProperties = _properties.where((p) => p.status == 'active').length;
    } catch (_) {
      _properties = await db.getProperties(status: null);
      _activeProperties = await db.getActivePropertiesCount();
    }

    // ── Utilisateurs depuis l'API (IDs serveur réels pour la messagerie) ───────
    try {
      final rawUsers = await ApiService.getAdminUsers();
      _users = rawUsers.map((u) => User.fromMap(Map<String, dynamic>.from(u))).toList();
      _totalUsers         = _users.length;
      _proprietairesCount = _users.where((u) => u.role == 'proprietaire').length;
      _locatairesCount    = _users.where((u) => u.role == 'locataire').length;
    } catch (_) {
      _users              = await db.getAllUsers();
      _totalUsers         = await db.getTotalUsers();
      _proprietairesCount = await db.getProprietairesCount();
      _locatairesCount    = await db.getLocatairesCount();
    }
    _settings           = await db.getAllSettings();
    _tickets            = await db.getTickets();

    // ── Commissions depuis l'API backend ─────────────────────────────────────
    try {
      final rawComm = await ApiService.getAdminCommissions();
      _commissions = rawComm.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    } catch (_) {
      _commissions = await db.getCommissions();
    }

    // ── Abonnés depuis l'API ─────────────────────────────────────────────────
    _subscribedUsers = await db.getSubscribedUsers();

    // ── Logs depuis l'API backend (source de vérité) ──────────────────────────
    try {
      final rawLogs = await ApiService.getAdminLogs();
      if (rawLogs.isNotEmpty) {
        _logs = rawLogs.map((l) => Map<String, dynamic>.from(l as Map)).toList();
      } else {
        _logs = await db.getLogs();
      }
    } catch (_) {
      _logs = await db.getLogs();
    }

    if (!mounted) return;
    final reportProvider = context.read<ReportProvider>();
    await reportProvider.loadAllReports();
    if (!mounted) return;
    final user = context.read<AppProvider>().user;
    if (user != null) {
      await context.read<NotificationProvider>().loadNotifications(user.id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final statsData = {
      'totalUtilisateurs': _totalUsers,
      'proprietaires': _proprietairesCount,
      'locataires': _locatairesCount,
      'biensActifs': _activeProperties,
      'transactions': _commissions.length,
      'revenue': _commissions.fold<double>(0.0, (sum, c) => sum + ((c['montant'] ?? 0.0) as num).toDouble()),
    };

    return RoleGuard(
      allowedRoles: const ['admin'],
      customErrorMessage: 'Seul l\'admin peut accéder au dashboard d\'administration',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        body: _isLoading
            ? Center(child: LoadingWidget(message: appProvider.translate('loading_data')))
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.getBackgroundGradient(context),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                    PremiumHeaderWidget(
                      title: appProvider.translate('admin_panel'),
                      subtitle: appProvider.translate('admin_subtitle'),
                      notificationCount: context.watch<NotificationProvider>().unreadCount,
                      onNotificationTap: () => _showNotificationsDialog(context.read<NotificationProvider>()),
                      onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                      onLogoutTap: () => _showLogoutConfirmation(context),
                    ),
                    _buildLanguagePicker(context, appProvider),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _DashboardTab(data: statsData, logs: _logs),
                          _UsersTab(users: _users, onRefresh: _loadData),
                          _PropertiesTab(properties: _properties, onRefresh: _loadData),
                          _ReportsTab(onRefresh: _loadData),
                          _SubscriptionsTab(users: _subscribedUsers, onRefresh: _loadData),
                          _CommissionsTab(commissions: _commissions),
                          _LogsTab(logs: _logs),
                          const KYCManagementScreen(),
                          _SupportTab(tickets: _tickets, onRefresh: _loadData),
                          _AdminMessagesTab(),
                          _SettingsTab(settings: _settings, onRefresh: _loadData),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
        floatingActionButton: _selectedIndex == 1 
            ? _buildPremiumFAB() 
            : (_selectedIndex == 2 ? _buildAddPropertyFAB() : null),
        bottomNavigationBar: _buildPremiumTabBar(appProvider),
      ),
    );
  }

  Widget _buildLanguagePicker(BuildContext context, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.language, size: 16, color: AppColors.accentOrange),
          const SizedBox(width: 8),
          DropdownButton<Locale>(
            value: provider.locale,
            underline: const SizedBox(),
            onChanged: (locale) => provider.setLocale(locale!),
            items: const [
              DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
              DropdownMenuItem(value: Locale('en'), child: Text('English')),
              DropdownMenuItem(value: Locale('fon'), child: Text('Fon')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTabBar(AppProvider appProvider) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppColors.cardDark 
          : Colors.white,
      child: SafeArea(
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black45,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          indicatorColor: AppColors.accentOrange,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) => setState(() => _selectedIndex = index),
          tabs: [
            Tab(icon: const Icon(Icons.dashboard_outlined, size: 24), text: appProvider.translate('dashboard')),
            Tab(icon: const Icon(Icons.people_outline, size: 24), text: appProvider.translate('users')),
            Tab(icon: const Icon(Icons.home_work_outlined, size: 24), text: appProvider.translate('properties')),
            Tab(icon: const Icon(Icons.warning_amber_outlined, size: 24), text: appProvider.translate('reports')),
            Tab(icon: const Icon(Icons.subscriptions_outlined, size: 24), text: appProvider.translate('subscriptions')),
            Tab(icon: const Icon(Icons.monetization_on_outlined, size: 24), text: appProvider.translate('commissions')),
            Tab(icon: const Icon(Icons.history_outlined, size: 24), text: appProvider.translate('logs')),
            Tab(icon: const Icon(Icons.verified_user_outlined, size: 24), text: appProvider.translate('kyc_management')),
            Tab(icon: const Icon(Icons.help_outline, size: 24), text: appProvider.translate('support')),
            const Tab(icon: Icon(Icons.chat_outlined, size: 24), text: 'Messages'),
            Tab(icon: const Icon(Icons.settings_outlined, size: 24), text: appProvider.translate('config')),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final appProvider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(appProvider.translate('logout_confirmation'), style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text(appProvider.translate('logout_confirmation_desc'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appProvider.translate('cancel'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: Text(appProvider.translate('logout'), style: TextStyle(color: AppColors.getTextColor(context))),
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
    if (user != null) {
      await notifProvider.markAllAsRead(user.id);
    }
    if (!mounted) return;
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

  Widget _buildPremiumFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddUserDialog(),
      backgroundColor: AppColors.accentOrange,
      icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
      label: Text(context.read<AppProvider>().translate('new_user'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.w600)),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  Widget _buildAddPropertyFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/add-property').then((_) => _loadData()),
      backgroundColor: AppColors.accentGreen,
      icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
      label: Text(context.read<AppProvider>().translate('new_property'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.w600)),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  void _showAddUserDialog() {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final telephoneController = TextEditingController();
    String selectedRole = 'locataire';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context), borderRadius: BorderRadius.circular(32)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.read<AppProvider>().translate('add_user'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                  const SizedBox(height: 20),
                  _buildTextField(context.read<AppProvider>().translate('last_name'), Icons.person_outline, nomController),
                  const SizedBox(height: 12),
                  _buildTextField(context.read<AppProvider>().translate('first_name'), Icons.person_outline, prenomController),
                  const SizedBox(height: 12),
                  _buildTextField(context.read<AppProvider>().translate('email'), Icons.email, emailController),
                  const SizedBox(height: 12),
                  _buildTextField(context.read<AppProvider>().translate('password'), Icons.lock_outline, passwordController, obscure: true),
                  const SizedBox(height: 12),
                  _buildTextField(context.read<AppProvider>().translate('phone'), Icons.phone_outlined, telephoneController),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(20)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        dropdownColor: AppColors.getCardColor(context),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'locataire', child: Text(context.read<AppProvider>().translate('tenant'))),
                          DropdownMenuItem(value: 'proprietaire', child: Text(context.read<AppProvider>().translate('landlord'))),
                          DropdownMenuItem(value: 'admin', child: Text(context.read<AppProvider>().translate('admin'))),
                        ],
                        onChanged: (v) { if (v != null) setStateDialog(() => selectedRole = v); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(context.read<AppProvider>().translate('cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nomController.text.isEmpty || prenomController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<AppProvider>().translate('fill_all_fields'))));
                              return;
                            }
                            final db = DatabaseHelper();
                            final existing = await db.getUserByEmail(emailController.text.trim());
                            if (!context.mounted) return;
                            if (existing != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<AppProvider>().translate('email_already_used'))));
                              return;
                            }
                            await db.addUser({
                              'nom': nomController.text.trim(),
                              'prenom': prenomController.text.trim(),
                              'email': emailController.text.trim(),
                              'password': passwordController.text,
                              'telephone': telephoneController.text.trim(),
                              'role': selectedRole,
                            });
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadData();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${prenomController.text} ${nomController.text} ${context.read<AppProvider>().translate('added_successfully')}')));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(context.read<AppProvider>().translate('add'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.2))),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide(color: AppColors.accentOrange)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

// ========== DASHBOARD TAB ==========
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> logs;
  const _DashboardTab({required this.data, required this.logs});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async { await Future.delayed(const Duration(seconds: 1)); },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context),
            const SizedBox(height: 16),
            _buildKpiGrid(context),
            const SizedBox(height: 16),
            _buildRevenueChart(context),
            const SizedBox(height: 16),
            _buildRecentActivitiesPlaceholder(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: AppColors.accentOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: AppColors.getCardColor(context), borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.admin_panel_settings, size: MediaQuery.of(context).size.width < 360 ? 28 : 36, color: AppColors.primaryDark)
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(context.read<AppProvider>().translate('admin_dashboard'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))),
                FittedBox(fit: BoxFit.scaleDown, child: Text(context.read<AppProvider>().translate('platform_immo_benin'), style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.9)))),
              ]
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(context.read<AppProvider>().translate('online'), style: TextStyle(color: AppColors.getTextColor(context), fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    final kpis = [
      {'title': context.read<AppProvider>().translate('users'), 'value': '${data['totalUtilisateurs']}', 'icon': Icons.people, 'color': AppColors.accentBlue, 'bgColor': AppColors.accentBlue.withValues(alpha: 0.15)},
      {'title': 'Transactions', 'value': '${data['transactions']}', 'icon': Icons.payments, 'color': AppColors.accentOrange, 'bgColor': AppColors.accentOrange.withValues(alpha: 0.15)},
      {'title': 'Revenus', 'value': NumberFormat.compact(locale: 'fr').format(data['revenue'] ?? 0), 'icon': Icons.account_balance_wallet, 'color': AppColors.accentGreen, 'bgColor': AppColors.accentGreen.withValues(alpha: 0.15)},
      {'title': context.read<AppProvider>().translate('active_properties'), 'value': '${data['biensActifs']}', 'icon': Icons.home, 'color': AppColors.accentPurple, 'bgColor': AppColors.accentPurple.withValues(alpha: 0.15)},
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: kpis.map((kpi) => _buildKpiCard(
            context,
            title: kpi['title'] as String,
            value: kpi['value'] as String,
            icon: kpi['icon'] as IconData,
            color: kpi['color'] as Color,
            bgColor: kpi['bgColor'] as Color,
          )).toList(),
    );
  }

  Widget _buildKpiCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color, required Color bgColor}) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color))
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.7) : Colors.black54), maxLines: 1)
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.read<AppProvider>().translate('revenue_analysis'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
              const Icon(Icons.trending_up, color: AppColors.accentGreen),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(context, 0.4, 'Lun'),
                const SizedBox(width: 15),
                _buildBar(context, 0.7, 'Mar'),
                const SizedBox(width: 15),
                _buildBar(context, 0.5, 'Mer'),
                const SizedBox(width: 15),
                _buildBar(context, 0.9, 'Jeu'),
                const SizedBox(width: 15),
                _buildBar(context, 0.6, 'Ven'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, double heightFactor, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.accentOrange, AppColors.accentOrange.withValues(alpha: 0.3)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildRecentActivitiesPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.history, color: AppColors.accentOrange), const SizedBox(width: 10), Text(context.read<AppProvider>().translate('recent_activities'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)))]),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(context.read<AppProvider>().translate('no_activity_yet'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
                  const SizedBox(height: 4),
                  Text(context.read<AppProvider>().translate('activities_will_appear_here'), style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.3))),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 5 ? 5 : logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.info_outline, color: AppColors.accentOrange, size: 20)),
                  title: Text(log['action']?.toString() ?? 'Action inconnue', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14)),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(log['createdAt']?.toString() ?? '') ?? DateTime.now()), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 12)),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ========== USERS TAB ==========
class _UsersTab extends StatefulWidget {
  final List<User> users;
  final VoidCallback onRefresh;
  const _UsersTab({required this.users, required this.onRefresh});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchQuery = '';
  String _selectedRole = 'all';

  List<User> get _filteredUsers {
    return widget.users.where((user) {
      if (_searchQuery.isNotEmpty && !user.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) && !user.email.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      if (_selectedRole != 'all' && user.role != _selectedRole) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur...',
                  hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search, color: AppColors.getTextColor(context).withValues(alpha: 0.54)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.transparent),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tous', 'all'),
                _buildFilterChip('Locataires', 'locataire'),
                _buildFilterChip('Propriétaires', 'proprietaire'),
                _buildFilterChip('Admins', 'admin'),
                _buildFilterChip('Partenaires', 'partenaire'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text('Aucun utilisateur', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 18)),
            const SizedBox(height: 8),
            Text('Appuyez sur + pour ajouter le premier utilisateur', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.3), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
    );
  }

  Widget _buildUserCard(User user) {
    final roleColors = {
      'locataire': AppColors.accentBlue,
      'proprietaire': AppColors.accentOrange,
      'admin': AppColors.accentPurple,
      'partenaire': AppColors.accentGreen,
    };
    const roleLabels = {
      'locataire': 'Locataire',
      'proprietaire': 'Propriétaire',
      'admin': 'Admin',
      'partenaire': 'Partenaire',
    };
    final color = roleColors[user.role] ?? Colors.white70;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserDetailScreen(user: user, onRefresh: widget.onRefresh))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                  child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context))),
                  const SizedBox(height: 4),
                  Text(user.email, style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.60))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(roleLabels[user.role] ?? (user.role ?? ''), style: TextStyle(fontSize: 10, color: color))),
                    const SizedBox(width: 8),
                    if ((user.telephone ?? '').isNotEmpty) Flexible(child: Text(user.telephone!, style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.54)), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      receiverId: user.id,
                      receiverName: user.displayName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_outlined, color: AppColors.accentBlue),
              tooltip: 'Envoyer un message',
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.getTextColor(context).withValues(alpha: 0.3), size: 14),
          ],
        ),
      ),
    );
  }
}

// ========== PROPERTIES TAB ==========
class _PropertiesTab extends StatefulWidget {
  final List<Property> properties;
  final VoidCallback onRefresh;
  const _PropertiesTab({required this.properties, required this.onRefresh});

  @override
  State<_PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends State<_PropertiesTab> {
  String _searchQuery = '';

  List<Property> get _filtered {
    if (_searchQuery.isEmpty) return widget.properties;
    return widget.properties.where((p) => p.titre.toLowerCase().contains(_searchQuery.toLowerCase()) || p.lieu.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: AppColors.getTextColor(context)),
            decoration: InputDecoration(
                hintText: 'Rechercher un bien...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: AppColors.getTextColor(context).withValues(alpha: 0.54)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Text('Aucun bien enregistré', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Les biens ajoutés par les propriétaires apparaîtront ici', style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.3)), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) => _buildPropertyCard(_filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              image: property.imageUrl != null ? DecorationImage(image: getSafeImageProvider(property.imageUrl!), fit: BoxFit.cover) : null,
              color: AppColors.getTextColor(context).withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: property.imageUrl == null ? Center(child: Icon(Icons.home_work, size: 40, color: AppColors.getTextColor(context).withValues(alpha: 0.10))) : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(property.titre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: property.status == 'actif' ? AppColors.successGradient : (property.status == 'suspendu' ? AppColors.dangerGradient : AppColors.warningGradient),
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(property.status == 'actif' ? 'Actif' : (property.status == 'suspendu' ? 'Suspendu' : 'En attente'),
                          style: TextStyle(color: AppColors.getTextColor(context), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(property.lieu, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 4),
                Text('${property.prix} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentOrange, fontSize: 16)),
                
                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.getTextColor(context).withValues(alpha: 0.10))),
                
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStat(Icons.thumb_up_alt_outlined, '${property.likes}'),
                        const SizedBox(width: 16),
                        _buildStat(Icons.chat_bubble_outline, '${property.commentsCount}'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (property.status == 'en_attente' || property.status == 'pending')
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await ApiService.approveProperty(property.id);
                              if (ok) {
                                widget.onRefresh();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                            label: const Text('Valider', style: TextStyle(fontSize: 12, color: Colors.white)),
                          ),
                        const SizedBox(width: 4),
                        if (property.status == 'en_attente' || property.status == 'pending')
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: AppColors.accentRed, size: 22),
                            tooltip: 'Rejeter',
                            onPressed: () async {
                              final ok = await ApiService.rejectProperty(property.id);
                              if (ok) widget.onRefresh();
                            },
                          ),
                        if (property.status == 'active' || property.status == 'actif')
                          IconButton(
                            icon: const Icon(Icons.pause_circle_outline, color: AppColors.accentYellow, size: 22),
                            tooltip: 'Suspendre',
                            onPressed: () async {
                              await ApiService.rejectProperty(property.id);
                              widget.onRefresh();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 20),
                          onPressed: () async {
                            await ApiService.post('/api/admin/properties/${property.id}/delete', {});
                            ApiService.invalidateCache('${ApiService.baseUrl}/api/admin/properties');
                            widget.onRefresh();
                          },
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

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.getTextColor(context).withValues(alpha: 0.54)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }
}

// ========== REPORTS TAB ==========
class _ReportsTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _ReportsTab({required this.onRefresh});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final filteredReports = provider.reports.where((r) {
          if (_filterType == 'all') return true;
          return true; 
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/admin-sanctions'),
                    icon: const Icon(Icons.gavel),
                    label: const Text('Accéder au Centre de Modération'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterType,
                              style: TextStyle(color: AppColors.getTextColor(context)),
                              dropdownColor: AppColors.getCardColor(context),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Tous les signalements')),
                              ],
                              onChanged: (v) => setState(() => _filterType = v!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.accentRed.withValues(alpha: 0.2), AppColors.accentRed.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.report, color: AppColors.accentRed, size: 18),
                              const SizedBox(width: 8),
                              Flexible(child: Text('${provider.openReportsCount} en attente', style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredReports.isEmpty
                  ? Center(child: Text('Aucun signalement', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) => _buildReportCard(context, filteredReports[index], provider),
                    ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildReportCard(BuildContext context, Report report, ReportProvider provider) {
    final statusColor = report.status == ReportStatus.open ? AppColors.accentRed :
                        report.status == ReportStatus.inReview ? AppColors.accentOrange : Colors.green;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.2), statusColor.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.report, color: statusColor, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                    Text('Signalé par ID: ${report.reporterId}', style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
                  ],
                ),
              ),
              Text(DateFormat('dd/MM/yyyy').format(report.createdAt), style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.warning_amber, size: 14, color: AppColors.accentYellow), const SizedBox(width: 6), Text('Motif: ${report.typeLabel}', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.70)))]),
                const SizedBox(height: 6),
                Text(report.description, style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
              ],
            ),
          ),
          
          if (report.ownerReply != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.reply, size: 14, color: AppColors.accentOrange), SizedBox(width: 6), Text('Défense du propriétaire :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accentOrange))]),
                  const SizedBox(height: 6),
                  Text(report.ownerReply!, style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
                ],
              ),
            ),
          ],

          if (report.status == ReportStatus.open || report.status == ReportStatus.inReview) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showSanctionDialog(context, report, provider),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text('Sanctionner', style: TextStyle(color: AppColors.getTextColor(context))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final admin = context.read<AppProvider>().user;
                      if (admin != null) {
                        await provider.rejectReport(report.id, admin.id, 'Signalement non fondé');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement rejeté')));
                      }
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accentRed), foregroundColor: AppColors.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Rejeter'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: (report.status == ReportStatus.approved ? AppColors.accentGreen : AppColors.accentRed).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(report.status == ReportStatus.approved ? '✓ Sanctionné' : '✗ Rejeté', style: TextStyle(color: report.status == ReportStatus.approved ? AppColors.accentGreen : AppColors.accentRed)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSanctionDialog(BuildContext context, Report report, ReportProvider provider) {
    SanctionType selectedSanction = SanctionType.warning;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          title: Text('Appliquer une sanction', style: TextStyle(color: AppColors.getTextColor(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type de sanction :', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
              const SizedBox(height: 8),
              DropdownButtonFormField<SanctionType>(
                initialValue: selectedSanction,
                items: SanctionType.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.toString().split('.').last),
                )).toList(),
                onChanged: (v) => setState(() => selectedSanction = v!),
                style: TextStyle(color: AppColors.getTextColor(context)),
                dropdownColor: AppColors.getCardColor(context),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                style: TextStyle(color: AppColors.getTextColor(context)),
                decoration: InputDecoration(
                  labelText: 'Motif de la sanction',
                  labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
            ElevatedButton(
              onPressed: () async {
                final admin = context.read<AppProvider>().user;
                if (admin != null) {
                  Navigator.pop(context);
                  await provider.approveReport(
                    report.id,
                    admin.id,
                    selectedSanction,
                    reasonController.text.isEmpty ? 'Violation des conditions' : reasonController.text
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sanction appliquée avec succès')));
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== SUBSCRIPTIONS TAB ==========
class _SubscriptionsTab extends StatelessWidget {
  final List<User> users;
  final VoidCallback onRefresh;
  const _SubscriptionsTab({required this.users, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subscriptions_outlined, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Aucun abonnement Premium+ actif', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final isActive = u.isSubscriptionActive ?? false;
        final statusColor = isActive ? AppColors.accentGreen : AppColors.accentRed;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.workspace_premium, color: AppColors.getTextColor(context), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PREMIUM+',
                            style: TextStyle(color: AppColors.accentOrange, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      isActive ? 'ACTIF' : 'EXPIRÉ',
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: AppColors.getTextColor(context).withValues(alpha: 0.10)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date d\'expiration', style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.54))),
                      const SizedBox(height: 4),
                      Text(
                        u.subscriptionExpiry != null 
                          ? DateFormat('dd MMMM yyyy').format(u.subscriptionExpiry!)
                          : 'N/A',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context).withValues(alpha: 0.70)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _handleProlong(context, u),
                    icon: const Icon(Icons.more_time, size: 18),
                    label: const Text('Prolonger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleProlong(BuildContext context, User u) async {
    final now = DateTime.now();
    DateTime newExpiry;
    
    if (u.subscriptionExpiry != null && u.subscriptionExpiry!.isAfter(now)) {
      newExpiry = u.subscriptionExpiry!.add(const Duration(days: 30));
    } else {
      newExpiry = now.add(const Duration(days: 30));
    }

    await DatabaseHelper().updateUser(u.id, {
      'subscriptionExpiry': newExpiry.toIso8601String(),
    });

    await DatabaseHelper().addLog(
      userId: 1, // Admin
      action: 'Prolongation abonnement',
      details: 'Abonnement de ${u.displayName} prolongé de 30 jours (Expire: ${DateFormat('dd/MM/yyyy').format(newExpiry)})',
      type: 'subscription',
    );

    onRefresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abonnement de ${u.displayName} prolongé jusqu\'au ${DateFormat('dd/MM/yyyy').format(newExpiry)}'),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }
}

// ========== COMMISSIONS TAB ==========
class _CommissionsTab extends StatefulWidget {
  final List<Map<String, dynamic>> commissions;
  const _CommissionsTab({required this.commissions});

  @override
  State<_CommissionsTab> createState() => _CommissionsTabState();
}

class _CommissionsTabState extends State<_CommissionsTab> {
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    if (widget.commissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Aucune commission enregistrée', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    final filtered = widget.commissions.where((c) {
      if (_filterType == 'all') return true;
      return c['type'] == _filterType;
    }).toList();

    double total = filtered.fold(0, (s, c) => s + (c['montant'] as num).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                Text('Total des revenus collectés', style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Text(
                  '${NumberFormat.decimalPattern('fr').format(total)} FCFA', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.getTextColor(context).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${filtered.length} transactions au total',
                    style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Détails des transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
              _buildFilterDropdown(),
            ],
          ),
          const SizedBox(height: 16),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final c = filtered[index];
              return _buildCommissionItem(context, c);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.getTextColor(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterType,
          dropdownColor: AppColors.getCardColor(context),
          style: TextStyle(color: AppColors.getTextColor(context), fontSize: 12),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'loyer', child: Text('Loyers')),
            DropdownMenuItem(value: 'service', child: Text('Services')),
          ],
          onChanged: (v) => setState(() => _filterType = v!),
        ),
      ),
    );
  }

  Widget _buildCommissionItem(BuildContext context, Map<String, dynamic> c) {
    final dateStr = c['date'] ?? DateTime.now().toIso8601String();
    final date = DateTime.parse(dateStr);
    final isLoyer = c['type'] == 'loyer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isLoyer ? AppColors.accentOrange : AppColors.accentBlue).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLoyer ? Icons.home_work_outlined : Icons.build_outlined,
              color: isLoyer ? AppColors.accentOrange : AppColors.accentBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['description'] ?? 'Commission',
                  style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMMM yyyy, HH:mm', 'fr').format(date),
                  style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.5)),
                ),
                if (c['transaction_id'] != null)
                  Text(
                    'Transaction ID: #${c['transaction_id']} | Locataire: #${c['locataire_id']}',
                    style: TextStyle(fontSize: 10, color: AppColors.accentOrange.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${NumberFormat.decimalPattern('fr').format(c['montant'])}', style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (c['taux_applique'] != null)
                Text(
                  'Taux: ${(c['taux_applique'] * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogsTab extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const _LogsTab({required this.logs});

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  String _filterType = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredLogs = widget.logs.where((log) {
      final matchesType = _filterType == 'all' || log['type'] == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          (log['action']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (log['details']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesType && matchesSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: AppColors.getTextColor(context), fontSize: 13),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: AppColors.getTextColor(context).withValues(alpha: 0.54), size: 20),
                      hintText: 'Rechercher un journal...',
                      hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.30)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    dropdownColor: AppColors.getCardColor(context),
                    style: TextStyle(color: AppColors.getTextColor(context), fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(value: 'property', child: Text('Biens')),
                      DropdownMenuItem(value: 'subscription', child: Text('Abonnements')),
                      DropdownMenuItem(value: 'system', child: Text('Système')),
                      DropdownMenuItem(value: 'auth', child: Text('Authentification')),
                    ],
                    onChanged: (v) => setState(() => _filterType = v!),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('Aucun journal trouvé', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildLogItem(context, log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    final timestamp = log['timestamp'] != null ? DateTime.parse(log['timestamp']) : DateTime.now();
    IconData icon;
    Color color;

    switch (log['type']) {
      case 'property':
        icon = Icons.home_work_outlined;
        color = AppColors.accentBlue;
        break;
      case 'subscription':
        icon = Icons.workspace_premium;
        color = AppColors.accentOrange;
        break;
      case 'auth':
        icon = Icons.lock_open;
        color = AppColors.accentGreen;
        break;
      case 'system':
      default:
        icon = Icons.settings_suggest_outlined;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log['action'] ?? 'Action',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), fontSize: 14),
                    ),
                    Text(
                      DateFormat('HH:mm', 'fr').format(timestamp),
                      style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log['details'] ?? '',
                  style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy', 'fr').format(timestamp),
                      style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline, size: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      'ID User: ${log['userId'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
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

class _SettingsTab extends StatelessWidget {
  final List<Map<String, dynamic>> settings;
  final VoidCallback onRefresh;
  const _SettingsTab({required this.settings, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> settingsMap = { for (var e in settings) e['key'] as String : e['value'] };
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Informations Générales', Icons.info_outline),
        _buildSettingItem(
          context,
          'Nom de la Plateforme', 
          'Nom affiché dans l\'application et les emails.',
          true, 
          null,
          trailing: Text(settingsMap['platform_name'] ?? 'Immo Bénin', style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'platform_name', 'Nom de la plateforme', settingsMap['platform_name'] ?? 'Immo Bénin')
        ),
        _buildSettingItem(
          context,
          'Email du Support', 
          'Adresse utilisée pour les demandes d\'aide.',
          true, 
          null,
          trailing: Text(settingsMap['support_email'] ?? 'support@immobenin.bj', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
          onTap: () => _showEditDialog(context, 'support_email', 'Email du support', settingsMap['support_email'] ?? 'support@immobenin.bj')
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('Finances & Commissions', Icons.monetization_on_outlined),
        _buildSettingItem(
          context,
          'Taux Commission Normal (%)', 
          'Pourcentage prélevé par défaut.',
          true, 
          null,
          trailing: Text('${settingsMap['commission_rate'] ?? 5}%', style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'commission_rate', 'Taux normal (%)', settingsMap['commission_rate'] ?? '5')
        ),
        _buildSettingItem(
          context,
          'Taux Commission Premium+ (%)', 
          'Taux réduit pour les abonnés actifs.',
          true, 
          null,
          trailing: Text('${settingsMap['commission_rate_premium'] ?? 3}%', style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'commission_rate_premium', 'Taux Premium (%)', settingsMap['commission_rate_premium'] ?? '3')
        ),
        _buildSettingItem(
          context,
          'Prix Abonnement Premium+ (FCFA)', 
          'Prix mensuel du pack Premium+.',
          true, 
          null,
          trailing: Text('${settingsMap['premium_price'] ?? 25000} FCFA', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'premium_price', 'Prix Premium+ (FCFA)', settingsMap['premium_price'] ?? '25000')
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('Règles & Limitations', Icons.rule),
        _buildSettingItem(
          context,
          'Max biens (Offre Gratuite)', 
          'Nombre max de biens publiables sans abonnement.',
          true, 
          null,
          trailing: Text(settingsMap['max_free_listings'] ?? '5', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'max_free_listings', 'Max biens gratuits', settingsMap['max_free_listings'] ?? '5')
        ),
        _buildSettingItem(
          context,
          'Seuil de Signalements', 
          'Nombre de signalements avant suspension auto.',
          true, 
          null,
          trailing: Text(settingsMap['report_threshold'] ?? '5', style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(context, 'report_threshold', 'Seuil signalements', settingsMap['report_threshold'] ?? '5')
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('Communications', Icons.notifications_active_outlined),
        _buildSettingItem(
          context,
          'Notifications Push Globales', 
          'Activer ou désactiver les envois push.',
          settingsMap['push_notifications'] == 'true', 
          (v) => _update(context, 'push_notifications', v.toString())
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('Sécurité & Accès', Icons.security),
        _buildSettingItem(context, 'Certification KYC Obligatoire', 'Les propriétaires doivent être certifiés pour publier', true, (v) {}),
        _buildSettingItem(context, 'Validation Manuelle des Biens', 'L\'admin doit valider chaque annonce', true, (v) {}),
        
        const SizedBox(height: 32),
        _buildSectionHeader('Partenaires & Services', Icons.handshake),
        _buildSettingItem(
          context, 
          'Gérer les Partenaires', 
          'Ajouter, modifier ou supprimer des partenaires', 
          false, 
          null,
          trailing: Icon(Icons.arrow_forward_ios, color: AppColors.getTextColor(context).withValues(alpha: 0.24), size: 16),
          onTap: () => _showPartnersManagement(context),
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('Maintenance & Données', Icons.system_update_alt),
        _buildSettingItem(context, 'Mode Maintenance', 'Désactive l\'accès public à l\'application', false, (v) {}),
        _buildSettingItem(
          context, 
          'Exporter les Données', 
          'Télécharger la configuration en JSON', 
          false, 
          null,
          trailing: const Icon(Icons.download, color: AppColors.accentOrange, size: 20),
          onTap: () => _exportSettings(context, settingsMap),
        ),
        _buildSettingItem(
          context, 
          'Réinitialiser la plateforme', 
          'Effacer tous les paramètres système', 
          false, 
          null,
          trailing: const Icon(Icons.refresh, color: AppColors.accentRed, size: 20),
          onTap: () => _showResetDialog(context),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showPartnersManagement(BuildContext context) async {
    final db = DatabaseHelper();
    final partners = await db.getAllPartners();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gestion Partenaires', style: TextStyle(color: AppColors.getTextColor(context))),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.accentGreen),
                onPressed: () async {
                  await _showAddPartnerDialog(context);
                  final updated = await db.getAllPartners();
                  setState(() => partners.clear());
                  setState(() => partners.addAll(updated));
                },
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: partners.isEmpty
              ? Center(child: Text('Aucun partenaire', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.54))))
              : ListView.builder(
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final p = partners[index];
                    return ListTile(
                      title: Text(p['name'], style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                      subtitle: Text(p['service'], style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.accentOrange, size: 18),
                            onPressed: () async {
                              await _showAddPartnerDialog(context, partner: p);
                              final updated = await db.getAllPartners();
                              setState(() => partners.clear());
                              setState(() => partners.addAll(updated));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.accentRed, size: 18),
                            onPressed: () async {
                              await db.deletePartner(p['id']);
                              final updated = await db.getAllPartners();
                              setState(() => partners.clear());
                              setState(() => partners.addAll(updated));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPartnerDialog(BuildContext context, {Map<String, dynamic>? partner}) async {
    final nameCtrl = TextEditingController(text: partner?['name']);
    final serviceCtrl = TextEditingController(text: partner?['service']);
    final contactCtrl = TextEditingController(text: partner?['contact']);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text(partner == null ? 'Ajouter un partenaire' : 'Modifier le partenaire', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Nom', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60))), style: TextStyle(color: AppColors.getTextColor(context))),
            TextField(controller: serviceCtrl, decoration: InputDecoration(labelText: 'Service', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60))), style: TextStyle(color: AppColors.getTextColor(context))),
            TextField(controller: contactCtrl, decoration: InputDecoration(labelText: 'Contact', labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60))), style: TextStyle(color: AppColors.getTextColor(context))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final db = DatabaseHelper();
              if (partner == null) {
                await db.addPartner({
                  'name': nameCtrl.text,
                  'service': serviceCtrl.text,
                  'contact': contactCtrl.text,
                });
              } else {
                await db.updatePartner(partner['id'], {
                  'name': nameCtrl.text,
                  'service': serviceCtrl.text,
                  'contact': contactCtrl.text,
                });
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Réinitialiser tout ?', style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text('Cela remettra tous les paramètres aux valeurs d\'usine. Cette action est irréversible.', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().setList('settings', []);
              await DatabaseHelper().addLog(userId: 1, action: 'Reset Paramètres', details: 'Tous les paramètres ont été réinitialisés.', type: 'system');
              if (!context.mounted) return;
              Navigator.pop(context);
              onRefresh();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Confirmer Reset'),
          ),
        ],
      ),
    );
  }

  void _exportSettings(BuildContext context, Map<String, dynamic> settings) {
    final json = const JsonEncoder.withIndent('  ').convert(settings);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Export Configuration (JSON)', style: TextStyle(color: AppColors.getTextColor(context))),
        content: SingleChildScrollView(
          child: SelectableText(json, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, String title, String subtitle, bool value, dynamic onChanged, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70), fontSize: 12)),
      trailing: trailing ?? (onChanged != null ? Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accentOrange) : null),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentOrange, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String key, String title, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text('Modifier $title', style: TextStyle(color: AppColors.getTextColor(context))),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: AppColors.getTextColor(context)),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60)),
            hintStyle: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.38)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.70)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _update(context, key, ctrl.text);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Future<void> _update(BuildContext context, String key, String value) async {
    final db = DatabaseHelper();
    final List<dynamic> currentList = await db.getList('settings');
    
    final index = currentList.indexWhere((e) => (e as Map)['key'] == key);
    if (index >= 0) {
      currentList[index] = {'key': key, 'value': value};
    } else {
      currentList.add({'key': key, 'value': value});
    }
    
    await db.setList('settings', currentList);
    onRefresh();
  }
}


class _SupportTab extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;
  final VoidCallback onRefresh;

  const _SupportTab({required this.tickets, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Tickets de Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: 16),
          if (tickets.isEmpty)
            const Expanded(child: Center(child: Text('Aucun ticket de support pour le moment.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      title: Text(ticket['sujet'] ?? 'Sans sujet', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket['email'] ?? 'Sans email', style: const TextStyle(fontSize: 12, color: AppColors.accentOrange)),
                          const SizedBox(height: 4),
                          Text(ticket['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Statut: ${ticket['status']}', style: TextStyle(color: ticket['status'] == 'ouvert' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.reply, color: AppColors.accentOrange),
                        onPressed: () => _showReplyDialog(context, ticket),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context, Map<String, dynamic> ticket) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        title: Text('Répondre à: ${ticket['sujet']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Message original:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(ticket['message'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            TextField(
              controller: replyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Votre réponse...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.isEmpty) return;
              
              final db = DatabaseHelper();
              await db.updateTicket(ticket['id'], {
                'status': 'fermé',
                'response': replyCtrl.text,
                'respondedAt': DateTime.now().toIso8601String(),
              });

              final users = await db.getAllUsers();
              final user = users.firstWhere(
                (u) => u.email.toLowerCase() == ticket['email'].toString().toLowerCase(), 
                orElse: () => User(id: 0, nom: '', prenom: '', email: '', password: '', telephone: '', role: '')
              );

              if (user.id != 0) {
                await NotificationService.addNotification(
                  userId: user.id,
                  title: 'Réponse Support : ${ticket['sujet']}',
                  body: replyCtrl.text,
                  type: 'support_reply',
                );
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              onRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Réponse envoyée et ticket fermé.'), backgroundColor: AppColors.accentGreen)
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Envoyer la réponse'),
          ),
        ],
      ),
    );
  }
}
class _AdminMessagesTab extends StatefulWidget {
  @override
  State<_AdminMessagesTab> createState() => _AdminMessagesTabState();
}

class _AdminMessagesTabState extends State<_AdminMessagesTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadConversations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadConversations());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      // API directe → même BDD que le web
      final raw = await ApiService.getConversations();
      _conversations = raw.cast<Map<String, dynamic>>();
    } catch (_) {
      // Fallback local
      final db = DatabaseHelper();
      if (!mounted) return;
      final user = context.read<AppProvider>().user;
      if (user != null) _conversations = await db.getConversations(user.id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingWidget(message: 'Chargement des messages...'));
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined, size: 64, color: AppColors.accentBlue),
            ),
            const SizedBox(height: 24),
            Text('Aucune conversation', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text('Les messages des locataires et propriétaires apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 14)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          // L'API retourne partnerId/partnerName (pas un objet User)
          final partnerId   = (conv['partnerId']   as num?)?.toInt() ?? 0;
          final partnerName = conv['partnerName']  as String? ?? 'Utilisateur';
          final lastMsg     = conv['lastMessage']  as Map<String, dynamic>?;
          final unread      = (conv['unreadCount'] as num?)?.toInt() ?? 0;
          final lastText    = lastMsg?['content'] ?? lastMsg?['text'] ?? '';
          final initials    = partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'U';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.getCardColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accentOrange.withValues(alpha: 0.2),
                    child: Text(initials, style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 0, top: 0,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.red,
                        child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                ],
              ),
              title: Text(
                partnerName,
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                  color: AppColors.getTextColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                lastText.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.60)),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColors.getTextColor(context).withValues(alpha: 0.24)),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      receiverId: partnerId,
                      receiverName: partnerName,
                    ),
                  ),
                );
                _loadConversations();
              },
            ),
          );
        },
      ),
    );
  }
}