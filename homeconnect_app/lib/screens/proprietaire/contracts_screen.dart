import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import '../../utils/app_colors.dart';
import '../../widgets/role_guard.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<Map<String, dynamic>> _contracts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final db = DatabaseHelper();
      // Récupérer les candidatures acceptées = contrats potentiels
      final candidatures = await db.getApplicationsForProprietaire(user.id);
      _contracts = candidatures
          .where((c) => c['statut'] == 'acceptee')
          .map((c) => {
                'id': c['id'],
                'reference': 'CTR-${c['id']}',
                'bien': c['bien'],
                'locataire': 'Locataire #${c['locataireId']}',
                'loyerMensuel': c['prix'],
                'statut': c['signed'] == true ? 'signe' : 'en_attente',
                'dateDebut': c['visiteDate'] ?? DateTime.now().toIso8601String(),
                'dateFin': null, // À définir lors de la signature
                'signedByProprietaire': c['signed'] == true,
                'propertyId': c['propertyId'],
                'locataireId': c['locataireId'],
              })
          .toList();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signContract(int contractId, int propertyId, int locataireId) async {
    try {
      final db = DatabaseHelper();
      // Mettre à jour la candidature comme "signée"
      await db.updateApplicationStatus(contractId, 'signee');
      
      // Ajouter une notification pour le locataire
      final locataire = await db.getUserById(locataireId);
      if (locataire != null) {
        await db.addNotification(
          locataireId,
          'Contrat signé',
          'Le propriétaire a signé le contrat pour votre candidature',
          'contrat',
        );
      }
      
      // Recharger les données
      await _loadContracts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contrat signé avec succès !'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _generatePdf(int contractId) async {
    // Simulation de génération PDF
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📄 Contrat PDF généré (simulation)'),
          backgroundColor: AppColors.accentBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['proprietaire'],
      customErrorMessage: 'Seuls les propriétaires peuvent gérer les contrats',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        appBar: AppBar(
          title: const Text('Mes contrats'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
          : _contracts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _contracts.length,
                  itemBuilder: (context, index) {
                    final contract = _contracts[index];
                    return _buildContractCard(contract);
                  },
                ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun contrat',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Les contrats apparaîtront ici après acceptation d\'une candidature',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractCard(Map<String, dynamic> contract) {
    final isSigned = contract['statut'] == 'signe';
    final reference = contract['reference'] ?? 'N/A';
    final bienTitre = contract['bien'] ?? 'Bien inconnu';
    final loyer = contract['loyerMensuel'] ?? 0;
    final dateDebut = contract['dateDebut'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(contract['dateDebut']))
        : 'À définir';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSigned ? AppColors.accentGreen.withValues(alpha: 0.3) : AppColors.accentOrange.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSigned ? AppColors.accentGreen.withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isSigned ? Icons.check_circle : Icons.pending_actions,
            color: isSigned ? AppColors.accentGreen : AppColors.accentOrange,
          ),
        ),
        title: Text(
          reference,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          bienTitre,
          style: const TextStyle(color: Colors.white70),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.monetization_on, '${loyer.toStringAsFixed(0)} FCFA/mois'),
              _buildInfoRow(Icons.person, contract['locataire'] ?? 'Locataire'),
              _buildInfoRow(Icons.calendar_today, 'Début: $dateDebut'),
              const SizedBox(height: 12),
              
              // Statut badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSigned ? AppColors.accentGreen.withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSigned ? Icons.check : Icons.pending,
                      size: 14,
                      color: isSigned ? AppColors.accentGreen : AppColors.accentOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSigned ? 'Signé ✓' : 'En attente de signature',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSigned ? AppColors.accentGreen : AppColors.accentOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Actions
              if (!isSigned) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _signContract(
                          contract['id'],
                          contract['propertyId'],
                          contract['locataireId'],
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Signer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generatePdf(contract['id']),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentBlue,
                          side: const BorderSide(color: AppColors.accentBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generatePdf(contract['id']),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Télécharger PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentBlue,
                          side: const BorderSide(color: AppColors.accentBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}