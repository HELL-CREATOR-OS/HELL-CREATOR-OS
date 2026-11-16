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

// ABA 2: CENTRO DE CONTROLO + PERFIS & EMPARELHAMENTO QR
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
  final _chatFilterCtrl = TextEditingController();
  final _syncInputCtrl = TextEditingController();
  final _bannedWordCtrl = TextEditingController();
  final List<String> _bannedWords = ['spam', 'scam', 'link falso'];
  final List<String> _moderators = ['@Mod_Joao', '@Mod_Sofia'];
  String _activeObsScene = 'Cena Principal (Jogo)';

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.activePlatforms.values.where((v) => v).length;
    final obsUrl = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay';
    final isOwner = UserAccountManager.isOwnerEmail(widget.user['email']);

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '📡 Live Monitor'),
              Tab(text: '💬 Unified Chat & Mod'),
              Tab(text: '🎬 OBS Control'),
              Tab(text: '📊 Stats & Diagnóstico'),
              Tab(text: '👤 Perfil & Sync QR'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 2.1 LIVE MONITOR & 2.8 MULTI-PLATFORM CONTROL
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('📡 Estado das Transmissões', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                              Text(activeCount > 0 ? '● EM DIRETO ($activeCount)' : '○ EM ESPERA', style: TextStyle(fontWeight: FontWeight.bold, color: activeCount > 0 ? Colors.greenAccent : Colors.orangeAccent)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...['tiktok', 'twitch', 'youtube', 'kick'].map((p) {
                            final on = widget.activePlatforms[p] == true;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.circle, size: 11, color: on ? Colors.greenAccent : Colors.white24),
                              title: Text(p.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(on ? 'Ligação estável · Bitrate 6000 kbps' : 'Desligado', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                              trailing: Text(on ? 'ATIVA' : 'OFF', style: TextStyle(fontWeight: FontWeight.bold, color: on ? Colors.greenAccent : Colors.white38)),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                // 2.2 UNIFIED CHAT, 2.3 EVENT MONITOR & 2.4 MODERAÇÃO
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _chatFilterCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Pesquisar mensagens ou utilizador...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🛡️ Moderação & Moderadores', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: _moderators.map((m) => Chip(label: Text(m, style: const TextStyle(fontSize: 11)))).toList(),
                          ),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _bannedWordCtrl, decoration: const InputDecoration(hintText: 'Adicionar palavra bloqueada...', isDense: true))),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8)),
                                onPressed: () {
                                  if (_bannedWordCtrl.text.trim().isNotEmpty) {
                                    setState(() {
                                      _bannedWords.add(_bannedWordCtrl.text.trim().toLowerCase());
                                      _bannedWordCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.chatFeed.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('Aguardando mensagens do TikTok, Twitch, YouTube ou Kick...', style: TextStyle(color: Colors.white54))),
                      )
                    else
                      ...widget.chatFeed
                          .where((m) => _chatFilterCtrl.text.isEmpty || (m['msg'] ?? '').toLowerCase().contains(_chatFilterCtrl.text.toLowerCase()))
                          .map((m) => Card(
                                color: const Color(0xFF0B1636),
                                child: ListTile(
                                  dense: true,
                                  title: Text('${m['user']} [${(m['type'] ?? 'chat').toUpperCase()}]', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                                  subtitle: Text(m['msg'] ?? ''),
                                ),
                              )),
                  ],
                ),

                // 2.5 OBS CONTROL
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎬 Controlo OBS Studio / Live Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 8),
                          SelectableText(obsUrl, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: obsUrl));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL Browser Source copiado!')));
                            },
                            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                            label: const Text('Copiar Browser Source OBS', style: TextStyle(color: Colors.white)),
                          ),
                          const Divider(color: Colors.white12, height: 22),
                          const Text('Mudar Cena Ativa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Cena Principal (Jogo)', 'Just Chatting / Câmara', 'Pausa / Volto Já', 'Encerramento'].map((sc) => ChoiceChip(
                              label: Text(sc),
                              selected: _activeObsScene == sc,
                              selectedColor: const Color(0xFF1E78FF),
                              onSelected: (_) => setState(() => _activeObsScene = sc),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2.6 DIAGNÓSTICO & 2.7 LIVE STATISTICS
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🩺 Diagnóstico de Rede & Incidentes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text('• Servidor Local OBS: Online (8765)\n• Motor de Voz PT-PT: Operacional\n• Incidentes registados na sessão: 0', style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),

                // PERFIL, EMPARELHAMENTO QR / CÓDIGO & GESTÃO DONO
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        children: [
                          UserAccountManager.buildUserAvatar(widget.user, radius: 36),
                          const SizedBox(height: 8),
                          Text(widget.user['nickname'] ?? 'Criador', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(widget.user['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF122B6B)),
                            onPressed: () async {
                              final res = await FilePicker.platform.pickFiles(type: FileType.image);
                              if (res != null && res.files.single.path != null) {
                                final updated = Map<String, dynamic>.from(widget.user);
                                updated['avatarPath'] = res.files.single.path!;
                                await UserAccountManager.saveUser(updated);
                                widget.onUserUpdated(updated);
                              }
                            },
                            icon: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
                            label: const Text('Alterar Foto de Perfil', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        children: [
                          const Text('📱 Sincronizar 2.º Aparelho (Telemóvel Velho)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: QrImageView(data: 'hellcreatoros://sync/${widget.syncCode}', version: QrVersions.auto, size: 130),
                          ),
                          const SizedBox(height: 8),
                          SelectableText('Código: ${widget.syncCode}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.greenAccent, fontSize: 15)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
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
