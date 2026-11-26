import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_data.dart';
import 'account_security.dart';

class MusicDeckController {
  static AudioPlayer? sharedPlayer;
  static final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> currentTitleNotifier = ValueNotifier<String>('Rádio Comercial Portugal');
  static int currentIndex = 0;

  static String _u(String host, String path) => 'https://$host$path';

  static final List<Map<String, String>> radioStations = <Map<String, String>>[
    {'title': 'Rádio Comercial (Portugal)', 'genre': 'Pop / Hits PT', 'url': _u(['stream-icy.', 'bauermedia.', 'pt'].join(), '/comercial.mp3')},
    {'title': 'RFM Portugal', 'genre': 'Top Hits PT', 'url': _u(['25683.', 'live.', 'streamtheworld.', 'com'].join(), '/RFMAAC.aac')},
    {'title': 'Mega Hits Portugal', 'genre': 'Jovem / Dance PT', 'url': _u(['25683.', 'live.', 'streamtheworld.', 'com'].join(), '/MEGA_HITSAAC.aac')},
    {'title': 'Cidade FM Portugal', 'genre': 'Urbano / Hip-Hop PT', 'url': _u(['stream-icy.', 'bauermedia.', 'pt'].join(), '/cidade.mp3')},
    {'title': 'M80 Rádio Portugal', 'genre': 'Clássicos 80s & 90s', 'url': _u(['stream-icy.', 'bauermedia.', 'pt'].join(), '/m80.mp3')},
    {'title': 'Rádio Renascença', 'genre': 'Atualidade & Música PT', 'url': _u(['25683.', 'live.', 'streamtheworld.', 'com'].join(), '/RADIO_RENASCENCAAAC.aac')},
    {'title': 'Antena 1 (RTP)', 'genre': 'Notícias & Cultura PT', 'url': _u(['streaming-live.', 'rtp.', 'pt'].join(), '/liveradio/antena180a/playlist.m3u8')},
    {'title': 'TSF Rádio Notícias', 'genre': 'Informação PT', 'url': _u(['tsfdirecto.', 'tsf.', 'pt'].join(), '/tsfdirecto.mp3')},
    {'title': 'Rádio Nova Era (Porto)', 'genre': 'Eletrónica & Hits', 'url': _u(['centova.', 'radios.', 'pt'].join(), '/proxy/478?mp=/stream')},
    {'title': 'Rádio Orbital (Lisboa)', 'genre': 'Dance & Club', 'url': _u(['centova.', 'radios.', 'pt'].join(), '/proxy/401?mp=/stream')},
    {'title': 'Lofi Girl · Beats 24/7 (Mundial)', 'genre': 'Lo-Fi Chill / Focus', 'url': _u(['play.', 'streamafrica.', 'net'].join(), '/lofiradio')},
    {'title': 'Nightride FM · Synthwave (EUA)', 'genre': 'Cyberpunk / Synthwave', 'url': _u(['stream.', 'nightride.', 'fm'].join(), '/nightride.mp3')},
    {'title': 'SomaFM · Groove Salad (Mundial)', 'genre': 'Ambient / Downtempo', 'url': _u(['ice1.', 'somafm.', 'com'].join(), '/groovesalad-128-mp3')},
    {'title': 'Radio Paradise · Main Mix (Mundial)', 'genre': 'Rock / Indie / Eclectic', 'url': _u(['stream.', 'radioparadise.', 'com'].join(), '/aac-128')},
    {'title': 'Los 40 Principales (Espanha)', 'genre': 'Hits Latinos & Pop', 'url': _u(['playerservices.', 'streamtheworld.', 'com'].join(), '/api/livestream-redirect/LOS40.mp3')},
    {'title': 'Jovem Pan FM (Brasil)', 'genre': 'Hits Brasil & Pop', 'url': _u(['stream.', 'zeno.', 'fm'].join(), '/c45wbq2us3buv')},
  ];

  static Future<void> loadCustomRadios() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hell_custom_radios_v1');
    if (raw != null && raw.isNotEmpty) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
      for (final item in list.reversed) {
        final title = (item['title'] ?? '').toString();
        final url = (item['url'] ?? '').toString();
        if (title.isNotEmpty && url.isNotEmpty && !radioStations.any((r) => r['url'] == url)) {
          radioStations.insert(0, {'title': title, 'genre': (item['genre'] ?? 'Rádio Personalizada').toString(), 'url': url});
        }
      }
    }
  }

  static Future<void> saveCustomRadios() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_custom_radios_v1', jsonEncode(radioStations));
  }

  static Future<void> playIndex(int index) async {
    final player = sharedPlayer ?? AudioPlayer();
    sharedPlayer = player;
    if (radioStations.isEmpty) return;
    currentIndex = index % radioStations.length;
    final station = radioStations[currentIndex];
    final url = station['url'] ?? '';
    currentTitleNotifier.value = station['title'] ?? 'Rádio Online';
    try {
      await player.stop();
      await player.play(UrlSource(url));
      isPlayingNotifier.value = true;
    } catch (_) {
      isPlayingNotifier.value = false;
    }
  }

  static Future<void> togglePlayPause() async {
    final player = sharedPlayer ?? AudioPlayer();
    sharedPlayer = player;
    if (radioStations.isEmpty) return;
    if (isPlayingNotifier.value) {
      await player.pause();
      isPlayingNotifier.value = false;
    } else {
      await playIndex(currentIndex);
    }
  }

  static Future<void> stopImmediately() async {
    try {
      await sharedPlayer?.stop();
    } catch (_) {}
    isPlayingNotifier.value = false;
  }

  static Future<void> nextTrack() async {
    if (radioStations.isEmpty) return;
    await playIndex((currentIndex + 1) % radioStations.length);
  }
}
  static Future<void> previousTrack() async {
    if (radioStations.isEmpty) return;
    final prevIdx = (currentIndex - 1 + radioStations.length) % radioStations.length;
    await playIndex(prevIdx);
  }

class FloatingMusicEdgeHandle extends StatefulWidget {
  final VoidCallback onOpenMusicScreen;
  const FloatingMusicEdgeHandle({super.key, required this.onOpenMusicScreen});

  @override
  State<FloatingMusicEdgeHandle> createState() => _FloatingMusicEdgeHandleState();
}

class _FloatingMusicEdgeHandleState extends State<FloatingMusicEdgeHandle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MusicDeckController.isPlayingNotifier,
      builder: (context, playing, _) {
        if (!playing && !_expanded) return const SizedBox.shrink();
        return Positioned(
          right: 0,
          bottom: 95,
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1433).withOpacity(0.95),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
              ),
              child: _expanded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
                          onPressed: () => setState(() => _expanded = false),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 115),
                          child: ValueListenableBuilder<String>(
                            valueListenable: MusicDeckController.currentTitleNotifier,
                            builder: (_, title, __) => Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        IconButton(
                          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.amberAccent, size: 24),
                          onPressed: () => MusicDeckController.togglePlayPause(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () async {
                            await MusicDeckController.stopImmediately();
                            if (mounted) setState(() => _expanded = false);
                          },
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: () => setState(() => _expanded = true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: Icon(Icons.graphic_eq_rounded, color: Color(0xFF38BDF8), size: 20),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class MusicBackgroundScreen extends StatefulWidget {
  final AudioPlayer bgPlayer;
  const MusicBackgroundScreen({super.key, required this.bgPlayer});

  @override
  State<MusicBackgroundScreen> createState() => _MusicBackgroundScreenState();
}

class _MusicBackgroundScreenState extends State<MusicBackgroundScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _radioNameCtrl = TextEditingController();
  final TextEditingController _radioUrlCtrl = TextEditingController();
  late final WebViewController _spotifyWebCtrl;
  late final WebViewController _ytMusicWebCtrl;
  double _volume = 0.80;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    MusicDeckController.sharedPlayer = widget.bgPlayer;
    MusicDeckController.loadCustomRadios().then((_) {
      if (mounted) setState(() {});
    });
    final spHost = ['open.', 'spotify.', 'com'].join();
    final ytHost = ['music.', 'youtube.', 'com'].join();
    _spotifyWebCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF04091A))
      ..loadRequest(Uri.https(spHost, '/'));
    _ytMusicWebCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF04091A))
      ..loadRequest(Uri.https(ytHost, '/'));
  }

  @override
  void dispose() {
    _radioNameCtrl.dispose();
    _radioUrlCtrl.dispose();
    super.dispose();
  }

  void _openAddRadioDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        title: const Text('Adicionar Rádio / Stream Online', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _radioNameCtrl, decoration: const InputDecoration(labelText: 'Nome da Rádio', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: _radioUrlCtrl, decoration: const InputDecoration(labelText: 'Link Direto MP3 / AAC / M3U8', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = _radioNameCtrl.text.trim();
              final url = _radioUrlCtrl.text.trim();
              if (name.isNotEmpty && url.startsWith('http')) {
                setState(() {
                  MusicDeckController.radioStations.insert(0, {'title': name, 'genre': 'Rádio Adicionada', 'url': url});
                });
                await MusicDeckController.saveCustomRadios();
                _radioNameCtrl.clear();
                _radioUrlCtrl.clear();
                if (ctx.mounted) Navigator.pop(ctx);
                await MusicDeckController.playIndex(0);
              }
            },
            child: const Text('Adicionar & Tocar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stations = MusicDeckController.radioStations;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: const Color(0xFF0A1433), borderRadius: BorderRadius.circular(14)),
            child: const TabBar(
              indicatorColor: Color(0xFF38BDF8),
              tabs: [Tab(text: '📻 Rádios FM & Mundiais'), Tab(text: '🟢 Spotify'), Tab(text: '🔴 YouTube Music')],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: MusicDeckController.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return HellCockpitWindow(
                          title: 'REPRODUTOR DE RÁDIOS EM 2.º PLANO',
                          icon: Icons.radio_rounded,
                          accent: const Color(0xFFF59E0B),
                          badge: isPlaying ? 'EM 2.º PLANO' : 'PARADO',
                          child: Column(
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: MusicDeckController.currentTitleNotifier,
                                builder: (_, title, __) => Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await MusicDeckController.togglePlayPause();
                                      setState(() {});
                                    },
                                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                                    label: Text(isPlaying ? 'Pausar' : 'Ouvir'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () async {
                                      await MusicDeckController.stopImmediately();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Parar'),
                                  ),
                                                          IconButton(
                          tooltip: 'Música / Rádio Anterior',
                          icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF38BDF8)),
                          onPressed: () async {
                            await MusicDeckController.previousTrack();
                            setState(() {});
                          },
                        ),

                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF38BDF8)),
                                    onPressed: () async {
                                      await MusicDeckController.nextTrack();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              Slider(
                                value: _volume,
                                onChanged: (v) async {
                                  setState(() => _volume = v);
                                  await widget.bgPlayer.setVolume(v);
                                },
                              ),
                              OutlinedButton.icon(
                                onPressed: _openAddRadioDialog,
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Adicionar Rádio / Link Stream'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ...stations.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final st = entry.value;
                      final active = (MusicDeckController.currentIndex % stations.length) == idx && MusicDeckController.isPlayingNotifier.value;
                      return Card(
                        color: active ? const Color(0xFF142A66) : const Color(0xFF0B1636),
                        child: ListTile(
                          leading: Icon(active ? Icons.graphic_eq_rounded : Icons.radio, color: active ? Colors.amberAccent : const Color(0xFF38BDF8)),
                          title: Text(st['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          subtitle: Text(st['genre'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(active ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.greenAccent, size: 26),
                                onPressed: () async {
                                  if (active) {
                                    await MusicDeckController.togglePlayPause();
                                  } else {
                                    await MusicDeckController.playIndex(idx);
                                  }
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                                onPressed: () async {
                                  setState(() => MusicDeckController.radioStations.removeAt(idx));
                                  await MusicDeckController.saveCustomRadios();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                WebViewWidget(controller: _spotifyWebCtrl),
                WebViewWidget(controller: _ytMusicWebCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarthDayNightPainter extends CustomPainter {
  final double rotation;
  _EarthDayNightPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    final oceanPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.85, -0.3),
        end: Alignment(0.85, 0.3),
        colors: [Color(0xFF1D4ED8), Color(0xFF0F296E), Color(0xFF04091A), Color(0xFF02040A)],
      ).createShader(rect);
    canvas.drawCircle(center, r, oceanPaint);

    final shift = rotation * r * 3.2;
    final landDayPaint = Paint()..color = const Color(0xFF15803D).withOpacity(0.75);
    final cityLightsPaint = Paint()..color = const Color(0xFFFACC15);

    final continents = <Offset>[
      Offset(-r * 0.4, -r * 0.25),
      Offset(r * 0.25, -r * 0.35),
      Offset(-r * 0.15, r * 0.30),
      Offset(r * 0.55, r * 0.15),
    ];

    for (int rep = -1; rep <= 1; rep++) {
      for (int i = 0; i < continents.length; i++) {
        final rawX = center.dx + continents[i].dx + (shift % (r * 2.2)) + (rep * r * 2.2) - r;
        final rawY = center.dy + continents[i].dy;
        canvas.drawOval(Rect.fromCenter(center: Offset(rawX, rawY), width: r * 0.62, height: r * 0.44), landDayPaint);
        if (rawX > center.dx - r * 0.1) {
          for (int k = 0; k < 5; k++) {
            canvas.drawCircle(Offset(rawX + ((k - 2) * 9), rawY + (((k % 3) - 1) * 8)), 1.6, cityLightsPaint);
          }
        }
      }
    }
    canvas.restore();
    canvas.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0..color = const Color(0xFF38BDF8).withOpacity(0.75));
  }

  @override
  bool shouldRepaint(covariant _EarthDayNightPainter oldDelegate) => oldDelegate.rotation != rotation;
}

class CommunitySocialScreen extends StatefulWidget {
  final String serverUrl;
  final Map<String, dynamic> currentUser;
  const CommunitySocialScreen({super.key, required this.serverUrl, required this.currentUser});

  @override
  State<CommunitySocialScreen> createState() => _CommunitySocialScreenState();
}

class _CommunitySocialScreenState extends State<CommunitySocialScreen> with SingleTickerProviderStateMixin {
  late AnimationController _globeRotCtrl;
  double _manualSpin = 0.0;
  final TextEditingController _chatCtrl = TextEditingController();
  final TextEditingController _appealCtrl = TextEditingController();

  int _warningCount = 0;
  bool _isChatBanned = false;
  bool _appealSubmitted = false;
  final List<Map<String, String>> _infractionScreenshots = List<Map<String, String>>.empty(growable: true);

  static const List<String> _blockedWords = <String>[
    'idiota', 'estupido', 'estúpido', 'lixo', 'otario', 'otário',
    'morre', 'matar', 'racista', 'cabrao', 'cabrão', 'filho da puta', 'burro',
  ];

  final List<Map<String, dynamic>> _communityMessages = <Map<String, dynamic>>[
    {'user': '@HELLCreator', 'msg': 'Bem-vindos à Comunidade Global! Respeito mútuo acima de tudo.', 'isVip': true},
    {'user': '@SofiaLive', 'msg': 'Adorei o novo globo dia e noite!', 'isVip': true},
    {'user': '@CarlosPT', 'msg': 'Alguém para jogar em equipa hoje à noite?', 'isVip': false},
  ];

  final List<Map<String, dynamic>> _globeUserAvatars = <Map<String, dynamic>>[
    {'nick': '@HELLCreator', 'country': 'Portugal', 'dx': -0.12, 'dy': -0.22, 'isVip': true, 'live': true, 'color': 0xFFF59E0B, 'initial': 'H'},
    {'nick': '@SofiaLive', 'country': 'Portugal', 'dx': -0.05, 'dy': -0.16, 'isVip': true, 'live': true, 'color': 0xFF38BDF8, 'initial': 'S'},
    {'nick': '@CarlosBR', 'country': 'Brasil', 'dx': -0.34, 'dy': 0.28, 'isVip': true, 'live': true, 'color': 0xFF10B981, 'initial': 'C'},
    {'nick': '@AlexUSA', 'country': 'EUA', 'dx': -0.52, 'dy': -0.24, 'isVip': true, 'live': false, 'color': 0xFFA855F7, 'initial': 'A'},
    {'nick': '@ElenaES', 'country': 'Espanha', 'dx': 0.04, 'dy': -0.20, 'isVip': false, 'live': true, 'color': 0xFFEC4899, 'initial': 'E'},
  ];

  @override
  void initState() {
    super.initState();
    _globeRotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  }

  @override
  void dispose() {
    _globeRotCtrl.dispose();
    _chatCtrl.dispose();
    _appealCtrl.dispose();
    super.dispose();
  }

  bool _containsToxicContent(String text) {
    final lower = text.toLowerCase();
    for (final w in _blockedWords) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  void _handleSendMessage() {
    final txt = _chatCtrl.text.trim();
    if (txt.isEmpty || _isChatBanned) return;

    if (_containsToxicContent(txt)) {
      _warningCount++;
      _infractionScreenshots.insert(0, {
        'id': 'PRINT-${DateTime.now().millisecondsSinceEpoch}',
        'message': txt,
        'time': DateTime.now().toIso8601String(),
        'status': _warningCount >= 3 ? 'BAN APLICADO (3/3)' : 'AVISO $_warningCount/3',
      });
      _chatCtrl.clear();
      setState(() {
        if (_warningCount >= 3) _isChatBanned = true;
      });
      return;
    }

    final isOwner = UserAccountManager.isOwnerEmail(widget.currentUser['email']);
    setState(() {
      _communityMessages.insert(0, {'user': '@${widget.currentUser['nickname'] ?? 'Criador'}', 'msg': txt, 'isVip': isOwner});
      _chatCtrl.clear();
    });
  }

  void _openInfractionsAndAppealDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          backgroundColor: const Color(0xFF0A1433),
          title: const Text('🛡️ Registo de Infrações (Prints IA) & Recurso', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Estado: ${_isChatBanned ? "BANIDO (3/3)" : "Ativo ($_warningCount/3 avisos)"}'),
                  ..._infractionScreenshots.map((inf) => ListTile(
                        dense: true,
                        title: Text('📸 ${inf['id']} · ${inf['status']}'),
                        subtitle: Text('Mensagem: "${inf['message']}"'),
                      )),
                  if (_isChatBanned) ...[
                    TextField(controller: _appealCtrl, decoration: const InputDecoration(hintText: 'Escreve o teu recurso...')),
                    ElevatedButton(
                      onPressed: () {
                        if (_appealCtrl.text.trim().isNotEmpty) {
                          setModal(() => _appealSubmitted = true);
                          setState(() => _appealSubmitted = true);
                        }
                      },
                      child: Text(_appealSubmitted ? '✓ Recurso Enviado' : 'Enviar Recurso'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedMembers = List<Map<String, dynamic>>.from(_globeUserAvatars)
      ..sort((a, b) => (b['isVip'] == true ? 1 : 0).compareTo(a['isVip'] == true ? 1 : 0));

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            tabs: [Tab(text: '🌍 Globo 3D Dia/Noite'), Tab(text: '⭐ Destaque & Online'), Tab(text: '💬 Chat & Moderação IA')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(() => _manualSpin += d.delta.dx * 0.002),
                  child: Center(
                    child: SizedBox(
                      width: 310,
                      height: 310,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _globeRotCtrl,
                            builder: (_, __) => CustomPaint(size: const Size(265, 265), painter: _EarthDayNightPainter((_globeRotCtrl.value + _manualSpin) % 1.0)),
                          ),
                          ..._globeUserAvatars.map((u) => Transform.translate(
                                offset: Offset((u['dx'] as double) * 195, (u['dy'] as double) * 195),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Color(u['color'] as int),
                                  child: Text(u['initial'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: sortedMembers.map((m) {
                    final isVip = m['isVip'] == true;
                    return Card(
                      color: isVip ? const Color(0xFF122659) : const Color(0xFF0B1636),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Color(m['color'] as int), child: Text(m['initial'].toString())),
                        title: Row(children: [Text(m['nick'].toString()), if (isVip) const Icon(Icons.verified_rounded, color: Colors.amberAccent, size: 16)]),
                        subtitle: Text('${m['country']} · ${m['live'] == true ? "🔴 Em Direto" : "🟢 Online"}'),
                      ),
                    );
                  }).toList(),
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🛡️ Moderação IA · Avisos: $_warningCount/3', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                        TextButton(onPressed: _openInfractionsAndAppealDialog, child: const Text('Infrações / Recurso')),
                      ],
                    ),
                    ..._communityMessages.map((m) => ListTile(dense: true, title: Text(m['user'].toString()), subtitle: Text(m['msg'].toString()))),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _chatCtrl, enabled: !_isChatBanned, decoration: const InputDecoration(hintText: 'Escrever no chat...'))),
                        IconButton(icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)), onPressed: _handleSendMessage),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
