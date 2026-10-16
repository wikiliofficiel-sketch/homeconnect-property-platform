// lib/widgets/app_drawer.dart
// ============================================================
// Drawer avec menu de l'app et déconnexion - Design professionnel
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../screens/auth/login_screen.dart';
import '../utils/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          final user = appProvider.user;
          
          return Column(
            children: [
              // En-tête du drawer avec design moderne
              _DrawerHeader(
                user: user,
                onClose: () => Navigator.pop(context),
              ),
              
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Menu par rôle avec sections
                    if (appProvider.isProprietaire) ...[
                      _MenuSection(
                        title: appProvider.translate('owner_space'),
                        icon: Icons.business_center_rounded,
                        children: [
                          _DrawerItem(
                            icon: Icons.home_rounded,
                            label: appProvider.translate('my_properties'),
                            onTap: () => _navigateAndClose(context, '/my-properties'),
                          ),
                          _DrawerItem(
                            icon: Icons.assignment_rounded,
                            label: appProvider.translate('applications'),
                            onTap: () => _navigateAndClose(context, '/applications'),
                          ),
                          _DrawerItem(
                            icon: Icons.description_rounded,
                            label: appProvider.translate('contracts'),
                            onTap: () => _navigateAndClose(context, '/contracts'),
                          ),
                          _DrawerItem(
                            icon: Icons.add_box_rounded,
                            label: appProvider.translate('add_property'),
                            onTap: () => _navigateAndClose(context, '/create-property'),
                          ),
                        ],
                      ),
                    ] else if (appProvider.isLocataire) ...[
                      _MenuSection(
                        title: appProvider.translate('search_placeholder').split(' ')[0],
                        icon: Icons.search_rounded,
                        children: [
                          _DrawerItem(
                            icon: Icons.search_rounded,
                            label: appProvider.translate('search_placeholder'),
                            onTap: () => _navigateAndClose(context, '/search'),
                          ),
                          _DrawerItem(
                            icon: Icons.favorite_rounded,
                            label: 'Mes favoris',
                            onTap: () => _navigateAndClose(context, '/favorites'),
                            badge: '3',
                          ),
                          _DrawerItem(
                            icon: Icons.assignment_rounded,
                            label: appProvider.translate('applications'),
                            onTap: () => _navigateAndClose(context, '/applications'),
                          ),
                          _DrawerItem(
                            icon: Icons.calendar_today_rounded,
                            label: 'Mes visites',
                            onTap: () => _navigateAndClose(context, '/visits'),
                          ),
                        ],
                      ),
                    ] else if (appProvider.isAdmin) ...[
                      _MenuSection(
                        title: appProvider.translate('admin_panel'),
                        icon: Icons.admin_panel_settings_rounded,
                        children: [
                          _DrawerItem(
                            icon: Icons.people_rounded,
                            label: appProvider.translate('users'),
                            onTap: () => _navigateAndClose(context, '/admin/users'),
                          ),
                          _DrawerItem(
                            icon: Icons.home_rounded,
                            label: appProvider.translate('properties'),
                            onTap: () => _navigateAndClose(context, '/admin/properties'),
                          ),
                          _DrawerItem(
                            icon: Icons.warning_rounded,
                            label: appProvider.translate('reports'),
                            onTap: () => _navigateAndClose(context, '/admin/reports'),
                            badge: '12',
                          ),
                          _DrawerItem(
                            icon: Icons.analytics_rounded,
                            label: 'Statistiques',
                            onTap: () => _navigateAndClose(context, '/admin/stats'),
                          ),
                        ],
                      ),
                    ],

                    // Section Communication
                    _MenuSection(
                      title: 'Communication',
                      icon: Icons.chat_rounded,
                      children: [
                        _DrawerItem(
                          icon: Icons.mail_rounded,
                          label: 'Messages',
                          onTap: () => _navigateAndClose(context, '/messages'),
                          badge: '2',
                        ),
                        _DrawerItem(
                          icon: Icons.notifications_rounded,
                          label: 'Notifications',
                          onTap: () => _navigateAndClose(context, '/notifications'),
                        ),
                      ],
                    ),

                    // Section Compte
                    _MenuSection(
                      title: appProvider.translate('profile'),
                      icon: Icons.person_rounded,
                      children: [
                        _DrawerItem(
                          icon: Icons.person_outline_rounded,
                          label: appProvider.translate('profile'),
                          onTap: () => _navigateAndClose(context, '/profile'),
                        ),
                        _DrawerItem(
                          icon: Icons.star_rounded,
                          label: 'Mes évaluations',
                          onTap: () => _navigateAndClose(context, '/evaluations'),
                        ),
                        _DrawerItem(
                          icon: Icons.subscriptions_rounded,
                          label: 'Mon abonnement',
                          onTap: () => _navigateAndClose(context, '/abonnement'),
                          badge: null,
                        ),
                        _DrawerItem(
                          icon: Icons.verified_rounded,
                          label: 'Vérification',
                          onTap: () => _navigateAndClose(context, '/verification'),
                          badge: user?.isVerified == true ? 'Vérifié' : null,
                        ),
                      ],
                    ),

                    // Section Support
                    _MenuSection(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      children: [
                        _DrawerItem(
                          icon: Icons.help_rounded,
                          label: 'Centre d\'aide',
                          onTap: () => _navigateAndClose(context, '/help'),
                        ),
                        _DrawerItem(
                          icon: Icons.feedback_rounded,
                          label: 'Nous contacter',
                          onTap: () => _navigateAndClose(context, '/contact'),
                        ),
                        _DrawerItem(
                          icon: Icons.info_rounded,
                          label: 'À propos',
                          onTap: () => _navigateAndClose(context, '/about'),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Switch mode sombre
                    _ThemeSwitchTile(
                      isDarkMode: appProvider.isDarkMode,
                      onChanged: (_) => appProvider.toggleDarkMode(),
                    ),

                    const SizedBox(height: 16),

                    // Version
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Version 2.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Bouton déconnexion
              _LogoutButton(
                onLogout: () {
                  appProvider.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Déconnecté avec succès'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateAndClose(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }
}

// ===== EN-TÊTE MODERNE DU DRAWER =====
class _DrawerHeader extends StatelessWidget {
  final dynamic user;
  final VoidCallback onClose;

  const _DrawerHeader({
    required this.user,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.nomComplet ?? 'Utilisateur';
    final email = user?.email ?? 'email@homeconnect.local';
    final role = user?.role ?? 'utilisateur';
    final isVerified = user?.isVerified ?? false;

    String roleLabel;
    Color roleColor;
    
    switch (role) {
      case 'proprietaire':
        roleLabel = 'Propriétaire';
        roleColor = AppColors.ctaOrange;
        break;
      case 'admin':
        roleLabel = 'Administrateur';
        roleColor = AppColors.primaryBlue;
        break;
      case 'locataire':
      default:
        roleLabel = 'Locataire';
        roleColor = AppColors.success;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getScaffoldBackground(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton fermeture
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundLight,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.getTextColor(context)),
                      onPressed: onClose,
                      splashRadius: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Avatar
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ctaOrange, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.backgroundNeutral,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ctaOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: roleColor,
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== SECTION DE MENU AVEC TITRE =====
class _MenuSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _MenuSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.ctaOrange),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

// ===== ITEM DE MENU AVEC BADGE =====
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppColors.textMedium),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getTextColor(context),
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge == 'Premium' 
                    ? AppColors.ctaOrange.withValues(alpha: 0.1)
                    : badge == 'Vérifié'
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.ctaOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badge == 'Premium'
                      ? AppColors.ctaOrange
                      : badge == 'Vérifié'
                          ? AppColors.success
                          : AppColors.ctaOrange,
                ),
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      hoverColor: AppColors.ctaOrange.withValues(alpha: 0.05),
      splashColor: AppColors.ctaOrange.withValues(alpha: 0.1),
    );
  }
}

// ===== SWITCH THEME AVEC DESIGN MODERNE =====
class _ThemeSwitchTile extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const _ThemeSwitchTile({
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.textDark.withValues(alpha: 0.05) : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          children: [
            Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
              color: isDarkMode ? Colors.white : AppColors.ctaOrange,
            ),
            const SizedBox(width: 12),
            Text(
              isDarkMode ? 'Mode sombre' : 'Mode clair',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        value: isDarkMode,
        onChanged: onChanged,
        activeThumbColor: AppColors.ctaOrange,
        activeTrackColor: AppColors.ctaOrange.withValues(alpha: 0.3),
      ),
    );
  }
}

// ===== BOUTON DE DÉCONNEXION MODERNE =====
class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;

  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.error,
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _showLogoutDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                context.read<AppProvider>().translate('logout'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.read<AppProvider>().translate('logout'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Êtes-vous sûr de vouloir vous déconnecter ?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ctaOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.ctaOrange),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Déconnexion'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}