# HomeConnect Platform

Plateforme immobilière complète pour le Bénin, intégrant :
- **Back-end** : Symfony 7.2
- **Application mobile** : Flutter 2.1 (homeconnect_app)
- **Application secondaire** : Flutter (immobenin_app)
- **Paiement** : Intégration FedaPay

## 🏗️ Structure du projet

```
HomeConnect/
├── homeconnect/              # Back-end Symfony 7.2
├── homeconnect_app/          # Application mobile Flutter principale
├── immobenin_app/            # Application secondaire Flutter
└── README.md                 # Ce fichier
```

## 🚀 Prérequis

### Back-end (Symfony)
- PHP 8.2+
- Composer
- MySQL 5.7+ ou PostgreSQL
- Symfony CLI (optionnel)

### Applications mobiles (Flutter)
- Flutter SDK 2.1+
- Dart SDK
- Android Studio / Xcode (pour les émulateurs)
- Compte FedaPay pour les paiements

## 🔧 Installation

### 1. Back-end Symfony
```bash
cd homeconnect
composer install
cp .env.local.example .env
# Éditer .env avec vos paramètres de base de données
php bin/console doctrine:database:create
php bin/console doctrine:migrations:migrate
php bin/console server:start
```

### 2. Application Flutter Principale
```bash
cd homeconnect_app
flutter pub get
flutter run
```

### 3. Application Flutter Secondaire
```bash
cd immobenin_app
flutter pub get
flutter run
```

## 🔑 Configuration des secrets

### FedaPay
Obtenez vos clés API depuis [FedaPay Dashboard](https://fedepay.com) et configurez-les dans :

- **Back-end** : `homeconnect/.env`
  ```
  FEDAPAY_API_KEY=your_api_key_here
  FEDAPAY_ENVIRONMENT=test  # ou production
  ```

- **Applications Flutter** : 
  - `homeconnect_app/firebase.json` (si utilisant Firebase)
  - `immobenin_app/firebase.json` (si utilisant Firebase)

## 📚 Documentation détaillée

- [Documentation du back-end](homeconnect/ADMIN_DOCUMENTATION.md)
- [Guide de déploiement](homeconnect/DEPLOYMENT_GUIDE.md)
- [Checklist d'implémentation](homeconnect/IMPLEMENTATION_CHECKLIST.md)
- [Documentation propriétaire](homeconnect/OWNER_DOCUMENTATION.md)
- [Guides de test](homeconnect/TESTING_GUIDE.md)

## 💳 Paiement avec FedaPay

Cette plateforme intègre FedaPay pour les transactions sécurisées :
- Paiements par carte bancaire
- Mobile Money (MTN Money, Moov Money, etc.)
- Virements bancaires
- Portefeuilles électroniques

## 🤝 Contribution

1. Forkez le dépôt
2. Créez votre branche de fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Committez vos changements (`git commit -m 'Add amazing feature'`)
4. Pushez vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence privée - Tous droits réservés © 2026 HomeConnect

## 📞 Contact

Pour le support ou les questions :
- Email: support@homeconnect.bj
- Téléphone: +229 XX XX XX XX