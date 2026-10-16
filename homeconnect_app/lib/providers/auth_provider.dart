import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _token;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;

  AuthProvider() {
    // Quand le serveur répond 401, on déconnecte automatiquement
    ApiService.onUnauthorized = () => logout();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('token');
      final userJson = prefs.getString('user');

      if (savedToken == null || userJson == null) {
        notifyListeners();
        return;
      }

      // Token expiré → on vide la session, l'utilisateur devra se reconnecter
      if (ApiService.isTokenExpired(savedToken)) {
        debugPrint('[Auth] Token expiré au démarrage — déconnexion');
        await _clearPrefs(prefs);
        notifyListeners();
        return;
      }

      _token = savedToken;
      _currentUser = User.fromMap(jsonDecode(userJson));
      ApiService.setToken(_token!);

      // Token expire bientôt → on le rafraîchit en arrière-plan
      if (ApiService.isTokenExpiringSoon(_token!, minutesBefore: 60)) {
        debugPrint('[Auth] Token expire bientôt — rafraîchissement');
        _refreshInBackground(prefs);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] Erreur chargement session: $e');
      notifyListeners();
    }
  }

  void _refreshInBackground(SharedPreferences prefs) async {
    final newToken = await ApiService.refreshToken();
    if (newToken != null) {
      _token = newToken;
      await prefs.setString('token', _token!);
      debugPrint('[Auth] Token rafraîchi avec succès');
    } else {
      debugPrint('[Auth] Rafraîchissement échoué — déconnexion');
      await logout();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      final data = await ApiService.login(email, password);
      if (data != null && data.containsKey('token')) {
        _token = data['token'];
        ApiService.setToken(_token!);

        if (data.containsKey('user')) {
          _currentUser = User.fromMap(data['user']);
        } else {
          _currentUser = User(id: 0, email: email, name: email.split('@')[0]);
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_currentUser!.toMap()));

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearPrefs(prefs);
      ApiService.clearToken();
    } catch (e) {
      debugPrint('[Auth] Logout error: $e');
    }
    notifyListeners();
  }

  Future<void> _clearPrefs(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('user');
  }
}
