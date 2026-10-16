import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/commission_provider.dart';
import '../../models/commission_models.dart';

/// Dashboard Admin pour gérer les commissions
class AdminCommissionsDashboardScreen extends StatefulWidget {
  const AdminCommissionsDashboardScreen({super.key});

  @override
  State<AdminCommissionsDashboardScreen> createState() =>
      _AdminCommissionsDashboardScreenState();
}

class _AdminCommissionsDashboardScreenState
    extends State<AdminCommissionsDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    final provider = context.read<CommissionProvider>();
    provider.loadAllTransactions();
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
        title: const Text('Gestion des Commissions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Retraits'),
            Tab(text: 'Statistiques'),
          ],
        ),
      ),
      body: Consumer<CommissionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionsTab(context, provider),
              _buildWithdrawalsTab(context, provider),
              _buildStatsTab(context, provider),
            ],
          );
        },
      ),
    );
  }

  /// Onglet Transactions
  Widget _buildTransactionsTab(
      BuildContext context, CommissionProvider provider) {
    if (provider.transactions.isEmpty) {
      return const Center(child: Text('Aucune transaction'));
    }

    // Grouper par utilisateur
    final byUser = <int, List<CommissionTransaction>>{};
    for (var t in provider.transactions) {
      byUser.putIfAbsent(t.userId, () => []).add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: byUser.length,
      itemBuilder: (context, index) {
        final userId = byUser.keys.toList()[index];
        final userTransactions = byUser[userId]!;
        final total = userTransactions.fold<double>(
            0, (sum, t) => sum + t.amount);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Utilisateur $userId',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: ${total.toStringAsFixed(2)} XOF',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...userTransactions
                    .map((t) => _buildTransactionRow(t))
                    ,
              ],
            ),
          ),
        );
      },
    );
  }

  /// Afficher une ligne de transaction
  Widget _buildTransactionRow(CommissionTransaction transaction) {
    final typeEmoji = {
          CommissionType.propertyListing: '🏠',
          CommissionType.applicationFee: '📝',
          CommissionType.transactionFee: '💳',
          CommissionType.withdraw: '💰',
          CommissionType.messagingFee: '💬',
          CommissionType.premiumFeature: '⭐',
        }[transaction.type] ??
        '•';

    final statusColor = {
          CommissionStatus.pending: Colors.orange,
          CommissionStatus.processing: Colors.blue,
          CommissionStatus.completed: Colors.green,
          CommissionStatus.refunded: Colors.grey,
          CommissionStatus.disputed: Colors.red,
        }[transaction.status] ??
        Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$typeEmoji ${transaction.description ?? transaction.type.toString().split('.').last}', style: const TextStyle(fontSize: 13),
                ),
                Text(
                  '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amount.toStringAsFixed(0)} XOF',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  transaction.status.toString().split('.').last,
                  style: TextStyle(fontSize: 10, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Onglet Retraits
  Widget _buildWithdrawalsTab(
      BuildContext context, CommissionProvider provider) {
    if (provider.withdrawals.isEmpty) {
      return const Center(child: Text('Aucun retrait'));
    }

    // Séparer par statut
    final pending = provider.withdrawals
        .where((w) => w.status == 'pending')
        .toList();
    final processing = provider.withdrawals
        .where((w) => w.status == 'processing')
        .toList();
    final completed = provider.withdrawals
        .where((w) => w.status == 'completed')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            const Text(
              'En attente',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...pending.map((w) => _buildWithdrawalCard(context, w, provider)),
            const SizedBox(height: 16),
          ],
          if (processing.isNotEmpty) ...[
            const Text(
              'En traitement',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...processing.map((w) => _buildWithdrawalCard(context, w, provider)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            const Text(
              'Complétés',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...completed.map((w) => _buildWithdrawalCard(context, w, provider)),
          ],
        ],
      ),
    );
  }

  /// Carte de retrait
  Widget _buildWithdrawalCard(BuildContext context,
      CommissionWithdrawal withdrawal, CommissionProvider provider) {
    final statusColor = {
          'pending': Colors.orange,
          'processing': Colors.blue,
          'completed': Colors.green,
          'failed': Colors.red,
        }[withdrawal.status] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${withdrawal.amount.toStringAsFixed(0)} XOF',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    withdrawal.status,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Utilisateur: ${withdrawal.userId}'),
            Text('Compte: ${withdrawal.bankAccount}'),
            Text('Banque: ${withdrawal.bankName}'),
            Text('Demandé: ${withdrawal.requestedAt.toString().split('.')[0]}'),
            if (withdrawal.status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => provider.rejectWithdrawal(
                          withdrawal.id, 'Rejeté par admin'),
                      child: const Text('Rejeter'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          provider.processWithdrawal(withdrawal.id),
                      child: const Text('Traiter'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Onglet Statistiques
  Widget _buildStatsTab(
      BuildContext context, CommissionProvider provider) {
    final total = provider.getTotalCommissions();
    final netRevenue = provider.getTotalNetRevenue();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard('Total des commissions', '${total.toStringAsFixed(0)} XOF',
              Colors.blue),
          _buildStatCard('Revenu net', '${netRevenue.toStringAsFixed(0)} XOF',
              Colors.green),
          _buildStatCard('Nombre de transactions',
              '${provider.transactions.length}', Colors.purple),
          _buildStatCard('Retraits en attente',
              '${provider.withdrawals.where((w) => w.status == 'pending').length}',
              Colors.orange),
        ],
      ),
    );
  }

  /// Carte statistique
  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 24, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
