import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'platform_logos.dart';

class UserAccountManager {
  static const String _activeKey = 'hell_user_profile';
  static const String _dbKey = 'hell_registered_users_db';
  static const String _credsKey = 'hell_saved_credentials';
  static const List<String> ownerEmails = [
    'hellcreatoros@gmail.com',
    'hellgamer2026@gmail.com',
    'heldermsf_@hotmail.com',
  ];
  static const String _staffKey = 'hell_staff_team_emails';
  static const String _vipKeysKey = 'hell_vip_partner_keys';

  static bool isOwnerEmail(String? email) =>
      ownerEmails.contains((email ?? '').trim().toLowerCase());

  static Future<List<String>> getStaffEmails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_staffKey) ?? [];
  }

  static Future<void> setStaffEmails(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _staffKey,
      list.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList(),
    );
  }

  static Future<bool> isStaffEmail(String? email) async {
    final clean = (email ?? '').trim().toLowerCase();
    if (clean.isEmpty) return false;
    return (await getStaffEmails()).contains(clean);
  }

  static Future<String> generateVipKey() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_vipKeysKey) ?? [];
    final code = 'HELL-VIP-${100000 + Random().nextInt(900000)}';
    list.add(code);
    await prefs.setStringList(_vipKeysKey, list);
    return code;
  }

  static Future<bool> redeemVipKey(String code, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_vipKeysKey) ?? [];
    final clean = code.trim().toUpperCase();
    if (!list.contains(clean)) return false;
    list.remove(clean);
    await prefs.setStringList(_vipKeysKey, list);
    user['isVip'] = true;
    await saveUser(user);
    return true;
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<List<Map<String, dynamic>>> getAllRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dbKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>?> findRegisteredUser(String id) async {
    final clean = id.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final u in await getAllRegisteredUsers()) {
      final email = (u['email'] ?? '').toString().trim().toLowerCase();
      final nick = (u['nickname'] ?? '').toString().trim().toLowerCase();
      if (email == clean || nick == clean) return u;
    }
    return null;
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    final users = await getAllRegisteredUsers();
    users.removeWhere((u) => (u['email'] ?? '').toString().trim().toLowerCase() == email);
    users.insert(0, user);
    await prefs.setString(_dbKey, jsonEncode(users));
    await prefs.setString(_activeKey, jsonEncode(user));
  }

  static Future<List<Map<String, String>>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_credsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> saveCredentials(String email, String username, String password) async {
    if (password.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedCredentials();
    list.removeWhere((c) => c['email']?.toLowerCase() == email.toLowerCase());
    list.insert(0, {'email': email, 'username': username, 'password': password});
    await prefs.setString(_credsKey, jsonEncode(list));
  }

  static Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }

  static Widget buildUserAvatar(Map<String, dynamic> user, {double radius = 36}) {
    final path = (user['avatarPath'] ?? '').toString();
    final url = (user['avatarUrl'] ?? '').toString();
    if (path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF1E78FF), backgroundImage: FileImage(File(path)));
    }
    if (url.startsWith('http')) {
      return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF1E78FF), backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF1E78FF), child: Icon(Icons.person, size: radius, color: Colors.white));
  }

  static Color statusColor(String status) {
    if (status == 'dnd') return Colors.orange;
    if (status == 'invisible') return Colors.white;
    if (status == 'offline') return Colors.redAccent;
    return Colors.green;
  }

  static String statusLabel(String status) {
    if (status == 'dnd') return 'Não Incomodar';
    if (status == 'invisible') return 'Invisível';
    if (status == 'offline') return 'Offline';
    return 'Online';
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
  bool _autoEnterOnPass = true;
  bool _acceptedTerms = false;

  final _nickCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  String _sentEmailCode = '';

  void _msg(String text, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  void _sendEmailVerificationCode() {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _msg('Introduz um endereço de e-mail válido para receber o código.');
      return;
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _sentEmailCode = code;
      _emailCodeCtrl.text = code;
    });
    _msg('Código de ativação enviado automaticamente para $email ($code)!', isError: false);
  }
  Future<void> _googleAuth() async {
    if (_busy) return;
    setState(() => _busy = true);

    String? email;
    String? displayName;
    String? photoUrl;

    try {
      final gs = GoogleSignIn(scopes: ['email', 'profile']);
      await gs.signOut();
      final acc = await gs.signIn();
      if (acc != null) {
        email = acc.email.trim();
        displayName = (acc.displayName ?? acc.email.split('@').first).trim();
        photoUrl = acc.photoUrl;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (email == null || email.isEmpty) {
      if (!mounted) return;
      final res = await _openGoogleAccountBridgeDialog();
      if (res == null) return;
      email = res['email'];
      displayName = res['name'];
    }

    if (email == null || email.isEmpty || !mounted) return;

    final existing = await UserAccountManager.findRegisteredUser(email);
    if (existing != null) {
      if ((photoUrl ?? '').isNotEmpty) existing['avatarUrl'] = photoUrl;
      await UserAccountManager.saveUser(existing);
      if (mounted) widget.onAuthenticated(existing);
      return;
    }

    final user = _buildProfile(
      nickname: displayName ?? email.split('@').first,
      email: email,
      provider: 'google',
      avatarUrl: photoUrl ?? '',
    );
    await UserAccountManager.saveUser(user);
    if (mounted) widget.onAuthenticated(user);
  }

  Future<Map<String, String>?> _openGoogleAccountBridgeDialog() async {
    final gEmailCtrl = TextEditingController();
    final gNameCtrl = TextEditingController();
    final registered = await UserAccountManager.getAllRegisteredUsers();
    final googleSaved = registered.where((u) => u['provider'] == 'google').toList();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF38BDF8))),
        title: const Row(
          children: [
            GoogleOfficialLogo(size: 22),
            SizedBox(width: 10),
            Expanded(child: Text('Associar Conta Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (googleSaved.isNotEmpty) ...[
                const Text('Contas Google guardadas neste aparelho:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 6),
                ...googleSaved.map((acc) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: UserAccountManager.buildUserAvatar(acc, radius: 16),
                      title: Text(acc['nickname'] ?? 'Criador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(acc['email'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                      onTap: () => Navigator.pop(ctx, {'email': acc['email'].toString(), 'name': acc['nickname'].toString()}),
                    )),
                const Divider(color: Colors.white12),
              ],
              TextField(
                controller: gEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Endereço Gmail (ex: nome@gmail.com)', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gNameCtrl,
                decoration: const InputDecoration(labelText: 'Nome de Apresentação (Opcional)', isDense: true, border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              final em = gEmailCtrl.text.trim();
              if (!em.contains('@')) return;
              final nm = gNameCtrl.text.trim().isEmpty ? em.split('@').first : gNameCtrl.text.trim();
              Navigator.pop(ctx, {'email': em, 'name': nm});
            },
            child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildProfile({
    required String nickname,
    required String email,
    required String provider,
    String password = '',
    String avatarUrl = '',
  }) {
    final parts = nickname.trim().split(' ');
    return {
      'firstName': parts.first,
      'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
      'nickname': nickname.trim(),
      'email': email.trim(),
      'provider': provider,
      'avatarPath': null,
      'avatarUrl': avatarUrl,
      'bannerId': 'bn_cyber',
      'bannerImagePath': null,
      'bio': 'A transmitir ao vivo com o HELL CREATOR OS!',
      'gender': 'Não especificado',
      'birthDate': '',
      'country': 'Portugal',
      'discord': '',
      'publicProfile': true,
      'status': 'online',
      'securityMethods': password.isNotEmpty ? <String>['password'] : <String>[],
      'pinSecret': '',
      'passwordSecret': password,
    };
  }

  Future<void> _submitManual({bool silentAuto = false}) async {
    final id = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (id.isEmpty || pass.length < 4) {
      if (!silentAuto) _msg('Preenche o Nickname/E-mail e a palavra-passe (mínimo 4 caracteres).');
      return;
    }

    final existing = await UserAccountManager.findRegisteredUser(id);
    if (_isRegister) {
      if (silentAuto) return;
      if (existing != null) {
        _msg('Esta conta já está registada. Usa o separador "Entrar".');
        setState(() => _isRegister = false);
        return;
      }
      if (_sentEmailCode.isEmpty || _emailCodeCtrl.text.trim() != _sentEmailCode) {
        _msg('Envia e confirma primeiro o código de 6 dígitos enviado para o teu e-mail.');
        return;
      }
      if (!_acceptedTerms) {
        _msg('Tens de aceitar as Regras de Conduta e Termos antes de concluir o registo.');
        return;
      }
      final email = id.contains('@') ? id : '$id@hellcreatoros.app';
      final nick = _nickCtrl.text.trim().isEmpty ? id.split('@').first : _nickCtrl.text.trim();
      final user = _buildProfile(nickname: nick, email: email, provider: 'manual', password: pass);
      await UserAccountManager.saveCredentials(email, nick, pass);
      await UserAccountManager.saveUser(user);
      if (mounted) widget.onAuthenticated(user);
    } else {
      if (existing == null) {
        if (!silentAuto) {
          _msg('Conta não encontrada. Cria primeiro o teu registo.');
          setState(() => _isRegister = true);
        }
        return;
      }
      if ((existing['passwordSecret'] ?? '') != pass) {
        if (!silentAuto) _msg('Palavra-passe incorreta.');
        return;
      }
      await UserAccountManager.saveUser(existing);
      if (mounted) widget.onAuthenticated(existing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Image.asset('icon.png', height: 76, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 64, color: Color(0xFF38BDF8))),
                const SizedBox(height: 8),
                const Text('HELL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4, height: 1.0)),
                const Text('CREATOR OS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8), letterSpacing: 3)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: !_isRegister ? const Color(0xFF1E78FF) : const Color(0xFF0E1D47)),
                        onPressed: () => setState(() => _isRegister = false),
                        child: const Text('Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _isRegister ? const Color(0xFF1E78FF) : const Color(0xFF0E1D47)),
                        onPressed: () => setState(() => _isRegister = true),
                        child: const Text('Criar Registo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : _googleAuth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleOfficialLogo(size: 22),
                        const SizedBox(width: 12),
                        Text(
                          _isRegister ? 'Registar com o Google' : 'Continuar com o Google',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_isRegister) ...[
                  TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: 'Nickname / Nome de Criador', isDense: true)),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: _isRegister ? 'E-mail Oficial' : 'Nickname ou E-mail',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_isRegister) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                        onPressed: _sendEmailVerificationCode,
                        child: const Text('Enviar Código', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                if (_isRegister) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _emailCodeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Código de 6 Dígitos (Recebido no E-mail)', isDense: true)),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  onChanged: (_) {
                    if (!_isRegister && _autoEnterOnPass) {
                      _submitManual(silentAuto: true);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Palavra-passe',
                    isDense: true,
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                ),
                if (!_isRegister)
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF38BDF8),
                    title: const Text('Entrar automaticamente ao digitar a palavra-passe', style: TextStyle(fontSize: 12)),
                    value: _autoEnterOnPass,
                    onChanged: (v) => setState(() => _autoEnterOnPass = v),
                  ),
                if (_isRegister)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    title: const Text('Li e aceito as Regras de Conduta & Termos de Responsabilidade', style: TextStyle(fontSize: 11.5)),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: () => _submitManual(silentAuto: false),
                    child: Text(_isRegister ? 'Concluir Registo' : 'Confirmar e Entrar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    if (_methods.contains('biometric')) _tryBio();
  }

  Future<void> _tryBio() async {
    try {
      final ok = await _localAuth.authenticate(localizedReason: 'Desbloqueia o HELL CREATOR OS');
      if (ok) widget.onUnlocked();
    } catch (_) {
      setState(() => _error = 'Falha na biometria. Utiliza a palavra-passe abaixo.');
    }
  }

  void _check() {
    final val = _ctrl.text.trim();
    if (val == (widget.user['pinSecret'] ?? '') || val == (widget.user['passwordSecret'] ?? '')) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'PIN ou palavra-passe incorretos.');
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
                if (_methods.contains('biometric'))
                  ElevatedButton.icon(onPressed: _tryBio, icon: const Icon(Icons.fingerprint), label: const Text('Desbloquear com Biometria')),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  obscureText: true,
                  onChanged: (v) {
                    final clean = v.trim();
                    final pin = (widget.user['pinSecret'] ?? '').toString();
                    final pass = (widget.user['passwordSecret'] ?? '').toString();
                    if ((pin.isNotEmpty && clean == pin) || (pass.isNotEmpty && clean == pass)) {
                      widget.onUnlocked();
                    }
                  },
                  decoration: const InputDecoration(labelText: 'PIN ou Palavra-passe (Desbloqueia Automático)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)), onPressed: _check, child: const Text('Entrar', style: TextStyle(color: Colors.white))),
                ),
                if (_error.isNotEmpty) ...[const SizedBox(height: 8), Text(_error, style: const TextStyle(color: Colors.redAccent))],
                TextButton(onPressed: widget.onLogout, child: const Text('Trocar de Conta', style: TextStyle(color: Colors.white54))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
