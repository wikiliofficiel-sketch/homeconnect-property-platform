import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/design_widgets.dart';
import '../../providers/notification_provider.dart';


import '../../models/property.dart';

class AddPropertyScreen extends StatefulWidget {
  final Property? property;
  const AddPropertyScreen({super.key, this.property});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _form = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _lieu = TextEditingController();
  final _prix = TextEditingController();
  final _pieces = TextEditingController();
  final _description = TextEditingController();
  final _superficie = TextEditingController();
  final _ville = TextEditingController();
  final _codePostal = TextEditingController();
  final _prixVente = TextEditingController();
  final _montantCharges = TextEditingController();
  final _depotGarantie = TextEditingController();
  final _fraisAgence = TextEditingController();
  final _nbChambres = TextEditingController();
  final _nbSalons = TextEditingController();
  final _nbSallesDeBain = TextEditingController();
  final _nbToilettes = TextEditingController();
  final _etage = TextEditingController();
  final _parkingPlaces = TextEditingController();
  final _dureeMinLocation = TextEditingController();
  final _preavis = TextEditingController();
  
  String _statutAnnonce = 'À louer';
  String _typeCuisine = 'Non équipée';
  bool _chargesComprises = false;
  bool _hasAscenseur = false;
  bool _hasParking = false;
  bool _hasJardin = false;
  bool _hasBalcon = false;
  bool _animauxAcceptes = false;
  bool _fumeursAcceptes = false;
  DateTime? _disponibiliteDate;
  
  List<String> _selectedEquipements = [];
  XFile? _planImage;
  XFile? _propertyVideo;
  
  XFile? _image;
  Uint8List? _imageBytes;
  List<XFile> _additionalImages = [];
  double? _lat;
  double? _lng;
  final _descriptionDetaillee = TextEditingController();
  final _videoUrl = TextEditingController();
  String _type = 'Appartement';
  
  bool _uploading = false;
  String? _existingImageUrl;
  List<String> _existingAdditionalUrls = [];
  String? _existingVideoUrl;
  @override
  void initState() {
    super.initState();
    _ville.text = 'Cotonou';
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppProvider>().checkAuthStatus();
    });
    if (widget.property != null) {
      _prefillData(widget.property!);
    }
  }

  void _prefillData(Property p) {
    _titre.text = p.titre;
    _lieu.text = p.lieu;
    _prix.text = p.prix.toString();
    _pieces.text = p.pieces.toString();
    _description.text = p.description ?? '';
    _superficie.text = p.superficie.toString();
    _ville.text = p.ville;
    _codePostal.text = p.codePostal ?? '';
    _prixVente.text = p.prixVente?.toString() ?? '';
    _montantCharges.text = p.montantCharges?.toString() ?? '';
    _depotGarantie.text = p.depotGarantie?.toString() ?? '';
    _fraisAgence.text = p.fraisAgence?.toString() ?? '';
    _nbChambres.text = p.nbChambres.toString();
    _nbSalons.text = p.nbSalons.toString();
    _nbSallesDeBain.text = p.nbSallesDeBain.toString();
    _nbToilettes.text = p.nbToilettes.toString();
    _etage.text = p.etage?.toString() ?? '';
    _parkingPlaces.text = p.parkingPlaces.toString();
    _dureeMinLocation.text = p.dureeMinLocation?.toString() ?? '';
    _preavis.text = p.preavis?.toString() ?? '';
    _descriptionDetaillee.text = p.descriptionDetaillee ?? '';
    _videoUrl.text = p.videoUrl ?? '';
    
    _statutAnnonce = p.statutAnnonce;
    _typeCuisine = p.typeCuisine;
    _chargesComprises = p.chargesComprises;
    _hasAscenseur = p.hasAscenseur;
    _hasParking = p.hasParking;
    _hasJardin = p.hasJardin;
    _hasBalcon = p.hasBalcon;
    _animauxAcceptes = p.animauxAcceptes;
    _fumeursAcceptes = p.fumeursAcceptes;
    _disponibiliteDate = p.disponibilite;
    _selectedEquipements = List.from(p.equipements);
    _type = p.type;
    _lat = p.latitude;
    _lng = p.longitude;
    
    _existingImageUrl = p.imageUrl;
    _existingAdditionalUrls = List.from(p.additionalImages);
    _existingVideoUrl = p.propertyVideoUrl;
  }

  @override
  void dispose() {
    _superficie.dispose();
    _ville.dispose();
    _codePostal.dispose();
    _prixVente.dispose();
    _montantCharges.dispose();
    _depotGarantie.dispose();
    _fraisAgence.dispose();
    _nbChambres.dispose();
    _nbSalons.dispose();
    _nbSallesDeBain.dispose();
    _nbToilettes.dispose();
    _etage.dispose();
    _parkingPlaces.dispose();
    _dureeMinLocation.dispose();
    _preavis.dispose();
    _descriptionDetaillee.dispose();
    _videoUrl.dispose();
    _description.dispose();
    _titre.dispose();
    _lieu.dispose();
    _prix.dispose();
    _pieces.dispose();
    super.dispose();

  }

  Future<void> _pickImage() async {
    try {
      final f = await StorageService.pickImage();
      if (f != null) {
        final bytes = await f.readAsBytes();
        if (mounted) {
          setState(() {
            _image = f;
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAdditionalImages() async {
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _additionalImages = images;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur images multiples: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final f = await StorageService.pickVideo();
      if (f != null) {
        setState(() => _propertyVideo = f);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Vidéo sélectionnée'), backgroundColor: AppColors.accentGreen),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur vidéo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _captureLocation() async {
    final p = await LocationService.getCurrentPosition();
    if (p != null) {
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      _showError('Veuillez remplir tous les champs obligatoires');
      return;
    }

    // Validation des photos (Minimum 1)
    int totalPhotos = (_image != null ? 1 : (_existingImageUrl != null ? 1 : 0)) +
                     _additionalImages.length + _existingAdditionalUrls.length;
    if (totalPhotos < 1) {
      _showError('Veuillez ajouter au moins 1 photo du bien');
      return;
    }

    // ── Vérification limite d'abonnement (uniquement pour nouvelle création) ──
    if (widget.property == null) {
      final subData = await ApiService.getCurrentSubscription();
      if (!mounted) return; // widget démontré pendant l'await
      if (subData != null) {
        final canAdd = subData['canPublishMore'] as bool? ?? true;
        if (!canAdd) {
          final max   = subData['maxProperties'] ?? 3;
          final plan  = subData['planLabel'] ?? 'Gratuit';
          final count = subData['publishedCount'] ?? 0;
          // Capture navigator/context avant toute async gap
          final nav = Navigator.of(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.lock, color: Color(0xFFFF8C00)),
                SizedBox(width: 10),
                Text('Limite atteinte', style: TextStyle(color: Colors.white, fontSize: 16)),
              ]),
              content: Text(
                'Vous avez atteint la limite de $max bien(s) du plan $plan ($count/$max).\n\nPassez à un plan supérieur pour publier davantage.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              actions: [
                TextButton(onPressed: () => nav.pop(), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
                  onPressed: () {
                    nav.pop();
                    nav.pushNamed('/subscription');
                  },
                  child: const Text('Voir les plans'),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    setState(() => _uploading = true);

    try {
    final appProvider = context.read<AppProvider>();
    final user = appProvider.user;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Vous devez être connecté'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _uploading = false);
        return;
      }

      // Upload images séquentiellement (plus fiable que parallèle sur PHP built-in)
      String? imageUrl = _existingImageUrl;
      List<String> additionalImageUrls = List.from(_existingAdditionalUrls);

      if (_image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⬆️ Upload photo principale...'), duration: Duration(seconds: 30)),
          );
        }
        final url = await StorageService.uploadImage(_image!, 'properties');
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
        }
      }

      for (int i = 0; i < _additionalImages.length; i++) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⬆️ Upload photo ${i + 2}/${_additionalImages.length + 1}...'), duration: const Duration(seconds: 30)),
          );
        }
        final url = await StorageService.uploadImage(_additionalImages[i], 'properties/extra');
        if (url != null) additionalImageUrls.add(url);
      }

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Upload vidéo (optionnel)
      String? propertyVideoUrl = _existingVideoUrl;
      if (_propertyVideo != null) {
        try {
          propertyVideoUrl = await StorageService.uploadFile(_propertyVideo!, 'properties/videos')
              .timeout(const Duration(seconds: 90));
        } catch (_) {
          propertyVideoUrl = null;
        }
      }

      final prixValue = int.tryParse(_prix.text);
      if (prixValue == null || prixValue <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Prix invalide (doit être > 0)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _uploading = false);
        return;
      }

      final piecesValue = int.tryParse(_pieces.text) ?? 1;

      // Ajout du bien via DatabaseHelper (SharedPreferences)
      final db = DatabaseHelper();
      final propertyData = {
        'titre': _titre.text.trim(),
        'lieu': _lieu.text.trim(),
        'prix': prixValue,
        'pieces': piecesValue,
        'type': _type,
        'description': _description.text.trim(),
        'descriptionDetaillee': _descriptionDetaillee.text.trim(),
        'videoUrl': _videoUrl.text.trim(),
        'propertyVideoUrl': propertyVideoUrl,
        'additionalImages': additionalImageUrls,
        'proprietaireId': user.id,
        'latitude': _lat,
        'longitude': _lng,
        'imageUrl': imageUrl ?? 'https://via.placeholder.com/400x300?text=Sans+image',
        'status': user.role == 'admin' ? 'actif' : 'en_attente',
        
        // New fields
        'statutAnnonce': _statutAnnonce,
        'superficie': double.tryParse(_superficie.text) ?? 0.0,
        'ville': _ville.text.trim(),
        'codePostal': _codePostal.text.trim(),
        'prixVente': int.tryParse(_prixVente.text),
        'chargesComprises': _chargesComprises ? 1 : 0,
        'montantCharges': int.tryParse(_montantCharges.text),
        'depotGarantie': int.tryParse(_depotGarantie.text),
        'fraisAgence': int.tryParse(_fraisAgence.text),
        'nbChambres': int.tryParse(_nbChambres.text) ?? 0,
        'nbSalons': int.tryParse(_nbSalons.text) ?? 0,
        'nbSallesDeBain': int.tryParse(_nbSallesDeBain.text) ?? 0,
        'nbToilettes': int.tryParse(_nbToilettes.text) ?? 0,
        'typeCuisine': _typeCuisine,
        'etage': int.tryParse(_etage.text),
        'hasAscenseur': _hasAscenseur ? 1 : 0,
        'hasParking': _hasParking ? 1 : 0,
        'parkingPlaces': int.tryParse(_parkingPlaces.text) ?? 0,
        'hasJardin': _hasJardin ? 1 : 0,
        'hasBalcon': _hasBalcon ? 1 : 0,
        'equipements': _selectedEquipements,
        'animauxAcceptes': _animauxAcceptes ? 1 : 0,
        'fumeursAcceptes': _fumeursAcceptes ? 1 : 0,
        'dureeMinLocation': int.tryParse(_dureeMinLocation.text),
        'preavis': int.tryParse(_preavis.text),
        'disponibilite': _disponibiliteDate?.toIso8601String(),
      };

      // Construire les images à envoyer (base64 data URLs ou URLs serveur)
      bool isValidImg(String? u) =>
          u != null && (u.startsWith('/uploads/') || u.startsWith('http') || u.startsWith('data:'));
      final allImages = <String>[
        if (isValidImg(imageUrl)) imageUrl!,
        ...additionalImageUrls.where(isValidImg),
      ];

      // Description : utiliser descriptionDetaillee en priorité (champ visible dans le form)
      final descriptionFinale = _descriptionDetaillee.text.trim().isNotEmpty
          ? _descriptionDetaillee.text.trim()
          : _description.text.trim();

      // Payload pour l'API Symfony
      final apiPayload = {
        'title':         _titre.text.trim(),
        'description':   descriptionFinale,
        'address':       _lieu.text.trim(),
        'city':          _ville.text.trim().isNotEmpty ? _ville.text.trim() : _lieu.text.trim(),
        'pricePerMonth': prixValue,
        'rooms':         piecesValue,
        'bedrooms':      int.tryParse(_nbChambres.text) ?? piecesValue,
        'surface':       double.tryParse(_superficie.text) ?? 0.0,
        'type':          _type,
        'images':        allImages,
        'statutAnnonce': _statutAnnonce,
        if (propertyVideoUrl != null) 'videoUrl': propertyVideoUrl,
      };

      if (widget.property != null) {
        propertyData['id'] = widget.property!.id;
        await db.updateProperty(widget.property!.id, propertyData);
        // Sync mise à jour vers l'API
        try { await ApiService.post('/api/properties/${widget.property!.id}/update', apiPayload); } catch (_) {}
        if (!mounted) return;
        await context.read<NotificationProvider>().addNotification(
          userId: user.id,
          title: '✅ Bien mis à jour',
          body: '${_titre.text} a été mis à jour avec succès',
          type: 'property',
        );
      } else {
        // Envoyer à l'API Symfony
        final result = await ApiService.post('/api/properties/new', apiPayload);

        // Limite d'abonnement atteinte → dialog upgrade
        if (result is Map && result['upgradeRequired'] == true) {
          if (mounted) {
            setState(() => _uploading = false);
            _showUpgradeDialog(
              currentPlan: result['currentPlan'] as String? ?? 'free',
              nextPlan:    result['nextPlan']    as String? ?? 'starter',
              nextPrice:   result['nextPlanPrice'] as int?   ?? 5000,
            );
          }
          return;
        }

        // KYC requis
        if (result is Map && result['kycRequired'] == true) {
          if (mounted) {
            setState(() => _uploading = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('🔒 Certification KYC requise avant de publier'),
              backgroundColor: Colors.orange,
            ));
          }
          return;
        }

        // Autre erreur API
        if (result is Map && result.containsKey('error')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('❌ ${result['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ));
          }
          setState(() => _uploading = false);
          return;
        }

        // API injoignable → fallback SQLite
        if (result == null) {
          await db.addProperty(propertyData);
        }

        // Invalider tous les caches biens (propriétaire + admin + public)
        ApiService.invalidateCache('${ApiService.baseUrl}/api/properties');
        ApiService.invalidateCache('${ApiService.baseUrl}/api/admin/properties');

        // Recharger les biens dans AppProvider (locataire/admin voient les nouveaux biens)
        if (!mounted) return;
        try { await context.read<AppProvider>().refreshProperties(); } catch (_) {}
        if (!mounted) return;
        await context.read<NotificationProvider>().addNotification(
          userId: user.id,
          title: '✅ Bien publié',
          body: '${_titre.text} a été publié et est en attente de validation par l\'admin',
          type: 'property',
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_titre.text} publié avec succès!'),
          backgroundColor: AppColors.accentGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur format: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final user = appProvider.user;
    
    if (user != null && user.role == 'proprietaire') {
      final isVerified = user.isVerified;
      
      if (!isVerified) {
        return RoleGuard(
          allowedRoles: const ['proprietaire', 'admin'],
          customErrorMessage: 'Seuls les propriétaires peuvent ajouter des biens',
          child: Scaffold(
            backgroundColor: AppColors.getScaffoldBackground(context),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF2D3E50), AppColors.getScaffoldBackground(context)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildSimpleAppBar('Ajouter un bien'),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.verified_user_rounded, size: 80, color: AppColors.accentOrange),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Certification Requise',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Pour garantir la sécurité de notre plateforme, vous devez être certifié avant de publier une annonce.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    const SizedBox(height: 32),
                                    ModernButton(
                                      text: 'Passer la Certification',
                                      onPressed: () => Navigator.pushNamed(context, '/verification'),
                                      icon: Icons.shield_outlined,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return RoleGuard(
      allowedRoles: const ['proprietaire', 'admin'],
      customErrorMessage: 'Seuls les propriétaires peuvent ajouter des biens',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2A3A), Color(0xFF0D1B2A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildSimpleAppBar('Publier une Annonce'),
                Expanded(
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      children: [
                        SectionHeaderWidget(title: appProvider.translate('general_info'), icon: Icons.info_outline),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _titre,
                          label: '${appProvider.translate('property_title')}*',
                          icon: Icons.title_rounded,
                          validator: (v) => v!.isEmpty ? appProvider.translate('required_field') : null,
                        ),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _descriptionDetaillee,
                          label: '${appProvider.translate('property_desc')}*',
                          icon: Icons.notes_rounded,
                          maxLines: 5,
                          validator: (v) => v!.isEmpty ? appProvider.translate('required_field') : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTypeDropdown(),
                        const SizedBox(height: 16),
                        _buildStatutAnnonceDropdown(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ModernTextField(
                                controller: _pieces,
                                label: '${appProvider.translate('rooms')}*',
                                icon: Icons.meeting_room_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? appProvider.translate('required_field') : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ModernTextField(
                                controller: _superficie,
                                label: '${appProvider.translate('area')}*',
                                icon: Icons.square_foot_rounded,
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? appProvider.translate('required_field') : null,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('localisation'), icon: Icons.location_on_outlined),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _lieu,
                          label: '${appProvider.translate('address')}*',
                          icon: Icons.map_outlined,
                          validator: (v) => v!.isEmpty ? appProvider.translate('required_field') : null,
                        ),
                        const SizedBox(height: 16),
                        _buildVilleDropdown(),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _codePostal,
                          label: '${appProvider.translate('postal_code')} (${appProvider.translate('optional')})',
                          icon: Icons.report_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildModernLocationPicker(),

                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('price_fees'), icon: Icons.monetization_on_outlined),
                        const SizedBox(height: 20),
                        if (_statutAnnonce == 'À louer' || _statutAnnonce == 'Les deux')
                          ModernTextField(
                            controller: _prix,
                            label: '${appProvider.translate('monthly_rent')}*',
                            icon: Icons.receipt_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => (_statutAnnonce != 'À vendre' && v!.isEmpty) ? appProvider.translate('required_field') : null,
                          ),
                        if (_statutAnnonce == 'À vendre' || _statutAnnonce == 'Les deux') ...[
                          const SizedBox(height: 16),
                          ModernTextField(
                            controller: _prixVente,
                            label: 'Prix de vente*',
                            icon: Icons.sell_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => (_statutAnnonce != 'À louer' && v!.isEmpty) ? 'Requis' : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildSwitchTile(appProvider.translate('charges_incl'), _chargesComprises, (v) => setState(() => _chargesComprises = v)),
                        if (!_chargesComprises) ...[
                          const SizedBox(height: 16),
                          ModernTextField(
                            controller: _montantCharges,
                            label: appProvider.translate('charges_amount'),
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ModernTextField(
                                controller: _depotGarantie,
                                label: appProvider.translate('deposit'),
                                icon: Icons.security_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ModernTextField(
                                controller: _fraisAgence,
                                label: appProvider.translate('agency_fees'),
                                icon: Icons.handshake_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('detailed_features'), icon: Icons.king_bed_outlined),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: ModernTextField(controller: _nbChambres, label: appProvider.translate('bedrooms'), icon: Icons.bed_rounded, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: ModernTextField(controller: _nbSalons, label: appProvider.translate('living_rooms'), icon: Icons.weekend_rounded, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: ModernTextField(controller: _nbSallesDeBain, label: appProvider.translate('bathrooms'), icon: Icons.bathtub_rounded, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: ModernTextField(controller: _nbToilettes, label: appProvider.translate('toilets'), icon: Icons.wc_rounded, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCuisineDropdown(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: ModernTextField(controller: _etage, label: appProvider.translate('floor'), icon: Icons.layers_rounded, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSwitchTile(appProvider.translate('elevator'), _hasAscenseur, (v) => setState(() => _hasAscenseur = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildSwitchTile(appProvider.translate('parking'), _hasParking, (v) => setState(() => _hasParking = v))),
                            if (_hasParking) ...[
                              const SizedBox(width: 12),
                              Expanded(child: ModernTextField(controller: _parkingPlaces, label: 'Places', icon: Icons.local_parking_rounded, keyboardType: TextInputType.number)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildSwitchTile(appProvider.translate('garden_terrace'), _hasJardin, (v) => setState(() => _hasJardin = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSwitchTile(appProvider.translate('balcony'), _hasBalcon, (v) => setState(() => _hasBalcon = v))),
                          ],
                        ),

                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('equipment'), icon: Icons.apps_rounded),
                        const SizedBox(height: 20),
                        _buildEquipementsGrid(),

                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('media'), icon: Icons.photo_camera_outlined),
                        const SizedBox(height: 20),
                        const Text('Photo principale (Obligatoire)*', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildModernImagePicker(),
                        const SizedBox(height: 16),
                        const Text('Photos supplémentaires (Minimum 2 recommandées)*', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildAdditionalImagesPicker(),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _videoUrl,
                          label: 'Lien vidéo (YouTube, optionnel)',
                          icon: Icons.play_circle_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildVideoFilePicker(),
                        const SizedBox(height: 16),
                        _buildPlanPicker(),

                        const SizedBox(height: 32),
                        SectionHeaderWidget(title: appProvider.translate('rules_conditions'), icon: Icons.gavel_rounded),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildSwitchTile('Animaux acceptés', _animauxAcceptes, (v) => setState(() => _animauxAcceptes = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSwitchTile('Fumeurs acceptés', _fumeursAcceptes, (v) => setState(() => _fumeursAcceptes = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: ModernTextField(controller: _dureeMinLocation, label: 'Durée min (mois)', icon: Icons.timer_outlined, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: ModernTextField(controller: _preavis, label: 'Préavis (mois)', icon: Icons.notification_important_outlined, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDatePicker('Disponibilité immédiate / Date', _disponibiliteDate, (date) => setState(() => _disponibiliteDate = date)),
                        const SizedBox(height: 32),
                        
                        const SectionHeaderWidget(title: 'Photos & Localisation', icon: Icons.photo_camera_outlined),
                        const SizedBox(height: 20),
                        _buildModernImagePicker(),
                        const SizedBox(height: 16),
                        _buildAdditionalImagesPicker(),
                        const SizedBox(height: 16),
                        _buildModernLocationPicker(),

                        const SizedBox(height: 40),
                        
                        ModernButton(
                          text: _uploading ? 'Publication...' : 'Publier l\'annonce',
                          onPressed: _uploading ? null : () => _submit(),
                          isLoading: _uploading,
                          icon: Icons.rocket_launch_rounded,
                        ),
                        const SizedBox(height: 20),
                        _buildInfoNote(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatutAnnonceDropdown() {
    return _buildDropdown('Statut de l\'annonce*', _statutAnnonce, ['À louer', 'À vendre', 'Les deux'], (v) => setState(() => _statutAnnonce = v!));
  }

  Widget _buildVilleDropdown() {
    return _buildDropdown('Ville*', _ville.text.isEmpty ? 'Cotonou' : _ville.text, ['Cotonou', 'Porto-Novo', 'Parakou', 'Abomey-Calavi', 'Ouidah', 'Bohicon', 'Natitingou'], (v) => setState(() => _ville.text = v!));
  }

  Widget _buildCuisineDropdown() {
    return _buildDropdown('Type de cuisine', _typeCuisine, ['Américaine', 'Séparée', 'Équipée', 'Non équipée'], (v) => setState(() => _typeCuisine = v!));
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A2A3A),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accentBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipementsGrid() {
    final list = [
      'Climatisation', 'Ventilateur', 'Chauffage', 'Eau courante', 'Groupe électrogène', 
      'Panneaux solaires', 'Interphone', 'Alarme', 'Gardiennage', 'Piscine', 
      'Salle de sport', 'Buanderie', 'Fibre / Internet'
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: list.map((e) {
        final isSelected = _selectedEquipements.contains(e);
        return FilterChip(
          label: Text(e),
          selected: isSelected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _selectedEquipements.add(e);
              } else {
                _selectedEquipements.remove(e);
              }
            });
          },
          selectedColor: AppColors.accentBlue.withValues(alpha: 0.2),
          checkmarkColor: AppColors.accentBlue,
          labelStyle: TextStyle(color: isSelected ? AppColors.accentBlue : Colors.white70, fontSize: 12),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
        );
      }).toList(),
    );
  }

  Widget _buildVideoFilePicker() {
    return InkWell(
      onTap: _pickVideo,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _propertyVideo != null ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.video_collection_rounded, color: _propertyVideo != null ? AppColors.accentBlue : Colors.white54),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _propertyVideo == null ? 'Vidéo du bien / champ (Optionnel)' : 'Vidéo sélectionnée ✓',
                        style: TextStyle(
                          color: _propertyVideo != null ? AppColors.accentBlue : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _propertyVideo == null ? 'Formats supportés: MP4, MOV, AVI' : _propertyVideo!.name,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_propertyVideo != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _propertyVideo = null),
                  ),
              ],
            ),
            if (_propertyVideo != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, size: 40, color: Colors.white30),
                      SizedBox(height: 4),
                      Text('Aperçu indisponible', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanPicker() {
    return InkWell(
      onTap: () async {
        final picker = ImagePicker();
        final img = await picker.pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => _planImage = img);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _planImage != null ? AppColors.accentGreen : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: _planImage != null ? AppColors.accentGreen : Colors.white54),
            const SizedBox(width: 16),
            Expanded(child: Text(_planImage == null ? 'Ajouter le plan du bien (PDF/Image)' : 'Plan ajouté ✓', style: TextStyle(color: _planImage != null ? AppColors.accentGreen : Colors.white70))),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onSelected) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context, 
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onSelected(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value != null ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: value != null ? AppColors.accentBlue : Colors.white54),
            const SizedBox(width: 16),
            Expanded(child: Text(value == null ? label : 'Disponible le : ${value.day}/${value.month}/${value.year}', style: TextStyle(color: value != null ? AppColors.accentBlue : Colors.white70))),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAppBar(String title) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _type,
          onChanged: (v) => setState(() => _type = v!),
          dropdownColor: AppColors.backgroundDark,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(border: InputBorder.none),
          items: ['Appartement', 'Maison', 'Studio', 'Villa', 'Terrain', 'Bureau', 'Entrepôt', 'Commerce']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildModernImagePicker() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _image != null ? AppColors.accentGreen : Colors.white.withValues(alpha: 0.1), width: 2),
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text('Ajouter une photo principale', style: TextStyle(color: Colors.white54)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                    : Container(color: Colors.black26),
              ),
      ),
    );
  }

  Widget _buildAdditionalImagesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickAdditionalImages,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: _additionalImages.isNotEmpty ? AppColors.accentBlue : Colors.white54),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _additionalImages.isEmpty ? 'Ajouter d\'autres photos' : '${_additionalImages.length} photos supplémentaires sélectionnées',
                    style: TextStyle(color: _additionalImages.isNotEmpty ? AppColors.accentBlue : Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_additionalImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _additionalImages.length,
              itemBuilder: (context, index) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(image: AssetImage('assets/images/placeholder.png'), fit: BoxFit.cover),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.image, color: Colors.white24),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildModernLocationPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.accentBlue, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'La localisation sera basée sur l\'adresse saisie ci-dessus.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _captureLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: (_lat != null ? AppColors.accentBlue : Colors.white).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (_lat != null ? AppColors.accentBlue : Colors.white).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.my_location_rounded, color: _lat != null ? AppColors.accentBlue : Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _lat == null ? 'Ajouter coordonnées GPS (Optionnel)' : 'Coordonnées GPS capturées ✓',
                    style: TextStyle(color: _lat != null ? AppColors.accentBlue : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $message'), backgroundColor: Colors.red),
      );
    }
  }

  static const Map<String, String> _planLabels = {
    'free': 'Gratuit', 'starter': 'Starter', 'pro': 'Pro',
  };
  static const Map<String, int> _planMaxBiens = {
    'free': 3, 'starter': 10,
  };

  void _showUpgradeDialog({
    required String currentPlan,
    required String nextPlan,
    required int nextPrice,
  }) {
    final nextLabel = _planLabels[nextPlan] ?? nextPlan;
    final nextMax   = _planMaxBiens[nextPlan];
    final maxStr    = nextMax != null ? '$nextMax biens' : 'biens illimités';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.workspace_premium_rounded, color: AppColors.accentOrange, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('Limite atteinte', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous avez atteint la limite du plan ${_planLabels[currentPlan] ?? currentPlan}.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2D4A6B), Color(0xFF1A3A5C)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.accentOrange, size: 20),
                    const SizedBox(width: 8),
                    Text('Plan $nextLabel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Text('✓ $maxStr', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '${nextPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA / mois',
                    style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Passez au plan supérieur pour continuer à publier vos biens.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Passer au plan $nextLabel'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentYellow.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentYellow, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Votre annonce sera mise en ligne après une rapide vérification de nos modérateurs.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}