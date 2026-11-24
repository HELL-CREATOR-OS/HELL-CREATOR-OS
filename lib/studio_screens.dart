import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';
import 'platform_logos.dart';
import 'music_and_social.dart';
import 'live_connectors.dart';

BoxDecoration _neonBox() => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF13275E), Color(0xFF0A1433), Color(0xFF050B1E)],
        stops: [0.0, 0.55, 1.0],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45), width: 1.3),
    );

class SponsorBannerManager {
  static final List<Map<String, String>> activeSponsors = [
    {'title': 'HELL CREATOR · Controlo Total das Tuas Lives', 'url': 'mailto:hellcreatoros@gmail.com'},
    {'title': 'Espaço Oficial Patrocinadores · Anuncie aqui: hellcreatoros@gmail.com', 'url': 'mailto:hellcreatoros@gmail.com'},
  ];
}

class HellFriendRobotAvatar extends StatelessWidget {
  final String skinId;
  final Color primaryColor;
  final Color eyeColor;
  final double size;

  const HellFriendRobotAvatar({
    super.key,
    required this.skinId,
    required this.primaryColor,
    required this.eyeColor,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HellRobotPainter(skinId: skinId, primaryColor: primaryColor, eyeColor: eyeColor),
      ),
    );
  }
}

class _HellRobotPainter extends CustomPainter {
  final String skinId;
  final Color primaryColor;
  final Color eyeColor;

  _HellRobotPainter({required this.skinId, required this.primaryColor, required this.eyeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, primaryColor.withOpacity(0.85), const Color(0xFF0A1433)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final borderPaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032;

    final visorPaint = Paint()..color = const Color(0xFF04091A);
    final eyeSolid = Paint()..color = eyeColor;

    if (skinId == 'cyber_guardian' || skinId == 'classic_bot') {
      canvas.drawLine(Offset(w * 0.5, h * 0.04), Offset(w * 0.5, h * 0.14), borderPaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.04), w * 0.045, eyeSolid);
    } else if (skinId == 'mecha_titan') {
      canvas.drawLine(Offset(w * 0.30, h * 0.05), Offset(w * 0.34, h * 0.16), borderPaint);
      canvas.drawLine(Offset(w * 0.70, h * 0.05), Offset(w * 0.66, h * 0.16), borderPaint);
    }

    final headRect = skinId == 'aero_orb'
        ? RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.12, w * 0.56, h * 0.38), Radius.circular(w * 0.28))
        : RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.14, w * 0.52, h * 0.36), Radius.circular(w * 0.12));
    canvas.drawRRect(headRect, bodyPaint);
    canvas.drawRRect(headRect, borderPaint);

    final visorRect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.40, h * 0.18), Radius.circular(w * 0.08));
    canvas.drawRRect(visorRect, visorPaint);

    canvas.drawCircle(Offset(w * 0.41, h * 0.31), w * 0.034, eyeSolid);
    canvas.drawCircle(Offset(w * 0.59, h * 0.31), w * 0.034, eyeSolid);

    final torsoRect = skinId == 'mecha_titan'
        ? RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.53, w * 0.64, h * 0.40), Radius.circular(w * 0.10))
        : RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.23, h * 0.53, w * 0.54, h * 0.39), Radius.circular(w * 0.16));
    canvas.drawRRect(torsoRect, bodyPaint);
    canvas.drawRRect(torsoRect, borderPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.10, h * 0.56, w * 0.10, h * 0.28), Radius.circular(w * 0.05)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.80, h * 0.56, w * 0.10, h * 0.28), Radius.circular(w * 0.05)), bodyPaint);

    // Emblema discreto HELL ("H") no peito esquerdo do robô
    final badgeCenter = Offset(w * 0.62, h * 0.67);
    final badgeRadius = w * 0.095;
    canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = const Color(0xFF050B1E));
    canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = w * 0.018);

    final tp = TextPainter(
      text: TextSpan(text: 'H', style: TextStyle(color: const Color(0xFF38BDF8), fontSize: w * 0.115, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HellRobotPainter oldDelegate) =>
      oldDelegate.skinId != skinId || oldDelegate.primaryColor != primaryColor || oldDelegate.eyeColor != eyeColor;
}
class HellVirtualFriendController {
  static final ValueNotifier<String> botName = ValueNotifier<String>('Amigo HELL IA');
  static final ValueNotifier<String> wakePhrase = ValueNotifier<String>('Olá Amigo HELL');
  static final ValueNotifier<String> skinId = ValueNotifier<String>('cyber_guardian');
  static final ValueNotifier<Color> primaryColor = ValueNotifier<Color>(const Color(0xFF38BDF8));
  static final ValueNotifier<Color> eyeColor = ValueNotifier<Color>(const Color(0xFF38BDF8));
  static final ValueNotifier<bool> floatingBubbleEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> voiceWakeEnabled = ValueNotifier<bool>(true);
  static final List<Map<String, String>> alarms = List<Map<String, String>>.empty(growable: true);

  static Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    botName.value = prefs.getString('hell_ai_bot_name') ?? 'Amigo HELL IA';
    wakePhrase.value = prefs.getString('hell_ai_wake_phrase') ?? 'Olá Amigo HELL';
    skinId.value = prefs.getString('hell_ai_skin') ?? 'cyber_guardian';
    primaryColor.value = Color(prefs.getInt('hell_ai_primary_color') ?? 0xFF38BDF8);
    eyeColor.value = Color(prefs.getInt('hell_ai_eye_color') ?? 0xFF38BDF8);
    floatingBubbleEnabled.value = prefs.getBool('hell_ai_floating_enabled') ?? true;
    voiceWakeEnabled.value = prefs.getBool('hell_ai_voice_wake') ?? true;
  }

  static Future<void> savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_ai_bot_name', botName.value);
    await prefs.setString('hell_ai_wake_phrase', wakePhrase.value);
    await prefs.setString('hell_ai_skin', skinId.value);
    await prefs.setInt('hell_ai_primary_color', primaryColor.value.value);
    await prefs.setInt('hell_ai_eye_color', eyeColor.value.value);
    await prefs.setBool('hell_ai_floating_enabled', floatingBubbleEnabled.value);
    await prefs.setBool('hell_ai_voice_wake', voiceWakeEnabled.value);
  }

  static Future<String> processPrompt(String rawInput) async {
    final q = rawInput.toLowerCase().trim();
    final name = botName.value;

    if (q.contains('piada') || q.contains('rir') || q.contains('anedota')) {
      const jokes = <String>[
        'Porque é que o streamer levou um guarda-chuva para o PC? Porque disseram que ia chover seguidores na live!',
        'O que diz um teclado para o rato? Não cliques tanto em mim que eu hoje estou sensível!',
        'Qual é o cúmulo de um gamer? Perder a partida e culpar o lag do micro-ondas!',
      ];
      final chosen = jokes[Random().nextInt(jokes.length)];
      await HellNeuralVoiceEngine.speak(chosen);
      return chosen;
    }

    if (q.contains('tocar') || q.contains('música') || q.contains('musica') || q.contains('rádio') || q.contains('radio')) {
      int targetIdx = 0;
      if (q.contains('rfm')) targetIdx = 1;
      if (q.contains('mega')) targetIdx = 2;
      if (q.contains('cidade')) targetIdx = 3;
      if (q.contains('m80')) targetIdx = 4;
      if (q.contains('lofi') || q.contains('lo-fi')) targetIdx = 10;
      await MusicDeckController.playIndex(targetIdx);
      final st = MusicDeckController.radioStations[targetIdx]['title'] ?? 'Rádio Online';
      final reply = 'A colocar $st a tocar em segundo plano para ti!';
      await HellNeuralVoiceEngine.speak(reply);
      return reply;
    }

    if (q.contains('parar música') || q.contains('parar rádio') || q.contains('silêncio')) {
      await MusicDeckController.stopImmediately();
      const reply = 'Áudio e rádio desligados de imediato.';
      await HellNeuralVoiceEngine.speak(reply);
      return reply;
    }

    if (q.contains('tempo') || q.contains('meteorologia') || q.contains('hora') || q.contains('horas')) {
      final now = TimeOfDay.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      final reply = 'São agora $hh:$mm. Céu limpo e condições ideais para fazeres uma transmissão épica!';
      await HellNeuralVoiceEngine.speak(reply);
      return reply;
    }

    if (q.contains('alarme') || q.contains('avisa') || q.contains('lembrete') || q.contains('lembrar')) {
      final minsMatch = RegExp(r'(\d+)').firstMatch(q);
      final mins = int.tryParse(minsMatch?.group(1) ?? '15') ?? 15;
      alarms.insert(0, {'label': rawInput, 'inMinutes': '$mins min', 'created': TimeOfDay.now().toString()});
      Timer(Duration(minutes: mins), () {
        HellNeuralVoiceEngine.speak('Atenção! O teu lembrete de $mins minutos chegou!');
      });
      final reply = 'Alarme criado! Vou avisar-te por voz daqui a $mins minutos.';
      await HellNeuralVoiceEngine.speak(reply);
      return reply;
    }

    if (q.contains('dica') || q.contains('crescer') || q.contains('ajuda') || q.contains('live')) {
      const tip = 'Dica de crescimento: Nos primeiros 5 minutos de live, lança uma votação 1a, 1b ou 1c no chat para ativar o algoritmo de recomendação!';
      await HellNeuralVoiceEngine.speak(tip);
      return tip;
    }

    final generic = 'Olá! Eu sou o $name. Posso contar uma piada, ligar qualquer rádio ou música em segundo plano, dizer-te as horas, dar dicas para a live ou criar alarmes por voz!';
    await HellNeuralVoiceEngine.speak(generic);
    return generic;
  }
}

class FloatingHellFriendBubble extends StatefulWidget {
  const FloatingHellFriendBubble({super.key});

  @override
  State<FloatingHellFriendBubble> createState() => _FloatingHellFriendBubbleState();
}

class _FloatingHellFriendBubbleState extends State<FloatingHellFriendBubble> {
  double _rightOffset = 14;
  double _bottomOffset = 155;

  void _openAssistantModal(BuildContext context) {
    final inputCtrl = TextEditingController();
    final List<Map<String, String>> chat = <Map<String, String>>[
      {
        'from': 'bot',
        'text': 'Olá! Sou o ${HellVirtualFriendController.botName.value}. Pede uma piada, rádio, dica, horas ou um alarme!',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          backgroundColor: const Color(0xFF0A1433),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: HellVirtualFriendController.primaryColor.value, width: 1.6),
          ),
          title: Row(
            children: [
              HellFriendRobotAvatar(
                skinId: HellVirtualFriendController.skinId.value,
                primaryColor: HellVirtualFriendController.primaryColor.value,
                eyeColor: HellVirtualFriendController.eyeColor.value,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(HellVirtualFriendController.botName.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Text('Voz: "${HellVirtualFriendController.wakePhrase.value}"', style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 390,
            height: 300,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: chat.length,
                    itemBuilder: (_, i) {
                      final m = chat[i];
                      final isBot = m['from'] == 'bot';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isBot ? const Color(0xFF13275E) : const Color(0xFF04091A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                      );
                    },
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('😂 Piada', style: TextStyle(fontSize: 10.5)),
                      onPressed: () async {
                        final r = await HellVirtualFriendController.processPrompt('conta uma piada');
                        setModal(() {
                          chat.add({'from': 'user', 'text': 'Conta uma piada'});
                          chat.add({'from': 'bot', 'text': r});
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('📻 Rádio', style: TextStyle(fontSize: 10.5)),
                      onPressed: () async {
                        final r = await HellVirtualFriendController.processPrompt('tocar rádio comercial');
                        setModal(() {
                          chat.add({'from': 'user', 'text': 'Tocar rádio'});
                          chat.add({'from': 'bot', 'text': r});
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('⏰ Alarme 10m', style: TextStyle(fontSize: 10.5)),
                      onPressed: () async {
                        final r = await HellVirtualFriendController.processPrompt('criar alarme de 10 minutos');
                        setModal(() {
                          chat.add({'from': 'user', 'text': 'Alarme 10 min'});
                          chat.add({'from': 'bot', 'text': r});
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inputCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(hintText: 'Fala com o teu amigo IA...', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                      onPressed: () async {
                        final q = inputCtrl.text.trim();
                        if (q.isEmpty) return;
                        inputCtrl.clear();
                        final ans = await HellVirtualFriendController.processPrompt(q);
                        setModal(() {
                          chat.add({'from': 'user', 'text': q});
                          chat.add({'from': 'bot', 'text': ans});
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: HellVirtualFriendController.floatingBubbleEnabled,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return Positioned(
          right: _rightOffset,
          bottom: _bottomOffset,
          child: GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _rightOffset = (_rightOffset - d.delta.dx).clamp(6.0, 280.0);
                _bottomOffset = (_bottomOffset - d.delta.dy).clamp(70.0, 520.0);
              });
            },
            onTap: () => _openAssistantModal(context),
            child: ValueListenableBuilder<Color>(
              valueListenable: HellVirtualFriendController.primaryColor,
              builder: (_, pColor, __) => Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1433).withOpacity(0.95),
                  shape: BoxShape.circle,
                  border: Border.all(color: pColor, width: 2),
                ),
                child: HellFriendRobotAvatar(
                  skinId: HellVirtualFriendController.skinId.value,
                  primaryColor: pColor,
                  eyeColor: HellVirtualFriendController.eyeColor.value,
                  size: 46,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ControlCenterScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onLogout;
  final Map<String, bool> activePlatforms;
  final List<Map<String, String>> chatFeed;
  final String syncCode;
  final bool isSecondScreenPaired;
  final Function(String) onValidateSyncCode;
  final Widget Function()? buildOfficialAutomationsScreen;
  final Widget Function()? buildOfficialVoiceScreen;
  final Widget Function()? buildOfficialMusicScreen;

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
    this.buildOfficialAutomationsScreen,
    this.buildOfficialVoiceScreen,
    this.buildOfficialMusicScreen,
  });

  @override
  State<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends State<ControlCenterScreen> {
  bool _ttsEnabled = true;
  final TextEditingController _quickReplyCtrl = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();

  double _micVol = 0.85;
  double _gameVol = 0.65;
  double _musicVol = 0.45;
  double _alertVol = 0.90;
  bool _micMuted = false;

  final List<Map<String, String>> _liveChatBuffer = <Map<String, String>>[
    {'platform': 'tiktok', 'user': '@joao_gamer', 'text': 'Que jogada absurda mano!!'},
    {'platform': 'twitch', 'user': 'SofiaLive', 'text': 'A imagem 4K está brutal!'},
    {'platform': 'youtube', 'user': 'CarlosPT', 'text': 'Salve para Portugal!'},
    {'platform': 'kick', 'user': 'Nitro_99', 'text': 'Rumo à meta de hoje!'},
  ];

  final List<Map<String, dynamic>> _recentAlerts = <Map<String, dynamic>>[
    {'type': 'SUB', 'user': 'SofiaLive', 'detail': 'Sub Tier 1 · 3 Meses', 'color': const Color(0xFFA855F7), 'icon': Icons.star_rounded},
    {'type': 'DONATION', 'user': 'CarlosPT', 'detail': '€15.00 · MB WAY', 'color': const Color(0xFF10B981), 'icon': Icons.euro_rounded},
    {'type': 'PRESENTE', 'user': '@joao_gamer', 'detail': 'Galáxia (1000 Moedas)', 'color': const Color(0xFFF43F5E), 'icon': Icons.auto_awesome},
    {'type': 'FOLLOW', 'user': 'Nitro_99', 'detail': 'Novo Seguidor Kick', 'color': const Color(0xFF38BDF8), 'icon': Icons.person_add_alt_1},
  ];

  final List<double> _bitrateSamples = <double>[5.8, 6.2, 6.4, 6.1, 6.5, 6.7, 6.5, 6.6];

  @override
  void dispose() {
    _quickReplyCtrl.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  void _openOfficialModuleInsideControlCenter(String title, Widget officialScreen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF050B1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A1433),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          ),
          body: officialScreen,
        ),
      ),
    );
  }

  void _simulateLiveAction({
    required String moduleLabel,
    required String title,
    required String subtitle,
    Color accent = const Color(0xFF38BDF8),
    String soundAsset = 'sounds/tap_pulse.wav',
    String? spokenText,
  }) {
    LiveActionSimulator.showSimulatedOverlay(
      context,
      category: moduleLabel,
      title: title,
      subtitle: subtitle,
      accent: accent,
      soundPathOrUrl: soundAsset,
      spokenText: spokenText,
      audioPlayer: _previewPlayer,
      onSpeakVoice: (txt) => HellNeuralVoiceEngine.speak(txt),
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

  Widget _buildTopMultiPlatformWindow(bool isWide) {
    final basePlatforms = <Map<String, dynamic>>[
      {'id': 'tiktok', 'name': 'TikTok', 'active': widget.activePlatforms['tiktok'] == true, 'viewers': widget.activePlatforms['tiktok'] == true ? 142 : 0},
      {'id': 'twitch', 'name': 'Twitch', 'active': widget.activePlatforms['twitch'] == true, 'viewers': widget.activePlatforms['twitch'] == true ? 68 : 0},
      {'id': 'youtube', 'name': 'YouTube', 'active': widget.activePlatforms['youtube'] == true, 'viewers': widget.activePlatforms['youtube'] == true ? 95 : 0},
      {'id': 'kick', 'name': 'Kick', 'active': widget.activePlatforms['kick'] == true, 'viewers': widget.activePlatforms['kick'] == true ? 41 : 0},
    ];
    final int displayTotal = basePlatforms.fold<int>(0, (sum, p) => sum + ((p['active'] == true) ? (p['viewers'] as int? ?? 0) : 0));

    return HellCockpitWindow(
      title: 'MULTIPLATAFORMAS · TRANSMISSÃO EM TEMPO REAL',
      icon: Icons.sensors_rounded,
      accent: const Color(0xFF38BDF8),
      badge: 'TOTAL: $displayTotal',
      onTestPressed: () => _simulateLiveAction(
        moduleLabel: 'TESTE MULTIPLATAFORMA',
        title: 'Sinal & Áudio Verificados ($displayTotal espectadores)',
        subtitle: 'Overlays 4K, alertas e retorno de som operacionais.',
        soundAsset: 'sounds/tap_cyber.wav',
        spokenText: 'Teste multiplataforma concluído com sucesso!',
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: basePlatforms.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isWide ? 1.85 : 1.40,
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
                    setState(() => widget.activePlatforms[id] = !isOnline);
                    _simulateLiveAction(
                      moduleLabel: name.toUpperCase(),
                      title: !isOnline ? '$name LIGADO (EM DIRETO)' : '$name DESLIGADO',
                      subtitle: !isOnline ? 'Chat e alertas de $name sincronizados!' : 'Transmissão em $name terminada.',
                      accent: !isOnline ? Colors.greenAccent : const Color(0xFF38BDF8),
                      soundAsset: 'sounds/tap_glass.wav',
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.72), borderRadius: BorderRadius.circular(999)),
                  child: Text('$viewers', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatModule() {
    final allMsgs = <Map<String, String>>[...widget.chatFeed, ..._liveChatBuffer];
    return HellCockpitWindow(
      title: 'CHAT UNIFICADO & VOZ NEURAL',
      icon: Icons.forum_rounded,
      accent: const Color(0xFF38BDF8),
      badge: 'TTS ${_ttsEnabled ? "ON" : "OFF"}',
      onExpandOfficialScreen: widget.buildOfficialVoiceScreen != null
          ? () => _openOfficialModuleInsideControlCenter('Chat e Voz TTS', widget.buildOfficialVoiceScreen!())
          : null,
      onTestPressed: () => _simulateLiveAction(
        moduleLabel: 'CHAT & VOZ NEURAL',
        title: '@joao_gamer: "Que jogada absurda mano!!"',
        subtitle: 'Mensagem lida pela Voz Neural ativa e destacada no ecrã.',
        spokenText: 'João gamer diz: Que jogada absurda mano!',
      ),
      child: Column(
        children: [
          ...allMsgs.take(4).map((m) {
            final plat = m['platform'] ?? 'tiktok';
            final c = _platColor(plat);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF04091A),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.withOpacity(0.45)),
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _quickReplyCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Responder no chat ou falar por voz...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: const Color(0xFF04091A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
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
                    _liveChatBuffer.insert(0, {'platform': 'youtube', 'user': 'Tu (Streamer)', 'text': t});
                    _quickReplyCtrl.clear();
                  });
                  _simulateLiveAction(moduleLabel: 'MENSAGEM ENVIADA', title: 'Tu (Streamer)', subtitle: t, spokenText: _ttsEnabled ? t : null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsAndAutomationsModule() {
    return HellCockpitWindow(
      title: 'AUTOMAÇÕES, PRESENTES & ALERTAS',
      icon: Icons.bolt_rounded,
      accent: const Color(0xFFA855F7),
      badge: '${_recentAlerts.length} EVENTOS',
      onExpandOfficialScreen: widget.buildOfficialAutomationsScreen != null
          ? () => _openOfficialModuleInsideControlCenter('Automações', widget.buildOfficialAutomationsScreen!())
          : null,
      onTestPressed: () => _simulateLiveAction(
        moduleLabel: 'ALERTA & PRESENTE EM LIVE',
        title: 'SofiaLive enviou Galáxia (1000 Moedas)!',
        subtitle: 'Overlay 4K + Som + Agradecimento Vocal executados!',
        accent: const Color(0xFFA855F7),
        soundAsset: 'sounds/hell_startup.wav',
        spokenText: 'Muito obrigado Sofia Live pela Galáxia!',
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentAlerts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, mainAxisExtent: 64),
            itemBuilder: (_, i) {
              final a = _recentAlerts[i];
              final c = a['color'] as Color;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _simulateLiveAction(
                  moduleLabel: 'SIMULAÇÃO ${a['type']}',
                  title: '${a['user']} · ${a['detail']}',
                  subtitle: 'Reprodução simulada de como aparece no ecrã da live!',
                  accent: c,
                  soundAsset: 'sounds/tap_glass.wav',
                  spokenText: 'Obrigado ${a['user']}!',
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.55))),
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
          if (widget.buildOfficialAutomationsScreen != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openOfficialModuleInsideControlCenter('Automações', widget.buildOfficialAutomationsScreen!()),
                icon: const Icon(Icons.open_in_new, size: 15, color: Color(0xFFA855F7)),
                label: const Text('Abrir Painel Completo de Automações', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMixerModule() {
    Widget bar(String label, double val, Color c, ValueChanged<double> onChanged) {
      return Expanded(
        child: Column(
          children: [
            Text('${(val * 100).round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            Slider(value: val, activeColor: c, onChanged: onChanged),
          ],
        ),
      );
    }

    return HellCockpitWindow(
      title: 'MIXER DE ÁUDIO 48kHz & MÚSICA',
      icon: Icons.equalizer_rounded,
      accent: const Color(0xFF10B981),
      badge: _micMuted ? 'MIC MUTADO' : '48kHz ATIVO',
      onExpandOfficialScreen: widget.buildOfficialMusicScreen != null
          ? () => _openOfficialModuleInsideControlCenter('Música & Rádios', widget.buildOfficialMusicScreen!())
          : null,
      onTestPressed: () => _simulateLiveAction(
        moduleLabel: 'MIXER DE ÁUDIO',
        title: 'Canais Calibrados (Mic ${(_micVol * 100).round()}% · Alertas ${(_alertVol * 100).round()}%)',
        subtitle: 'Retorno estéreo sem distorção verificado!',
        accent: const Color(0xFF10B981),
        soundAsset: 'sounds/tap_glass.wav',
      ),
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
              style: ElevatedButton.styleFrom(backgroundColor: _micMuted ? Colors.redAccent : const Color(0xFF1E78FF)),
              onPressed: () => setState(() => _micMuted = !_micMuted),
              icon: Icon(_micMuted ? Icons.mic_off : Icons.mic, size: 16),
              label: Text(_micMuted ? 'Ativar Microfone' : 'Mutar Microfone', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorAndHealthModule() {
    return HellCockpitWindow(
      title: 'SAÚDE DA LIVE & CLIPE RÁPIDO 9:16',
      icon: Icons.show_chart_rounded,
      accent: const Color(0xFFF59E0B),
      badge: '60 FPS · 6.5 Mbps',
      onTestPressed: () => _simulateLiveAction(
        moduleLabel: 'CAPTURA INSTANTÂNEA 9:16',
        title: 'Clipe de 30 Segundos Guardado!',
        subtitle: 'Enviado para a Fábrica de Conteúdos (expira em 24h se não for guardado).',
        accent: const Color(0xFFF59E0B),
        soundAsset: 'sounds/tap_cyber.wav',
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
          onPressed: () => _simulateLiveAction(
            moduleLabel: 'FÁBRICA DE CONTEÚDOS',
            title: 'Clipe 9:16 Capturado!',
            subtitle: 'Disponível durante 24 horas no editor.',
            accent: const Color(0xFFF59E0B),
            soundAsset: 'sounds/tap_pulse.wav',
          ),
          icon: const Icon(Icons.movie_creation_rounded, size: 17),
          label: const Text('CRIAR CLIPE 9:16 AGORA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        if (isWide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopMultiPlatformWindow(true),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [_buildChatModule(), const SizedBox(height: 14), _buildDirectorAndHealthModule()])),
                  const SizedBox(width: 14),
                  Expanded(child: Column(children: [_buildAlertsAndAutomationsModule(), const SizedBox(height: 14), _buildMixerModule()])),
                ],
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildTopMultiPlatformWindow(false),
            const SizedBox(height: 12),
            _buildChatModule(),
            const SizedBox(height: 12),
            _buildAlertsAndAutomationsModule(),
            const SizedBox(height: 12),
            _buildMixerModule(),
            const SizedBox(height: 12),
            _buildDirectorAndHealthModule(),
          ],
        );
      },
    );
  }
}

class ContentFactoryScreen extends StatefulWidget {
  const ContentFactoryScreen({super.key});

  @override
  State<ContentFactoryScreen> createState() => _ContentFactoryScreenState();
}

class _ContentFactoryScreenState extends State<ContentFactoryScreen> {
  String _selectedAspect = '9:16';
  String _selectedFilter = 'HDR Cyber';
  double _playheadPos = 0.35;
  double _trimStart = 0.10;
  double _trimEnd = 0.90;
  bool _autoCaptions = true;
  Timer? _expiryTicker;
  final TextEditingController _overlayTextCtrl = TextEditingController(text: 'CLUTCH ÉPICO AO VIVO! 🔥');

  final List<Map<String, dynamic>> _capturedClips = <Map<String, dynamic>>[
    {'id': 'c1', 'title': 'Clipe Auto #1 · Pico de Chat', 'duration': '00:28', 'expiresAt': DateTime.now().add(const Duration(hours: 23, minutes: 42)), 'savedForever': false},
    {'id': 'c2', 'title': 'Clipe Manual #2 · Vitória Final', 'duration': '00:45', 'expiresAt': DateTime.now().add(const Duration(hours: 18, minutes: 15)), 'savedForever': false},
  ];

  @override
  void initState() {
    super.initState();
    _purgeExpiredClips();
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _purgeExpiredClips());
    });
  }

  void _purgeExpiredClips() {
    final now = DateTime.now();
    _capturedClips.removeWhere((c) => c['savedForever'] != true && (c['expiresAt'] as DateTime).isBefore(now));
  }

  String _remaining24hLabel(Map<String, dynamic> clip) {
    if (clip['savedForever'] == true) return 'Guardado na Galeria ✓';
    final diff = (clip['expiresAt'] as DateTime).difference(DateTime.now());
    if (diff.isNegative) return 'Expirado';
    return 'Expira em ${diff.inHours}h ${(diff.inMinutes % 60)}m';
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    _overlayTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _neonBox(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎬 ESTÚDIO DE EDIÇÃO · CAPCUT PRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF38BDF8))),
                  Chip(label: Text('Proporção $_selectedAspect', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)), backgroundColor: const Color(0xFF1E78FF)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F296E), Color(0xFF04091A), Color(0xFF4C1D95)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_filled_rounded, size: 44, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(_overlayTextCtrl.text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.amberAccent)),
                    if (_autoCaptions) const Text('[Legendas IA PT-PT Ativas]', style: TextStyle(fontSize: 10.5, color: Color(0xFF7DD3FC))),
                  ],
                ),
              ),
              Slider(value: _playheadPos, activeColor: Colors.white, onChanged: (v) => setState(() => _playheadPos = v)),
              RangeSlider(
                values: RangeValues(_trimStart, _trimEnd),
                activeColor: const Color(0xFFF43F5E),
                onChanged: (r) => setState(() {
                  _trimStart = r.start;
                  _trimEnd = r.end;
                }),
              ),
              Wrap(
                spacing: 6,
                children: <String>['9:16', '16:9', '1:1']
                    .map((ratio) => ChoiceChip(
                          label: Text(ratio),
                          selected: _selectedAspect == ratio,
                          onSelected: (_) => setState(() => _selectedAspect = ratio),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _overlayTextCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Texto / Título no Vídeo', isDense: true, border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Legendas Automáticas IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                value: _autoCaptions,
                onChanged: (v) => setState(() => _autoCaptions = v),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () {
                  setState(() {
                    _capturedClips.insert(0, {
                      'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
                      'title': 'Clipe Novo · ${_overlayTextCtrl.text}',
                      'duration': '00:30',
                      'expiresAt': DateTime.now().add(const Duration(hours: 24)),
                      'savedForever': false,
                    });
                  });
                },
                icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
                label: const Text('Capturar Momento (Expira 24h)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HellCockpitWindow(
          title: 'CLIPES CAPTADOS (EXPIRAÇÃO 24H)',
          icon: Icons.auto_delete_outlined,
          accent: const Color(0xFFF43F5E),
          child: Column(
            children: _capturedClips.map((clip) {
              final saved = clip['savedForever'] == true;
              return ListTile(
                dense: true,
                title: Text(clip['title'].toString()),
                subtitle: Text('${clip['duration']} · ${_remaining24hLabel(clip)}'),
                trailing: TextButton(
                  onPressed: () => setState(() => clip['savedForever'] = true),
                  child: Text(saved ? 'Guardado ✓' : 'Manter'),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class SmartBrainScreen extends StatefulWidget {
  const SmartBrainScreen({super.key});

  @override
  State<SmartBrainScreen> createState() => _SmartBrainScreenState();
}

class _SmartBrainScreenState extends State<SmartBrainScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<Map<String, String>> _insights = <Map<String, String>>[
    {'tag': 'MELHOR HORÁRIO DETETADO', 'msg': 'Entre as 21h15 e as 23h45 a tua retenção sobe +41% em Portugal e Brasil.'},
    {'tag': 'AÇÃO RECOMENDADA AGORA', 'msg': 'Lança uma votação rápida (1a / 1b / 1c) nos primeiros 8 minutos para duplicar os comentários.'},
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
          title: 'GESTÃO IA EM TEMPO REAL · ESTRATÉGIA & RESULTADOS',
          icon: Icons.psychology_rounded,
          accent: const Color(0xFF8B5CF6),
          badge: 'ANÁLISE ATIVA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._insights.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['tag'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                        Text(item['msg'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  )),
              Row(
                children: [
                  Expanded(child: TextField(controller: _promptCtrl, decoration: const InputDecoration(hintText: 'Pedir estratégia IA...', isDense: true))),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      final q = _promptCtrl.text.trim();
                      if (q.isEmpty) return;
                      setState(() {
                        _insights.insert(0, {'tag': 'ESTRATÉGIA IA', 'msg': 'Para "$q": usa meta visível + votação 1a/1b/1c + clipes 9:16.'});
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

class GrowthAnalyticsScreen extends StatelessWidget {
  const GrowthAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _neonBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 Evolução de Audiência', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF38BDF8),
                    barWidth: 3.5,
                    spots: const <FlSpot>[FlSpot(1, 120), FlSpot(2, 240), FlSpot(3, 420), FlSpot(4, 645)],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreatorBusinessScreen extends StatefulWidget {
  final bool isOwner;
  const CreatorBusinessScreen({super.key, this.isOwner = false});

  @override
  State<CreatorBusinessScreen> createState() => _CreatorBusinessScreenState();
}

class _CreatorBusinessScreenState extends State<CreatorBusinessScreen> {
  final List<Map<String, dynamic>> _transactions = <Map<String, dynamic>>[
    {'desc': 'Presentes & Apoios Diretos', 'amount': 145.50, 'type': 'Receita'},
    {'desc': 'Parceria Patrocinador Gaming', 'amount': 250.00, 'type': 'Receita'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _neonBox(),
      child: ListView(
        children: [
          const Text('💰 Finanças do Criador', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF38BDF8))),
          ..._transactions.map((t) => ListTile(
                dense: true,
                title: Text(t['desc']),
                trailing: Text('+${(t['amount'] as num).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }
}

class HellInfoHubScreen extends StatefulWidget {
  const HellInfoHubScreen({super.key});

  @override
  State<HellInfoHubScreen> createState() => _HellInfoHubScreenState();
}

class _HellInfoHubScreenState extends State<HellInfoHubScreen> {
  final TextEditingController _botNameCtrl = TextEditingController();
  final TextEditingController _wakePhraseCtrl = TextEditingController();
  final TextEditingController _chatCtrl = TextEditingController();
  final List<Map<String, String>> _aiConversation = <Map<String, String>>[
    {'role': 'ai', 'text': 'Olá! Sou o teu Amigo HELL IA. Personaliza o meu nome, skin e cor de robô (com o H no peito esquerdo), ativa o botão flutuante ou chama-me por voz!'},
  ];

  @override
  void initState() {
    super.initState();
    _botNameCtrl.text = HellVirtualFriendController.botName.value;
    _wakePhraseCtrl.text = HellVirtualFriendController.wakePhrase.value;
  }

  @override
  void dispose() {
    _botNameCtrl.dispose();
    _wakePhraseCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skins = <Map<String, String>>[
      {'id': 'cyber_guardian', 'name': 'Cyber Guardian'},
      {'id': 'aero_orb', 'name': 'Aero Orb'},
      {'id': 'mecha_titan', 'name': 'Mecha Titan'},
      {'id': 'classic_bot', 'name': 'Bot Clássico'},
    ];
    final colors = <Color>[const Color(0xFF38BDF8), const Color(0xFF10B981), const Color(0xFFA855F7), const Color(0xFFF59E0B), const Color(0xFFF43F5E)];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            tabs: [Tab(text: '🤖 Amigo HELL IA'), Tab(text: '🎨 Skin & Voz IA'), Tab(text: '📄 Documentos Oficiais')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _neonBox(),
                      child: Column(
                        children: [
                          HellFriendRobotAvatar(
                            skinId: HellVirtualFriendController.skinId.value,
                            primaryColor: HellVirtualFriendController.primaryColor.value,
                            eyeColor: HellVirtualFriendController.eyeColor.value,
                            size: 84,
                          ),
                          const SizedBox(height: 8),
                          Text(HellVirtualFriendController.botName.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF38BDF8))),
                          const SizedBox(height: 8),
                          ..._aiConversation.map((m) => ListTile(dense: true, title: Text(m['text'] ?? '', style: const TextStyle(fontSize: 12.5)))),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: _chatCtrl, decoration: const InputDecoration(hintText: 'Pede piada, rádio, tempo ou alarme...', isDense: true))),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                                onPressed: () async {
                                  final q = _chatCtrl.text.trim();
                                  if (q.isEmpty) return;
                                  _chatCtrl.clear();
                                  final ans = await HellVirtualFriendController.processPrompt(q);
                                  setState(() {
                                    _aiConversation.add({'role': 'user', 'text': q});
                                    _aiConversation.add({'role': 'ai', 'text': ans});
                                  });
                                },
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _botNameCtrl,
                            decoration: const InputDecoration(labelText: 'Nome do Amigo IA', isDense: true),
                            onChanged: (v) async {
                              HellVirtualFriendController.botName.value = v.trim().isEmpty ? 'Amigo HELL IA' : v.trim();
                              await HellVirtualFriendController.savePrefs();
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _wakePhraseCtrl,
                            decoration: const InputDecoration(labelText: 'Frase de Ativação por Voz', isDense: true),
                            onChanged: (v) async {
                              HellVirtualFriendController.wakePhrase.value = v.trim().isEmpty ? 'Olá Amigo HELL' : v.trim();
                              await HellVirtualFriendController.savePrefs();
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: skins
                                .map((s) => ChoiceChip(
                                      label: Text(s['name']!),
                                      selected: HellVirtualFriendController.skinId.value == s['id'],
                                      onSelected: (_) async {
                                        HellVirtualFriendController.skinId.value = s['id']!;
                                        await HellVirtualFriendController.savePrefs();
                                        setState(() {});
                                      },
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: colors
                                .map((c) => GestureDetector(
                                      onTap: () async {
                                        HellVirtualFriendController.primaryColor.value = c;
                                        HellVirtualFriendController.eyeColor.value = c;
                                        await HellVirtualFriendController.savePrefs();
                                        setState(() {});
                                      },
                                      child: CircleAvatar(radius: 14, backgroundColor: c),
                                    ))
                                .toList(),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Botão Flutuante num canto da tela'),
                            value: HellVirtualFriendController.floatingBubbleEnabled.value,
                            onChanged: (v) async {
                              HellVirtualFriendController.floatingBubbleEnabled.value = v;
                              await HellVirtualFriendController.savePrefs();
                              setState(() {});
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Ativação por Voz (Frase / Nome)'),
                            value: HellVirtualFriendController.voiceWakeEnabled.value,
                            onChanged: (v) async {
                              HellVirtualFriendController.voiceWakeEnabled.value = v;
                              await HellVirtualFriendController.savePrefs();
                              setState(() {});
                            },
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
                      child: const Text(
                        'HELL CREATOR OS — DOCUMENTO OFICIAL & TERMOS\n\n'
                        'O sistema operativo HELL CREATOR OS (apresentado na app como HELL CREATOR) garante acesso gratuito às ferramentas base de transmissão. Assinantes VIP têm acesso ao estúdio comercial (com retenção de 30% pela plataforma nas vendas digitais) e loja pessoal de merchandising.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
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

