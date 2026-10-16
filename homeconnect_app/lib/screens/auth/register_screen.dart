import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/design_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telephoneController = TextEditingController();
  
  String _selectedRole = 'locataire';
  bool _acceptTerms = false;

  // Fichiers KYC sélectionnés
  File? _fileIdentite;
  String _typeIdentite = 'cni';
  File? _fileDomicile;
  String _typeDomicile = 'electricite';
  File? _filePropriete;
  String _typePropriete = 'titre_foncier';
  File? _fileRib;
  File? _fileAssurance;
  File? _fileCasParticulier;
  String? _typeCasParticulier;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(Function(File) onPicked) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _handleRegister() async {
    final appProvider = context.read<AppProvider>();
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appProvider.translate('accept_terms_error'))),
      );
      return;
    }

    // Vérification documents KYC obligatoires pour propriétaire
    if (_selectedRole == 'proprietaire') {
      final missing = <String>[];
      if (_fileIdentite == null)  missing.add('Pièce d\'identité');
      if (_fileDomicile == null)  missing.add('Justificatif de domicile');
      if (_filePropriete == null) missing.add('Justificatif de propriété');
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Documents manquants : ${missing.join(', ')}'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    // Créer le compte
    final success = await appProvider.register(
      nom:       _nomController.text.trim(),
      prenom:    _prenomController.text.trim(),
      email:     _emailController.text.trim(),
      password:  _passwordController.text,
      telephone: _telephoneController.text.trim(),
      role:      _selectedRole,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appProvider.error), backgroundColor: Colors.red),
      );
      return;
    }

    // Upload KYC pour les propriétaires
    String successMessage;
    if (_selectedRole == 'proprietaire') {
      await _uploadKycDocuments();
      if (!mounted) return;
      successMessage = '✅ Inscription réussie ! Vos documents KYC ont été soumis. L\'admin validera votre compte sous 24–48h.';
    } else {
      successMessage = '✅ Inscription réussie ! Connectez-vous avec vos identifiants.';
    }

    if (!mounted) return;
    // Naviguer vers login en passant le message de succès
    Navigator.pushReplacementNamed(
      context,
      '/',
      arguments: successMessage,
    );
  }

  Future<void> _uploadKycDocuments() async {
    // Upload chaque fichier et récupérer l'URL
    Future<String?> upload(File? file) async {
      if (file == null) return null;
      return ApiService.uploadImage(file.path);
    }

    final identiteUrl  = await upload(_fileIdentite);
    final domicileUrl  = await upload(_fileDomicile);
    final proprieteUrl = await upload(_filePropriete);
    final ribUrl       = await upload(_fileRib);
    final assuranceUrl = await upload(_fileAssurance);
    final casUrl       = await upload(_fileCasParticulier);

    // Envoyer les métadonnées KYC à l'API
    await ApiService.post('/api/kyc/submit', {
      'kycIdentiteUrl':       identiteUrl,
      'kycIdentiteType':      _typeIdentite,
      'kycDomicileUrl':       domicileUrl,
      'kycDomicileType':      _typeDomicile,
      'kycProprieteUrl':      proprieteUrl,
      'kycProprieteType':     _typePropriete,
      if (ribUrl != null)        'kycRibUrl':       ribUrl,
      if (assuranceUrl != null)  'kycAssuranceUrl': assuranceUrl,
      if (casUrl != null)        'kycCasParticulierUrl': casUrl,
      if (_typeCasParticulier != null) 'kycCasParticulier': _typeCasParticulier,
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(appProvider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRoleSelector(appProvider),
                        const SizedBox(height: 32),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ModernTextField(
                                controller: _prenomController,
                                label: appProvider.translate('first_name'),
                                icon: Icons.person_outline,
                                validator: (v) => v?.isEmpty ?? true ? appProvider.translate('required_field') : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ModernTextField(
                                controller: _nomController,
                                label: appProvider.translate('last_name'),
                                icon: Icons.person_outline,
                                validator: (v) => v?.isEmpty ?? true ? appProvider.translate('required_field') : null,
                              ),
                            ),
                          ],
                        ),
                        
                        ModernTextField(
                          controller: _emailController,
                          label: appProvider.translate('email_address'),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.isEmpty ?? true) return appProvider.translate('email_required');
                            if (!v!.contains('@')) return appProvider.translate('email_invalid');
                            return null;
                          },
                        ),
                        
                        ModernTextField(
                          controller: _telephoneController,
                          label: appProvider.translate('phone_label'),
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v?.isEmpty ?? true ? appProvider.translate('required_field') : null,
                        ),
                        
                        ModernPasswordField(
                          controller: _passwordController,
                          label: appProvider.translate('password_label'),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return appProvider.translate('required_field');
                            if (v!.length < 6) return appProvider.translate('min_char');
                            return null;
                          },
                        ),
                        
                        ModernPasswordField(
                          controller: _confirmPasswordController,
                          label: appProvider.translate('confirm_password'),
                          validator: (v) {
                            if (v != _passwordController.text) return appProvider.translate('passwords_match');
                            return null;
                          },
                        ),
                        
                        if (_selectedRole == 'proprietaire') ...[
                          const SizedBox(height: 24),
                          _buildKycSection(appProvider),
                        ],
                        
                        const SizedBox(height: 16),
                        _buildTerms(appProvider),
                        const SizedBox(height: 32),
                        
                        ModernButton(
                          text: appProvider.translate('create_account_btn'),
                          isLoading: appProvider.isLoading,
                          onPressed: _handleRegister,
                        ),
                        
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(appProvider.translate('already_registered'), style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6))),
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
    );
  }

  Widget _buildHeader(AppProvider appProvider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.getTextColor(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              appProvider.translate('register_title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.getTextColor(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildRoleTab(appProvider.translate('tenant'), 'locataire', Icons.person_search),
          _buildRoleTab(appProvider.translate('owner'), 'proprietaire', Icons.vpn_key_outlined),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String label, String value, IconData icon) {
    final isSelected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? [BoxShadow(color: AppColors.accentOrange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.getTextColor(context).withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.getTextColor(context).withValues(alpha: 0.5), 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerms(AppProvider appProvider) {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          activeColor: AppColors.accentOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (v) => setState(() => _acceptTerms = v ?? false),
        ),
        Expanded(
          child: Text(
            appProvider.translate('accept_terms'),
            style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 12),
          ),
        ),
      ],
    );
  }



  // ── Section KYC complète ─────────────────────────────────────────────────

  Widget _buildKycSection(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('Vérification d\'identité (KYC)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Documents requis pour publier des biens. L\'admin validera sous 24–48h.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. Pièce d'identité (obligatoire)
          _kycDocRow(
            num: '1',
            title: 'Pièce d\'identité *',
            required: true,
            file: _fileIdentite,
            typeWidget: DropdownButton<String>(
              value: _typeIdentite,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'cni', child: Text('CNI', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'passeport', child: Text('Passeport', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _typeIdentite = v!),
            ),
            onPick: () => _pickFile((f) => setState(() => _fileIdentite = f)),
          ),

          // 2. Justificatif de domicile (obligatoire)
          _kycDocRow(
            num: '2',
            title: 'Justificatif de domicile *',
            required: true,
            file: _fileDomicile,
            typeWidget: DropdownButton<String>(
              value: _typeDomicile,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'electricite', child: Text('Facture électricité', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'eau',         child: Text('Facture eau',         style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'telephone',   child: Text('Facture téléphone',   style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'taxe_fonciere', child: Text('Taxe foncière',     style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'quittance',   child: Text('Quittance loyer',     style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _typeDomicile = v!),
            ),
            onPick: () => _pickFile((f) => setState(() => _fileDomicile = f)),
          ),

          // 3. Justificatif de propriété (obligatoire)
          _kycDocRow(
            num: '3',
            title: 'Justificatif de propriété *',
            required: true,
            file: _filePropriete,
            typeWidget: DropdownButton<String>(
              value: _typePropriete,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'titre_foncier',      child: Text('Titre foncier',      style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'attestation_notaire', child: Text('Attestation notaire', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'acte_vente',         child: Text('Acte de vente',       style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'donation_succession', child: Text('Don / Succession',    style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _typePropriete = v!),
            ),
            onPick: () => _pickFile((f) => setState(() => _filePropriete = f)),
          ),

          // Optionnels
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Documents complémentaires (facultatifs)',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
            children: [
              _kycDocRow(
                num: '4',
                title: 'RIB bancaire',
                required: false,
                file: _fileRib,
                onPick: () => _pickFile((f) => setState(() => _fileRib = f)),
              ),
              _kycDocRow(
                num: '5',
                title: 'Assurance PNO',
                required: false,
                file: _fileAssurance,
                onPick: () => _pickFile((f) => setState(() => _fileAssurance = f)),
              ),
            ],
          ),

          // Cas particuliers
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Cas particuliers (Copropriété / SCI)',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
            children: [
              Row(
                children: [
                  _kycTypeChip('Copropriété', 'copropriete'),
                  const SizedBox(width: 8),
                  _kycTypeChip('SCI', 'sci'),
                ],
              ),
              const SizedBox(height: 8),
              _kycDocRow(
                num: '6',
                title: 'Document copropriété / SCI',
                required: false,
                file: _fileCasParticulier,
                onPick: () => _pickFile((f) => setState(() => _fileCasParticulier = f)),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.access_time, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Statut : en_attente → certifié après validation admin. '
                    'Seul un compte certifié peut publier des biens.',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kycDocRow({
    required String num,
    required String title,
    required bool required,
    required File? file,
    Widget? typeWidget,
    required VoidCallback onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: required ? Colors.orange : Colors.grey.shade400,
                child: Text(num, style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (file != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else
                GestureDetector(
                  onTap: onPick,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Joindre', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (file != null) ...[
            const SizedBox(height: 4),
            Text(file.path.split('/').last,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
          if (typeWidget != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 28),
                const Text('Type : ', style: TextStyle(fontSize: 12)),
                typeWidget,
              ],
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _kycTypeChip(String label, String value) {
    final selected = _typeCasParticulier == value;
    return GestureDetector(
      onTap: () => setState(() => _typeCasParticulier = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.orange,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}