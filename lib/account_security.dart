import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class _BirthDateAutoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(limited[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _GoogleOfficialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.19;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, h - stroke);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.45, 1.85, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.48, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.72, 1.63, false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 0.87, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.50, h * 0.41, w * 0.46, stroke * 0.95),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserAccountManager {
  static const String _kCurrentUserKey = 'hell_current_user_v2';
  static const String _kUsersDbKey = 'hell_registered_users_v2';
  static const String _kSavedCredsKey = 'hell_saved_creds_v2';
  static const String _kAutofillEnabledKey = 'hell_autofill_enabled_v2';
  static const String termsVersion = 'v2.4-2026';

  static const String ownerEmail = 'hellgamer2026@gmail.com';
  static const String ownerNick = 'HELLGAMER';

  static bool isOwnerEmail(String? email) =>
      (email ?? '').trim().toLowerCase() == ownerEmail;

  static Future<String> _firebaseApiKey() async {
    try {
      final raw = await rootBundle.loadString('google-services.json');
      final p = jsonDecode(raw) as Map<String, dynamic>;
      return (p['client']['api_key']['current_key'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, dynamic>> sendRealFirebaseVerificationEmail(
      String email, String password) async {
    try {
      final key = await _firebaseApiKey();
      if (key.isEmpty) {
        return {'error': 'Chave Firebase não encontrada no projeto.'};
      }
      final base = [
        'https:',
        '//',
        'identitytoolkit.',
        'google',
        'apis.',
        'com/v1/accounts:'
      ].join();

      var res = await http.post(
        Uri.parse('${base}signUp?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      var data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        final msg = (data['error']['message'] ?? '').toString();
        if (msg.contains('EMAIL_EXISTS')) {
          res = await http.post(
            Uri.parse('${base}signInWithPassword?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'returnSecureToken': true,
            }),
          );
          data = jsonDecode(res.body) as Map<String, dynamic>;
        }
      }

      final idToken = (data['idToken'] ?? '').toString();
      if (idToken.isEmpty) {
        return {
          'error': data['error']?['message']?.toString() ??
              'Falha ao preparar validação.'
        };
      }

      final oobRes = await http.post(
        Uri.parse('${base}sendOobCode?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'VERIFY_EMAIL', 'idToken': idToken}),
      );
      final oobData = jsonDecode(oobRes.body) as Map<String, dynamic>;
      if (oobData['error'] != null) {
        return {'error': oobData['error']['message'].toString()};
      }
      return {'token': idToken};
    } catch (e) {
      return {'error': 'Erro de ligação ao serviço de verificação: $e'};
    }
  }
  static Future<bool> checkFirebaseEmailVerified(String idToken) async {
    try {
      final key = await _firebaseApiKey();
      if (key.isEmpty || idToken.isEmpty) return false;
      final base = [
        'https:',
        '//',
        'identitytoolkit.',
        'google',
        'apis.',
        'com/v1/accounts:'
      ].join();

      final res = await http.post(
        Uri.parse('${base}lookup?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final users = data['users'] as List?;
      if (users != null && users.isNotEmpty) {
        return users.first['emailVerified'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCurrentUserKey);
    if (raw == null || raw.isEmpty) return null;
    final user = jsonDecode(raw) as Map<String, dynamic>;
    if (user['registrationCompleted'] != true) return null;
    return user;
  }

  static Future<Map<String, dynamic>?> getSavedUser() => getCurrentUser();

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    user['registrationCompleted'] = true;
    await prefs.setString(_kCurrentUserKey, jsonEncode(user));

    final db = await getAllRegisteredAccounts();
    if (email.isNotEmpty) {
      db[email] = user;
      await prefs.setString(_kUsersDbKey, jsonEncode(db));
    }
  }

  static Future<Map<String, dynamic>> getAllRegisteredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersDbKey);
    if (raw == null || raw.isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<Map<String, dynamic>?> findRegisteredAccount(
      String identifier) async {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final db = await getAllRegisteredAccounts();
    if (db.containsKey(clean)) {
      return Map<String, dynamic>.from(db[clean] as Map);
    }
    for (final entry in db.values) {
      final u = Map<String, dynamic>.from(entry as Map);
      final nick = (u['nickname'] ?? '').toString().trim().toLowerCase();
      final user = (u['username'] ?? '').toString().trim().toLowerCase();
      if (nick == clean || user == clean) return u;
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserKey);
  }

  static Future<bool> isAutofillEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutofillEnabledKey) ?? true;
  }

  static Future<void> setAutofillEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutofillEnabledKey, enabled);
    if (!enabled) await clearSavedCredentials();
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kAutofillEnabledKey) ?? true)) return null;
    final raw = prefs.getString(_kSavedCredsKey);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static Future<void> saveCredentials(
      String identifier, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kAutofillEnabledKey) ?? true)) return;
    await prefs.setString(
      _kSavedCredsKey,
      jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
  }

  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedCredsKey);
  }
}
class AuthGateScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onAuthenticated;

  const AuthGateScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;
  bool _emailVerified = false;
  bool _acceptedTerms = false;
  String? _pendingFirebaseToken;
  String? _verifiedForEmail;
  String _googlePhotoUrl = '';

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _nickCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _passConfirmCtrl = TextEditingController();

  DateTime? _birthDate;
  String _selectedCountry = 'Portugal';

  final List<String> _countries = const [
    'Portugal',
    'Brasil',
    'Espanha',
    'França',
    'Reino Unido',
    'Alemanha',
    'Suíça',
    'Luxemburgo',
    'Angola',
    'Moçambique',
    'Cabo Verde',
    'Estados Unidos',
    'Outro País',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await UserAccountManager.getSavedCredentials();
    if (saved != null && mounted) {
      setState(() {
        _emailCtrl.text = saved['identifier'] ?? '';
        _passCtrl.text = saved['password'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _nickCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
  Future<void> _authenticateWithGoogle({required bool isRegisterFlow}) async {
    setState(() => _busy = true);
    HttpServer? server;
    try {
      if (!isRegisterFlow) {
        final savedCreds = await UserAccountManager.getSavedCredentials();
        final savedEmail =
            (savedCreds?['identifier'] ?? '').trim().toLowerCase();
        if (savedEmail.contains('@')) {
          final existing =
              await UserAccountManager.findRegisteredAccount(savedEmail);
          if (existing != null &&
              existing['registrationCompleted'] == true &&
              existing['authProvider'] == 'google') {
            await UserAccountManager.saveUser(existing);
            widget.onAuthenticated(existing);
            return;
          }
        }
      }

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final localScheme = ['http:', '//', '127.0.0.1'].join();
      final redirectUri = '$localScheme:${server.port}';
           String webClientId = '://googleusercontent.com';
      try {
        final rawGs = await rootBundle.loadString('google-services.json');
        final parsedGs = jsonDecode(rawGs) as Map<String, dynamic>;
        final clients = parsedGs['client'] as List?;
        if (clients != null && clients.isNotEmpty) {
          final oauthList = clients.first['oauth_client'] as List?;
          if (oauthList != null) {
            for (final oc in oauthList) {
              if (oc['client_type'] == 3 && (oc['client_id'] ?? '').toString().isNotEmpty) {
                webClientId = oc['client_id'].toString().trim();
                break;
              }
            }
          }
        }
      } catch (_) {}


      final authHost = ['accounts.', 'google', '.com'].join();
      final params = <String, String>{
        'client_id': webClientId,
        'redirect_uri': redirectUri,
        'response_type': 'token',
        'scope': 'email profile',
      };
      if (isRegisterFlow) {
        params['prompt'] = 'select_account';
      }
      final authUri = Uri.https(authHost, '/o/oauth2/v2/auth', params);

      await launchUrl(authUri, mode: LaunchMode.externalApplication);

      final completer = Completer<String?>();
      server.listen((HttpRequest req) async {
        if (req.uri.path == '/token') {
          final tok = req.uri.queryParameters['access_token'];
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(
                '<html><body style="background:#050B1E;color:#38BDF8;font-family:sans-serif;text-align:center;padding-top:60px;"><h2>Conta Google Validada!</h2><p>Podes fechar esta janela e voltar ao HELL CREATOR OS.</p></body></html>');
          await req.response.close();
          if (!completer.isCompleted) completer.complete(tok);
        } else {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(
                '<html><body style="background:#050B1E;color:white;font-family:sans-serif;text-align:center;padding-top:60px;"><p>A concluir ligação segura...</p><script>const h=window.location.hash.substring(1);const p=new URLSearchParams(h);const t=p.get("access_token");if(t){fetch("/token?access_token="+encodeURIComponent(t)).then(()=>{document.body.innerHTML="<h2 style=color:#38BDF8>Validado com sucesso! Pode fechar este separador.</h2>";});}</script></body></html>');
          await req.response.close();
        }
      });

      final token = await completer.future
          .timeout(const Duration(minutes: 2), onTimeout: () => null);
      if (token == null || token.isEmpty) {
        _msg('Tempo limite atingido na autenticação Google.');
        return;
      }

      final apiHost = ['www.', 'google', 'apis.', 'com'].join();
      final infoRes = await http.get(
        Uri.https(apiHost, '/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (infoRes.statusCode != 200) {
        _msg('Não foi possível obter os dados da Conta Google.');
        return;
      }

      final profile = jsonDecode(infoRes.body) as Map<String, dynamic>;
      final email = (profile['email'] ?? '').toString().trim().toLowerCase();
      final name = (profile['name'] ?? '').toString().trim();
      final photo = (profile['picture'] ?? '').toString().trim();

      if (email.isEmpty) {
        _msg('A Conta Google não devolveu um e-mail válido.');
        return;
      }

      final existing = await UserAccountManager.findRegisteredAccount(email);
      if (existing != null && existing['registrationCompleted'] == true) {
        if (photo.isNotEmpty) existing['photoUrl'] = photo;
        existing['authProvider'] = 'google';
        await UserAccountManager.saveUser(existing);
        await UserAccountManager.saveCredentials(email, 'GOOGLE_OAUTH');
        widget.onAuthenticated(existing);
        return;
      }

      final parts = name.split(' ');
      setState(() {
        _isRegister = true;
        _emailCtrl.text = email;
        if (_firstNameCtrl.text.trim().isEmpty && parts.isNotEmpty) {
          _firstNameCtrl.text = parts.first;
        }
        if (_lastNameCtrl.text.trim().isEmpty && parts.length > 1) {
          _lastNameCtrl.text = parts.sublist(1).join(' ');
        }
        _googlePhotoUrl = photo;
        _emailVerified = true;
        _verifiedForEmail = email;
      });
      _msg('Conta Google validada! Completa os dados e conclui o registo.');
    } catch (e) {
      _msg('Erro na ligação Google: $e');
    } finally {
      await server?.close(force: true);
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _sendVerificationEmailToInbox() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _msg('Introduz um endereço de e-mail válido.');
      return;
    }
    if (pass.length < 6) {
      _msg('Define primeiro uma palavra-passe com pelo menos 6 caracteres.');
      return;
    }

    setState(() => _busy = true);
    final res = await UserAccountManager.sendRealFirebaseVerificationEmail(
        email, pass);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['error'] != null) {
      _msg('Erro ao enviar e-mail: ${res['error']}');
      return;
    }

    setState(() {
      _pendingFirebaseToken = res['token']?.toString();
      _verifiedForEmail = email;
    });
    _msg(
        'E-mail de confirmação enviado para $email! Abre a tua caixa de correio, clica no link e depois toca em "Confirmar Link".');
  }

  Future<void> _confirmInboxEmailLink() async {
    final token = _pendingFirebaseToken;
    if (token == null || token.isEmpty) {
      _msg('Clica primeiro em "Enviar E-mail de Confirmação".');
      return;
    }
    setState(() => _busy = true);
    final ok = await UserAccountManager.checkFirebaseEmailVerified(token);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      setState(() => _emailVerified = true);
      _msg('E-mail confirmado com sucesso!');
    } else {
      _msg(
          'Ainda não detetámos o clique no link enviado para a tua caixa de correio.');
    }
  }

  Future<void> _submitAuth() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _msg('Preenche o e-mail e a palavra-passe.');
      return;
    }

    if (!_isRegister) {
      setState(() => _busy = true);
      final existing = await UserAccountManager.findRegisteredAccount(email);
      if (!mounted) return;
      setState(() => _busy = false);

      if (existing == null || existing['registrationCompleted'] != true) {
        _msg('Conta não encontrada. Cria primeiro o teu registo.');
        return;
      }
      final savedPass = (existing['passwordSecret'] ?? '').toString();
      if (savedPass.isNotEmpty && savedPass != pass) {
        _msg('Palavra-passe incorreta.');
        return;
      }
      await UserAccountManager.saveUser(existing);
      await UserAccountManager.saveCredentials(email, pass);
      widget.onAuthenticated(existing);
      return;
    }

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final nick = _nickCtrl.text.trim();

    if (firstName.isEmpty || nick.isEmpty) {
      _msg('Preenche o teu nome e o nickname.');
      return;
    }
    if (_birthDate == null) {
      _msg('Seleciona a tua data de nascimento.');
      return;
    }
    if (_calculateAge(_birthDate!) < 13) {
      _msg('É necessário ter pelo menos 13 anos para criar conta.');
      return;
    }
    if (!_emailVerified || _verifiedForEmail != email) {
      _msg(
          'Valida o teu e-mail na caixa de correio antes de concluir o registo.');
      return;
    }
    if (pass.length < 6 || pass != _passConfirmCtrl.text.trim()) {
      _msg('A palavra-passe deve ter mínimo 6 caracteres e coincidir.');
      return;
    }
    if (!_acceptedTerms) {
      _msg('Aceita os Termos e Política de Privacidade para continuar.');
      return;
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final consentId =
        'CONSENT-${DateTime.now().millisecondsSinceEpoch}-${1000 + Random().nextInt(9000)}';

    final user = <String, dynamic>{
      'registrationCompleted': true,
      'authProvider': _googlePhotoUrl.isNotEmpty ? 'google' : 'email',
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nick,
      'birthDate': _birthDate!.toIso8601String(),
      'age': _calculateAge(_birthDate!),
      'country': _selectedCountry,
      'email': email,
      'photoUrl': _googlePhotoUrl,
      'passwordSecret': pass,
      'legalAuditLog': {
        'consentId': consentId,
        'acceptedAtUtc': nowUtc,
        'termsVersion': UserAccountManager.termsVersion,
      },
    };

    await UserAccountManager.saveUser(user);
    await UserAccountManager.saveCredentials(email, pass);
    widget.onAuthenticated(user);
  }
    Widget _googleLogoIcon() {
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleOfficialPainter()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'icon.png',
                    height: 68,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_fire_department,
                      size: 68,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HELL',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'CREATOR OS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'UM CRIADOR • VÁRIAS PLATAFORMAS • CONTROLO TOTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRegister
                                ? const Color(0xFF1E7BFF)
                                : Colors.white10,
                          ),
                          onPressed: () {
                            setState(() {
                              _isRegister = true;
                              _emailCtrl.clear();
                              _passCtrl.clear();
                              _passConfirmCtrl.clear();
                              _emailVerified = false;
                              _pendingFirebaseToken = null;
                            });
                          },
                          child: const Text(
                            'Criar Registo',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isRegister
                                ? const Color(0xFF1E7BFF)
                                : Colors.white10,
                          ),
                          onPressed: () async {
                            setState(() {
                              _isRegister = false;
                              _emailCtrl.clear();
                              _passCtrl.clear();
                            });
                            final savedCreds =
                                await UserAccountManager.getSavedCredentials();
                            if (!mounted || _isRegister) return;
                            if (savedCreds != null &&
                                (savedCreds['identifier'] ?? '').isNotEmpty) {
                              setState(() {
                                _emailCtrl.text =
                                    savedCreds['identifier'] ?? '';
                                _passCtrl.text = savedCreds['password'] ?? '';
                              });
                            }
                          },
                          child: const Text(
                            'Já Tenho Conta',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _authenticateWithGoogle(
                              isRegisterFlow: _isRegister),
                      icon: _googleLogoIcon(),
                      label: Text(
                        _isRegister
                            ? 'Registar com Conta Google'
                            : 'Entrar com Conta Google',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isRegister) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Nome *', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Apelido', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nickCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nickname de Criador *', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            inputFormatters: [_BirthDateAutoFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Nascimento (DD/MM/AAAA) *',
                              hintText: '15/08/1998',
                              isDense: true,
                            ),
                            onChanged: (val) {
                              if (val.length == 10) {
                                final p = val.split('/');
                                if (p.length == 3) {
                                                                   final d = int.tryParse(p.first);
                                  final m = int.tryParse(p.elementAt(1));
                                  final y = int.tryParse(p.last);

                                  if (d != null && m != null && y != null && y >= 1920 && y <= DateTime.now().year) {
                                    setState(() => _birthDate = DateTime(y, m, d));
                                  }
                                }
                              } else if (_birthDate != null) {
                                setState(() => _birthDate = null);
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCountry,
                            dropdownColor: const Color(0xFF0B1636),
                            decoration: const InputDecoration(
                                labelText: 'País', isDense: true),
                            items: _countries
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _selectedCountry = v ?? 'Portugal'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail (ou Nickname para entrar)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Palavra-passe',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passConfirmCtrl,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar Palavra-passe',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!_emailVerified)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _busy ? null : _sendVerificationEmailToInbox,
                              icon: const Icon(
                                  Icons.mark_email_unread_outlined,
                                  size: 16),
                              label: const Text(
                                'Enviar E-mail de Confirmação',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                          if (_pendingFirebaseToken != null) ...[
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed:
                                  _busy ? null : _confirmInboxEmailLink,
                              child: const Text('Confirmar Link',
                                  style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ],
                      )
                    else
                      const Row(
                        children: [
                          Icon(Icons.verified,
                              color: Colors.greenAccent, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'E-mail verificado com sucesso!',
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                      title: const Text(
                        'Aceito os Termos de Utilização e Política de Privacidade.',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF050B1E),
                      ),
                      onPressed: _busy ? null : _submitAuth,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isRegister
                                  ? 'Concluir Registo'
                                  : 'Entrar na Aplicação',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
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

class AuthScreen extends StatelessWidget {
  final Function(Map<String, dynamic>) onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  Widget build(BuildContext context) {
    return AuthGateScreen(onAuthenticated: onAuthenticated);
  }
}

class AppLockScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUnlocked;
  final VoidCallback? onLogout;
  const AppLockScreen({
    super.key,
    required this.user,
    required this.onUnlocked,
    this.onLogout,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _tryUnlock();
  }

  Future<void> _tryUnlock() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        widget.onUnlocked();
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: 'Desbloqueia o HELL CREATOR OS',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      if (mounted) widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 64, color: Color(0xFF38BDF8)),
            const SizedBox(height: 12),
            const Text('HELL CREATOR OS BLOQUEADO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _tryUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Desbloquear Agora'),
            ),
          ],
        ),
      ),
    );
  }
}

class AutofillPrivacySettingsCard extends StatefulWidget {
  const AutofillPrivacySettingsCard({super.key});

  @override
  State<AutofillPrivacySettingsCard> createState() =>
      _AutofillPrivacySettingsCardState();
}

class _AutofillPrivacySettingsCardState
    extends State<AutofillPrivacySettingsCard> {
  bool _enabled = true;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final e = await UserAccountManager.isAutofillEnabled();
    final s = await UserAccountManager.getSavedCredentials();
    if (mounted) {
      setState(() {
        _enabled = e;
        _hasSaved = s != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title: const Text('Guardar sessão e preenchimento automático'),
            subtitle: const Text('Entra automaticamente sem repetir login.'),
            value: _enabled,
            onChanged: (v) async {
              await UserAccountManager.setAutofillEnabled(v);
              await _refresh();
            },
          ),
          if (_hasSaved)
            TextButton.icon(
              onPressed: () async {
                await UserAccountManager.clearSavedCredentials();
                await _refresh();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: const Text(
                'Limpar credenciais guardadas neste dispositivo',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
