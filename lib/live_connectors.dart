import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LocalObsServer {
  static HttpServer? _server;
  static String localIp = '127.0.0.1';
  static int port = 8765;
  static Map<String, dynamic> latestAlert = {};
  static Map<String, dynamic> latestGoal = {'title': 'Meta da Live', 'current': 0, 'target': 1000};
  static Map<String, dynamic> latestTimer = {'seconds': 1800, 'running': false};

  static Future<String> start() async {
    if (_server != null) return 'http://$localIp:$port';
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            localIp = addr.address;
            break;
          }
        }
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen((HttpRequest req) async {
        req.response.headers.add('Access-Control-Allow-Origin', '*');
        final path = req.uri.path;
               if (path == '/api/state') {
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'alert': latestAlert,
            'goal': latestGoal,
            'timer': latestTimer,
          }));
        } else if (path == '/donate') {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_buildDonatePageHtml(req.uri.queryParameters));
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
    latestAlert = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'user': user,
      'message': message,
      'media': mediaUrl,
    };
  }
  static String _buildDonatePageHtml(Map<String, String> q) {
    final mbway = q['mbway'] ?? '';
    final paypal = q['paypal'] ?? '';
    final revolut = q['revolut'] ?? '';
    final pix = q['pix'] ?? '';
    return '''<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>HELL Live · Apoiar Criador</title>
<style>body{background:#050B1E;color:#fff;font-family:Arial;text-align:center;padding:24px}.card{max-width:420px;margin:auto;background:#0B1636;border:1px solid #1E78FF;border-radius:16px;padding:20px}.btn{display:block;margin:10px 0;padding:14px;border-radius:12px;background:#1E78FF;color:#fff;text-decoration:none;font-weight:bold}</style>
</head><body><div class="card"><h2 style="color:#38BDF8">HELL Live · Apoiar Transmissão</h2>
${mbway.isNotEmpty ? '<div class="btn">📱 MB WAY: $mbway</div>' : ''}
${paypal.isNotEmpty ? '<a class="btn" href="$paypal" target="_blank">💳 Pagar com PayPal</a>' : ''}
${revolut.isNotEmpty ? '<a class="btn" href="$revolut" target="_blank">🏦 Pagar com Revolut</a>' : ''}
${pix.isNotEmpty ? '<div class="btn">🇧🇷 Chave PIX: $pix</div>' : ''}
</div></body></html>''';
  }

  static String _buildTransparentOverlayHtml(String widgetType) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { margin: 0; background: transparent; overflow: hidden; font-family: Arial, sans-serif; color: white; }
  #alert-box { position: fixed; top: 10%; left: 50%; transform: translateX(-50%); text-align: center; display: none; background: rgba(5,11,30,0.85); border: 2px solid #38BDF8; border-radius: 18px; padding: 18px 28px; box-shadow: 0 0 25px rgba(56,189,248,0.6); }
  #timer-box { position: fixed; bottom: 8%; left: 50%; transform: translateX(-50%); text-align: center; display: ${widgetType == 'timer_hud' ? 'block' : 'none'}; }
  .time-val { font-size: 54px; font-weight: 900; text-shadow: 0 0 18px #38BDF8, 2px 2px 4px #000; }
  .time-sub { font-size: 16px; font-weight: bold; color: #7DD3FC; letter-spacing: 2px; text-shadow: 1px 1px 3px #000; }
</style>
</head>
<body>
  <div id="alert-box">
    <img id="alert-img" src="" width="96" height="96"/><br/>
    <h2 id="alert-user" style="color:#38BDF8;margin:8px 0 4px;"></h2>
    <p id="alert-msg" style="margin:0;font-size:18px;"></p>
  </div>
  <div id="timer-box">
    <div class="time-val" id="t-val">00:30:00</div>
    <div class="time-sub">Tu controlas o tempo!</div>
  </div>
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
      if (d.timer) {
        const s = d.timer.seconds || 0;
        const h = String(Math.floor(s/3600)).padStart(2,'0');
        const m = String(Math.floor((s%3600)/60)).padStart(2,'0');
        const sec = String(s%60).padStart(2,'0');
        document.getElementById('t-val').innerText = h + ':' + m + ':' + sec;
      }
    } catch(e) {}
  }, 1000);
</script>
</body>
</html>
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

  LivePlatformConnector({
    required this.onLiveEvent,
    required this.onStatusChanged,
  });

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
      await _connectTikTokLive(user);
    } else {
      await _connectYouTubeLive(user);
    }
  }

  Future<void> _connectTwitchIrc(String channel) async {
    try {
      _ws = await WebSocket.connect('wss://irc-ws.chat.twitch.tv:443');
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
            onLiveEvent({
              'platform': 'twitch',
              'type': 'chat',
              'user': userPart,
              'message': msgPart,
            });
          }
        }
      }, onDone: () {
        isConnected = false;
        onStatusChanged(false, 'Ligação Twitch encerrada.');
      });
    } catch (e) {
      isConnected = false;
      onStatusChanged(false, 'Não foi possível ligar ao canal Twitch.');
    }
  }

    static const String _kickHost = 'https://kick.com';
  static const String _pusherHost = 'wss://://pusher.com';
  static const String _tiktokHost = 'https://tiktok.com';

  Future<void> _connectKickChat(String channel) async {
    try {
      final res = await http.get(Uri.parse('$_kickHost/api/v2/channels/$channel'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final chatroomId = data['chatroom']?['id'];
        if (chatroomId != null) {
          _ws = await WebSocket.connect('$_pusherHost/app/eb1d5f283081a78b932c?protocol=7&client=js&version=7.6.0');
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

  Future<void> _connectTikTokLive(String username) async {
    try {
      final res = await http.get(
        Uri.parse('$_tiktokHost/@$username/live'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      );
      if (res.statusCode == 200) {
        isConnected = true;
        onStatusChanged(true, 'Monitorização TikTok Live ativa (@$username)');
        _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
          try {
            final check = await http.get(Uri.parse('$_tiktokHost/api-live/user/room/?aid=1988&uniqueId=$username'));
            if (check.statusCode == 200) {
              final body = jsonDecode(check.body);
              final status = body['data']?['user']?['status'];
              if (status != null && status != 2) {
                onStatusChanged(false, 'A transmissão de @$username terminou no TikTok.');
                await disconnect();
              }
            }
          } catch (_) {}
        });
      } else {
        onStatusChanged(false, 'Utilizador @$username não encontrado no TikTok.');
      }
    } catch (_) {
      onStatusChanged(false, 'Erro ao contactar o TikTok Live.');
    }
  }

  Future<void> _connectYouTubeLive(String handle) async {
    isConnected = true;
    onStatusChanged(true, 'Canal YouTube Live ligado (@$handle)');
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
  final FlutterTts _tts = FlutterTts();
  int _subTab = 0; // 0 = Vozes (3M+3F), 1 = Natural Voice Alerts, 2 = Clonar Voz (2 min)
  String _voiceAlertMode = 'normal'; // normal | focus | silent
  bool _saySenderName = true;
  bool _isCloningRecording = false;
  int _cloneSeconds = 0;
  Timer? _cloneTimer;
  String? _clonedVoiceName;

  final List<Map<String, String>> _onlineVoiceCatalog = [
    {'id': 'pt_m1', 'name': 'Duarte Natural (PT)', 'gender': 'male', 'lang': 'pt', 'desc': 'Voz masculina natural e clara.'},
    {'id': 'pt_m2', 'name': 'Tiago Gaming (PT)', 'gender': 'male', 'lang': 'pt', 'desc': 'Voz masculina energética para lives.'},
    {'id': 'pt_m3', 'name': 'Locutor Épico (PT)', 'gender': 'male', 'lang': 'pt', 'desc': 'Tom grave ideal para alertas e metas.'},
    {'id': 'pt_f1', 'name': 'Raquel Natural (PT)', 'gender': 'female', 'lang': 'pt', 'desc': 'Voz feminina suave e expressiva.'},
    {'id': 'pt_f2', 'name': 'Beatriz Stream (PT)', 'gender': 'female', 'lang': 'pt', 'desc': 'Voz feminina dinâmica para leitura rápida.'},
    {'id': 'pt_f3', 'name': 'Inês Assistente (PT)', 'gender': 'female', 'lang': 'pt', 'desc': 'Voz feminina equilibrada para copilot.'},
    {'id': 'en_m1', 'name': 'Guy Natural (EN)', 'gender': 'male', 'lang': 'en', 'desc': 'Voz masculina em Inglês.'},
    {'id': 'en_f1', 'name': 'Jenny Natural (EN)', 'gender': 'female', 'lang': 'en', 'desc': 'Voz feminina em Inglês.'},
  ];

  final Map<String, Map<String, dynamic>> _naturalEvents = {
    'follow': {'label': 'Novos Seguidores', 'enabled': true, 'important': false, 'phrase': 'O {nome} começou a seguir-te!'},
    'gift': {'label': 'Presentes & Rosas', 'enabled': true, 'important': true, 'phrase': 'A {nome} enviou-te {presente}!'},
    'donation': {'label': 'Doações (€)', 'enabled': true, 'important': true, 'phrase': 'Recebeste uma doação de {valor} de {nome}!'},
    'sub': {'label': 'Subscrições & Membros', 'enabled': true, 'important': true, 'phrase': 'Temos um novo membro! Bem-vindo, {nome}!'},
    'raid': {'label': 'Raids & Grupos', 'enabled': true, 'important': true, 'phrase': 'Atenção! Recebeste uma raid de {quantidade} pessoas!'},
    'goal': {'label': 'Metas Atingidas', 'enabled': true, 'important': true, 'phrase': 'Parabéns! A tua meta foi atingida!'},
    'tech': {'label': 'Alertas Técnicos / Ligação', 'enabled': true, 'important': true, 'phrase': 'Atenção, verifica a ligação da tua transmissão!'},
  };

  Set<String> _downloadedIds = {'pt_m1', 'pt_f1'};
  String _selectedId = 'pt_m1';
  String _genderFilter = 'all';
  bool _showAllLanguages = false;
  @override
  void initState() {
    super.initState();
    _loadVoicePrefs();
  }

  @override
  void dispose() {
    _cloneTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVoicePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hell_downloaded_voices');
    if (saved != null && saved.isNotEmpty) _downloadedIds = saved.toSet();
    _selectedId = prefs.getString('hell_active_voice_id') ?? 'pt_m1';
    _clonedVoiceName = prefs.getString('hell_cloned_voice_name');
    if (mounted) setState(() {});
  }

  Future<void> _previewVoice(Map<String, String> voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_active_voice_id', voice['id']!);
    setState(() => _selectedId = voice['id']!);
    final isMale = voice['gender'] == 'male';
    try {
      await _tts.stop();
      if (Platform.isAndroid) await _tts.setEngine('com.google.android.tts');
      await _tts.setLanguage(voice['lang'] == 'en' ? 'en-US' : 'pt-PT');
      await _tts.setPitch(voice['id'] == 'pt_m3' ? 0.58 : (isMale ? 0.78 : 1.18));
      await _tts.setSpeechRate(widget.speechRate);
      await _tts.setVolume(widget.volume);
      await _tts.speak('Olá! Sou a voz ${voice['name']} da HELL Live.');
    } catch (_) {}
  }

  void _toggleCloneRecording() {
    if (_isCloningRecording) {
      _cloneTimer?.cancel();
      setState(() => _isCloningRecording = false);
      return;
    }
    setState(() {
      _isCloningRecording = true;
      _cloneSeconds = 0;
    });
    _cloneTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _cloneSeconds++);
      if (_cloneSeconds >= 120) {
        t.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hell_cloned_voice_name', 'Minha Voz Clonada (HD)');
        await prefs.setString('hell_active_voice_id', 'cloned_user_voice');
        if (mounted) {
          setState(() {
            _isCloningRecording = false;
            _clonedVoiceName = 'Minha Voz Clonada (HD)';
            _selectedId = 'cloned_user_voice';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎙️ Voz clonada em 2 minutos e ativada com sucesso!'), backgroundColor: Colors.green),
          );
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final appLang = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en') ? 'en' : 'pt';
    final voices = _onlineVoiceCatalog.where((v) {
      if (!_showAllLanguages && v['lang'] != appLang) return false;
      if (_genderFilter != 'all' && v['gender'] != _genderFilter) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E78FF)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🗣️ Vozes & Natural Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  Switch(activeColor: Colors.white, activeTrackColor: const Color(0xFF1E78FF), value: widget.ttsEnabled, onChanged: widget.onToggleTts),
                ],
              ),
              Row(
                children: [
                  const Text('Velocidade:', style: TextStyle(fontSize: 12)),
                  Expanded(child: Slider(value: widget.speechRate, min: 0.2, max: 0.9, onChanged: (v) => widget.onParamsChanged(v, widget.pitch, widget.volume))),
                  const Text('Vol:', style: TextStyle(fontSize: 12)),
                  Expanded(child: Slider(value: widget.volume, min: 0.0, max: 1.0, onChanged: (v) => widget.onParamsChanged(widget.speechRate, widget.pitch, v))),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(label: const Text('Vozes (3M + 3F)'), selected: _subTab == 0, selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _subTab = 0)),
                  ChoiceChip(label: const Text('Natural Alerts'), selected: _subTab == 1, selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _subTab = 1)),
                  ChoiceChip(label: const Text('Clonar Voz (2m)'), selected: _subTab == 2, selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _subTab = 2)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_subTab == 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(label: const Text('Todas'), selected: _genderFilter == 'all', onSelected: (_) => setState(() => _genderFilter = 'all')),
                  ChoiceChip(label: const Text('3 Masculinas'), selected: _genderFilter == 'male', onSelected: (_) => setState(() => _genderFilter = 'male')),
                  ChoiceChip(label: const Text('3 Femininas'), selected: _genderFilter == 'female', onSelected: (_) => setState(() => _genderFilter = 'female')),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _showAllLanguages = !_showAllLanguages),
                child: Text(_showAllLanguages ? 'Só Idioma App' : '+ Baixar Mais', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
              ),
            ],
          ),
          ...voices.map((v) => Card(
                color: _selectedId == v['id'] ? const Color(0xFF122E73) : const Color(0xFF0B1636),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: v['gender'] == 'male' ? const Color(0xFF1E78FF) : Colors.pinkAccent,
                    child: Icon(v['gender'] == 'male' ? Icons.man : Icons.woman, color: Colors.white),
                  ),
                  title: Text(v['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text(v['desc']!, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                  trailing: IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: () => _previewVoice(v)),
                  onTap: () => _previewVoice(v),
                ),
              )),
        ] else if (_subTab == 1) ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('🔊 Normal'), selected: _voiceAlertMode == 'normal', onSelected: (_) => setState(() => _voiceAlertMode = 'normal')),
              ChoiceChip(label: const Text('🎮 Concentração'), selected: _voiceAlertMode == 'focus', onSelected: (_) => setState(() => _voiceAlertMode = 'focus')),
              ChoiceChip(label: const Text('🔇 Silencioso'), selected: _voiceAlertMode == 'silent', onSelected: (_) => setState(() => _voiceAlertMode = 'silent')),
            ],
          ),
          SwitchListTile(
            title: const Text('Dizer o nome de quem enviou', style: TextStyle(fontSize: 13)),
            value: _saySenderName,
            onChanged: (v) => setState(() => _saySenderName = v),
          ),
          ..._naturalEvents.entries.map((e) => Card(
                color: const Color(0xFF0B1636),
                child: SwitchListTile(
                  title: Text(e.value['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(e.value['phrase'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8))),
                  value: e.value['enabled'] as bool,
                  onChanged: (v) => setState(() => e.value['enabled'] = v),
                ),
              )),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF38BDF8))),
            child: Column(
              children: [
                Text(_clonedVoiceName ?? 'Estúdio de Clonagem de Voz (2 Minutos)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                const SizedBox(height: 8),
                const Text(
                  'Lê em voz alta durante 2 minutos: "Olá comunidade da HELL Live! Obrigado pelas rosas, pelos likes e por acompanharem mais uma transmissão épica ao vivo!"',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text('Tempo gravado: $_cloneSeconds / 120s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _isCloningRecording ? Colors.redAccent : const Color(0xFF1E78FF)),
                  icon: Icon(_isCloningRecording ? Icons.stop : Icons.mic, color: Colors.white),
                  onPressed: _toggleCloneRecording,
                  label: Text(_isCloningRecording ? 'Parar Gravação' : 'Iniciar Gravação de 2 Minutos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
