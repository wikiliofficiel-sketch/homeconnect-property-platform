import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/application_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/role_guard.dart';

class ApplicationsManagementScreen extends StatefulWidget {
  final int? propertyId;

  const ApplicationsManagementScreen({super.key, this.propertyId});

  @override
  State<ApplicationsManagementScreen> createState() =>
      _ApplicationsManagementScreenState();
}

class _ApplicationsManagementScreenState
    extends State<ApplicationsManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late ApplicationProvider _appProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _appProvider = context.read<ApplicationProvider>();

    Future.microtask(() {
      if (widget.propertyId != null) {
        _appProvider.loadApplicationsByProperty(widget.propertyId!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['proprietaire'],
      customErrorMessage: 'Seuls les propriétaires peuvent gérer les candidatures',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des candidatures'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.schedule), text: 'Visites'),
              Tab(icon: Icon(Icons.mail), text: 'Evolution'),
              Tab(icon: Icon(Icons.check_circle), text: 'Compteurs'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ScheduledVisitsTab(propertyId: widget.propertyId),
            _ApplicationsEvolutionTab(propertyId: widget.propertyId),
            _ApplicationsCountersTab(propertyId: widget.propertyId),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: VISITES PLANIFIÉES
// ============================================================
class _ScheduledVisitsTab extends StatelessWidget {
  final int? propertyId;

  const _ScheduledVisitsTab({this.propertyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          final visits = appProvider.scheduledVisits
              .where((v) =>
                  propertyId == null ||
                  appProvider.applications
                      .where((a) =>
                          a.id == v.applicationId &&
                          a.propertyId == propertyId)
                      .isNotEmpty)
              .toList();

          if (visits.isEmpty) {
            return const Center(
              child: Text('Aucune visite planifiée'),
            );
          }

          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return _VisitCard(visit: visit);
            },
          );
        },
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final dynamic visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final statusColor = visit.status == 'completed'
        ? Colors.green
        : visit.status == 'cancelled'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visite programmée',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(visit.status),
                backgroundColor: statusColor,
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoItem(
            icon: Icons.calendar_today,
            label: 'Date',
            value: visit.visitDate?.toString().split(' ')[0] ?? 'N/A',
          ),
          _InfoItem(
            icon: Icons.access_time,
            label: 'Heure',
            value: visit.visitTime ?? 'Non définie',
          ),
          if (visit.notes != null && visit.notes.isNotEmpty)
            _InfoItem(
              icon: Icons.note,
              label: 'Notes',
              value: visit.notes,
            ),
          const SizedBox(height: 12),
          if (visit.status == 'scheduled')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await context
                        .read<ApplicationProvider>()
                        .updateVisitStatus(visit.id, 'cancelled');
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context
                        .read<ApplicationProvider>()
                        .updateVisitStatus(visit.id, 'completed');
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: ÉVOLUTION DES CANDIDATURES
// ============================================================
class _ApplicationsEvolutionTab extends StatelessWidget {
  final int? propertyId;

  const _ApplicationsEvolutionTab({this.propertyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          final applications = propertyId == null
              ? appProvider.applications
              : appProvider.applications
                  .where((a) => a.propertyId == propertyId)
                  .toList();

          final stats = {
            'pending': applications.where((a) => a.status == 'pending').length,
            'approved': applications.where((a) => a.status == 'approved').length,
            'rejected': applications.where((a) => a.status == 'rejected').length,
          };

          return Column(
            children: [
              _StatsRow(label: 'En attente', count: stats['pending'] ?? 0, color: Colors.orange),
              _StatsRow(label: 'Approuvées', count: stats['approved'] ?? 0, color: Colors.green),
              _StatsRow(label: 'Refusées', count: stats['rejected'] ?? 0, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Détails',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (applications.isEmpty)
                const Center(child: Text('Aucune candidature'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                    final app = applications[index];
                    return _ApplicationDetailCard(application: app);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatsRow({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationDetailCard extends StatelessWidget {
  final dynamic application;

  const _ApplicationDetailCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final statusColor = application.status == 'approved'
        ? Colors.green
        : application.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('App #${0}'),
              Chip(
                label: Text(application.status),
                backgroundColor: statusColor,
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (application.coverLetter != null)
            Text(
              'Lettre: ${application.coverLetter}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 3: COMPTEURS
// ============================================================
class _ApplicationsCountersTab extends StatelessWidget {
  final int? propertyId;

  const _ApplicationsCountersTab({this.propertyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          final applications = propertyId == null
              ? appProvider.applications
              : appProvider.applications
                  .where((a) => a.propertyId == propertyId)
                  .toList();

          final counters = {
            'total': applications.length,
            'pending': applications.where((a) => a.status == 'pending').length,
            'approved': applications.where((a) => a.status == 'approved').length,
            'rejected': applications.where((a) => a.status == 'rejected').length,
            'visits_scheduled': appProvider.scheduledVisits
                .where((v) => v.status == 'scheduled')
                .length,
            'visits_completed': appProvider.scheduledVisits
                .where((v) => v.status == 'completed')
                .length,
          };

          return Column(
            children: [
              _CounterCard(label: 'Total candidatures', value: '${counters['total']}'),
              _CounterCard(label: 'Candidatures en attente', value: '${counters['pending']}', color: Colors.orange),
              _CounterCard(label: 'Candidatures approuvées', value: '${counters['approved']}', color: Colors.green),
              _CounterCard(label: 'Candidatures refusées', value: '${counters['rejected']}', color: Colors.red),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              _CounterCard(label: 'Visites programmées', value: '${counters['visits_scheduled']}', color: Colors.blue),
              _CounterCard(label: 'Visites complétées', value: '${counters['visits_completed']}', color: Colors.green),
            ],
          );
        },
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _CounterCard({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color ?? AppColors.borderColor,
          width: color != null ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
