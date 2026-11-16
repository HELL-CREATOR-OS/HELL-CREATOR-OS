import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app_data.dart';
import 'studio_screens.dart';
import 'deck_and_community.dart';
import 'platform_logos.dart';
import 'account_security.dart';
import 'music_and_social.dart';
import 'actions_studio.dart';
import 'live_connectors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  LocalObsServer.start();
  runApp(const HellCreatorOsApp());
}

class HellCreatorOsApp extends StatefulWidget {
  const HellCreatorOsApp({super.key});
  @override
  State<HellCreatorOsApp> createState() => _HellCreatorOsAppState();
}

class _HellCreatorOsAppState extends State<HellCreatorOsApp> {
  String _themeMode = 'azul';
  void _changeTheme(String mode) => setState(() => _themeMode = mode);

  ThemeData _buildTheme() {
    if (_themeMode == 'claro') {
      return ThemeData.light().copyWith(
        primaryColor: const Color(0xFF1D6CE0),
        colorScheme: const ColorScheme.light(primary: Color(0xFF1D6CE0), secondary: Color(0xFF38BDF8)),
      );
    } else if (_themeMode == 'escuro') {
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090E),
        cardColor: const Color(0xFF10131C),
        primaryColor: const Color(0xFF2563EB),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF07090E), elevation: 0),
      );
    }
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF050B1E),
      cardColor: const Color(0xFF0B1636),
      primaryColor: const Color(0xFF1E78FF),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF050B1E), elevation: 0),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF1E78FF), secondary: Color(0xFF38BDF8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HELL CREATOR OS',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: SplashScreen(currentTheme: _themeMode, onThemeChanged: _changeTheme),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String currentTheme;
  final Function(String) onThemeChanged;
  const SplashScreen({super.key, required this.currentTheme, required this.onThemeChanged});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

    Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      final savedUser = await UserAccountManager.getSavedUser();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => AuthGateScreen(
            initialUser: savedUser,
            currentTheme: widget.currentTheme,
            onThemeChanged: widget.onThemeChanged,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.15), radius: 1.0, colors: [Color(0xFF132E73), Color(0xFF07112E), Color(0xFF040817)]),
        ),
        child: FadeTransition(
          opacity: _controller,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('icon.png', height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 95, color: Color(0xFF38BDF8))),
              const SizedBox(height: 18),
              const Text('HELL', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white, height: 1.0)),
              const Text('CREATOR OS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 4, color: Color(0xFF38BDF8))),
              const SizedBox(height: 14),
              const Text('UM CRIADOR · VÁRIAS PLATAFORMAS · CONTROLO TOTAL', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Color(0xFF7DD3FC))),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGateScreen extends StatefulWidget {
  final Map<String, dynamic>? initialUser;
  final String currentTheme;
  final Function(String) onThemeChanged;

  const AuthGateScreen({super.key, required this.initialUser, required this.currentTheme, required this.onThemeChanged});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  Map<String, dynamic>? _user;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    final methods = _user?['securityMethods'];
    if (_user != null && (methods == null || (methods is List && methods.isEmpty))) {
      _unlocked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return AuthScreen(
        onAuthenticated: (u) => setState(() {
          _user = u;
          _unlocked = true;
        }),
      );
    }

    if (!_unlocked) {
      return AppLockScreen(
        user: _user!,
        onUnlocked: () => setState(() => _unlocked = true),
        onLogout: () async {
          await UserAccountManager.logout();
          setState(() {
            _user = null;
            _unlocked = false;
          });
        },
      );
    }

    return MainShell(
      user: _user!,
      onUserUpdated: (updated) => setState(() => _user = updated),
      onLogout: () async {
        await UserAccountManager.logout();
        setState(() {
          _user = null;
          _unlocked = false;
        });
      },
      currentTheme: widget.currentTheme,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}
class MainShell extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onLogout;
  final String currentTheme;
  final Function(String) onThemeChanged;

  const MainShell({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String _appLang = 'pt';
  late IO.Socket socket;
  late LivePlatformConnector _liveConnector;

  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer sfxAudioPlayer = AudioPlayer();
  final AudioPlayer bgMusicPlayer = AudioPlayer();
  final AudioRecorder _voiceRecorder = AudioRecorder();

  final TextEditingController _channelCtrl = TextEditingController();
  final TextEditingController _streamKeyCtrl = TextEditingController();
  final Map<String, bool> _activePlatforms = {
    'tiktok': false,
    'twitch': false,
    'youtube': false,
    'kick': false,
  };
  String _selectedPlatform = 'tiktok';
  String _selectedEncoder = 'Direto no Telemóvel / Tablet';
  bool _isMuted = false;

  bool _ttsEnabled = true;
  double _speechRate = 0.50;
  double _voicePitch = 0.85;
  double _voiceVolume = 1.0;

  bool _allGiftsEnabled = true;
  late String _syncCode;
  bool _isSecondScreenPaired = false;
  int _sponsorIndex = 0;
  Timer? _sponsorTimer;

  final List<Map<String, dynamic>> _alertsList = [
    {'id': 'a1', 'trigger': 'follow', 'name': 'Novo Seguidor', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs[0]['url']!, 'sound': ''},
    {'id': 'a2', 'trigger': 'like500', 'name': 'Meta de Gostos da Live', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs[1]['url']!, 'sound': ''},
    {'id': 'a3', 'trigger': 'sub', 'name': 'Novo Subscritor', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs[2]['url']!, 'sound': ''},
    {'id': 'a4', 'trigger': 'share', 'name': 'Partilha da Live', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs[3]['url']!, 'sound': ''},
  ];

  final List<Map<String, dynamic>> _goalsList = [
    {'id': 'm1', 'title': 'Meta de Gostos da Live', 'target': 5000, 'current': 1250, 'overlayType': 'tiktok_heart'},
    {'id': 'm2', 'title': 'Novos Seguidores Hoje', 'target': 100, 'current': 42, 'overlayType': 'tikfinity_neon'},
  ];

  final List<Map<String, String>> _chatFeed = [];
  List<Map<String, String>> _sounds = [];

  @override
  void initState() {
    super.initState();
    _syncCode = 'HELL-${100000 + Random().nextInt(900000)}';
    _sounds = List<Map<String, String>>.from(DefaultMediaLibrary.builtInSounds);
    MusicDeckController.sharedPlayer = bgMusicPlayer;
    _loadSettings();
    _initConnectors();
    _sponsorTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && SponsorBannerManager.activeSponsors.isNotEmpty) {
        setState(() => _sponsorIndex = (_sponsorIndex + 1) % SponsorBannerManager.activeSponsors.length);
      }
    });
  }

  @override
  void dispose() {
    _sponsorTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _channelCtrl.text = prefs.getString('channel_user') ?? '';
      _appLang = prefs.getString('app_lang') ?? 'pt';
      _ttsEnabled = prefs.getBool('tts_enabled') ?? true;
      _speechRate = prefs.getDouble('tts_rate') ?? 0.50;
      _voicePitch = prefs.getDouble('tts_pitch') ?? 0.85;
      _voiceVolume = prefs.getDouble('tts_volume') ?? 1.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('channel_user', _channelCtrl.text.trim());
    await prefs.setString('app_lang', _appLang);
    await prefs.setBool('tts_enabled', _ttsEnabled);
    await prefs.setDouble('tts_rate', _speechRate);
    await prefs.setDouble('tts_pitch', _voicePitch);
    await prefs.setDouble('tts_volume', _voiceVolume);
  }

  Future<void> _speakRealVoice(String text) async {
    if (_isMuted || text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString('hell_active_voice_id') ?? 'pt_m1';
    final isFemale = activeId.startsWith('pt_f');
    final pitchVal = activeId == 'pt_m3'
        ? 0.55
        : (activeId == 'pt_m2' ? 0.72 : (isFemale ? 1.22 : 0.85));

    try {
      await flutterTts.stop();
      if (Platform.isAndroid) await flutterTts.setEngine('com.google.android.tts');
      await flutterTts.setLanguage(_appLang == 'en' ? 'en-US' : (_appLang == 'es' ? 'es-ES' : 'pt-PT'));
      await flutterTts.setPitch(pitchVal);
      await flutterTts.setSpeechRate(_speechRate);
      await flutterTts.setVolume(_voiceVolume);
      await flutterTts.speak(text);
    } catch (_) {}
  }

  void _initConnectors() {
    socket = IO.io('http://${LocalObsServer.localIp}:${LocalObsServer.port}', IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    _liveConnector = LivePlatformConnector(
      onStatusChanged: (connected, statusMsg) {
        if (!mounted) return;
        setState(() => _activePlatforms[_selectedPlatform] = connected);
        _showSnack(statusMsg);
      },
      onLiveEvent: (event) {
        if (!mounted) return;
        final user = (event['user'] ?? 'Espectador').toString();
        final msg = (event['message'] ?? '').toString();
        setState(() {
          _chatFeed.insert(0, {'user': user, 'msg': msg, 'type': (event['type'] ?? 'chat').toString()});
          if (_chatFeed.length > 50) _chatFeed.removeLast();
        });
        if (!_isMuted && _ttsEnabled && msg.isNotEmpty) {
          _speakRealVoice('$user diz: $msg');
        }
      },
    );
  }

  Future<void> _toggleMuteState() async {
    setState(() => _isMuted = !_isMuted);
    if (_isMuted) {
      await sfxAudioPlayer.stop();
      await bgMusicPlayer.pause();
      await flutterTts.stop();
      _showSnack('Todos os sons e alertas foram silenciados.');
    } else {
      _showSnack('Sons e alertas ativos.');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }
  void _handlePlatformTap(String platformId, String platformName) {
    setState(() => _selectedPlatform = platformId);
    final isCurrentlyOn = _activePlatforms[platformId] == true;

    if (isCurrentlyOn) {
      setState(() => _activePlatforms[platformId] = false);
      _liveConnector.disconnect();
      _showSnack('$platformName desligado (OFF).');
      return;
    }

    if (_channelCtrl.text.trim().isNotEmpty) {
      setState(() => _activePlatforms[platformId] = true);
      _liveConnector.connect(platformId, _channelCtrl.text.trim());
      return;
    }

    _openPlatformSetupDialog(platformId, platformName);
  }

  void _openPlatformSetupDialog(String platformId, String platformName) {
    final isTikTok = platformId == 'tiktok';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
          title: Row(
            children: [
              PlatformBrandLogo(platform: platformId, size: 28),
              const SizedBox(width: 12),
              Text('Configurar $platformName', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _channelCtrl,
                  decoration: InputDecoration(labelText: 'Utilizador / Canal ($platformName)', prefixIcon: const Icon(Icons.alternate_email), border: const OutlineInputBorder()),
                ),
                if (!isTikTok) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedEncoder,
                    dropdownColor: const Color(0xFF0B1636),
                    decoration: const InputDecoration(labelText: 'Modo de Transmissão', isDense: true, border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Direto no Telemóvel / Tablet', child: Text('Direto no Telemóvel / Tablet (RTMP)')),
                      DropdownMenuItem(value: 'OBS Studio / PC', child: Text('OBS Studio / PC')),
                    ],
                    onChanged: (v) => setDialogState(() => _selectedEncoder = v ?? 'Direto no Telemóvel / Tablet'),
                  ),
                  if (_selectedEncoder == 'Direto no Telemóvel / Tablet') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _streamKeyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Stream Key (Chave RTMP)', isDense: true, border: OutlineInputBorder()),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
              onPressed: () async {
                await _saveSettings();
                final user = _channelCtrl.text.trim();
                if (user.isNotEmpty) {
                  setState(() => _activePlatforms[platformId] = true);
                  await _liveConnector.connect(platformId, user);
                }
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Ligar Agora (ON)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _neonCard() => BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E429F), width: 1.2),
      );

  Widget _menuTile(IconData icon, String title, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _neonCard(),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1E78FF), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final platforms = [
      {'id': 'tiktok', 'name': 'TikTok'},
      {'id': 'twitch', 'name': 'Twitch'},
      {'id': 'youtube', 'name': 'YouTube'},
      {'id': 'kick', 'name': 'Kick'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.86,
          children: platforms.map((p) {
            final id = p['id']!;
            final name = p['name']!;
            return PlatformGlassTile(
              platform: id,
              label: name,
              isActive: _activePlatforms[id] == true,
              onTap: () => _handlePlatformTap(id, name),
              onLongPress: () => _openPlatformSetupDialog(id, name),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _menuTile(Icons.bolt_outlined, '1. ${AppTranslations.t(_appLang, 'automations')}', () => setState(() => _selectedIndex = 1), badge: 'AÇÕES & REGRAS'),
        _menuTile(Icons.dashboard_customize_outlined, '2. ${AppTranslations.t(_appLang, 'control_center')}', () => setState(() => _selectedIndex = 2), badge: 'LIVE & PERFIL'),
        _menuTile(Icons.record_voice_over_outlined, '3. ${AppTranslations.t(_appLang, 'hell_voice')}', () => setState(() => _selectedIndex = 3), badge: '6 VOZES PT'),
        _menuTile(Icons.sports_esports_outlined, '4. ${AppTranslations.t(_appLang, 'game_mode')}', () => setState(() => _selectedIndex = 4), badge: 'AUTO'),
        _menuTile(Icons.grid_view_rounded, '5. ${AppTranslations.t(_appLang, 'second_screen')}', () => setState(() => _selectedIndex = 5), badge: _isSecondScreenPaired ? 'SYNC ON' : 'QR SYNC'),
        _menuTile(Icons.music_note_outlined, '6. ${AppTranslations.t(_appLang, 'music')}', () => setState(() => _selectedIndex = 6), badge: 'PLAYER'),
        _menuTile(Icons.psychology_outlined, '7. ${AppTranslations.t(_appLang, 'smart_brain')}', () => setState(() => _selectedIndex = 7), badge: 'DIRECTOR IA'),
        _menuTile(Icons.movie_filter_outlined, '8. ${AppTranslations.t(_appLang, 'content_factory')}', () => setState(() => _selectedIndex = 8), badge: 'CLIPS 9:16'),
        _menuTile(Icons.public, '9. ${AppTranslations.t(_appLang, 'community')}', () => setState(() => _selectedIndex = 9), badge: 'GLOBO 3D'),
        _menuTile(Icons.trending_up_rounded, '10. ${AppTranslations.t(_appLang, 'growth')}', () => setState(() => _selectedIndex = 10), badge: 'GRÁFICOS'),
        _menuTile(Icons.business_center_outlined, '11. ${AppTranslations.t(_appLang, 'business')}', () => setState(() => _selectedIndex = 11), badge: 'FINANÇAS & ADS'),
        _menuTile(Icons.extension_outlined, '12. ${AppTranslations.t(_appLang, 'plugins_market')}', () => setState(() => _selectedIndex = 12), badge: 'LOJA & PLANOS'),
        _menuTile(Icons.info_outline, '13. ${AppTranslations.t(_appLang, 'info_hub')}', () => setState(() => _selectedIndex = 13), badge: 'ROBÔ H & FAQ'),
        _menuTile(Icons.settings_outlined, '14. ${AppTranslations.t(_appLang, 'settings')}', () => setState(() => _selectedIndex = 14)),
      ],
    );
  }

  Widget _buildGameModeScreen() {
    final isSingleDevice = !_isSecondScreenPaired;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎮 HELL Modo de Jogo (Deteção Automática)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              Text(
                isSingleDevice
                    ? '• Equipamento detetado: Aparelho Único.\n• Ao minimizar a app para jogar, o Modo Invisível entra automaticamente sem janelas no ecrã — apenas voz HELL VOICE e alertas nos auriculares.'
                    : '• Equipamento detetado: 2 Aparelhos Sincronizados.\n• Este ecrã permanece limpo para o jogo enquanto o 2.º aparelho controla o Stream Deck Pro.',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Volume Independente da Voz:', style: TextStyle(fontSize: 12.5)),
                  Expanded(
                    child: Slider(
                                            value: _voiceVolume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() => _voiceVolume = v);
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Idioma da Aplicação', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _appLang,
                dropdownColor: const Color(0xFF0B1636),
                items: const [
                  DropdownMenuItem(value: 'pt', child: Text('Português (Portugal)')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                ],
                onChanged: (v) async {
                  if (v != null) {
                    setState(() => _appLang = v);
                    await _saveSettings();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(left: 12, top: 4, bottom: 4), child: Text('Tema Visual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              RadioListTile<String>(activeColor: const Color(0xFF38BDF8), title: const Text('Azul Néon (Padrão)'), value: 'azul', groupValue: widget.currentTheme, onChanged: (v) => widget.onThemeChanged(v!)),
              RadioListTile<String>(activeColor: const Color(0xFF38BDF8), title: const Text('Escuro Profundo'), value: 'escuro', groupValue: widget.currentTheme, onChanged: (v) => widget.onThemeChanged(v!)),
              RadioListTile<String>(activeColor: const Color(0xFF38BDF8), title: const Text('Claro'), value: 'claro', groupValue: widget.currentTheme, onChanged: (v) => widget.onThemeChanged(v!)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = UserAccountManager.isOwnerEmail(widget.user['email']);
    final titles = [
      '',
      AppTranslations.t(_appLang, 'automations'),
      AppTranslations.t(_appLang, 'control_center'),
      AppTranslations.t(_appLang, 'hell_voice'),
      AppTranslations.t(_appLang, 'game_mode'),
      AppTranslations.t(_appLang, 'second_screen'),
      AppTranslations.t(_appLang, 'music'),
      AppTranslations.t(_appLang, 'smart_brain'),
      AppTranslations.t(_appLang, 'content_factory'),
      AppTranslations.t(_appLang, 'community'),
      AppTranslations.t(_appLang, 'growth'),
      AppTranslations.t(_appLang, 'business'),
      AppTranslations.t(_appLang, 'plugins_market'),
      AppTranslations.t(_appLang, 'info_hub'),
      AppTranslations.t(_appLang, 'settings'),
    ];

    final screens = [
      _buildHomeTab(),
      ActionsStudioTab(
        alertsList: _alertsList,
        goalsList: _goalsList,
        sounds: _sounds,
        sfxPlayer: sfxAudioPlayer,
        voiceRecorder: _voiceRecorder,
        allGiftsEnabled: _allGiftsEnabled,
        onToggleAllGifts: (v) => setState(() => _allGiftsEnabled = v),
        onSpeakVoice: (txt) => _speakRealVoice(txt),
        onStateChanged: () => setState(() {}),
      ),
      ControlCenterScreen(
        user: widget.user,
        onUserUpdated: widget.onUserUpdated,
        onLogout: widget.onLogout,
        activePlatforms: _activePlatforms,
        chatFeed: _chatFeed,
        syncCode: _syncCode,
        isSecondScreenPaired: _isSecondScreenPaired,
        onValidateSyncCode: (code) {
          if (code.isNotEmpty) {
            setState(() => _isSecondScreenPaired = true);
            _showSnack('2.º Aparelho Sincronizado! Stream Deck Pro ativo.');
          }
        },
      ),
      ChatTtsRepositoryScreen(
        ttsEnabled: _ttsEnabled,
        speechRate: _speechRate,
        pitch: _voicePitch,
        volume: _voiceVolume,
        onToggleTts: (v) {
          setState(() => _ttsEnabled = v);
          _saveSettings();
        },
        onParamsChanged: (r, p, vol) {
          setState(() {
            _speechRate = r;
            _voicePitch = p;
            _voiceVolume = vol;
          });
          _saveSettings();
        },
        onTestVoice: (sample) => _speakRealVoice(sample),
      ),
      _buildGameModeScreen(),
      const SizedBox(),
      MusicBackgroundScreen(bgPlayer: bgMusicPlayer),
      const SmartBrainScreen(),
      const ContentFactoryScreen(),
      DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF38BDF8),
              labelColor: Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white54,
              tabs: [Tab(text: '🌍 Globo 3D Real'), Tab(text: '👥 Comunidade & Chat')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CommunityGlobeScreen(serverUrl: 'http://${LocalObsServer.localIp}:${LocalObsServer.port}', isOwner: isOwner),
                  CommunitySocialScreen(serverUrl: 'http://${LocalObsServer.localIp}:${LocalObsServer.port}', currentUser: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
      const GrowthAnalyticsScreen(),
      CreatorBusinessScreen(isOwner: isOwner),
      MarketplacePublicScreen(hasFreeOwnerOrStaffAccess: isOwner),
      const HellInfoHubScreen(),
      _buildSettingsTab(),
    ];

    final sponsor = SponsorBannerManager.activeSponsors.isNotEmpty
        ? SponsorBannerManager.activeSponsors[_sponsorIndex % SponsorBannerManager.activeSponsors.length]
        : null;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: _selectedIndex == 5
          ? StreamDeckScreen(
              socket: socket,
              activeRoom: _channelCtrl.text.trim(),
              generatedCode: _syncCode,
              pairedRoom: _isSecondScreenPaired ? _syncCode : null,
              isMuted: _isMuted,
              onToggleMute: _toggleMuteState,
              onGenerateCode: () {},
              onJoinWithCode: (code) => setState(() => _isSecondScreenPaired = code.isNotEmpty),
              onSendCommand: (cmd, val) async {
                if (cmd == 'music_toggle') await MusicDeckController.togglePlayPause();
                if (cmd == 'music_next') await MusicDeckController.nextTrack();
                if (cmd == 'sound_clap' && !_isMuted) await sfxAudioPlayer.play(UrlSource(DefaultMediaLibrary.onlineSoundsRepository.first['url']!));
                if (cmd == 'sound_horn' && !_isMuted) await sfxAudioPlayer.play(UrlSource(DefaultMediaLibrary.onlineSoundsRepository.last['url']!));
              },
              onMinimizeDeck: () => setState(() => _selectedIndex = 0),
            )
          : Scaffold(
              appBar: AppBar(
                centerTitle: true,
                leading: _selectedIndex == 0
                    ? GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 2),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: UserAccountManager.buildUserAvatar(widget.user, radius: 17),
                        ),
                      )
                    : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedIndex = 0)),
                title: _selectedIndex == 0
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('HELL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 4, color: Colors.white, height: 1.0)),
                          Text('CREATOR OS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 3, color: Color(0xFF38BDF8))),
                        ],
                      )
                    : Text(titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: _toggleMuteState,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _isMuted ? Colors.redAccent : Colors.green, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              body: screens[_selectedIndex],
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sponsor != null)
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(sponsor['url']!), mode: LaunchMode.externalApplication),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1636),
                          border: Border(top: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.35))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_outlined, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                sponsor['title']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
                    child: const Text(
                      'UM CRIADOR · VÁRIAS PLATAFORMAS · CONTROLO TOTAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: Color(0xFF7DD3FC), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

