import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kyc_provider.dart';
import '../providers/app_provider.dart';
import '../models/kyc_models.dart';

class KYCVerificationScreen extends StatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().user;
    if (user != null) {
      context.read<KYCProvider>().loadUserVerification(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification KYC'),
        centerTitle: true,
      ),
      body: Consumer2<KYCProvider, AppProvider>(
        builder: (context, kycProvider, appProvider, _) {
          final user = appProvider.user;
          if (user == null) {
            return const Center(
              child: Text('Utilisateur non trouvé'),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Documents section
                  const Text(
                    'Documents requis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    DocumentType.passport,
                    DocumentType.nationalId,
                    DocumentType.drivingLicense,
                  ]
                      .map((docType) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDocumentCard(
                          context,
                          docType,
                          kycProvider,
                          user.id,
                        ),
                      ))
                      ,
                  const SizedBox(height: 24),
                  
                  // Error messages
                  if (kycProvider.errorMessage != null &&
                      kycProvider.errorMessage!.isNotEmpty)
                    _buildErrorMessage(kycProvider.errorMessage!),
                  
                  const SizedBox(height: 16),
                  
                  // Tips section
                  _buildTipsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentType docType,
    KYCProvider kycProvider,
    int userId,
  ) {
    final docTitle = docType.toString().split('.').last;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Téléchargez votre $docTitle',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: const Text('Non soumis'),
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  avatar: const Icon(Icons.file_upload, color: Colors.grey, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showUploadDialog(
                  context,
                  docType,
                  kycProvider,
                  userId,
                ),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Télécharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(
    BuildContext context,
    DocumentType docType,
    KYCProvider kycProvider,
    int userId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Soumettre: ${docType.toString().split('.').last}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Veuillez prendre une photo claire de votre document',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Simulé: En production, utiliser image_picker
                await kycProvider.addDocument(
                  userId: userId,
                  type: docType,
                  documentNumber: 'DOC123456',
                  frontImageUrl: 'mock_image_front_${docType}_${DateTime.now()}.jpg',
                  backImageUrl: 'mock_image_back_${docType}_${DateTime.now()}.jpg',
                  issueDate: DateTime(2020),
                  expiryDate: DateTime.now().add(const Duration(days: 365)),
                  issuingCountry: 'Bénin',
                  fullName: 'Test User',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Simuler l\'upload'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[100],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Card(
      color: Colors.blue[50],
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conseils pour la vérification réussie',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Document doit être valide et en cours de validité\n'
              '• La photo doit être claire et bien éclairée\n'
              '• Votre visage doit être visible sur le selfie\n'
              '• Pas de filtres ou modifications sur les photos',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
