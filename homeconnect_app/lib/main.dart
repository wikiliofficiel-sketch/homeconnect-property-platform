import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:feda_flutter/feda_flutter.dart';
import 'config/app_config.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/kyc_provider.dart';
import 'providers/report_provider.dart';
import 'providers/commission_provider.dart';
import 'providers/advanced_chat_provider.dart';
import 'providers/property_provider.dart';
import 'providers/application_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/evaluation_provider.dart';
import 'providers/locataire_provider.dart';
import 'providers/support_provider.dart';
import 'providers/proprietaire_provider.dart';
import 'providers/admin_provider.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/proprietaire/proprietaire_dashboard_screen.dart';
import 'screens/proprietaire/proprietaire_dashboard_enhanced_screen.dart';
import 'screens/proprietaire/add_property_screen.dart';
import 'screens/proprietaire/create_property_screen.dart';
import 'screens/proprietaire/contracts_screen.dart';
import 'screens/proprietaire/property_detail_management_screen.dart';
import 'screens/proprietaire/property_form_screen.dart';
import 'screens/proprietaire/applications_management_screen.dart';
import 'screens/locataire/locataire_dashboard_screen.dart';
import 'screens/locataire/locataire_dashboard_enhanced_screen.dart';
import 'screens/partenaire/partenaire_dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/property_detail_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/tenant/chat_screen.dart';
import 'screens/evaluation/evaluations_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/admin/kyc_management_screen.dart';
import 'screens/admin/admin_sanctions_dashboard_screen.dart';
import 'screens/community/community_forum_screen.dart';
import 'screens/help/help_center_screen.dart';
import 'screens/partenaire/partners_directory_screen.dart';
import 'screens/report_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'providers/partnership_provider.dart';
import 'config/app_secrets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('fr_BJ', null);
  await initializeDateFormatting('en_US', null);
  
  // Initialisation FedaPay (Mode Sandbox pour test réel)
  FedaFlutter.applyConfig(
    apiKey: AppSecrets.fedapayKey,
    environment: AppSecrets.isProduction ? ApiEnvironment.live : ApiEnvironment.sandbox,
  );
  
  await NotificationService.init();

  // Synchronisation périodique toutes les 30 secondes APRÈS login uniquement
  // (démarrée depuis AppProvider.login() une fois connecté)


  runApp(const HomeConnectApp());
}

class HomeConnectApp extends StatelessWidget {
  const HomeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => KYCProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => CommissionProvider()),
        ChangeNotifierProvider(create: (_) => AdvancedChatProvider()),
        ChangeNotifierProvider(create: (_) => PropertyProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => EvaluationProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => TenantReportProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
        ChangeNotifierProvider(create: (_) => ProprietaireProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => PartnershipProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) => MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[50],
            primarySwatch: Colors.orange,
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.backgroundDark,
            primarySwatch: Colors.orange,
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr', 'BJ'),
            Locale('fr', 'FR'),
            Locale('en', 'US'),
          ],
          // Fon n'est pas un locale Flutter standard — on utilise fr_BJ pour les
          // widgets Material, mais AppProvider.locale garde Locale('fon') pour
          // afficher le texte en Fon dans l'UI personnalisée.
          locale: appProvider.locale.languageCode == 'fon'
              ? const Locale('fr', 'BJ')
              : appProvider.locale,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale?.languageCode == 'fon') return const Locale('fr', 'BJ');
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale?.languageCode) return supported;
            }
            return supportedLocales.first;
          },
        
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/proprietaire': (context) => const ProprietaireDashboardScreen(),
          '/proprietaire-enhanced': (context) => const ProprietaireDashboardEnhancedScreen(),
          '/locataire': (context) => const LocataireDashboardScreen(),
          '/locataire-enhanced': (context) => const LocataireDashboardEnhancedScreen(),
          '/partenaire': (context) => const PartenaireDashboardScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/add-property': (context) => const AddPropertyScreen(),
          '/create-property': (context) => const CreatePropertyScreen(),
          '/contracts': (context) => const ContractsScreen(),
          '/messages': (context) => const MessagesScreen(),
          '/search': (context) => const SearchScreen(),
          '/verification': (context) => const VerificationScreen(),
          '/admin-kyc': (context) => const KYCManagementScreen(),
          '/admin-sanctions': (context) => const AdminSanctionsDashboardScreen(),
          '/add-property-form': (context) => const PropertyFormScreen(),
          '/applications-management': (context) => const ApplicationsManagementScreen(),
          '/community': (context) => const CommunityForumScreen(),
          '/help': (context) => const HelpCenterScreen(),
          '/partners-directory': (context) => const PartnersDirectoryScreen(),
          '/report': (context) => const ReportScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/change-password': (context) => const ChangePasswordScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name?.startsWith('/property/') ?? false) {
            final propertyId = int.tryParse(settings.name!.replaceFirst('/property/', ''));
            if (propertyId != null) {
              return MaterialPageRoute(
                builder: (context) => PropertyDetailsScreen(propertyId: propertyId),
              );
            }
          }
          if (settings.name?.startsWith('/property-detail/') ?? false) {
            final propertyId = int.tryParse(settings.name!.replaceFirst('/property-detail/', ''));
            if (propertyId != null) {
              return MaterialPageRoute(
                builder: (context) => PropertyDetailManagementScreen(propertyId: propertyId),
              );
            }
          }
          if (settings.name?.startsWith('/edit-property/') ?? false) {
            final propertyId = int.tryParse(settings.name!.replaceFirst('/edit-property/', ''));
            if (propertyId != null) {
              return MaterialPageRoute(
                builder: (context) => PropertyFormScreen(propertyId: propertyId),
              );
            }
          }
          if (settings.name?.startsWith('/applications/') ?? false) {
            final propertyId = int.tryParse(settings.name!.replaceFirst('/applications/', ''));
            if (propertyId != null) {
              return MaterialPageRoute(
                builder: (context) => ApplicationsManagementScreen(propertyId: propertyId),
              );
            }
          }
          if (settings.name?.startsWith('/chat/') ?? false) {
            final receiverId = int.tryParse(settings.name!.replaceFirst('/chat/', ''));
            if (receiverId != null) {
              return MaterialPageRoute(
                builder: (context) => ChatScreen(receiverId: receiverId),
              );
            }
          }
          if (settings.name?.startsWith('/evaluations/') ?? false) {
            final userId = int.tryParse(settings.name!.replaceFirst('/evaluations/', ''));
            if (userId != null) {
              return MaterialPageRoute(
                builder: (context) => EvaluationsScreen(userId: userId),
              );
            }
          }
          return null;
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      ),
    ),
    );
  }
}