import 'package:url_launcher/url_launcher.dart';

class ExternalLauncher {
  static Future<void> launchWhatsApp(String phone, String message) async {
    // Nettoyer le numéro (pas de +, pas d'espaces)
    final cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    
    // Essayer d'abord l'URL universelle (plus stable)
    final webUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback Android Intent
        final androidUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");
        await launchUrl(androidUrl);
      }
    } catch (e) {
      // Si tout échoue, on ne crash pas
    }
  }

  static Future<void> launchCall(String phone) async {
    final uri = Uri.parse("tel:${phone.replaceAll(' ', '')}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<void> launchEmail(String email, {String subject = '', String body = ''}) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
