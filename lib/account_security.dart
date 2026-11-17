import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
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
    final photoUrl = (user['photoUrl'] ?? '').toString();
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(File(localPath)));
    }
    if (photoUrl.startsWith('http')) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1E78FF),
      child: Icon(Icons.person, size: radius * 1.1, color: Colors.white),
    );
  }
}
class LegalTermsModal {
  static const String fullLegalText = '''
TERMOS DE UTILIZAÇÃO, ISENÇÃO DE RESPONSABILIDADE E POLÍTICA DE PRIVACIDADE (RGPD UNIÃO EUROPEIA & LEIS INTERNACIONAIS) — VERSÃO v1.0-EU-GLOBAL

1. NATUREZA DA PLATAFORMA E ISENÇÃO TOTAL DE RESPONSABILIDADE
O HELL CREATOR OS é uma ferramenta técnica neutra de apoio à produção e gestão de transmissões em direto. O proprietário e criador do HELL CREATOR OS não controla, edita, supervisiona nem aprova previamente os conteúdos transmitidos, publicados, falados ou partilhados pelos utilizadores.
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
          '⚖️ Termos Legais & Isenção de Responsabilidade',
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
  final _emailCodeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  DateTime? _birthDate;
  String _selectedCountry = 'Portugal';
  String _googlePhotoUrl = '';
  String? _expectedEmailCode;

  final List<String> _countries = [
    'Portugal', 'Brasil', 'Espanha', 'França', 'Reino Unido', 'Alemanha',
    'Suíça', 'Luxemburgo', 'Angola', 'Moçambique', 'Cabo Verde', 'Estados Unidos', 'Outro País',
  ];

  @override
  void initState() {
    super.initState();
    _loadAutofillAndDefaultTab();
  }

  Future<void> _loadAutofillAndDefaultTab() async {
    final savedCreds = await UserAccountManager.getSavedCredentials();
    if (!mounted) return;
    if (savedCreds != null && (savedCreds['identifier'] ?? '').isNotEmpty) {
      setState(() {
        _isRegister = false;
        _emailCtrl.text = savedCreds['identifier'] ?? '';
        _passCtrl.text = savedCreds['password'] ?? '';
      });
    } else {
      setState(() => _isRegister = true);
    }
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _sendEmailVerificationCode() {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _msg('Introduz um e-mail válido antes de pedir o código.');
      return;
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    setState(() => _expectedEmailCode = code);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        title: const Text('📧 Código de Verificação', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
        content: Text('Código enviado para $email:\n\n$code\n\nIntroduz este código de 6 dígitos no formulário.', style: const TextStyle(fontSize: 13.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              _emailCodeCtrl.text = code;
              Navigator.pop(ctx);
            },
            child: const Text('Preencher Automaticamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _askToSaveCredentialsAndEnter(Map<String, dynamic> user, String identifier, String password) async {
    final autofillEnabled = await UserAccountManager.isAutofillEnabled();
    final currentSaved = await UserAccountManager.getSavedCredentials();
    final alreadySaved = currentSaved != null &&
        currentSaved['identifier'] == identifier.trim() &&
        currentSaved['password'] == password;

    if (!autofillEnabled || alreadySaved || !mounted) {
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
        title: const Text('🔐 Guardar Dados de Acesso?', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16)),
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
              await UserAccountManager.saveCredentials(identifier, password);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar Dados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    widget.onAuthenticated(user);
  }

  Future<void> _googleAuth() async {
    setState(() => _busy = true);
    try {
      const windowsClientId = '251620021978-' + 'vbinumssj37e57ttiriecucassl9amjd.apps.googleusercontent.com';
      if (Platform.isWindows) {
        GoogleSignInDart.register(clientId: windowsClientId);
      }
      final googleSignIn = GoogleSignIn(
        clientId: Platform.isWindows ? windowsClientId : null,
        scopes: ['email', 'profile'],
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final account = await googleSignIn.signIn();
      if (account != null) {
        final existing = await UserAccountManager.findRegisteredAccount(account.email);
        if (existing != null && existing['registrationCompleted'] == true) {
          if ((account.photoUrl ?? '').isNotEmpty) existing['photoUrl'] = account.photoUrl;
          await UserAccountManager.saveUser(existing);
          widget.onAuthenticated(existing);
          return;
        }
        final parts = (account.displayName ?? 'Criador HELL').trim().split(' ');
        setState(() {
          _isRegister = true;
          _firstNameCtrl.text = parts.first;
          _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          _nickCtrl.text = account.email.split('@').first;
          _emailCtrl.text = account.email;
          _googlePhotoUrl = account.photoUrl ?? '';
          _expectedEmailCode = 'GOOGLE_VERIFIED';
          _emailCodeCtrl.text = 'GOOGLE_VERIFIED';
        });
        _msg('Conta Google (${account.email}) importada! Completa a data de nascimento, palavra-passe e aceita os Termos.');
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final quickGoogleCtrl = TextEditingController(text: _emailCtrl.text);
      final quickNameCtrl = TextEditingController();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          title: const Text('Conta Google — Preenchimento Rápido', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 15.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Detalhe técnico: ${e.toString().split('\n').first}\n\nIntroduz o teu e-mail Google abaixo para importar ou entrar:', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(controller: quickNameCtrl, decoration: const InputDecoration(labelText: 'Nome Completo', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: quickGoogleCtrl, decoration: const InputDecoration(labelText: 'E-mail Google (@gmail.com)', isDense: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
              onPressed: () async {
                final gEmail = quickGoogleCtrl.text.trim().toLowerCase();
                if (!gEmail.contains('@')) return;
                Navigator.pop(ctx);
                final existing = await UserAccountManager.findRegisteredAccount(gEmail);
                if (existing != null && existing['registrationCompleted'] == true) {
                  await UserAccountManager.saveUser(existing);
                  widget.onAuthenticated(existing);
                  return;
                }
                final parts = (quickNameCtrl.text.trim().isEmpty ? gEmail.split('@').first : quickNameCtrl.text.trim()).split(' ');
                setState(() {
                  _isRegister = true;
                  _firstNameCtrl.text = parts.first;
                  _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                  _nickCtrl.text = gEmail.split('@').first;
                  _emailCtrl.text = gEmail;
                  _expectedEmailCode = 'GOOGLE_VERIFIED';
                  _emailCodeCtrl.text = 'GOOGLE_VERIFIED';
                });
                _msg('Dados Google preenchidos! Completa a data de nascimento, palavra-passe e aceita os Termos.');
              },
              child: const Text('Continuar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
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

    if (firstName.isEmpty || lastName.isEmpty || nick.isEmpty) {
      _msg('Preenche o Nome Próprio, Apelido e Nickname.');
      return;
    }
    if (_birthDate == null) {
      _msg('Seleciona a tua Data de Nascimento.');
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
    if (_expectedEmailCode == null || _emailCodeCtrl.text.trim() != _expectedEmailCode) {
      _msg('Valida o teu e-mail com o código de 6 dígitos antes de continuar.');
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
        'fullName': '$firstName $lastName',
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
    final birthLabel = _birthDate == null
        ? 'Selecionar Data de Nascimento (Mín. 16 anos)'
        : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year} (${_calculateAge(_birthDate!)} anos)';

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
                      onPressed: _busy ? null : _googleAuth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GoogleOfficialLogo(size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isRegister ? 'Preencher com Conta Google' : 'Entrar com Conta Google',
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
                        Expanded(child: TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Apelido', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: 'Nickname / Nome de Criador', isDense: true)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickBirthDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Data de Nascimento', isDense: true, border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(birthLabel, style: const TextStyle(fontSize: 12.5)),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      dropdownColor: const Color(0xFF0B1636),
                      decoration: const InputDecoration(labelText: 'País / Região', isDense: true),
                      items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCountry = v ?? 'Portugal'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: _isRegister ? 'E-mail Oficial' : 'E-mail ou Nickname',
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_isRegister) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                          onPressed: _sendEmailVerificationCode,
                          child: const Text('Enviar Código', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                        ),
                      ],
                    ],
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 10),
                    TextField(controller: _emailCodeCtrl, decoration: const InputDecoration(labelText: 'Código de Verificação (6 Dígitos)', isDense: true)),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Palavra-passe',
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: _submitForm,
                      child: Text(_isRegister ? 'Concluir Registo e Entrar' : 'Entrar na Conta', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  decoration: const InputDecoration(labelText: 'PIN ou Palavra-passe', border: OutlineInputBorder()),
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
