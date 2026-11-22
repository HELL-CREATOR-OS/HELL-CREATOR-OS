import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'user_profile_screen.dart';


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
            locale: const Locale('pt', 'PT'),
      supportedLocales: const [
        Locale('pt', 'PT'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideTitleAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.45, curve: Curves.easeIn)),
    );
    _slideTitleAnim = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.25, 0.70, curve: Curves.easeOutCubic)),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.20, 1.0, curve: Curves.easeInOut)),
    );

    _logoController.forward();

    Timer(const Duration(milliseconds: 2700), () async {
      if (!mounted) return;
      final savedUser = await UserAccountManager.getSavedUser();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 550),
          pageBuilder: (_, __, ___) => AuthGateScreen(
            initialUser: savedUser,
            currentTheme: widget.currentTheme,
            onThemeChanged: widget.onThemeChanged,
          ),
          transitionsBuilder: (_, anim, __, child) {
            final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim);
            return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: child));
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.05,
            colors: [Color(0xFF132E73), Color(0xFF07112E), Color(0xFF040817)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.22 + (_pulseController.value * 0.28)),
                          blurRadius: 28 + (_pulseController.value * 16),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Image.asset(
                    'icon.png',
                    height: 128,
                    errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 100, color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SlideTransition(
                position: _slideTitleAnim,
                child: const Column(
                  children: [
                    Text('HELL', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 6, color: Colors.white, height: 1.0)),
                    SizedBox(height: 4),
                    Text('CREATOR OS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 4.5, color: Color(0xFF38BDF8))),
                    SizedBox(height: 14),
                    Text('UM CRIADOR · VÁRIAS PLATAFORMAS · CONTROLO TOTAL', style: TextStyle(fontSize: 10.5, letterSpacing: 1.3, color: Color(0xFF7DD3FC))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 190,
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressAnim.value,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                ),
              ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13275E), Color(0xFF0A1433), Color(0xFF050B1E)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF1E78FF).withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: 0.5,
          ),
        ],
      );

  Widget _menuTile(IconData icon, String title, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        decoration: _neonCard(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.white.withOpacity(0.55), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF38BDF8).withOpacity(0.12),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1E78FF), Color(0xFF0284C7)]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ],
          ),
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

    final menuItems = [
      _menuTile(Icons.dashboard_customize_outlined, 'Centro de Controlo', () => setState(() => _selectedIndex = 1), badge: 'LIVE & PAINEL'),
      _menuTile(Icons.grid_view_rounded, 'Stream Deck HELL', () => setState(() => _selectedIndex = 2), badge: _isSecondScreenPaired ? 'SYNC ON' : 'EMPARELHAR'),
      _menuTile(Icons.bolt_outlined, 'Automações', () => setState(() => _selectedIndex = 3), badge: 'AÇÕES & REGRAS'),
      _menuTile(Icons.record_voice_over_outlined, 'Chat e Voz TTS', () => setState(() => _selectedIndex = 4), badge: 'VOZES & CHAT'),
      _menuTile(Icons.music_note_outlined, 'Música', () => setState(() => _selectedIndex = 5), badge: 'PLAYER'),
      _menuTile(Icons.movie_filter_outlined, 'Fábrica de Conteúdos', () => setState(() => _selectedIndex = 6), badge: 'CLIPES 9:16'),
      _menuTile(Icons.public, 'Comunidade', () => setState(() => _selectedIndex = 7), badge: 'GLOBO & CHAT'),
      _menuTile(Icons.extension_outlined, 'Marketplace', () => setState(() => _selectedIndex = 8), badge: 'LOJA & PACKS'),
      _menuTile(Icons.psychology_outlined, 'Gestão IA', () => setState(() => _selectedIndex = 9), badge: 'DIRETOR & NEGÓCIO'),
      _menuTile(Icons.info_outline, 'Informações', () => setState(() => _selectedIndex = 10), badge: 'GUIA & FAQ'),
      _menuTile(Icons.settings_outlined, 'Configurações', () => setState(() => _selectedIndex = 11)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final cols = constraints.maxWidth >= 1050 ? 3 : (isWide ? 2 : 1);

           final deckCard = Container(
          padding: EdgeInsets.fromLTRB(isWide ? 18 : 12, 10, isWide ? 18 : 12, isWide ? 14 : 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10204D), Color(0xFF070E24), Color(0xFF030712)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.55), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 18, offset: const Offset(0, 8)),
              BoxShadow(color: const Color(0xFF1E78FF).withOpacity(0.22), blurRadius: 20, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF04091A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'MULTIPLATAFORMAS · TRANSMISSÃO DIRETA',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: Color(0xFF7DD3FC)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF030714),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.12), blurRadius: 8),
                  ],
                ),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: isWide ? 14 : 8,
                  mainAxisSpacing: isWide ? 14 : 8,
                  childAspectRatio: isWide ? 2.4 : 0.84,
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
              ),
            ],
          ),
        );

        final deckPanel = isWide
            ? SizedBox(width: double.infinity, child: deckCard)
            : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: deckCard));


        return ListView(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 14, 14, isWide ? 24 : 14, 28),
          children: [
            deckPanel,
            const SizedBox(height: 18),
            if (cols == 1)
              ...menuItems
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menuItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 4,
                  mainAxisExtent: 74,
                ),
                itemBuilder: (_, i) => menuItems[i],
              ),
          ],
        );
      },
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
      'Centro de Controlo',
            'Stream Deck HELL',
      'Automações',
      'Chat e Voz TTS',
      'Música',
      'Fábrica de Conteúdos',
      'Comunidade',
      'Marketplace',
      'Gestão IA',
      'Informações',
      'Configurações',
    ];

        final screens = [
      _buildHomeTab(),
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
            _showSnack('Aparelho Sincronizado! Streamdeck HELL ativo.');
          }
        },
      ),
      const SizedBox(),
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
      MusicBackgroundScreen(bgPlayer: bgMusicPlayer),
      const ContentFactoryScreen(),
      DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF38BDF8),
              labelColor: Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white54,
              tabs: [Tab(text: 'Globo 3D Real'), Tab(text: 'Comunidade & Chat')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                                                CommunityGlobeScreen(serverUrl: 'http://127.0.0.1:8080', isOwner: isOwner),
               CommunitySocialScreen(serverUrl: 'http://127.0.0.1:8080', currentUser: widget.user),

                ],
              ),
            ),
          ],
        ),
      ),
      MarketplacePublicScreen(hasFreeOwnerOrStaffAccess: isOwner),
      DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF38BDF8),
              labelColor: Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'AI Diretor Stream'),
                Tab(text: 'Crescimento'),
                Tab(text: 'Gestão de Negócio'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const SmartBrainScreen(),
                  const GrowthAnalyticsScreen(),
                  CreatorBusinessScreen(isOwner: isOwner),
                ],
              ),
            ),
          ],
        ),
      ),
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
      child: _selectedIndex == 2
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
            ? TopLeftProfileAvatarButton(
                user: widget.user,
                onUserUpdated: (updated) {
                  setState(() {
                    widget.user.clear();
                    widget.user.addAll(updated);
                  });
                },
                onAccountDeletedOrSuspended: () {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              )
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedIndex = 0)),
                            title: _selectedIndex == 0
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('HELL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 4.5, color: Colors.white, height: 1.0)),
                            const Text('CREATOR OS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 3.2, color: Color(0xFF38BDF8), height: 1.15)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A1433),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35), width: 0.8),
                              ),
                              child: const Text(
                                'UM CRIADOR • VÁRIAS PLATAFORMAS • CONTROLO TOTAL',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 8.0, letterSpacing: 1.0, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        titles[_selectedIndex],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                      ),

                      actions: [
          IconButton(
            tooltip: 'Terminar Sessão (Logout)',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await UserAccountManager.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
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
                 
                ],
              ),
            ),
    );
  }
}
