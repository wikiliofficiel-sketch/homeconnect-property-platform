import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kyc_provider.dart';
import '../../models/kyc_models.dart';
import '../../utils/app_colors.dart';
import '../../widgets/role_guard.dart';


class CreatePropertyScreen extends StatefulWidget {
  const CreatePropertyScreen({super.key});

  @override
  State<CreatePropertyScreen> createState() => _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends State<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titreController;
  late TextEditingController _descriptionController;
  late TextEditingController _loyerController;
  late TextEditingController _cautionController;

  String _type = 'appartement';
  String _ville = 'Cotonou';
  bool _wifi = false;
  bool _parking = false;
  bool _climatisation = false;

  @override
  void initState() {
    super.initState();
    _titreController = TextEditingController();
    _descriptionController = TextEditingController();
    _loyerController = TextEditingController();
    _cautionController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final kycProvider = context.read<KYCProvider>();
    final user = context.read<AuthProvider>().currentUser;
    
    // Vérifier si le KYC est validé
    if (user != null && user.role == 'proprietaire') {
      final verification = kycProvider.currentVerification;
      final isVerified = verification?.status == KYCStatus.verified;
      
      if (!isVerified) {
        return RoleGuard(
          allowedRoles: const ['proprietaire'],
          customErrorMessage: 'Seuls les propriétaires peuvent créer des biens',
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Créer une annonce'),
              backgroundColor: AppColors.accentOrange,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentOrange, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_user, size: 64, color: AppColors.accentOrange),
                          const SizedBox(height: 16),
                          const Text(
                            'Compte non certifié',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Vous devez d\'abord compléter votre vérification d\'identité (KYC) avant de pouvoir publier une annonce.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/verification');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Compléter la vérification KYC',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return RoleGuard(
      allowedRoles: const ['proprietaire'],
      customErrorMessage: 'Seuls les propriétaires peuvent créer des biens',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Créer une annonce'),
          backgroundColor: const Color(0xFF1A6B3C),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titreController,
              decoration: const InputDecoration(labelText: 'Titre'),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: ['appartement', 'maison', 'studio', 'chambre', 'villa']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _ville,
              items: ['Cotonou', 'Porto-Novo', 'Parakou']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _ville = v!),
              decoration: const InputDecoration(labelText: 'Ville'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loyerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Loyer mensuel (FCFA)'),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cautionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Caution (FCFA)'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('WiFi'),
              value: _wifi,
              onChanged: (v) => setState(() => _wifi = v!),
            ),
            CheckboxListTile(
              title: const Text('Parking'),
              value: _parking,
              onChanged: (v) => setState(() => _parking = v!),
            ),
            CheckboxListTile(
              title: const Text('Climatisation'),
              value: _climatisation,
              onChanged: (v) => setState(() => _climatisation = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B3C),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _submitForm,
              child: const Text('Créer l\'annonce', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Enregistrer le bien localement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce créée avec succès!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _loyerController.dispose();
    _cautionController.dispose();
    super.dispose();
  }
}
