import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_logos.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_data.dart';
import 'live_connectors.dart';
import 'account_security.dart';

BoxDecoration _neonBox() => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF13275E), Color(0xFF0A1433), Color(0xFF050B1E)],
    stops: [0.0, 0.55, 1.0],
  ),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45), width: 1.3),
  boxShadow: [
    BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 12, offset: const Offset(0, 6)),
    BoxShadow(color: const Color(0xFF1E78FF).withOpacity(0.18), blurRadius: 16, spreadRadius: 0.5),
  ],
);


class SponsorBannerManager {
  static final List<Map<String, String>> activeSponsors = [
    {
      'title': 'HELL CREATOR OS PRO · Controlo Total das Tuas Lives',
      'url': 'mailto:hellcreatoros@gmail.com',
    },
    {
      'title': 'Espaço Oficial Patrocinadores · Anuncie aqui: hellcreatoros@gmail.com',
      'url': 'mailto:hellcreatoros@gmail.com',
    },
  ];
}
class HellVisualBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String badge;
  final Widget? trailing;

  const HellVisualBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = const Color(0xFF38BDF8),
    this.badge = 'STUDIO 4K HDR',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.28),
            const Color(0xFF0E1D47),
            const Color(0xFF04091A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.65), width: 1.4),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [accent.withOpacity(0.35), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(0.6)),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accent.withOpacity(0.5)),
                          ),
                          child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: accent)),
                        ),
                        const SizedBox(height: 5),
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CENTRO DE CONTROLO - COCKPIT UNIFICADO OFF/LIVE (4K HDR + SCROLL INTERNO + ECRÃ COMPLETO + ARRASTO PC/TABLET)
class ControlCenterScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onLogout;
  final Map<String, bool> activePlatforms;
  final List<Map<String, String>> chatFeed;
  final String syncCode;
  final bool isSecondScreenPaired;
  final Function(String) onValidateSyncCode;

  const ControlCenterScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.activePlatforms,
    required this.chatFeed,
    required this.syncCode,
    required this.isSecondScreenPaired,
    required this.onValidateSyncCode,
  });

  @override
  State<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends State<ControlCenterScreen> {
  bool _ttsEnabled = true;
  bool _isMusicPlaying = true;
  bool _forceLiveMode = false;
  final TextEditingController _quickReplyCtrl = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();

  double _micVol = 0.85;
  double _gameVol = 0.65;
  double _musicVol = 0.45;
  double _alertVol = 0.90;
  bool _micMuted = false;

  final List<Map<String, String>> _liveChatBuffer = [
    {'platform': 'tiktok', 'user': '@joao_gamer', 'text': 'Que jogada absurda mano!!'},
    {'platform': 'twitch', 'user': 'SofiaLive', 'text': 'A imagem 4K está brutal!'},
    {'platform': 'youtube', 'user': 'CarlosPT', 'text': 'Salve para Portugal!'},
    {'platform': 'kick', 'user': 'Nitro_99', 'text': 'Rumo à meta de hoje!'},
  ];

  final List<Map<String, dynamic>> _recentAlerts = [
    {'type': 'SUB', 'user': 'SofiaLive', 'detail': 'Sub Tier 1 · 3 Meses', 'color': const Color(0xFFA855F7), 'icon': Icons.star_rounded},
    {'type': 'DONATION', 'user': 'CarlosPT', 'detail': '€15.00 · MB WAY', 'color': const Color(0xFF10B981), 'icon': Icons.euro_rounded},
    {'type': 'PRESENTE', 'user': '@joao_gamer', 'detail': 'Galáxia (1000 Moedas)', 'color': const Color(0xFFF43F5E), 'icon': Icons.auto_awesome},
    {'type': 'FOLLOW', 'user': 'Nitro_99', 'detail': 'Novo Seguidor Kick', 'color': const Color(0xFF38BDF8), 'icon': Icons.person_add_alt_1},
  ];

  final List<double> _bitrateSamples = [6.1, 6.4, 6.2, 6.6, 6.5, 6.8, 6.4, 6.7, 6.5, 6.9];

  bool get _isOnAir => _forceLiveMode || widget.activePlatforms.values.any((v) => v);

  @override
  void dispose() {
    _quickReplyCtrl.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _executeAction(String moduleLabel, String assetOrMsg) async {
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource('sounds/tap_pulse.wav'));
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnAir
              ? '🔴 [NO AR · TRANSMITIDO] $moduleLabel: $assetOrMsg'
              : '🎧 [ESTÚDIO OFF · NOS AUSCULTADORES] $moduleLabel: $assetOrMsg',
        ),
        backgroundColor: _isOnAir ? const Color(0xFF059669) : const Color(0xFFB91C1C),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _platColor(String p) {
    switch (p.toLowerCase()) {
      case 'tiktok':
        return const Color(0xFFFF2A5F);
      case 'twitch':
        return const Color(0xFF9146FF);
      case 'youtube':
        return const Color(0xFFFF0033);
      default:
        return const Color(0xFF53FC18);
    }
  }

  final List<Map<String, dynamic>> _extraStreamPlatforms = [];
  int? _customTotalViewers;

  void _openAddPlatformDialog() {
    final nameCtrl = TextEditingController();
    final rtmpCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        title: const Text('Adicionar Plataforma de Streaming', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome (ex.: Instagram, Facebook, Trovo)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rtmpCtrl,
              decoration: const InputDecoration(labelText: 'Servidor RTMP / Stream Key', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) {
                setState(() {
                  _extraStreamPlatforms.add({
                    'id': n.toLowerCase().replaceAll(' ', '_'),
                    'name': n,
                    'active': true,
                    'viewers': 0,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCockpitHeader(bool isWide) {
    final basePlatforms = [
      {'id': 'tiktok', 'name': 'TikTok', 'active': widget.activePlatforms['tiktok'] == true, 'viewers': widget.activePlatforms['tiktok'] == true ? 142 : 0},
      {'id': 'twitch', 'name': 'Twitch', 'active': widget.activePlatforms['twitch'] == true, 'viewers': widget.activePlatforms['twitch'] == true ? 68 : 0},
      {'id': 'youtube', 'name': 'YouTube', 'active': widget.activePlatforms['youtube'] == true, 'viewers': widget.activePlatforms['youtube'] == true ? 95 : 0},
      {'id': 'kick', 'name': 'Kick', 'active': widget.activePlatforms['kick'] == true, 'viewers': widget.activePlatforms['kick'] == true ? 41 : 0},
      ..._extraStreamPlatforms,
    ];

    final int calculatedTotal = basePlatforms.fold<int>(0, (sum, p) => sum + ((p['active'] == true) ? (p['viewers'] as int? ?? 0) : 0));
    final int displayTotal = _customTotalViewers ?? calculatedTotal;

    return HellCockpitWindow(
      title: 'MULTIPLATAFORMAS · TRANSMISSÃO EM TEMPO REAL',
      icon: Icons.sensors_rounded,
      accent: const Color(0xFF38BDF8),
      badge: 'TOTAL: $displayTotal ESPECTADORES',
      onTestPressed: () {
        Clipboard.setData(ClipboardData(text: 'http://127.0.0'));
        _executeAction('Overlay Contador Geral ($displayTotal espectadores)', 'copiado para OBS / Live');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04091A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, size: 17, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contador Geral ao Vivo: $displayTotal espectadores',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final ctrl = TextEditingController(text: displayTotal.toString());
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF0A1433),
                              title: const Text('Personalizar Contador Geral', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                              content: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Número de espectadores (vazio = automático)', border: OutlineInputBorder()),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() => _customTotalViewers = null);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Automático'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => _customTotalViewers = int.tryParse(ctrl.text.trim()));
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Aplicar'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Personalizar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E78FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openAddPlatformDialog,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Plataforma', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: basePlatforms.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isWide ? 1.55 : 1.35,
            ),
            itemBuilder: (_, idx) {
              final p = basePlatforms[idx];
              final id = p['id'] as String;
              final name = p['name'] as String;
              final isOnline = p['active'] == true;
              final viewers = isOnline ? (p['viewers'] as int? ?? 0) : 0;

              return Stack(
                children: [
                  Positioned.fill(
                    child: PlatformGlassTile(
                      platform: id,
                      label: name,
                      isActive: isOnline,
                      onTap: () {
                        setState(() {
                          if (widget.activePlatforms.containsKey(id)) {
                            widget.activePlatforms[id] = !isOnline;
                          } else {
                            p['active'] = !isOnline;
                          }
                        });
                      },
                      onLongPress: () => _executeAction(name, 'Configurações RTMP abertas'),
                    ),
                  ),
                  // Quando em live: aparece "EM LIVE" a verde no canto superior direito; quando off: não aparece nada
                  if (isOnline)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 8)],
                        ),
                        child: const Text('EM LIVE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                  // Contador de espectadores em tempo real na parte inferior da tecla
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, size: 10, color: isOnline ? Colors.greenAccent : Colors.white54),
                          const SizedBox(width: 3),
                          Text('$viewers', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: isOnline ? Colors.white : Colors.white60)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatModule() {
    final allMsgs = [...widget.chatFeed, ..._liveChatBuffer];
    return HellCockpitWindow(
      title: 'CHAT UNIFICADO & VOZ TTS',
      icon: Icons.forum_rounded,
      accent: const Color(0xFF38BDF8),
      badge: _ttsEnabled ? 'TTS ON' : 'TTS OFF',
      onTestPressed: () => _executeAction('Chat & Voz TTS', 'Mensagem de teste lida com voz masculina real!'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...allMsgs.map((m) {
            final plat = m['platform'] ?? 'tiktok';
            final c = _platColor(plat);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF04091A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${m['user']}: ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: c)),
                  Expanded(child: Text(m['text'] ?? m['msg'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.white))),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _quickReplyCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Responder no chat ou falar no TTS...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: const Color(0xFF04091A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(_ttsEnabled ? Icons.record_voice_over : Icons.voice_over_off, color: _ttsEnabled ? Colors.greenAccent : Colors.white38, size: 20),
                onPressed: () => setState(() => _ttsEnabled = !_ttsEnabled),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8), size: 20),
                onPressed: () {
                  final t = _quickReplyCtrl.text.trim();
                  if (t.isEmpty) return;
                  setState(() {
                    _liveChatBuffer.insert(0, {'platform': 'youtube', 'user': 'Streamer (Tu)', 'text': t});
                    _quickReplyCtrl.clear();
                  });
                  _executeAction('Chat Unificado', t);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsModule() {
    return HellCockpitWindow(
      title: 'ALERTAS & INTERAÇÕES',
      icon: Icons.notifications_active_rounded,
      accent: const Color(0xFFA855F7),
      badge: '${_recentAlerts.length} EVENTOS',
      onTestPressed: () {
        setState(() {
          _recentAlerts.insert(0, {'type': 'SUB', 'user': 'AlexPro_PT', 'detail': 'Sub Tier 1 · Validado', 'color': const Color(0xFFA855F7), 'icon': Icons.star_rounded});
        });
        _executeAction('Alerta Subscrição', 'Som + Overlay + Agradecimento Vocal executados!');
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentAlerts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 64,
        ),
        itemBuilder: (_, i) {
          final a = _recentAlerts[i];
          final c = a['color'] as Color;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _executeAction('Reproduzir ${a['type']}', '${a['user']} · ${a['detail']}'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withOpacity(0.55)),
              ),
              child: Row(
                children: [
                  Icon(a['icon'] as IconData, color: c, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(a['user'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis),
                        Text(a['detail'] as String, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMixerModule() {
    Widget bar(String label, double val, Color c, ValueChanged<double> onChanged) {
      return Expanded(
        child: Column(
          children: [
            Container(
              height: 82,
              width: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF04091A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withOpacity(0.5)),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: val.clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.withOpacity(0.45), c]),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [BoxShadow(color: c.withOpacity(0.45), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(val * 100).round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(value: val, activeColor: c, onChanged: onChanged),
            ),
          ],
        ),
      );
    }

    return HellCockpitWindow(
      title: 'MIXER DE ÁUDIO & VOZ',
      icon: Icons.equalizer_rounded,
      accent: const Color(0xFF10B981),
      badge: _micMuted ? 'MIC MUTADO' : 'ÁUDIO 48kHz',
      onTestPressed: () => _executeAction('Mixer 48kHz', 'Retorno de áudio verificado nos canais!'),
      child: Column(
        children: [
          Row(
            children: [
              bar('Mic', _micMuted ? 0.0 : _micVol, const Color(0xFF38BDF8), (v) => setState(() => _micVol = v)),
              bar('Jogo', _gameVol, const Color(0xFFA855F7), (v) => setState(() => _gameVol = v)),
              bar('Música', _musicVol, const Color(0xFF10B981), (v) => setState(() => _musicVol = v)),
              bar('Alertas', _alertVol, const Color(0xFFF59E0B), (v) => setState(() => _alertVol = v)),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _micMuted ? Colors.redAccent : const Color(0xFF1E78FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () => setState(() => _micMuted = !_micMuted),
              icon: Icon(_micMuted ? Icons.mic_off : Icons.mic, size: 16),
              label: Text(_micMuted ? 'Ativar Microfone' : 'Mutar Microfone', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorAndClipsModule() {
    return HellCockpitWindow(
      title: 'DIRETOR IA & CLIPES 9:16',
      icon: Icons.auto_awesome_rounded,
      accent: const Color(0xFFF59E0B),
      badge: 'IA ATIVA',
      onTestPressed: () => _executeAction('Replay Buffer 30s', 'Momento guardado na Fábrica de Conteúdos!'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF04091A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
            ),
            child: const Row(
              children: [
                Icon(Icons.psychology_rounded, color: Color(0xFFF59E0B), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diretor IA: Pico de mensagens no chat! Ideal para puxar atrás e criar Clipe Vertical 9:16.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E78FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _executeAction('Clipe 9:16', 'Últimos 30s capturados para a Fábrica de Conteúdos!'),
              icon: const Icon(Icons.movie_creation_rounded, size: 18),
              label: const Text('CRIAR CLIPE 9:16 AGORA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF04091A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('HELL Beats · Cyber Stream Lo-Fi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(_isMusicPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFF38BDF8), size: 24),
                  onPressed: () => setState(() => _isMusicPlaying = !_isMusicPlaying),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGraphModule() {
    return HellCockpitWindow(
      title: 'SAÚDE DA LIVE & MÉTRICAS',
      icon: Icons.show_chart_rounded,
      accent: const Color(0xFF38BDF8),
      badge: '60 FPS · ESTÁVEL',
      onTestPressed: () => _executeAction('Diagnóstico Rede', 'Bitrate 6.5 Mbps · 0% Perda de Frames!'),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.white12)),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF38BDF8),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF38BDF8).withOpacity(0.22)),
                    spots: List.generate(_bitrateSamples.length, (i) => FlSpot(i.toDouble(), _bitrateSamples[i])),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricPill('BITRATE', '6.5 Mbps', const Color(0xFF38BDF8)),
              _metricPill('FPS', '60.0', Colors.greenAccent),
              _metricPill('PERDA', '0.0%', const Color(0xFFA855F7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF04091A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white54)),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: c)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isDesktop = w >= 1024;
        final isTablet = w >= 650 && w < 1024;

        if (isDesktop) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _buildTopCockpitHeader(true),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildChatModule()),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildAlertsModule(),
                        const SizedBox(height: 14),
                        _buildDirectorAndClipsModule(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildMixerModule(),
                        const SizedBox(height: 14),
                        _buildHealthGraphModule(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (isTablet) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopCockpitHeader(true),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildChatModule(),
                        const SizedBox(height: 14),
                        _buildDirectorAndClipsModule(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _buildAlertsModule(),
                        const SizedBox(height: 14),
                        _buildMixerModule(),
                        const SizedBox(height: 14),
                        _buildHealthGraphModule(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildTopCockpitHeader(false),
            const SizedBox(height: 12),
            _buildChatModule(),
            const SizedBox(height: 12),
            _buildAlertsModule(),
            const SizedBox(height: 12),
            _buildMixerModule(),
            const SizedBox(height: 12),
            _buildDirectorAndClipsModule(),
            const SizedBox(height: 12),
            _buildHealthGraphModule(),
          ],
        );
      },
    );
  }
}

// ABA 7: HELL GESTÃO IA (CÉREBRO INTELIGENTE 4K HDR)
class SmartBrainScreen extends StatefulWidget {
  const SmartBrainScreen({super.key});

  @override
  State<SmartBrainScreen> createState() => _SmartBrainScreenState();
}

class _SmartBrainScreenState extends State<SmartBrainScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<Map<String, String>> _directorFeed = [
    {'tag': 'DIRETOR AO VIVO', 'msg': 'Pico de atividade no chat nos últimos 4 minutos. Boa altura para lançar a Roleta 3D!'},
    {'tag': 'HORÁRIO NOBRE', 'msg': 'As tuas lives entre as 21h00 e as 23h30 têm +38% de retenção média.'},
    {'tag': 'ENGAJAMENTO', 'msg': '64% da audiência interage mais durante desafios interativos e agradecimentos por voz.'},
    {'tag': 'RELATÓRIO IA', 'msg': 'Última live gerou +42 novos seguidores e 1.250 gostos.'},
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'HELL GESTÃO IA · AI STREAM DIRECTOR 4K',
          icon: Icons.psychology_rounded,
          accent: const Color(0xFF8B5CF6),
          badge: 'CÉREBRO ATIVO',
          onTestPressed: () {
            setState(() {
              _directorFeed.insert(0, {'tag': 'DIAGNÓSTICO IA', 'msg': 'Retenção 94% · Recomendação: Ativar meta relâmpago nos próximos 5 minutos!'});
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._directorFeed.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF04091A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['tag'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                        const SizedBox(height: 3),
                        Text(item['msg'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Pedir análise de horário, título ou ideia de live...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      final q = _promptCtrl.text.trim();
                      if (q.isEmpty) return;
                      setState(() {
                        _directorFeed.insert(0, {'tag': 'RESPOSTA IA', 'msg': 'Para "$q": Foca os primeiros 10 minutos num desafio rápido com o chat para maximizar o algoritmo.'});
                        _promptCtrl.clear();
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
// ABA 8: HELL FÁBRICA DE CONTEÚDOS IA (EDITOR TIMELINE 9:16/16:9 + ESTILOS + ENGAJAMENTO + EXPORTAÇÃO)
class ContentFactoryScreen extends StatefulWidget {
  const ContentFactoryScreen({super.key});

  @override
  State<ContentFactoryScreen> createState() => _ContentFactoryScreenState();
}

class _ContentFactoryScreenState extends State<ContentFactoryScreen> {
  String _captionLang = 'Português (PT-PT)';
  String _selectedFormat = '9:16 Vertical (TikTok / Reels / Shorts)';
  String _selectedMood = 'Épico / Cinematográfico';
  String _selectedFilter = 'HDR Cyber Neon (Grátis)';
  double _trimStart = 0.15;
  double _trimEnd = 0.85;
  int _viralScore = 92;
  final TextEditingController _thumbTitleCtrl = TextEditingController(text: 'JOGADA ÉPICA AO VIVO!');
  final TextEditingController _hashtagsCtrl = TextEditingController(text: '#gaming #portugal #livestream #viral #fyp');

    final List<Map<String, dynamic>> _clipsQueue = [
    {'title': 'Clipe #1 · Pico de Chat ao Vivo', 'format': '9:16 Vertical', 'mood': 'Divertido', 'score': '94%', 'createdAt': DateTime.now().subtract(const Duration(minutes: 25)), 'saved': false},
    {'title': 'Clipe #2 · Vitória no Desafio Final', 'format': '9:16 Vertical', 'mood': 'Épico', 'score': '96%', 'createdAt': DateTime.now().subtract(const Duration(hours: 2)), 'saved': false},
    {'title': 'Clipe #3 · Momento Galáxia Cósmica', 'format': '16:9 YouTube', 'mood': 'Alegre', 'score': '89%', 'createdAt': DateTime.now().subtract(const Duration(hours: 25)), 'saved': false},
  ];

  @override
  void initState() {
    super.initState();
    _clipsQueue.removeWhere((c) => c['saved'] != true && DateTime.now().difference(c['createdAt'] as DateTime).inHours >= 24);
  }


  @override
  void dispose() {
    _thumbTitleCtrl.dispose();
    _hashtagsCtrl.dispose();
    super.dispose();
  }

  void _runAiAnalysis() {
    setState(() {
      _viralScore = 88 + (_thumbTitleCtrl.text.length % 11);
      if (_selectedMood.contains('Épico')) {
        _thumbTitleCtrl.text = 'NINGUÉM ACREDITOU NISTO AO VIVO! 🔥';
        _hashtagsCtrl.text = '#epico #gamingpt #twitch #tiktoklive #viral';
      } else if (_selectedMood.contains('Divertido')) {
        _thumbTitleCtrl.text = 'O MOMENTO MAIS ENGRAÇADO DA LIVE 😂';
        _hashtagsCtrl.text = '#humor #live #clipes #funny #fyp';
      } else if (_selectedMood.contains('Gaming')) {
        _thumbTitleCtrl.text = 'CLUTCH IMPOSSÍVEL NO ÚLTIMO SEGUNDO! 🎯';
        _hashtagsCtrl.text = '#gamer #clutch #highlights #proplay #shorts';
      } else {
        _thumbTitleCtrl.text = 'A VERDADE SOBRE ISTO EM DIRETO 🎙️';
        _hashtagsCtrl.text = '#conversa #podcast #opiniao #livept #reels';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🤖 Análise IA concluída! Potencial Viral: $_viralScore/100'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'ESTÚDIO DE EDIÇÃO & TIMELINE IA 4K HDR',
          icon: Icons.movie_filter_rounded,
          accent: const Color(0xFFF43F5E),
          badge: 'BASE GRÁTIS · PRO VIP',
          onTestPressed: _runAiAnalysis,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 92,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E78FF), Color(0xFF0A1433), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_thumbTitleCtrl.text.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.1, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('$_selectedFormat · $_selectedMood · $_selectedFilter', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7DD3FC))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Corte Timeline (Início / Fim do Clipe):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70)),
              RangeSlider(
                values: RangeValues(_trimStart, _trimEnd),
                activeColor: const Color(0xFFF43F5E),
                onChanged: (v) => setState(() {
                  _trimStart = v.start;
                  _trimEnd = v.end;
                }),
              ),
              DropdownButtonFormField<String>(
                value: _selectedFormat,
                decoration: const InputDecoration(labelText: 'Formato de Entrega nas Redes', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '9:16 Vertical (TikTok / Reels / Shorts)', child: Text('9:16 Vertical (TikTok / Reels / Shorts)')),
                  DropdownMenuItem(value: '16:9 Widescreen (YouTube 4K)', child: Text('16:9 Widescreen (YouTube 4K)')),
                  DropdownMenuItem(value: '1:1 Quadrado (Feed Instagram / X)', child: Text('1:1 Quadrado (Feed Instagram / X)')),
                ],
                onChanged: (v) => setState(() => _selectedFormat = v ?? _selectedFormat),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMood,
                decoration: const InputDecoration(labelText: 'Estilo de Edição Automática IA', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Épico / Cinematográfico', child: Text('🔥 Épico / Cinematográfico')),
                  DropdownMenuItem(value: 'Divertido / Memes & Zoom', child: Text('😂 Divertido / Memes & Zoom')),
                  DropdownMenuItem(value: 'Gaming / Highlights Rápidos', child: Text('🎮 Gaming / Highlights Rápidos')),
                  DropdownMenuItem(value: 'Sério / Conversa & Podcast', child: Text('🎙️ Sério / Conversa & Podcast')),
                  DropdownMenuItem(value: 'Alegre / Vlogs & Presentes', child: Text('✨ Alegre / Vlogs & Presentes')),
                ],
                onChanged: (v) => setState(() => _selectedMood = v ?? _selectedMood),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedFilter,
                decoration: const InputDecoration(labelText: 'Filtro & LUT de Cor (Grátis vs. VIP)', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'HDR Cyber Neon (Grátis)', child: Text('HDR Cyber Neon (Grátis)')),
                  DropdownMenuItem(value: 'Clean Broadcast 4K (Grátis)', child: Text('Clean Broadcast 4K (Grátis)')),
                  DropdownMenuItem(value: '👑 Cinema Dolby Vision LUT (VIP)', child: Text('👑 Cinema Dolby Vision LUT (VIP)')),
                  DropdownMenuItem(value: '👑 IA Auto-Zoom & Efeitos 3D (VIP)', child: Text('👑 IA Auto-Zoom & Efeitos 3D (VIP)')),
                ],
                onChanged: (v) => setState(() => _selectedFilter = v ?? _selectedFilter),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _captionLang,
                decoration: const InputDecoration(labelText: 'Legendas Automáticas & Tradução', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Português (PT-PT)', child: Text('Português (PT-PT)')),
                  DropdownMenuItem(value: 'English (EN)', child: Text('English (EN)')),
                  DropdownMenuItem(value: 'Español (ES)', child: Text('Español (ES)')),
                ],
                onChanged: (v) => setState(() => _captionLang = v ?? _captionLang),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎬 Renderizado em $_selectedFormat e pronto para publicar!'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.publish_rounded, size: 17),
                      label: const Text('Exportar & Publicar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('💾 Ficheiro MP4 guardado na galeria para edição externa!'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Guardar MP4', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HellCockpitWindow(
          title: 'AVALIAÇÃO DE ENGAJAMENTO IA & HASHTAGS',
          icon: Icons.insights_rounded,
          accent: const Color(0xFF38BDF8),
          badge: 'SCORE $_viralScore/100',
          onTestPressed: _runAiAnalysis,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _thumbTitleCtrl, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(labelText: 'Título Otimizado por IA', isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _hashtagsCtrl, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(labelText: 'Hashtags Recomendadas IA', isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 10),
              ..._clipsQueue.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                    child: Row(
                      children: [
                        const Icon(Icons.movie_creation_outlined, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              Text('${c['format']} · Estilo ${c['mood']}', style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
                            ],
                          ),
                        ),
                        Text('Viral ${c['score']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.greenAccent)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ABA 10: HELL CRESCIMENTO E NEGÓCIO (GRÁFICOS REAIS FL_CHART)
class GrowthAnalyticsScreen extends StatelessWidget {
  const GrowthAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _neonBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📈 Evolução de Seguidores (Últimos 7 Dias)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.white12)),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: const Color(0xFF38BDF8),
                        barWidth: 3.5,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: const Color(0xFF38BDF8).withOpacity(0.18)),
                        spots: const [
                          FlSpot(1, 120),
                          FlSpot(2, 185),
                          FlSpot(3, 240),
                          FlSpot(4, 310),
                          FlSpot(5, 420),
                          FlSpot(6, 510),
                          FlSpot(7, 645),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _neonBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 Métricas Individuais por Plataforma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
              const SizedBox(height: 4),
              const Text(
                'Nota: Os espectadores simultâneos são apresentados separadamente por canal e nunca somados como pessoas únicas.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(height: 10),
              _platformStatRow('TikTok LIVE', '142 simultâneos', '+84 seguidores', const Color(0xFF25F4EE)),
              _platformStatRow('Twitch', '68 simultâneos', '+29 seguidores', const Color(0xFF9146FF)),
              _platformStatRow('YouTube LIVE', '54 simultâneos', '+21 seguidores', const Color(0xFFFF4444)),
              _platformStatRow('Kick', '41 simultâneos', '+18 seguidores', const Color(0xFF53FC18)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _platformStatRow(String name, String concurrent, String followers, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
          Text(concurrent, style: const TextStyle(fontSize: 12, color: Colors.white)),
          Text(followers, style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ABA 11: HELL GESTÃO DO NEGÓCIO + PATROCÍNIOS & PUBLICIDADES PAGAS
class CreatorBusinessScreen extends StatefulWidget {
  final bool isOwner;
  const CreatorBusinessScreen({super.key, this.isOwner = false});

  @override
  State<CreatorBusinessScreen> createState() => _CreatorBusinessScreenState();
}

class _CreatorBusinessScreenState extends State<CreatorBusinessScreen> {
  final _descCtrl = TextEditingController();
  final _valCtrl = TextEditingController();
  String _txType = 'Receita';

  final List<Map<String, dynamic>> _transactions = [
    {'desc': 'Presentes & Subscrições Live', 'amount': 145.50, 'type': 'Receita'},
    {'desc': 'Campanha Patrocinador Gaming', 'amount': 250.00, 'type': 'Receita'},
    {'desc': 'Equipamento Áudio / Microfone', 'amount': 65.00, 'type': 'Despesa'},
  ];

  final _sponsorTitleCtrl = TextEditingController();
  final _sponsorUrlCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;
    for (final t in _transactions) {
      if (t['type'] == 'Receita') {
        income += (t['amount'] as num).toDouble();
      } else {
        expense += (t['amount'] as num).toDouble();
      }
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '💰 Finanças'),
              Tab(text: '📢 Patrocínios & Ads'),
              Tab(text: '🏢 Agência & Equipa'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 11.1 FINANCE MANAGER
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _neonBox(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [const Text('Receitas', style: TextStyle(fontSize: 11, color: Colors.white60)), Text('+${income.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))]),
                          Column(children: [const Text('Despesas', style: TextStyle(fontSize: 11, color: Colors.white60)), Text('-${expense.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]),
                          Column(children: [const Text('Saldo', style: TextStyle(fontSize: 11, color: Colors.white60)), Text('${(income - expense).toStringAsFixed(2)} €', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900))]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _txType,
                          dropdownColor: const Color(0xFF0B1636),
                          items: ['Receita', 'Despesa'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _txType = v ?? 'Receita'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Descrição...', isDense: true))),
                        const SizedBox(width: 6),
                        SizedBox(width: 75, child: TextField(controller: _valCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '€', isDense: true))),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8)),
                          onPressed: () {
                            final v = double.tryParse(_valCtrl.text.replaceAll(',', '.')) ?? 0.0;
                            if (_descCtrl.text.trim().isNotEmpty && v > 0) {
                              setState(() {
                                _transactions.insert(0, {'desc': _descCtrl.text.trim(), 'amount': v, 'type': _txType});
                                _descCtrl.clear();
                                _valCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    ..._transactions.map((t) => ListTile(
                          dense: true,
                          title: Text(t['desc'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            '${t['type'] == 'Receita' ? '+' : '-'}${(t['amount'] as num).toStringAsFixed(2)} €',
                            style: TextStyle(color: t['type'] == 'Receita' ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        )),
                  ],
                ),

                // 11.2 - 11.4 PATROCÍNIOS, CONTRATOS & PUBLICIDADES PAGAS (RODAPÉ)
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📢 Patrocínios & Publicidades Ativas no Rodapé', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 8),
                          ...SponsorBannerManager.activeSponsors.asMap().entries.map((e) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.value['title']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                trailing: widget.isOwner
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () => setState(() => SponsorBannerManager.activeSponsors.removeAt(e.key)),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF38BDF8)),
                                        onPressed: () => launchUrl(Uri.parse(e.value['url']!), mode: LaunchMode.externalApplication),
                                      ),
                              )),
                          if (widget.isOwner) ...[
                            const Divider(color: Colors.white12),
                            const Text('👑 Painel Dono: Adicionar Publicidade no Rodapé', style: TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(controller: _sponsorTitleCtrl, decoration: const InputDecoration(hintText: 'Texto da campanha / patrocinador...', isDense: true)),
                            const SizedBox(height: 6),
                            TextField(controller: _sponsorUrlCtrl, decoration: const InputDecoration(hintText: 'Link da campanha (https://...)', isDense: true)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                              onPressed: () {
                                if (_sponsorTitleCtrl.text.trim().isNotEmpty) {
                                  setState(() {
                                    SponsorBannerManager.activeSponsors.insert(0, {
                                      'title': _sponsorTitleCtrl.text.trim(),
                                      'url': _sponsorUrlCtrl.text.trim().isEmpty ? 'mailto:hellcreatoros@gmail.com' : _sponsorUrlCtrl.text.trim(),
                                    });
                                    _sponsorTitleCtrl.clear();
                                    _sponsorUrlCtrl.clear();
                                  });
                                }
                              },
                              child: const Text('Publicar no Rodapé da App', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // 11.5 - 11.7 TEAM MANAGEMENT, SPONSOR MATCH AI & AGENCY DASHBOARD
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏢 Agency Dashboard & Sponsor Match AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text('• Gestão de vários criadores, permissões de equipa e relatórios globais.\n• Sponsor Match AI: Setores recomendados para o teu perfil — Gaming Peripherals, Energia & Software.\n• Contacto Comercial Oficial: hellcreatoros@gmail.com', style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5)),
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
