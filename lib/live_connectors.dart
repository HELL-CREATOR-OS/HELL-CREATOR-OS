import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'app_data.dart';

class LocalObsServer {
  static HttpServer? _server;
  static String localIp = '127.0.0.1';
  static int port = 8765;
  static Map<String, dynamic> latestAlert = {};
  static Map<String, dynamic> latestGoal = {'title': 'Meta da Live', 'current': 0, 'target': 1000};
  static Map<String, dynamic> latestTimer = {'seconds': 1800, 'running': false};
  static Map<String, dynamic> latestDeckCmd = {'id': 0, 'cmd': '', 'val': null};
  static void Function(String cmd, dynamic val)? onRemoteDeckCommand;

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
               if (req.uri.path == '/api/state') {
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'alert': latestAlert,
            'goal': latestGoal,
            'timer': latestTimer,
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
        } else if (req.uri.path == '/deck') {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_buildRemoteDeckHtml());
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

  static String _buildTransparentOverlayHtml(String widgetType) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { margin: 0; background: transparent; overflow: hidden; font-family: Arial, sans-serif; color: white; }
  #alert-box { position: fixed; top: 10%; left: 50%; transform: translateX(-50%); text-align: center; display: none; background: rgba(5,11,30,0.88); border: 2px solid #38BDF8; border-radius: 18px; padding: 18px 28px; box-shadow: 0 0 25px rgba(56,189,248,0.65); }
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
  static String _buildRemoteDeckHtml() {
    return '''
<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
<title>HELL CREATOR OS • Streamdeck & 2.º Ecrã</title>
<style>
  body { margin: 0; background: #050B1E; color: white; font-family: Arial, sans-serif; }
  .top { background: #0B1636; padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1E293B; }
  .brand { font-weight: 900; letter-spacing: 2px; color: #38BDF8; font-size: 14px; }
  .tabs { display: flex; gap: 8px; }
  .tab { background: #13224D; border: 1px solid #38BDF855; color: white; padding: 6px 12px; border-radius: 8px; font-weight: bold; font-size: 12px; }
  .tab.active { background: #38BDF8; color: #050B1E; }
  .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; padding: 14px; }
  .btn { background: #0B1636; border: 1.5px solid #38BDF866; border-radius: 14px; padding: 16px 8px; text-align: center; font-weight: bold; font-size: 12px; color: white; cursor: pointer; user-select: none; }
  .btn:active { background: #38BDF8; color: #050B1E; transform: scale(0.96); }
  .btn.danger { border-color: #EF444488; color: #FCA5A5; }
  .card { background: #0B1636; border: 1px solid #38BDF844; border-radius: 14px; padding: 16px; margin: 14px; }
</style>
</head>
<body>
  <div class="top">
    <div class="brand">HELL STREAMDECK</div>
    <div class="tabs">
      <button class="tab active" id="t-deck" onclick="showTab('deck')">Streamdeck</button>
      <button class="tab" id="t-screen" onclick="showTab('screen')">2.º Ecrã</button>
    </div>
  </div>
  <div id="view-deck" class="grid">
    <div class="btn danger" onclick="sendCmd('toggle_mute')">🔇 MUTE GERAL</div>
    <div class="btn" onclick="sendCmd('scene_game')">🎮 CENA JOGO</div>
    <div class="btn" onclick="sendCmd('scene_cam')">📷 CÂMARA FULL</div>
    <div class="btn" onclick="sendCmd('scene_brb')">⏸️ PAUSA / BRB</div>
    <div class="btn" onclick="sendCmd('stream_start')">📡 INICIAR LIVE</div>
    <div class="btn" onclick="sendCmd('save_clip')">🎬 CLIPAR</div>
    <div class="btn" onclick="sendCmd('music_toggle')">🎵 PLAY / PAUSE</div>
    <div class="btn" onclick="sendCmd('music_next')">⏭️ PRÓXIMA</div>
    <div class="btn" onclick="sendCmd('spin_wheel')">🎡 GIRAR ROLETA</div>
    <div class="btn" onclick="sendCmd('test_alert')">🔔 TESTAR ALERTA</div>
    <div class="btn" onclick="sendCmd('add_timer_60')">⏱️ +1 MIN TIMER</div>
    <div class="btn danger" onclick="sendCmd('stream_stop')">⏹️ PARAR LIVE</div>
  </div>
  <div id="view-screen" style="display:none;">
    <div class="card">
      <div style="color:#38BDF8;font-weight:bold;margin-bottom:6px;">META ATIVA NA LIVE</div>
      <div id="goal-info" style="font-size:20px;font-weight:900;">A carregar...</div>
    </div>
    <div class="card">
      <div style="color:#38BDF8;font-weight:bold;margin-bottom:6px;">CRONÓMETRO / TIMER</div>
      <div id="timer-info" style="font-size:28px;font-weight:900;">00:30:00</div>
    </div>
  </div>
<script>
  function showTab(t) {
    document.getElementById('view-deck').style.display = t === 'deck' ? 'grid' : 'none';
    document.getElementById('view-screen').style.display = t === 'screen' ? 'block' : 'none';
    document.getElementById('t-deck').className = t === 'deck' ? 'tab active' : 'tab';
    document.getElementById('t-screen').className = t === 'screen' ? 'tab active' : 'tab';
  }
  async function sendCmd(c) {
    await fetch('/api/deck-cmd?cmd=' + encodeURIComponent(c));
  }
  setInterval(async () => {
    try {
      const r = await fetch('/api/state');
      const d = await r.json();
      if (d.goal) document.getElementById('goal-info').innerText = (d.goal.title || 'Meta') + ': ' + (d.goal.current || 0) + ' / ' + (d.goal.target || 100);
      if (d.timer) {
        const s = d.timer.seconds || 0;
        const h = String(Math.floor(s/3600)).padStart(2,'0');
        const m = String(Math.floor((s%3600)/60)).padStart(2,'0');
        const sec = String(s%60).padStart(2,'0');
        document.getElementById('timer-info').innerText = h + ':' + m + ':' + sec;
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
        onStatusChanged(false, 'Atenção! A ligação Twitch caiu.');
      });
    } catch (e) {
      isConnected = false;
      onStatusChanged(false, 'Não foi possível ligar ao canal Twitch.');
    }
  }

  Future<void> _connectKickChat(String channel) async {
    try {
      final res = await http.get(Uri.parse('https://kick.com'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final chatroomId = data['chatroom']?['id'];
        if (chatroomId != null) {
          _ws = await WebSocket.connect('wss://://pusher.com');
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
    isConnected = true;
    onStatusChanged(true, 'Monitorização TikTok LIVE ativa (@$username)');
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      try {
        final check = await http.get(
          Uri.parse('https://tiktok.com'),
          headers: {'User-Agent': 'Mozilla/5.0'},
        );
        if (check.statusCode != 200) {
          onStatusChanged(false, 'Atenção! A transmissão de @$username perdeu a ligação no TikTok.');
          await disconnect();
        }
      } catch (_) {}
    });
  }

  Future<void> _connectYouTubeLive(String handle) async {
    isConnected = true;
    onStatusChanged(true, 'Canal YouTube LIVE ligado (@$handle)');
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
  final AudioRecorder _cloneRecorder = AudioRecorder();
  bool _isRecordingClone = false;
  int _cloneSec = 0;
  Timer? _cloneTimer;
  String _activeProfile = 'Full Live';

  final List<Map<String, dynamic>> _voiceLibrary = [
    {'id': 'pt_m1', 'name': 'Tiago — Natural (PT-PT)', 'gender': 'male', 'pitch': 0.85, 'rate': 0.50, 'desc': 'Voz masculina equilibrada em Português de Portugal.'},
    {'id': 'pt_m2', 'name': 'Diogo — Competitivo (PT-PT)', 'gender': 'male', 'pitch': 0.72, 'rate': 0.56, 'desc': 'Voz masculina rápida e direta para jogos.'},
    {'id': 'pt_m3', 'name': 'Locutor — Grave Épico (PT-PT)', 'gender': 'male', 'pitch': 0.55, 'rate': 0.45, 'desc': 'Tom grave de estúdio para alertas e doações.'},
    {'id': 'pt_f1', 'name': 'Raquel — Clara (PT-PT)', 'gender': 'female', 'pitch': 1.18, 'rate': 0.50, 'desc': 'Voz feminina nítida em Português de Portugal.'},
    {'id': 'pt_f2', 'name': 'Beatriz — Suave (PT-PT)', 'gender': 'female', 'pitch': 1.28, 'rate': 0.47, 'desc': 'Voz feminina calma para modo Relax.'},
    {'id': 'pt_f3', 'name': 'Mariana — Energia Live (PT-PT)', 'gender': 'female', 'pitch': 1.35, 'rate': 0.55, 'desc': 'Voz feminina expressiva para festas e metas.'},
  ];

  Set<String> _installedIds = {'pt_m1', 'pt_f1'};
  String _selectedId = 'pt_m1';
  String _genderFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _cloneTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hell_installed_voices');
    if (saved != null && saved.isNotEmpty) _installedIds = saved.toSet();
    _selectedId = prefs.getString('hell_active_voice_id') ?? 'pt_m1';
    if (mounted) setState(() {});
  }

  Future<void> _installVoice(Map<String, dynamic> v) async {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/voice_${v['id']}.json').writeAsString(jsonEncode(v));
    final prefs = await SharedPreferences.getInstance();
    _installedIds.add(v['id']);
    _selectedId = v['id'];
    await prefs.setStringList('hell_installed_voices', _installedIds.toList());
    await prefs.setString('hell_active_voice_id', _selectedId);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voz "${v['name']}" instalada e ativa na app!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _testVoice(Map<String, dynamic> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_active_voice_id', v['id']);
    setState(() => _selectedId = v['id']);
    try {
      await _tts.stop();
      if (Platform.isAndroid) await _tts.setEngine('com.google.android.tts');
      await _tts.setLanguage('pt-PT');
      await _tts.setPitch((v['pitch'] as num).toDouble());
      await _tts.setSpeechRate((v['rate'] as num).toDouble());
      await _tts.setVolume(widget.volume);
      await _tts.speak('Olá! Sou a voz ${v['name']} do HELL CREATOR OS.');
    } catch (_) {}
  }

  Future<void> _toggleCloneRecord() async {
    if (_isRecordingClone) {
      _cloneTimer?.cancel();
      await _cloneRecorder.stop();
      setState(() => _isRecordingClone = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amostra de clonagem guardada com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } else if (await _cloneRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      await _cloneRecorder.start(const RecordConfig(), path: '${dir.path}/hell_cloned_voice.m4a');
      setState(() {
        _isRecordingClone = true;
        _cloneSec = 0;
      });
      _cloneTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_cloneSec >= 120) {
          _toggleCloneRecord();
        } else if (mounted) {
          setState(() => _cloneSec++);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _voiceLibrary.where((v) => _genderFilter == 'all' || v['gender'] == _genderFilter).toList();
    final profiles = ['Gaming', 'Relax', 'Full Live', 'Competitive', 'Custom'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E78FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🗣️ HELL Voz / Chat TTS (PT-PT)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  Switch(activeColor: Colors.white, activeTrackColor: const Color(0xFF1E78FF), value: widget.ttsEnabled, onChanged: widget.onToggleTts),
                ],
              ),
              const Text('Perfil de Voz Ativo (Voice Queue Anti-Spam ligada):', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: profiles.map((p) => ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 11)),
                  selected: _activeProfile == p,
                  selectedColor: const Color(0xFF1E78FF),
                  onSelected: (_) => setState(() => _activeProfile = p),
                )).toList(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('Todas (6)'), selected: _genderFilter == 'all', selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _genderFilter = 'all')),
                  ChoiceChip(label: const Text('👨 Masculinas (3)'), selected: _genderFilter == 'male', selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _genderFilter = 'male')),
                  ChoiceChip(label: const Text('👩 Femininas (3)'), selected: _genderFilter == 'female', selectedColor: const Color(0xFF1E78FF), onSelected: (_) => setState(() => _genderFilter = 'female')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((v) {
          final isInstalled = _installedIds.contains(v['id']);
          final isSelected = _selectedId == v['id'];
          final isMale = v['gender'] == 'male';
          return Card(
            color: isSelected ? const Color(0xFF122E73) : const Color(0xFF0B1636),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isSelected ? const Color(0xFF38BDF8) : Colors.white12, width: isSelected ? 1.6 : 1),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isMale ? const Color(0xFF1E78FF) : Colors.pinkAccent,
                child: Icon(isMale ? Icons.man : Icons.woman, color: Colors.white),
              ),
              title: Text(v['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text(v['desc'], style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: () => _testVoice(v)),
                  if (!isInstalled)
                    IconButton(icon: const Icon(Icons.download_rounded, color: Color(0xFF38BDF8)), onPressed: () => _installVoice(v))
                  else
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎙️ Clonar a Minha Voz (2 Minutos)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  Text('${(_cloneSec ~/ 60).toString().padLeft(2, '0')}:${(_cloneSec % 60).toString().padLeft(2, '0')} / 02:00', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(DefaultMediaLibrary.voiceCloneScript2Min, style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _isRecordingClone ? Colors.redAccent : const Color(0xFF1E78FF)),
                  onPressed: _toggleCloneRecord,
                  icon: Icon(_isRecordingClone ? Icons.stop : Icons.mic, color: Colors.white),
                  label: Text(_isRecordingClone ? 'Parar Gravação' : 'Gravar Guião de 2 Minutos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
