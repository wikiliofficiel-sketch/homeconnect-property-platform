import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../providers/app_provider.dart';
import '../models/report_sanction_models.dart';

class ReportScreen extends StatefulWidget {
  final int? targetPropertyId;
  final int? targetUserId;

  const ReportScreen({
    super.key,
    this.targetPropertyId,
    this.targetUserId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  ReportType _selectedType = ReportType.fraudulentListing;

  final reportTypeLabels = {
    ReportType.fraudulentListing: 'Annonce frauduleuse',
    ReportType.inappropriateContent: 'Contenu inapproprié',
    ReportType.abusiveUser: 'Utilisateur abusif',
    ReportType.fakePics: 'Photos falsifiées',
    ReportType.scam: 'Arnaque',
    ReportType.spam: 'Spam',
    ReportType.unsafeMeeting: 'Rencontre non sécurisée',
    ReportType.unwantedContact: 'Contact non désiré',
    ReportType.discriminatory: 'Contenu discriminatoire',
    ReportType.other: 'Autre',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un problème'),
        centerTitle: true,
      ),
      body: Consumer2<ReportProvider, AppProvider>(
        builder: (context, reportProvider, appProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signaler un problème',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aidez-nous à maintenir une plateforme sûre',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Type de signalement
                const Text(
                  'Type de signalement *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTypeSelector(),
                const SizedBox(height: 20),

                // Titre
                const Text(
                  'Titre du signalement *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Résumé court du problème',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  'Description détaillée *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  minLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Décrivez le problème en détail...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Avertissements
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Les faux signalements peuvent entraîner une suspension\n'
                        '• Soyez aussi détaillé que possible\n'
                        '• Les signalements seront enquêtés par nos modérateurs',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Messages
                if (reportProvider.errorMessage?.isNotEmpty ?? false)
                  _buildErrorMessage(reportProvider.errorMessage ?? ''),
                const SizedBox(height: 16),

                // Boutons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: reportProvider.isLoading
                        ? null
                        : () => _submitReport(context, reportProvider, appProvider),
                    child: reportProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Soumettre le signalement'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector() {
    return RadioGroup<ReportType>(
      groupValue: _selectedType,
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedType = value);
        }
      },
      child: Column(
        children: reportTypeLabels.entries.map((entry) {
          return RadioListTile<ReportType>(
            title: Text(entry.value),
            value: entry.key,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  void _submitReport(
    BuildContext context,
    ReportProvider reportProvider,
    AppProvider appProvider,
  ) async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final user = appProvider.user;
    if (user == null) return;

    if (widget.targetPropertyId == null && widget.targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Aucune cible trouvée')),
      );
      return;
    }

    final targetUserId = widget.targetUserId;
    if (targetUserId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Cible non trouvée')),
        );
      }
      return;
    }

    await reportProvider.submitReport(
      reporterId: user.id,
      targetUserId: targetUserId,
      type: _selectedType,
      title: _titleController.text,
      description: _descriptionController.text,
      targetPropertyId: widget.targetPropertyId,
      attachments: [],
    );

    if (!context.mounted) return;
    if ((reportProvider.errorMessage ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement envoyé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) Navigator.pop(context);
      });
    }
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
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
