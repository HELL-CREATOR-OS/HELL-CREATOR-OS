import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// CENTRO DE CONTROLO - COCKPIT COMPLETO (PC 3 COLUNAS, TABLET 2 COLUNAS, MOBILE RICA + ECRÃ CHEIO + SIMULADOR OFFLINE)
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
  String? _expandedPanelId;
  bool _ttsEnabled = true;
  bool _isMusicPlaying = true;
  final TextEditingController _chatFilterCtrl = TextEditingController();
  final TextEditingController _quickReplyCtrl = TextEditingController();
  double _micVol = 0.85;
  double _gameVol = 0.65;
  double _musicVol = 0.45;
  double _alertVol = 0.90;
  bool _micMuted = false;

  final List<Map<String, String>> _simChat = [
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

  @override
  void dispose() {
    _chatFilterCtrl.dispose();
    _quickReplyCtrl.dispose();
    super.dispose();
  }

  void _triggerOfflineSim(String type) {
    setState(() {
      if (type == 'sub') {
        _recentAlerts.insert(0, {'type': 'SUB SIM', 'user': 'AlexPro_PT', 'detail': 'Subscrição Simulada', 'color': const Color(0xFFA855F7), 'icon': Icons.star_rounded});
        _simChat.insert(0, {'platform': 'twitch', 'user': 'AlexPro_PT', 'text': 'Acabei de subscrever ao canal!'});
      } else if (type == 'donation') {
        _recentAlerts.insert(0, {'type': 'DONATION SIM', 'user': 'MarianaVIP', 'detail': '€10.00 · Teste Offline', 'color': const Color(0xFF10B981), 'icon': Icons.euro_rounded});
        _simChat.insert(0, {'platform': 'youtube', 'user': 'MarianaVIP', 'text': 'Força na live, continua assim!'});
      } else if (type == 'gift') {
        _recentAlerts.insert(0, {'type': 'PRESENTE SIM', 'user': '@pedro_tk', 'detail': 'Leão Rei (29999 Moedas)', 'color': const Color(0xFFF43F5E), 'icon': Icons.local_fire_department});
        _simChat.insert(0, {'platform': 'tiktok', 'user': '@pedro_tk', 'text': 'Enviou um Leão Rei!'});
      } else {
        _recentAlerts.insert(0, {'type': 'FOLLOW SIM', 'user': 'RuiStream', 'detail': 'Novo Seguidor (Teste)', 'color': const Color(0xFF38BDF8), 'icon': Icons.person_add_alt_1});
        _simChat.insert(0, {'platform': 'kick', 'user': 'RuiStream', 'text': 'Cheguei agora à transmissão!'});
      }
      if (_recentAlerts.length > 6) _recentAlerts.removeLast();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulação Offline disparada com sucesso!'),
        backgroundColor: Color(0xFF1E78FF),
        duration: Duration(seconds: 2),
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

  Widget _cockpitCard({
    required String id,
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
    String? badge,
  }) {
    final isExpanded = _expandedPanelId == id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12255B), Color(0xFF091330), Color(0xFF04091A)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(isExpanded ? 0.95 : 0.5), width: isExpanded ? 1.8 : 1.3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: accent.withOpacity(isExpanded ? 0.3 : 0.16), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.5)),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.4, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.5)),
                  ),
                  child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: accent)),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expandedPanelId = isExpanded ? null : id),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 17, color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Colors.white12),
          child,
        ],
      ),
    );
  }

  Widget _buildTopCockpitHeader(bool isWide) {
    final activeCount = widget.activePlatforms.values.where((v) => v).length;
    final pills = [
      {'id': 'tiktok', 'name': 'TikTok', 'viewers': widget.activePlatforms['tiktok'] == true ? '2.1K' : 'OFF', 'color': const Color(0xFFFF2A5F)},
      {'id': 'twitch', 'name': 'Twitch', 'viewers': widget.activePlatforms['twitch'] == true ? '1.8K' : 'OFF', 'color': const Color(0xFF9146FF)},
      {'id': 'youtube', 'name': 'YouTube', 'viewers': widget.activePlatforms['youtube'] == true ? '1.5K' : 'OFF', 'color': const Color(0xFFFF0033)},
      {'id': 'kick', 'name': 'Kick', 'viewers': widget.activePlatforms['kick'] == true ? '900' : 'OFF', 'color': const Color(0xFF53FC18)},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF142A66), Color(0xFF08122E), Color(0xFF040817)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.85), blurRadius: 18, offset: const Offset(0, 7)),
          BoxShadow(color: const Color(0xFF1E78FF).withOpacity(0.24), blurRadius: 22),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.45), blurRadius: 14)],
                ),
                child: Image.asset('icon.png', width: 34, height: 34, errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: Color(0xFF38BDF8), size: 30)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CENTRO DE CONTROLO · COCKPIT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.8, color: Colors.white)),
                      Text(
                        activeCount > 0 ? '$activeCount Plataformas em Direto · Sincronizado' : 'Modo Pré-Live & Simulação Offline Ativo',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: activeCount > 0 ? Colors.greenAccent : const Color(0xFF7DD3FC)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF1E78FF).withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: activeCount > 0 ? Colors.redAccent : const Color(0xFF38BDF8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, size: 10, color: activeCount > 0 ? Colors.redAccent : const Color(0xFF38BDF8)),
                      const SizedBox(width: 5),
                      Text(activeCount > 0 ? 'AO VIVO' : 'SIMULAÇÃO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 8,
              childAspectRatio: isWide ? 3.4 : 2.9,
              children: pills.map((p) {
                final c = p['color'] as Color;
                final on = widget.activePlatforms[p['id']] == true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04091A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: on ? c : c.withOpacity(0.45), width: on ? 1.6 : 1.1),
                    boxShadow: [BoxShadow(color: c.withOpacity(on ? 0.28 : 0.12), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sensors_rounded, size: 16, color: c),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white), overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        p['viewers'] as String,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: on ? Colors.white : c),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('TESTAR EM OFFLINE: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF7DD3FC), letterSpacing: 0.6)),
                  const SizedBox(width: 6),
                  _simChip('Simular Sub', const Color(0xFFA855F7), () => _triggerOfflineSim('sub')),
                  const SizedBox(width: 6),
                  _simChip('Simular Doação €10', const Color(0xFF10B981), () => _triggerOfflineSim('donation')),
                  const SizedBox(width: 6),
                  _simChip('Simular Leão VIP', const Color(0xFFF43F5E), () => _triggerOfflineSim('gift')),
                  const SizedBox(width: 6),
                  _simChip('Simular Seguidor', const Color(0xFF38BDF8), () => _triggerOfflineSim('follow')),
                ],
              ),
            ),
          ],
        ),
      );
    }

  Widget _simChip(String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 14, color: color),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatModule(bool expanded) {
    final allMsgs = [...widget.chatFeed, ..._simChat];
    final shown = expanded ? allMsgs : allMsgs.take(4).toList();
    return _cockpitCard(
      id: 'chat',
      title: 'CHAT UNIFICADO & VOZ TTS',
      icon: Icons.forum_rounded,
      accent: const Color(0xFF38BDF8),
      badge: _ttsEnabled ? 'TTS ON' : 'TTS OFF',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...shown.map((m) {
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
                  Expanded(child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.white), overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis)),
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
                    _simChat.insert(0, {'platform': 'youtube', 'user': 'Streamer (Tu)', 'text': t});
                    _quickReplyCtrl.clear();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsModule(bool expanded) {
    final items = expanded ? _recentAlerts : _recentAlerts.take(4).toList();
    return _cockpitCard(
      id: 'alerts',
      title: 'ALERTAS & INTERAÇÕES',
      icon: Icons.notifications_active_rounded,
      accent: const Color(0xFFA855F7),
      badge: '${_recentAlerts.length} EVENTOS',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 64,
        ),
        itemBuilder: (_, i) {
          final a = items[i];
          final c = a['color'] as Color;
          return Container(
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
          );
        },
      ),
    );
  }

  Widget _buildMixerModule(bool expanded) {
    Widget bar(String label, double val, Color c, ValueChanged<double> onChanged) {
      return Expanded(
        child: Column(
          children: [
            Container(
              height: expanded ? 120 : 78,
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
            const SizedBox(height: 5),
            Text('${(val * 100).round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
            if (expanded)
              Slider(value: val, activeColor: c, onChanged: onChanged),
          ],
        ),
      );
    }

    return _cockpitCard(
      id: 'mixer',
      title: 'MIXER DE ÁUDIO & VOZ',
      icon: Icons.equalizer_rounded,
      accent: const Color(0xFF10B981),
      badge: _micMuted ? 'MIC MUTADO' : 'ÁUDIO 48kHz',
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
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
        ],
      ),
    );
  }
  Widget _buildDirectorAndClipsModule(bool expanded) {
    return _cockpitCard(
      id: 'director',
      title: 'DIRETOR IA & CLIPES 9:16',
      icon: Icons.auto_awesome_rounded,
      accent: const Color(0xFFF59E0B),
      badge: 'IA ATIVA',
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
                    'Sugestão IA: Pico de mensagens no chat! Ideal para criar um Clipe Vertical 9:16 agora.',
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clipe Vertical 9:16 marcado e enviado para a Fábrica de Conteúdos!'), backgroundColor: Colors.green),
                );
              },
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

  Widget _buildHealthGraphModule(bool expanded) {
    return _cockpitCard(
      id: 'health',
      title: 'SAÚDE DA LIVE & MÉTRICAS',
      icon: Icons.show_chart_rounded,
      accent: const Color(0xFF38BDF8),
      badge: '60 FPS · ESTÁVEL',
      child: Column(
        children: [
          SizedBox(
            height: expanded ? 160 : 88,
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

        if (_expandedPanelId != null) {
          Widget fullPanel;
          switch (_expandedPanelId) {
            case 'chat':
              fullPanel = _buildChatModule(true);
              break;
            case 'alerts':
              fullPanel = _buildAlertsModule(true);
              break;
            case 'mixer':
              fullPanel = _buildMixerModule(true);
              break;
            case 'director':
              fullPanel = _buildDirectorAndClipsModule(true);
              break;
            default:
              fullPanel = _buildHealthGraphModule(true);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopCockpitHeader(w >= 650),
              const SizedBox(height: 14),
              fullPanel,
            ],
          );
        }

        if (isDesktop) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _buildTopCockpitHeader(true),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildChatModule(true)),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildAlertsModule(false),
                        const SizedBox(height: 14),
                        _buildDirectorAndClipsModule(false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildMixerModule(false),
                        const SizedBox(height: 14),
                        _buildHealthGraphModule(false),
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
                        _buildChatModule(false),
                        const SizedBox(height: 14),
                        _buildDirectorAndClipsModule(false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _buildAlertsModule(false),
                        const SizedBox(height: 14),
                        _buildMixerModule(false),
                        const SizedBox(height: 14),
                        _buildHealthGraphModule(false),
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
            _buildChatModule(false),
            const SizedBox(height: 12),
            _buildAlertsModule(false),
            const SizedBox(height: 12),
            _buildMixerModule(false),
            const SizedBox(height: 12),
            _buildDirectorAndClipsModule(false),
            const SizedBox(height: 12),
            _buildHealthGraphModule(false),
          ],
        );
      },
    );
  }
}

// ABA 7: HELL GESTÃO IA (CÉREBRO INTELIGENTE)
class SmartBrainScreen extends StatefulWidget {
  const SmartBrainScreen({super.key});

  @override
  State<SmartBrainScreen> createState() => _SmartBrainScreenState();
}

class _SmartBrainScreenState extends State<SmartBrainScreen> {
  final _promptCtrl = TextEditingController();
  final List<String> _directorFeed = [
    '🎯 AI Stream Director: Pico de atividade no chat nos últimos 4 minutos. Boa altura para lançar a Roleta 3D!',
    '📈 Growth Recommendation: As tuas lives entre as 21h00 e as 23h30 têm +38% de retenção média.',
    '👥 Audience Intelligence: 64% da audiência interage mais durante desafios interativos.',
    '📋 Automatic Report: Última live gerou +42 novos seguidores e 1.250 gostos.',
  ];

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
              const Text('🧠 HELL Gestão IA · AI Stream Director', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF38BDF8))),
              const SizedBox(height: 10),
              ..._directorFeed.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF050B1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                    child: Text(item, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      decoration: const InputDecoration(hintText: 'Pedir análise de horário, título ou ideia de live...', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      final q = _promptCtrl.text.trim();
                      if (q.isEmpty) return;
                      setState(() {
                        _directorFeed.insert(0, '🤖 Resposta IA para "$q": Foca os primeiros 10 minutos num desafio rápido com o chat para maximizar o algoritmo.');
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

// ABA 8: HELL FÁBRICA DE CONTEÚDOS
class ContentFactoryScreen extends StatefulWidget {
  const ContentFactoryScreen({super.key});

  @override
  State<ContentFactoryScreen> createState() => _ContentFactoryScreenState();
}

class _ContentFactoryScreenState extends State<ContentFactoryScreen> {
  String _captionLang = 'Português (PT-PT)';
  final _thumbTitleCtrl = TextEditingController(text: 'JOGADA ÉPICA AO VIVO!');
  final List<Map<String, String>> _clipsQueue = [
    {'title': 'Clip #1 · Pico de Reações no Chat (00:42)', 'format': 'Vertical 9:16 · TikTok / Shorts', 'status': 'Pronto'},
    {'title': 'Clip #2 · Vitória no Desafio da Roleta (00:58)', 'format': 'Vertical 9:16 · Reels', 'status': 'Legendado'},
  ];

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
              const Text('🎬 Automatic Clips & Vertical Video (9:16)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              ..._clipsQueue.map((c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie_creation_outlined, color: Color(0xFF38BDF8)),
                    title: Text(c['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    subtitle: Text(c['format']!, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    trailing: Text(c['status']!, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11.5)),
                  )),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () {
                  setState(() {
                    _clipsQueue.insert(0, {
                      'title': 'Clip #${_clipsQueue.length + 1} · Momento Marcado Agora',
                      'format': 'Vertical 9:16 · Legendas $_captionLang',
                      'status': 'Exportado',
                    });
                  });
                },
                icon: const Icon(Icons.cut, size: 17, color: Colors.white),
                label: const Text('Marcar & Gerar Clip Vertical 9:16', style: TextStyle(color: Colors.white)),
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
              const Text('📝 Legendas Automáticas, Tradução & Thumbnail Creator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _captionLang,
                dropdownColor: const Color(0xFF0B1636),
                decoration: const InputDecoration(labelText: 'Idioma das Legendas & Tradução', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'Português (PT-PT)', child: Text('Português (PT-PT)')),
                  DropdownMenuItem(value: 'English (EN)', child: Text('English (EN)')),
                  DropdownMenuItem(value: 'Español (ES)', child: Text('Español (ES)')),
                ],
                onChanged: (v) => setState(() => _captionLang = v ?? 'Português (PT-PT)'),
              ),
              const SizedBox(height: 8),
              TextField(controller: _thumbTitleCtrl, decoration: const InputDecoration(labelText: 'Texto da Thumbnail HD', isDense: true)),
              const SizedBox(height: 8),
              Container(
                height: 75,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E78FF), Color(0xFF050B1E)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                alignment: Alignment.center,
                child: Text(_thumbTitleCtrl.text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: Colors.white)),
              ),
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
