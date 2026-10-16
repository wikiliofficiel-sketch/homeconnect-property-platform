import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kyc_provider.dart';
import '../../models/kyc_models.dart' show KYCDocument;

class AdminKYCDashboardScreen extends StatefulWidget {
  const AdminKYCDashboardScreen({super.key});

  @override
  State<AdminKYCDashboardScreen> createState() =>
      _AdminKYCDashboardScreenState();
}

class _AdminKYCDashboardScreenState extends State<AdminKYCDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<KYCProvider>().loadUserDocuments(1); // Load all docs
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion KYC'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Approuvés'),
            Tab(text: 'Tous'),
          ],
        ),
      ),
      body: Consumer<KYCProvider>(
        builder: (context, kycProvider, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(kycProvider),
              _buildApprovedTab(kycProvider),
              _buildAllTab(kycProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(KYCProvider kycProvider) {
    final pending =
        kycProvider.documents.where((d) => d.status == 'en_attente').toList();

    if (pending.isEmpty) {
      return const Center(
        child: Text('Aucun document en attente'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final doc = pending[index];
        return _buildDocumentCard(
          context,
          doc,
          kycProvider,
          isPending: true,
        );
      },
    );
  }

  Widget _buildApprovedTab(KYCProvider kycProvider) {
    final approved =
        kycProvider.documents.where((d) => d.status == 'verifiee').toList();

    if (approved.isEmpty) {
      return const Center(
        child: Text('Aucun document approuvé'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: approved.length,
      itemBuilder: (context, index) {
        final doc = approved[index];
        return _buildDocumentCard(context, doc, kycProvider);
      },
    );
  }

  Widget _buildAllTab(KYCProvider kycProvider) {
    if (kycProvider.documents.isEmpty) {
      return const Center(
        child: Text('Aucun document'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: kycProvider.documents.length,
      itemBuilder: (context, index) {
        final doc = kycProvider.documents[index];
        return _buildDocumentCard(context, doc, kycProvider);
      },
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    KYCDocument doc,
    KYCProvider kycProvider, {
    bool isPending = false,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (doc.status) {
      case 'verifiee':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approuvé';
        break;
      case 'rejetee':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Rejeté';
        break;
      case 'suspendue':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = 'Suspendu';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
        statusText = 'En attente';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document ID: ${doc.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Utilisateur ID: ${doc.userId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  avatar: Icon(statusIcon, size: 16),
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Détails
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      doc.type.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Numéro',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      doc.documentNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${doc.uploadedAt.day}/${doc.uploadedAt.month}/${doc.uploadedAt.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),

            if (doc.verificationNotes != null && doc.verificationNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Raison du rejet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doc.verificationNotes ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Actions
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _approveDocument(context, doc, kycProvider),
                      icon: const Icon(Icons.check),
                      label: const Text('Approuver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _rejectDocument(context, doc, kycProvider),
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              )
            else
              Center(
                child: Text(
                  'Statut: $statusText',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _approveDocument(
    BuildContext context,
    KYCDocument doc,
    KYCProvider kycProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver le document?'),
        content: const Text('Êtes-vous sûr de vouloir approuver ce document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await kycProvider.approveDocument(
                documentId: doc.id,
                adminId: 1,
              );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document approuvé'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
  }

  void _rejectDocument(
    BuildContext context,
    KYCDocument doc,
    KYCProvider kycProvider,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Raison du rejet:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Entrez la raison...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer une raison')),
                );
                return;
              }

              final success = await kycProvider.rejectDocument(
                documentId: doc.id,
                adminId: 1,
                rejectionReason: reasonController.text,
              );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document rejeté'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
