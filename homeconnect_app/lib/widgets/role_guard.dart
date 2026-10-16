import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Widget de protection d'accès par rôle
/// Affiche une page d'erreur si l'utilisateur n'a pas le rôle requis
class RoleGuard extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;
  final String? customErrorMessage;

  const RoleGuard({
    required this.child,
    required this.allowedRoles,
    this.customErrorMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, appProvider, _) {
        final user = appProvider.user;
        
        // Si pas d'utilisateur connecté
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    '❌ Accès refusé',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vous devez être connecté',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                    icon: const Icon(Icons.login),
                    label: const Text('Aller à la connexion'),
                  ),
                ],
              ),
            ),
          );
        }

        // Si le rôle n'est pas autorisé
        if (!allowedRoles.contains(user.role)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    '❌ Accès refusé',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customErrorMessage ?? 
                    'Vous n\'avez pas les droits pour accéder à cette page.\n'
                    'Rôle requis: ${allowedRoles.join(", ")}\n'
                    'Votre rôle: ${user.role}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour'),
                  ),
                ],
              ),
            ),
          );
        }

        // Rôle autorisé - afficher le contenu
        return child;
      },
    );
  }
}
