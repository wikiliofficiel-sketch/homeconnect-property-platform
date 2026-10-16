import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/design_widgets.dart';

/// Écran Centre d'Aide Premium avec FAQ et Tutoriels
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId;
  int? _selectedTutorialId;
  bool _showContactForm = false;

  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactSubjectController = TextEditingController();
  final _contactMessageController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactSubjectController.dispose();
    _contactMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primaryMedium,
              AppColors.primaryDark.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<SupportProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _showContactForm 
                        ? _buildContactForm()
                        : _selectedTutorialId != null
                            ? _buildTutorialDetails(provider)
                            : _selectedCategoryId != null 
                                ? _buildCategoryDetails(provider)
                                : _buildMainContent(provider),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: !_showContactForm && _selectedCategoryId == null ? FloatingActionButton.extended(
        onPressed: () => setState(() => _showContactForm = true),
        icon: const Icon(Icons.support_agent),
        label: const Text('Support'),
        backgroundColor: AppColors.accentOrange,
      ) : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedCategoryId != null || _showContactForm || _selectedTutorialId != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => setState(() {
                    _selectedCategoryId = null;
                    _selectedTutorialId = null;
                    _showContactForm = false;
                  }),
                ),
              Text(
                _showContactForm 
                    ? 'Contactez-nous' 
                    : (_selectedTutorialId != null 
                        ? 'Tutoriel' 
                        : (_selectedCategoryId != null ? 'Détails' : 'Centre d\'Aide')),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: BorderRadius.circular(20),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Chercher une fonctionnalité...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: AppColors.accentOrange),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMainContent(SupportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeaderWidget(
            title: 'Catégories',
            icon: Icons.category,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final cat = provider.categories[index];
              return _buildCategoryCard(cat);
            },
          ),
          const SizedBox(height: 32),
          const SectionHeaderWidget(
            title: 'Tutoriels populaires',
            icon: Icons.lightbulb_outline,
          ),
          const SizedBox(height: 16),
          ...provider.tutorials.map((tuto) {
            IconData icon = Icons.lightbulb_outline;
            if (tuto.titre.contains('message')) icon = Icons.message;
            if (tuto.titre.contains('image')) icon = Icons.image;
            if (tuto.titre.contains('unique')) icon = Icons.security;
            if (tuto.titre.contains('position')) icon = Icons.location_on;
            
            return _buildTutorialQuickLink(tuto.titre, icon, tuto.id);
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(dynamic category) {
    IconData iconData;
    switch (category.icon) {
      case 'message': iconData = Icons.message; break;
      case 'call': iconData = Icons.call; break;
      case 'groups': iconData = Icons.groups; break;
      case 'security': iconData = Icons.security; break;
      case 'smart_toy': iconData = Icons.smart_toy; break;
      default: iconData = Icons.help_outline;
    }

    return InkWell(
      onTap: () => setState(() => _selectedCategoryId = category.id),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: AppColors.accentOrange, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              category.titre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialQuickLink(String title, IconData icon, int id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedTutorialId = id),
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accentBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialDetails(SupportProvider provider) {
    final tuto = provider.tutorials.firstWhere((t) => t.id == _selectedTutorialId);
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tuto.titre,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Catégorie : ${tuto.categorie}',
          style: TextStyle(color: AppColors.accentOrange.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        ...tuto.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return _buildStepItem(index + 1, step.action, step.description);
        }),
      ],
    );
  }

  Widget _buildStepItem(int number, String action, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDetails(SupportProvider provider) {
    final category = provider.categories.firstWhere((c) => c.id == _selectedCategoryId);
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.accentOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              category.description,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...category.items.map((item) => _buildFAQItem(item)),
      ],
    );
  }

  Widget _buildFAQItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          title: Text(
            item.question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          iconColor: AppColors.accentOrange,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.all(12),
          tilePadding: EdgeInsets.zero,
          children: [
            Text(
              item.reponse,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField(_contactNameController, 'Nom complet', Icons.person),
          const SizedBox(height: 16),
          _buildTextField(_contactEmailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(_contactSubjectController, 'Sujet', Icons.subject),
          const SizedBox(height: 16),
          _buildTextField(_contactMessageController, 'Message', Icons.message, maxLines: 5),
          const SizedBox(height: 32),
          ActionButtonWidget(
            label: 'Envoyer ma demande',
            onPressed: _submitForm,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          icon: Icon(icon, color: AppColors.accentOrange, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _submitForm() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demande envoyée ! Nous reviendrons vers vous rapidement.'),
        backgroundColor: AppColors.success,
      ),
    );
    setState(() => _showContactForm = false);
  }
}