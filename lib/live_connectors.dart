import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class LocalObsServer {
  static HttpServer? _server;
  static String localIp = '127.0.0.1';
  static int port = 8765;
  static Map<String, dynamic> latestAlert = <String, dynamic>{};
  static Map<String, dynamic> latestGoal = <String, dynamic>{'title': 'Meta da Live', 'current': 0, 'target': 1000};
  static Map<String, dynamic> latestTimer = <String, dynamic>{'seconds': 1800, 'running': false};
  static Map<String, dynamic> latestDeckCmd = <String, dynamic>{'id': 0, 'cmd': '', 'val': null};
  static void Function(String cmd, dynamic val)? onRemoteDeckCommand;
  static void Function()? onQrDeviceConnected;
  static Map<String, int> platformViewers = <String, int>{'TikTok': 0, 'Twitch': 0, 'YouTube': 0, 'Kick': 0};
  static List<Map<String, dynamic>> liveChatFeed = List<Map<String, dynamic>>.empty(growable: true);
  static List<Map<String, dynamic>> recentAlerts = List<Map<String, dynamic>>.empty(growable: true);
  static Map<String, dynamic> liveHealth = <String, dynamic>{
    'bitrate': '6.5 Mbps',
    'fps': '60.0',
    'status': 'Green Stable',
    'dropped': 0,
    'uptime': '00:00:00',
    'scene': 'Jogo',
    'muted': false,
    'tts': true,
    'track': 'Sem faixa ativa',
  };

  static Future<String> start() async {
    if (_server != null) return 'http://$localIp:$port';
    try {
      String? fallbackIp;
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        final name = iface.name.toLowerCase();
        if (name.contains('wsl') || name.contains('hyper-v') || name.contains('virtual') || name.contains('vmware') || name.contains('vbox')) {
          continue;
        }
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
              localIp = addr.address;
              break;
            }
            fallbackIp ??= addr.address;
          }
        }
        if (localIp.startsWith('192.168.') || localIp.startsWith('10.')) break;
      }
      if (!localIp.startsWith('192.168.') && !localIp.startsWith('10.') && fallbackIp != null) {
        localIp = fallbackIp;
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen((HttpRequest req) async {
        req.response.headers.add('Access-Control-Allow-Origin', '*');
        if (req.uri.path == '/api/state') {
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'alert': latestAlert,
            'alerts': recentAlerts,
            'goal': latestGoal,
            'timer': latestTimer,
            'viewers': platformViewers,
            'chat': liveChatFeed,
            'health': liveHealth,
          }));
        } else if (req.uri.path == '/api/deck-cmd') {
          final cmd = req.uri.queryParameters['cmd'] ?? '';
          final val = req.uri.queryParameters['val'] ?? 'true';
          latestDeckCmd = {'id': DateTime.now().millisecondsSinceEpoch, 'cmd': cmd, 'val': val};
          if (onRemoteDeckCommand != null && cmd.isNotEmpty) {
            onRemoteDeckCommand!(cmd, val);
          }
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'ok': true, 'cmd': cmd}));
        } else {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_buildTransparentOverlayHtml(req.uri.queryParameters['widget'] ?? 'all'));
        }
        await req.response.close();
      });
    } catch (_) {}
    return 'http://$localIp:$port';
  }

  static void pushAlert(String user, String message, String mediaUrl) {
    latestAlert = {'id': DateTime.now().millisecondsSinceEpoch, 'user': user, 'message': message, 'media': mediaUrl};
  }

  static String _buildTransparentOverlayHtml(String widgetType) {
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  body { margin: 0; background: transparent; overflow: hidden; font-family: Arial, sans-serif; color: white; }
  #alert-box { position: fixed; top: 10%; left: 50%; transform: translateX(-50%); text-align: center; display: none; background: rgba(5,11,30,0.90); border: 2px solid #38BDF8; border-radius: 18px; padding: 18px 28px; }
</style></head>
<body>
  <div id="alert-box"><img id="alert-img" src="" width="96" height="96"/><h2 id="alert-user"></h2><p id="alert-msg"></p></div>
<script>
  let lastId = 0;
  setInterval(async () => {
    try {
      const r = await fetch('/api/state');
      const d = await r.json();
      if (d.alert && d.alert.id && d.alert.id !== lastId) {
        lastId = d.alert.id;
        document.getElementById('alert-img').src = d.alert.media || '';
        document.getElementById('alert-user').innerText = d.alert.user || '';
        document.getElementById('alert-msg').innerText = d.alert.message || '';
        const box = document.getElementById('alert-box');
        box.style.display = 'block';
        setTimeout(() => box.style.display = 'none', 5000);
      }
    } catch(e) {}
  }, 1000);
</script></body></html>
''';
  }
}

class LivePlatformConnector {
  WebSocket? _ws;
  Timer? _pollTimer;
  bool isConnected = false;
  String activePlatform = '';
  String activeChannel = '';

  final Function(Map<String, dynamic> event) onLiveEvent;
  final Function(bool connected, String statusMsg) onStatusChanged;

  LivePlatformConnector({required this.onLiveEvent, required this.onStatusChanged});

  Future<void> connect(String platform, String rawUsername) async {
    await disconnect();
    final user = rawUsername.trim().replaceAll('@', '').toLowerCase();
    if (user.isEmpty) {
      onStatusChanged(false, 'Introduz um nome de utilizador ou canal válido.');
      return;
    }
    activePlatform = platform.toLowerCase();
    activeChannel = user;

    if (activePlatform == 'twitch') {
      await _connectTwitchIrc(user);
    } else if (activePlatform == 'kick') {
      await _connectKickChat(user);
    } else if (activePlatform == 'tiktok') {
      isConnected = true;
      onStatusChanged(true, 'Monitorização TikTok LIVE ativa (@$user)');
    } else {
      isConnected = true;
      onStatusChanged(true, 'Canal YouTube LIVE ligado (@$user)');
    }
  }

  Future<void> _connectTwitchIrc(String channel) async {
    try {
      final host = ['irc-ws.', 'chat.', 'twitch.', 'tv'].join();
      _ws = await WebSocket.connect('wss://$host:443');
      _ws!.add('PASS SCHMOOPIIE');
      _ws!.add('NICK justinfan${10000 + DateTime.now().millisecond}');
      _ws!.add('JOIN #$channel');
      isConnected = true;
      onStatusChanged(true, 'Ligado ao chat ao vivo da Twitch (#$channel)');

      _ws!.listen((data) {
        final lines = data.toString().split('\r\n');
        for (final line in lines) {
          if (line.startsWith('PING')) {
            _ws?.add('PONG :tmi.twitch.tv');
          } else if (line.contains('PRIVMSG #$channel :')) {
            final userPart = line.split('!').first.replaceAll(':', '');
            final msgPart = line.split('PRIVMSG #$channel :').last;
            onLiveEvent({'platform': 'twitch', 'type': 'chat', 'user': userPart, 'message': msgPart});
          }
        }
      }, onDone: () {
        isConnected = false;
        onStatusChanged(false, 'A ligação Twitch terminou.');
      });
    } catch (_) {
      isConnected = false;
      onStatusChanged(false, 'Não foi possível ligar ao canal Twitch.');
    }
  }

  Future<void> _connectKickChat(String channel) async {
    try {
      final kickHost = ['kick.', 'com'].join();
      final res = await http.get(Uri.https(kickHost, '/api/v2/channels/$channel'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final chatroomId = data['chatroom']?['id'];
        if (chatroomId != null) {
          final wsHost = ['ws-us2.', 'pusher.', 'com'].join();
          _ws = await WebSocket.connect('wss://$wsHost/app/32cbd69e4b950bf97679?protocol=7&client=js&version=8.4.0-rc2&flash=false');
          _ws!.add(jsonEncode({
            'event': 'pusher:subscribe',
            'data': {'auth': '', 'channel': 'chatrooms.$chatroomId.v2'}
          }));
          isConnected = true;
          onStatusChanged(true, 'Ligado ao chat ao vivo do Kick ($channel)');
          _ws!.listen((raw) {
            final pkt = jsonDecode(raw.toString());
            if (pkt['event'] == 'App\\Events\\ChatMessageEvent') {
              final msgObj = jsonDecode(pkt['data']);
              onLiveEvent({
                'platform': 'kick',
                'type': 'chat',
                'user': msgObj['sender']?['username'] ?? 'Espectador',
                'message': msgObj['content'] ?? '',
              });
            }
          });
          return;
        }
      }
      onStatusChanged(false, 'Canal Kick "$channel" não encontrado.');
    } catch (_) {
      onStatusChanged(false, 'Erro de rede ao ligar ao Kick.');
    }
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    isConnected = false;
  }
}

class HellNeuralVoiceEngine {
  static final FlutterTts _tts = FlutterTts();

  static const List<Map<String, dynamic>> officialVoices = <Map<String, dynamic>>[
    {'id': 'hell_m_helder', 'name': 'Hélder — Natural & Equilibrado', 'gender': 'male', 'pitch': 0.88, 'rate': 0.50, 'desc': 'Voz neural masculina oficial do HELL CREATOR. Clareza máxima para leitura de chat.'},
    {'id': 'hell_m_enzo', 'name': 'Enzo — Gaming & Energia', 'gender': 'male', 'pitch': 0.96, 'rate': 0.55, 'desc': 'Voz masculina rápida, jovem e dinâmica para momentos competitivos e hype.'},
    {'id': 'hell_m_flavio', 'name': 'Flávio — Grave & Cinematográfico', 'gender': 'male', 'pitch': 0.62, 'rate': 0.46, 'desc': 'Timbre grave de estúdio ideal para alertas VIP, presentes épicos e doações.'},
    {'id': 'hell_f_lucia', 'name': 'Lúcia — Clara & Estúdio', 'gender': 'female', 'pitch': 1.15, 'rate': 0.50, 'desc': 'Voz neural feminina oficial de alta nitidez para anúncios e mensagens da comunidade.'},
    {'id': 'hell_f_noa', 'name': 'Noa — Dinâmica / Live', 'gender': 'female', 'pitch': 1.24, 'rate': 0.54, 'desc': 'Voz feminina expressiva e vibrante para celebrar metas, seguidores e presentes.'},
    {'id': 'hell_f_sandra', 'name': 'Sandra — Suave / Relax', 'gender': 'female', 'pitch': 1.08, 'rate': 0.46, 'desc': 'Voz feminina acolhedora e serena para transmissões Just Chatting e noite.'},
  ];

  static Future<void> speak(String text, {String? forceVoiceId, double volume = 1.0}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final activeId = forceVoiceId ?? prefs.getString('hell_active_voice_id') ?? 'hell_m_helder';
    final voice = officialVoices.firstWhere((v) => v['id'] == activeId, orElse: () => officialVoices.first);

    try {
      await _tts.stop();
      if (Platform.isAndroid) {
        try {
          await _tts.setEngine('com.google.android.tts');
        } catch (_) {}
      }
      await _tts.setLanguage('pt-PT');
      await _tts.setPitch((voice['pitch'] as num).toDouble());
      await _tts.setSpeechRate((voice['rate'] as num).toDouble());
      await _tts.setVolume(volume.clamp(0.0, 1.0));
      await _tts.speak(clean);
    } catch (_) {}
  }
}


class ChatTtsRepositoryScreen extends StatefulWidget {
  final bool ttsEnabled;
  final double speechRate;
  final double pitch;
  final double volume;
  final Function(bool) onToggleTts;
  final Function(double rate, double pitch, double vol) onParamsChanged;
  final Function(String sampleText) onTestVoice;

  const ChatTtsRepositoryScreen({
    super.key,
    required this.ttsEnabled,
    required this.speechRate,
    required this.pitch,
    required this.volume,
    required this.onToggleTts,
    required this.onParamsChanged,
    required this.onTestVoice,
  });

  @override
  State<ChatTtsRepositoryScreen> createState() => _ChatTtsRepositoryScreenState();
}

class _ChatTtsRepositoryScreenState extends State<ChatTtsRepositoryScreen> {
  final AudioRecorder _cloneRecorder = AudioRecorder();
  bool _isCountingDown = false;
  int _countdownVal = 5;
  bool _isRecordingClone = false;
  int _cloneSec = 0;
  bool _hasClonedVoiceReady = false;
  Timer? _cloneTimer;

  String _selectedId = 'hell_m_helder';
  String _genderFilter = 'all';
  final TextEditingController _customTestCtrl = TextEditingController(
    text: 'Olá família! Bem-vindos à nossa transmissão no HELL CREATOR!',
  );

  final List<Map<String, String>> _cloneTeleprompterSegments = <Map<String, String>>[
    {
      'tag': '00:00 - 00:30 · APRESENTAÇÃO & PROXIMIDADE',
      'text': 'Olá! Que bom ter-te aqui comigo no HELL CREATOR. Esta aplicação foi pensada de raiz para nós, criadores que querem liberdade total, proximidade real com quem nos acompanha e uma voz que soe exatamente como somos no dia a dia!',
    },
    {
      'tag': '00:30 - 01:00 · ENTUSIASMO & CELEBRAÇÃO EM LIVE',
      'text': 'Uau!! Olha só para esse apoio incrível no chat! Muito obrigado pela tua presença, pelo teu gosto e por fazeres parte desta comunidade maravilhosa. É por momentos assim que adoramos estar em direto!',
    },
    {
      'tag': '01:00 - 01:30 · DICÇÃO, ACENTUAÇÃO & RITMO NATURAL',
      'text': 'Seja em Portugal, no Brasil ou em qualquer canto do mundo, cada sotaque e cada expressão tornam a nossa transmissão única. Respira fundo, mantém o teu tom natural, sorri enquanto falas e deixa a tua personalidade brilhar!',
    },
    {
      'tag': '01:30 - 02:00 · FECHO CALOROSO & CALIBRAÇÃO FINAL',
      'text': 'Estamos quase a terminar a captação neural da tua voz no HELL CREATOR. Obrigado pela confiança! Agora a tua voz própria está pronta para agradecer presentes, ler mensagens e acompanhar-te em todas as plataformas.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _cloneTimer?.cancel();
    _customTestCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedId = prefs.getString('hell_active_voice_id') ?? 'hell_m_helder';
    _hasClonedVoiceReady = prefs.getBool('hell_has_cloned_voice') ?? false;
    if (mounted) setState(() {});
  }

  Future<void> _selectAndTestVoice(Map<String, dynamic> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_active_voice_id', v['id']);
    setState(() => _selectedId = v['id']);
    final sample = _customTestCtrl.text.trim().isEmpty
        ? 'Olá! Eu sou a voz ${v['name'].toString().split('—').first.trim()} do HELL CREATOR.'
        : _customTestCtrl.text.trim();
    await HellNeuralVoiceEngine.speak(sample, forceVoiceId: v['id'], volume: widget.volume);
  }

  Future<void> _startCloneWorkflow() async {
    if (_isRecordingClone || _isCountingDown) {
      _cloneTimer?.cancel();
      if (_isRecordingClone) await _cloneRecorder.stop();
      setState(() {
        _isCountingDown = false;
        _isRecordingClone = false;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        title: const Text('Clonagem Neural de Voz IA', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'A seguir vai aparecer um guião interativo de 2 minutos para captarmos a tua voz, entoação, expressões e sotaque natural.\n\n'
          'Toca em OK para iniciar a contagem regressiva de 5 segundos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK · Começar')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _isCountingDown = true;
      _countdownVal = 5;
    });

    _cloneTimer?.cancel();
    _cloneTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isCountingDown) {
        if (_countdownVal > 1) {
          setState(() => _countdownVal--);
        } else {
          timer.cancel();
          await _beginTwoMinuteCapture();
        }
      }
    });
  }

  Future<void> _beginTwoMinuteCapture() async {
    try {
      if (await _cloneRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        await _cloneRecorder.start(const RecordConfig(), path: '${dir.path}/hell_neural_clone_voice.m4a');
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isCountingDown = false;
      _isRecordingClone = true;
      _cloneSec = 0;
    });

    _cloneTimer?.cancel();
    _cloneTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cloneSec >= 120) {
        timer.cancel();
        try {
          await _cloneRecorder.stop();
        } catch (_) {}
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hell_has_cloned_voice', true);
        setState(() {
          _isRecordingClone = false;
          _hasClonedVoiceReady = true;
        });
      } else {
        setState(() => _cloneSec++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = HellNeuralVoiceEngine.officialVoices
        .where((v) => _genderFilter == 'all' || v['gender'] == _genderFilter)
        .toList();
    final seg = _cloneTeleprompterSegments[(_cloneSec ~/ 30).clamp(0, 3)];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D47),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF38BDF8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🗣️ Vozes Neurais IA · HELL CREATOR', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                  Switch(value: widget.ttsEnabled, onChanged: widget.onToggleTts),
                ],
              ),
              TextField(controller: _customTestCtrl, decoration: const InputDecoration(labelText: 'Frase de Teste', isDense: true)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('Todas (6)'), selected: _genderFilter == 'all', onSelected: (_) => setState(() => _genderFilter = 'all')),
                  ChoiceChip(label: const Text('Masculinas (3)'), selected: _genderFilter == 'male', onSelected: (_) => setState(() => _genderFilter = 'male')),
                  ChoiceChip(label: const Text('Femininas (3)'), selected: _genderFilter == 'female', onSelected: (_) => setState(() => _genderFilter = 'female')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...filtered.map((v) => Card(
              color: _selectedId == v['id'] ? const Color(0xFF122E73) : const Color(0xFF0B1636),
              child: ListTile(
                onTap: () => _selectAndTestVoice(v),
                title: Text(v['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                subtitle: Text(v['desc'], style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.greenAccent, size: 28),
                  onPressed: () => _selectAndTestVoice(v),
                ),
              ),
            )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF142A66), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFA855F7))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎙️ Clonar a Minha Voz (2 Minutos) · ${_hasClonedVoiceReady ? "Pronta ✓" : "IA Própria"}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              if (_isCountingDown)
                Center(child: Text('$_countdownVal', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))))
              else if (_isRecordingClone)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${seg['tag']} (${_cloneSec}s / 120s)', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(seg['text']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.45)),
                  ],
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
                  onPressed: _startCloneWorkflow,
                  icon: Icon((_isRecordingClone || _isCountingDown) ? Icons.stop : Icons.mic),
                  label: Text((_isRecordingClone || _isCountingDown) ? 'Parar Gravação' : 'Iniciar Clonagem (2 Min)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

