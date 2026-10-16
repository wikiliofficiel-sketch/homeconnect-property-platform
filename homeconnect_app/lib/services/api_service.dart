import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Cache mémoire simple avec TTL par endpoint
class _Cache {
  static final Map<String, _Entry> _store = {};

  static dynamic get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiry)) { _store.remove(key); return null; }
    return e.data;
  }

  static void set(String key, dynamic data, {int ttlSeconds = 30}) {
    _store[key] = _Entry(data, DateTime.now().add(Duration(seconds: ttlSeconds)));
  }

  static void invalidate(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  static void clear() => _store.clear();
}

class _Entry {
  final dynamic data;
  final DateTime expiry;
  _Entry(this.data, this.expiry);
}

/// Service API — backend Symfony via JWT
class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const _kTimeout = Duration(seconds: 10);
  static const _kUpload  = Duration(seconds: 60);

  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Appelé automatiquement quand le serveur répond 401 (token expiré ou invalide).
  /// AuthProvider le positionne pour déclencher le logout + redirection login.
  static Function()? onUnauthorized;

  static void setToken(String token) {
    _headers['Authorization'] = 'Bearer $token';
    _Cache.clear();
  }

  static void clearToken() {
    _headers.remove('Authorization');
    _Cache.clear();
  }

  /// Invalide le cache pour un préfixe d'URL donné (ex. après une mutation)
  static void invalidateCache(String urlPrefix) {
    _Cache.invalidate(urlPrefix);
  }

  /// Headers d'auth pour les requêtes multipart (sans Content-Type JSON)
  static Map<String, String> get authHeaders {
    final h = <String, String>{'Accept': 'application/json'};
    if (_headers.containsKey('Authorization')) {
      h['Authorization'] = _headers['Authorization']!;
    }
    return h;
  }

  // ── JWT utilities ─────────────────────────────────────────────────────────

  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Retourne true si le token est expiré (ou invalide).
  static bool isTokenExpired(String token) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > (exp as int);
  }

  /// Retourne true si le token expire dans moins de [minutesBefore] minutes.
  static bool isTokenExpiringSoon(String token, {int minutesBefore = 10}) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return false;
    final threshold = DateTime.now().millisecondsSinceEpoch ~/ 1000 + minutesBefore * 60;
    return threshold > (exp as int);
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  /// Demande un nouveau JWT au serveur (nécessite que le token actuel soit encore valide).
  /// Retourne le nouveau token ou null si l'opération échoue.
  static Future<String?> refreshToken() async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/auth/token/refresh'),
        headers: _headers,
      ).timeout(_kTimeout);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null) {
          setToken(newToken);
          return newToken;
        }
      }
      if (r.statusCode == 401) {
        onUnauthorized?.call();
      }
      return null;
    } catch (e) {
      debugPrint('[API] refreshToken error: $e');
      return null;
    }
  }

  // ── Intercepteur 401 ──────────────────────────────────────────────────────

  static void _handleUnauthorized() {
    debugPrint('[API] Token invalide ou expiré — déconnexion forcée');
    onUnauthorized?.call();
  }

  // ── Helper GET avec cache ─────────────────────────────────────────────────

  static Future<dynamic> _get(String url, {int ttl = 30}) async {
    final cached = _Cache.get(url);
    if (cached != null) return cached;
    try {
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(_kTimeout);
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _Cache.set(url, data, ttlSeconds: ttl);
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('[API] GET $url error: $e');
      return null;
    }
  }

  /// Wrapper pour toutes les requêtes mutation (POST/PATCH/DELETE/PUT).
  /// Gère automatiquement le 401 et les erreurs réseau.
  static Future<http.Response?> _request(Future<http.Response> Function() fn) async {
    try {
      final r = await fn();
      if (r.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      return r;
    } catch (e) {
      debugPrint('[API] Request error: $e');
      return null;
    }
  }

  // ── Vérification connectivité ─────────────────────────────────────────────

  static Future<bool> checkConnectivity() async {
    try {
      await http.get(Uri.parse('$baseUrl/api/health'), headers: {
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return true;
    }
  }

  // ─── AUTHENTIFICATION ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login_check'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(_kTimeout);
      debugPrint('[API] login → ${response.statusCode}');
      if (response.statusCode == 200) return jsonDecode(response.body);
      debugPrint('[API] login failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[API] login error: $e');
      return null;
    }
  }

  static Future<String?> registerWithError({
    required String email,
    required String password,
    String? firstname,
    String? lastname,
    String? role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
          'prenom': firstname,
          'nom': lastname,
          'role': role,
        }),
      ).timeout(_kTimeout);
      debugPrint('[API] register → ${response.statusCode}');
      if (response.statusCode == 201) return null;
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          final v = body['violations'];
          if (v is List && v.isNotEmpty) return v.first['title']?.toString() ?? 'Erreur.';
          return body['detail']?.toString()
              ?? body['message']?.toString()
              ?? body['error']?.toString()
              ?? 'Inscription échouée.';
        }
        if (body is List && body.isNotEmpty) return body.first['message']?.toString() ?? 'Erreur.';
      } catch (_) {}
      return 'Inscription échouée (code ${response.statusCode}).';
    } catch (e) {
      return 'Impossible de joindre le serveur.';
    }
  }

  static Future<bool> register({
    required String email, required String password,
    String? firstname, String? lastname, String? role,
  }) async {
    final err = await registerWithError(email: email, password: password,
        firstname: firstname, lastname: lastname, role: role);
    return err == null;
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAdminUsers() async {
    try {
      final data = await _get('$baseUrl/api/admin/users', ttl: 30);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getAdminUsers error: $e'); return []; }
  }

  /// Tous les biens (tous statuts) — admin uniquement
  static Future<List<dynamic>> getAdminProperties() async {
    try {
      final data = await _get('$baseUrl/api/admin/properties', ttl: 5);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getAdminProperties error: $e'); return []; }
  }

  /// Approuver un bien (admin)
  static Future<bool> approveProperty(int id) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/properties/$id/approve'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null) invalidateCache('$baseUrl/api/admin/properties');
    return r != null && r.statusCode == 200;
  }

  /// Rejeter un bien (admin)
  static Future<bool> rejectProperty(int id) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/properties/$id/reject'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null) invalidateCache('$baseUrl/api/admin/properties');
    return r != null && r.statusCode == 200;
  }

  // ─── PROPRIÉTÉS ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getProperties() async {
    try {
      final data = await _get('$baseUrl/api/properties', ttl: 10);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getProperties error: $e'); return []; }
  }

  static Future<Map<String, dynamic>?> getProperty(int id) async {
    try {
      final data = await _get('$baseUrl/api/properties/$id', ttl: 10);
      return data as Map<String, dynamic>?;
    } catch (e) { debugPrint('[API] getProperty error: $e'); return null; }
  }

  static Future<List<dynamic>> getOwnerProperties() async {
    try {
      final data = await _get('$baseUrl/api/properties/mine', ttl: 30);
      if (data is Map) return (data['properties'] as List?) ?? [];
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getOwnerProperties error: $e'); return []; }
  }

  static Future<bool> createProperty(Map<String, dynamic> propertyData) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/properties/new'),
      headers: _headers, body: jsonEncode(propertyData),
    ).timeout(_kTimeout));
    _Cache.invalidate('$baseUrl/api/properties');
    return r != null && (r.statusCode == 201 || r.statusCode == 200);
  }

  // ─── MESSAGES ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getConversations() async {
    try {
      final data = await _get('$baseUrl/api/messages/conversations', ttl: 10);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getConversations error: $e'); return []; }
  }

  static Future<List<dynamic>> getConversationMessages(int partnerId) async {
    try {
      final data = await _get('$baseUrl/api/messages/conversation/$partnerId', ttl: 5);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getConversationMessages error: $e'); return []; }
  }

  static Future<bool> markMessageRead(int messageId) async {
    final r = await _request(() => http.patch(
      Uri.parse('$baseUrl/api/messages/$messageId/read'),
      headers: _headers,
    ).timeout(_kTimeout));
    _Cache.invalidate('$baseUrl/api/messages/conversations');
    return r != null && r.statusCode == 200;
  }

  static Future<bool> reactToMessage(int messageId, String emoji) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/react'),
      headers: _headers, body: jsonEncode({'emoji': emoji}),
    ).timeout(_kTimeout));
    _Cache.invalidate('$baseUrl/api/messages');
    return r != null && r.statusCode == 200;
  }

  static Future<bool> deleteMessage(int messageId, {bool forAll = false}) async {
    final r = await _request(() => http.delete(
      Uri.parse('$baseUrl/api/messages/$messageId/delete'),
      headers: _headers, body: jsonEncode({'forAll': forAll}),
    ).timeout(_kTimeout));
    _Cache.invalidate('$baseUrl/api/messages');
    return r != null && r.statusCode == 200;
  }

  static Future<bool> editMessage(int messageId, String newContent) async {
    final r = await _request(() => http.patch(
      Uri.parse('$baseUrl/api/messages/$messageId/edit'),
      headers: _headers, body: jsonEncode({'content': newContent}),
    ).timeout(_kTimeout));
    _Cache.invalidate('$baseUrl/api/messages');
    return r != null && r.statusCode == 200;
  }

  static Future<bool> forwardMessage(int messageId, List<int> receiverIds) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/forward'),
      headers: _headers, body: jsonEncode({'receiverIds': receiverIds}),
    ).timeout(_kTimeout));
    return r != null && r.statusCode == 201;
  }

  static Future<bool> logCall({required int receiverId, required String callType,
      required String status, int? duration}) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/messages/call-log'),
      headers: _headers, body: jsonEncode({
        'receiverId': receiverId, 'callType': callType, 'status': status,
        if (duration != null) 'duration': duration,
      }),
    ).timeout(_kTimeout));
    return r != null && r.statusCode == 201;
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required int receiverId, required String content,
    int? replyToId, String type = 'text',
    String? attachmentUrl, String? attachmentName, int? voiceDuration,
  }) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/messages/send'),
      headers: _headers, body: jsonEncode({
        'receiverId': receiverId, 'content': content, 'type': type,
        if (replyToId != null) 'replyToId': replyToId,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentName != null) 'attachmentName': attachmentName,
        if (voiceDuration != null) 'voiceDuration': voiceDuration,
      }),
    ).timeout(_kTimeout));
    debugPrint('[API] sendMessage → ${r?.statusCode}');
    if (r != null && (r.statusCode == 201 || r.statusCode == 200)) {
      _Cache.invalidate('$baseUrl/api/messages/conversation/$receiverId');
      _Cache.invalidate('$baseUrl/api/messages/conversations');
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<List<dynamic>> getMessages(String userEmail) async {
    try {
      final data = await _get('$baseUrl/api/messages/$userEmail', ttl: 10);
      return data as List? ?? [];
    } catch (e) { return []; }
  }

  // ─── ABONNEMENT ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final data = await _get('$baseUrl/api/subscription/plans', ttl: 300);
      return data as List? ?? [];
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>?> getCurrentSubscription() async {
    try {
      final data = await _get('$baseUrl/api/subscription/current', ttl: 30);
      return data as Map<String, dynamic>?;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> upgradeSubscription({
    required String plan, int months = 1,
  }) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/subscription/upgrade'),
      headers: _headers, body: jsonEncode({'plan': plan, 'months': months}),
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/subscription');
      return jsonDecode(r.body);
    }
    return null;
  }

  // ─── CANDIDATURES ─────────────────────────────────────────────────────────

  /// Candidatures du locataire connecté
  static Future<List<dynamic>> getTenantApplications() async {
    try {
      final data = await _get('$baseUrl/api/applications', ttl: 15);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getTenantApplications error: $e'); return []; }
  }

  /// Candidatures reçues sur les biens du propriétaire connecté
  static Future<List<dynamic>> getOwnerApplications() async {
    try {
      final data = await _get('$baseUrl/api/applications/owner', ttl: 15);
      return data as List? ?? [];
    } catch (e) { debugPrint('[API] getOwnerApplications error: $e'); return []; }
  }

  static Future<bool> applyForProperty(Map<String, dynamic> applicationData) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/applications/new'),
      headers: _headers, body: jsonEncode(applicationData),
    ).timeout(_kTimeout));
    return r != null && (r.statusCode == 201 || r.statusCode == 200);
  }

  static Future<bool> updateApplicationStatus(int applicationId, String status) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/applications/$applicationId/status'),
      headers: _headers, body: jsonEncode({'status': status}),
    ).timeout(_kTimeout));
    return r != null && r.statusCode == 200;
  }

  // ─── PAIEMENTS ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> initiatePayment({
    required double amount, required String description,
    String? email, int? rentalId,
  }) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/payments/initiate'),
      headers: _headers, body: jsonEncode({
        'amount': amount, 'description': description, 'email': email,
        if (rentalId != null) 'rental_id': rentalId,
      }),
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  // ─── IMAGES ───────────────────────────────────────────────────────────────

  static Future<String?> uploadImage(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload/image'));
      request.headers.addAll(_headers);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send().timeout(_kUpload);
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      if (response.statusCode == 200) {
        return jsonDecode(await response.stream.bytesToString())['url'];
      }
      return null;
    } catch (e) { debugPrint('[API] uploadImage error: $e'); return null; }
  }

  // ─── SIGNALEMENTS ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> createReport({
    required String motif, String type = 'user', String priorite = 'medium',
    int? propertyId, int? targetUserId,
  }) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/reports'),
      headers: _headers, body: jsonEncode({
        'motif': motif, 'message': motif, 'type': type, 'priorite': priorite,
        if (propertyId != null) 'propertyId': propertyId,
        if (targetUserId != null) 'targetUserId': targetUserId,
      }),
    ).timeout(_kTimeout));
    if (r != null && (r.statusCode == 201 || r.statusCode == 200)) return jsonDecode(r.body);
    return null;
  }

  static Future<List<dynamic>> getReports() async {
    try {
      final data = await _get('$baseUrl/api/reports', ttl: 60);
      return data as List? ?? [];
    } catch (e) { return []; }
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  static void logout() {
    clearToken();
    _Cache.clear();
  }

  // ─── SYNC BULK ────────────────────────────────────────────────────────────

  static Future<bool> importBulk(Map<String, dynamic> data) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/import-bulk'),
      headers: _headers, body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30)));
    return r != null && r.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> exportBulk() async {
    try {
      final data = await _get('$baseUrl/api/export-bulk', ttl: 120);
      return data as Map<String, dynamic>?;
    } catch (e) { return null; }
  }

  // ─── FAVORIS ──────────────────────────────────────────────────────────────

  static Future<bool> isFavorite(int propertyId) async {
    try {
      final data = await _get('$baseUrl/api/properties/$propertyId/is-favorite', ttl: 0);
      return (data as Map<String, dynamic>?)?['isFavorite'] == true;
    } catch (_) { return false; }
  }

  static Future<bool?> toggleFavorite(int propertyId) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/properties/$propertyId/toggle-favorite'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/properties/$propertyId/is-favorite');
      _Cache.invalidate('$baseUrl/api/properties/favorites');
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return d['isFavorite'] as bool?;
    }
    return null;
  }

  static Future<List<dynamic>> getFavorites() async {
    try {
      final data = await _get('$baseUrl/api/properties/favorites', ttl: 30);
      return data as List? ?? [];
    } catch (_) { return []; }
  }

  // ─── RÉACTIONS (LIKE/DISLIKE) ─────────────────────────────────────────────

  static Future<Map<String, dynamic>?> reactToProperty(int propertyId, String type) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/properties/$propertyId/react'),
      headers: _headers,
      body: jsonEncode({'type': type}),
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/properties/$propertyId');
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    return null;
  }

  // ─── ADMIN LOGS ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAdminLogs({
    String? action,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/admin/logs').replace(queryParameters: {
        if (action != null && action.isNotEmpty) 'action': action,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      });
      final data = await _get(uri.toString(), ttl: 60);
      return data is List ? data : [];
    } catch (_) { return []; }
  }

  // ─── ADMIN ACTIONS UTILISATEURS ───────────────────────────────────────────

  static Future<bool> adminKycApprove(int userId) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/kyc/$userId/approve'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/admin/users');
      return true;
    }
    return false;
  }

  static Future<bool> adminKycReject(int userId, {String reason = ''}) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/kyc/$userId/reject'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/admin/users');
      return true;
    }
    return false;
  }

  static Future<bool> adminDeleteUser(int userId) async {
    final r = await _request(() => http.delete(
      Uri.parse('$baseUrl/api/admin/users/$userId'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/admin/users');
      return true;
    }
    return false;
  }

  static Future<bool> adminSuspendProperty(int propertyId, {String motif = ''}) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/properties/$propertyId/suspend'),
      headers: _headers,
      body: jsonEncode({'motif': motif}),
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/admin/properties');
      return true;
    }
    return false;
  }

  static Future<bool> adminDeleteProperty(int propertyId) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl/api/admin/properties/$propertyId/delete'),
      headers: _headers,
    ).timeout(_kTimeout));
    if (r != null && r.statusCode == 200) {
      _Cache.invalidate('$baseUrl/api/admin/properties');
      return true;
    }
    return false;
  }

  // ─── STATISTIQUES PROPRIÉTAIRE ────────────────────────────────────────────

  /// Statistiques agrégées : vues, taux conversion, revenus, commissions
  static Future<Map<String, dynamic>?> getOwnerStatistics() async {
    try {
      final data = await _get('$baseUrl/api/properties/statistics', ttl: 60);
      return data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[API] getOwnerStatistics error: $e');
      return null;
    }
  }

  // ─── COMMISSIONS ──────────────────────────────────────────────────────────

  /// Commissions générées (admin seulement)
  static Future<List<dynamic>> getAdminCommissions() async {
    try {
      final data = await _get('$baseUrl/api/admin/commissions', ttl: 30);
      return data is List ? data : (data is Map ? [data] : []);
    } catch (e) {
      debugPrint('[API] getAdminCommissions error: $e');
      return [];
    }
  }

  // ─── MESSAGERIE - HELPERS RESTRICTION ─────────────────────────────────────

  /// Vérifie si l'utilisateur courant peut envoyer un message à [receiverRoles].
  /// Règle : Propriétaire↔Admin uniquement, Locataire↔Admin uniquement.
  static bool canMessageUser(String senderRole, List<String> receiverRoles) {
    final isAdmin       = receiverRoles.contains('ROLE_ADMIN');
    final senderIsAdmin = senderRole == 'ROLE_ADMIN';
    if (senderIsAdmin) return true; // admin peut écrire à tous
    return isAdmin; // proprio et locataire → uniquement admin
  }

  /// Filtre une liste de conversations pour ne garder que les autorisées.
  static List<dynamic> filterAllowedConversations(
    List<dynamic> conversations, String myRole,
  ) {
    if (myRole == 'ROLE_ADMIN') return conversations;
    return conversations.where((c) {
      final roles = (c['partner']?['roles'] as List?)?.cast<String>() ?? [];
      return roles.contains('ROLE_ADMIN');
    }).toList();
  }

  // ─── UTILS ────────────────────────────────────────────────────────────────

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final r = await _request(() => http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers, body: jsonEncode(body),
    ).timeout(_kTimeout));
    if (r == null) return null;
    if (r.statusCode == 200 || r.statusCode == 201) {
      try { return jsonDecode(r.body); } catch (_) { return {}; }
    }
    // Retourner aussi le body pour les erreurs 4xx (limite abonnement, KYC, etc.)
    if (r.statusCode >= 400 && r.statusCode < 500) {
      try {
        final err = jsonDecode(r.body) as Map<String, dynamic>;
        return {'_httpStatus': r.statusCode, ...err};
      } catch (_) {}
    }
    return null;
  }

  static String mapStatusToBackend(String status) {
    switch (status.toLowerCase().trim()) {
      case 'en_attente': case 'pending': return 'pending';
      case 'acceptée': case 'acceptee': case 'accepted': case 'approved': return 'accepted';
      case 'rejetée': case 'rejetee': case 'refused': case 'rejected': return 'refused';
      case 'annulée': case 'annulee': case 'cancelled': return 'cancelled';
      case 'actif': case 'active': return 'active';
      case 'loué': case 'loue': case 'rented': return 'rented';
      default: return status;
    }
  }

  static String mapStatusToMobile(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending': case 'draft': return 'en_attente';
      case 'accepted': return 'acceptée';
      case 'refused': case 'rejected': return 'rejetée';
      case 'cancelled': return 'annulée';
      case 'active': return 'actif';
      default: return status;
    }
  }
}
