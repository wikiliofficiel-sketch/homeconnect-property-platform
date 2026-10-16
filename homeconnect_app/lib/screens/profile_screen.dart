// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/design_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final user = appProvider.user;

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: AppBar(
        title: Text(appProvider.translate('profile')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.accentOrange.withValues(alpha: 0.1),
              child: const Icon(Icons.person, size: 50, color: AppColors.accentOrange),
            ),
            const SizedBox(height: 20),
            Text(
              '${user?.prenom ?? ""} ${user?.nom ?? ""}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? "",
              style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 40),
            _buildOption(
              context,
              icon: Icons.edit_outlined,
              title: appProvider.translate('edit_profile'),
              onTap: () => Navigator.pushNamed(context, '/edit-profile'),
            ),
            _buildOption(
              context,
              icon: Icons.lock_outline,
              title: appProvider.translate('change_password'),
              onTap: () => Navigator.pushNamed(context, '/change-password'),
            ),
            _buildOption(
              context,
              icon: Icons.language_outlined,
              title: appProvider.translate('language'),
              onTap: () => _showLanguageDialog(context),
            ),
            _buildOption(
              context,
              icon: Icons.dark_mode_outlined,
              title: appProvider.translate('dark_mode'),
              trailing: Switch(
                value: appProvider.isDarkMode,
                onChanged: (value) => appProvider.toggleDarkMode(),
                activeThumbColor: AppColors.accentOrange,
              ),
            ),
            const SizedBox(height: 40),
            _buildOption(
              context,
              icon: Icons.logout,
              title: appProvider.translate('logout'),
              color: AppColors.accentRed,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.getTextColor(context)),
      title: Text(title, style: TextStyle(color: color ?? AppColors.getTextColor(context))),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextColor(context).withValues(alpha: 0.3)),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appProvider.translate('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Français'),
              onTap: () {
                appProvider.setLocale(const Locale('fr'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                appProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Fon'),
              onTap: () {
                appProvider.setLocale(const Locale('fon'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.read<AppProvider>().translate('logout'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
        content: Text(context.read<AppProvider>().translate('logout_homeconnect_desc'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.read<AppProvider>().translate('cancel'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5)))),
          ModernButton(
            text: context.read<AppProvider>().translate('quit'),
            color: AppColors.accentRed,
            onPressed: () async {
              Navigator.pop(context);
              await _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await context.read<AppProvider>().logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
