import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_colors.dart';

import '../../widgets/design_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _successMessage; // Message venant de l'inscription

  @override
  void initState() {
    super.initState();
    // Lire le message passé en argument depuis RegisterScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        setState(() => _successMessage = args);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = context.read<AppProvider>();
    final success = await appProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final userRole = appProvider.user?.role ?? 'locataire';
      _navigateToDashboard(userRole);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appProvider.error), backgroundColor: AppColors.accentRed),
      );
    }
  }

  void _navigateToDashboard(String role) {
    if (role == 'proprietaire') {
      Navigator.pushReplacementNamed(context, '/proprietaire');
      return;
    }

    
    switch (role) {
      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      case 'locataire':
        Navigator.pushReplacementNamed(context, '/locataire');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/locataire');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(appProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, 
              color: AppColors.getTextColor(context)),
            onPressed: () => appProvider.toggleDarkMode(),
          ),
          PopupMenuButton<Locale>(
            icon: Icon(Icons.language, color: AppColors.getTextColor(context)),
            onSelected: (locale) => appProvider.setLocale(locale),
            itemBuilder: (context) => [
              const PopupMenuItem(value: Locale('fr'), child: Text('Français')),
              const PopupMenuItem(value: Locale('en'), child: Text('English')),
              const PopupMenuItem(value: Locale('fon'), child: Text('Fon')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Message de succès après inscription
                    if (_successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(color: Colors.green, fontSize: 13),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _successMessage = null),
                              child: const Icon(Icons.close, color: Colors.green, size: 18),
                            ),
                          ],
                        ),
                      ),

                    // Logo Section
                    const Icon(Icons.home_work_rounded, size: 80, color: AppColors.accentOrange),
                    const SizedBox(height: 24),
                    Text(
                      'HomeConnect',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), letterSpacing: 1.2),
                    ),
                    Text(
                      appProvider.translate('login_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 48),
                    
                    ModernTextField(
                      controller: _emailController,
                      label: appProvider.translate('email_label'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return appProvider.translate('email_required');
                        if (!value.contains('@')) return appProvider.translate('email_invalid');
                        return null;
                      },
                    ),
                    
                    ModernPasswordField(
                      controller: _passwordController,
                      label: appProvider.translate('password_label'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return appProvider.translate('password_required');
                        return null;
                      },
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context, appProvider),
                        child: Text(appProvider.translate('forgot_password'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    ModernButton(
                      text: appProvider.translate('login_title'),
                      isLoading: appProvider.isLoading,
                      onPressed: _handleLogin,
                    ),
                    
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${appProvider.translate('new_to_app')} ', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6))),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          child: Text(appProvider.translate('create_account'), style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context, AppProvider appProvider) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(appProvider.translate('reset_title'), style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appProvider.translate('reset_body'),
                style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7), fontSize: 14),
              ),
              const SizedBox(height: 20),
              ModernTextField(
                controller: emailController,
                label: appProvider.translate('email_label'),
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ),
          ModernButton(
            text: appProvider.translate('send_code'),
            onPressed: () {
              if (emailController.text.contains('@')) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email: ${emailController.text}'),
                    backgroundColor: AppColors.accentGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(appProvider.translate('email_invalid')), backgroundColor: AppColors.accentRed),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}