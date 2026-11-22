import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_data.dart';
import 'account_security.dart';

class MusicDeckController {
  static AudioPlayer? sharedPlayer;
  static bool isPlaying = false;
  static int currentIndex = 0;
  static final List<Map<String, String>> activeTracks = [
    {'title': 'HELL Cyber Synth 4K (Estéreo)', 'artist': 'HELL Studio Audio · Sem Copyright', 'url': 'sounds/music_cyber.wav'},
    {'title': 'Midnight Lo-Fi Stream (Estéreo)', 'artist': 'HELL Studio Audio · Sem Copyright', 'url': 'sounds/music_lofi.wav'},
    {'title': 'Fanfarra Arena 4K HDR', 'artist': 'HELL Broadcast Pack', 'url': 'sounds/hell_startup.wav'},
    ...DefaultMediaLibrary.royaltyFreeMusicRepo,
  ];

  static Future<void> _playSource(AudioPlayer player, String src) async {
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    if (src.startsWith('http')) {
      await player.play(UrlSource(src));
    } else if (src.startsWith('sounds/')) {
      await player.play(AssetSource(src));
    } else if (src.isNotEmpty) {
      await player.play(DeviceFileSource(src));
    }
  }

  static Future<void> togglePlayPause() async {
    final player = sharedPlayer ?? AudioPlayer();
    sharedPlayer = player;
    if (activeTracks.isEmpty) return;
    if (isPlaying) {
      await player.pause();
      isPlaying = false;
    } else {
      final track = activeTracks[currentIndex % activeTracks.length];
      await _playSource(player, track['url'] ?? 'sounds/music_cyber.wav');
      isPlaying = true;
    }
  }

  static Future<void> nextTrack() async {
    final player = sharedPlayer ?? AudioPlayer();
    sharedPlayer = player;
    if (activeTracks.isEmpty) return;
    currentIndex = (currentIndex + 1) % activeTracks.length;
    final track = activeTracks[currentIndex];
    await _playSource(player, track['url'] ?? 'sounds/music_cyber.wav');
    isPlaying = true;
  }
}

class MusicBackgroundScreen extends StatefulWidget {
  final AudioPlayer bgPlayer;
  const MusicBackgroundScreen({super.key, required this.bgPlayer});

  @override
  State<MusicBackgroundScreen> createState() => _MusicBackgroundScreenState();
}

class _MusicBackgroundScreenState extends State<MusicBackgroundScreen> {
  final TextEditingController _playlistUrlCtrl = TextEditingController();
  double _volume = 0.65;

  @override
  void initState() {
    super.initState();
    MusicDeckController.sharedPlayer = widget.bgPlayer;
  }

  @override
  void dispose() {
    _playlistUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _playIndex(int index) async {
    if (MusicDeckController.activeTracks.isEmpty) return;
    MusicDeckController.currentIndex = index % MusicDeckController.activeTracks.length;
    final track = MusicDeckController.activeTracks[MusicDeckController.currentIndex];
    final src = track['url'] ?? 'sounds/music_cyber.wav';
    await widget.bgPlayer.setVolume(_volume);
    await MusicDeckController._playSource(widget.bgPlayer, src);
    setState(() => MusicDeckController.isPlaying = true);
  }

  Future<void> _pickLocalTracks() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        for (final f in res.files) {
          if (f.path != null) {
            MusicDeckController.activeTracks.insert(0, {
              'title': f.name,
              'artist': 'Ficheiro Local MP3/WAV',
              'url': f.path!,
            });
          }
        }
      });
    }
  }

  void _addCustomStreamOrPlaylist() {
    final u = _playlistUrlCtrl.text.trim();
    if (u.isEmpty) return;
    setState(() {
      MusicDeckController.activeTracks.insert(0, {
        'title': 'Stream / Rádio Customizada',
        'artist': u,
        'url': u,
      });
      _playlistUrlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracks = MusicDeckController.activeTracks;
    final currentTrack = tracks.isNotEmpty ? tracks[MusicDeckController.currentIndex % tracks.length] : {'title': 'Sem faixa', 'artist': ''};

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'ESTÚDIO MUSICAL & RÁDIO 4K HDR',
          icon: Icons.album_rounded,
          accent: const Color(0xFFF59E0B),
          badge: MusicDeckController.isPlaying ? 'A TOCAR' : 'PRONTO',
          onTestPressed: () => _playIndex(MusicDeckController.currentIndex),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A2F6E), Color(0xFF070E24)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.55)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Icon(MusicDeckController.isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded, color: const Color(0xFFF59E0B), size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentTrack['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(currentTrack['artist'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 30, color: Colors.white),
                          onPressed: () => _playIndex((MusicDeckController.currentIndex - 1 + tracks.length) % tracks.length),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          onPressed: () async {
                            await MusicDeckController.togglePlayPause();
                            setState(() {});
                          },
                          icon: Icon(MusicDeckController.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22),
                          label: Text(MusicDeckController.isPlaying ? 'PAUSAR' : 'TOCAR AGORA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 30, color: Colors.white),
                          onPressed: () async {
                            await MusicDeckController.nextTrack();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, size: 18, color: Colors.white60),
                        Expanded(
                          child: Slider(
                            value: _volume,
                            activeColor: const Color(0xFFF59E0B),
                            onChanged: (v) async {
                              setState(() => _volume = v);
                              await widget.bgPlayer.setVolume(v);
                            },
                          ),
                        ),
                        Text('${(_volume * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _playlistUrlCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(hintText: 'URL de Rádio MP3 / Stream...', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                    onPressed: _addCustomStreamOrPlaylist,
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HellCockpitWindow(
          title: 'BIBLIOTECA DE FAIXAS (SEM COPYRIGHT + LOCAIS)',
          icon: Icons.queue_music_rounded,
          accent: const Color(0xFF38BDF8),
          badge: '${tracks.length} FAIXAS',
          onTestPressed: () => _playIndex(0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pickLocalTracks,
                  icon: const Icon(Icons.folder_open_rounded, size: 17, color: Color(0xFF38BDF8)),
                  label: const Text('+ Importar MP3/WAV do Dispositivo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8))),
                ),
              ),
              ...tracks.asMap().entries.map((e) {
                final isCurrent = (MusicDeckController.currentIndex % tracks.length) == e.key && MusicDeckController.isPlaying;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF1E78FF).withOpacity(0.22) : const Color(0xFF04091A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? const Color(0xFF38BDF8) : Colors.white12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(isCurrent ? Icons.equalizer_rounded : Icons.library_music_rounded, color: isCurrent ? Colors.greenAccent : const Color(0xFF38BDF8)),
                    title: Text(e.value['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white)),
                    subtitle: Text(e.value['artist'] ?? '', style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
                    trailing: IconButton(
                      icon: Icon(isCurrent ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.greenAccent, size: 26),
                      onPressed: () => _playIndex(e.key),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
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
  final TextEditingController _chatCtrl = TextEditingController();
  bool _showMyLocationOnGlobe = true;
  int _vipRotationSeed = 0;

  final List<Map<String, dynamic>> _communityMessages = [
    {'user': '@HELLCreatorOS', 'country': 'Portugal 🇵🇹', 'msg': 'Bem-vindos à Comunidade Global 4K HDR! Mapa NASA ativo.', 'isOwner': true},
    {'user': '@SofiaLive', 'country': 'Portugal 🇵🇹', 'msg': 'O globo da NASA com os VIPs em tempo real ficou brutal!', 'isOwner': false},
    {'user': 'CarlosGamer_BR', 'country': 'Brasil 🇧🇷', 'msg': 'Salve desde São Paulo! A testar os alertas 4K.', 'isOwner': false},
  ];

  final List<Map<String, dynamic>> _globalVipNodes = [
    {'nick': '@HELLCreatorOS (FUNDADOR)', 'country': 'Portugal', 'flag': '🇵🇹', 'lat': 0.34, 'lon': 0.46, 'fixed': true, 'live': true, 'tier': 'DONO · SUPREMO'},
    {'nick': 'SofiaLive_VIP', 'country': 'Portugal', 'flag': '🇵🇹', 'lat': 0.36, 'lon': 0.48, 'fixed': false, 'live': true, 'tier': 'VIP SUPREMO'},
    {'nick': 'CarlosGamer_BR', 'country': 'Brasil', 'flag': '🇧🇷', 'lat': 0.64, 'lon': 0.33, 'fixed': false, 'live': true, 'tier': 'VIP PRO'},
    {'nick': 'LucasStream_BR', 'country': 'Brasil', 'flag': '🇧🇷', 'lat': 0.60, 'lon': 0.35, 'fixed': false, 'live': false, 'tier': 'VIP PRO'},
    {'nick': 'CyberAlex_US', 'country': 'EUA', 'flag': '🇺🇸', 'lat': 0.36, 'lon': 0.22, 'fixed': false, 'live': true, 'tier': 'VIP SUPREMO'},
    {'nick': 'ElenaStream_ES', 'country': 'Espanha', 'flag': '🇪🇸', 'lat': 0.35, 'lon': 0.49, 'fixed': false, 'live': true, 'tier': 'VIP PRO'},
    {'nick': 'KenjiPlays_JP', 'country': 'Japão', 'flag': '🇯🇵', 'lat': 0.38, 'lon': 0.84, 'fixed': false, 'live': true, 'tier': 'VIP SUPREMO'},
  ];

  @override
  void initState() {
    super.initState();
    _globeRotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  }

  @override
  void dispose() {
    _globeRotCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _visibleNodesForCurrentPass() {
    final owner = _globalVipNodes.first;
    final others = _globalVipNodes.where((n) => n['fixed'] != true).toList();
    final selected = <Map<String, dynamic>>[];
    if (_showMyLocationOnGlobe) {
      selected.add(owner);
    }
    for (int i = 0; i < others.length; i++) {
      if ((i + _vipRotationSeed) % 2 == 0) {
        selected.add(others[i]);
      }
    }
    return selected;
  }

  void _openNodeDetails(Map<String, dynamic> node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
        title: Row(
          children: [
            Text(node['flag'] ?? '🌍', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(child: Text(node['nick'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('País: ${node['country']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF38BDF8))),
            const SizedBox(height: 6),
            Text('Estatuto: ${node['tier']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.amberAccent)),
            const SizedBox(height: 6),
            Text(node['live'] == true ? '🟢 Em Direto Agora' : '🔵 Online na Comunidade', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = UserAccountManager.isOwnerEmail(widget.currentUser['email']);
    final visibleNodes = _visibleNodesForCurrentPass();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'GLOBO TERRESTRE NASA · REDE GLOBAL VIP',
          icon: Icons.public_rounded,
          accent: const Color(0xFF38BDF8),
          badge: 'NASA BLUE MARBLE 4K',
          onTestPressed: () {
            setState(() => _vipRotationSeed++);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🌍 Órbita NASA atualizada! Nova rotação aleatória de VIPs por país.'), behavior: SnackBarBehavior.floating),
            );
          },
          child: Column(
            children: [
              SizedBox(
                height: 250,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _globeRotCtrl,
                    builder: (_, __) {
                      return GestureDetector(
                        onTap: () => setState(() => _vipRotationSeed++),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 224,
                              height: 224,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.45), blurRadius: 34, spreadRadius: 4),
                                  BoxShadow(color: const Color(0xFF1E78FF).withOpacity(0.35), blurRadius: 55),
                                ],
                              ),
                              child: ClipOval(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      'https://wikimedia.org',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        decoration: const BoxDecoration(
                                          gradient: RadialGradient(colors: [Color(0xFF1E78FF), Color(0xFF0A2463), Color(0xFF030712)]),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: const Alignment(-0.35, -0.35),
                                          radius: 0.95,
                                          colors: [Colors.white.withOpacity(0.14), Colors.transparent, Colors.black.withOpacity(0.75)],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ...visibleNodes.map((n) {
                              final isFixedOwner = n['fixed'] == true;
                              final dx = ((n['lon'] as double) - 0.5) * 165;
                              final dy = ((n['lat'] as double) - 0.5) * 165;
                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: GestureDetector(
                                  onTap: () => _openNodeDetails(n),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFixedOwner ? Colors.amberAccent : const Color(0xFF04091A).withOpacity(0.88),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: isFixedOwner ? Colors.white : const Color(0xFF38BDF8)),
                                        ),
                                        child: Text(
                                          isFixedOwner ? '🇵🇹 DONO' : '${n['flag']} VIP',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: isFixedOwner ? Colors.black : Colors.white),
                                        ),
                                      ),
                                      Container(
                                        width: isFixedOwner ? 12 : 9,
                                        height: isFixedOwner ? 12 : 9,
                                        decoration: BoxDecoration(
                                          color: isFixedOwner ? Colors.amberAccent : Colors.greenAccent,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: isFixedOwner ? Colors.amberAccent : Colors.greenAccent, blurRadius: 10, spreadRadius: 2)],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF38BDF8),
                title: const Text('Mostrar a minha presença no Globo NASA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                subtitle: const Text('Portugal mantém o fundador em destaque; restantes VIPs rodam aleatoriamente por país.', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
                value: _showMyLocationOnGlobe,
                onChanged: (v) => setState(() => _showMyLocationOnGlobe = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HellCockpitWindow(
          title: 'CHAT GLOBAL & DESTAQUE DO FUNDADOR',
          icon: Icons.forum_rounded,
          accent: const Color(0xFFA855F7),
          badge: '${_communityMessages.length} MENSAGENS',
          onTestPressed: () {
            setState(() {
              _communityMessages.insert(0, {'user': '@HELLCreatorOS', 'country': 'Portugal 🇵🇹', 'msg': 'Sinal global verificado com sucesso!', 'isOwner': true});
            });
          },
          child: Column(
            children: [
              ..._communityMessages.map((m) {
                final ownerMsg = m['isOwner'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ownerMsg ? const Color(0xFF1E2B58) : const Color(0xFF04091A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ownerMsg ? Colors.amberAccent : Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m['user'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: ownerMsg ? Colors.amberAccent : const Color(0xFF38BDF8))),
                          const SizedBox(width: 6),
                          Text(m['country'] ?? '', style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(m['msg'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Escrever na comunidade global...', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      if (_chatCtrl.text.trim().isEmpty) return;
                      setState(() {
                        _communityMessages.insert(0, {
                          'user': '@${widget.currentUser['nickname'] ?? 'Criador'}',
                          'country': 'Portugal 🇵🇹',
                          'msg': _chatCtrl.text.trim(),
                          'isOwner': isOwner,
                        });
                        _chatCtrl.clear();
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
}


class HellInfoHubScreen extends StatefulWidget {
  const HellInfoHubScreen({super.key});

  @override
  State<HellInfoHubScreen> createState() => _HellInfoHubScreenState();
}

class _HellInfoHubScreenState extends State<HellInfoHubScreen> {
  final TextEditingController _aiInputCtrl = TextEditingController();
  final List<Map<String, String>> _aiChat = [
    {
      'role': 'ai',
      'text': 'Olá! Sou o Robô Assistente do HELL CREATOR OS. Pergunta-me como sincronizar um segundo aparelho, ligar o OBS, configurar vozes ou usar o Modo de Jogo!',
    },
  ];

  final List<Map<String, String>> _faqTopics = [
    {
      'title': '1. Como fazer Live Direta no Telemóvel ou Tablet sem PC?',
      'example': 'Toca num dos 4 quadrados (Twitch, YouTube ou Kick) no topo do ecrã inicial, cola a tua Stream Key e inicia. Ao minimizar para jogar, o Modo de Jogo Invisível ativa-se automaticamente sem nada no ecrã.',
    },
    {
      'title': '2. Como sincronizar um Telemóvel Velho como Stream Deck Pro?',
      'example': 'Inicia sessão com a mesma conta nos dois aparelhos, vai a "Centro de Controlo > Perfil & Sync QR" e lê o Código QR (ou escreve o código de 6 dígitos) para desbloquear o Stream Deck Pro sincronizado.',
    },
    {
      'title': '3. Como escolher e instalar Vozes Masculinas e Femininas?',
      'example': 'Abre "HELL Voz / Chat TTS", escolhe entre as 3 vozes masculinas e 3 femininas em Português, toca em Play para testar e instala na aplicação.',
    },
    {
      'title': '4. Como ligar Overlays no OBS Studio / TikTok Live Studio?',
      'example': 'Vai a "Centro de Controlo > OBS Control", copia o URL Browser Source local e cola-o como Fonte de Navegador (1920x1080) no teu software de transmissão.',
    },
  ];

  String _generateAiReply(String question) {
    final q = question.toLowerCase();
    if (q.contains('qr') || q.contains('sincronizar') || q.contains('segundo') || q.contains('deck')) {
      return 'Para sincronizar um segundo aparelho, entra na mesma conta nos dois dispositivos e valida o Código QR ou o código de 6 dígitos em "Centro de Controlo > Perfil & Sync QR".';
    }
    if (q.contains('obs') || q.contains('overlay') || q.contains('link')) {
      return 'Em "Centro de Controlo > OBS Control", copia o endereço local http://IP:8765/overlay e adiciona-o como Browser Source no OBS Studio ou TikTok Live Studio.';
    }
    if (q.contains('voz') || q.contains('tts')) {
      return 'Na aba "HELL Voz / Chat TTS" tens 3 vozes masculinas e 3 femininas em Português prontas a testar e instalar, além da clonagem de voz de 2 minutos.';
    }
    if (q.contains('doar') || q.contains('donation') || q.contains('mbway')) {
      return 'Em "HELL Automações > Donation", configura o teu MB WAY, PayPal.me, Revolut ou PIX e copia o teu link único /donate para a bio da live.';
    }
    return 'Podes consultar os guias na sub-aba "FAQ & Regras" ou contactar diretamente a equipa oficial em hellcreatoros@gmail.com.';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '📱 Ecrã & Toque'),
              Tab(text: 'ℹ️ Quem Somos'),
              Tab(text: '🤖 Ajuda (Robô IA)'),
              Tab(text: '📖 FAQ & Regras'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                            // 0. ECRÃ & TOQUE (FEEDBACK HÁPTICO & SONORO MOBILE)
            ListView(
              padding: const EdgeInsets.all(14),
              children: [
                HellCockpitWindow(
                  title: 'ECRÃ & TOQUE · FEEDBACK MOBILE',
                  icon: Icons.touch_app_rounded,
                  accent: const Color(0xFF38BDF8),
                  badge: HellFeedbackEngine.isMobileDevice ? 'MOBILE ATIVO' : 'MODO PC (SILENCIOSO)',
                  onTestPressed: () async {
                    final prev = HellFeedbackEngine.soundEnabled;
                    HellFeedbackEngine.soundEnabled = true;
                    try {
                      final p = AudioPlayer();
                      await p.setVolume(HellFeedbackEngine.tapVolume);
                      await p.play(AssetSource(HellFeedbackEngine.tapSoundAsset));
                    } catch (_) {}
                    HellFeedbackEngine.soundEnabled = prev;
                    HapticFeedback.mediumImpact();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF38BDF8),
                        title: const Text('Som de Clique ao Tocar nos Botões (Mobile)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        subtitle: const Text('Ativo no Android/Tablet e automaticamente silencioso no Windows.', style: TextStyle(fontSize: 11, color: Colors.white60)),
                        value: HellFeedbackEngine.soundEnabled,
                        onChanged: (v) => setState(() => HellFeedbackEngine.soundEnabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF38BDF8),
                        title: const Text('Vibração Háptica nos Toques (Mobile)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        subtitle: const Text('Resposta tátil suave ao pressionar teclas e menus.', style: TextStyle(fontSize: 11, color: Colors.white60)),
                        value: HellFeedbackEngine.vibrationEnabled,
                        onChanged: (v) => setState(() => HellFeedbackEngine.vibrationEnabled = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: HellFeedbackEngine.tapSoundAsset,
                        decoration: const InputDecoration(labelText: 'Tipo de Som de Toque', border: OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'sounds/tap_cyber.wav', child: Text('Cyber Mech (Futurista)')),
                          DropdownMenuItem(value: 'sounds/tap_glass.wav', child: Text('Cristal HD (Suave)')),
                          DropdownMenuItem(value: 'sounds/tap_pulse.wav', child: Text('Pulso Néon (Energético)')),
                          DropdownMenuItem(value: 'sounds/tap_zerog.wav', child: Text('Zero-G Synth (Espacial)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => HellFeedbackEngine.tapSoundAsset = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF38BDF8)),
                          Expanded(
                            child: Slider(
                              value: HellFeedbackEngine.tapVolume,
                              activeColor: const Color(0xFF38BDF8),
                              onChanged: (v) => setState(() => HellFeedbackEngine.tapVolume = v),
                            ),
                          ),
                          Text('${(HellFeedbackEngine.tapVolume * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF38BDF8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

                // 1. QUEM SOMOS
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Image.asset('icon.png', height: 85, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 70, color: Color(0xFF38BDF8))),
                    ),
                    const SizedBox(height: 10),
                    const Center(child: Text('HELL', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white, height: 1.0))),
                    const Center(child: Text('CREATOR OS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3, color: Color(0xFF38BDF8)))),
                    const SizedBox(height: 6),
                    const Center(child: Text('UM CRIADOR · VÁRIAS PLATAFORMAS · CONTROLO TOTAL', style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: Color(0xFF7DD3FC)))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E78FF)),
                      ),
                      child: const Text(
                        'O HELL CREATOR OS é um sistema operativo completo criado para dar a todos os criadores de conteúdo — desde quem transmite apenas com um telemóvel até estúdios profissionais no PC — controlo total sobre múltiplas plataformas, voz natural em tempo real, automações sem código e ferramentas inteligentes de crescimento.',
                        style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF0B1636),
                      child: ListTile(
                        leading: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
                        title: const Text('Contacto Oficial HELL CREATOR OS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('hellcreatoros@gmail.com', style: TextStyle(color: Colors.cyanAccent)),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                          onPressed: () => launchUrl(Uri.parse('mailto:hellcreatoros@gmail.com')),
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. AJUDA COM ROBÔ BRANCO & AZUL NÉON ("H")
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1636),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: Column(
                        children: [
                          const _HellRobotMascot(),
                          const SizedBox(height: 8),
                          const Text('Assistente IA · HELL CREATOR OS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 10),
                          ..._aiChat.map((m) => Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: m['role'] == 'ai' ? const Color(0xFF122E73) : const Color(0xFF1E78FF).withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(m['text']!, style: const TextStyle(fontSize: 12.5)),
                              )),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _aiInputCtrl,
                                  decoration: const InputDecoration(hintText: 'Escreve a tua dúvida aqui...', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                                onPressed: () {
                                  final q = _aiInputCtrl.text.trim();
                                  if (q.isEmpty) return;
                                  setState(() {
                                    _aiChat.add({'role': 'user', 'text': q});
                                    _aiChat.add({'role': 'ai', 'text': _generateAiReply(q)});
                                    _aiInputCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. FAQ, REGRAS DE CONDUTA, TERMOS & PRIVACIDADE
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('📚 Guias Práticos (FAQ)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                    const SizedBox(height: 8),
                    ..._faqTopics.map((f) => Card(
                          color: const Color(0xFF0B1636),
                          child: ExpansionTile(
                            title: Text(f['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                child: Text(f['example']!, style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45)),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⚖️ Regras de Conduta, Termos & Privacidade', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text(
                            '• Respeito mútuo obrigatório na comunidade e nas transmissões.\n'
                            '• Proibido spam, discurso de ódio ou partilha de links maliciosos.\n'
                            '• Privacidade garantida: o HELL CREATOR OS não cruza automaticamente identidades de utilizadores entre TikTok, Twitch, YouTube e Kick.\n'
                            '• Cada criador é responsável pelo conteúdo transmitido nos seus canais.',
                            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
                          ),
                        ],
                      ),
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

class _HellRobotMascot extends StatelessWidget {
  const _HellRobotMascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFE0F2FE)]),
        border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
        boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.55), blurRadius: 16)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF050B1E), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF38BDF8)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('H', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E78FF), height: 1.0)),
        ],
      ),
    );
  }
}
