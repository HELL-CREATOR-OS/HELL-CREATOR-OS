import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
  String? _currentlyPlayingUrl;

  // Donation State
  final _mbwayCtrl = TextEditingController();
  final _paypalCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _pixCtrl = TextEditingController();
  final _minAmountCtrl = TextEditingController(text: '1.00');
  bool _readTtsThank = true;

  // Desafios & Roleta 3D State
  late AnimationController _wheelCtrl;
  double _currentAngle = 0;
  String _lastWinner = 'Toca em Girar!';
  final _optionCtrl = TextEditingController();
  final List<String> _wheelOptions = [
    '10 Flexões',
    'Escolher Música',
    'Sem Mira 1 Ronda',
    'Salve Especial',
    'Desafio do Chat',
    'Sorte Grande!',
  ];
  int _subathonSec = 1800;
  bool _subathonRunning = false;
  Timer? _subathonTimer;
  int _podiumLimit = 3;

  // Regras Automáticas ("Quando X -> Faz Y")
  String _ruleProfile = 'Live Padrão';
  final List<Map<String, dynamic>> _automationRules = [
    {'when': 'Novo Seguidor', 'then': 'Anunciar nome por voz + Som Cristalino', 'priority': 'Alta', 'active': true},
    {'when': '30 Rosas Seguidas', 'then': 'Agrupar anúncio na Voice Queue', 'priority': 'Média', 'active': true},
    {'when': 'Presente Especial (>= 500)', 'then': 'Alerta Prioritário + Confetes', 'priority': 'Crítica', 'active': true},
    {'when': 'Live Desligada / Queda', 'then': 'Emitir alerta crítico nos auriculares', 'priority': 'Crítica', 'active': true},
  ];
  final List<String> _executionHistory = [
    '18:40 • Regra "Novo Seguidor" executada com sucesso.',
    '18:32 • Meta de Gostos atualizada para 25%.',
  ];

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _subathonTimer?.cancel();
    super.dispose();
  }

   BoxDecoration _neonCard() => BoxDecoration(
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

  Future<void> _togglePlayAudio(String url, {bool isLocal = false, VoidCallback? onStateUpdate}) async {
    if (url.isEmpty) return;
    if (_currentlyPlayingUrl == url) {
      await widget.sfxPlayer.stop();
      _currentlyPlayingUrl = null;
      if (mounted) setState(() {});
      onStateUpdate?.call();
      return;
    }
    _currentlyPlayingUrl = url;
    if (mounted) setState(() {});
    onStateUpdate?.call();
    try {
      await widget.sfxPlayer.stop();
      if (isLocal || !url.startsWith('http')) {
        await widget.sfxPlayer.play(DeviceFileSource(url));
      } else {
        await widget.sfxPlayer.play(UrlSource(url));
      }
      widget.sfxPlayer.onPlayerComplete.listen((_) {
        if (_currentlyPlayingUrl == url) {
          _currentlyPlayingUrl = null;
          if (mounted) setState(() {});
          onStateUpdate?.call();
        }
      });
    } catch (_) {
      _currentlyPlayingUrl = null;
      if (mounted) setState(() {});
      onStateUpdate?.call();
    }
  }

  Widget _buildSmartMediaWidget(String mediaPath, {double size = 42}) {
    if (mediaPath.isEmpty) {
      return Icon(Icons.card_giftcard, size: size, color: const Color(0xFF38BDF8));
    }
    if (!mediaPath.startsWith('http')) {
      final f = File(mediaPath);
      if (f.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(f, width: size, height: size, fit: BoxFit.contain),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        mediaPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, size: size, color: const Color(0xFF38BDF8)),
      ),
    );
  }

  void _openInstantPreviewDialog({
    required String title,
    required String mediaUrl,
    required String soundUrl,
    String? customVoicePath,
    required String message,
  }) {
    if (customVoicePath != null && customVoicePath.isNotEmpty) {
      widget.sfxPlayer.stop().then((_) => widget.sfxPlayer.play(DeviceFileSource(customVoicePath)));
    } else if (soundUrl.isNotEmpty) {
      widget.sfxPlayer.stop().then((_) {
        if (soundUrl.startsWith('http')) {
          widget.sfxPlayer.play(UrlSource(soundUrl));
        } else {
          widget.sfxPlayer.play(DeviceFileSource(soundUrl));
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF050B1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8), width: 2)),
        title: Text('Pré-visualização · $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmartMediaWidget(mediaUrl, size: 84),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              widget.sfxPlayer.stop();
              Navigator.pop(ctx);
            },
            child: const Text('Fechar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openRichCustomizer({
    required String title,
    required String initialMedia,
    required String initialSound,
    required String? initialCustomVoice,
    required bool initialTtsThank,
    required String? initialCustomMessage,
    required String defaultMessageTemplate,
    required Function(String media, String sound, String? voicePath, bool ttsThank, String customMsg) onSave,
  }) {
    String chosenMedia = initialMedia;
    String chosenSound = initialSound;
    String? customVoicePath = initialCustomVoice;
    bool ttsThank = initialTtsThank;
    final msgCtrl = TextEditingController(text: (initialCustomMessage == null || initialCustomMessage.isEmpty) ? defaultMessageTemplate : initialCustomMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF08112B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: 460,
            child: ListView(
              children: [
                Text('⚙️ Personalizar · $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                const SizedBox(height: 10),
                TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Mensagem do Alerta (usa {user})', isDense: true, border: OutlineInputBorder())),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ler agradecimento por voz (TTS)', style: TextStyle(fontSize: 13)),
                  value: ttsThank,
                  onChanged: (v) => setModalState(() => ttsThank = v),
                ),
                const Text('🔊 Escolher Som:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF38BDF8))),
                ...DefaultMediaLibrary.onlineSoundsRepository.map((s) {
                  final url = s['url']!;
                  final isSelected = chosenSound == url;
                  return ListTile(
                    dense: true,
                    leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: const Color(0xFF38BDF8)),
                    title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 12.5)),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent),
                      onPressed: () => _togglePlayAudio(url, onStateUpdate: () => setModalState(() {})),
                    ),
                    onTap: () => setModalState(() {
                      chosenSound = url;
                      customVoicePath = null;
                    }),
                  );
                }),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                  onPressed: () async {
                    await widget.sfxPlayer.stop();
                    onSave(chosenMedia, chosenSound, customVoicePath, ttsThank, msgCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Guardar Alterações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildUniformActionCard({
    required String title,
    required String subtitle,
    required String mediaUrl,
    required bool isEnabled,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
    required VoidCallback onPlayPreview,
    required Function(bool) onToggleEnabled,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: _neonCard(),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: onDelete),
          _buildSmartMediaWidget(mediaUrl, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 26), onPressed: onPlayPreview),
          Switch(activeColor: Colors.white, activeTrackColor: const Color(0xFF1E78FF), value: isEnabled, onChanged: onToggleEnabled),
        ],
      ),
    );
  }

  Widget _buildDonationSubTab() {
    final donateLink = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/donate';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('💸 Donation & Link /donate', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    onPressed: () {
                      final amount = double.tryParse(_minAmountCtrl.text.replaceAll(',', '.')) ?? 5.0;
                      final natural = AppTranslations.formatEuroNaturalPt(amount);
                      final msg = 'Muito obrigado Apoiante VIP pela doação de $natural!';
                      if (_readTtsThank) widget.onSpeakVoice(msg);
                      LocalObsServer.pushAlert('Apoiante VIP', msg, DefaultMediaLibrary.builtInGifsAndPngs.first['url']!);
                    },
                    icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    label: const Text('Testar Voz', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _minAmountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor Mínimo (€)', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _mbwayCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telemóvel MB WAY', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _paypalCtrl, decoration: const InputDecoration(labelText: 'Link PayPal.me', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _revolutCtrl, decoration: const InputDecoration(labelText: 'Link Revolut.me', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _pixCtrl, decoration: const InputDecoration(labelText: 'Chave PIX', isDense: true)),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ler doações em português natural (ex: cinco euros)', style: TextStyle(fontSize: 12)),
                value: _readTtsThank,
                onChanged: (v) => setState(() => _readTtsThank = v),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF050B1E), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(child: Text(donateLink, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12))),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Colors.white),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: donateLink));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link /donate copiado!')));
                      },
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

  void _spinWheel() {
    if (_wheelOptions.isEmpty) return;
    final rnd = Random();
    final end = _currentAngle + (5 + rnd.nextInt(4)) * 2 * pi + rnd.nextDouble() * 2 * pi;
    final anim = Tween<double>(begin: _currentAngle, end: end).animate(CurvedAnimation(parent: _wheelCtrl, curve: Curves.easeOutQuart));
    anim.addListener(() => setState(() => _currentAngle = anim.value));
    _wheelCtrl.forward(from: 0).then((_) {
      final winner = _wheelOptions[rnd.nextInt(_wheelOptions.length)];
      setState(() {
        _lastWinner = '🎉 $winner';
        _executionHistory.insert(0, 'Roleta 3D sorteou: $winner');
      });
    });
  }
  @override
  Widget build(BuildContext context) {
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
              Tab(text: '🎁 Presentes'),
              Tab(text: '🔔 Alertas'),
              Tab(text: '💸 Donation'),
              Tab(text: '🎯 Metas & Desafios'),
              Tab(text: '⚡ Regras & Histórico'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. PRESENTES
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: _neonCard(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ativar Todos os Presentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Switch(activeColor: Colors.white, activeTrackColor: const Color(0xFF1E78FF), value: widget.allGiftsEnabled, onChanged: widget.onToggleAllGifts),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...DefaultMediaLibrary.tiktokGiftsCatalog.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final g = entry.value;
                      final defaultMsg = 'Obrigado {user} pelo presente ${g['name']}!';
                      return _buildUniformActionCard(
                        title: g['name'] ?? 'Presente',
                        subtitle: '${g['coins']} moedas · ${(g['sound'] ?? '').toString().isEmpty ? 'Sem som' : 'Som ativo'}',
                        mediaUrl: g['png'] ?? '',
                        isEnabled: g['enabled'] == true,
                        onDelete: () => setState(() => DefaultMediaLibrary.tiktokGiftsCatalog.removeAt(idx)),
                        onEdit: () => _openRichCustomizer(
                          title: g['name'] ?? 'Presente',
                          initialMedia: g['png'] ?? '',
                          initialSound: g['sound'] ?? '',
                          initialCustomVoice: g['customVoicePath'],
                          initialTtsThank: g['ttsThank'] ?? true,
                          initialCustomMessage: g['customMessage'],
                          defaultMessageTemplate: defaultMsg,
                          onSave: (m, s, v, tts, msg) => setState(() {
                            g['png'] = m;
                            g['sound'] = s;
                            g['customVoicePath'] = v;
                            g['ttsThank'] = tts;
                            g['customMessage'] = msg;
                          }),
                        ),
                        onPlayPreview: () {
                          final spoken = defaultMsg.replaceAll('{user}', 'Apoiante');
                          _openInstantPreviewDialog(title: g['name'], mediaUrl: g['png'] ?? '', soundUrl: g['sound'] ?? '', message: spoken);
                          if ((g['ttsThank'] ?? true) == true) widget.onSpeakVoice(spoken);
                        },
                        onToggleEnabled: (v) => setState(() => g['enabled'] = v),
                      );
                    }),
                  ],
                ),

                // 2. ALERTAS
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: widget.alertsList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final al = entry.value;
                    final defaultMsg = '{user} ativou ${al['name']}!';
                    return _buildUniformActionCard(
                      title: al['name'] ?? 'Alerta',
                      subtitle: (al['sound'] ?? '').toString().isEmpty ? 'Sem som selecionado' : 'Som ativo',
                      mediaUrl: al['media'] ?? '',
                      isEnabled: al['enabled'] == true,
                      onDelete: () => setState(() => widget.alertsList.removeAt(idx)),
                      onEdit: () => _openRichCustomizer(
                        title: al['name'] ?? 'Alerta',
                        initialMedia: al['media'] ?? '',
                        initialSound: al['sound'] ?? '',
                        initialCustomVoice: al['customVoicePath'],
                        initialTtsThank: al['ttsThank'] ?? true,
                        initialCustomMessage: al['customMessage'],
                        defaultMessageTemplate: defaultMsg,
                        onSave: (m, s, v, tts, msg) => setState(() {
                          al['media'] = m;
                          al['sound'] = s;
                          al['customVoicePath'] = v;
                          al['ttsThank'] = tts;
                          al['customMessage'] = msg;
                        }),
                      ),
                      onPlayPreview: () {
                        final spoken = defaultMsg.replaceAll('{user}', 'Apoiante');
                        _openInstantPreviewDialog(title: al['name'], mediaUrl: al['media'] ?? '', soundUrl: al['sound'] ?? '', message: spoken);
                        if ((al['ttsThank'] ?? true) == true) widget.onSpeakVoice(spoken);
                      },
                      onToggleEnabled: (v) => setState(() => al['enabled'] = v),
                    );
                  }).toList(),
                ),

                // 3. DONATION
                _buildDonationSubTab(),

                // 4. METAS, DESAFIOS (SUBATHON + ROLETA 3D) & PÓDIO TOP 1-10
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonCard(),
                      child: Column(
                        children: [
                          const Text('🎡 Roleta 3D Interativa (Texto nas Fatias)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 15)),
                          const Icon(Icons.arrow_drop_down, size: 34, color: Colors.amberAccent),
                          Transform.rotate(
                            angle: _currentAngle,
                            child: SizedBox(
                              width: 190,
                              height: 190,
                              child: CustomPaint(painter: _LabeledWheelPainter(_wheelOptions)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_lastWinner, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                            onPressed: _spinWheel,
                            child: const Text('GIRAR ROLETA 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _optionCtrl, decoration: const InputDecoration(hintText: 'Novo prémio / desafio...', isDense: true))),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8)),
                                onPressed: () {
                                  if (_optionCtrl.text.trim().isNotEmpty) {
                                    setState(() {
                                      _wheelOptions.add(_optionCtrl.text.trim());
                                      _optionCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonCard(),
                      child: Column(
                        children: [
                          const Text('⏱️ Temporizador Subathon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 6),
                          Text(
                            '${(_subathonSec ~/ 3600).toString().padLeft(2, '0')}:${((_subathonSec % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_subathonSec % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _subathonRunning ? Colors.amber : Colors.green),
                                onPressed: () {
                                  if (_subathonRunning) {
                                    _subathonTimer?.cancel();
                                    setState(() => _subathonRunning = false);
                                  } else {
                                    setState(() => _subathonRunning = true);
                                    _subathonTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                                      if (_subathonSec > 0 && mounted) setState(() => _subathonSec--);
                                    });
                                  }
                                },
                                child: Text(_subathonRunning ? 'Pausar' : 'Iniciar', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(onPressed: () => setState(() => _subathonSec += 300), child: const Text('+5 Min')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _neonCard(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🏆 Pódio Configurável (Top 1–10)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                              DropdownButton<int>(
                                value: _podiumLimit,
                                dropdownColor: const Color(0xFF0B1636),
                                items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => DropdownMenuItem(value: n, child: Text('Top $n'))).toList(),
                                onChanged: (v) => setState(() => _podiumLimit = v ?? 3),
                              ),
                            ],
                          ),
                          ...List.generate(_podiumLimit, (i) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                            title: Text('Lugar #${i + 1} (Atualiza em direto)', style: const TextStyle(fontSize: 12.5)),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),

                // 5. REGRAS "QUANDO X -> FAZ Y", PRIORIDADES, PERFIS & HISTÓRICO
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _neonCard(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('⚡ Regras (Quando X ➔ Faz Y)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                              DropdownButton<String>(
                                value: _ruleProfile,
                                dropdownColor: const Color(0xFF0B1636),
                                items: ['Live Padrão', 'Competitivo', 'Subathon'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setState(() => _ruleProfile = v ?? 'Live Padrão'),
                              ),
                            ],
                          ),
                          ..._automationRules.map((r) => SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Quando: ${r['when']} (${r['priority']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            subtitle: Text('Faz: ${r['then']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8))),
                            value: r['active'] == true,
                            onChanged: (v) => setState(() => r['active'] = v),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _neonCard(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📜 Histórico de Execuções', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 6),
                          ..._executionHistory.map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $h', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          )),
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

class _LabeledWheelPainter extends CustomPainter {
  final List<String> options;
  _LabeledWheelPainter(this.options);

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = (2 * pi) / options.length;
    final colors = [const Color(0xFF1E78FF), const Color(0xFF0E1D47), const Color(0xFF0284C7), const Color(0xFF1E3A8A)];

    for (int i = 0; i < options.length; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * sweep, sweep, true, Paint()..color = colors[i % colors.length]);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * sweep, sweep, true, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.4);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweep + sweep / 2);
      final tp = TextPainter(
        text: TextSpan(text: options[i], style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.72);
      tp.paint(canvas, Offset(radius * 0.22, -tp.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(center, 16, Paint()..color = const Color(0xFF38BDF8));
  }

  @override
  bool shouldRepaint(covariant _LabeledWheelPainter oldDelegate) => true;
}
