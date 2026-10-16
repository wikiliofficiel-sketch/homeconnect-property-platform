import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../models/report_sanction_models.dart';

class AdminSanctionsDashboardScreen extends StatefulWidget {
  const AdminSanctionsDashboardScreen({super.key});

  @override
  State<AdminSanctionsDashboardScreen> createState() =>
      _AdminSanctionsDashboardScreenState();
}

class _AdminSanctionsDashboardScreenState
    extends State<AdminSanctionsDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final int _adminId = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    context.read<ReportProvider>().loadAllSanctions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Sanctions'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actives'),
            Tab(text: 'Appels'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final active = provider.sanctions
              .where((s) => s.isCurrentlyActive)
              .toList();
          final inactive = provider.sanctions
              .where((s) => !s.isCurrentlyActive)
              .toList();

          return Column(
            children: [
              _buildStatsBar(provider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveSanctionsTab(provider, active),
                    _buildAppealTab(provider),
                    _buildHistoryTab(provider, inactive),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Barre de statistiques
  Widget _buildStatsBar(ReportProvider provider) {
    final activeCount = provider.sanctions.where((s) => s.isCurrentlyActive).length;
    final appealsCount = provider.sanctionAppeals
        .where((a) => a.status == 'pending')
        .length;
    final permanentCount = provider.sanctions
        .where((s) => s.type == SanctionType.banned)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard('Total', '${provider.sanctions.length}', Colors.blue),
            const SizedBox(width: 8),
            _buildStatCard('Actives', '$activeCount', Colors.orange),
            const SizedBox(width: 8),
            _buildStatCard('Appels', '$appealsCount', Colors.purple),
            const SizedBox(width: 8),
            _buildStatCard('Bans', '$permanentCount', Colors.red),
          ],
        ),
      ),
    );
  }

  /// Carte de statistique
  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Onglet Sanctions Actives
  Widget _buildActiveSanctionsTab(
      ReportProvider provider, List<Sanction> active) {
    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Aucune sanction active'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final sanction = active[index];
        return _buildSanctionCard(context, sanction, provider);
      },
    );
  }

  /// Onglet Appels
  Widget _buildAppealTab(ReportProvider provider) {
    final appeals = provider.sanctionAppeals;

    if (appeals.isEmpty) {
      return const Center(child: Text('Aucun appel enregistré'));
    }

    final pending = appeals.where((a) => a.status == 'pending').toList();
    final approved = appeals.where((a) => a.status == 'approved').toList();
    final rejected = appeals.where((a) => a.status == 'rejected').toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pending.isNotEmpty) ...[
          _buildAppealSection('En attente', pending, provider, Colors.orange),
          const SizedBox(height: 16),
        ],
        if (approved.isNotEmpty) ...[
          _buildAppealSection('Approuvés', approved, provider, Colors.green),
          const SizedBox(height: 16),
        ],
        if (rejected.isNotEmpty) ...[
          _buildAppealSection('Rejetés', rejected, provider, Colors.red),
        ],
      ],
    );
  }

  /// Section d'appels
  Widget _buildAppealSection(String title, List<SanctionAppeal> appeals,
      ReportProvider provider, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...appeals.map((a) => _buildAppealCard(a, provider)),
      ],
    );
  }

  /// Carte d'appel
  Widget _buildAppealCard(SanctionAppeal appeal, ReportProvider provider) {
    final sanction = provider.sanctions.cast<Sanction?>().firstWhere(
      (s) => s?.id == appeal.sanctionId,
      orElse: () => null,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Utilisateur #${appeal.userId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sanction != null 
                          ? 'Sanction: ${sanction.typeLabel}'
                          : 'Sanction inconnue (#${appeal.sanctionId})',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (appeal.approved == null)
                        ? Colors.orange.withValues(alpha: 0.1)
                        : (appeal.approved!)
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appeal.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: (appeal.approved == null)
                          ? Colors.orange
                          : (appeal.approved!)
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Raison de l\'appel:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(appeal.reason, style: const TextStyle(fontSize: 14)),
            if (appeal.adminNotes != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Notes Admin:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(appeal.adminNotes!, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
            ],
            if (appeal.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _handleAppealAction(context, appeal.id, false),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Rejeter'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleAppealAction(context, appeal.id, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approuver'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAppealAction(BuildContext context, int appealId, bool approve) async {
    final provider = context.read<ReportProvider>();
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approuver l\'appel' : 'Rejeter l\'appel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous ${approve ? 'approuver' : 'rejeter'} cet appel ?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: approve ? Colors.green : Colors.red),
            child: Text(approve ? 'Approuver' : 'Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success;
      if (approve) {
        success = await provider.approveAppeal(appealId, _adminId, notesController.text);
      } else {
        success = await provider.rejectAppeal(appealId, _adminId, notesController.text);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Action effectuée avec succès' : 'Une erreur est survenue'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// Onglet Historique
  Widget _buildHistoryTab(ReportProvider provider, List<Sanction> inactive) {
    if (inactive.isEmpty) {
      return const Center(child: Text('Aucune sanction dans l\'historique'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: inactive.length,
      itemBuilder: (context, index) {
        final sanction = inactive[index];
        return _buildSanctionCard(context, sanction, provider);
      },
    );
  }

  /// Carte de sanction
  Widget _buildSanctionCard(
      BuildContext context, Sanction sanction, ReportProvider provider) {
    Color typeColor;
    IconData typeIcon;

    switch (sanction.type) {
      case SanctionType.banned:
        typeColor = Colors.red;
        typeIcon = Icons.block;
        break;
      case SanctionType.suspension30Days:
        typeColor = Colors.orange;
        typeIcon = Icons.pause_circle;
        break;
      case SanctionType.suspension7Days:
        typeColor = Colors.amber;
        typeIcon = Icons.pause_circle;
        break;
      case SanctionType.suspension3Days:
        typeColor = Colors.yellow[800]!;
        typeIcon = Icons.pause_circle;
        break;
      case SanctionType.warning:
        typeColor = Colors.blue;
        typeIcon = Icons.warning;
        break;
    }

    final isActive = sanction.isCurrentlyActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? typeColor.withValues(alpha: 0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      elevation: isActive ? 2 : 0,
      color: isActive ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sanction.typeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Utilisateur #${sanction.userId}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'EXPIRÉE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              sanction.reason,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('APPLIQUÉE LE', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '${sanction.appliedAt.day}/${sanction.appliedAt.month}/${sanction.appliedAt.year}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (sanction.expiresAt != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXPIRE LE', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${sanction.expiresAt!.day}/${sanction.expiresAt!.month}/${sanction.expiresAt!.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (isActive && sanction.daysRemaining != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sanction.daysRemaining} j restants',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLiftSanction(context, sanction.id),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Lever la sanction prématurément'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleLiftSanction(BuildContext context, int sanctionId) async {
    final provider = context.read<ReportProvider>();
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lever la sanction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Êtes-vous sûr de vouloir lever cette sanction avant son expiration ?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif de la levée',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir un motif')));
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.liftSanction(sanctionId, _adminId, reasonController.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Sanction levée' : 'Erreur lors de la levée'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}