import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/property_provider.dart';
import '../../providers/application_provider.dart';
import '../../utils/app_colors.dart';

class PropertyDetailManagementScreen extends StatefulWidget {
  final int propertyId;

  const PropertyDetailManagementScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<PropertyDetailManagementScreen> createState() =>
      _PropertyDetailManagementScreenState();
}

class _PropertyDetailManagementScreenState
    extends State<PropertyDetailManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    Future.microtask(() {
      if (!mounted) return;
      context
          .read<ApplicationProvider>()
          .loadApplicationsByProperty(widget.propertyId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final property = context
        .read<PropertyProvider>()
        .getProperty(widget.propertyId);
    final stats = context
        .read<PropertyProvider>()
        .getPropertyStats(widget.propertyId);

    if (property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Propriété')),
        body: const Center(child: Text('Propriété non trouvée')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(property.titre),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Détails'),
            Tab(icon: Icon(Icons.mail), text: 'Candidatures'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DetailsTab(property: property),
          _ApplicationsTab(propertyId: widget.propertyId),
          _StatsTab(property: property, stats: stats),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: DÉTAILS
// ============================================================
class _DetailsTab extends StatefulWidget {
  final dynamic property;

  const _DetailsTab({required this.property});

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.property.titre);
    _locationController = TextEditingController(text: widget.property.lieu);
    _priceController = TextEditingController(text: widget.property.prix.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _isEditing ? _cancelEdit : _startEdit,
                icon: Icon(_isEditing ? Icons.close : Icons.edit),
                label: Text(_isEditing ? 'Annuler' : 'Modifier'),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.check),
                    label: const Text('Enregistrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Formulaire
          _buildTextField('Titre', _titleController, enabled: _isEditing),
          const SizedBox(height: 12),
          _buildTextField('Lieu', _locationController, enabled: _isEditing),
          const SizedBox(height: 12),
          _buildTextField('Prix (FCFA)', _priceController, enabled: _isEditing),
          const SizedBox(height: 16),

          // Informations
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _InfoRow('Type', widget.property.type ?? 'N/A'),
                _InfoRow('Pièces', '${widget.property.pieces ?? 0}'),
                _InfoRow(
                  'Statut',
                  widget.property.status ?? 'inconnu',
                ),
                _InfoRow(
                  'Créée le',
                  widget.property.createdAt?.toString().split(' ')[0] ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bouton Supprimer
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text(
                'Supprimer la propriété',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  void _startEdit() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    _titleController.text = widget.property.titre;
    _locationController.text = widget.property.lieu;
    _priceController.text = widget.property.prix.toString();
    setState(() {
      _isEditing = false;
    });
  }

  void _saveChanges() async {
    final success = await context.read<PropertyProvider>().updateProperty(
      propertyId: widget.property.id,
      title: _titleController.text,
      location: _locationController.text,
      price: int.tryParse(_priceController.text) ?? widget.property.prix,
    );

    if (!mounted) return;
    if (success) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propriété mise à jour')),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la propriété'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette propriété? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PropertyProvider>().deleteProperty(widget.property.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: CANDIDATURES
// ============================================================
class _ApplicationsTab extends StatelessWidget {
  final int propertyId;

  const _ApplicationsTab({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ApplicationProvider>(
        builder: (context, appProvider, _) {
          final apps = appProvider.applications
              .where((a) => a.propertyId == propertyId)
              .toList();

          if (apps.isEmpty) {
            return const Center(
              child: Text('Aucune candidature pour cette propriété'),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return _ApplicationItem(application: app);
            },
          );
        },
      ),
    );
  }
}

class _ApplicationItem extends StatelessWidget {
  final dynamic application;

  const _ApplicationItem({required this.application});

  @override
  Widget build(BuildContext context) {
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
              const Text('Candidature'),
              Chip(
                label: Text(application.status),
                backgroundColor: application.status == 'approved'
                    ? Colors.green
                    : application.status == 'rejected'
                        ? Colors.red
                        : Colors.orange,
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (application.coverLetter != null)
            Text(
              'Lettre: ${application.coverLetter}',
              style: const TextStyle(fontSize: 11),
            ),
          const SizedBox(height: 12),
          if (application.status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await context
                        .read<ApplicationProvider>()
                        .rejectApplication(
                          applicationId: application.id,
                          ownerId: 1,
                        );
                  },
                  child: const Text('Refuser', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await context
                        .read<ApplicationProvider>()
                        .approveApplication(
                          applicationId: application.id,
                          ownerId: 1,
                        );
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Approuver'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 3: STATISTIQUES
// ============================================================
class _StatsTab extends StatelessWidget {
  final dynamic property;
  final dynamic stats;

  const _StatsTab({required this.property, required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _StatRow(
                  'Vues totales',
                  '${stats?.totalViews ?? property.views ?? 0}',
                ),
                _StatRow(
                  'Vues ce mois',
                  '${stats?.thisMonthViews ?? 0}',
                ),
                _StatRow(
                  'Candidatures',
                  '${stats?.applicationCount ?? 0}',
                ),
                _StatRow(
                  'Candidatures actives',
                  '${stats?.activeApplicationCount ?? 0}',
                ),
                _StatRow(
                  'Note moyenne',
                  '${(stats?.averageRating ?? 0.0).toStringAsFixed(1)}/5',
                ),
                _StatRow(
                  'Évaluations',
                  '${stats?.ratingCount ?? 0}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!(property.isHighlighted ?? false))
            ElevatedButton.icon(
              onPressed: () async {
                await context
                    .read<PropertyProvider>()
                    .highlightProperty(property.id, 7);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Propriété mise en avant')),
                );
              },
              icon: const Icon(Icons.star),
              label: const Text('Mettre en avant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
