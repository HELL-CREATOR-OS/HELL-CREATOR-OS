import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StreamDeckScreen extends StatefulWidget {
  final IO.Socket socket;
  final String activeRoom;
  final String? generatedCode;
  final String? pairedRoom;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onGenerateCode;
  final Function(String) onJoinWithCode;
  final Function(String, dynamic) onSendCommand;
  final VoidCallback onMinimizeDeck;

  const StreamDeckScreen({
    super.key,
    required this.socket,
    required this.activeRoom,
    this.generatedCode,
    this.pairedRoom,
    required this.isMuted,
    required this.onToggleMute,
    required this.onGenerateCode,
    required this.onJoinWithCode,
    required this.onSendCommand,
    required this.onMinimizeDeck,
  });

  @override
  State<StreamDeckScreen> createState() => _StreamDeckScreenState();
}

class _StreamDeckScreenState extends State<StreamDeckScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabs;
  final PageController _deckPageCtrl = PageController();
  int _currentDeckPage = 0;
  int _cols = 4;
  int _rows = 3;
  final Map<int, bool> _activeStates = {};
  final TextEditingController _joinCodeCtrl = TextEditingController();
  String _secondScreenMode = 'deck';

  final List<String> _pageNames = ['Live & Cenas', 'Áudio & Efeitos', 'Alertas & Roleta'];

  final List<List<Map<String, dynamic>>> _pagesButtons = [
    [
      {'label': 'CORTAR SOM (MUTE)', 'cmd': 'toggle_mute', 'icon': Icons.mic_off_rounded, 'color': 0xFFEF4444, 'isMuteBtn': true},
      {'label': 'CENA JOGO', 'cmd': 'scene_game', 'icon': Icons.sports_esports_rounded, 'color': 0xFF38BDF8},
      {'label': 'CÂMARA FULL', 'cmd': 'scene_cam', 'icon': Icons.videocam_rounded, 'color': 0xFF8B5CF6},
      {'label': 'PAUSA / BRB', 'cmd': 'scene_brb', 'icon': Icons.pause_circle_filled_rounded, 'color': 0xFFF59E0B},
      {'label': 'INICIAR LIVE', 'cmd': 'stream_start', 'icon': Icons.sensors_rounded, 'color': 0xFF10B981},
      {'label': 'CLIPAR JOGADA', 'cmd': 'save_clip', 'icon': Icons.movie_creation_rounded, 'color': 0xFFEC4899},
      {'label': 'LIMPAR CHAT', 'cmd': 'clear_chat', 'icon': Icons.cleaning_services_rounded, 'color': 0xFF64748B},
      {'label': 'MODO LENTO', 'cmd': 'slow_chat', 'icon': Icons.speed_rounded, 'color': 0xFF0EA5E9},
      {'label': 'ENCERRAR LIVE', 'cmd': 'stream_stop', 'icon': Icons.stop_circle_rounded, 'color': 0xFFDC2626},
    ],
    [
      {'label': 'PLAY / PAUSE', 'cmd': 'music_toggle', 'icon': Icons.play_arrow_rounded, 'color': 0xFF10B981},
      {'label': 'PRÓXIMA FAIXA', 'cmd': 'music_next', 'icon': Icons.skip_next_rounded, 'color': 0xFF38BDF8},
      {'label': 'APLAUSOS', 'cmd': 'sound_clap', 'icon': Icons.celebration_rounded, 'color': 0xFFEC4899},
      {'label': 'BUZINA LIVE', 'cmd': 'sound_horn', 'icon': Icons.campaign_rounded, 'color': 0xFFF59E0B},
      {'label': 'VOZ TTS ON/OFF', 'cmd': 'toggle_tts', 'icon': Icons.record_voice_over_rounded, 'color': 0xFF8B5CF6},
      {'label': 'SILENCIAR MÚSICA', 'cmd': 'mute_music', 'icon': Icons.volume_off_rounded, 'color': 0xFFEF4444},
    ],
    [
      {'label': 'GIRAR ROLETA', 'cmd': 'spin_wheel', 'icon': Icons.casino_rounded, 'color': 0xFFF59E0B},
      {'label': 'TESTAR ALERTA', 'cmd': 'test_alert', 'icon': Icons.notifications_active_rounded, 'color': 0xFF38BDF8},
      {'label': '+1 MIN TIMER', 'cmd': 'add_timer_60', 'icon': Icons.more_time_rounded, 'color': 0xFF10B981},
      {'label': 'MODO PADRÃO', 'cmd': 'toggle_default_gift', 'icon': Icons.card_giftcard_rounded, 'color': 0xFFEC4899},
      {'label': 'BANNER PARCEIRO', 'cmd': 'toggle_sponsor', 'icon': Icons.handshake_rounded, 'color': 0xFF8B5CF6},
      {'label': 'ALERTA RAID', 'cmd': 'trigger_raid', 'icon': Icons.bolt_rounded, 'color': 0xFFEF4444},
    ],
  ];

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTabs.dispose();
    _deckPageCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }
  Widget _buildStreamDeckTab() {
    final totalSlots = _cols * _rows;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Streamdeck HELL • ${_pageNames[_currentDeckPage]}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF38BDF8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4))),
                child: DropdownButton<String>(
                  value: '${_cols}x$_rows',
                  underline: const SizedBox(),
                  isDense: true,
                  dropdownColor: const Color(0xFF0B1636),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: '3x3', child: Text('Grelha 3x3 (9)')),
                    DropdownMenuItem(value: '4x3', child: Text('Grelha 4x3 (12)')),
                    DropdownMenuItem(value: '5x3', child: Text('Grelha 5x3 (15)')),
                    DropdownMenuItem(value: '5x4', child: Text('Grelha 5x4 (20)')),
                    DropdownMenuItem(value: '5x5', child: Text('Grelha 5x5 (25)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      final parts = v.split('x');
                      setState(() {
                        _cols = int.parse(parts[0]);
                        _rows = int.parse(parts[1]);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _deckPageCtrl,
            itemCount: _pagesButtons.length,
            onPageChanged: (idx) => setState(() => _currentDeckPage = idx),
            itemBuilder: (context, pageIdx) {
              final list = _pagesButtons[pageIdx];
              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: totalSlots,
                itemBuilder: (context, i) {
                  if (i >= list.length) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF081028),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(child: Icon(Icons.add, color: Colors.white24, size: 22)),
                    );
                  }
                  final btn = list[i];
                  final isMute = btn['isMuteBtn'] == true;
                  final keyIdx = pageIdx * 100 + i;
                  final isOn = isMute ? widget.isMuted : (_activeStates[keyIdx] == true);
                  final baseColor = Color(btn['color'] as int);

                  return GestureDetector(
                    onTap: () {
                      if (isMute) {
                        widget.onToggleMute();
                      } else {
                        setState(() => _activeStates[keyIdx] = !isOn);
                        widget.onSendCommand(btn['cmd'].toString(), !isOn);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOn ? baseColor.withOpacity(0.28) : const Color(0xFF0B1636),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isOn ? baseColor : baseColor.withOpacity(0.45), width: isOn ? 2 : 1.1),
                        boxShadow: isOn ? [BoxShadow(color: baseColor.withOpacity(0.35), blurRadius: 10)] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(btn['icon'] as IconData, color: isOn ? Colors.white : baseColor, size: _cols >= 5 ? 22 : 27),
                          const SizedBox(height: 6),
                          Text(
                            btn['label'].toString(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: _cols >= 5 ? 9.5 : 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pagesButtons.length, (i) {
              final active = _currentDeckPage == i;
              return GestureDetector(
                onTap: () => _deckPageCtrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF38BDF8) : Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondScreenTab() {
    final code = widget.generatedCode ?? (widget.activeRoom.isNotEmpty ? widget.activeRoom : 'HELL-SYNC-8842');
    final isPaired = widget.pairedRoom != null && widget.pairedRoom!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1636),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPaired ? Colors.greenAccent : const Color(0xFF38BDF8).withOpacity(0.45)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isPaired ? Icons.check_circle : Icons.qr_code_scanner_rounded, color: isPaired ? Colors.greenAccent : const Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text(
                    isPaired ? 'Segundo Ecrã Conectado (${widget.pairedRoom})' : 'Emparelhar Segundo Ecrã via Sync QR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isPaired ? Colors.greenAccent : Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Lê este Código QR no teu telemóvel ou tablet para transformar o aparelho numa mesa Streamdeck HELL (até 5x) ou num monitor de Centro de Controlo ao vivo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: QrImageView(data: 'HELL_SYNC:$code', version: QrVersions.auto, size: 150),
              ),
              const SizedBox(height: 10),
              SelectableText('Código Manual: $code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onGenerateCode,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Gerar Novo Código QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modo de Exibição no 2.º Aparelho:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'deck', icon: Icon(Icons.grid_view_rounded, size: 16), label: Text('Streamdeck HELL')),
                  ButtonSegment(value: 'cockpit', icon: Icon(Icons.dashboard_rounded, size: 16), label: Text('Monitor Live & Chat')),
                ],
                selected: {_secondScreenMode},
                onSelectionChanged: (s) {
                  setState(() => _secondScreenMode = s.first);
                  widget.onSendCommand('second_screen_mode', s.first);
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _joinCodeCtrl, decoration: const InputDecoration(labelText: 'Inserir código de outro PC/App', isDense: true))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_joinCodeCtrl.text.trim().isNotEmpty) widget.onJoinWithCode(_joinCodeCtrl.text.trim());
                  },
                  child: const Text('Ligar'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1636),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onMinimizeDeck),
        title: const Text('Streamdeck HELL & Segundo Ecrã', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _mainTabs,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Streamdeck HELL'),
            Tab(icon: Icon(Icons.qr_code_2_rounded, size: 18), text: 'Segundo Ecrã & Sync QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabs,
        children: [
          _buildStreamDeckTab(),
          _buildSecondScreenTab(),
        ],
      ),
    );
  }
}

class CommunityGlobeScreen extends StatefulWidget {
  final String serverUrl;
  final bool isOwner;
  const CommunityGlobeScreen({super.key, required this.serverUrl, this.isOwner = false});

  @override
  State<CommunityGlobeScreen> createState() => _CommunityGlobeScreenState();
}

class _CommunityGlobeScreenState extends State<CommunityGlobeScreen> with SingleTickerProviderStateMixin {

  late AnimationController _globeCtrl;
  double _manualDragOffset = 0.0;
  bool _requireFollowAppSocials = false;
  final List<Map<String, String>> _appOfficialSocials = [
    {'platform': 'TikTok Oficial', 'handle': '@hellcreatoros', 'url': 'https://tiktok.com'},
    {'platform': 'Instagram Oficial', 'handle': '@hellcreatoros', 'url': 'https://instagram.com'},
    {'platform': 'Discord Oficial', 'handle': 'HELL CREATOR OS Community', 'url': 'https://discord.com'},
  ];

  final List<Map<String, String>> _globalCreators = [
    {'user': '@HellGamer2026', 'country': 'Portugal · Lisboa', 'platform': 'TikTok LIVE', 'viewers': '1.4K', 'url': 'https://tiktok.com'},
    {'user': '@SofiaStreamPT', 'country': 'Portugal · Porto', 'platform': 'Twitch', 'viewers': '820', 'url': 'https://twitch.tv'},
    {'user': '@KikoArena', 'country': 'Brasil · São Paulo', 'platform': 'Kick', 'viewers': '2.1K', 'url': 'https://kick.com'},
    {'user': '@LukaCyber', 'country': 'Espanha · Madrid', 'platform': 'YouTube LIVE', 'viewers': '960', 'url': 'https://youtube.com'},
  ];

  @override
  void initState() {
    super.initState();
    _globeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 32))..repeat();
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() => _manualDragOffset += d.delta.dx * 0.012),
          child: Container(
            height: 310,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.1,
                colors: [Color(0xFF0A1D42), Color(0xFF020612), Color(0xFF000208)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.55), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _globeCtrl,
                  builder: (_, __) {
                    final angle = (_globeCtrl.value * 2 * pi) + _manualDragOffset;
                    final shiftX = ((angle % (2 * pi)) / (2 * pi)) * 520.0;
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.45), blurRadius: 28, spreadRadius: 4),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            Positioned(
                              left: -shiftX,
                              top: 0,
                              bottom: 0,
                              width: 1040,
                              child: Row(
                                children: [
                                  Image.network(
                                    'https://wikimedia.org',
                                    width: 520,
                                    height: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F296E)),
                                  ),
                                  Image.network(
                                    'https://wikimedia.org',
                                    width: 520,
                                    height: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F296E)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.35, -0.35),
                                  radius: 1.05,
                                  colors: [
                                    Colors.white.withOpacity(0.16),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Positioned(
                  top: 12,
                  child: Text('🛰️ GLOBO TERRESTRE 3D REAL · ARRASTA PARA RODAR', style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: Color(0xFF7DD3FC), fontWeight: FontWeight.bold)),
                ),
                const Positioned(
                  bottom: 12,
                  child: Text('🌍 COMUNIDADE GLOBAL HELL CREATOR OS', style: TextStyle(fontSize: 11.5, letterSpacing: 1.8, color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF122E73), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text('👑 Criador & Fundador em Destaque', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Olá! Sou o criador do HELL CREATOR OS. Construí este ecossistema para ajudar todos os streamers e gamers a terem controlo total com pouco equipamento. Acompanha as minhas lives e junta-te à nossa família!',
                style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _appOfficialSocials.map((soc) => OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(soc['url']!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF38BDF8)),
                  label: Text('${soc['platform']} (${soc['handle']})', style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                )).toList(),
              ),
              if (widget.isOwner) ...[
                const Divider(color: Colors.white12),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('👑 Controlo Dono: Exigir seguir redes da app antes do chat', style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
                  value: _requireFollowAppSocials,
                  onChanged: (v) => setState(() => _requireFollowAppSocials = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('🔴 Criadores em Direto pelo Mundo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        ..._globalCreators.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E429F)),
              ),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1E78FF), child: Icon(Icons.public, color: Colors.white)),
                title: Text(s['user']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${s['country']} · ${s['platform']} (${s['viewers']} a assistir)', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                  onPressed: () async {
                                        final uri = Uri.tryParse(s['url']!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: const Text('Assistir', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            )),
      ],
    );
  }
}

class MarketplaceState {
  static final List<Map<String, dynamic>> items = [
    {
      'id': 'mp_1',
      'title': 'Pack Overlays Néon Cyber 3D',
      'creator': '@TugaStream',
      'category': 'Overlays 3D',
      'netPrice': 0.0,
      'desc': 'Moldura de câmara + barra de metas transparente para OBS e TikTok Live Studio.',
      'owned': true,
    },
    {
      'id': 'mp_2',
      'title': 'Plugin Auto-Clip & Highlight Detector',
      'creator': '@HELLDev',
      'category': 'Plugins & API',
      'netPrice': 5.0,
      'desc': 'Extensão oficial que marca picos de chat e guarda clips automáticos.',
      'owned': false,
    },
    {
      'id': 'mp_3',
      'title': 'Pack 15 Sons Épicos + Stickers 3D',
      'creator': '@KikoGamer',
      'category': 'Sons & GIFs',
      'netPrice': 10.0,
      'desc': 'Efeitos sonoros masterizados em MP3 e ícones 3D para alertas de presentes.',
      'owned': false,
    },
  ];
}

class MarketplacePublicScreen extends StatefulWidget {
  final bool hasFreeOwnerOrStaffAccess;
  const MarketplacePublicScreen({super.key, this.hasFreeOwnerOrStaffAccess = false});

  @override
  State<MarketplacePublicScreen> createState() => _MarketplacePublicScreenState();
}

class _MarketplacePublicScreenState extends State<MarketplacePublicScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final visible = MarketplaceState.items.where((it) {
      if (_filter == 'Grátis') return (it['netPrice'] as double) == 0.0;
      if (_filter == 'PRO') return (it['netPrice'] as double) > 0.0;
      return true;
    }).toList();

    final plans = [
      {'name': 'HELL STARTER', 'price': '0 € / mês', 'desc': 'Ferramentas essenciais, Dashboard básico e alertas iniciais.'},
      {'name': 'HELL CREATOR PRO', 'price': '9,99 € / mês', 'desc': 'Chat avançado, HELL VOICE personalizado, alertas avançados, automações e estatísticas.'},
      {'name': 'HELL CREATOR ELITE', 'price': '19,99 € / mês', 'desc': 'IA avançada, Fábrica de Conteúdos, Analytics avançados e ferramentas de comunidade.'},
      {'name': 'HELL AGENCY / STUDIO', 'price': '49,99 €+ / mês', 'desc': 'Vários criadores, gestão de equipa, permissões, relatórios e dashboard de agência.'},
    ];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '🛒 Market Place'),
              Tab(text: '🔌 Plugins & API'),
              Tab(text: '💎 Planos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. MARKET PLACE
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: ['Todos', 'Grátis', 'PRO'].map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        selectedColor: const Color(0xFF1E78FF),
                        onSelected: (_) => setState(() => _filter = f),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                    ...visible.map((item) {
                      final double net = (item['netPrice'] as num).toDouble();
                      final double consumerPrice = widget.hasFreeOwnerOrStaffAccess ? 0.0 : (net == 0.0 ? 0.0 : net * 1.30);
                      final bool owned = item['owned'] == true || widget.hasFreeOwnerOrStaffAccess;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                Text(
                                  consumerPrice == 0.0 ? 'GRÁTIS' : '${consumerPrice.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Por ${item['creator']} · ${item['category']}', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                            const SizedBox(height: 6),
                            Text(item['desc'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: owned ? Colors.green : const Color(0xFF1E78FF)),
                                onPressed: () => setState(() => item['owned'] = true),
                                child: Text(owned ? 'Ativo na Conta' : 'Transferir / Adquirir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),

                // 2. PLUGINS, API & WHITE-LABEL
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF38BDF8))),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🔌 Ecossistema de Extensões & API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text('• Plugins de Terceiros com permissões controladas e regras claras de segurança.\n• Extensões de alertas, áudio, vídeo e ferramentas de comunidade.\n• API oficial para programadores e soluções White-Label para agências.', style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. PLANOS & SUBSCRIÇÕES
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.hasFreeOwnerOrStaffAccess)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent)),
                        child: const Text('👑 Acesso Livre Total Ativo (Conta Dono / Equipa STAFF)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ),
                    ...plans.map((p) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF38BDF8))),
                                  Text(widget.hasFreeOwnerOrStaffAccess ? '0,00 € (Livre)' : p['price']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(p['desc']!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        )),
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
