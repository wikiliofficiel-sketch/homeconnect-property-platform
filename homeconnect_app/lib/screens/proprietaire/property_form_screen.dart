import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/property_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kyc_provider.dart';
import '../../models/kyc_models.dart';
import '../../utils/app_colors.dart';

class PropertyFormScreen extends StatefulWidget {
  final int? propertyId;

  const PropertyFormScreen({super.key, this.propertyId});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _piecesController;

  String _selectedType = 'Appartement';
  String _selectedStatus = 'available';

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController();
    _locationController = TextEditingController();
    _priceController = TextEditingController();
    _descriptionController = TextEditingController();
    _piecesController = TextEditingController();

    if (widget.propertyId != null) {
      _loadProperty();
    }
  }

  void _loadProperty() {
    final property = context
        .read<PropertyProvider>()
        .getProperty(widget.propertyId!);

    if (property != null) {
      _titleController.text = property.titre;
      _locationController.text = property.lieu;
      _priceController.text = property.prix.toString();
      _descriptionController.text = '';
      _piecesController.text = property.pieces.toString();
      _selectedType = property.type;
      _selectedStatus = property.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _piecesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.propertyId != null;
    final kycProvider = context.read<KYCProvider>();
    final user = context.read<AuthProvider>().currentUser;
    
    // Vérifier si le KYC est validé pour les nouvelles propriétés
    if (user != null && user.role == 'proprietaire' && !isEditing) {
      final verification = kycProvider.currentVerification;
      final isVerified = verification?.status == KYCStatus.verified;
      
      if (!isVerified) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ajouter une propriété'),
            centerTitle: true,
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
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la propriété' : 'Ajouter une propriété'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              'Titre',
              _titleController,
              icon: Icons.home,
              hint: 'Ex: Bel appartement T2 à Cotonou',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Lieu',
              _locationController,
              icon: Icons.location_on,
              hint: 'Ex: Akron, Cotonou',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Prix (FCFA)',
              _priceController,
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              hint: 'Ex: 500000',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Nombre de pièces',
              _piecesController,
              icon: Icons.meeting_room,
              keyboardType: TextInputType.number,
              hint: 'Ex: 2',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Description',
              _descriptionController,
              icon: Icons.description,
              hint: 'Décrivez votre propriété...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              'Type de propriété',
              _selectedType,
              ['Appartement', 'Maison', 'Villa', 'Studio', 'Bureau'],
              (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              'Statut',
              _selectedStatus,
              ['available', 'rented', 'maintenance'],
              (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  isEditing ? 'Mettre à jour' : 'Créer la propriété',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            items: options
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (_titleController.text.isEmpty || _locationController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final title = _titleController.text;
    final location = _locationController.text;
    final price = int.tryParse(_priceController.text) ?? 0;
    final pieces = int.tryParse(_piecesController.text) ?? 0;

    try {
      if (widget.propertyId != null) {
        // Mise à jour
        final success = await context.read<PropertyProvider>().updateProperty(
              propertyId: widget.propertyId!,
              title: title,
              location: location,
              price: price,
            );

        if (!mounted) return;
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Propriété mise à jour avec succès')),
          );
        }
      } else {
        // Création
        await context.read<PropertyProvider>().createProperty(
              title: title,
              location: location,
              price: price,
              type: _selectedType,
              rooms: pieces,
              ownerId: 1,
          );
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propriété créée avec succès')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}
