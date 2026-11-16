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
  static List<Map<String, String>> activeTracks =
      List<Map<String, String>>.from(DefaultMediaLibrary.royaltyFreeMusicRepo);

  static Future<void> togglePlayPause() async {
    final player = sharedPlayer;
    if (player == null || activeTracks.isEmpty) return;
    if (isPlaying) {
      await player.pause();
      isPlaying = false;
    } else {
      final track = activeTracks[currentIndex % activeTracks.length];
      final src = track['url'] ?? '';
      if (src.startsWith('http')) {
        await player.play(UrlSource(src));
      } else if (src.isNotEmpty) {
        await player.play(DeviceFileSource(src));
      }
      isPlaying = true;
    }
  }

  static Future<void> nextTrack() async {
    final player = sharedPlayer;
    if (player == null || activeTracks.isEmpty) return;
    currentIndex = (currentIndex + 1) % activeTracks.length;
    final track = activeTracks[currentIndex];
    final src = track['url'] ?? '';
    await player.stop();
    if (src.startsWith('http')) {
      await player.play(UrlSource(src));
    } else if (src.isNotEmpty) {
      await player.play(DeviceFileSource(src));
    }
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
  double _volume = 0.35;

  @override
  void initState() {
    super.initState();
    MusicDeckController.sharedPlayer = widget.bgPlayer;
  }

  Future<void> _playIndex(int index) async {
    if (MusicDeckController.activeTracks.isEmpty) return;
    MusicDeckController.currentIndex = index % MusicDeckController.activeTracks.length;
    final track = MusicDeckController.activeTracks[MusicDeckController.currentIndex];
    final src = track['url'] ?? '';
    await widget.bgPlayer.setVolume(_volume);
    await widget.bgPlayer.setReleaseMode(ReleaseMode.loop);
    await widget.bgPlayer.stop();
    if (src.startsWith('http')) {
      await widget.bgPlayer.play(UrlSource(src));
    } else if (src.isNotEmpty) {
      await widget.bgPlayer.play(DeviceFileSource(src));
    }
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
              'artist': 'Ficheiro Local',
              'url': f.path!,
            });
          }
        }
      });
      await _playIndex(0);
    }
  }

  void _addCustomStreamOrPlaylist() {
    final raw = _playlistUrlCtrl.text.trim();
    if (raw.isEmpty) return;
    final fullUrl = raw.startsWith('http') ? raw : 'https://$raw';
    setState(() {
      MusicDeckController.activeTracks.insert(0, {
        'title': 'Stream / Playlist Externa',
        'artist': fullUrl,
        'url': fullUrl,
      });
      _playlistUrlCtrl.clear();
    });
    _playIndex(0);
  }

  @override
  Widget build(BuildContext context) {
    final tracks = MusicDeckController.activeTracks;
    final activeTitle = tracks.isNotEmpty
        ? tracks[MusicDeckController.currentIndex % tracks.length]['title']!
        : 'Nenhuma faixa selecionada';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
          ),
          child: Column(
            children: [
              const Text('🎵 LEITOR INTEGRADO NA APP (SINCRONIZADO)', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(activeTitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    color: Colors.greenAccent,
                    icon: Icon(MusicDeckController.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: () async {
                      await MusicDeckController.togglePlayPause();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 38,
                    color: Colors.redAccent,
                    icon: const Icon(Icons.stop_circle),
                    onPressed: () async {
                      await widget.bgPlayer.stop();
                      setState(() => MusicDeckController.isPlaying = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 36,
                    color: const Color(0xFF38BDF8),
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: () async {
                      await MusicDeckController.nextTrack();
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: const Color(0xFF38BDF8),
                      onChanged: (v) async {
                        setState(() => _volume = v);
                        await widget.bgPlayer.setVolume(v);
                      },
                    ),
                  ),
                  Text('${(_volume * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
                      onPressed: () => launchUrl(Uri.parse('https://spotify.com'), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.music_note, color: Colors.white, size: 18),
                      label: const Text('Spotify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000)),
                      onPressed: () => launchUrl(Uri.parse('https://youtube.com'), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                      label: const Text('YouTube Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _playlistUrlCtrl,
                      decoration: const InputDecoration(hintText: 'Colar link Spotify, playlist ou MP3 direto...', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                    onPressed: _addCustomStreamOrPlaylist,
                    child: const Text('Rodar', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎧 Faixas & Playlists (Sem Copyright)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            TextButton.icon(onPressed: _pickLocalTracks, icon: const Icon(Icons.add, size: 18), label: const Text('+ MP3 Local')),
          ],
        ),
        ...tracks.asMap().entries.map((e) {
          final isCurrent = (MusicDeckController.currentIndex % tracks.length) == e.key && MusicDeckController.isPlaying;
          return Card(
            color: isCurrent ? const Color(0xFF122E73) : const Color(0xFF0B1636),
            child: ListTile(
              dense: true,
                            leading: Icon(isCurrent ? Icons.equalizer : Icons.library_music, color: isCurrent ? Colors.greenAccent : const Color(0xFF38BDF8)),
              title: Text(e.value['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(e.value['artist'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white60)),
              trailing: IconButton(
                icon: Icon(isCurrent ? Icons.pause : Icons.play_arrow, color: Colors.greenAccent),
                onPressed: () => _playIndex(e.key),
              ),
            ),
          );
        }),
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

class _CommunitySocialScreenState extends State<CommunitySocialScreen> {
  final TextEditingController _chatCtrl = TextEditingController();
  final List<Map<String, dynamic>> _communityMessages = [
    {'user': '@SofiaLive', 'msg': 'Alguém a testar os novos overlays néon hoje?', 'isOwner': false},
    {'user': '@HELLCreatorOS', 'msg': 'Bem-vindos à comunidade oficial! Podem deixar aqui sugestões ou dúvidas.', 'isOwner': true},
  ];

  final List<Map<String, dynamic>> _creators = [
    {'nick': '@SofiaLive', 'bio': 'FPS & Just Chatting · Portugal', 'status': 'online', 'following': false},
    {'nick': '@KikoGamer', 'bio': 'Torneios e Desafios ao vivo', 'status': 'dnd', 'following': true},
    {'nick': '@TugaStream', 'bio': 'Criador de Overlays PRO', 'status': 'online', 'following': false},
  ];

  Color _dotColor(String st) {
    if (st == 'dnd') return Colors.orange;
    if (st == 'invisible') return Colors.white;
    if (st == 'offline') return Colors.redAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = UserAccountManager.isOwnerEmail(widget.currentUser['email']);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '💬 Chat Interativo'),
              Tab(text: '👥 Criadores'),
              Tab(text: '🏅 Fidelização & VIP'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. CHAT INTERATIVO COM DESTAQUE DO DONO
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _communityMessages.map((m) {
                          final ownerMsg = m['isOwner'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ownerMsg ? const Color(0xFF122E73) : const Color(0xFF0B1636),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ownerMsg ? const Color(0xFF38BDF8) : Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(m['user']!, style: TextStyle(fontWeight: FontWeight.bold, color: ownerMsg ? Colors.amberAccent : const Color(0xFF38BDF8), fontSize: 12.5)),
                                    if (ownerMsg) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(color: const Color(0xFF1E78FF), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('👑 CRIADOR & DONO HELL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(m['msg']!, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(child: TextField(controller: _chatCtrl, decoration: const InputDecoration(hintText: 'Publicar ou mencionar @Dono...', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                            onPressed: () {
                              if (_chatCtrl.text.trim().isNotEmpty) {
                                setState(() {
                                  _communityMessages.add({
                                    'user': '@${widget.currentUser['nickname'] ?? 'Criador'}',
                                    'msg': _chatCtrl.text.trim(),
                                    'isOwner': isOwner,
                                  });
                                  _chatCtrl.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. PERFIS PÚBLICOS (SEM CRUZAR IDENTIDADES ENTRE PLATAFORMAS)
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Privacidade: A identidade de cada espectador entre TikTok, Twitch, YouTube e Kick nunca é cruzada automaticamente.',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ),
                    ..._creators.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E429F)),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  const CircleAvatar(backgroundColor: Color(0xFF1E78FF), child: Icon(Icons.person, color: Colors.white)),
                                  Container(width: 11, height: 11, decoration: BoxDecoration(color: _dotColor(c['status']), shape: BoxShape.circle)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['nick'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                                    Text(c['bio'], style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: c['following'] ? Colors.white12 : const Color(0xFF1E78FF)),
                                onPressed: () => setState(() => c['following'] = !c['following']),
                                child: Text(c['following'] ? 'A Seguir' : 'Seguir', style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),

                // 3. FIDELIZAÇÃO, MISSÕES & VIP COMMUNITY
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏅 Sistema de Fidelização & VIP Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text('• Missões diárias de participação no chat e partilhas.\n• Níveis de fidelização e recompensas personalizadas para apoiantes.\n• Gestão de grupos VIP e histórico de seguidores, membros e subscritores.', style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5)),
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
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'ℹ️ Quem Somos'),
              Tab(text: '🤖 Ajuda (Robô IA)'),
              Tab(text: '📜 FAQ & Regras'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
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
