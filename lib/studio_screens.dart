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
      gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1E429F), width: 1.2),
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

// CENTRO DE CONTROLO • COCKPIT MODULAR EXPANSÍVEL (SEM PERFIL E SEM SYNC QR)
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
  final TextEditingController _chatFilterCtrl = TextEditingController();
  final TextEditingController _bannedWordCtrl = TextEditingController();
  final List<String> _bannedWords = ['spam', 'scam', 'link falso'];
  final List<String> _moderators = ['@Mod_Joao', '@Mod_Sofia'];
  String _activeObsScene = 'Cena Principal (Jogo)';

  @override
  void dispose() {
    _chatFilterCtrl.dispose();
    _bannedWordCtrl.dispose();
    super.dispose();
  }

  Widget _panelShell({
    required String id,
    required String title,
    required IconData icon,
    required Color accent,
    required Widget compactBody,
    required Widget expandedBody,
    String? badge,
  }) {
    final isExpanded = _expandedPanelId == id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1636),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(isExpanded ? 0.85 : 0.35), width: isExpanded ? 1.5 : 1),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: accent), overflow: TextOverflow.ellipsis),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: accent.withOpacity(0.16), borderRadius: BorderRadius.circular(8)),
                  child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expandedPanelId = isExpanded ? null : id),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                  child: Icon(isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white12),
          isExpanded ? expandedBody : compactBody,
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final activeCount = widget.activePlatforms.values.where((v) => v).length;
    final obsUrl = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay';
    final filteredChat = widget.chatFeed.where((m) {
      final q = _chatFilterCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (m['user'] ?? '').toLowerCase().contains(q) || (m['text'] ?? '').toLowerCase().contains(q);
    }).toList();

    final livePanel = _panelShell(
      id: 'live',
      title: 'Transmissões Multiplataforma',
      icon: Icons.sensors_rounded,
      accent: activeCount > 0 ? Colors.greenAccent : const Color(0xFF38BDF8),
      badge: activeCount > 0 ? '$activeCount EM DIRETO' : 'EM ESPERA',
      compactBody: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: ['tiktok', 'twitch', 'youtube', 'kick'].map((p) {
          final on = widget.activePlatforms[p] == true;
          return Chip(
            backgroundColor: on ? Colors.greenAccent.withOpacity(0.18) : Colors.white10,
            avatar: Icon(Icons.circle, size: 10, color: on ? Colors.greenAccent : Colors.white38),
            label: Text(p.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: on ? Colors.greenAccent : Colors.white60)),
          );
        }).toList(),
      ),
      expandedBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ['tiktok', 'twitch', 'youtube', 'kick'].map((p) {
          final on = widget.activePlatforms[p] == true;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.circle, size: 12, color: on ? Colors.greenAccent : Colors.white30),
            title: Text(p.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(on ? 'Sinal ativo • Chat e eventos sincronizados' : 'Aguardando ligação na aba Configurações'),
            trailing: Text(on ? 'ONLINE' : 'OFFLINE', style: TextStyle(fontWeight: FontWeight.bold, color: on ? Colors.greenAccent : Colors.white38)),
          );
        }).toList(),
      ),
    );

    final chatPanel = _panelShell(
      id: 'chat',
      title: 'Chat Unificado & Moderação',
      icon: Icons.forum_rounded,
      accent: const Color(0xFF38BDF8),
      badge: '${widget.chatFeed.length} msgs',
      compactBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filteredChat.isEmpty
            ? [const Text('Sem mensagens no feed neste momento.', style: TextStyle(fontSize: 12, color: Colors.white54))]
            : filteredChat.take(4).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('[${(m['platform'] ?? 'LIVE').toUpperCase()}] ${m['user']}: ${m['text']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                )).toList(),
      ),
      expandedBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _chatFilterCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Filtrar mensagens ou utilizador', isDense: true)),
          const SizedBox(height: 8),
          ...filteredChat.take(15).map((m) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${m['user']} (${(m['platform'] ?? 'LIVE').toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF38BDF8))),
                subtitle: Text(m['text'] ?? '', style: const TextStyle(fontSize: 12)),
              )),
          const Divider(),
          Text('Moderadores ativos: ${_moderators.join(', ')}', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _bannedWordCtrl, decoration: const InputDecoration(labelText: 'Adicionar palavra bloqueada', isDense: true))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (_bannedWordCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _bannedWords.add(_bannedWordCtrl.text.trim());
                    _bannedWordCtrl.clear();
                  });
                }
              },
              child: const Text('Bloquear'),
            ),
          ]),
        ],
      ),
    );

    final obsPanel = _panelShell(
      id: 'obs',
      title: 'Estúdio OBS / Streamlabs / TikTok Live',
      icon: Icons.videocam_rounded,
      accent: const Color(0xFFA855F7),
      badge: _activeObsScene,
      compactBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cena Ativa: $_activeObsScene', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('Overlay Browser Source: $obsUrl', style: const TextStyle(fontSize: 11, color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      expandedBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('Link Overlay (OBS / Streamlabs / TikTok Studio):\n$obsUrl', style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Cena Principal (Jogo)', 'Just Chatting / Câmara', 'Intervalo / Pausa', 'Encerramento'].map((sc) => ChoiceChip(
              label: Text(sc),
              selected: _activeObsScene == sc,
              onSelected: (_) => setState(() => _activeObsScene = sc),
            )).toList(),
          ),
        ],
      ),
    );

    final statsPanel = _panelShell(
      id: 'stats',
      title: 'Telemetria, Metas & Streamdeck HELL',
      icon: Icons.analytics_rounded,
      accent: Colors.amberAccent,
      badge: widget.isSecondScreenPaired ? '2.º ECRÃ ATIVO' : 'PRONTO',
      compactBody: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Plataformas: $activeCount/4', style: const TextStyle(fontSize: 12)),
          Text('Segundo Ecrã: ${widget.isSecondScreenPaired ? 'Ligado' : 'Em espera'}', style: const TextStyle(fontSize: 12)),
          const Text('Motor: 60 FPS', style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
        ],
      ),
      expandedBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Plataformas Conectadas'), trailing: Text('$activeCount de 4')),
          ListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Mensagens Processadas na Sessão'), trailing: Text('${widget.chatFeed.length}')),
          ListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Estado Streamdeck HELL & Segundo Ecrã'), trailing: Text(widget.isSecondScreenPaired ? 'Sincronizado' : 'Configurar na aba Streamdeck')),
          ListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Servidor Local de Overlays'), trailing: Text('Porta ${LocalObsServer.port}')),
        ],
      ),
    );

    final allPanels = <String, Widget>{
      'live': livePanel,
      'chat': chatPanel,
      'obs': obsPanel,
      'stats': statsPanel,
    };

    if (_expandedPanelId != null && allPanels.containsKey(_expandedPanelId)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vista Expandida do Painel', style: TextStyle(color: Colors.white70, fontSize: 12)),
              TextButton.icon(
                onPressed: () => setState(() => _expandedPanelId = null),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('Minimizar para Vista Completa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          allPanels[_expandedPanelId]!,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;
        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: livePanel), const SizedBox(width: 14), Expanded(child: obsPanel)]),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: chatPanel), const SizedBox(width: 14), Expanded(child: statsPanel)]),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            livePanel,
            const SizedBox(height: 12),
            obsPanel,
            const SizedBox(height: 12),
            chatPanel,
            const SizedBox(height: 12),
            statsPanel,
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
