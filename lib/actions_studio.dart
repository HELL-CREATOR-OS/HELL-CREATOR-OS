import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'app_data.dart';
import 'live_connectors.dart';

class ActionsStudioTab extends StatefulWidget {
  final List<Map<String, dynamic>> alertsList;
  final List<Map<String, dynamic>> goalsList;
  final List<Map<String, String>> sounds;
  final AudioPlayer sfxPlayer;
  final AudioRecorder voiceRecorder;
  final bool allGiftsEnabled;
  final Function(bool) onToggleAllGifts;
  final Function(String) onSpeakVoice;
  final VoidCallback onStateChanged;

  const ActionsStudioTab({
    super.key,
    required this.alertsList,
    required this.goalsList,
    required this.sounds,
    required this.sfxPlayer,
    required this.voiceRecorder,
    required this.allGiftsEnabled,
    required this.onToggleAllGifts,
    required this.onSpeakVoice,
    required this.onStateChanged,
  });

  @override
  State<ActionsStudioTab> createState() => _ActionsStudioTabState();
}

class _ActionsStudioTabState extends State<ActionsStudioTab> with SingleTickerProviderStateMixin {
  int _activeSection = 0; // 0: Tudo (Cockpit), 1: Presentes, 2: Alertas, 3: Doações, 4: Metas, 5: Regras

  // Presentes Padrão & Individuais
  bool _defaultGiftsVoice = true;
  String _defaultGiftSound = 'sounds/tap_pulse.wav';
  final TextEditingController _defaultGiftMsgCtrl = TextEditingController(text: 'Muito obrigado {user} pelo presente {presente}!');
  final List<Map<String, dynamic>> _individualGifts = [
    {'id': 'g1', 'name': 'Rosa', 'coins': 1, 'custom': false, 'sound': 'sounds/tap_glass.wav', 'msg': 'Obrigado {user} pela Rosa!', 'color': const Color(0xFFF43F5E)},
    {'id': 'g2', 'name': 'Coração Neon', 'coins': 10, 'custom': false, 'sound': 'sounds/tap_cyber.wav', 'msg': 'Valeu {user} pelo Coração!', 'color': const Color(0xFFEC4899)},
    {'id': 'g3', 'name': 'Galáxia', 'coins': 1000, 'custom': true, 'sound': 'sounds/hell_startup.wav', 'msg': 'Incrível {user}! Enviou uma Galáxia!', 'color': const Color(0xFFA855F7)},
    {'id': 'g4', 'name': 'Leão Rei VIP', 'coins': 29999, 'custom': true, 'sound': 'sounds/hell_startup.wav', 'msg': 'LENDÁRIO {user}! Leão Rei na arena!', 'color': const Color(0xFFF59E0B)},
  ];

  // Alertas Padrão
  bool _defaultAlertsEnabled = true;
  bool _defaultAlertsVoice = true;
    String _defaultAlertSound = 'sounds/tap_glass.wav';

  final TextEditingController _defaultAlertMsgCtrl = TextEditingController(text: 'Bem-vindo à família {user}! Obrigado pelo apoio!');

  // Doações 4K HDR
  final TextEditingController _mbwayCtrl = TextEditingController(text: '+351 910 000 000');
  final TextEditingController _paypalCtrl = TextEditingController(text: 'paypal.me/hellcreator');
  final TextEditingController _revolutCtrl = TextEditingController(text: 'revolut.me/hellcreator');
  final TextEditingController _pixCtrl = TextEditingController(text: 'hellcreator@pix.pt');
  final TextEditingController _minAmountCtrl = TextEditingController(text: '1.00');
  bool _readDonationTts = true;

  // Metas & Roleta
  late AnimationController _wheelCtrl;
  double _currentAngle = 0;
  String _lastWinner = 'Toca em Girar!';
  final List<String> _wheelOptions = ['10 Flexões', 'Escolher Música', 'Sem Mira 1 Ronda', 'Salve Especial', 'Desafio do Chat', 'Sorte Grande!'];

  // Regras & Histórico
  final List<Map<String, dynamic>> _automationRules = [
    {'when': 'Novo Seguidor', 'then': 'Anunciar nome por voz + Som Cristalino', 'priority': 'Alta', 'active': true},
    {'when': '10 Rosas Seguidas', 'then': 'Agrupar anúncio na Voice Queue', 'priority': 'Média', 'active': true},
    {'when': 'Presente Especial (>= 500)', 'then': 'Alerta Prioritário + Voz VIP', 'priority': 'Crítica', 'active': true},
    {'when': 'Doação >= €10', 'then': 'Efeito Dourado + Agradecimento Completo', 'priority': 'Crítica', 'active': true},
  ];
  final List<String> _executionHistory = [
    '15:20 · Presente Galáxia (@joao_gamer) executado com voz.',
    '15:14 · Regra "Novo Seguidor" executada nos auscultadores.',
  ];

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _defaultGiftMsgCtrl.dispose();
    _defaultAlertMsgCtrl.dispose();
    _mbwayCtrl.dispose();
    _paypalCtrl.dispose();
    _revolutCtrl.dispose();
    _pixCtrl.dispose();
    _minAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _testAutomation({required String title, required String soundAsset, required String spokenText}) async {
    try {
      await widget.sfxPlayer.stop();
      await widget.sfxPlayer.play(AssetSource(soundAsset));
    } catch (_) {}
    widget.onSpeakVoice(spokenText);
    setState(() {
      _executionHistory.insert(0, '${TimeOfDay.now().format(context)} · Teste "$title" executado.');
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('▶ Testado: $title · "$spokenText"'),
        backgroundColor: const Color(0xFF1E78FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF08122E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E78FF), Color(0xFF38BDF8)]),
                borderRadius: BorderRadius.circular(11),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
              tabs: const [
                Tab(text: '🎁 Presentes'),
                Tab(text: '🔔 Alertas Padrão'),
                Tab(text: '💶 Doações'),
                Tab(text: '🎯 Metas & Desafios'),
                Tab(text: '⚡ Regras & Histórico'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGiftsTab(),
                _buildAlertsTab(),
                _buildDonationsTab(),
                _buildGoalsTab(),
                _buildRulesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'ATIVAR PRESENTES PADRÃO · REGRA GLOBAL',
          icon: Icons.card_giftcard_rounded,
          accent: const Color(0xFFF43F5E),
          badge: widget.allGiftsEnabled ? 'ATIVO' : 'DESLIGADO',
          onTestPressed: () => _testAutomation(
            title: 'Presente Padrão (Rosa)',
            soundAsset: _defaultGiftSound,
            spokenText: _defaultGiftMsgCtrl.text.replaceAll('{user}', 'AlexPro_PT').replaceAll('{presente}', 'Rosa'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFFF43F5E),
                title: const Text('Ativar Presentes Padrão', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                subtitle: const Text('Aplica som e agradecimento vocal automático a todos os presentes sem regra individual.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                value: widget.allGiftsEnabled,
                onChanged: widget.onToggleAllGifts,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _defaultGiftSound,
                decoration: const InputDecoration(labelText: 'Som de Alerta Padrão', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'sounds/tap_pulse.wav', child: Text('Pulso Néon (Estéreo)')),
                  DropdownMenuItem(value: 'sounds/tap_glass.wav', child: Text('Cristal HD (Estéreo)')),
                  DropdownMenuItem(value: 'sounds/tap_cyber.wav', child: Text('Cyber Mech (Estéreo)')),
                  DropdownMenuItem(value: 'sounds/hell_startup.wav', child: Text('Fanfarra HELL 4K')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _defaultGiftSound = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _defaultGiftMsgCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Mensagem de Voz ({user} e {presente})',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._individualGifts.map((g) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HellCockpitWindow(
              title: '${g['icon']} ${g['name'].toString().toUpperCase()} · ${g['coins']} MOEDAS',
              icon: Icons.auto_awesome_rounded,
              accent: const Color(0xFFA855F7),
              badge: g['custom'] == true ? 'PERSONALIZADO' : 'USA PADRÃO',
              onTestPressed: () => _testAutomation(
                title: g['name'],
                soundAsset: g['sound'],
                spokenText: g['msg'].toString().replaceAll('{user}', 'SofiaLive').replaceAll('{presente}', g['name']),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFFA855F7),
                    title: const Text('Personalizar este presente individualmente', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    value: g['custom'] == true,
                    onChanged: (v) => setState(() => g['custom'] = v),
                  ),
                                       TextFormField(
                        initialValue: g['msg'],
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(labelText: 'Agradecimento Vocal Individual', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => g['msg'] = v,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF38BDF8),
                                side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.6)),
                              ),
                              onPressed: () {
                                final hdLibrary = [
                                  {'name': '🔔 Sino Cristalino HD', 'url': 'https://google.com', 'badge': '💎 Diamante HDR'},
                                  {'name': '🪙 Caixa Registadora / Moeda HD', 'url': 'https://google.com', 'badge': '👑 Coroa Ouro HDR'},
                                  {'name': '🚀 Impacto Sci-Fi & Laser HD', 'url': 'https://google.com', 'badge': '🚀 Foguete Turbo HDR'},
                                  {'name': '🎉 Fanfarra Vitória / Sub HD', 'url': 'https://google.com', 'badge': '🌌 Galáxia 4K HDR'},
                                  {'name': '⚡ Alarme Raid Épico HD', 'url': 'https://google.com', 'badge': '🔥 Troféu Lendário HDR'},
                                ];
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF0A1433),
                                    title: Text('Biblioteca Real HD · ${g['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                    content: SizedBox(
                                      width: 360,
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: hdLibrary.length,
                                        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                                        itemBuilder: (_, i) {
                                          final item = hdLibrary[i];
                                          return ListTile(
                                            dense: true,
                                            title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                            subtitle: Text('Visual: ${item['badge']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8))),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Ouvir em Tempo Real',
                                                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.greenAccent),
                                                  onPressed: () async {
                                                    try {
                                                      await widget.sfxPlayer.stop();
                                                      await widget.sfxPlayer.play(UrlSource(item['url']!));
                                                    } catch (_) {}
                                                  },
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(horizontal: 10)),
                                                  onPressed: () {
                                                    setState(() {
                                                      g['sound'] = item['url']!;
                                                      g['custom'] = true;
                                                    });
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('✅ "${item['name']}" guardado offline e aplicado a ${g['name']}!')),
                                                    );
                                                  },
                                                  child: const Text('Baixar & Aplicar', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.library_music_rounded, size: 16),
                              label: const Text('Biblioteca Real HD (Ouvir, Baixar & Aplicar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }


  Widget _buildAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'ALERTAS PADRÃO · PERSONALIZAÇÃO GLOBAL',
          icon: Icons.notifications_active_rounded,
          accent: const Color(0xFF38BDF8),
          badge: _defaultAlertsEnabled ? 'ATIVO' : 'PAUSADO',
          onTestPressed: () => _testAutomation(
            title: 'Alerta Padrão',
            soundAsset: _defaultAlertSound,
            spokenText: _defaultAlertMsgCtrl.text.replaceAll('{user}', 'CarlosPT'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF38BDF8),
                title: const Text('Ativar Alertas Padrão', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                subtitle: const Text('Configuração mestre para seguidores, subscritores e partilhas.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                value: _defaultAlertsEnabled,
                onChanged: (v) => setState(() => _defaultAlertsEnabled = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _defaultAlertSound,
                decoration: const InputDecoration(labelText: 'Som de Alerta Padrão', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'sounds/tap_glass.wav', child: Text('Cristal HD (Estéreo)')),
                  DropdownMenuItem(value: 'sounds/tap_pulse.wav', child: Text('Pulso Néon (Estéreo)')),
                  DropdownMenuItem(value: 'sounds/tap_zerog.wav', child: Text('Zero-G Synth (Estéreo)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _defaultAlertSound = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _defaultAlertMsgCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(labelText: 'Mensagem de Voz Padrão ({user})', border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...widget.alertsList.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HellCockpitWindow(
              title: a['name'].toString().toUpperCase(),
              icon: Icons.bolt_rounded,
              accent: const Color(0xFF1E78FF),
              badge: a['enabled'] == true ? 'ATIVO' : 'OFF',
              onTestPressed: () => _testAutomation(
                title: a['name'],
                soundAsset: _defaultAlertSound,
                spokenText: 'Obrigado ${a['name']} de Nitro_99!',
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF38BDF8),
                title: Text('Ativar ${a['name']} + Voz TTS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                value: a['enabled'] == true,
                onChanged: (v) {
                  setState(() => a['enabled'] = v);
                  widget.onStateChanged();
                },
              ),
            ),
          );
        }),
      ],
    );
  }
  Widget _buildDonationsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'DASHBOARD DE DOAÇÕES · 4K HDR',
          icon: Icons.euro_rounded,
          accent: const Color(0xFF10B981),
          badge: 'RECEITA AO VIVO',
          onTestPressed: () => _testAutomation(
            title: 'Doação €15.00 (MB WAY)',
            soundAsset: 'sounds/hell_startup.wav',
            spokenText: 'Muito obrigado CarlosPT pela doação de 15 euros!',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HOJE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white60)),
                          Text('€45.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ESTE MÊS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white60)),
                          Text('€680.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _mbwayCtrl, decoration: const InputDecoration(labelText: 'Telemóvel MB WAY (Portugal)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _paypalCtrl, decoration: const InputDecoration(labelText: 'Email / Link PayPal.me', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _revolutCtrl, decoration: const InputDecoration(labelText: 'Tag Revolut (@utilizador)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _pixCtrl, decoration: const InputDecoration(labelText: 'Chave PIX (Brasil)', border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: widget.goalsList.map((m) {
        final target = (m['target'] as num).toDouble();
        final current = (m['current'] as num).toDouble();
        final pct = (current / (target <= 0 ? 1 : target)).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HellCockpitWindow(
            title: m['title'].toString().toUpperCase(),
            icon: Icons.track_changes_rounded,
            accent: const Color(0xFFF59E0B),
            badge: '${(pct * 100).round()}%',
            onTestPressed: () => _testAutomation(
              title: m['title'],
              soundAsset: 'sounds/tap_pulse.wav',
              spokenText: 'Meta ${m['title']} atualizada no ecrã!',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${current.round()} / ${target.round()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 12,
                    backgroundColor: const Color(0xFF04091A),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => m['current'] = (m['current'] as num) + 50);
                        widget.onStateChanged();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+50 Progresso'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => m['current'] = 0);
                        widget.onStateChanged();
                      },
                      child: const Text('Reiniciar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        HellCockpitWindow(
          title: 'REGRAS AUTOMÁTICAS · QUANDO X -> FAZ Y',
          icon: Icons.account_tree_rounded,
          accent: const Color(0xFFA855F7),
          badge: '${_automationRules.length} REGRAS',
          onTestPressed: () => _testAutomation(
            title: 'Motor de Regras IA',
            soundAsset: 'sounds/tap_cyber.wav',
            spokenText: 'Todas as regras automáticas verificadas e operacionais!',
          ),
          child: Column(
            children: _automationRules.map((r) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF04091A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.45)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('QUANDO: ${r['when']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: Color(0xFF38BDF8))),
                          Text('FAZ: ${r['then']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Switch(
                      activeColor: const Color(0xFFA855F7),
                      value: r['active'] == true,
                      onChanged: (v) => setState(() => r['active'] = v),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        HellCockpitWindow(
          title: 'HISTÓRICO DE EXECUÇÕES',
          icon: Icons.history_rounded,
          accent: const Color(0xFF38BDF8),
          badge: 'TEMPO REAL',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _executionHistory.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $h', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
