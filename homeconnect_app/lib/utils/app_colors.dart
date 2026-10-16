import 'package:flutter/material.dart';

class AppColors {
  // Palette principale - Dégradés
  static const primaryDark = Color(0xFF1A1A2E);
  static const primaryMedium = Color(0xFF16213E);
  static const primaryLight = Color(0xFF0F3460);
  
  // Accents
  static const accentOrange = Color(0xFFFF6B35);
  static const accentBlue = Color(0xFF4ECDC4);
  static const accentGreen = Color(0xFF2ECC71);
  static const accentRed = Color(0xFFE74C3C);
  static const accentPurple = Color(0xFF9B59B6);
  static const accentYellow = Color(0xFFF1C40F);
  static const accentTeal = Color(0xFF1ABC9C);
  
  // WhatsApp Style Colors
  static const whatsappGreen = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF075E54);
  static const whatsappLightGreen = Color(0xFF128C7E);
  static const whatsappBlue = Color(0xFF34B7F1);
  static const whatsappBubbleMe = Color(0xFFE7FFDB);
  static const whatsappBubbleOther = Colors.white;
  static const whatsappDarkBubbleMe = Color(0xFF005C4B);
  static const whatsappDarkBubbleOther = Color(0xFF1F2C34);
  static const whatsappDarkBg = Color(0xFF0B141A);
  static const whatsappReadBlue = Color(0xFF53BDEB);
  
  // Couleurs principales requises
  static const primaryGreen = Color(0xFF2ECC71);
  static const primaryBlue = Color(0xFF4ECDC4);
  static const ctaOrange = Color(0xFFFF6B35);
  
  static const backgroundLight = Color(0xFFF8F9FA);
  static const backgroundNeutral = Color(0xFFEAEAEA);
  static const backgroundDark = Color(0xFF0D0D1A);
  
  static Color getScaffoldBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? backgroundDark 
        : const Color(0xFFF0F2F5); // Slightly darker gray for light mode background
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF1A1A2E) 
        : Colors.white;
  }
  
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? Colors.white 
        : const Color(0xFF1A1A2E);
  }

  static Color getSubtitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? Colors.white70 
        : Colors.black54;
  }

  static Color getInputFillColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.black.withValues(alpha: 0.04);
  }

  static Color getInputBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? Colors.white.withValues(alpha: 0.1) 
        : Colors.black.withValues(alpha: 0.08);
  }
  
  // Couleurs de texte
  static const textDark = Color(0xFF1A1A2E);
  static const textMedium = Color(0xFF555555);
  static const textLight = Color(0xFF999999);
  
  // Couleurs d'état
  static const success = Color(0xFF2ECC71);
  static const error = Color(0xFFE74C3C);
  static const warning = Color(0xFFF1C40F);
  
  // Text colors
  static const textWhite = Colors.white;
  static const textWhite70 = Colors.white70;
  static const textWhite54 = Colors.white54;
  static LinearGradient getBackgroundGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryDark, primaryMedium, primaryLight],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF0F2F5)],
          );
  }
  
  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [accentOrange, Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const secondaryGradient = LinearGradient(
    colors: [accentBlue, Color(0xFF45B7D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const successGradient = LinearGradient(
    colors: [accentGreen, Color(0xFF27AE60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const dangerGradient = LinearGradient(
    colors: [accentRed, Color(0xFFC0392B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const warningGradient = LinearGradient(
    colors: [accentYellow, Color(0xFFE67E22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Utility methods
  static Color getRoleColor(String role) {
    switch (role) {
      case 'locataire': return accentBlue;
      case 'proprietaire': return accentOrange;
      case 'admin': return accentPurple;
      case 'partenaire': return accentTeal;
      default: return Colors.grey;
    }
  }
  
  // Card and Border colors
  static const cardDark = Color(0xFF1A1A2E);
  static const borderColor = Color(0xFF333333);
  static const primary = accentOrange;
  
  static Color getStatusColor(String status) {
    switch (status) {
      case 'actif': return accentGreen;
      case 'en_attente': return accentYellow;
      case 'suspendu': return accentRed;
      case 'certifie': return accentGreen;
      case 'rejete': return accentRed;
      default: return Colors.grey;
    }
  }
}