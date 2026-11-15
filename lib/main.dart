import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_data.dart';
import 'platform_logos.dart';
import 'account_security.dart';
import 'live_connectors.dart';
import 'actions_studio.dart';
import 'studio_screens.dart';
import 'deck_and_community.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalObsServer.start();
  runApp(const HellLiveApp());
}

class HellLiveApp extends StatelessWidget {
  const HellLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HELL Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050B1E),
        primaryColor: const Color(0xFF1E78FF),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF08112B), elevation: 0),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF1E78FF), secondary: Color(0xFF38BDF8)),
      ),
      home: const AuthGateScreen(),
    );
  }
}
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  Map<String, dynamic>? _user;
  bool _unlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final saved = await UserAccountManager.getSavedUser();
    if (mounted) {
      setState(() {
        _user = saved;
        _unlocked = saved == null ? false : (List<String>.from(saved['securityMethods'] ?? []).isEmpty);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
      onUserUpdated: (u) => setState(() => _user = u),
      onLogout: () async {
        await UserAccountManager.logout();
        setState(() {
          _user = null;
          _unlocked = false;
        });
      },
    );
  }
}
class MainShell extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String _appLang = 'pt';
  bool _ttsEnabled = true;
  bool _isMuted = false;
  String _selectedVoiceName = '';
  String _activePlatform = '';
  String _connectionStatus = 'Pronto para ligar às tuas plataformas em direto';

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isMusicPlaying = false;
  int _currentTrackIndex = 0;
  final List<Map<String, String>> _playlist = List<Map<String, String>>.from(DefaultMediaLibrary.royaltyFreeMusicRepo);
  final _musicLinkCtrl = TextEditingController();

  final List<Map<String, String>> _chatLog = [];
  final List<Map<String, dynamic>> _topLikes = [];
  final List<Map<String, dynamic>> _topGifts = [];
  final List<Map<String, dynamic>> _topDonors = [];
  late final List<Map<String, dynamic>> _giftsList = DefaultMediaLibrary.defaultGiftsCatalog.map((e) => Map<String, dynamic>.from(e)).toList();
  final List<Map<String, String>> _mediaLibrary = List<Map<String, String>>.from(DefaultMediaLibrary.builtInGifsAndPngs);
  final List<Map<String, String>> _soundsLibrary = List<Map<String, String>>.from(DefaultMediaLibrary.onlineSoundsRepository);

    final List<Map<String, dynamic>> _alertsList = [
    {'id': 'a1', 'trigger': 'follow', 'name': 'Novo Seguidor', 'enabled': true, 'autoRecognize': true, 'ttsThank': true, 'customMessage': 'Muito obrigado {user} por seguires o canal!', 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs.first['url']!, 'sound': ''},
    {'id': 'a2', 'trigger': 'like500', 'name': 'Meta de Gostos', 'enabled': true, 'autoRecognize': true, 'ttsThank': true, 'customMessage': 'Obrigado {user} pelos gostos na live!', 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs.last['url']!, 'sound': ''},
    {'id': 'a3', 'trigger': 'sub', 'name': 'Novo Subscritor', 'enabled': true, 'autoRecognize': true, 'ttsThank': true, 'customMessage': 'Bem-vindo ao clube VIP {user}!', 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs.first['url']!, 'sound': ''},
    {'id': 'a4', 'trigger': 'share', 'name': 'Partilha da Live', 'enabled': true, 'autoRecognize': true, 'ttsThank': true, 'customMessage': 'Obrigado {user} por partilhares a transmissão!', 'customVoicePath': null, 'media': DefaultMediaLibrary.builtInGifsAndPngs.last['url']!, 'sound': ''},
  ];

  final List<Map<String, dynamic>> _goalsList = [
    {'title': 'Meta de Seguidores da Live', 'current': 420, 'target': 1000, 'overlayType': 'neon'},
    {'title': 'Meta de Gostos (Likes)', 'current': 3500, 'target': 5000, 'overlayType': 'gold_vip'},
  ];

  final _mbwayCtrl = TextEditingController();
  final _paypalCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _pixCtrl = TextEditingController();
  final _simDonorCtrl = TextEditingController(text: 'Apoiante');
  final _simAmountCtrl = TextEditingController(text: '1.50');
  final _aiHelpCtrl = TextEditingController();
  String _aiReply = 'Olá! Sou o Assistente Oficial da HELL Live. Pergunta-me sobre OBS, overlays, doações ou multiplataformas.';
  late MultiPlatformLiveConnector _connector;
  @override
  void initState() {
    super.initState();
    DonationMethodsStore.creatorName = widget.user['nickname'] ?? 'HELL Live Creator';
    _flutterTts.setLanguage('pt-PT');

    _connector = MultiPlatformLiveConnector(
      onChatMessage: (platform, user, msg) {
        setState(() => _chatLog.insert(0, {'platform': platform, 'user': user, 'msg': msg}));
        WheelTriggerEngine.checkChatForWheel(msg);
        if (_ttsEnabled && !_isMuted) {
          final safe = GoogleVoiceAndModulatorService.filterChatMessage(msg);
          if (safe != null) _speak(safe);
        }
      },
      onGiftReceived: (platform, user, giftCode, giftName, coins) {
        _addScore(_topGifts, user, coins);
        _handleGiftRecognition(user, giftCode, giftName, coins);
      },
      onSocialEvent: (platform, user, evType) {
        if (evType == 'like') _addScore(_topLikes, user, 1);
        _handleAlertRecognition(user, evType);
      },
      onConnectionStatus: (st) {
        if (mounted) setState(() => _connectionStatus = st);
      },
    );
  }

  void _addScore(List<Map<String, dynamic>> list, String user, num delta) {
    setState(() {
      final idx = list.indexWhere((e) => e['user'] == user);
      if (idx >= 0) {
        list[idx]['score'] = (list[idx]['score'] as num) + delta;
      } else {
        list.add({'user': user, 'score': delta, 'avatar': ''});
      }
      list.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    });
  }
  Future<void> _speak(String text) async {
    if (_isMuted) return;
    await GoogleVoiceAndModulatorService.applyModulatorPreset(
      _flutterTts,
      GoogleVoiceAndModulatorService.activeModulator,
    );
    await _flutterTts.speak(text);
  }

  Future<void> _handleGiftRecognition(String user, String giftCode, String giftName, int coins) async {
    final codeLow = giftCode.toLowerCase();
    final nameLow = giftName.toLowerCase();
    final match = _giftsList.firstWhere(
      (g) => g['enabled'] == true && g['autoRecognize'] == true && ((g['code'] ?? '').toString().toLowerCase() == codeLow || (g['name'] ?? '').toString().toLowerCase() == nameLow),
      orElse: () => {
        'name': giftName,
        'ttsThank': true,
        'customMessage': 'Muito obrigado {user} por enviares $giftName!',
        'png': DefaultMediaLibrary.builtInGifsAndPngs.first['url']!,
        'sound': '',
      },
    );
    final spoken = (match['customMessage'] ?? 'Obrigado {user} pelo $giftName!').toString().replaceAll('{user}', user);
    LocalObsServer.pushAlert('🎁 $giftName ($coins)', spoken, match['png'] ?? '');
    if (!_isMuted && (match['sound'] ?? '').toString().isNotEmpty) {
      await _sfxPlayer.play(UrlSource(match['sound']));
    }
    if (match['ttsThank'] == true) await _speak(spoken);
  }

  Future<void> _handleAlertRecognition(String user, String trigger) async {
    final match = _alertsList.where((a) => a['enabled'] == true && a['autoRecognize'] != false && a['trigger'] == trigger).toList();
    if (match.isEmpty) return;
    final al = match.first;
    final spoken = (al['customMessage'] ?? 'Obrigado {user}!').toString().replaceAll('{user}', user);
    LocalObsServer.pushAlert(al['name'] ?? 'Alerta', spoken, al['media'] ?? '');
    if (!_isMuted && (al['sound'] ?? '').toString().isNotEmpty) {
      await _sfxPlayer.play(UrlSource(al['sound']));
    }
    if (al['ttsThank'] == true) await _speak(spoken);
  }
  void _openPlatformConnectDialog(String platform) {
    final userCtrl = TextEditingController();
    final extraCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF08112B),
        title: Text('Ligar $platform Live', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(
                labelText: platform == 'YouTube' ? 'ID ou Link da Live YouTube' : 'Nome de Utilizador / Canal ($platform)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (platform == 'YouTube') ...[
              const SizedBox(height: 10),
              TextField(controller: extraCtrl, decoration: const InputDecoration(labelText: 'YouTube Data API Key', border: OutlineInputBorder())),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              final val = userCtrl.text.trim();
              if (val.isEmpty) return;
              setState(() => _activePlatform = platform);
              if (platform == 'TikTok') _connector.connectTikTokBridge(val);
              if (platform == 'Twitch') _connector.connectTwitch(val);
              if (platform == 'Kick') _connector.connectKick(val);
              if (platform == 'YouTube') _connector.connectYouTube(val, extraCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Ligar em Direto', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Future<void> _playTrack(int idx) async {
    if (_playlist.isEmpty) return;
    _currentTrackIndex = idx % _playlist.length;
    final url = _playlist[_currentTrackIndex]['url'] ?? '';
    if (url.isEmpty) return;
    await _musicPlayer.stop();
    if (url.startsWith('http')) {
      await _musicPlayer.play(UrlSource(url));
    } else {
      await _musicPlayer.play(DeviceFileSource(url));
    }
    setState(() => _isMusicPlaying = true);
  }

  Widget _buildDonationTab() {
    final unifiedDonateLink = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/donate';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF38BDF8))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💸 Link Único Multi-Pagamento (MB WAY, PayPal, Revolut, PIX)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 13.5)),
              const SizedBox(height: 6),
              const Text('Este link único abre uma página limpa com todos os métodos que ativares abaixo, sem violar regras da live:', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(unifiedDonateLink, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: unifiedDonateLink));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link único de doação copiado!')));
                    },
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativar MB WAY'),
                value: DonationMethodsStore.mbwayEnabled,
                onChanged: (v) => setState(() => DonationMethodsStore.mbwayEnabled = v),
              ),
              if (DonationMethodsStore.mbwayEnabled)
                TextField(controller: _mbwayCtrl, onChanged: (v) => DonationMethodsStore.mbwayPhone = v.trim(), decoration: const InputDecoration(labelText: 'Número MB WAY', isDense: true)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativar PayPal'),
                value: DonationMethodsStore.paypalEnabled,
                onChanged: (v) => setState(() => DonationMethodsStore.paypalEnabled = v),
              ),
              if (DonationMethodsStore.paypalEnabled)
                TextField(controller: _paypalCtrl, onChanged: (v) => DonationMethodsStore.paypalLink = v.trim(), decoration: const InputDecoration(labelText: 'Link PayPal.me', isDense: true)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativar Revolut'),
                value: DonationMethodsStore.revolutEnabled,
                onChanged: (v) => setState(() => DonationMethodsStore.revolutEnabled = v),
              ),
              if (DonationMethodsStore.revolutEnabled)
                TextField(controller: _revolutCtrl, onChanged: (v) => DonationMethodsStore.revolutLink = v.trim(), decoration: const InputDecoration(labelText: 'Link Revolut.me', isDense: true)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativar PIX'),
                value: DonationMethodsStore.pixEnabled,
                onChanged: (v) => setState(() => DonationMethodsStore.pixEnabled = v),
              ),
              if (DonationMethodsStore.pixEnabled)
                TextField(controller: _pixCtrl, onChanged: (v) => DonationMethodsStore.pixKey = v.trim(), decoration: const InputDecoration(labelText: 'Chave PIX', isDense: true)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E78FF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔊 Testar Leitura Natural de Valores em Euros', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _simDonorCtrl, decoration: const InputDecoration(labelText: 'Nome Apoiante', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _simAmountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor (€) ex: 0.50, 1, 1.50', isDense: true))),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () {
                  final amt = double.tryParse(_simAmountCtrl.text.replaceAll(',', '.')) ?? 1.0;
                  final donor = _simDonorCtrl.text.trim().isEmpty ? 'Apoiante' : _simDonorCtrl.text.trim();
                  final speechAmount = DefaultMediaLibrary.formatEuroSpeech(amt);
                  final phrase = amt == 1.0 ? 'Muito obrigado $donor pelo euro!' : 'Muito obrigado $donor pelos $speechAmount!';
                  _addScore(_topDonors, donor, amt);
                  LocalObsServer.pushAlert('💶 Doação: ${amt.toStringAsFixed(2)} €', phrase, DefaultMediaLibrary.builtInGifsAndPngs.first['url']!);
                  _speak(phrase);
                },
                icon: const Icon(Icons.record_voice_over, color: Colors.white),
                label: const Text('Disparar Alerta & Voz da Doação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildMusicTab() {
    final currentTrack = _playlist.isEmpty ? {'title': 'Nenhuma faixa', 'artist': ''} : _playlist[_currentTrackIndex % _playlist.length];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF38BDF8))),
          child: Column(
            children: [
              const Text('🎵 Leitor Interno de Música & Playlists (Sem Sair da App)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              Text(currentTrack['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              Text(currentTrack['artist'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () => _playTrack((_currentTrackIndex - 1 + _playlist.length) % _playlist.length)),
                  IconButton(
                    icon: Icon(_isMusicPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 46, color: const Color(0xFF38BDF8)),
                    onPressed: () async {
                      if (_isMusicPlaying) {
                        await _musicPlayer.pause();
                        setState(() => _isMusicPlaying = false);
                      } else {
                        await _playTrack(_currentTrackIndex);
                      }
                    },
                  ),
                  IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () => _playTrack((_currentTrackIndex + 1) % _playlist.length)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _musicLinkCtrl, decoration: const InputDecoration(hintText: 'Colar link direto MP3 / Stream / Rádio...', isDense: true))),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                    onPressed: () {
                      final url = _musicLinkCtrl.text.trim();
                      if (url.isNotEmpty) {
                        setState(() {
                          _playlist.insert(0, {'title': 'Stream Personalizado', 'artist': url, 'url': url});
                          _musicLinkCtrl.clear();
                        });
                        _playTrack(0);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Carregar MP3 do Dispositivo',
                    icon: const Icon(Icons.folder_open, color: Color(0xFF38BDF8)),
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                      if (res != null && res.files.single.path != null) {
                        setState(() => _playlist.insert(0, {'title': res.files.single.name, 'artist': 'Ficheiro Local', 'url': res.files.single.path!}));
                        _playTrack(0);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._playlist.asMap().entries.map((e) => Card(
              color: e.key == _currentTrackIndex ? const Color(0xFF122E73) : const Color(0xFF0B1636),
              child: ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFF38BDF8)),
                title: Text(e.value['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(e.value['artist'] ?? '', style: const TextStyle(fontSize: 11)),
                trailing: IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent), onPressed: () => _playTrack(e.key)),
              ),
            )),
      ],
    );
  }
  Widget _buildAboutAndHelpTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF38BDF8))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔥 Quem Somos Nós & Ajuda · HELL Live', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              const Text(
                'A HELL Live é o centro de comando definitivo para criadores multiplataforma (TikTok, Twitch, YouTube e Kick), unindo overlays 3D, reconhecimento automático de presentes, voz Google oficial, Stream Deck Pro, Comunidade Global e Loja Oficial.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email, color: Color(0xFF38BDF8)),
                title: const Text('Contacto Oficial de Suporte & Marca', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                subtitle: const Text(DefaultMediaLibrary.brandOfficialEmail, style: TextStyle(color: Colors.greenAccent)),
                onTap: () => launchUrl(Uri.parse('mailto:${DefaultMediaLibrary.brandOfficialEmail}')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E78FF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🤖 Assistente IA HELL Live (Ajuda & Ideias)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              Text(_aiReply, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _aiHelpCtrl, decoration: const InputDecoration(hintText: 'Escreve a tua dúvida sobre a app...', isDense: true))),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      final q = _aiHelpCtrl.text.trim().toLowerCase();
                      if (q.isEmpty) return;
                      setState(() {
                        if (q.contains('obs') || q.contains('overlay')) {
                          _aiReply = 'Para usar no OBS Studio ou TikTok Live Studio, adiciona uma fonte "Browser" com o link http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay.';
                        } else if (q.contains('doar') || q.contains('donation') || q.contains('mbway')) {
                          _aiReply = 'Ativa MB WAY, PayPal, Revolut ou PIX na aba Donation e partilha o link único http://${LocalObsServer.localIp}:${LocalObsServer.port}/donate.';
                        } else {
                          _aiReply = 'Podes gerir todos os presentes automáticos em Ações, Vozes Google em Chat TTS e testar o Estúdio VIP grátis por 3 dias!';
                        }
                        _aiHelpCtrl.clear();
                      });
                    },
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
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E78FF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌐 Idioma da Interface', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('🇵🇹 Português'), selected: _appLang == 'pt', onSelected: (_) => setState(() => _appLang = 'pt')),
                  ChoiceChip(label: const Text('🇬🇧 English'), selected: _appLang == 'en', onSelected: (_) => setState(() => _appLang = 'en')),
                  ChoiceChip(label: const Text('🇪🇸 Español'), selected: _appLang == 'es', onSelected: (_) => setState(() => _appLang = 'es')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF38BDF8))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔐 Privacidade, Segurança & Termos Legais', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 6),
              PrivacySecurityTermsPanel(user: widget.user, onUserUpdated: widget.onUserUpdated),
            ],
          ),
        ),
      ],
    );
  }
  Widget _menuTile(IconData icon, String title, VoidCallback onTap, {String? badge}) {
    return Card(
      color: const Color(0xFF0B1636),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF1E78FF), width: 1.1)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF38BDF8)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF122E73), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Expanded(child: PlatformGlassTile(platform: 'tiktok', label: 'TikTok', isActive: _activePlatform == 'TikTok', onTap: () => _openPlatformConnectDialog('TikTok'))),
            const SizedBox(width: 8),
            Expanded(child: PlatformGlassTile(platform: 'twitch', label: 'Twitch', isActive: _activePlatform == 'Twitch', onTap: () => _openPlatformConnectDialog('Twitch'))),
            const SizedBox(width: 8),
            Expanded(child: PlatformGlassTile(platform: 'youtube', label: 'YouTube', isActive: _activePlatform == 'YouTube', onTap: () => _openPlatformConnectDialog('YouTube'))),
            const SizedBox(width: 8),
            Expanded(child: PlatformGlassTile(platform: 'kick', label: 'Kick', isActive: _activePlatform == 'Kick', onTap: () => _openPlatformConnectDialog('Kick'))),
          ],
        ),
        const SizedBox(height: 8),
        Text(_connectionStatus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: Color(0xFF7DD3FC))),
        const SizedBox(height: 12),
        _menuTile(Icons.bolt, AppTranslations.t(_appLang, 'actions'), () => setState(() => _selectedIndex = 1), badge: 'AUTO GIFT'),
        _menuTile(Icons.record_voice_over, AppTranslations.t(_appLang, 'chat_tts'), () => setState(() => _selectedIndex = 2), badge: 'VOZ GOOGLE'),
        _menuTile(Icons.volunteer_activism, AppTranslations.t(_appLang, 'donation'), () => setState(() => _selectedIndex = 3), badge: 'EUROS'),
        _menuTile(Icons.music_note, AppTranslations.t(_appLang, 'music'), () => setState(() => _selectedIndex = 4), badge: 'INTERNO'),
        _menuTile(Icons.casino, AppTranslations.t(_appLang, 'interaction'), () => setState(() => _selectedIndex = 5), badge: 'ROLETA & TOP'),
        _menuTile(Icons.storefront, AppTranslations.t(_appLang, 'loja_hell'), () => setState(() => _selectedIndex = 6), badge: 'LOJA HELL'),
        _menuTile(Icons.workspace_premium, AppTranslations.t(_appLang, 'estudio_vip'), () => setState(() => _selectedIndex = 7), badge: '3 DIAS GRÁTIS'),
        _menuTile(Icons.grid_view_rounded, AppTranslations.t(_appLang, 'stream_deck'), () => setState(() => _selectedIndex = 8), badge: 'VIDRO 3D'),
        _menuTile(Icons.public, AppTranslations.t(_appLang, 'community'), () => setState(() => _selectedIndex = 9), badge: 'GLOBO REAL'),
        _menuTile(Icons.support_agent_outlined, AppTranslations.t(_appLang, 'about'), () => setState(() => _selectedIndex = 10), badge: 'AJUDA & IA'),
        _menuTile(Icons.settings_outlined, AppTranslations.t(_appLang, 'settings'), () => setState(() => _selectedIndex = 11)),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      ActionsStudioScreen(
        giftsList: _giftsList,
        alertsList: _alertsList,
        goalsList: _goalsList,
        mediaLibrary: _mediaLibrary,
        sounds: _soundsLibrary,
        sfxPlayer: _sfxPlayer,
        onSpeakVoice: _speak,
        onStateChanged: () => setState(() {}),
      ),
      ChatTtsScreen(
        flutterTts: _flutterTts,
        chatLog: _chatLog,
        ttsEnabled: _ttsEnabled,
        onToggleTts: (v) => setState(() => _ttsEnabled = v),
        selectedVoiceName: _selectedVoiceName,
        onSelectVoice: (v) => setState(() => _selectedVoiceName = v['name'] ?? ''),
      ),
      _buildDonationTab(),
      _buildMusicTab(),
      InteractionScreen(
        topLikes: _topLikes,
        topGifts: _topGifts,
        topDonors: _topDonors,
        onSpeakVoice: _speak,
      ),
      LojaHellScreen(currentUser: widget.user),
      EstudioVipHellScreen(currentUser: widget.user, onUserUpdated: widget.onUserUpdated),
      StreamDeckProScreen(
        onExecuteAction: (cmd) async {
          if (cmd == 'mute_all') {
            setState(() => _isMuted = !_isMuted);
          } else if (cmd == 'mod_deep') {
            GoogleVoiceAndModulatorService.activeModulator = 'deep_epic';
            _speak('Modo de voz grave épica ativado!');
          } else if (cmd == 'mod_robot') {
            GoogleVoiceAndModulatorService.activeModulator = 'robot';
            _speak('Modo robô ativado!');
          } else if (cmd == 'mod_normal') {
            GoogleVoiceAndModulatorService.activeModulator = 'normal';
            _speak('Voz normal restaurada.');
          } else if (cmd == 'spin_wheel') {
            WheelTriggerEngine.onRemoteSpinRequested?.call();
          } else if (cmd == 'sound_clap' && !_isMuted) {
            await _sfxPlayer.play(UrlSource(DefaultMediaLibrary.onlineSoundsRepository.first['url']!));
          } else if (cmd == 'sound_horn' && !_isMuted) {
            await _sfxPlayer.play(UrlSource(DefaultMediaLibrary.onlineSoundsRepository.last['url']!));
          } else if (cmd == 'music_toggle') {
            if (_isMusicPlaying) {
              await _musicPlayer.pause();
              setState(() => _isMusicPlaying = false);
            } else {
              await _playTrack(_currentTrackIndex);
            }
          } else if (cmd == 'music_next') {
            await _playTrack((_currentTrackIndex + 1) % _playlist.length);
          } else if (cmd == 'credits_roll') {
            setState(() => _selectedIndex = 5);
          } else if (cmd == 'test_alert') {
            LocalObsServer.pushAlert('🔥 HELL Live', 'Teste de alerta do Stream Deck Pro!', DefaultMediaLibrary.builtInGifsAndPngs.first['url']!);
          } else if (cmd == 'copy_obs') {
            Clipboard.setData(ClipboardData(text: 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay'));
          }
        },
      ),
      CommunityGlobeScreen(currentUser: widget.user),
      _buildAboutAndHelpTab(),
      _buildSettingsTab(),
    ];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileFullScreen(
                    user: widget.user,
                    onUserUpdated: widget.onUserUpdated,
                    onLogout: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                  ),
                ),
              ),
              child: Center(child: UserAccountManager.buildUserAvatar(widget.user, radius: 19)),
            ),
          ),
          title: Row(
            children: [
              if (_selectedIndex != 0)
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedIndex = 0)),
              const Text('HELL LIVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _isMuted ? Colors.redAccent : const Color(0xFF38BDF8)),
              onPressed: () => setState(() => _isMuted = !_isMuted),
            ),
          ],
        ),
        body: screens[_selectedIndex],
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
          child: const Text(
            'A tua live, no teu comando.  ·  LIVE  ·  PLAY  ·  CONNECT',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: Color(0xFF7DD3FC), fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
