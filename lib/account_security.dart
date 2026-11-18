import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:local_auth/local_auth.dart';
import 'platform_logos.dart';

class UserAccountManager {
  static const String _activeSessionKey = 'hell_active_session_v2';
  static const String _accountsDbKey = 'hell_registered_accounts_v2';
  static const String _savedCredentialsKey = 'hell_saved_autofill_creds_v1';
  static const String _autofillEnabledKey = 'hell_autofill_enabled_v1';
  static const String _vipKeysKey = 'hell_vip_keys_v2';
  static const String termsVersion = 'v1.0-EU-GLOBAL';

  static String get _firebaseAuthEndpoint =>
      ['https://', 'identitytoolkit.', 'google', 'apis.', 'com/v1/accounts:'].join();

  static Future<String> _getOfficialFirebaseApiKey() async {
    try {
      final raw = await rootBundle.loadString('google-services.json');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final clients = parsed['client'] as List<dynamic>;
      final apiKeys = clients.first['api_key'] as List<dynamic>;
      final key = (apiKeys.first['current_key'] ?? '').toString().trim();
      if (key.isNotEmpty) return key;
    } catch (_) {}
    return '';
  }

  static const List<String> ownerEmails = [
    'hellcreatoros@gmail.com',
  ];

  static bool isOwnerEmail(String? email) {
    if (email == null) return false;
    return ownerEmails.contains(email.trim().toLowerCase());
  }

  static Future<bool> isAutofillEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autofillEnabledKey) ?? true;
  }

  static Future<void> setAutofillEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autofillEnabledKey, enabled);
    if (!enabled) {
      await clearSavedCredentials();
    }
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final enabled = await isAutofillEnabled();
    if (!enabled) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedCredentialsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'identifier': (decoded['identifier'] ?? '').toString(),
        'password': (decoded['password'] ?? '').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCredentials(String identifier, String password) async {
    final enabled = await isAutofillEnabled();
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedCredentialsKey,
      jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
  }

  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedCredentialsKey);
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['registrationCompleted'] != true) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> findRegisteredAccount(String identifier) async {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsDbKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final db = jsonDecode(raw) as Map<String, dynamic>;
      if (db[clean] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(db[clean]);
      }
      for (final entry in db.values) {
        if (entry is Map<String, dynamic>) {
          final email = (entry['email'] ?? '').toString().trim().toLowerCase();
          final nick = (entry['nickname'] ?? '').toString().trim().toLowerCase();
          if (email == clean || nick == clean || '@$nick' == clean) {
            return Map<String, dynamic>.from(entry);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    await prefs.setString(_activeSessionKey, jsonEncode(user));
    if (email.isNotEmpty) {
      Map<String, dynamic> db = {};
      final rawDb = prefs.getString(_accountsDbKey);
      if (rawDb != null && rawDb.isNotEmpty) {
        try {
          db = jsonDecode(rawDb) as Map<String, dynamic>;
        } catch (_) {}
      }
      db[email] = user;
      await prefs.setString(_accountsDbKey, jsonEncode(db));
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionKey);
  }

  static Future<String> generateVipKey() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_vipKeysKey) ?? [];
    final key = 'HELL-VIP-${100000 + Random().nextInt(900000)}';
    list.add(key);
    await prefs.setStringList(_vipKeysKey, list);
    return key;
  }

  static Widget buildUserAvatar(Map<String, dynamic> user, {double radius = 20}) {
    final localPath = (user['avatarPath'] ?? '').toString();
    final photoUrl = (user['photoUrl'] ?? '').toString().trim();
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(File(localPath)));
    }
    if (photoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1E78FF),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1E78FF),
      child: Icon(Icons.person, size: radius * 1.1, color: Colors.white),
    );
  }

  static Future<Map<String, String?>> sendRealFirebaseVerificationEmail(String email, String tempPassword) async {
    try {
      final base = _firebaseAuthEndpoint;
      final apiKey = await _getOfficialFirebaseApiKey();
      if (apiKey.isEmpty) {
        return {'token': null, 'error': 'Ficheiro google-services.json não encontrado nos assets.'};
      }
      final signUpRes = await http.post(
        Uri.parse('${base}signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': tempPassword, 'returnSecureToken': true}),
      );
      Map<String, dynamic> data = jsonDecode(signUpRes.body);
      String? idToken = data['idToken'];

      if (idToken == null && (data['error']?['message'] == 'EMAIL_EXISTS')) {
        final signInRes = await http.post(
          Uri.parse('${base}signInWithPassword?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': tempPassword, 'returnSecureToken': true}),
        );
        data = jsonDecode(signInRes.body);
        idToken = data['idToken'];
      }

      if (idToken == null) {
        final errCode = data['error']?['message']?.toString() ?? 'Erro desconhecido';
        return {'token': null, 'error': errCode};
      }

      final oobRes = await http.post(
        Uri.parse('${base}sendOobCode?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'VERIFY_EMAIL', 'idToken': idToken}),
      );
      if (oobRes.statusCode == 200) return {'token': idToken, 'error': null};
      final oobErr = jsonDecode(oobRes.body)['error']?['message']?.toString() ?? 'Falha ao enviar';
      return {'token': null, 'error': oobErr};
    } catch (e) {
      return {'token': null, 'error': e.toString()};
    }
  }

  static Future<bool> checkFirebaseEmailVerified(String idToken) async {
    try {
      final base = _firebaseAuthEndpoint;
      final apiKey = await _getOfficialFirebaseApiKey();
      if (apiKey.isEmpty) return false;
      final res = await http.post(
        Uri.parse('${base}lookup?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      final users = data['users'] as List<dynamic>?;
      if (users != null && users.isNotEmpty) {
        return users.first['emailVerified'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class LegalTermsModal {
  static const String fullLegalText = '''
TERMOS DE UTILIZAÇÃO, ISENÇÃO DE RESPONSABILIDADE E POLÍTICA DE PRIVACIDADE (RGPD UNIÃO EUROPEIA & LEIS INTERNACIONAIS) — VERSÃO v1.0-EU-GLOBAL

1. NATUREZA DA PLATAFORMA E ISENÇÃO TOTAL DE RESPONSABILIDADE
O HELL CREATOR OS é uma ferramenta técnica neutra de apoio à produção e gestão de transmissões em direto. O proprietário e criador do HELL CREATOR OS não controla, edita, supervisiona nem aprova previamente os conteúdos transmitidos, publicados, falados ou partilhados pelos utilizadores.
