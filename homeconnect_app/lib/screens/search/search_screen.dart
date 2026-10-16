// lib/screens/search/search_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  String? _selectedType;
  String? _selectedVille;
  int? _selectedBeds;
  final bool _parking = false;
  List<Bien> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _types = ['Appartement', 'Maison', 'Studio', 'Chambre', 'Villa', 'Bureau'];
  final List<String> _villes = ['Cotonou', 'Porto-Novo', 'Parakou', 'Bohicon', 'Abomey-Calavi'];

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  // Mappe un objet JSON retourné par le backend vers un Bien
  Bien _mapApiPropertyToBien(Map<String, dynamic> p) {
    final images = p['images'];
    String? imagePrincipale;
    if (images is List && images.isNotEmpty) {
      imagePrincipale = images.first?.toString();
    }

    return Bien(
      id: p['id'] ?? 0,
      reference: 'HC-${p['id']}',
      titre: p['titre'] ?? p['title'] ?? '',
      description: p['description'],
      typeBien: p['type'] ?? 'Appartement',
      ville: p['ville'] ?? p['city'] ?? '',
      commune: p['ville'] ?? p['city'] ?? '',
      quartier: p['lieu'] ?? p['address'] ?? '',
      adresse: p['lieu'] ?? p['address'],
      latitude: null,
      longitude: null,
      loyerMensuel: (p['prix'] ?? p['pricePerMonth'] ?? 0).toInt(),
      caution: p['deposit'] != null ? (p['deposit'] as num).toInt() : null,
      charges: p['montantCharges'] != null ? (p['montantCharges'] as num).toInt() : 0,
      negociable: false,
      nbChambres: p['bedrooms'] ?? p['nbChambres'] ?? 0,
      nbPieces: p['pieces'] ?? p['rooms'] ?? 0,
      surface: p['superficie'] != null ? (p['superficie'] as num).toDouble()
               : p['surface'] != null ? (p['surface'] as num).toDouble() : null,
      meuble: p['furnished'] == true || p['furnished'] == 1,
      statut: p['status'] ?? p['statut'] ?? 'actif',
      isFeatured: p['isHighlighted'] == true,
      nbVues: p['views'] ?? 0,
      imagePrincipale: imagePrincipale,
      images: const [],
      createdAt: p['createdAt'] != null
          ? DateTime.tryParse(p['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Appel réel à l'API backend — GET /api/properties
      final rawProperties = await ApiService.getProperties();

      if (rawProperties.isEmpty) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        return;
      }

      // Convertir les données API en modèles Bien
      List<Bien> allBiens = rawProperties
          .map((p) => _mapApiPropertyToBien(p as Map<String, dynamic>))
          .toList();

      // Appliquer les filtres côté client
      final query = _searchController.text.toLowerCase().trim();
      List<Bien> filtered = allBiens.where((bien) {
        // Filtre texte
        if (query.isNotEmpty) {
          if (!bien.titre.toLowerCase().contains(query) &&
              !(bien.description?.toLowerCase().contains(query) ?? false) &&
              !bien.ville.toLowerCase().contains(query)) {
            return false;
          }
        }

        // Filtre type
        if (_selectedType != null &&
            !bien.typeBien.toLowerCase().contains(_selectedType!.toLowerCase())) {
          return false;
        }

        // Filtre ville
        if (_selectedVille != null &&
            !bien.ville.toLowerCase().contains(_selectedVille!.toLowerCase())) {
          return false;
        }

        // Filtre prix min
        if (_minPriceController.text.isNotEmpty) {
          final min = int.tryParse(_minPriceController.text);
          if (min != null && bien.loyerMensuel < min) return false;
        }

        // Filtre prix max
        if (_maxPriceController.text.isNotEmpty) {
          final max = int.tryParse(_maxPriceController.text);
          if (max != null && bien.loyerMensuel > max) return false;
        }

        // Filtre chambres
        if (_selectedBeds != null && bien.nbChambres != _selectedBeds) {
          return false;
        }

        // Filtre parking
        if (_parking && bien.statut == 'loué') return false;

        return true;
      }).toList();

      setState(() => _results = filtered);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur de connexion : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger les biens. Vérifiez votre connexion.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un bien...',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) {
                if (_searchController.text.isEmpty) _performSearch();
              },
            ),
          ),

          // Filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Type
                DropdownButton<String>(
                  value: _selectedType,
                  hint: const Text('Type'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les types')),
                    ..._types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedType = v);
                    _performSearch();
                  },
                ),
                const SizedBox(width: 8),
                // Ville
                DropdownButton<String>(
                  value: _selectedVille,
                  hint: const Text('Ville'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes les villes')),
                    ..._villes.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedVille = v);
                    _performSearch();
                  },
                ),
              ],
            ),
          ),

          // Prix
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Prix min (FCFA)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Prix max (FCFA)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
              ],
            ),
          ),

          // Bouton Rechercher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performSearch,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Recherche...' : 'Rechercher'),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Résultats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _isLoading
                  ? 'Chargement...'
                  : '${_results.length} bien(s) trouvé(s)',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 8),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          if (_results.isEmpty && !_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Aucun bien trouvé', style: TextStyle(color: Colors.grey)),
                    Text('Modifiez vos critères de recherche', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Liste des résultats
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final bien = _results[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: bien.imagePrincipale != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            bien.imagePrincipale!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.home, size: 40),
                          ),
                        )
                      : const Icon(Icons.home, size: 40),
                  title: Text(
                    bien.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bien.ville, style: const TextStyle(fontSize: 12)),
                      Text(
                        '${bien.loyerMensuel.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA/mois',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(bien.typeBien, style: const TextStyle(fontSize: 11)),
                      if (bien.nbChambres != null && bien.nbChambres! > 0)
                        Text('${bien.nbChambres} ch.', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  onTap: () {
                    // Navigation vers le détail du bien
                    Navigator.pushNamed(context, '/property-detail', arguments: {'id': bien.id});
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
