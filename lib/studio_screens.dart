import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'live_connectors.dart';

class WheelTriggerEngine {
  static bool chatTriggerEnabled = true;
  static String triggerKeyword = '!roleta';
  static VoidCallback? onRemoteSpinRequested;

  static void checkChatForWheel(String message) {
    if (!chatTriggerEnabled) return;
    if (message.trim().toLowerCase().contains(triggerKeyword.trim().toLowerCase())) {
      onRemoteSpinRequested?.call();
    }
  }
}

class InteractionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> topLikes;
  final List<Map<String, dynamic>> topGifts;
  final List<Map<String, dynamic>> topDonors;
  final Function(String) onSpeakVoice;

  const InteractionScreen({
    super.key,
    required this.topLikes,
    required this.topGifts,
    required this.topDonors,
    required this.onSpeakVoice,
  });

  @override
  State<InteractionScreen> createState() => _InteractionScreenState();
}
class _InteractionScreenState extends State<InteractionScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _remainingSeconds = 300;
  bool _isRunning = false;
  final _customMinsCtrl = TextEditingController(text: '5');

  late AnimationController _wheelCtrl;
  double _wheelAngle = 0;
  String _lastWinner = 'Gira a Roleta ou escreve !roleta no chat!';
  int _podiumTopCount = 3;
  final _optionCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController(text: WheelTriggerEngine.triggerKeyword);

  final List<String> _options = [
    '15 Flexões',
    'Beber Água',
    '20 Abdominais',
    'Salto VIP',
    'Cantar 10s',
    'Nada Desta Vez',
    '10 Agachamentos',
    'Desafio Chat',
  ];

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
    WheelTriggerEngine.onRemoteSpinRequested = _spinWheel;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wheelCtrl.dispose();
    if (WheelTriggerEngine.onRemoteSpinRequested == _spinWheel) {
      WheelTriggerEngine.onRemoteSpinRequested = null;
    }
    super.dispose();
  }

  void _spinWheel() {
    if (_options.isEmpty || _wheelCtrl.isAnimating) return;
    final rng = Random();
    final extraTurns = (5 + rng.nextInt(4)) * 2 * pi;
    final randomOffset = rng.nextDouble() * 2 * pi;
    final start = _wheelAngle;
    final end = start + extraTurns + randomOffset;

    final anim = Tween<double>(begin: start, end: end).animate(CurvedAnimation(parent: _wheelCtrl, curve: Curves.easeOutCubic));
    void listener() => setState(() => _wheelAngle = anim.value);
    anim.addListener(listener);

    _wheelCtrl.forward(from: 0).then((_) {
      anim.removeListener(listener);
      final normalized = _wheelAngle % (2 * pi);
      final slice = (2 * pi) / _options.length;
      final index = ((2 * pi - normalized) / slice).floor() % _options.length;
      final winner = _options[index];
      setState(() => _lastWinner = winner);
      LocalObsServer.pushWheelSpin(_options, winner);
      LocalObsServer.pushAlert('🎡 Roleta 3D HELL Live', 'Saiu o desafio: $winner!', '');
      widget.onSpeakVoice('A roleta parou em: $winner!');
    });
  }
  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        widget.onSpeakVoice('O tempo terminou!');
      }
    });
  }

  String _formatTime(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<Map<String, dynamic>> _computeWeightedTopOverall() {
    final map = <String, Map<String, dynamic>>{};
    for (final item in widget.topLikes) {
      final u = item['user'] ?? 'Viewer';
      map[u] = {
        'user': u,
        'avatar': item['avatar'] ?? '',
        'score': ((item['score'] ?? 0) as num).toInt() * 1,
      };
    }
    for (final item in widget.topGifts) {
      final u = item['user'] ?? 'Viewer';
      final pts = ((item['score'] ?? 0) as num).toInt() * 2;
      map[u] = {
        'user': u,
        'avatar': item['avatar'] ?? map[u]?['avatar'] ?? '',
        'score': (map[u]?['score'] ?? 0) + pts,
      };
    }
    for (final item in widget.topDonors) {
      final u = item['user'] ?? 'Viewer';
      final pts = (((item['score'] ?? 0) as num).toDouble() * 100).round();
      map[u] = {
        'user': u,
        'avatar': item['avatar'] ?? map[u]?['avatar'] ?? '',
        'score': (map[u]?['score'] ?? 0) + pts,
      };
    }
    final list = map.values.toList();
    list.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return list;
  }

  void _launchEndOfLiveCredits(List<Map<String, dynamic>> topOverall) {
    final lines = <String>[
      '🎬 CRÉDITOS OFICIAIS DA LIVE · HELL LIVE',
      '--- TOP APOIANTES & DOADORES ---',
      ...topOverall.take(10).map((e) => '${e['user']} · ${e['score']} pts'),
      '--- TOP PRESENTES ---',
      ...widget.topGifts.take(5).map((e) => '${e['user']} · ${e['score']} moedas'),
      '--- TOP GOSTOS ---',
      ...widget.topLikes.take(5).map((e) => '${e['user']} · ${e['score']} likes'),
      'OBRIGADO A TODOS PELA PRESENÇA!',
    ];
    LocalObsServer.pushCreditsRoll(lines);
    widget.onSpeakVoice('A iniciar os créditos finais da live! Obrigado a todos!');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🎬 Créditos de Fim de Live enviados para o Overlay OBS!'), backgroundColor: Colors.green),
    );
  }
  Widget _overlayLinkBar(String label, String widgetParam) {
    final url = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay?widget=$widgetParam';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF050B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers, color: Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$label:\n$url', style: const TextStyle(fontSize: 11, color: Colors.white70))),
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFF38BDF8), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link "$label" copiado!')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCasinoWheelWidget() {
    return Column(
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _wheelAngle,
                child: CustomPaint(
                  size: const Size(248, 248),
                  painter: _CasinoWheelPainter(options: _options),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFD97706)]),
                  border: Border.all(color: const Color(0xFF78350F), width: 2),
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFACC15), width: 2.5),
                  ),
                  child: const Icon(Icons.arrow_left, color: Color(0xFFFACC15), size: 22),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 140,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
            border: Border.all(color: Colors.white24),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final topOverall = _computeWeightedTopOverall();
    final medals = ['🥇', '🥈', '🥉'];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Temporizador'),
              Tab(text: 'Roleta 3D & Chat'),
              Tab(text: 'Pódio & Tops'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _overlayLinkBar('Overlay Temporizador OBS / Studio', 'timer'),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF1E78FF))),
                      child: Column(
                        children: [
                          const Text('⏱️ Tu controlas o tempo!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 12),
                          Text(_formatTime(_remainingSeconds), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, letterSpacing: 3)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: _startTimer,
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text('Iniciar', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () {
                                  _timer?.cancel();
                                  setState(() => _isRunning = false);
                                },
                                icon: const Icon(Icons.pause, color: Colors.white),
                                label: const Text('Pausar', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () {
                                  _timer?.cancel();
                                  setState(() {
                                    _isRunning = false;
                                    _remainingSeconds = (int.tryParse(_customMinsCtrl.text) ?? 5) * 60;
                                  });
                                },
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Reiniciar', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _customMinsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos', isDense: true))),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                                onPressed: () => setState(() => _remainingSeconds = (int.tryParse(_customMinsCtrl.text) ?? 5) * 60),
                                child: const Text('Aplicar', style: TextStyle(color: Colors.white)),
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
                    _overlayLinkBar('Overlay Roleta 3D OBS / Studio', 'wheel'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFACC15))),
                      child: Column(
                        children: [
                          _buildCasinoWheelWidget(),
                          const SizedBox(height: 10),
                          Text(_lastWinner, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFACC15))),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: _spinWheel,
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: const Text('GIRAR ROLETA AGORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Permitir que o Chat ative a Roleta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            value: WheelTriggerEngine.chatTriggerEnabled,
                            onChanged: (v) => setState(() => WheelTriggerEngine.chatTriggerEnabled = v),
                          ),
                          TextField(
                            controller: _keywordCtrl,
                            onChanged: (v) => WheelTriggerEngine.triggerKeyword = v,
                            decoration: const InputDecoration(labelText: 'Comando do Chat (ex: !roleta)', isDense: true, border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _optionCtrl, decoration: const InputDecoration(hintText: 'Novo desafio visível na roleta...', isDense: true))),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8)),
                                onPressed: () {
                                  if (_optionCtrl.text.trim().isNotEmpty) {
                                    setState(() {
                                      _options.add(_optionCtrl.text.trim());
                                      _optionCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            children: _options.map((o) => Chip(label: Text(o, style: const TextStyle(fontSize: 11)), onDeleted: () => setState(() => _options.remove(o)))).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Mostrar no Pódio:', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownButton<int>(
                          value: _podiumTopCount,
                          dropdownColor: const Color(0xFF0B1636),
                          items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('Top ${i + 1}'))),
                          onChanged: (v) => setState(() => _podiumTopCount = v ?? 3),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF122E73), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _launchEndOfLiveCredits(topOverall),
                      icon: const Icon(Icons.movie_filter, color: Color(0xFFFACC15)),
                      label: const Text('🎬 Iniciar Créditos de Fim de Live (Rolagem Cinema)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                    _overlayLinkBar('Overlay Pódio Geral OBS / Studio', 'podium_overall'),
                    _buildRankingCard('🏆 TOP $_podiumTopCount GERAL (Pontuação Justa)', topOverall, 'pts', const Color(0xFF38BDF8), medals),
                    const SizedBox(height: 12),
                    _overlayLinkBar('Overlay Pódio Likes OBS / Studio', 'podium_likes'),
                    _buildRankingCard('❤️ TOP $_podiumTopCount GOSTOS (LIKES)', widget.topLikes, 'likes', const Color(0xFFF43F5E), medals),
                    const SizedBox(height: 12),
                    _overlayLinkBar('Overlay Pódio Presentes & Doações OBS', 'podium_gifts'),
                    _buildRankingCard('💎 TOP $_podiumTopCount PRESENTES & DOAÇÕES', widget.topGifts, 'moedas', const Color(0xFFFACC15), medals),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingCard(String title, List<Map<String, dynamic>> list, String unit, Color accent, List<String> medals) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 13.5)),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Text('Aguardando interações dos espectadores em direto...', style: TextStyle(color: Colors.white54, fontSize: 12))
          else
            ...list.take(_podiumTopCount).toList().asMap().entries.map((e) {
              final avatar = (e.value['avatar'] ?? '').toString();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.key < 3 ? medals[e.key] : '#${e.key + 1}', style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: accent.withOpacity(0.25),
                      backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                      child: !avatar.startsWith('http') ? Icon(Icons.person, size: 15, color: accent) : null,
                    ),
                  ],
                ),
                title: Text(e.value['user'] ?? 'Espectador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                trailing: Text('${e.value['score']} $unit', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
              );
            }),
        ],
      ),
    );
  }
}

class _CasinoWheelPainter extends CustomPainter {
  final List<String> options;
  _CasinoWheelPainter({required this.options});

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 14;
    final sweep = (2 * pi) / options.length;

    canvas.drawCircle(center, outerRadius, Paint()..color = const Color(0xFFB45309));
    canvas.drawCircle(center, outerRadius - 3, Paint()..color = const Color(0xFFFACC15));

    const sliceColors = [
      Color(0xFFDC2626),
      Color(0xFFF3F4F6),
      Color(0xFFD97706),
      Color(0xFF16A34A),
      Color(0xFF2563EB),
      Color(0xFF9333EA),
    ];

    for (int i = 0; i < options.length; i++) {
      final startAngle = i * sweep;
      final fill = Paint()..color = sliceColors[i % sliceColors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweep, true, fill);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweep,
        true,
        Paint()
          ..color = const Color(0xFFFACC15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sweep / 2);
      final isLight = sliceColors[i % sliceColors.length] == const Color(0xFFF3F4F6);
      final tp = TextPainter(
        text: TextSpan(
          text: options[i],
          style: TextStyle(
            color: isLight ? Colors.black : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerRadius - 32);
      tp.paint(canvas, Offset(24, -tp.height / 2));
      canvas.restore();
    }

    for (int b = 0; b < 24; b++) {
      final a = (b * 2 * pi) / 24;
      final bx = center.dx + (outerRadius - 7) * cos(a);
      final by = center.dy + (outerRadius - 7) * sin(a);
      canvas.drawCircle(Offset(bx, by), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CasinoWheelPainter oldDelegate) => true;
}
