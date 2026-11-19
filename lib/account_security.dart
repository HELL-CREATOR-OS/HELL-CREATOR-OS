import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'platform_logos.dart';

class UserAccountManager {
  static const String _activeSessionKey = 'hell_active_session_v2';
  static const String _accountsDbKey = 'hell_registered_accounts_v2';
  static const String _savedCredentialsKey = 'hell_saved_autofill_creds_v1';
  static const String _autofillEnabledKey = 'hell_autofill_enabled_v1';
  static const String _vipKeysKey = 'hell_vip_keys_v2';
  static const String termsVersion = 'v1.0-EU-GLOBAL';

  static String get _firebaseAuthEndpoint =>
      ['https:', '//', 'identitytoolkit.', 'google', 'apis.', 'com/v1/accounts:'].join();

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

   static const String _savedAccountsListKey = 'hell_saved_autofill_list_v1';

  static Future<void> saveCredentials(String identifier, String password) async {
    final enabled = await isAutofillEnabled();
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedCredentialsKey,
      jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
    final map = await getSavedPasswordsMap();
    map[identifier.trim().toLowerCase()] = password;
    await prefs.setString(_savedAccountsListKey, jsonEncode(map));
  }

  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedCredentialsKey);
    await prefs.remove(_savedAccountsListKey);
  }

  static Future<List<Map<String, dynamic>>> getRegisteredAccountsList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsDbKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final db = jsonDecode(raw) as Map<String, dynamic>;
      final list = <Map<String, dynamic>>[];
      for (final entry in db.values) {
        if (entry is Map<String, dynamic> && entry['registrationCompleted'] == true) {
          list.add(Map<String, dynamic>.from(entry));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, String>> getSavedPasswordsMap() async {
    final enabled = await isAutofillEnabled();
    if (!enabled) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAccountsListKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
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
Cada utilizador declara e aceita que atua de livre e espontânea vontade e assume a responsabilidade civil, criminal, administrativa e de direitos de autor integral e exclusiva por tudo o que fizer através da aplicação ou nas plataformas externas ligadas (TikTok, Twitch, YouTube, Kick ou outras), isentando totalmente o proprietário da aplicação de qualquer reclamação, coima ou litígio.
Cada utilizador declara e aceita que atua de livre e espontânea vontade e assume a responsabilidade civil, criminal, administrativa e de direitos de autor integral e exclusiva por tudo o que fizer através da aplicação ou nas plataformas externas ligadas (TikTok, Twitch, YouTube, Kick ou outras), isentando totalmente o proprietário da aplicação de qualquer reclamação, coima ou litígio.

2. REGRAS DE CONDUTA E TOLERÂNCIA ZERO
É estritamente proibido utilizar o HELL CREATOR OS para promover discurso de ódio, assédio, difamação, fraude, pirataria, violação de direitos de autor ou qualquer atividade ilegal nos termos da legislação da União Europeia e internacional.

3. IDADE MÍNIMA LEGAL
Em conformidade com o Regulamento Geral sobre a Proteção de Dados (RGPD - UE 2016/679) e normas internacionais, a criação de conta exige idade mínima legal de 16 anos.

4. PRIVACIDADE E PROTEÇÃO DE DADOS (RGPD)
Os dados fornecidos no registo destinam-se exclusivamente à gestão da conta, segurança e registo legal de aceitação destes termos. O HELL CREATOR OS não cruza automaticamente identidades de espectadores entre diferentes redes sociais. O utilizador pode solicitar a eliminação dos seus dados através do contacto oficial: hellcreatoros@gmail.com.
''';

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
        ),
        title: const Text(
          'Termos Legais & Isenção de Responsabilidade',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          height: 340,
          child: SingleChildScrollView(
            child: Text(fullLegalText, style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.45)),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compreendi e Fechar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;
  bool _acceptedTerms = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  final _dayCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();

  DateTime? _birthDate;
  String? _selectedCountry;
  String _googlePhotoUrl = '';
  String? _firebaseVerifyToken;
  bool _emailVerified = false;
  bool _emailSentPulse = false;

  final List<String> _countries = [
    'Portugal', 'Brasil', 'Espanha', 'França', 'Reino Unido', 'Alemanha',
    'Suíça', 'Luxemburgo', 'Angola', 'Moçambique', 'Cabo Verde', 'Estados Unidos', 'Outro País',
  ];
  List<Map<String, dynamic>> _localAccounts = [];
  Map<String, String> _savedPasswordsByEmail = {};

  @override
  void initState() {
    super.initState();
    _loadAutofillAndDefaultTab();
  }

    Future<void> _loadAutofillAndDefaultTab() async {
    final savedCreds = await UserAccountManager.getSavedCredentials();
    final accounts = await UserAccountManager.getRegisteredAccountsList();
    final passMap = await UserAccountManager.getSavedPasswordsMap();
    if (!mounted) return;
    setState(() {
      _localAccounts = accounts;
      _savedPasswordsByEmail = passMap;
      if (savedCreds != null && (savedCreds['identifier'] ?? '').isNotEmpty) {
        _isRegister = false;
        _emailCtrl.text = savedCreds['identifier'] ?? '';
        _passCtrl.text = savedCreds['password'] ?? '';
      } else if (accounts.isNotEmpty) {
        _isRegister = false;
      } else {
        _isRegister = true;
      }
    });
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }

  void _syncBirthDateFromInputs() {
    final d = int.tryParse(_dayCtrl.text.trim());
    final m = int.tryParse(_monthCtrl.text.trim());
    final y = int.tryParse(_yearCtrl.text.trim());
    if (d != null && m != null && y != null && _yearCtrl.text.trim().length == 4 && d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 1920 && y <= DateTime.now().year) {
      final candidate = DateTime(y, m, d);
      if (candidate.year == y && candidate.month == m && candidate.day == d) {
        setState(() => _birthDate = candidate);
        return;
      }
    }
    if (_birthDate != null) setState(() => _birthDate = null);
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'PT'),
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: 'Selecionar Data de Nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _dayCtrl.text = picked.day.toString().padLeft(2, '0');
        _monthCtrl.text = picked.month.toString().padLeft(2, '0');
        _yearCtrl.text = picked.year.toString();
      });
    }
  }

  Future<void> _sendRealVerificationEmail() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _msg('Introduz primeiro um e-mail pessoal válido.');
      return;
    }
    if (pass.length < 6) {
      _msg('Define primeiro uma palavra-passe (mínimo 6 caracteres) para validar o e-mail.');
      return;
    }
    setState(() => _busy = true);
    final res = await UserAccountManager.sendRealFirebaseVerificationEmail(email, pass);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _firebaseVerifyToken = res['token'];
    });
    if (res['token'] != null) {
      setState(() => _emailSentPulse = true);
      _msg('E-mail enviado para $email! Abre a caixa de entrada (ou Spam), clica no link e carrega abaixo em "Concluir Registo e Entrar".');
    } else {
      _msg('Falha no envio (${res['error']}).');
    }
  }

   Future<void> _askToSaveCredentialsAndEnter(Map<String, dynamic> user, String identifier, String password) async {
    final autofillEnabled = await UserAccountManager.isAutofillEnabled();
    final canonicalEmail = (user['email'] ?? identifier).toString().trim().toLowerCase();
    final savedMap = await UserAccountManager.getSavedPasswordsMap();
    final alreadySaved = savedMap[canonicalEmail] == password ||
        savedMap[identifier.trim().toLowerCase()] == password;

    if (!autofillEnabled || alreadySaved || !mounted) {
      if (alreadySaved && autofillEnabled) {
        await UserAccountManager.saveCredentials(canonicalEmail, password);
      }
      widget.onAuthenticated(user);
      return;
    }


    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.3),
        ),
        title: const Text('Guardar Dados de Acesso?', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Queres guardar o teu E-mail / Nickname e Palavra-passe para preenchimento automático na próxima vez que entrares na app?\n\n(Podes ativar, desativar ou apagar estes dados a qualquer momento nas Definições de Privacidade.)',
          style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Agora Não', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () async {
                         await UserAccountManager.saveCredentials(canonicalEmail, password);

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar Dados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    widget.onAuthenticated(user);
  }
  Future<void> _googleLoginExistingOnly() async {
    setState(() => _busy = true);
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final localScheme = ['http:', '//', '127.0.0.1:'].join();
      final redirectUri = '$localScheme${server.port}';
      final webClientId = [
        '251620021978-uclsrrtd0l77ctn15tivh0u2vii4sj0d',
        '.apps.',
        'googleusercontent.com',
      ].join();

      final authHost = ['accounts.', 'google', '.com'].join();
      final authUri = Uri.https(authHost, '/o/oauth2/v2/auth', {
        'client_id': webClientId,
        'redirect_uri': redirectUri,
        'response_type': 'token',
        'scope': 'email profile',
        'prompt': 'select_account',
      });

      final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Não foi possível abrir o navegador.');
      }

      String? accessToken;
      await for (final request in server.timeout(const Duration(minutes: 2))) {
        final uri = request.uri;
        if (uri.queryParameters.containsKey('access_token')) {
          accessToken = uri.queryParameters['access_token'];
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('<html><body style="background:#050B1E;color:#38BDF8;font-family:sans-serif;text-align:center;padding-top:60px;"><h2>Conta Google Autenticada!</h2><p style="color:white;">Podes fechar esta aba e voltar ao HELL CREATOR OS.</p><script>window.close();</script></body></html>');
          await request.response.close();
          break;
        } else {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
<html><body style="background:#050B1E;color:white;font-family:sans-serif;text-align:center;padding-top:60px;">
<p>A validar sessão Google...</p>
<script>
const hash = window.location.hash.substring(1);
if (hash) {
  window.location.replace("$redirectUri/callback?" + hash);
} else {
  document.body.innerHTML = "<h3 style='color:#f87171'>Autenticação cancelada. Podes voltar à app.</h3>";
}
</script>
</body></html>''');
          await request.response.close();
        }
      }

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Sessão Google não concluída.');
      }

      final userInfoUrl = ['https:', '//', 'www.', 'google', 'apis.', 'com/oauth2/v2/userinfo'].join();
      final userInfoRes = await http.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (userInfoRes.statusCode != 200) {
        throw Exception('Falha ao obter perfil Google.');
      }

      final profile = jsonDecode(userInfoRes.body) as Map<String, dynamic>;
      final email = (profile['email'] ?? '').toString().trim().toLowerCase();
      final photo = (profile['picture'] ?? '').toString().trim();
      final givenName = (profile['given_name'] ?? '').toString().trim();
      final familyName = (profile['family_name'] ?? '').toString().trim();
      final fullName = (profile['name'] ?? 'Criador HELL').toString().trim();
      final locale = (profile['locale'] ?? '').toString().toLowerCase();

      String? detectedCountry;
      if (locale.contains('pt-pt') || locale == 'pt') {
        detectedCountry = 'Portugal';
      } else if (locale.contains('pt-br')) {
        detectedCountry = 'Brasil';
      } else if (locale.startsWith('es')) {
        detectedCountry = 'Espanha';
      } else if (locale.startsWith('fr')) {
        detectedCountry = 'França';
      } else if (locale.contains('en-gb')) {
        detectedCountry = 'Reino Unido';
      } else if (locale.startsWith('de')) {
        detectedCountry = 'Alemanha';
      } else if (locale.contains('en-us')) {
        detectedCountry = 'Estados Unidos';
      }

      if (email.isEmpty) {
        throw Exception('E-mail Google não devolvido.');
      }

      final existing = await UserAccountManager.findRegisteredAccount(email);
      if (existing != null && existing['registrationCompleted'] == true) {
        if (photo.isNotEmpty) existing['photoUrl'] = photo;
        await UserAccountManager.saveUser(existing);
        widget.onAuthenticated(existing);
      } else {
        final parts = fullName.split(' ');
        setState(() {
          _isRegister = true;
          _firstNameCtrl.text = givenName.isNotEmpty ? givenName : parts.first;
          _lastNameCtrl.text = familyName.isNotEmpty ? familyName : (parts.length > 1 ? parts.sublist(1).join(' ') : '');
          _nickCtrl.text = email.split('@').first;
          _emailCtrl.text = email;
          _googlePhotoUrl = photo;
          _emailVerified = true;
          if (detectedCountry != null) _selectedCountry = detectedCountry;
        });
        _msg('Conta Google ($email) e foto sincronizadas! Preenche apenas a Data de Nascimento, Palavra-passe e aceita os Termos.');
      }
    } catch (e) {
      _msg('Aviso Google: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      await server?.close(force: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitForm() async {
    final identifier = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (!_isRegister) {
      if (identifier.isEmpty || pass.length < 6) {
        _msg('Introduz o teu E-mail ou Nickname registado e a palavra-passe.');
        return;
      }
      final existing = await UserAccountManager.findRegisteredAccount(identifier);
      if (existing != null && existing['passwordSecret'] == pass) {
        await UserAccountManager.saveUser(existing);
        await _askToSaveCredentialsAndEnter(existing, identifier, pass);
      } else {
        _msg('Conta não encontrada ou palavra-passe incorreta. Verifica os dados ou cria o teu registo.');
      }
      return;
    }

    final email = identifier.toLowerCase();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final nick = _nickCtrl.text.trim();
    final passConfirm = _passConfirmCtrl.text.trim();

       if (firstName.isEmpty || nick.isEmpty) {
      _msg('Preenche o Nome Próprio e o Nickname.');
      return;
    }

    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      _msg('Seleciona o teu País / Região.');
      return;
    }
    if (_birthDate == null) {
      _msg('Introduz a tua Data de Nascimento completa (Dia, Mês e Ano).');
      return;
    }
    if (_calculateAge(_birthDate!) < 16) {
      _msg('Registo bloqueado: a idade mínima legal é de 16 anos.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _msg('Introduz um endereço de e-mail válido.');
      return;
    }
    if (pass.length < 6) {
      _msg('A palavra-passe deve ter pelo menos 6 caracteres.');
      return;
    }
    if (pass != passConfirm) {
      _msg('As duas palavras-passe não coincidem.');
      return;
    }
    if (!_acceptedTerms) {
      _msg('É obrigatório ler e aceitar os Termos de Utilização, Privacidade e Isenção de Responsabilidade.');
      return;
    }
    if (!_emailVerified) {
      if (_firebaseVerifyToken == null) {
        _msg('Clica primeiro em "Enviar E-mail de Verificação" para receberes o link na tua caixa de entrada.');
        return;
      }
      setState(() => _busy = true);
      final verifiedNow = await UserAccountManager.checkFirebaseEmailVerified(_firebaseVerifyToken!);
      if (!mounted) return;
      if (!verifiedNow) {
        setState(() => _busy = false);
        _msg('Ainda não detetámos o clique no link enviado para $email. Abre o e-mail (verifica também o Spam), clica no link e carrega novamente em "Concluir Registo e Entrar".');
        return;
      }
      setState(() {
        _emailVerified = true;
        _emailSentPulse = false;
      });
      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      setState(() => _busy = false);
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final consentId = 'CONSENT-${DateTime.now().millisecondsSinceEpoch}-${1000 + Random().nextInt(9000)}';

    final user = <String, dynamic>{
      'registrationCompleted': true,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nick,
      'birthDate': _birthDate!.toIso8601String(),
      'age': _calculateAge(_birthDate!),
      'country': _selectedCountry,
      'email': email,
      'photoUrl': _googlePhotoUrl,
      'passwordSecret': pass,
      'securityMethods': <String>[],
      'legalAuditLog': {
        'consentId': consentId,
        'acceptedAtUtc': nowUtc,
        'termsVersion': UserAccountManager.termsVersion,
        'fullName': lastName.isEmpty ? firstName : '$firstName $lastName',
        'email': email,
        'country': _selectedCountry,
      },
    };

    await UserAccountManager.saveUser(user);
    await _askToSaveCredentialsAndEnter(user, email, pass);
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1636),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('icon.png', height: 68, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 60, color: Color(0xFF38BDF8))),
                  const SizedBox(height: 8),
                  const Text('HELL', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white, height: 1.0)),
                  const Text('CREATOR OS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3, color: Color(0xFF38BDF8))),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _isRegister ? const Color(0xFF1E78FF) : Colors.white10),
                          onPressed: () => setState(() => _isRegister = true),
                          child: const Text('Criar Registo', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: !_isRegister ? const Color(0xFF1E78FF) : Colors.white10),
                          onPressed: () => setState(() => _isRegister = false),
                          child: const Text('Já Tenho Conta', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _busy ? null : _googleLoginExistingOnly,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GoogleOfficialLogo(size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isRegister ? 'Continuar com Conta Google' : 'Entrar com Conta Google',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isRegister) ...[
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'Nome Próprio', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Apelido (Opcional)', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: 'Nickname / Nome de Criador', isDense: true)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dayCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Dia (DD)', counterText: '', isDense: true),
                            onChanged: (v) {
                              _syncBirthDateFromInputs();
                              if (v.length == 2) _monthFocus.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _monthCtrl,
                            focusNode: _monthFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Mês (MM)', counterText: '', isDense: true),
                            onChanged: (v) {
                              _syncBirthDateFromInputs();
                              if (v.length == 2) _yearFocus.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _yearCtrl,
                            focusNode: _yearFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Ano (AAAA)', counterText: '', isDense: true),
                            onChanged: (_) => _syncBirthDateFromInputs(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Abrir Calendário em Português',
                          onPressed: _pickBirthDate,
                          icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    if (_birthDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Idade calculada: ${_calculateAge(_birthDate!)} anos',
                            style: TextStyle(fontSize: 11.5, color: _calculateAge(_birthDate!) >= 16 ? Colors.greenAccent : Colors.redAccent),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      dropdownColor: const Color(0xFF0B1636),
                      hint: const Text('Selecionar País / Região', style: TextStyle(color: Colors.white60)),
                      decoration: const InputDecoration(labelText: 'País / Região', isDense: true),
                      items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCountry = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                                    TextField(
                    controller: _emailCtrl,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: _isRegister ? 'E-mail Oficial' : 'E-mail ou Nickname',
                      isDense: true,
                      suffixIcon: (!_isRegister && _localAccounts.isNotEmpty)
                          ? PopupMenuButton<Map<String, dynamic>>(
                              tooltip: 'Escolher Conta Registada',
                              color: const Color(0xFF0B1636),
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF38BDF8)),
                              onSelected: (acc) {
                                final accEmail = (acc['email'] ?? '').toString().trim().toLowerCase();
                                setState(() {
                                  _emailCtrl.text = accEmail;
                                  _passCtrl.text = _savedPasswordsByEmail[accEmail] ?? '';
                                });
                              },
                              itemBuilder: (ctx) => _localAccounts.map((acc) {
                                final accEmail = (acc['email'] ?? '').toString();
                                final accNick = (acc['nickname'] ?? 'Criador').toString();
                                return PopupMenuItem<Map<String, dynamic>>(
                                  value: acc,
                                  child: Row(
                                    children: [
                                      UserAccountManager.buildUserAvatar(acc, radius: 15),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(accNick, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(accEmail, style: const TextStyle(color: Colors.white60, fontSize: 11), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Palavra-passe (mín. 6 caracteres)',
                      isDense: true,
                      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passConfirmCtrl,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Repetir Palavra-passe', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    if (_emailVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.greenAccent)),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.greenAccent, size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text('E-mail verificado com sucesso!', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 11)),
                          onPressed: _busy ? null : _sendRealVerificationEmail,
                          icon: const Icon(Icons.mark_email_unread_outlined, size: 17, color: Colors.white),
                          label: Text(
                            _emailSentPulse ? 'Reenviar E-mail de Verificação' : 'Enviar E-mail de Verificação',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => LegalTermsModal.show(context),
                        icon: const Icon(Icons.gavel_rounded, size: 17, color: Color(0xFF38BDF8)),
                        label: const Text('Ler Termos Legais, RGPD & Isenção de Responsabilidade', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, decoration: TextDecoration.underline)),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF38BDF8),
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      title: const Text(
                        'Li e aceito os Termos de Utilização, Política de Privacidade (RGPD) e assumo total responsabilidade pelos meus conteúdos e transmissões.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: (_isRegister && _emailVerified)
                          ? const Color(0xFF10B981)
                          : (_isRegister && _emailSentPulse)
                              ? const Color(0xFF00A3FF)
                              : const Color(0xFF1E78FF),
                      border: Border.all(
                        color: (_isRegister && _emailVerified)
                            ? Colors.greenAccent
                            : (_isRegister && _emailSentPulse)
                                ? const Color(0xFF7DD3FC)
                                : Colors.transparent,
                        width: 1.8,
                      ),
                      boxShadow: (_isRegister && _emailVerified)
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.55),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : (_isRegister && _emailSentPulse)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 1.5,
                                  ),
                                ]
                              : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _busy ? null : _submitForm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13.5, horizontal: 16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: (_isRegister && _emailVerified)
                                ? const Row(
                                    key: ValueKey('verified_btn'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'E-mail Confirmado • A Entrar...',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _isRegister ? 'Concluir Registo e Entrar' : 'Entrar na Conta',
                                    key: ValueKey(_isRegister ? 'reg_btn' : 'login_btn'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AutofillPrivacySettingsCard extends StatefulWidget {
  const AutofillPrivacySettingsCard({super.key});

  @override
  State<AutofillPrivacySettingsCard> createState() => _AutofillPrivacySettingsCardState();
}

class _AutofillPrivacySettingsCardState extends State<AutofillPrivacySettingsCard> {
  bool _enabled = true;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final en = await UserAccountManager.isAutofillEnabled();
    final creds = await UserAccountManager.getSavedCredentials();
    if (!mounted) return;
    setState(() {
      _enabled = en;
      _hasSaved = creds != null && (creds['identifier'] ?? '').isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1636),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF38BDF8),
            title: const Text('Guardar Credenciais & Preenchimento Automático', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: const Text('Perguntar se pretendes guardar o e-mail/nickname e palavra-passe para entrar automaticamente.', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
            value: _enabled,
            onChanged: (v) async {
              await UserAccountManager.setAutofillEnabled(v);
              await _refresh();
            },
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
              onPressed: _hasSaved
                  ? () async {
                      await UserAccountManager.clearSavedCredentials();
                      await _refresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dados de preenchimento automático e palavra-passe guardada apagados.')),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(_hasSaved ? 'Apagar Palavra-passe e Dados Guardados' : 'Sem Credenciais Guardadas'),
            ),
          ),
        ],
      ),
    );
  }
}

class AppLockScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUnlocked;
  final VoidCallback onLogout;
  const AppLockScreen({super.key, required this.user, required this.onUnlocked, required this.onLogout});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _localAuth = LocalAuthentication();
  final _ctrl = TextEditingController();
  String _error = '';

  List<String> get _methods => List<String>.from(widget.user['securityMethods'] ?? []);

  @override
  void initState() {
    super.initState();
    if (_methods.contains('biometric') || _methods.contains('device')) {
      _tryDeviceUnlock();
    }
  }

  Future<void> _tryDeviceUnlock() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Desbloqueia o HELL CREATOR OS com a segurança do aparelho (Impressão Digital, Face ID, PIN, Senha ou Padrão)',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (ok) widget.onUnlocked();
    } catch (_) {
      setState(() => _error = 'Utiliza a palavra-passe da conta abaixo para entrar.');
    }
  }

  void _check() {
    final val = _ctrl.text.trim();
    if (val == (widget.user['passwordSecret'] ?? '')) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Palavra-passe incorreta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UserAccountManager.buildUserAvatar(widget.user, radius: 38),
                const SizedBox(height: 12),
                Text('Olá, ${widget.user['nickname'] ?? 'Criador'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), foregroundColor: Colors.white),
                  onPressed: _tryDeviceUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear com Aparelho (Biometria / PIN / Padrão)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _ctrl,
                  obscureText: true,
                  onChanged: (v) {
                    final clean = v.trim();
                    final pass = (widget.user['passwordSecret'] ?? '').toString();
                    if (pass.isNotEmpty && clean == pass) {
                      widget.onUnlocked();
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Ou introduz a Palavra-passe da Conta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)), onPressed: _check, child: const Text('Entrar', style: TextStyle(color: Colors.white))),
                ),
                if (_error.isNotEmpty) ...[const SizedBox(height: 8), Text(_error, style: const TextStyle(color: Colors.redAccent))],
                TextButton(onPressed: widget.onLogout, child: const Text('Terminar Sessão', style: TextStyle(color: Colors.white54))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

