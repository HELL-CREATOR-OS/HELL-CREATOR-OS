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
      _showSnack('$platformName desligado (Estúdio OFF).');
      return;
    }
    final user = _channelCtrl.text.trim();
    if (user.isEmpty) {
      _openPlatformSetupDialog(platformId, platformName);
      return;
    }
    setState(() => _activePlatforms[platformId] = true);
    _liveConnector.connect(platform: platformId, channelUser: user, streamKey: _streamKeyCtrl.text.trim());
  }

  void _openPlatformSetupDialog(String platformId, String platformName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        title: Text('Configurar $platformName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _channelCtrl,
              decoration: InputDecoration(
                labelText: 'Nome do Canal / @Utilizador ($platformName)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _streamKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Stream Key (Opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedEncoder,
              decoration: const InputDecoration(labelText: 'Origem da Transmissão', border: OutlineInputBorder()),
              items: ['Direto no Telemóvel / Tablet', 'OBS Studio (PC)', 'TikTok Live Studio', 'Streamlabs Desktop']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedEncoder = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _saveSettings();
              if (!mounted) return;
              Navigator.pop(ctx);
              if (_channelCtrl.text.trim().isNotEmpty) {
                setState(() => _activePlatforms[platformId] = true);
                _liveConnector.connect(platform: platformId, channelUser: _channelCtrl.text.trim(), streamKey: _streamKeyCtrl.text.trim());
              }
            },
            child: const Text('Ligar & Transmitir'),
          ),
        ],
      ),
    );
  }

  void _openMenuItem(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildActiveScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeDashboard();
      case 1:
        return ControlCenterScreen(
          user: widget.user,
          onUserUpdated: widget.onUserUpdated,
          onLogout: widget.onLogout,
          activePlatforms: _activePlatforms,
          chatFeed: _chatFeed,
          syncCode: _syncCode,
          isSecondScreenPaired: _isSecondScreenPaired,
          onValidateSyncCode: (code) {
            if (code.trim().toUpperCase() == _syncCode) {
              setState(() => _isSecondScreenPaired = true);
              _showSnack('Segundo ecrã emparelhado com sucesso!');
            } else {
              _showSnack('Código inválido.');
            }
          },
        );
      case 2:
        return StreamDeckScreen(
          activePlatforms: _activePlatforms,
          onTogglePlatform: _handlePlatformTap,
          onTriggerSound: (url) async {
            if (_isMuted) return;
            await sfxAudioPlayer.stop();
            if (url.startsWith('http')) {
              await sfxAudioPlayer.play(UrlSource(url));
            } else {
              await sfxAudioPlayer.play(AssetSource(url));
            }
          },
          onSpeakTts: _speakRealVoice,
          syncCode: _syncCode,
          isPaired: _isSecondScreenPaired,
          onValidateSync: (c) => setState(() => _isSecondScreenPaired = c.trim().toUpperCase() == _syncCode),
        );
      case 3:
        return ActionsStudioScreen(
          alertsList: _alertsList,
          goalsList: _goalsList,
          sounds: _sounds,
          allGiftsEnabled: _allGiftsEnabled,
          onToggleAllGifts: (v) => setState(() => _allGiftsEnabled = v),
          onSpeakTts: _speakRealVoice,
          sfxPlayer: sfxAudioPlayer,
        );
      case 4:
        return ChatAndVoiceScreen(
          chatFeed: _chatFeed,
          ttsEnabled: _ttsEnabled,
          speechRate: _speechRate,
          voicePitch: _voicePitch,
          voiceVolume: _voiceVolume,
          onToggleTts: (v) {
            setState(() => _ttsEnabled = v);
            _saveSettings();
          },
          onChangedRate: (v) {
            setState(() => _speechRate = v);
            _saveSettings();
          },
          onChangedPitch: (v) {
            setState(() => _voicePitch = v);
            _saveSettings();
          },
          onChangedVolume: (v) {
            setState(() => _voiceVolume = v);
            _saveSettings();
          },
          onTestSpeak: _speakRealVoice,
          voiceRecorder: _voiceRecorder,
        );
      case 5:
        return MusicStudioScreen(bgPlayer: bgMusicPlayer);
      case 6:
        return ContentFactoryScreen(user: widget.user);
      case 7:
        return CommunityHubScreen(user: widget.user);
      case 8:
        return AiManagementScreen(user: widget.user);
      case 9:
        return InfoAndSettingsScreen(
          user: widget.user,
          onUserUpdated: widget.onUserUpdated,
          onLogout: widget.onLogout,
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
          appLang: _appLang,
          onLangChanged: (l) {
            setState(() => _appLang = l);
            _saveSettings();
          },
        );
      default:
        return _buildHomeDashboard();
    }
  }
  Widget _buildHomeDashboard() {
    final platforms = [
      {'id': 'tiktok', 'name': 'TikTok'},
      {'id': 'twitch', 'name': 'Twitch'},
      {'id': 'youtube', 'name': 'YouTube'},
      {'id': 'kick', 'name': 'Kick'},
    ];

    final menuItems = [
      {'idx': 1, 'title': 'Centro de Controlo', 'sub': 'Cockpit 4K · Chat · Mixer · Live', 'icon': Icons.dashboard_customize_rounded, 'color': const Color(0xFF38BDF8)},
      {'idx': 2, 'title': 'Stream Deck HELL', 'sub': 'Teclas Translúcidas · Ecrã Inteiro', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFF1E78FF)},
      {'idx': 3, 'title': 'Automações & Alertas', 'sub': 'Presentes · Doações · Metas · Regras', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFA855F7)},
      {'idx': 4, 'title': 'Chat & Voz Masculina', 'sub': 'TTS Real · Clonagem de Voz', 'icon': Icons.record_voice_over_rounded, 'color': const Color(0xFF10B981)},
      {'idx': 5, 'title': 'Música & Rádio 4K', 'sub': 'Faixas Offline · Sem Copyright', 'icon': Icons.music_note_rounded, 'color': const Color(0xFFF59E0B)},
      {'idx': 6, 'title': 'Fábrica de Conteúdos IA', 'sub': 'Clipes 9:16 · Editor · Engajamento', 'icon': Icons.movie_filter_rounded, 'color': const Color(0xFFF43F5E)},
      {'idx': 7, 'title': 'Comunidade & Globo NASA', 'sub': 'Mapa Global VIP · Marketplace', 'icon': Icons.public_rounded, 'color': const Color(0xFF06B6D4)},
      {'idx': 8, 'title': 'HELL Gestão IA', 'sub': 'Diretor Inteligente · Sugestões', 'icon': Icons.psychology_rounded, 'color': const Color(0xFF8B5CF6)},
      {'idx': 9, 'title': 'Informações & Definições', 'sub': 'Ecrã & Toque · Temas · Conta', 'icon': Icons.settings_rounded, 'color': const Color(0xFF94A3B8)},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isWide = w >= 650;
        final cols = w >= 1024 ? 3 : (w >= 650 ? 2 : 1);

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
          padding: EdgeInsets.all(isWide ? 18 : 14),
          children: [
            deckPanel,
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menuItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 82,
              ),
              itemBuilder: (_, i) {
                final m = menuItems[i];
                final c = m['color'] as Color;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openMenuItem(m['idx'] as int),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF13275E), Color(0xFF0A1433), Color(0xFF050B1E)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.withOpacity(0.55), width: 1.3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.75), blurRadius: 14, offset: const Offset(0, 6)),
                        BoxShadow(color: c.withOpacity(0.18), blurRadius: 16),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.withOpacity(0.5)),
                          ),
                          child: Icon(m['icon'] as IconData, color: c, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(m['title'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(m['sub'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white60), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activePlatforms.values.where((v) => v).length;
    return Scaffold(
      appBar: AppBar(
        leading: _selectedIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF38BDF8)),
                onPressed: () => setState(() => _selectedIndex = 0),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: Color(0xFF38BDF8))),
              ),
        title: Text(
          _selectedIndex == 0 ? 'HELL CREATOR OS' : 'VOLTAR AO MENU PRINCIPAL',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.1),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: activeCount > 0 ? Colors.greenAccent.withOpacity(0.18) : Colors.redAccent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: activeCount > 0 ? Colors.greenAccent : Colors.redAccent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, size: 9, color: activeCount > 0 ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 5),
                Text(
                  activeCount > 0 ? 'NO AR' : 'ESTÚDIO OFF',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: activeCount > 0 ? Colors.greenAccent : Colors.redAccent),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: _isMuted ? Colors.redAccent : const Color(0xFF38BDF8)),
            tooltip: _isMuted ? 'Ativar Sons' : 'Silenciar Tudo',
            onPressed: _toggleMuteState,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
            tooltip: 'Perfil & VIP',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    user: widget.user,
                    onUserUpdated: widget.onUserUpdated,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildActiveScreen(),
    );
  }
}
