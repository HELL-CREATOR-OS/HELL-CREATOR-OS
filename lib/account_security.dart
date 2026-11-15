import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';

class UserAccountManager {
  static const String _activeUserKey = 'hell_active_user_v3';
  static const String _registryKey = 'hell_registered_accounts_v3';
  static const String _vipCodesKey = 'hell_generated_vip_codes_v1';

  static String gravatarUrlForEmail(String email) {
    final clean = email.trim().toLowerCase();
    final hash = md5.convert(utf8.encode(clean)).toString();
    return 'https://gravatar.com';
  }

  static Future<Map<String, Map<String, dynamic>>> getAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>?> findAccountByEmail(String email) async {
    final all = await getAllAccounts();
    return all[email.trim().toLowerCase()];
  }

  static Future<void> registerOrUpdateAccount(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty) return;

    user['email'] = email;
    user['isOwner'] = DefaultMediaLibrary.isOwnerEmail(email);
    if (user['isOwner'] == true) {
      user['isVip'] = true;
    }

    final all = await getAllAccounts();
    all[email] = user;
    await prefs.setString(_registryKey, jsonEncode(all));
    await prefs.setString(_activeUserKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final user = Map<String, dynamic>.from(jsonDecode(raw));
      user['isOwner'] = DefaultMediaLibrary.isOwnerEmail(user['email']);
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeUserKey);
  }
  static Future<List<String>> getVipCodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_vipCodesKey) ?? ['HELL-VIP-3DIAS', 'PARCEIRO-HELL'];
  }

  static Future<void> addVipCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getVipCodes();
    final clean = code.trim().toUpperCase();
    if (clean.isNotEmpty && !list.contains(clean)) {
      list.insert(0, clean);
      await prefs.setStringList(_vipCodesKey, list);
    }
  }

  static Future<bool> redeemVipCode(String code, Map<String, dynamic> user) async {
    final list = await getVipCodes();
    final clean = code.trim().toUpperCase();
    if (list.contains(clean)) {
      user['isVip'] = true;
      user['vipCodeUsed'] = clean;
      await registerOrUpdateAccount(user);
      return true;
    }
    return false;
  }

  static Color statusColor(String? status) {
    switch (status) {
      case 'dnd':
        return Colors.orange;
      case 'invisible':
        return Colors.white;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.green;
    }
  }

  static Widget buildUserAvatar(Map<String, dynamic> user, {double radius = 22}) {
    final customPath = user['avatarPath']?.toString() ?? '';
    final googlePhoto = user['photoUrl']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final isOwner = DefaultMediaLibrary.isOwnerEmail(email);

    ImageProvider? img;
    if (customPath.isNotEmpty && File(customPath).existsSync()) {
      img = FileImage(File(customPath));
    } else if (googlePhoto.startsWith('http')) {
      img = NetworkImage(googlePhoto);
    } else if (email.isNotEmpty) {
      img = NetworkImage(gravatarUrlForEmail(email));
    }

    return Container(
      padding: EdgeInsets.all(isOwner ? 2.2 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isOwner ? Border.all(color: const Color(0xFFFACC15), width: 2) : null,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1E78FF),
        backgroundImage: img,
        child: img == null ? Icon(Icons.person, color: Colors.white, size: radius) : null,
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
  bool _loading = false;
  bool _acceptedTerms = false;
  bool _codeSent = false;
  String _generatedCode = '';

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _verifyCodeCtrl = TextEditingController();

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  void _openTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF08112B),
        title: const Text('Termos de Utilização & Responsabilidades', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 15)),
        content: const SizedBox(
          width: 480,
          height: 360,
          child: SingleChildScrollView(
            child: Text(DefaultMediaLibrary.legalTermsAndResponsibilityText, style: TextStyle(fontSize: 12, height: 1.45, color: Colors.white70)),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              setState(() => _acceptedTerms = true);
              Navigator.pop(ctx);
            },
            child: const Text('Li e Aceito os Termos', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      _showMsg('Introduz um endereço de e-mail válido.', isError: true);
      return;
    }
    if (!_acceptedTerms) {
      _showMsg('Tens de aceitar os Termos de Utilização e Responsabilidades primeiro.', isError: true);
      return;
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _generatedCode = code;
      _codeSent = true;
    });
    _showMsg('Código de confirmação enviado por ${DefaultMediaLibrary.brandOfficialEmail}: $code');
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final account = await GoogleSignIn(scopes: ['email', 'profile']).signIn();
      if (account != null) {
        final email = account.email.trim().toLowerCase();
        final existing = await UserAccountManager.findAccountByEmail(email);
        final user = existing ??
            {
              'firstName': account.displayName?.split(' ').first ?? 'Criador',
              'lastName': account.displayName?.split(' ').skip(1).join(' ') ?? '',
              'nickname': account.displayName ?? email.split('@').first,
              'email': email,
              'photoUrl': account.photoUrl ?? UserAccountManager.gravatarUrlForEmail(email),
              'provider': 'google',
              'status': 'online',
              'publicProfile': true,
              'showPrivateData': false,
              'securityMethods': <String>[],
            };
        if (account.photoUrl != null && account.photoUrl!.isNotEmpty) {
          user['photoUrl'] = account.photoUrl;
        }
        await UserAccountManager.registerOrUpdateAccount(user);
        widget.onAuthenticated(user);
      }
    } catch (_) {
      _showMsg('Início de sessão Google indisponível neste dispositivo. Usa o registo por e-mail.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _submitForm() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    if (!email.contains('@') || pass.length < 4) {
      _showMsg('Introduz um e-mail válido e uma palavra-passe (mínimo 4 caracteres).', isError: true);
      return;
    }

    if (!_isRegister) {
      final existing = await UserAccountManager.findAccountByEmail(email);
      if (existing == null) {
        _showMsg('E-mail não registado. Por favor cria primeiro o teu registo.', isError: true);
        setState(() => _isRegister = true);
        return;
      }
      if ((existing['password'] ?? '') != pass) {
        _showMsg('Palavra-passe incorreta. Verifica os dados e tenta novamente.', isError: true);
        return;
      }
      await UserAccountManager.registerOrUpdateAccount(existing);
      widget.onAuthenticated(existing);
      return;
    }

    if (!_acceptedTerms) {
      _showMsg('É obrigatório aceitar os Termos de Utilização e Responsabilidades.', isError: true);
      return;
    }
    if (!_codeSent || _verifyCodeCtrl.text.trim() != _generatedCode) {
      _showMsg('Valida primeiro o código de confirmação de 6 dígitos enviado para o teu e-mail.', isError: true);
      return;
    }

    final newUser = {
      'firstName': _firstNameCtrl.text.trim().isEmpty ? 'Criador' : _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'nickname': _nickCtrl.text.trim().isEmpty ? email.split('@').first : _nickCtrl.text.trim(),
      'email': email,
      'phone': _phoneCtrl.text.trim(),
      'password': pass,
      'photoUrl': UserAccountManager.gravatarUrlForEmail(email),
      'provider': 'email',
      'status': 'online',
      'publicProfile': true,
      'showPrivateData': false,
      'securityMethods': <String>['password'],
    };
    await UserAccountManager.registerOrUpdateAccount(newUser);
    widget.onAuthenticated(newUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF132E73), Color(0xFF050B1E)]),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1636),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF1E78FF), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('icon.png', height: 68, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 60, color: Color(0xFF38BDF8)))),
                  const SizedBox(height: 8),
                  const Text('HELL LIVE', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                  Text(_isRegister ? 'Criar Conta Verificada e Segura' : 'Acesso Seguro à Tua Conta', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF7DD3FC))),
                  const SizedBox(height: 16),
                  if (_isRegister) ...[
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'Nome', isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Apelido', isDense: true, border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: 'Nickname / Canal', prefixIcon: Icon(Icons.alternate_email), isDense: true, border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined), isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  if (_isRegister) ...[
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contacto Telefónico (Para Código SMS/Backup)', prefixIcon: Icon(Icons.phone_android), isDense: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    onChanged: (val) async {
                      if (!_isRegister) {
                        final existing = await UserAccountManager.findAccountByEmail(_emailCtrl.text.trim().toLowerCase());
                        if (existing != null && (existing['password'] ?? '') == val.trim()) {
                          await UserAccountManager.registerOrUpdateAccount(existing);
                          widget.onAuthenticated(existing);
                        }
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Palavra-Passe (Entra automaticamente ao acertar)', prefixIcon: Icon(Icons.lock_outline), isDense: true, border: OutlineInputBorder()),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(value: _acceptedTerms, activeColor: const Color(0xFF38BDF8), onChanged: (v) => setState(() => _acceptedTerms = v ?? false)),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openTermsDialog,
                            child: const Text('Aceito os Termos de Utilização, Regras e Isenção de Responsabilidade (Ler)', style: TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8), decoration: TextDecoration.underline)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _verifyCodeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Código 6 Dígitos', isDense: true, border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF122E73)),
                          onPressed: _sendVerificationCode,
                          child: Text(_codeSent ? 'Reenviar' : 'Enviar Código', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: _loading ? null : _submitForm,
                    child: Text(_isRegister ? 'Confirmar Código e Criar Conta' : 'Entrar na Conta', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 26, color: Colors.redAccent),
                    label: const Text('Entrar / Sincronizar com Conta Google', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _codeSent = false;
                    }),
                    child: Text(_isRegister ? 'Já tenho conta registada · Iniciar Sessão' : 'Ainda não tens conta? Criar Registo Obrigatório', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
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
class AppLockScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUnlocked;
  final VoidCallback onLogout;
  const AppLockScreen({super.key, required this.user, required this.onUnlocked, required this.onLogout});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _unlockCtrl = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    final methods = List<String>.from(widget.user['securityMethods'] ?? []);
    if (methods.contains('biometric')) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Desbloqueia a tua conta HELL Live',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {}
  }

  void _checkAutoUnlock(String val) {
    final savedPass = (widget.user['password'] ?? '').toString();
    final savedPin = (widget.user['pin'] ?? '').toString();
    if ((savedPass.isNotEmpty && val == savedPass) || (savedPin.isNotEmpty && val == savedPin)) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = DefaultMediaLibrary.isOwnerEmail(widget.user['email']);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.0, colors: [Color(0xFF132E73), Color(0xFF050B1E)]),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1636),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isOwner ? const Color(0xFFFACC15) : const Color(0xFF38BDF8), width: 1.6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAccountManager.buildUserAvatar(widget.user, radius: 36),
                const SizedBox(height: 12),
                Text(widget.user['nickname'] ?? 'Criador', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (isOwner)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('👑 FUNDADOR / DONO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.5)),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _unlockCtrl,
                  obscureText: true,
                  onChanged: _checkAutoUnlock,
                  decoration: const InputDecoration(
                    labelText: 'Palavra-Passe ou PIN (Entrada Automática)',
                    prefixIcon: Icon(Icons.lock_open),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint, color: Color(0xFF38BDF8)),
                  label: const Text('Desbloquear com Biometria / Dispositivo', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: widget.onLogout,
                  child: const Text('Trocar de Conta', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class ProfileFullScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onLogout;

  const ProfileFullScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileFullScreen> createState() => _ProfileFullScreenState();
}

class _ProfileFullScreenState extends State<ProfileFullScreen> {
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  late TextEditingController _nickCtrl;
  late TextEditingController _birthCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  final _vipGenCtrl = TextEditingController();

  late String _status;
  late bool _publicProfile;
  late bool _showPrivateData;
  List<String> _vipCodes = [];

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.user['firstName'] ?? '');
    _lastCtrl = TextEditingController(text: widget.user['lastName'] ?? '');
    _nickCtrl = TextEditingController(text: widget.user['nickname'] ?? '');
    _birthCtrl = TextEditingController(text: widget.user['birthDate'] ?? '');
    _countryCtrl = TextEditingController(text: widget.user['country'] ?? 'Portugal');
    _cityCtrl = TextEditingController(text: widget.user['city'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.user['phone'] ?? '');
    _bioCtrl = TextEditingController(text: widget.user['bio'] ?? '');
    _status = widget.user['status'] ?? 'online';
    _publicProfile = widget.user['publicProfile'] ?? true;
    _showPrivateData = widget.user['showPrivateData'] ?? false;
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    final codes = await UserAccountManager.getVipCodes();
    if (mounted) setState(() => _vipCodes = codes);
  }

  Future<void> _saveProfile() async {
    final updated = Map<String, dynamic>.from(widget.user);
    updated['firstName'] = _firstCtrl.text.trim();
    updated['lastName'] = _lastCtrl.text.trim();
    updated['nickname'] = _nickCtrl.text.trim();
    updated['birthDate'] = _birthCtrl.text.trim();
    updated['country'] = _countryCtrl.text.trim();
    updated['city'] = _cityCtrl.text.trim();
    updated['phone'] = _phoneCtrl.text.trim();
    updated['bio'] = _bioCtrl.text.trim();
    updated['status'] = _status;
    updated['publicProfile'] = _publicProfile;
    updated['showPrivateData'] = _showPrivateData;
    await UserAccountManager.registerOrUpdateAccount(updated);
    widget.onUserUpdated(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = DefaultMediaLibrary.isOwnerEmail(widget.user['email']);
    final bioCardLink = 'https://hell.live{_nickCtrl.text.trim().isEmpty ? 'criador' : _nickCtrl.text.trim()}';

    return Scaffold(
      appBar: AppBar(title: const Text('O Meu Perfil Completo', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                UserAccountManager.buildUserAvatar(widget.user, radius: 44),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFF1E78FF),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (res != null && res.files.single.path != null) {
                        final updated = Map<String, dynamic>.from(widget.user);
                        updated['avatarPath'] = res.files.single.path!;
                        await UserAccountManager.registerOrUpdateAccount(updated);
                        widget.onUserUpdated(updated);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isOwner ? '👑 FUNDADOR / DONO HELL LIVE' : (widget.user['isVip'] == true ? '⭐ CRIADOR VIP ATIVO' : 'Criador Registado'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isOwner ? const Color(0xFFFACC15) : const Color(0xFF38BDF8)),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF122E73), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFACC15))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👑 Painel de Fundador · Gerador de Chaves VIP / Parceiro', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFACC15), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _vipGenCtrl, decoration: const InputDecoration(hintText: 'Ex: PARCEIRO-2026', isDense: true, border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15)),
                        onPressed: () async {
                          await UserAccountManager.addVipCode(_vipGenCtrl.text);
                          _vipGenCtrl.clear();
                          await _loadCodes();
                        },
                        child: const Text('Criar Chave', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _vipCodes.map((c) => ActionChip(
                          label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          avatar: const Icon(Icons.copy, size: 14),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: c));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chave VIP "$c" copiada!')));
                          },
                        )).toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF38BDF8))),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: Color(0xFF38BDF8)),
                const SizedBox(width: 10),
                Expanded(child: Text('Cartão de Visita / Bio HELL:\n$bioCardLink', style: const TextStyle(fontSize: 11.5, color: Colors.white70))),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFF38BDF8)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bioCardLink));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link Cartão Bio HELL copiado!')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _firstCtrl, decoration: const InputDecoration(labelText: 'Nome', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _lastCtrl, decoration: const InputDecoration(labelText: 'Apelido', isDense: true))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: 'Nickname / Canal', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _birthCtrl, decoration: const InputDecoration(labelText: 'Data de Nascimento (Opcional)', isDense: true)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'País (Opcional)', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Cidade (Opcional)', isDense: true))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contacto Telefónico', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Sobre Mim (Apresentação para a Comunidade)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Perfil Público na Comunidade', style: TextStyle(fontSize: 13)),
            value: _publicProfile,
            onChanged: (v) => setState(() => _publicProfile = v),
          ),
          SwitchListTile(
            title: const Text('Tornar Dados Pessoais Visíveis (Assumo total responsabilidade)', style: TextStyle(fontSize: 12.5)),
            subtitle: const Text('Se desligado, cidade, telefone e e-mail ficam ocultos do público.', style: TextStyle(fontSize: 11, color: Colors.white54)),
            value: _showPrivateData,
            onChanged: (v) => setState(() => _showPrivateData = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: _saveProfile,
            child: const Text('Guardar Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: widget.onLogout, child: const Text('Terminar Sessão', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}
class PrivacySecurityTermsPanel extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  const PrivacySecurityTermsPanel({super.key, required this.user, required this.onUserUpdated});

  @override
  State<PrivacySecurityTermsPanel> createState() => _PrivacySecurityTermsPanelState();
}

class _PrivacySecurityTermsPanelState extends State<PrivacySecurityTermsPanel> {
  final _pinCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final methods = List<String>.from(widget.user['securityMethods'] ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Desbloqueio por Biometria / Impressão Digital', style: TextStyle(fontSize: 13.5)),
          value: methods.contains('biometric'),
          onChanged: (v) async {
            final updated = Map<String, dynamic>.from(widget.user);
            final list = List<String>.from(updated['securityMethods'] ?? []);
            v ? list.add('biometric') : list.remove('biometric');
            updated['securityMethods'] = list.toSet().toList();
            await UserAccountManager.registerOrUpdateAccount(updated);
            widget.onUserUpdated(updated);
            setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _pinCtrl, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Definir PIN Rápido (4-6 dígitos)', isDense: true))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () async {
                  if (_pinCtrl.text.trim().length < 4) return;
                  final updated = Map<String, dynamic>.from(widget.user);
                  updated['pin'] = _pinCtrl.text.trim();
                  final list = List<String>.from(updated['securityMethods'] ?? []);
                  if (!list.contains('pin')) list.add('pin');
                  updated['securityMethods'] = list;
                  await UserAccountManager.registerOrUpdateAccount(updated);
                  widget.onUserUpdated(updated);
                  _pinCtrl.clear();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN de desbloqueio automático guardado!')));
                },
                child: const Text('Guardar PIN', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.gavel, color: Color(0xFF38BDF8)),
          title: const Text('Regras, Termos de Utilização & Responsabilidades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: const Text('Consultar cláusulas de isenção, RGPD e direitos de autor', style: TextStyle(fontSize: 11.5)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF08112B),
                title: const Text('Termos Legais & Responsabilidades — HELL Live', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14.5, fontWeight: FontWeight.bold)),
                content: const SizedBox(
                  width: 500,
                  height: 380,
                  child: SingleChildScrollView(
                    child: Text(DefaultMediaLibrary.legalTermsAndResponsibilityText, style: TextStyle(fontSize: 12, height: 1.45, color: Colors.white70)),
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
              ),
            );
          },
        ),
      ],
    );
  }
}
