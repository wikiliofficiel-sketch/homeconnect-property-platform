import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final _picker = ImagePicker();

  static Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
    } catch (e) {
      return null;
    }
  }

  /// Convertit une image en data URL base64 (pas d'upload séparé).
  /// Le serveur décodera et sauvegarde lors de la création du bien.
  static Future<String?> uploadImage(XFile file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        debugPrint('[Storage] Image trop grande (${bytes.length ~/ 1024}KB)');
        return null;
      }
      debugPrint('[Storage] Conversion base64: ${bytes.length ~/ 1024}KB');
      final b64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$b64';
    } catch (e) {
      debugPrint('[Storage] Erreur conversion: $e');
      return null;
    }
  }

  static Future<XFile?> pickVideo() async {
    try {
      return await _picker.pickVideo(source: ImageSource.gallery);
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadFile(XFile file, String path) async {
    return uploadImage(file, path);
  }
}
