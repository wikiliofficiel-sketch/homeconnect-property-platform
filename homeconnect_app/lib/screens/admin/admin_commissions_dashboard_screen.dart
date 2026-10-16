import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/commission_provider.dart';
import '../../models/commission_models.dart';

class AdminCommissionsDashboardScreen extends StatefulWidget {
  const AdminCommissionsDashboardScreen({super.key});

  @override
  State<AdminCommissionsDashboardScreen> createState() =>
      _AdminCommissionsDashboardScreenState();
}

class _AdminCommissionsDashboardScreenState
    extends State<AdminCommissionsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommissionProvider>().loadAllCommissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commissions'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Créditées'),
            Tab(text: 'Toutes'),
          ],
        ),
      ),
      body: Consumer<CommissionProvider>(
        builder: (context, commissionProvider, _) {
          final stats = commissionProvider.getCommissionStats();

          return Column(
            children: [
              // Statistiques
              _buildStatsSection(stats),

              // Onglets
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingTab(commissionProvider),
                    _buildCreditedTab(commissionProvider),
                    _buildAllTab(commissionProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.green[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé des commissions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBigStatCard(
                  'Total gagné',
                  '${(stats['totalEarned'] as num).toStringAsFixed(0)} FCFA',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBigStatCard(
                  'En attente',
                  '${(stats['totalPending'] as num).toStringAsFixed(0)} FCFA',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBigStatCard(
                  'Créditées',
                  '${(stats['totalCredited'] as num).toStringAsFixed(0)} FCFA',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigStatCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab(CommissionProvider commissionProvider) {
    final pending = commissionProvider.transactions
        .where((c) => c.status == CommissionStatus.pending)
        .toList();

    if (pending.isEmpty) {
      return const Center(child: Text('Aucune commission en attente'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final commission = pending[index];
        return _buildCommissionCard(
          context,
          commission,
          commissionProvider,
          isPending: true,
        );
      },
    );
  }

  Widget _buildCreditedTab(CommissionProvider commissionProvider) {
    final completed = commissionProvider.transactions
        .where((c) => c.status == CommissionStatus.completed)
        .toList();

    if (completed.isEmpty) {
      return const Center(child: Text('Aucune commission créditée'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: completed.length,
      itemBuilder: (context, index) {
        final commission = completed[index];
        return _buildCommissionCard(context, commission, commissionProvider);
      },
    );
  }

  Widget _buildAllTab(CommissionProvider commissionProvider) {
    if (commissionProvider.transactions.isEmpty) {
      return const Center(child: Text('Aucune commission'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: commissionProvider.transactions.length,
      itemBuilder: (context, index) {
        final commission = commissionProvider.transactions[index];
        return _buildCommissionCard(context, commission, commissionProvider);
      },
    );
  }

  Widget _buildCommissionCard(
    BuildContext context,
    CommissionTransaction commission,
    CommissionProvider commissionProvider, {
    bool isPending = false,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (commission.status) {
      case CommissionStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Créditée';
        break;
      case CommissionStatus.refunded:
        statusColor = Colors.purple;
        statusIcon = Icons.account_balance_wallet;
        statusText = 'Retirée';
        break;
      case CommissionStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'En attente';
        break;
      case CommissionStatus.processing:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        statusText = 'En traitement';
        break;
      case CommissionStatus.disputed:
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        statusText = 'Contestée';
        break;
    }

    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.monetization_on;
    String typeLabel = commission.type.toString().split('.').last;

    switch (commission.type) {
      case CommissionType.propertyListing:
        typeColor = Colors.blue;
        typeIcon = Icons.home;
        typeLabel = 'Listing propriété';
        break;
      case CommissionType.applicationFee:
        typeColor = Colors.green;
        typeIcon = Icons.handshake;
        typeLabel = 'Location réussie';
        break;
      case CommissionType.premiumFeature:
        typeColor = Colors.purple;
        typeIcon = Icons.star;
        typeLabel = 'Service premium';
        break;
      default:
        break;
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
                      Row(
                        children: [
                          Icon(typeIcon, color: typeColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Utilisateur ID: ${commission.userId}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  avatar: Icon(statusIcon, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Montant
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Montant',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '${commission.amount.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taux appliqué',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '${(commission.rate ?? 0.0).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acquise le',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '${commission.createdAt.day}/${commission.createdAt.month}/${commission.createdAt.year}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                if (commission.completedAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Créditée le',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        '${commission.completedAt!.day}/${commission.completedAt!.month}/${commission.completedAt!.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
              ],
            ),

            if (commission.notes != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Note: ${commission.notes}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),

            // Actions
            if (isPending)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _creditCommission(
                          context,
                          commission,
                          commissionProvider,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Créditer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _creditCommission(
    BuildContext context,
    CommissionTransaction commission,
    CommissionProvider commissionProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créditer la commission?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Montant: '),
            Text(
              '${commission.amount.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Êtes-vous sûr de vouloir créditer cette commission?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success =
                  await commissionProvider.creditCommission(commission.id);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Commission créditée'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Créditer'),
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
