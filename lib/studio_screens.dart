import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_data.dart';

class StudioAndGrowthView extends StatefulWidget {
  final Function(String speechText) onSpeakAlert;

  const StudioAndGrowthView({
    super.key,
    required this.onSpeakAlert,
  });

  @override
  State<StudioAndGrowthView> createState() => _StudioAndGrowthViewState();
}

class _StudioAndGrowthViewState extends State<StudioAndGrowthView>
    with SingleTickerProviderStateMixin {
  int _subSection = 0; // 0 = HELL Studio & Content, 1 = Growth Intelligence
  late AnimationController _wheelController;
  double _currentAngle = 0;
  String _wheelResult = 'Escreve !roleta no chat ou gira manualmente';
  int _podiumSize = 3; // Configurável de Top 1 a Top 10
  String _selectedAnalyticsPlatform = 'TikTok LIVE';

  final List<String> _wheelSlices = [
    'Jogar sem Mira',
    '10 Flexões',
    'Subir Sensibilidade',
    'VIP 7 Dias',
    'Só Pistola',
    'Escolher Música',
    'Desafio Chat',
    'Salto Duplo',
  ];

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  void spinWheel() {
    if (_wheelController.isAnimating) return;
    final randomTurns = 4 + math.Random().nextDouble() * 4;
    final targetAngle = _currentAngle + (randomTurns * 2 * math.pi);

    final anim = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
    );

    anim.addListener(() {
      setState(() => _currentAngle = anim.value);
    });

    _wheelController.forward(from: 0).then((_) {
      final index = math.Random().nextInt(_wheelSlices.length);
      final chosen = _wheelSlices[index];
      setState(() => _wheelResult = 'Resultado: $chosen');
      widget.onSpeakAlert('A roleta parou em: $chosen!');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(child: _subTabBtn('HELL Studio & Content', 0)),
              const SizedBox(width: 8),
              Expanded(child: _subTabBtn('Growth Intelligence', 1)),
            ],
          ),
        ),
        Expanded(
          child: _subSection == 0 ? _buildStudioAndContent() : _buildGrowthIntelligence(),
        ),
      ],
    );
  }

  Widget _subTabBtn(String label, int idx) {
    final active = _subSection == idx;
    return GestureDetector(
      onTap: () => setState(() => _subSection = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: HellTheme.neonCard(isActiveGreen: false, radius: 10).copyWith(
          color: active ? HellTheme.neonBlue : HellTheme.cardDark,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? HellTheme.bgDark : HellTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStudioAndContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            children: [
              const Text(
                'ROLETA 3D INTERATIVA (Gatilho Chat: !roleta)',
                style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 210,
                height: 210,
                child: Transform.rotate(
                  angle: _currentAngle,
                  child: CustomPaint(
                    painter: _Wheel3DPainter(_wheelSlices),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _wheelResult,
                style: const TextStyle(color: HellTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HellTheme.neonBlue,
                  foregroundColor: HellTheme.bgDark,
                ),
                onPressed: spinWheel,
                icon: const Icon(Icons.casino_rounded),
                label: const Text('Girar Roleta na Live', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Galeria de Presentes 3D HD com Som Real
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Presentes 3D HD & Efeitos Sonoros Online',
                style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppData.hdGifts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final gift = AppData.hdGifts[i];
                    return GestureDetector(
                      onTap: () {
                        final matchedSound = AppData.onlineSoundLibrary.firstWhere(
                          (s) => s.id == gift.soundId,
                          orElse: () => AppData.onlineSoundLibrary.first,
                        );
                        HellAudioEngine.playUrl(matchedSound.url);
                        widget.onSpeakAlert(
                          'Presente ${gift.name} no valor de ${AppData.formatEuroSpeech(gift.euroValue)}!',
                        );
                      },
                      child: Container(
                        width: 88,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HellTheme.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: gift.glowColor.withValues(alpha: 0.7)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(gift.icon, color: gift.glowColor, size: 30),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: HellTheme.textWhite, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${gift.euroValue.toStringAsFixed(2)} €',
                              style: const TextStyle(color: HellTheme.neonBlue, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pódios Configuráveis (Top 1 a Top 10) & Créditos Finais
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pódio Apoiantes (Top 1 a 10)',
                    style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  DropdownButton<int>(
                    value: _podiumSize,
                    dropdownColor: HellTheme.cardElevated,
                    style: const TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.bold),
                    items: List.generate(10, (i) => i + 1)
                        .map((n) => DropdownMenuItem(value: n, child: Text('Top $n')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _podiumSize = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_podiumSize, (idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('#${idx + 1}', style: const TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Apoiante_PT_${idx + 1}', style: const TextStyle(color: HellTheme.textWhite, fontSize: 13)),
                      ),
                      Text('${(50 - idx * 4).clamp(2, 100)},00 €', style: const TextStyle(color: HellTheme.neonGreen, fontSize: 12)),
                    ],
                  ),
                );
              }),
              const Divider(color: HellTheme.textMuted),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.movie_creation_rounded, color: HellTheme.neonBlue),
                  label: const Text('Lançar Créditos Finais da Live', style: TextStyle(color: HellTheme.textWhite)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: HellTheme.neonBlue)),
                  onPressed: () => widget.onSpeakAlert('A exibir os créditos finais da transmissão na live!'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content Factory (Fábrica de Conteúdos)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTENT FACTORY • FÁBRICA DE CONTEÚDOS',
                style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _factoryChip(Icons.content_cut_rounded, 'Clips Automáticos'),
                  _factoryChip(Icons.stay_current_portrait_rounded, 'Formato Vertical 9:16'),
                  _factoryChip(Icons.subtitles_rounded, 'Legendas PT-PT'),
                  _factoryChip(Icons.image_rounded, 'Criador Thumbnails'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _factoryChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, color: HellTheme.neonBlue, size: 16),
      label: Text(label, style: const TextStyle(color: HellTheme.textWhite, fontSize: 12)),
      backgroundColor: HellTheme.cardElevated,
      side: BorderSide(color: HellTheme.neonBlue.withValues(alpha: 0.4)),
    );
  }

  Widget _buildGrowthIntelligence() {
    final platformMetrics = {
      'TikTok LIVE': {'viewers': '412', 'followers': '+185', 'hours': '14,5 h'},
      'Twitch': {'viewers': '128', 'followers': '+42', 'hours': '18,0 h'},
      'YouTube LIVE': {'viewers': '265', 'followers': '+94', 'hours': '11,2 h'},
      'Kick': {'viewers': '89', 'followers': '+31', 'hours': '9,0 h'},
    };

    final current = platformMetrics[_selectedAnalyticsPlatform]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GROWTH INTELLIGENCE (Por Plataforma Individual)',
                style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Text(
                'Os espectadores são apresentados separadamente por canal para rigor total.',
                style: TextStyle(color: HellTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: platformMetrics.keys.map((plat) {
                  final sel = plat == _selectedAnalyticsPlatform;
                  return ChoiceChip(
                    label: Text(plat),
                    selected: sel,
                    selectedColor: HellTheme.neonBlue,
                    backgroundColor: HellTheme.cardElevated,
                    labelStyle: TextStyle(
                      color: sel ? HellTheme.bgDark : HellTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _selectedAnalyticsPlatform = plat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _metricCard('Média Viewers', current['viewers']!),
                  const SizedBox(width: 8),
                  _metricCard('Novos Seguidores', current['followers']!),
                  const SizedBox(width: 8),
                  _metricCard('Tempo Live', current['hours']!),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
          color: HellTheme.cardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HellTheme.neonBlue.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(val, style: const TextStyle(color: HellTheme.neonGreen, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: HellTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Wheel3DPainter extends CustomPainter {
  final List<String> slices;
  _Wheel3DPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = (2 * math.pi) / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final paint = Paint()
        ..color = i.isEven ? const Color(0xFF0B1A36) : const Color(0xFF102854)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = HellTheme.neonBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweep + sweep / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: slices[i],
          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.72);
      tp.paint(canvas, Offset(radius * 0.22, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, 18, Paint()..color = HellTheme.neonBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
