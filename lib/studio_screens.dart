import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_data.dart';

BoxDecoration _neonBox({Color border = const Color(0xFF38BDF8)}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A1638), Color(0xFF050B1E)],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: border.withOpacity(0.45), width: 1.3),
    boxShadow: [
      BoxShadow(color: border.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );
}

// ============================================================================
// 4. CHAT E VOZ TTS (REPOSITÓRIO REAL DE VOZES NEURAIS & FILTROS)
// ============================================================================
class ChatTtsRepositoryScreen extends StatefulWidget {
  final FlutterTts? tts;
  final AudioPlayer? sfxPlayer;
  final void Function(String)? onSpeak;
  final void Function(String)? onSpeakVoice;

  const ChatTtsRepositoryScreen({
    super.key,
    this.tts,
    this.sfxPlayer,
    this.onSpeak,
    this.onSpeakVoice,
  });

  @override
  State<ChatTtsRepositoryScreen> createState() => _ChatTtsRepositoryScreenState();
}

class _ChatTtsRepositoryScreenState extends State<ChatTtsRepositoryScreen> {
  final FlutterTts _localTts = FlutterTts();
  final TextEditingController _testTextCtrl = TextEditingController(
    text: 'Olá pessoal! Bem-vindos à transmissão em direto no HELL CREATOR!',
  );

  String _selectedLang = 'pt-PT';
  String _selectedVoiceName = 'Portugal · Madalena (Neural HD)';
  double _rate = 0.50;
  double _pitch = 1.0;
  bool _readAllChat = true;
  bool _readGiftsAndDonations = true;
  bool _antiSpamFilter = true;

  final List<Map<String, String>> _voiceCatalog = [
    {'name': 'Portugal · Madalena (Neural HD)', 'lang': 'pt-PT', 'tag': 'Feminina · Natural'},
    {'name': 'Portugal · Duarte (Estúdio Pro)', 'lang': 'pt-PT', 'tag': 'Masculina · Grave'},
    {'name': 'Brasil · Francisca (Cristal)', 'lang': 'pt-BR', 'tag': 'Feminina · Dinâmica'},
    {'name': 'Brasil · António (Locutor)', 'lang': 'pt-BR', 'tag': 'Masculina · Épica'},
    {'name': 'English · Aria (Global)', 'lang': 'en-US', 'tag': 'Feminina · Internacional'},
    {'name': 'Español · Elvira (Latam/ES)', 'lang': 'es-ES', 'tag': 'Feminina · Clara'},
  ];

  Future<void> _speakPreview([String? customText]) async {
    final engine = widget.tts ?? _localTts;
    final text = (customText ?? _testTextCtrl.text).trim();
    if (text.isEmpty) return;
    try {
      await engine.stop();
      await engine.setLanguage(_selectedLang);
      await engine.setSpeechRate(_rate);
      await engine.setPitch(_pitch);
      await engine.speak(text);
    } catch (_) {}
  }

  @override
  void dispose() {
    _testTextCtrl.dispose();
    super.dispose();
  }

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
              const Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estúdio de Voz Neural & Leitura do Chat',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Voz Ativa: $_selectedVoiceName ($_selectedLang)',
                style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testTextCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Texto de pré-audição ao vivo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Velocidade: ${(_rate * 2).toStringAsFixed(1)}x', style: const TextStyle(fontSize: 11)),
                        Slider(
                          value: _rate,
                          min: 0.25,
                          max: 0.85,
                          onChanged: (v) => setState(() => _rate = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tom de Voz: ${_pitch.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11)),
                        Slider(
                          value: _pitch,
                          min: 0.6,
                          max: 1.5,
                          onChanged: (v) => setState(() => _pitch = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                  onPressed: () => _speakPreview(),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Ouvir Pré-Audição da Voz Agora', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _neonBox(border: Colors.amberAccent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎙️ Catálogo de Vozes Disponíveis',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amberAccent),
              ),
              const SizedBox(height: 8),
              ..._voiceCatalog.map((v) {
                final selected = _selectedVoiceName == v['name'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? const Color(0xFF38BDF8) : Colors.white54,
                  ),
                  title: Text(v['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${v['lang']} · ${v['tag']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      setState(() {
                        _selectedVoiceName = v['name']!;
                        _selectedLang = v['lang']!;
                      });
                      _speakPreview();
                    },
                  ),
                  onTap: () {
                    setState(() {
                      _selectedVoiceName = v['name']!;
                      _selectedLang = v['lang']!;
                    });
                  },
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _neonBox(),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Ler mensagens do chat em direto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _readAllChat,
                onChanged: (v) => setState(() => _readAllChat = v),
              ),
              SwitchListTile(
                title: const Text('Anunciar presentes, seguidores e doações', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _readGiftsAndDonations,
                onChanged: (v) => setState(() => _readGiftsAndDonations = v),
              ),
              SwitchListTile(
                title: const Text('Filtro inteligente anti-spam e links', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _antiSpamFilter,
                onChanged: (v) => setState(() => _antiSpamFilter = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 6. FÁBRICA DE CONTEÚDOS (CLIPES, TÍTULOS VIRAIS & CAPAS HDR)
// ============================================================================
class ContentFactoryScreen extends StatefulWidget {
  const ContentFactoryScreen({super.key});

  @override
  State<ContentFactoryScreen> createState() => _ContentFactoryScreenState();
}

class _ContentFactoryScreenState extends State<ContentFactoryScreen> {
  final TextEditingController _topicCtrl = TextEditingController(text: 'Melhores momentos da live de hoje');
  String _generatedHook = '🔥 NÃO VAIS ACREDITAR NO QUE ACONTECEU NESTA LIVE! #HELLCREATOR #LIVE';

  void _generateCopy() {
    final topic = _topicCtrl.text.trim().isEmpty ? 'Transmissão Épica' : _topicCtrl.text.trim();
    setState(() {
      _generatedHook = '⚡ $topic — O momento mais épico da semana! Vê até ao fim e deixa o teu comentário 👇 #HELLCREATOR #Direto';
    });
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

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
              const Text('🎬 Fábrica de Conteúdos & Clipes Rápidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              const Text('Cria títulos virais, descrições otimizadas e prepara os cortes gravados pelo botão Clipe do Stream Deck.', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 12),
              TextField(
                controller: _topicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tema do clipe ou vídeo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: _generateCopy,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Gerar Título & Hashtags Virais'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF04091A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_generatedHook, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedHook));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Texto copiado para a área de transferência!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar Texto'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. MARKETPLACE & GESTÃO DE PUBLICIDADES E PARCERIAS
// ============================================================================
class CreatorBusinessScreen extends StatefulWidget {
  final bool isOwner;
  const CreatorBusinessScreen({super.key, this.isOwner = true});

  @override
  State<CreatorBusinessScreen> createState() => _CreatorBusinessScreenState();
}

class _CreatorBusinessScreenState extends State<CreatorBusinessScreen> {
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _valCtrl = TextEditingController();
  final TextEditingController _sponsorTitleCtrl = TextEditingController();
  final TextEditingController _sponsorUrlCtrl = TextEditingController();
  String _txType = 'Receita';

  final List<Map<String, dynamic>> _transactions = [
    {'desc': 'Presentes & Subscrições Live', 'amount': 145.50, 'type': 'Receita'},
    {'desc': 'Campanha Patrocinador Gaming', 'amount': 250.00, 'type': 'Receita'},
    {'desc': 'Equipamento Áudio / Microfone', 'amount': 65.00, 'type': 'Despesa'},
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _valCtrl.dispose();
    _sponsorTitleCtrl.dispose();
    _sponsorUrlCtrl.dispose();
    super.dispose();
  }

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
            tabs: [
              Tab(text: '💰 Finanças'),
              Tab(text: '📢 Parcerias & Ads'),
              Tab(text: '🏢 Agência & Equipa'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo Líquido: € ${(income - expense).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.greenAccent),
                          ),
                          const SizedBox(height: 6),
                          Text('Receitas: € ${income.toStringAsFixed(2)}  ·  Despesas: € ${expense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          const Divider(color: Colors.white12, height: 22),
                          ..._transactions.map((t) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  t['type'] == 'Receita' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: t['type'] == 'Receita' ? Colors.greenAccent : Colors.redAccent,
                                ),
                                title: Text(t['desc'].toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                trailing: Text('€ ${(t['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📢 Gestão de Publicidades & Parcerias (Live + Perfil + Stream Deck)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 6),
                          const Text('Gere aqui os teus patrocinadores e códigos. Sincroniza automaticamente com o teu Perfil, com o Overlay da Live e com o Botão de Ciclo do Stream Deck.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 10),
                          ...SponsorBannerManager.activeSponsors.asMap().entries.map((e) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.campaign_rounded, color: Colors.amberAccent, size: 20),
                                title: Text(e.value['title'] ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                subtitle: Text(e.value['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Abrir Ligação',
                                      icon: const Icon(Icons.open_in_new, size: 17, color: Color(0xFF38BDF8)),
                                      onPressed: () {
                                        final uri = Uri.tryParse(e.value['url'] ?? '');
                                        if (uri != null) {
                                          launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Remover Parceria',
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      onPressed: () => setState(() => SponsorBannerManager.activeSponsors.removeAt(e.key)),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(color: Colors.white12),
                          const Text('➕ Adicionar Nova Publicidade ou Parceria', style: TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(controller: _sponsorTitleCtrl, decoration: const InputDecoration(hintText: 'Texto / Código (ex: Usa código HELL15 · 15% OFF)', isDense: true)),
                          const SizedBox(height: 6),
                          TextField(controller: _sponsorUrlCtrl, decoration: const InputDecoration(hintText: 'Ligação do patrocinador ou perfil (https://...)', isDense: true)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                                  onPressed: () {
                                    if (_sponsorTitleCtrl.text.trim().isNotEmpty) {
                                      setState(() {
                                        SponsorBannerManager.activeSponsors.insert(0, {
                                          'title': _sponsorTitleCtrl.text.trim(),
                                          'url': _sponsorUrlCtrl.text.trim().isEmpty ? 'https://hellcreator.app' : _sponsorUrlCtrl.text.trim(),
                                        });
                                        _sponsorTitleCtrl.clear();
                                        _sponsorUrlCtrl.clear();
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.add_circle_outline, size: 16),
                                  label: const Text('Adicionar Parceria', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF38BDF8)),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: 'http://127.0.0'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Ligação OBS de Publicidades & Parcerias copiada!')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 15),
                                label: const Text('Link OBS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonBox(),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏢 Painel de Agência & Equipa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text(
                            'Gestão de vários criadores, permissões de moderadores e relatórios globais.\n• Setores recomendados: Periféricos Gaming, Energia, Áudio e Software.\n• Contacto comercial integrado no teu perfil público.',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
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

// ============================================================================
// 9. GESTÃO IA (COPILOTO INTELIGENTE DE TRANSMISSÃO)
// ============================================================================
class SmartBrainScreen extends StatefulWidget {
  const SmartBrainScreen({super.key});

  @override
  State<SmartBrainScreen> createState() => _SmartBrainScreenState();
}

class _SmartBrainScreenState extends State<SmartBrainScreen> {
  bool _autoReplyChat = true;
  bool _autoHighlightClips = true;
  bool _smartVolumeDucking = true;

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
              const Text('🧠 Gestão IA · Copiloto HELL CREATOR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              const SizedBox(height: 8),
              const Text('Automatiza respostas inteligentes no chat, ajusta o volume da música quando falas e marca momentos épicos.', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Respostas automáticas IA a perguntas frequentes (!loja, !discord, !setup)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _autoReplyChat,
                onChanged: (v) => setState(() => _autoReplyChat = v),
              ),
              SwitchListTile(
                title: const Text('Deteção automática de picos de emoção para Clipes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _autoHighlightClips,
                onChanged: (v) => setState(() => _autoHighlightClips = v),
              ),
              SwitchListTile(
                title: const Text('Baixar música automaticamente quando a voz TTS fala', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _smartVolumeDucking,
                onChanged: (v) => setState(() => _smartVolumeDucking = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 10. INFORMAÇÕES & LIGAÇÃO OBS / TIKTOK LIVE STUDIO
// ============================================================================
class InfoSupportScreen extends StatelessWidget {
  const InfoSupportScreen({super.key});

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
              const Text('ℹ️ HELL CREATOR · Guia Oficial de Estúdio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              const SizedBox(height: 10),
              const Text(
                '• Servidor Local de Overlays Ativo em: http://127.0.0.1:8080\n'
                '• No OBS Studio ou TikTok Live Studio, adiciona uma fonte "Navegador" (Browser Source) com largura 1920x1080 e cola o link copiado na Biblioteca de Overlays HDR.\n'
                '• Usa o Stream Deck HELL no telemóvel ou tablet para controlar cenas, sons, clipes, música em segundo plano e publicidades ao vivo.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'http://127.0.0.1:8080'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Endereço base http://127.0.0.1:8080 copiado!')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar Endereço do Servidor Local OBS'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 11. CONFIGURAÇÕES & SEGURANÇA
// ============================================================================
class SettingsSecurityScreen extends StatefulWidget {
  const SettingsSecurityScreen({super.key});

  @override
  State<SettingsSecurityScreen> createState() => _SettingsSecurityScreenState();
}

class _SettingsSecurityScreenState extends State<SettingsSecurityScreen> {
  bool _pinLock = false;
  bool _keepScreenAwake = true;
  bool _hardwareAccel = true;

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
              const Text('⚙️ Configurações & Segurança HELL CREATOR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Manter ecrã sempre ligado durante a transmissão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _keepScreenAwake,
                onChanged: (v) => setState(() => _keepScreenAwake = v),
              ),
              SwitchListTile(
                title: const Text('Aceleração gráfica HDR 60 FPS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _hardwareAccel,
                onChanged: (v) => setState(() => _hardwareAccel = v),
              ),
              SwitchListTile(
                title: const Text('Bloqueio PIN ao abrir o Estúdio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _pinLock,
                onChanged: (v) => setState(() => _pinLock = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
