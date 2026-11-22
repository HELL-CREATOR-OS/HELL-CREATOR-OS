import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';

import 'app_data.dart';
import 'account_security.dart';
import 'platform_logos.dart';
import 'live_connectors.dart';
import 'actions_studio.dart';
import 'deck_and_community.dart';
import 'studio_screens.dart';
import 'music_and_social.dart';
import 'user_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalObsServer.start();
  runApp(const HellCreatorOsApp());
}

class HellCreatorOsApp extends StatefulWidget {
  const HellCreatorOsApp({super.key});
  @override
  State<HellCreatorOsApp> createState() => _HellCreatorOsAppState();
}

class _HellCreatorOsAppState extends State<HellCreatorOsApp> {
  String _themeMode = 'cyber';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _themeMode = prefs.getString('hell_theme') ?? 'cyber');
  }

  Future<void> _changeTheme(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_theme', t);
    if (!mounted) return;
    setState(() => _themeMode = t);
  }

  ThemeData _buildTheme() {
    Color primary = const Color(0xFF1E78FF);
    Color scaffoldBg = const Color(0xFF050B1E);
    Color cardBg = const Color(0xFF0A1433);
    if (_themeMode == 'emerald') {
      primary = const Color(0xFF10B981);
      scaffoldBg = const Color(0xFF031510);
      cardBg = const Color(0xFF07261D);
    } else if (_themeMode == 'gold') {
      primary = const Color(0xFFF59E0B);
      scaffoldBg = const Color(0xFF140D03);
      cardBg = const Color(0xFF241807);
    }
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(primary: primary, secondary: const Color(0xFF38BDF8), surface: cardBg),
      appBarTheme: AppBarTheme(backgroundColor: scaffoldBg, elevation: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => HellFeedbackEngine.triggerTap(),
      child: MaterialApp(
        title: 'HELL CREATOR OS',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        supportedLocales: const [Locale('pt', 'PT'), Locale('en', 'US'), Locale('es', 'ES')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SplashScreen(currentTheme: _themeMode, onThemeChanged: _changeTheme),
      ),
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
  late AnimationController _logoController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () async {
      try {
        final p = AudioPlayer();
        await p.setVolume(0.85);
        await p.play(AssetSource('sounds/hell_startup.wav'));
      } catch (_) {}
    });
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
    _scaleAnim = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    Timer(const Duration(milliseconds: 2200), () async {
      final saved = await UserAccountManager.getSavedUser();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AuthGateScreen(
            initialUser: saved,
            currentTheme: widget.currentTheme,
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040817),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFF1E78FF), Color(0xFF07112E)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.55), blurRadius: 45, spreadRadius: 6)],
                ),
                child: Image.asset('icon.png', width: 96, height: 96, errorBuilder: (_, __, ___) => const Icon(Icons.bolt, size: 78, color: Color(0xFF38BDF8))),
              ),
              const SizedBox(height: 20),
              const Text('HELL CREATOR OS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('4K HDR BROADCAST & STREAM DECK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: Color(0xFF38BDF8))),
            ],
          ),
        ),
      ),
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
    {'id': 'a1', 'trigger': 'follow', 'name': 'Novo Seguidor', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs['url'], 'sound': ''},
    {'id': 'a2', 'trigger': 'like500', 'name': 'Meta de Gostei na Live', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs['url'], 'sound': ''},
    {'id': 'a3', 'trigger': 'sub', 'name': 'Novo Subscritor', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs['url'], 'sound': ''},
    {'id': 'a4', 'trigger': 'share', 'name': 'Partilha da Live', 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs['url'], 'sound': ''},
  ];

  final List<Map<String, dynamic>> _goalsList = [
    {'id': 'm1', 'title': 'Meta de Gostei da Live', 'target': 5000, 'current': 1250, 'overlayType': 'tiktok_heart'},
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
        : (activeId == 'pt_m2' ? 0.72 : (isFemale ? 1.22 : 0.78));

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
