import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
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

// CENTRO DE CONTROLO BROADCAST 4K (SEM COCKPIT INÚTIL + CHAT BOT ALGORITMO + TODAS AS AUTOMAÇÕES + VOZES HÉLDER/ENZO/FLÁVIO/LÚCIA/NOA/SANDRA)
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

class _ControlCenterScreenState extends State<ControlCenterScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _studioPlayer = AudioPlayer();
  final FlutterTts _neuralTts = FlutterTts();
  final TextEditingController _quickReplyCtrl = TextEditingController();
  final TextEditingController _botMsgCtrl = TextEditingController(text: 'Bem-vindos à live! Deixem o gosto e sigam nas redes para não perderem os desafios!');
  final TextEditingController _libSearchCtrl = TextEditingController();

  // Chat Unificado & Bot Algoritmo (Ponto 4.1)
  Color _chatAccentColor = const Color(0xFF38BDF8);
  double _chatFontSize = 12.5;
  bool _algoBotEnabled = true;
  int _algoIntervalSec = 180;
  final List<String> _algoAutoMessages = [
    '👋 Bem-vindos a todos os que acabaram de entrar! Deixem o gosto para ajudar o algoritmo!',
    '🔥 Rumo à próxima meta! Comentem no chat para participar no próximo desafio!',
    '📲 Sigam-nos nas redes sociais e ativem as notificações para receberem avisos de live!',
  ];
  final List<Map<String, String>> _liveChatBuffer = [
    {'platform': 'tiktok', 'user': '@joao_gamer', 'text': 'Que jogada absurda mano!!'},
    {'platform': 'twitch', 'user': 'SofiaLive', 'text': 'Som e imagem cristalinos!'},
    {'platform': 'youtube', 'user': 'CarlosPT', 'text': 'Salve para Portugal!'},
  ];

  // Automações Integradas no Centro de Controlo (Ponto 4.2 + Bibliotecas Reais CC0)
  bool _defaultGiftsEnabled = true;
  String _defaultGiftSound = 'sounds/tap_pulse.wav';
  String _defaultGiftVoiceTpl = 'Muito obrigado {user} pelo presente {presente}!';
  bool _defaultAlertsEnabled = true;
  String _defaultAlertSound = 'sounds/tap_glass.wav';
  String _selectedLibraryCategory = 'Sons CC0';

  final List<Map<String, dynamic>> _studioGiftsCatalog = [
    {'name': 'Rosa Néon', 'coins': 1, 'sound': 'sounds/tap_pulse.wav', 'visual': '🌹 Aura Néon 4K', 'custom': false},
    {'name': 'Coração Cristal', 'coins': 10, 'sound': 'sounds/tap_glass.wav', 'visual': '💎 Pulso Diamante', 'custom': false},
    {'name': 'Óculos Cyber', 'coins': 99, 'sound': 'sounds/tap_cyber.wav', 'visual': '🕶️ Visor Holográfico', 'custom': true},
    {'name': 'Corgi Turbo', 'coins': 299, 'sound': 'sounds/tap_zerog.wav', 'visual': '🐕 Rasto Elétrico', 'custom': true},
    {'name': 'Galáxia Cósmica', 'coins': 1000, 'sound': 'sounds/hell_startup.wav', 'visual': '🌌 Nebulosa 360°', 'custom': true},
    {'name': 'Leão Imperial', 'coins': 29999, 'sound': 'sounds/hell_startup.wav', 'visual': '🦁 Rugido Arena HDR', 'custom': true},
  ];

  final List<Map<String, String>> _onlineFreeLibrary = [
    {'type': 'Som CC0', 'name': 'Fanfarra Vitória Arena', 'source': 'Freesound CC0', 'asset': 'sounds/hell_startup.wav'},
    {'type': 'Som CC0', 'name': 'Pulso Cristal HD', 'source': 'HELL Studio Pack', 'asset': 'sounds/tap_glass.wav'},
    {'type': 'Som CC0', 'name': 'Laser Cyber Estéreo', 'source': 'OpenGameArt CC0', 'asset': 'sounds/tap_cyber.wav'},
    {'type': 'Som CC0', 'name': 'Sintetizador Zero-G', 'source': 'HELL Studio Pack', 'asset': 'sounds/tap_zerog.wav'},
    {'type': 'Imagem HD', 'name': 'Terra à Noite (NASA)', 'source': 'NASA Open Media', 'url': 'https://wikimedia.org'},
    {'type': 'Imagem HD', 'name': 'Nebulosa Orion 4K', 'source': 'NASA / ESA Public', 'url': 'https://wikimedia.org'},
  ];

  // Vozes Neurais IA Reais (Ponto 5: Hélder, Enzo, Flávio, Lúcia, Noa, Sandra + Idioma Automático & Instalável)
  String _detectedLanguage = 'Português (PT-PT)';
  final List<Map<String, dynamic>> _languagePacks = [
    {'lang': 'Português (PT-PT)', 'installed': true, 'auto': true},
    {'lang': 'Português (PT-BR)', 'installed': true, 'auto': false},
    {'lang': 'English (EN-US)', 'installed': true, 'auto': false},
    {'lang': 'Español (ES-ES)', 'installed': false, 'auto': false},
    {'lang': 'Français (FR-FR)', 'installed': false, 'auto': false},
  ];
  String _selectedVoiceName = 'Hélder';
  double _voicePitch = 0.78;
  double _voiceRate = 0.50;
  final List<Map<String, dynamic>> _neuralVoices = [
    {'name': 'Hélder', 'gender': 'Masculina · Grave Locutor', 'pitch': 0.74, 'rate': 0.48, 'color': const Color(0xFF38BDF8)},
    {'name': 'Enzo', 'gender': 'Masculina · Energética Gaming', 'pitch': 0.86, 'rate': 0.54, 'color': const Color(0xFF1E78FF)},
    {'name': 'Flávio', 'gender': 'Masculina · Natural Estúdio', 'pitch': 0.80, 'rate': 0.50, 'color': const Color(0xFF10B981)},
    {'name': 'Lúcia', 'gender': 'Feminina · Clara Broadcast', 'pitch': 1.06, 'rate': 0.51, 'color': const Color(0xFFA855F7)},
    {'name': 'Noa', 'gender': 'Feminina · Jovem Dinâmica', 'pitch': 1.14, 'rate': 0.55, 'color': const Color(0xFFF43F5E)},
    {'name': 'Sandra', 'gender': 'Feminina · Suave Institucional', 'pitch': 1.00, 'rate': 0.48, 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    final sysLang = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag().toLowerCase();
    if (sysLang.contains('br')) {
      _detectedLanguage = 'Português (PT-BR)';
    } else if (sysLang.startsWith('en')) {
      _detectedLanguage = 'English (EN-US)';
    } else if (sysLang.startsWith('es')) {
      _detectedLanguage = 'Español (ES-ES)';
    } else {
      _detectedLanguage = 'Português (PT-PT)';
    }
  }

  @override
  void dispose() {
    _studioPlayer.dispose();
    _neuralTts.stop();
    _quickReplyCtrl.dispose();
    _botMsgCtrl.dispose();
    _libSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _playStudioSound(String asset) async {
    try {
      await _studioPlayer.stop();
      await _studioPlayer.setVolume(1.0);
      await _studioPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> _speakWithVoice(String text, {String? forceVoice}) async {
    final vName = forceVoice ?? _selectedVoiceName;
    final voiceCfg = _neuralVoices.firstWhere((v) => v['name'] == vName, orElse: () => _neuralVoices.first);
    final isMale = (voiceCfg['gender'] as String).startsWith('Masculina');
    try {
      await _neuralTts.stop();
      final langCode = _detectedLanguage.contains('BR')
          ? 'pt-BR'
          : _detectedLanguage.contains('EN')
              ? 'en-US'
              : _detectedLanguage.contains('ES')
                  ? 'es-ES'
                  : 'pt-PT';
      await _neuralTts.setLanguage(langCode);
      final voices = await _neuralTts.getVoices;
      if (voices is List) {
        final match = voices.cast<Map>().firstWhere(
          (v) {
            final n = (v['name'] ?? '').toString().toLowerCase();
            final l = (v['locale'] ?? '').toString().toLowerCase();
            final langOk = l.contains(langCode.split('-').first);
            if (!langOk) return false;
            return isMale ? (n.contains('male') || n.contains('man') || n.contains('duarte') || n.contains('antonio') || n.contains('ptd') || n.contains('daniel')) : (n.contains('female') || n.contains('woman') || n.contains('raquel') || n.contains('francisca'));
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          await _neuralTts.setVoice({'name': match['name'], 'locale': match['locale']});
        }
      }
      await _neuralTts.setPitch((voiceCfg['pitch'] as double));
      await _neuralTts.setSpeechRate((voiceCfg['rate'] as double));
      await _neuralTts.speak(text);
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final allMsgs = [...widget.chatFeed, ..._liveChatBuffer];

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // BANNER VISUAL PANORÂMICO DE ESTÚDIO BROADCAST (SEM COCKPIT INÚTIL)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF142A66), Color(0xFF0A1433), Color(0xFF1E1B4B)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.55), width: 1.4),
              boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.18), blurRadius: 16)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('icon.png', width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.graphic_eq_rounded, color: Color(0xFF38BDF8), size: 28)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ESTÚDIO DE PRODUÇÃO & AUTOMAÇÕES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.7, color: Colors.white)),
                          Text('Chat Bot Algoritmo · Presentes · Vozes Neurais IA · Bibliotecas Reais', style: TextStyle(fontSize: 10.5, color: Color(0xFF7DD3FC), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E78FF), Color(0xFF38BDF8)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  tabs: const [
                    Tab(text: '💬 Chat & Bot Algoritmo'),
                    Tab(text: '🎁 Presentes & Alertas'),
                    Tab(text: '🎙️ Vozes IA (Hélder/Enzo/Lúcia)'),
                    Tab(text: '📚 Biblioteca Online CC0'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. CHAT UNIFICADO PERSONALIZÁVEL + BOT ALGORITMO AUTOMÁTICO
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'CHAT UNIFICADO & PERSONALIZAÇÃO VISUAL',
                      icon: Icons.forum_rounded,
                      accent: _chatAccentColor,
                      badge: '${allMsgs.length} MENSAGENS',
                      onTestPressed: () {
                        setState(() {
                          _liveChatBuffer.insert(0, {'platform': 'tiktok', 'user': 'HELL_Bot', 'text': _algoAutoMessages.first});
                        });
                        _playStudioSound('sounds/tap_glass.wav');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Cor do Tema:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              ...[const Color(0xFF38BDF8), const Color(0xFFA855F7), const Color(0xFF10B981), const Color(0xFFF43F5E), const Color(0xFFF59E0B)].map((c) => GestureDetector(
                                    onTap: () => setState(() => _chatAccentColor = c),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _chatAccentColor == c ? Colors.white : Colors.transparent, width: 2)),
                                    ),
                                  )),
                              const Spacer(),
                              Text('Letra: ${_chatFontSize.round()}px', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                          Slider(
                            value: _chatFontSize,
                            min: 11,
                            max: 16,
                            activeColor: _chatAccentColor,
                            onChanged: (v) => setState(() => _chatFontSize = v),
                          ),
                          ...allMsgs.map((m) {
                            final c = _platColor(m['platform'] ?? 'tiktok');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF04091A),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: _chatAccentColor.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text('${m['user']}: ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: _chatFontSize, color: c)),
                                  Expanded(child: Text(m['text'] ?? m['msg'] ?? '', style: TextStyle(fontSize: _chatFontSize, color: Colors.white))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quickReplyCtrl,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(hintText: 'Enviar mensagem no chat unificado...', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(Icons.send_rounded, color: _chatAccentColor),
                                onPressed: () {
                                  final t = _quickReplyCtrl.text.trim();
                                  if (t.isEmpty) return;
                                  setState(() {
                                    _liveChatBuffer.insert(0, {'platform': 'youtube', 'user': 'Criador (Tu)', 'text': t});
                                    _quickReplyCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    HellCockpitWindow(
                      title: 'CHAT BOT IMPULSIONADOR DE ALGORITMO',
                      icon: Icons.rocket_launch_rounded,
                      accent: const Color(0xFF10B981),
                      badge: _algoBotEnabled ? 'ATIVO (${_algoIntervalSec}s)' : 'PAUSADO',
                      onTestPressed: () {
                        final msg = _botMsgCtrl.text.trim().isEmpty ? _algoAutoMessages.first : _botMsgCtrl.text.trim();
                        setState(() => _liveChatBuffer.insert(0, {'platform': 'tiktok', 'user': '🤖 HELL_Bot', 'text': msg}));
                        _playStudioSound('sounds/tap_pulse.wav');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF10B981),
                            title: const Text('Disparo Automático para Mexer com o Algoritmo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            subtitle: const Text('Envia convites automáticos para gostos, comentários e redes sociais a quem passa na live.', style: TextStyle(fontSize: 11, color: Colors.white60)),
                            value: _algoBotEnabled,
                            onChanged: (v) => setState(() => _algoBotEnabled = v),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _botMsgCtrl,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(labelText: 'Nova Mensagem Automática do Bot', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                                onPressed: () {
                                  if (_botMsgCtrl.text.trim().isEmpty) return;
                                  setState(() {
                                    _algoAutoMessages.insert(0, _botMsgCtrl.text.trim());
                                    _botMsgCtrl.clear();
                                  });
                                },
                                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._algoAutoMessages.map((m) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(m, style: const TextStyle(fontSize: 11.5, color: Colors.white))),
                                    IconButton(
                                      icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF10B981)),
                                      onPressed: () {
                                        setState(() => _liveChatBuffer.insert(0, {'platform': 'tiktok', 'user': '🤖 HELL_Bot', 'text': m}));
                                        _playStudioSound('sounds/tap_pulse.wav');
                                      },
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. TODAS AS AUTOMAÇÕES INTEGRADAS (PRESENTES PADRÃO & INDIVIDUAIS + ALERTAS)
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'ATIVAR PRESENTES PADRÃO · REGRA GLOBAL',
                      icon: Icons.card_giftcard_rounded,
                      accent: const Color(0xFFF43F5E),
                      badge: _defaultGiftsEnabled ? 'ATIVO' : 'OFF',
                      onTestPressed: () async {
                        await _playStudioSound(_defaultGiftSound);
                        await _speakWithVoice(_defaultGiftVoiceTpl.replaceAll('{user}', 'SofiaLive').replaceAll('{presente}', 'Rosa Néon'));
                      },
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFFF43F5E),
                            title: const Text('Ativar Presentes Padrão (Som + Voz Automática)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            value: _defaultGiftsEnabled,
                            onChanged: (v) => setState(() => _defaultGiftsEnabled = v),
                          ),
                          DropdownButtonFormField<String>(
                            value: _defaultGiftSound,
                            decoration: const InputDecoration(labelText: 'Som Global dos Presentes', isDense: true, border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'sounds/tap_pulse.wav', child: Text('Pulso Néon Estéreo')),
                              DropdownMenuItem(value: 'sounds/tap_glass.wav', child: Text('Cristal HD Estéreo')),
                              DropdownMenuItem(value: 'sounds/tap_cyber.wav', child: Text('Cyber Mech Estéreo')),
                              DropdownMenuItem(value: 'sounds/hell_startup.wav', child: Text('Fanfarra Arena 4K')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _defaultGiftSound = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._studioGiftsCatalog.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: HellCockpitWindow(
                            title: '${g['name'].toString().toUpperCase()} · ${g['coins']} MOEDAS',
                            icon: Icons.auto_awesome_rounded,
                            accent: const Color(0xFFA855F7),
                            badge: g['visual'] as String,
                            onTestPressed: () async {
                              await _playStudioSound(g['sound'] as String);
                              await _speakWithVoice('Obrigado CarlosPT pelo presente ${g['name']}!');
                            },
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFFA855F7),
                              title: Text('Regra Individual · ${g['visual']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                              value: g['custom'] == true,
                              onChanged: (v) => setState(() => g['custom'] = v),
                            ),
                          ),
                        )),
                  ],
                ),

                // 3. VOZES NEURAIS IA REAIS (HÉLDER, ENZO, FLÁVIO, LÚCIA, NOA, SANDRA + IDIOMA AUTOMÁTICO & INSTALÁVEL)
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'IDIOMA DO APARELHO & PACOTES PARA BAIXAR',
                      icon: Icons.language_rounded,
                      accent: const Color(0xFF38BDF8),
                      badge: _detectedLanguage,
                      onTestPressed: () => _speakWithVoice('Idioma $_detectedLanguage ativo e calibrado no motor neural.'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reconhecido automaticamente pelo aparelho: $_detectedLanguage', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF7DD3FC))),
                          const SizedBox(height: 8),
                          ..._languagePacks.map((lp) {
                            final installed = lp['installed'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                              child: Row(
                                children: [
                                  Expanded(child: Text(lp['lang'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                                  if (installed)
                                    TextButton(
                                      onPressed: () => setState(() => _detectedLanguage = lp['lang'] as String),
                                      child: Text(_detectedLanguage == lp['lang'] ? '✓ Selecionado' : 'Usar', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900)),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                      onPressed: () {
                                        setState(() {
                                          lp['installed'] = true;
                                          _detectedLanguage = lp['lang'] as String;
                                        });
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 15),
                                      label: const Text('Baixar & Instalar', style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    HellCockpitWindow(
                      title: 'ESTÚDIO DE VOZES IA · HÉLDER, ENZO, FLÁVIO, LÚCIA, NOA, SANDRA',
                      icon: Icons.record_voice_over_rounded,
                      accent: const Color(0xFFA855F7),
                      badge: 'VOZ ATIVA: $_selectedVoiceName',
                      onTestPressed: () => _speakWithVoice('Olá! Eu sou a voz $_selectedVoiceName da HELL CREATOR OS em alta definição!'),
                      child: Column(
                        children: _neuralVoices.map((v) {
                          final selected = _selectedVoiceName == v['name'];
                          final c = v['color'] as Color;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: selected ? c.withOpacity(0.18) : const Color(0xFF04091A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? c : Colors.white12, width: selected ? 1.6 : 1),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(backgroundColor: c.withOpacity(0.25), child: Icon(Icons.graphic_eq_rounded, color: c, size: 20)),
                              title: Text(v['name'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                              subtitle: Text(v['gender'] as String, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                onPressed: () async {
                                  setState(() => _selectedVoiceName = v['name'] as String);
                                  await _speakWithVoice('Olá! Eu sou ${v['name']}, pronto para narrar a tua live!', forceVoice: v['name'] as String);
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 17),
                                label: const Text('Ouvir & Aplicar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // 4. BIBLIOTECA REAL DE SONS & IMAGENS ONLINE GRATUITAS (CC0 / NASA / ROYALTY-FREE)
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'GALERIA ONLINE GRATUITA (SONS CC0 & IMAGENS NASA/HD)',
                      icon: Icons.perm_media_rounded,
                      accent: const Color(0xFFF59E0B),
                      badge: 'OUVIR / VER & APLICAR',
                      onTestPressed: () => _playStudioSound('sounds/hell_startup.wav'),
                      child: Column(
                        children: _onlineFreeLibrary.map((item) {
                          final isSound = item['type'] == 'Som CC0';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                            child: Row(
                              children: [
                                if (isSound)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF38BDF8)),
                                  )
                                else
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(item['url'] ?? '', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 36)),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                                      Text('${item['type']} · ${item['source']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7DD3FC))),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                  onPressed: () async {
                                    if (isSound) {
                                      setState(() => _defaultGiftSound = item['asset'] ?? 'sounds/tap_pulse.wav');
                                      await _playStudioSound(_defaultGiftSound);
                                    }
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('✅ "${item['name']}" aplicado na tua biblioteca de automações!'), behavior: SnackBarBehavior.floating),
                                    );
                                  },
                                  child: Text(isSound ? 'Ouvir & Aplicar' : 'Ver & Aplicar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
