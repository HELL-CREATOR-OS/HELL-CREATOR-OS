import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DonationMethodsStore {
  static String creatorName = 'HELL Live Creator';
  static bool mbwayEnabled = true;
  static String mbwayPhone = '';
  static bool paypalEnabled = true;
  static String paypalLink = '';
  static bool revolutEnabled = true;
  static String revolutLink = '';
  static bool pixEnabled = false;
  static String pixKey = '';
}

class LocalObsServer {
  static HttpServer? _server;
  static String localIp = '127.0.0.1';
  static const int port = 8095;
  static Map<String, dynamic> latestAlert = {};
  static Map<String, dynamic> latestWheelState = {'spinning': false, 'winner': '', 'options': []};
  static Map<String, dynamic> latestCreditsState = {'active': false, 'lines': []};

  static Future<void> start() async {
    if (_server != null) return;
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
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
            'wheel': latestWheelState,
            'credits': latestCreditsState,
          }));
        } else if (path == '/donate') {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_buildDonateHtml());
        } else {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_buildOverlayHtml());
        }
        await req.response.close();
      });
    } catch (_) {}
  }

  static void pushAlert(String title, String subtitle, String mediaUrl) {
    latestAlert = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'subtitle': subtitle,
      'media': mediaUrl,
    };
  }

  static void pushWheelSpin(List<String> options, String winner) {
    latestWheelState = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'spinning': true,
      'options': options,
      'winner': winner,
    };
  }

  static void pushCreditsRoll(List<String> lines) {
    latestCreditsState = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'active': true,
      'lines': lines,
    };
  }
  static String _buildDonateHtml() {
    final btns = StringBuffer();
    if (DonationMethodsStore.mbwayEnabled && DonationMethodsStore.mbwayPhone.isNotEmpty) {
      btns.writeln('<div class="card"><h3>📱 MB WAY</h3><p>Número: <b>${DonationMethodsStore.mbwayPhone}</b></p><button onclick="navigator.clipboard.writeText(\'${DonationMethodsStore.mbwayPhone}\');alert(\'Número MB WAY copiado!\')">Copiar Número MB WAY</button></div>');
    }
    if (DonationMethodsStore.paypalEnabled && DonationMethodsStore.paypalLink.isNotEmpty) {
      final url = DonationMethodsStore.paypalLink.startsWith('http') ? DonationMethodsStore.paypalLink : 'https://${DonationMethodsStore.paypalLink}';
      btns.writeln('<div class="card"><h3>💳 PayPal</h3><a class="btn" href="$url" target="_blank">Apoiar via PayPal</a></div>');
    }
    if (DonationMethodsStore.revolutEnabled && DonationMethodsStore.revolutLink.isNotEmpty) {
      final url = DonationMethodsStore.revolutLink.startsWith('http') ? DonationMethodsStore.revolutLink : 'https://${DonationMethodsStore.revolutLink}';
      btns.writeln('<div class="card"><h3>⚡ Revolut</h3><a class="btn" href="$url" target="_blank">Apoiar via Revolut</a></div>');
    }
    if (DonationMethodsStore.pixEnabled && DonationMethodsStore.pixKey.isNotEmpty) {
      btns.writeln('<div class="card"><h3>💠 PIX</h3><p>Chave: <b>${DonationMethodsStore.pixKey}</b></p><button onclick="navigator.clipboard.writeText(\'${DonationMethodsStore.pixKey}\');alert(\'Chave PIX copiada!\')">Copiar Chave PIX</button></div>');
    }
    return '''
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Apoiar ${DonationMethodsStore.creatorName} · HELL Live</title>
<style>
body{background:#050B1E;color:#fff;font-family:sans-serif;text-align:center;padding:24px}
.wrap{max-width:440px;margin:auto;background:#0B1636;padding:22px;border-radius:18px;border:1px solid #38BDF8}
.card{background:#122E73;padding:14px;border-radius:12px;margin-top:12px}
.btn,button{display:inline-block;background:#1E78FF;color:#fff;padding:10px 18px;border-radius:10px;text-decoration:none;border:none;font-weight:bold;cursor:pointer;margin-top:6px}
</style></head><body><div class="wrap"><h2>🔥 Apoiar ${DonationMethodsStore.creatorName}</h2><p>Escolhe o teu método preferido de apoio direto:</p>$btns</div></body></html>
''';
  }

  static String _buildOverlayHtml() {
    return '''
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body{margin:0;background:transparent;overflow:hidden;font-family:sans-serif;color:#fff}
#box{position:fixed;top:36px;left:50%;transform:translateX(-50%);background:rgba(8,17,43,0.92);border:2px solid #38BDF8;border-radius:18px;padding:16px 28px;text-align:center;display:none;box-shadow:0 0 24px rgba(56,189,248,0.5)}
#box img{height:76px;margin-bottom:8px}
#credits{position:fixed;bottom:-100%;left:50%;transform:translateX(-50%);text-align:center;width:80%;font-size:24px;font-weight:bold;text-shadow:0 2px 8px #000}
@keyframes rollUp{0%{bottom:-60%}100%{bottom:110%}}
</style></head><body>
<div id="box"><img id="m" src=""><h2 id="t" style="margin:0;color:#38BDF8"></h2><p id="s" style="margin:4px 0 0"></p></div>
<div id="credits"></div>
<script>
let lastId=0,lastCred=0;
setInterval(async()=>{
  try{
    const r=await fetch('/api/state');const d=await r.json();
    if(d.alert && d.alert.id && d.alert.id!==lastId){
      lastId=d.alert.id;
      document.getElementById('m').src=d.alert.media||'';
      document.getElementById('t').innerText=d.alert.title||'';
      document.getElementById('s').innerText=d.alert.subtitle||'';
      const b=document.getElementById('box');b.style.display='block';
      setTimeout(()=>b.style.display='none',5500);
    }
    if(d.credits && d.credits.active && d.credits.id!==lastCred){
      lastCred=d.credits.id;
      const c=document.getElementById('credits');
      c.innerHTML=(d.credits.lines||[]).map(x=>'<div>'+x+'</div>').join('<br>');
      c.style.animation='rollUp 18s linear forwards';
    }
  }catch(e){}
},1000);
</script></body></html>
''';
  }
}
class MultiPlatformLiveConnector {
  WebSocket? _ws;
  Timer? _pollTimer;
  String? _lastYoutubeMsgId;

  final Function(String platform, String user, String message) onChatMessage;
  final Function(String platform, String user, String giftCode, String giftName, int coins) onGiftReceived;
  final Function(String platform, String user, String eventType) onSocialEvent;
  final Function(String statusText) onConnectionStatus;

  MultiPlatformLiveConnector({
    required this.onChatMessage,
    required this.onGiftReceived,
    required this.onSocialEvent,
    required this.onConnectionStatus,
  });

  Future<void> connectTwitch(String channel) async {
    disconnect();
    final clean = channel.replaceAll('@', '').trim().toLowerCase();
    if (clean.isEmpty) return;
    onConnectionStatus('A ligar ao chat IRC da Twitch ($clean)...');
    try {
      _ws = await WebSocket.connect('wss://irc-ws.chat.twitch.tv:443');
      _ws!.add('CAP REQ :twitch.tv/tags twitch.tv/commands');
      _ws!.add('PASS SCHMOOPIIE');
      _ws!.add('NICK justinfan${DateTime.now().millisecond + 1000}');
      _ws!.add('JOIN #$clean');
      onConnectionStatus('Ligado em direto à Twitch (#$clean)');

      _ws!.listen((raw) {
        final lines = raw.toString().split('\r\n');
        for (final line in lines) {
          if (line.startsWith('PING')) {
            _ws?.add('PONG :tmi.twitch.tv');
          } else if (line.contains('PRIVMSG #$clean :')) {
            final idx = line.indexOf('PRIVMSG #$clean :');
            final msg = line.substring(idx + 'PRIVMSG #$clean :'.length).trim();
            final userMatch = RegExp(r'display-name=([^;]+)').firstMatch(line);
            final user = userMatch?.group(1) ?? 'Viewer';
            onChatMessage('Twitch', user, msg);
          } else if (line.contains('USERNOTICE #$clean')) {
            final userMatch = RegExp(r'display-name=([^;]+)').firstMatch(line);
            final user = userMatch?.group(1) ?? 'Subscritor';
            onSocialEvent('Twitch', user, 'sub');
          }
        }
      }, onDone: () => onConnectionStatus('Ligação Twitch terminada.'));
    } catch (e) {
      onConnectionStatus('Erro ao ligar à Twitch: $e');
    }
  }

  Future<void> connectKick(String chatroomIdOrUser) async {
    disconnect();
    final clean = chatroomIdOrUser.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    onConnectionStatus('A obter sala Kick de $clean...');
    try {
      String roomId = clean;
      if (int.tryParse(clean) == null) {
        final res = await http.get(Uri.parse('https://kick.com'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          roomId = (data['chatroom']?['id'] ?? clean).toString();
        }
      }
      _ws = await WebSocket.connect('wss://://pusher.com');
      _ws!.listen((raw) {
        final decoded = jsonDecode(raw.toString());
        final event = decoded['event']?.toString() ?? '';
        if (event == 'pusher:connection_established') {
          _ws?.add(jsonEncode({
            'event': 'pusher:subscribe',
            'data': {'auth': '', 'channel': 'chatrooms.$roomId.v2'}
          }));
          onConnectionStatus('Ligado em direto à Kick (Sala $roomId)');
        } else if (event == 'App\\Events\\ChatMessageEvent') {
          final payload = jsonDecode(decoded['data'].toString());
          final user = payload['sender']?['username'] ?? 'KickUser';
          final msg = payload['content'] ?? '';
          onChatMessage('Kick', user, msg);
        }
      });
    } catch (e) {
      onConnectionStatus('Erro ao ligar à Kick: $e');
    }
  }

  Future<void> connectYouTube(String videoIdOrUrl, String apiKey) async {
    disconnect();
    String vid = videoIdOrUrl.trim();
    if (vid.contains('v=')) {
      vid = Uri.tryParse(vid)?.queryParameters['v'] ?? vid;
    } else if (vid.contains('youtu.be/')) {
      vid = vid.split('youtu.be/').last.split('?').first;
    }
    if (vid.isEmpty || apiKey.trim().isEmpty) {
      onConnectionStatus('Introduz o ID do vídeo YouTube e a API Key.');
      return;
    }
    try {
      final vRes = await http.get(Uri.parse('https://googleapis.com'));
      final vData = jsonDecode(vRes.body);
      final chatId = vData['items']?.first?['liveStreamingDetails']?['activeLiveChatId'];
      if (chatId == null) {
        onConnectionStatus('Live Chat do YouTube não encontrado para este ID.');
        return;
      }
      onConnectionStatus('Ligado em direto ao YouTube Live!');
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final cRes = await http.get(Uri.parse('https://googleapis.com'));
        if (cRes.statusCode == 200) {
          final items = List<Map<String, dynamic>>.from(jsonDecode(cRes.body)['items'] ?? []);
          for (final item in items) {
            final id = item['id']?.toString() ?? '';
            if (_lastYoutubeMsgId == id) continue;
            _lastYoutubeMsgId = id;
            final user = item['authorDetails']?['displayName'] ?? 'YouTuber';
            final msg = item['snippet']?['displayMessage'] ?? '';
            onChatMessage('YouTube', user, msg);
          }
        }
      });
    } catch (e) {
      onConnectionStatus('Erro YouTube API: $e');
    }
  }

  Future<void> connectTikTokBridge(String username, {String bridgeUrl = 'ws://127.0.0.1:21213/'}) async {
    disconnect();
    final clean = username.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    onConnectionStatus('A ligar ao TikTok Live (@$clean)...');
    try {
      _ws = await WebSocket.connect(bridgeUrl);
      _ws!.listen((raw) {
        final data = jsonDecode(raw.toString());
        final event = (data['event'] ?? '').toString().toLowerCase();
        final payload = data['data'] ?? data;
        final user = (payload['nickname'] ?? payload['uniqueId'] ?? 'Seguidor').toString();

        if (event == 'chat') {
          onChatMessage('TikTok', user, (payload['comment'] ?? '').toString());
        } else if (event == 'gift') {
          final giftName = (payload['giftName'] ?? 'Presente').toString();
          final giftCode = (payload['giftId'] ?? giftName.toLowerCase()).toString();
          final coins = int.tryParse((payload['diamondCount'] ?? payload['coins'] ?? '1').toString()) ?? 1;
          onGiftReceived('TikTok', user, giftCode, giftName, coins);
        } else if (event == 'like') {
          onSocialEvent('TikTok', user, 'like');
        } else if (event == 'follow') {
          onSocialEvent('TikTok', user, 'follow');
        } else if (event == 'share') {
          onSocialEvent('TikTok', user, 'share');
        }
      }, onDone: () => onConnectionStatus('Ponte TikTok desligada.'));
      onConnectionStatus('Ligado em direto ao TikTok (@$clean)');
    } catch (_) {
      onConnectionStatus('TikTok (@$clean) pronto · Aguardando ponte TikFinity/EulerStream local (porta 21213).');
    }
  }

  void disconnect() {
    _pollTimer?.cancel();
    _ws?.close();
    _ws = null;
  }
}
class GoogleVoiceAndModulatorService {
  static String activeModulator = 'normal';
  static bool antiTrollEnabled = true;
  static bool blockLinksEnabled = true;
  static final List<String> blockedWords = [
    'merda', 'caralho', 'foda', 'puta', 'cabrao', 'cabrão', 'paneleiro', 'filho da puta',
    'fuck', 'shit', 'bitch', 'asshole', 'nigger', 'faggot', 'retard', 'scam', 'http://', 'https://', 'www.'
  ];

  static String? filterChatMessage(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!antiTrollEnabled) return text;
    final lower = text.toLowerCase();
    if (blockLinksEnabled && (lower.contains('http://') || lower.contains('https://') || lower.contains('www.') || lower.contains('.com/'))) {
      return null;
    }
    for (final w in blockedWords) {
      if (w.isNotEmpty && lower.contains(w.toLowerCase())) {
        return null;
      }
    }
    return text;
  }

  static bool isFemaleGoogleVoice(Map<String, String> v) {
    final id = ('${v['name'] ?? ''} ${v['identifier'] ?? ''}').toLowerCase();
    const femaleTokens = [
      'sfs', 'afs', 'tpf', 'sfg', 'iol', 'iob', 'ptg', 'ptf', 'esd', 'esf',
      'female', 'feminina', 'woman', 'girl', 'joana', 'ines', 'inês', 'helga',
      'lucia', 'maria', 'sofia', 'camila', 'vitoria', 'vitória', 'sara', 'clara', 'ana', 'emma', 'ava', 'zoe'
    ];
    const maleTokens = [
      'jfb', 'iom', 'tpd', 'ptm', 'esm', 'male', 'masculina', 'man', 'boy',
      'duarte', 'cristiano', 'diogo', 'ricardo', 'antonio', 'antónio', 'carlos', 'miguel', 'pedro', 'joao', 'joão', 'daniel', 'david', 'liam'
    ];
    for (final m in maleTokens) {
      if (id.contains(m)) return false;
    }
    for (final f in femaleTokens) {
      if (id.contains(f)) return true;
    }
    return id.hashCode.isEven;
  }

  static Future<void> applyModulatorPreset(FlutterTts tts, String preset, {double basePitch = 1.0, double baseRate = 0.50}) async {
    activeModulator = preset;
    switch (preset) {
      case 'deep_epic':
        await tts.setPitch(0.62);
        await tts.setSpeechRate((baseRate * 0.88).clamp(0.25, 0.9));
        break;
      case 'robot':
        await tts.setPitch(0.78);
        await tts.setSpeechRate((baseRate * 0.95).clamp(0.25, 0.9));
        break;
      case 'radio':
        await tts.setPitch(1.22);
        await tts.setSpeechRate((baseRate * 1.12).clamp(0.3, 1.0));
        break;
      case 'stadium':
        await tts.setPitch(0.85);
        await tts.setSpeechRate((baseRate * 0.84).clamp(0.25, 0.9));
        break;
      default:
        await tts.setPitch(basePitch);
        await tts.setSpeechRate(baseRate);
    }
  }
}
class ChatTtsScreen extends StatefulWidget {
  final FlutterTts flutterTts;
  final List<Map<String, String>> chatLog;
  final bool ttsEnabled;
  final ValueChanged<bool> onToggleTts;
  final String selectedVoiceName;
  final ValueChanged<Map<String, String>> onSelectVoice;

  const ChatTtsScreen({
    super.key,
    required this.flutterTts,
    required this.chatLog,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.selectedVoiceName,
    required this.onSelectVoice,
  });

  @override
  State<ChatTtsScreen> createState() => _ChatTtsScreenState();
}

class _ChatTtsScreenState extends State<ChatTtsScreen> {
  List<Map<String, String>> _allGoogleVoices = [];
  String _genderFilter = 'all';
  String _searchQuery = '';
  double _pitch = 1.0;
  double _rate = 0.50;
  final _testVoiceCtrl = TextEditingController(text: 'Olá pessoal! Bem-vindos à live da HELL Live!');
  final _badWordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRealGoogleVoices();
  }

  Future<void> _loadRealGoogleVoices() async {
    try {
      final raw = await widget.flutterTts.getVoices;
      if (raw is List) {
        final parsed = <Map<String, String>>[];
        for (final item in raw) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            final locale = (item['locale'] ?? '').toString();
            if (name.isEmpty) continue;
            final isFemale = GoogleVoiceAndModulatorService.isFemaleGoogleVoice({'name': name, 'locale': locale});
            parsed.add({
              'name': name,
              'locale': locale,
              'gender': isFemale ? 'female' : 'male',
              'label': '${isFemale ? "👩 Feminina" : "👨 Masculina"} · $name ($locale)',
            });
          }
        }
        if (mounted) setState(() => _allGoogleVoices = parsed);
      }
    } catch (_) {}
  }

  Future<void> _previewVoice(Map<String, String> v) async {
    await widget.flutterTts.stop();
    await widget.flutterTts.setVoice({'name': v['name']!, 'locale': v['locale']!});
    await GoogleVoiceAndModulatorService.applyModulatorPreset(
      widget.flutterTts,
      GoogleVoiceAndModulatorService.activeModulator,
      basePitch: _pitch,
      baseRate: _rate,
    );
    await widget.flutterTts.speak(_testVoiceCtrl.text.trim().isEmpty ? 'Teste de voz Google oficial.' : _testVoiceCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allGoogleVoices.where((v) {
      if (_genderFilter != 'all' && v['gender'] != _genderFilter) return false;
      if (_searchQuery.isNotEmpty && !v['label']!.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SwitchListTile(
          tileColor: const Color(0xFF0B1636),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Leitura Automática do Chat (Vozes Reais Google)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: Text('Voz ativa: ${widget.selectedVoiceName.isEmpty ? "Padrão Google do Sistema" : widget.selectedVoiceName}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8))),
          value: widget.ttsEnabled,
          onChanged: widget.onToggleTts,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E78FF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎙️ Modulador de Voz em Tempo Real (Voice Changer)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 13.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _modChip('normal', '🎤 Normal'),
                  _modChip('deep_epic', '🦍 Voz Grave Épica'),
                  _modChip('robot', '🤖 Robô Metálico'),
                  _modChip('radio', '📻 Rádio / Walkie-Talkie'),
                  _modChip('stadium', '🏟️ Eco de Estádio'),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _testVoiceCtrl,
                decoration: InputDecoration(
                  labelText: 'Frase de Teste da Voz',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.greenAccent),
                    onPressed: () async {
                      await GoogleVoiceAndModulatorService.applyModulatorPreset(
                        widget.flutterTts,
                        GoogleVoiceAndModulatorService.activeModulator,
                        basePitch: _pitch,
                        baseRate: _rate,
                      );
                      await widget.flutterTts.speak(_testVoiceCtrl.text);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🛡️ Filtro Anti-Palavrões & Anti-Spam (Proteção da Live)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13.5)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear Palavrões e Insultos antes de ler', style: TextStyle(fontSize: 12.5)),
                value: GoogleVoiceAndModulatorService.antiTrollEnabled,
                onChanged: (v) => setState(() => GoogleVoiceAndModulatorService.antiTrollEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear Links e Spam automaticamente', style: TextStyle(fontSize: 12.5)),
                value: GoogleVoiceAndModulatorService.blockLinksEnabled,
                onChanged: (v) => setState(() => GoogleVoiceAndModulatorService.blockLinksEnabled = v),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _badWordCtrl, decoration: const InputDecoration(hintText: 'Adicionar palavra proibida...', isDense: true))),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.redAccent),
                    onPressed: () {
                      final w = _badWordCtrl.text.trim();
                      if (w.isNotEmpty) {
                        setState(() {
                          GoogleVoiceAndModulatorService.blockedWords.add(w);
                          _badWordCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('🗣️ Vozes Oficiais Google (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8)))),
            IconButton(
              tooltip: 'Atualizar Lista de Vozes Google',
              icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
              onPressed: _loadRealGoogleVoices,
            ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://google.com'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Pacotes Google', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        Row(
          children: [
            ChoiceChip(label: const Text('Todas'), selected: _genderFilter == 'all', onSelected: (_) => setState(() => _genderFilter = 'all')),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text('👨 Masculinas'), selected: _genderFilter == 'male', onSelected: (_) => setState(() => _genderFilter = 'male')),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text('👩 Femininas'), selected: _genderFilter == 'female', onSelected: (_) => setState(() => _genderFilter = 'female')),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(hintText: 'Pesquisar por idioma (pt-PT, pt-BR, en-US, es-ES)...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        ...filtered.map((v) {
          final isSel = widget.selectedVoiceName == v['name'];
          return Card(
            color: isSel ? const Color(0xFF122E73) : const Color(0xFF0B1636),
            child: ListTile(
              dense: true,
              leading: Icon(v['gender'] == 'female' ? Icons.face_3 : Icons.face, color: v['gender'] == 'female' ? Colors.pinkAccent : const Color(0xFF38BDF8)),
              title: Text(v['label']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent), onPressed: () => _previewVoice(v)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: isSel ? Colors.green : const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () {
                      widget.onSelectVoice(v);
                      _previewVoice(v);
                    },
                    child: Text(isSel ? 'Ativa' : 'Usar', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _modChip(String id, String label) {
    final active = GoogleVoiceAndModulatorService.activeModulator == id;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: active,
      selectedColor: const Color(0xFF1E78FF),
      onSelected: (_) => setState(() => GoogleVoiceAndModulatorService.activeModulator = id),
    );
  }
}
