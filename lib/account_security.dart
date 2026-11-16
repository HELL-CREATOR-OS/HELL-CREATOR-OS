import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';

class HellUserSession {
  final String name;
  final String email;
  final String phone;
  final String role; // OWNER, STAFF, VIP, CREATOR
  final String pin;

  const HellUserSession({
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    required this.pin,
  });

  bool get isOwner =>
      HellAppInfo.owners.contains(email.trim().toLowerCase()) || role == 'OWNER';

  bool get hasFullFreeAccess => isOwner || role == 'STAFF' || role == 'VIP';
}

class AccountSecurityGate extends StatefulWidget {
  final Widget child;
  final Function(HellUserSession) onAuthenticated;

  const AccountSecurityGate({
    super.key,
    required this.child,
    required this.onAuthenticated,
  });

  @override
  State<AccountSecurityGate> createState() => _AccountSecurityGateState();
}

class _AccountSecurityGateState extends State<AccountSecurityGate> {
  bool _loading = true;
  bool _languageSelected = false;
  HellUserSession? _savedUser;
  bool _unlocked = false;

  String _authMode = 'welcome'; // welcome, google_pin, sms, register
  String _tempName = '';
  String _tempEmail = '';
  String _enteredPin = '';
  String _errorMessage = '';

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();
  bool _smsSent = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('hell_app_locale');
    if (savedLang != null && savedLang.isNotEmpty) {
      HellLocaleManager.currentLocale = savedLang;
      _languageSelected = true;
    }

    final email = prefs.getString('hell_user_email');
    final name = prefs.getString('hell_user_name');
    final pin = prefs.getString('hell_user_pin');
    final role = prefs.getString('hell_user_role') ?? 'CREATOR';
    final phone = prefs.getString('hell_user_phone') ?? '';

    if (email != null && email.isNotEmpty && pin != null && pin.length == 4) {
      setState(() {
        _savedUser = HellUserSession(
          name: name ?? email.split('@').first,
          email: email,
          phone: phone,
          role: role,
          pin: pin,
        );
        _languageSelected = true;
        _loading = false;
      });
    } else {
      setState(() {
        _savedUser = null;
        _loading = false;
      });
    }
  }

  Future<void> _selectLanguage(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_app_locale', localeCode);
    setState(() {
      HellLocaleManager.currentLocale = localeCode;
      _languageSelected = true;
    });
  }

  String _resolveRole(String email) {
    final clean = email.trim().toLowerCase();
    if (HellAppInfo.owners.contains(clean)) return 'OWNER';
    return 'CREATOR';
  }

  Future<void> _completeAndSaveAccount({
    required String name,
    required String email,
    String phone = '',
    required String pin,
    String? customRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = customRole ?? _resolveRole(email);

    await prefs.setString('hell_user_name', name.trim());
    await prefs.setString('hell_user_email', email.trim().toLowerCase());
    await prefs.setString('hell_user_phone', phone.trim());
    await prefs.setString('hell_user_pin', pin);
    await prefs.setString('hell_user_role', role);

    final session = HellUserSession(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: role,
      pin: pin,
    );

    setState(() {
      _savedUser = session;
      _unlocked = true;
      _errorMessage = '';
    });
    widget.onAuthenticated(session);
  }

  void _handleGoogleOneClick(String googleEmail, String googleName) {
    final cleanEmail = googleEmail.trim().toLowerCase();

    if (_savedUser != null && _savedUser!.email == cleanEmail) {
      setState(() {
        _unlocked = true;
        _errorMessage = '';
      });
      widget.onAuthenticated(_savedUser!);
      return;
    }

    setState(() {
      _tempName = googleName;
      _tempEmail = cleanEmail;
      _enteredPin = '';
      _errorMessage = '';
      _authMode = 'google_pin';
    });
  }

  void _onPinDigit(String digit, {required bool isCreating}) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      if (isCreating) {
        _completeAndSaveAccount(
          name: _tempName.isNotEmpty ? _tempName : _tempEmail.split('@').first,
          email: _tempEmail,
          phone: _phoneCtrl.text,
          pin: _enteredPin,
        );
      } else if (_savedUser != null) {
        if (_enteredPin == _savedUser!.pin) {
          setState(() => _unlocked = true);
          widget.onAuthenticated(_savedUser!);
        } else {
          setState(() {
            _enteredPin = '';
            _errorMessage = 'PIN incorreto. Tenta novamente.';
          });
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: HellTheme.bgDark,
        body: Center(
          child: CircularProgressIndicator(color: HellTheme.neonBlue),
        ),
      );
    }

    if (_savedUser != null && _unlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: HellTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: HellTheme.neonCard(),
                child: !_languageSelected
                    ? _buildLanguageOnboardingView()
                    : (_savedUser != null && _authMode == 'welcome')
                        ? _buildPinUnlockView()
                        : _buildAuthFlowView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOnboardingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HellBrandIcon(size: 64),
        const SizedBox(height: 14),
        const Text(
          HellAppInfo.appName,
          style: TextStyle(
            color: HellTheme.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          HellLocaleManager.t('choose_lang'),
          style: const TextStyle(color: HellTheme.neonBlue, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...HellLocaleManager.supportedLanguages.entries.map((entry) {
          final code = entry.key;
          final info = entry.value;
          final isSelected = HellLocaleManager.currentLocale == code;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: HellTheme.neonCard(isActiveGreen: isSelected, radius: 12),
            child: ListTile(
              dense: true,
              leading: Text(info['flag']!, style: const TextStyle(fontSize: 22)),
              title: Text(
                info['name']!,
                style: const TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: HellTheme.neonGreen)
                  : null,
              onTap: () => setState(() => HellLocaleManager.currentLocale = code),
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HellTheme.neonBlue,
              foregroundColor: HellTheme.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _selectLanguage(HellLocaleManager.currentLocale),
            child: Text(
              HellLocaleManager.t('continue_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinUnlockView() {
    final user = _savedUser!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HellBrandIcon(size: 58),
        const SizedBox(height: 12),
        Text(
          '${HellLocaleManager.t('welcome_back')}, ${user.name}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: HellTheme.textWhite,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.isOwner ? 'ACESSO DONO • LIBERDADE TOTAL' : user.email,
          style: TextStyle(
            color: user.isOwner ? HellTheme.neonGreen : HellTheme.neonBlue,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Digita o teu PIN de 4 dígitos (entra automaticamente)',
          textAlign: TextAlign.center,
          style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _buildPinDots(),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_errorMessage, style: const TextStyle(color: HellTheme.neonRed, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        _buildNumericKeypad(isCreating: false),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _languageSelected = false),
              child: const Text('Idioma 🌐', style: TextStyle(color: HellTheme.neonBlue, fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _savedUser = null;
                  _enteredPin = '';
                  _authMode = 'welcome';
                });
              },
              child: const Text(
                'Trocar de conta',
                style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthFlowView() {
    if (_authMode == 'google_pin') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, color: HellTheme.neonGreen, size: 44),
          const SizedBox(height: 10),
          const Text(
            'Conta Associada com Sucesso',
            style: TextStyle(color: HellTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$_tempName ($_tempEmail)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: HellTheme.neonBlue, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Define apenas um PIN de 4 dígitos para desbloqueio rápido:',
            textAlign: TextAlign.center,
            style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _buildPinDots(),
          const SizedBox(height: 18),
          _buildNumericKeypad(isCreating: true),
          TextButton(
            onPressed: () => setState(() => _authMode = 'welcome'),
            child: const Text('Voltar', style: TextStyle(color: HellTheme.textMuted)),
          ),
        ],
      );
    }

    if (_authMode == 'sms') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Entrada Rápida por SMS',
            style: TextStyle(color: HellTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: HellTheme.textWhite),
            decoration: const InputDecoration(
              labelText: 'Número de Telemóvel (+351...)',
              labelStyle: TextStyle(color: HellTheme.textMuted),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: HellTheme.neonBlue)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: HellTheme.neonGreen)),
            ),
          ),
          const SizedBox(height: 12),
          if (_smsSent) ...[
            TextField(
              controller: _smsCodeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: HellTheme.textWhite),
              decoration: const InputDecoration(
                labelText: 'Código SMS recebido (6 dígitos)',
                labelStyle: TextStyle(color: HellTheme.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: HellTheme.neonBlue)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HellTheme.neonBlue,
                foregroundColor: HellTheme.bgDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (!_smsSent) {
                  if (_phoneCtrl.text.trim().length < 9) {
                    setState(() => _errorMessage = 'Insere um número válido.');
                    return;
                  }
                  setState(() {
                    _smsSent = true;
                    _errorMessage = '';
                  });
                } else {
                  if (_smsCodeCtrl.text.trim().length < 4) {
                    setState(() => _errorMessage = 'Insere o código SMS.');
                    return;
                  }
                  _tempName = 'Criador ${_phoneCtrl.text.trim()}';
                  _tempEmail = '${_phoneCtrl.text.trim()}@sms.hellcreator.os';
                  _enteredPin = '';
                  setState(() => _authMode = 'google_pin');
                }
              },
              child: Text(
                _smsSent ? 'Validar Código SMS' : 'Enviar Código SMS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_errorMessage, style: const TextStyle(color: HellTheme.neonRed, fontSize: 12)),
          ],
