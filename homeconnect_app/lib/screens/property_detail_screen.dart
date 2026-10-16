// lib/screens/property_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../utils/app_colors.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../models/property.dart';
import '../models/user.dart';
import '../widgets/design_widgets.dart';
import '../services/notification_service.dart';
import 'tenant/chat_screen.dart';
import 'proprietaire/add_property_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final int propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late Future<Map<String, dynamic>> _propertyDataFuture;
  User? _owner;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  void _loadPropertyData() {
    _propertyDataFuture = _fetchProperty();
  }

  Future<Map<String, dynamic>> _fetchProperty() async {
    // 1. Essayer d'abord depuis l'API (source de vérité)
    try {
      final raw = await ApiService.getProperty(widget.propertyId);
      if (raw != null) {
        final p = Property.fromApiMap(Map<String, dynamic>.from(raw));
        return p.toMap();
      }
    } catch (_) {}

    // 2. Fallback sur SQLite local
    return await DatabaseHelper().getPropertyById(widget.propertyId);
  }

  bool _isLiked = false;
  bool _isDisliked = false;
  int _galleryCurrentIndex = 0;
  final PageController _galleryController = PageController();

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_outline,
              color: _isFavorite ? AppColors.accentRed : AppColors.getTextColor(context),
            ),
            onPressed: () => _toggleFavorite(appProvider.user),
          ),
          IconButton(
            icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, color: _isLiked ? AppColors.accentBlue : AppColors.getTextColor(context)),
            onPressed: () => _toggleLike(appProvider.user),
          ),
          IconButton(
            icon: Icon(_isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined, color: _isDisliked ? AppColors.accentRed : AppColors.getTextColor(context)),
            onPressed: () => _toggleDislike(appProvider.user),
          ),

          if (appProvider.user?.role == 'proprietaire')
            PopupMenuButton(
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'Modifier', child: Text(appProvider.translate('edit'), style: TextStyle(color: AppColors.getTextColor(ctx)))),
                PopupMenuItem(value: 'Supprimer', child: Text(appProvider.translate('delete'), style: const TextStyle(color: AppColors.accentRed))),
              ],
              onSelected: (value) async {
                if (value == 'Modifier') {
                  final data = await DatabaseHelper().getPropertyById(widget.propertyId);
                  if (!context.mounted) return;
                  final p = Property.fromMap(data);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => AddPropertyScreen(property: p)),
                  ).then((_) => setState(() => _loadPropertyData()));
                } else if (value == 'Supprimer') {
                  _showDeleteDialog();
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _propertyDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.accentRed),
                  const SizedBox(height: 16),
                  Text(appProvider.translate('error_loading'), style: TextStyle(color: AppColors.getTextColor(context))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _loadPropertyData()),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
                    child: Text(appProvider.translate('retry')),
                  ),
                ],
              ),
            );
          }

          final propertyData = snapshot.data!;
          return _buildPropertyDetails(propertyData, appProvider);
        },
      ),
    );
  }

  Widget _buildPropertyDetails(Map<String, dynamic> propertyData, AppProvider appProvider) {
    final property = Property.fromMap(propertyData);

    return CustomScrollView(
      slivers: [
        // Galerie multi-images avec PageView
        SliverAppBar(
          expandedHeight: 350,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.getScaffoldBackground(context),
          flexibleSpace: FlexibleSpaceBar(
            background: Builder(builder: (ctx) {
              // Construire la liste de toutes les images
              final allImages = <String>[
                if (property.imageUrl != null && property.imageUrl!.isNotEmpty) property.imageUrl!,
                ...property.additionalImages,
              ];
              if (allImages.isEmpty) {
                allImages.add('https://images.unsplash.com/photo-1560518883-ce09059eeffa?q=80&w=1073&auto=format&fit=crop');
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  // PageView images
                  PageView.builder(
                    controller: _galleryController,
                    itemCount: allImages.length,
                    onPageChanged: (i) => setState(() => _galleryCurrentIndex = i),
                    itemBuilder: (_, i) => i == 0
                        ? Hero(
                            tag: 'bien_${property.titre}',
                            child: SafeImage(url: allImages[i], fit: BoxFit.cover),
                          )
                        : SafeImage(url: allImages[i], fit: BoxFit.cover),
                  ),
                  // Dégradé bas
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6), Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                  // Indicateur de page (dots)
                  if (allImages.length > 1)
                    Positioned(
                      top: 12,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${_galleryCurrentIndex + 1}/${allImages.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Infos basses
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.accentOrange, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${property.prix} FCFA / mois',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          property.titre,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 10)]),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.accentOrange, size: 16),
                            const SizedBox(width: 4),
                            Expanded(child: Text(property.lieu, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            Row(
                              children: [
                                _buildSocialStat(Icons.visibility, '${property.views}', Colors.white54),
                                const SizedBox(width: 12),
                                _buildSocialStat(Icons.thumb_up, '${property.likes}', AppColors.accentBlue),
                                const SizedBox(width: 12),
                                _buildSocialStat(Icons.chat_bubble, '${property.commentsCount}', Colors.white70),
                              ],
                            ),
                          ],
                        ),
                        if (property.verified) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.verified_user, color: AppColors.accentGreen, size: 14),
                            const SizedBox(width: 4),
                            Text(appProvider.translate('verified_by_app'), style: const TextStyle(color: AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ],
                        // Points de navigation miniatures
                        if (allImages.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(allImages.length > 6 ? 6 : allImages.length, (i) => Container(
                              width: i == _galleryCurrentIndex ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: i == _galleryCurrentIndex ? AppColors.accentOrange : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Specs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickSpec(Icons.hotel_rounded, '${property.nbChambres > 0 ? property.nbChambres : property.pieces} Ch.'),
                    _buildQuickSpec(Icons.square_foot_rounded, '${property.superficie > 0 ? property.superficie : 120} m²'),
                    _buildQuickSpec(Icons.location_city_rounded, property.ville.isNotEmpty ? property.ville : 'Cotonou'),
                  ],
                ),
                const SizedBox(height: 32),
                
                Text(appProvider.translate('media'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildGalleryItem(property.imageUrl ?? 'https://via.placeholder.com/400x300?text=Sans+image', isVideo: false),
                      ...property.additionalImages.map((img) => _buildGalleryItem(img, isVideo: false)),
                      if (property.videoUrl != null && property.videoUrl!.isNotEmpty)
                        _buildGalleryItem(property.imageUrl ?? 'https://via.placeholder.com/400x300?text=Video+YouTube', isVideo: true, videoUrl: property.videoUrl),
                      if (property.propertyVideoUrl != null && property.propertyVideoUrl!.isNotEmpty)
                        _buildGalleryItem(property.imageUrl ?? 'https://via.placeholder.com/400x300?text=Video+Locale', isVideo: true, videoUrl: property.propertyVideoUrl),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Description
                Text(appProvider.translate('property_desc'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 12),
                Text(
                  (property.descriptionDetaillee?.isEmpty ?? true) 
                    ? (property.description?.isEmpty ?? true ? appProvider.translate('no_description') : property.description!)
                    : property.descriptionDetaillee!,
                  style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.7), fontSize: 15, height: 1.6),
                ),

                const SizedBox(height: 32),
                
                // Amenities
                Text(appProvider.translate('equipment'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: property.equipements.isEmpty 
                    ? [
                        _buildCharacteristicChip(Icons.info_outline, appProvider.translate('no_equipment')),
                      ]
                    : property.equipements.map((e) => _buildCharacteristicChip(_getAmenityIcon(e), e)).toList(),
                ),
                const SizedBox(height: 32),

                // Technical Sheet
                Text(appProvider.translate('technical_sheet'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 16),
                _buildTechnicalRow(appProvider.translate('property_type'), property.type),
                _buildTechnicalRow(appProvider.translate('property_status'), property.statutAnnonce),
                _buildTechnicalRow(appProvider.translate('city'), property.ville),
                _buildTechnicalRow(appProvider.translate('total_rooms'), '${property.pieces}'),
                _buildTechnicalRow(appProvider.translate('bedrooms'), '${property.nbChambres}'),
                _buildTechnicalRow(appProvider.translate('living_rooms'), '${property.nbSalons}'),
                _buildTechnicalRow(appProvider.translate('bathrooms'), '${property.nbSallesDeBain}'),
                _buildTechnicalRow(appProvider.translate('kitchen_type'), property.typeCuisine),
                if (property.etage != null) _buildTechnicalRow(appProvider.translate('floor'), '${property.etage}'),
                _buildTechnicalRow(appProvider.translate('parking'), property.hasParking ? 'Oui (${property.parkingPlaces} places)' : 'Non'),
                _buildTechnicalRow(appProvider.translate('elevator'), property.hasAscenseur ? 'Oui' : 'Non'),
                _buildTechnicalRow(appProvider.translate('availability'), property.disponibilite != null ? 'Le ${DateFormat('dd/MM/yyyy').format(property.disponibilite!)}' : appProvider.translate('immediate')),
                
                const SizedBox(height: 24),
                Text(appProvider.translate('rules_conditions'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 12),
                _buildTechnicalRow(appProvider.translate('pets_allowed'), property.animauxAcceptes ? appProvider.translate('yes') : appProvider.translate('no')),
                _buildTechnicalRow(appProvider.translate('smokers_allowed'), property.fumeursAcceptes ? appProvider.translate('yes') : appProvider.translate('no')),
                if (property.dureeMinLocation != null) _buildTechnicalRow(appProvider.translate('min_lease'), '${property.dureeMinLocation} ${appProvider.translate('months')}'),
                if (property.preavis != null) _buildTechnicalRow(appProvider.translate('notice_period'), '${property.preavis} ${appProvider.translate('months')}'),

                const SizedBox(height: 32),
                Text(appProvider.translate('price_fees'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                const SizedBox(height: 16),
                if (property.statutAnnonce != 'À vendre') _buildTechnicalRow(appProvider.translate('monthly_rent'), '${property.prix} FCFA'),
                if (property.statutAnnonce != 'À louer' && property.prixVente != null) _buildTechnicalRow(appProvider.translate('sale_price'), '${property.prixVente} FCFA'),
                _buildTechnicalRow(appProvider.translate('charges_incl'), property.chargesComprises ? appProvider.translate('yes') : appProvider.translate('no')),
                if (!property.chargesComprises && property.montantCharges != null) _buildTechnicalRow(appProvider.translate('charges_amount'), '${property.montantCharges} FCFA/mois'),
                if (property.depotGarantie != null) _buildTechnicalRow(appProvider.translate('deposit'), '${property.depotGarantie} FCFA'),
                if (property.fraisAgence != null) _buildTechnicalRow(appProvider.translate('agency_fees'), '${property.fraisAgence} FCFA'),

                const SizedBox(height: 32),
                
                // Owner Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getTextColor(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.backgroundLight,
                        child: Icon(Icons.person, color: AppColors.primaryBlue, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Administration', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 12)),
                            Text('Administration Immo Bénin', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(
                              children: [
                                Icon(Icons.verified, color: (_owner?.isVerified == true ? Colors.blue : Colors.grey), size: 14),
                                const SizedBox(width: 4),
                                Text(_owner?.isVerified == true ? appProvider.translate('certified_app') : appProvider.translate('not_certified'), style: TextStyle(color: (_owner?.isVerified == true ? Colors.blue : Colors.grey).withValues(alpha: 0.8), fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _startChat(1), // Redirection Admin
                        icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accentOrange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Comments Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(appProvider.translate('comments_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
                    TextButton(onPressed: () => _showAddCommentDialog(property), child: Text(appProvider.translate('add'), style: const TextStyle(color: AppColors.accentOrange))),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCommentsList(property.id),
                const SizedBox(height: 32),
                
                // Action Button
                if (appProvider.user?.role == 'locataire')
                  Column(
                    children: [
                      ModernButton(
                        text: appProvider.translate('apply_for_property'),
                        onPressed: () => _showApplyDialog(appProvider.user, property),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _startChat(1), // Redirection Admin
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          side: BorderSide(color: AppColors.getTextColor(context).withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(appProvider.translate('im_interested'), style: TextStyle(color: AppColors.getTextColor(context))),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSpec(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentOrange, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCharacteristicChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accentOrange),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  void _showApplyDialog(User? user, Property property) {
    if (user?.role != 'locataire') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservé aux locataires')));
      return;
    }

    final messageCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Candidature', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ajoutez un message pour convaincre l\'administration.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ModernTextField(
              controller: messageCtrl,
              label: 'Votre message...',
              icon: Icons.message_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ModernButton(
            text: 'Envoyer',
            onPressed: () async {
              if (user == null) return;
              await DatabaseHelper().addApplication(user.id, property.id, messageCtrl.text);
              
              // Notification Propriétaire
              await DatabaseHelper().addNotification(
                property.proprietaireId,
                'Nouvelle candidature',
                '${user.displayName} a postulé pour ${property.titre}',
                'candidature',
              );

              // Notification Admin
              await NotificationService.envoyerNotification(
                userId: 1,
                type: 'candidature',
                message: '${user.displayName} a postulé pour le bien "${property.titre}".',
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Candidature envoyée avec succès !'), backgroundColor: AppColors.accentGreen),
              );
            },
          ),
        ],
      ),
    );
  }

  void _startChat(int receiverId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: receiverId,
          receiverName: receiverId == 1 ? 'Administration Immo Bénin' : 'Contact',
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce bien?', style: TextStyle(color: Colors.white)),
        content: const Text('Cette action est irréversible.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().deleteProperty(widget.propertyId);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bien supprimé')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGalleryItem(String url, {required bool isVideo, String? videoUrl}) {
    return InkWell(
      onTap: () {
        if (isVideo && videoUrl != null) {
          _showVideoDialog(videoUrl);
        } else {
          _showImageFullscreen(url);
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(image: getSafeImageProvider(url), fit: BoxFit.cover),
        ),
        child: isVideo ? Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ) : null,
      ),
    );
  }

  void _showVideoDialog(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoPreviewWidget(videoUrl: videoUrl),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(String url) {
     showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: SafeImage(url: url))),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList(int propertyId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getComments(propertyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final comments = snapshot.data!;
        if (comments.isEmpty) return const Text('Aucun commentaire pour le moment.', style: TextStyle(color: Colors.white30, fontSize: 12));
        
        return Column(
          children: comments.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 12, backgroundColor: AppColors.accentBlue.withValues(alpha: 0.2), child: Text(c['userName'][0], style: const TextStyle(fontSize: 10, color: AppColors.accentBlue))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['userName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(c['text'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  void _showAddCommentDialog(Property property) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        title: const Text('Ajouter un commentaire', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.getTextColor(context)),
          decoration: const InputDecoration(hintText: 'Votre avis...', hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final user = context.read<AppProvider>().user;
              if (user == null) return;
              await DatabaseHelper().addComment(property.id, user.id, user.displayName, controller.text);
              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalRow(String label, String value) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5), fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // ========= INTERACTIONS (FAVORITE / LIKE / DISLIKE) =========
  Future<void> _toggleFavorite(User? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter')));
      return;
    }
    // Sync locale + API
    final newVal = !_isFavorite;
    setState(() => _isFavorite = newVal);
    if (newVal) {
      await DatabaseHelper().addFavorite(user.id, widget.propertyId);
    } else {
      await DatabaseHelper().removeFavorite(user.id, widget.propertyId);
    }
    await ApiService.toggleFavorite(widget.propertyId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newVal ? '❤️ Ajouté aux favoris' : 'Retiré des favoris'),
      duration: const Duration(seconds: 1),
      backgroundColor: newVal ? const Color(0xFFFF4B5C) : Colors.grey,
    ));
  }

  Future<void> _toggleLike(User? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter')));
      return;
    }
    final wasLiked = _isLiked;
    setState(() { _isLiked = !wasLiked; if (!wasLiked) _isDisliked = false; });
    await DatabaseHelper().toggleLike(widget.propertyId, user.id);
    final res = await ApiService.reactToProperty(widget.propertyId, wasLiked ? 'unlike' : 'like');
    if (res != null) _loadPropertyData();
  }

  Future<void> _toggleDislike(User? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter')));
      return;
    }
    final wasDisliked = _isDisliked;
    setState(() { _isDisliked = !wasDisliked; if (!wasDisliked) _isLiked = false; });
    await DatabaseHelper().toggleDislike(widget.propertyId, user.id);
    final res = await ApiService.reactToProperty(widget.propertyId, wasDisliked ? 'unlike' : 'dislike');
    if (res != null) _loadPropertyData();
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'Climatisation': return Icons.ac_unit;
      case 'Ventilateur': return Icons.mode_fan_off;
      case 'Chauffage': return Icons.hot_tub;
      case 'Eau courante': return Icons.water_drop;
      case 'Groupe électrogène': return Icons.bolt;
      case 'Panneaux solaires': return Icons.solar_power;
      case 'Interphone': return Icons.ring_volume;
      case 'Alarme': return Icons.alarm;
      case 'Gardiennage': return Icons.security;
      case 'Piscine': return Icons.pool;
      case 'Salle de sport': return Icons.fitness_center;
      case 'Buanderie': return Icons.local_laundry_service;
      case 'Fibre / Internet': return Icons.wifi;
      default: return Icons.check_circle_outline;
    }
  }
}
