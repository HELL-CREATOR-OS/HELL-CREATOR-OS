import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';
import 'account_security.dart';
import 'platform_logos.dart';
import 'live_connectors.dart';
import 'actions_studio.dart';
import 'deck_and_community.dart';
import 'studio_screens.dart';
import 'music_and_social.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HellCreatorOsApp());
}

class HellCreatorOsApp extends StatelessWidget {
  const HellCreatorOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: HellAppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: HellTheme.bgDark,
        primaryColor: HellTheme.neonBlue,
        colorScheme: const ColorScheme.dark(
          primary: HellTheme.neonBlue,
          secondary: HellTheme.neonGreen,
          surface: HellTheme.cardDark,
        ),
      ),
      home: const _StartupConnectivityGate(),
    );
  }
}

class _StartupConnectivityGate extends StatefulWidget {
  const _StartupConnectivityGate();

  @override
  State<_StartupConnectivityGate> createState() => _StartupConnectivityGateState();
}

class _StartupConnectivityGateState extends State<_StartupConnectivityGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _ready = false;
  String _statusText = 'A inicializar HELL CREATOR OS...';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    await Future.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => _statusText = 'A sincronizar nódulos multiplataforma...');
    await Future.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => _statusText = 'HELL VOICE PT-PT pronto.');
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return AccountSecurityGate(
        onAuthenticated: (_) {},
        child: const HellCreatorHomeShell(),
      );
    }

    return Scaffold(
      backgroundColor: HellTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Transform.scale(
                  scale: 0.96 + (_pulseCtrl.value * 0.08),
                  child: const HellBrandIcon(size: 86),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              HellAppInfo.appName,
              style: TextStyle(
                color: HellTheme.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              HellAppInfo.slogan,
              style: TextStyle(color: HellTheme.neonBlue, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Text(
              _statusText,
              style: const TextStyle(color: HellTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class HellCreatorHomeShell extends StatefulWidget {
  const HellCreatorHomeShell({super.key});

  @override
  State<HellCreatorHomeShell> createState() => _HellCreatorHomeShellState();
}

class _HellCreatorHomeShellState extends State<HellCreatorHomeShell> {
  int _currentTab = 0;
  bool _gamingModeInvisible = false;
  bool _voiceMuted = false;
  bool _lowResourceMode = false;

  final FlutterTts _tts = FlutterTts();
  final HellLiveConnectorsManager _connectors = HellLiveConnectorsManager();
  List<Map<String, String>> _ptVoices = [];
  String? _selectedVoiceName;
  String _voiceProfile = 'Gaming';
  final List<String> _voiceQueue = [];
  bool _isSpeaking = false;

  bool _isRecordingClone = false;
  int _cloneSecondsElapsed = 0;
  Timer? _cloneTimer;
  bool _hasClonedVoice = false;

  HellUserSession _user = const HellUserSession(
    name: 'Criador HELL',
    email: 'hellcreatoros@gmail.com',
    role: 'OWNER',
    pin: '0000',
  );

  final List<PlatformAccountConfig> _platforms = [
    PlatformAccountConfig(id: 'tiktok', name: 'TikTok', brandColor: const Color(0xFF00F2FE), emblemIcon: Icons.music_note),
    PlatformAccountConfig(id: 'twitch', name: 'Twitch', brandColor: const Color(0xFF9146FF), emblemIcon: Icons.videogame_asset),
    PlatformAccountConfig(id: 'youtube', name: 'YouTube', brandColor: const Color(0xFFFF0000), emblemIcon: Icons.play_arrow),
    PlatformAccountConfig(id: 'kick', name: 'Kick', brandColor: const Color(0xFF53FC18), emblemIcon: Icons.bolt),
  ];

  final List<HellLiveEvent> _events = [
    HellLiveEvent(
      id: 'init_1',
      platform: 'TikTok',
      type: 'chat',
      username: 'Ana_Gamer',
      message: 'Bora para a live! Boa sorte na partida!',
    ),
    HellLiveEvent(
      id: 'init_2',
      platform: 'YouTube',
      type: 'follow',
      username: 'Miguel_PT',
      message: 'O Miguel começou a seguir-te!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _initPortugueseTts();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('hell_user_email') ?? 'hellcreatoros@gmail.com';
    final name = prefs.getString('hell_user_name') ?? 'Criador HELL';
    final role = prefs.getString('hell_user_role') ?? 'OWNER';
    final pin = prefs.getString('hell_user_pin') ?? '0000';

    setState(() {
      _user = HellUserSession(name: name, email: email, role: role, pin: pin);
      for (final p in _platforms) {
        final savedUser = prefs.getString('hell_plat_${p.id}_user') ?? '';
        p.usernameOrKey = savedUser;
      }
    });
  }

  Future<void> _initPortugueseTts() async {
    final targetLocale = HellLocaleManager.activeTtsLocale;
    await _tts.setLanguage(targetLocale);
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processNextInVoiceQueue();
    });

    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is List) {
        final filtered = <Map<String, String>>[];
        final langPrefix = targetLocale.split('-').first.toLowerCase();
        for (final v in rawVoices) {
          if (v is Map) {
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final name = (v['name'] ?? '').toString();
            if (locale.startsWith(langPrefix)) {
              filtered.add({'name': name, 'locale': locale});
            }
          }
        }
        if (mounted) {
          setState(() {
            _ptVoices = filtered;
            if (_ptVoices.isNotEmpty) {
              final exact = _ptVoices.firstWhere(
                (v) => v['locale'] == targetLocale.toLowerCase(),
                orElse: () => _ptVoices.first,
              );
              _selectedVoiceName = exact['name'];
              _tts.setVoice({'name': exact['name']!, 'locale': exact['locale']!});
            }
          });
        }
      }
    } catch (_) {}
  }
  void _enqueueSpeech(String text) {
    if (_voiceMuted || text.trim().isEmpty) return;
    _voiceQueue.add(text);
    if (!_isSpeaking) {
      _processNextInVoiceQueue();
    }
  }

  Future<void> _processNextInVoiceQueue() async {
    if (_voiceQueue.isEmpty || _voiceMuted) return;
    _isSpeaking = true;
    final nextText = _voiceQueue.removeAt(0);
    await _tts.setLanguage(HellLocaleManager.activeTtsLocale);
    await _tts.speak(nextText);
  }

  void _handleNewEvent(HellLiveEvent event) {
    _connectors.dispatchExternalEvent(
      event: event,
      onAcceptedEvent: (accepted) {
        setState(() {
          _events.insert(0, accepted);
        });
        _enqueueSpeech(accepted.message);
      },
    );
  }

  void _toggleVoiceCloneRecording() {
    if (_isRecordingClone) {
      _cloneTimer?.cancel();
      setState(() {
        _isRecordingClone = false;
        if (_cloneSecondsElapsed >= 15) {
          _hasClonedVoice = true;
          _enqueueSpeech('Amostra de voz clonada com sucesso em português de Portugal!');
        }
      });
    } else {
      setState(() {
        _isRecordingClone = true;
        _cloneSecondsElapsed = 0;
      });
      _cloneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _cloneSecondsElapsed++;
          if (_cloneSecondsElapsed >= 120) {
            _isRecordingClone = false;
            _hasClonedVoice = true;
            timer.cancel();
            _enqueueSpeech('Gravação de dois minutos concluída! A tua voz pessoal está pronta.');
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _cloneTimer?.cancel();
    _connectors.disposeAll();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStreamDeckTab = _currentTab == 2;

    return Scaffold(
      backgroundColor: HellTheme.bgDark,
      appBar: isStreamDeckTab
          ? AppBar(
              backgroundColor: HellTheme.bgDark,
              elevation: 0,
              toolbarHeight: 42,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: HellTheme.neonBlue),
                onPressed: () => setState(() => _currentTab = 0),
              ),
              title: const Text(
                'Voltar ao Centro de Comando',
                style: TextStyle(color: HellTheme.textWhite, fontSize: 13),
              ),
            )
          : AppBar(
              backgroundColor: HellTheme.bgDark,
              elevation: 0,
              leading: const Padding(
                padding: EdgeInsets.all(8.0),
                child: HellBrandIcon(size: 36),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    HellAppInfo.appName,
                    style: TextStyle(
                      color: HellTheme.textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    _gamingModeInvisible
                        ? HellLocaleManager.t('gaming_active')
                        : HellAppInfo.slogan,
                    style: TextStyle(
                      color: _gamingModeInvisible ? HellTheme.neonGreen : HellTheme.neonBlue,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _voiceMuted ? 'Ativar HELL VOICE' : 'Silenciar HELL VOICE',
                  icon: Icon(
                    _voiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: _voiceMuted ? HellTheme.neonRed : HellTheme.neonBlue,
                  ),
                  onPressed: () {
                    setState(() => _voiceMuted = !_voiceMuted);
                    if (_voiceMuted) _tts.stop();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ActionChip(
                    avatar: Icon(
                      _gamingModeInvisible ? Icons.visibility_off_rounded : Icons.sports_esports_rounded,
                      color: _gamingModeInvisible ? HellTheme.bgDark : HellTheme.neonBlue,
                      size: 16,
                    ),
                    label: Text(
                      _gamingModeInvisible ? 'JOGO ON' : 'Gaming',
                      style: TextStyle(
                        color: _gamingModeInvisible ? HellTheme.bgDark : HellTheme.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    backgroundColor: _gamingModeInvisible ? HellTheme.neonGreen : HellTheme.cardElevated,
                    onPressed: () {
                      setState(() => _gamingModeInvisible = !_gamingModeInvisible);
                      if (_gamingModeInvisible) {
                        _enqueueSpeech('Modo jogo ativado. Ecrã limpo, apenas voz e alertas sonoros.');
                      }
                    },
                  ),
                ),
              ],
            ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildCommandCenterTab(),
          _buildHellVoiceTab(),
          StreamDeckScreen(
            onDeckActionTriggered: (id, label) {
              _connectors.switchObsScene(label);
              _enqueueSpeech('Ação $label ativada na live.');
            },
          ),
          StudioAndGrowthView(onSpeakAlert: _enqueueSpeech),
          CommunityAndPlansView(currentUser: _user),
          MusicBusinessAndHelpView(onSpeakAlert: _enqueueSpeech),
        ],
      ),
      bottomNavigationBar: isStreamDeckTab
          ? null
          : BottomNavigationBar(
              currentIndex: _currentTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: HellTheme.cardDark,
              selectedItemColor: HellTheme.neonBlue,
              unselectedItemColor: HellTheme.textMuted,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              onTap: (idx) => setState(() => _currentTab = idx),
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: HellLocaleManager.t('tab_command')),
                BottomNavigationBarItem(icon: const Icon(Icons.record_voice_over_rounded), label: HellLocaleManager.t('tab_voice')),
                BottomNavigationBarItem(icon: const Icon(Icons.grid_view_rounded), label: HellLocaleManager.t('tab_deck')),
                BottomNavigationBarItem(icon: const Icon(Icons.auto_awesome_rounded), label: HellLocaleManager.t('tab_studio')),
                BottomNavigationBarItem(icon: const Icon(Icons.public_rounded), label: HellLocaleManager.t('tab_community')),
                BottomNavigationBarItem(icon: const Icon(Icons.more_horiz_rounded), label: HellLocaleManager.t('tab_more')),
              ],
            ),
    );
  }

  Widget _buildCommandCenterTab() {
    final activeCount = _platforms.where((p) => p.isConnected).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlatformLogosGrid(
          platforms: _platforms,
          onPlatformToggled: (plat) {
            setState(() {});
            _connectors.syncPlatformConnection(
              platform: plat,
              onEventReceived: _handleNewEvent,
            );
            _enqueueSpeech(
              plat.isConnected
                  ? '${plat.name} ligado e em direto!'
                  : '${plat.name} desligado.',
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: HellTheme.neonCard(isActiveGreen: activeCount > 0),
          child: Row(
            children: [
              Icon(
                activeCount > 0 ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                color: activeCount > 0 ? HellTheme.neonGreen : HellTheme.neonBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeCount > 0
                      ? '$activeCount plataforma(s) em direto • Segundo plano pronto'
                      : 'Toca num quadrado acima para iniciar (ON)',
                  style: const TextStyle(color: HellTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Modo Leve (Poupar Bateria/RAM)',
                icon: Icon(
                  Icons.speed_rounded,
                  color: _lowResourceMode ? HellTheme.neonGreen : HellTheme.textMuted,
                ),
                onPressed: () => setState(() => _lowResourceMode = !_lowResourceMode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: HellTheme.neonCard(),
          child: Row(
            children: [
              const Icon(Icons.psychology_rounded, color: HellTheme.neonBlue, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI STREAM DIRECTOR',
