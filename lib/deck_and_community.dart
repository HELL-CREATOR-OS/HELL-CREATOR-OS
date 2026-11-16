import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_data.dart';
import 'account_security.dart';

class StreamDeckButtonModel {
  final String id;
  final String label;
  final IconData icon;
  bool isActive;

  StreamDeckButtonModel({
    required this.id,
    required this.label,
    required this.icon,
    this.isActive = false,
  });
}

class StreamDeckScreen extends StatefulWidget {
  final Function(String actionId, String label) onDeckActionTriggered;

  const StreamDeckScreen({
    super.key,
    required this.onDeckActionTriggered,
  });

  @override
  State<StreamDeckScreen> createState() => _StreamDeckScreenState();
}

class _StreamDeckScreenState extends State<StreamDeckScreen> {
  int _columns = 5; // Opção entre 4x e 5x

  final List<StreamDeckButtonModel> _buttons = [
    StreamDeckButtonModel(id: 'obs_scene_game', label: 'Cena Jogo', icon: Icons.sports_esports_rounded, isActive: true),
    StreamDeckButtonModel(id: 'obs_scene_chat', label: 'Cena Chat', icon: Icons.forum_rounded),
    StreamDeckButtonModel(id: 'obs_scene_brb', label: 'Volto Já', icon: Icons.pause_circle_filled_rounded),
    StreamDeckButtonModel(id: 'voice_mute', label: 'Silenciar Voz', icon: Icons.volume_off_rounded),
    StreamDeckButtonModel(id: 'gaming_mode', label: 'Gaming Mode', icon: Icons.visibility_off_rounded),
    StreamDeckButtonModel(id: 'trigger_wheel', label: 'Roleta 3D', icon: Icons.casino_rounded),
    StreamDeckButtonModel(id: 'show_podium', label: 'Pódio Top', icon: Icons.emoji_events_rounded),
    StreamDeckButtonModel(id: 'show_credits', label: 'Créditos Live', icon: Icons.movie_filter_rounded),
    StreamDeckButtonModel(id: 'sfx_applause', label: 'Som Aplausos', icon: Icons.celebration_rounded),
    StreamDeckButtonModel(id: 'sfx_raid', label: 'Alerta Raid', icon: Icons.flash_on_rounded),
    StreamDeckButtonModel(id: 'clip_mark', label: 'Marcar Clip', icon: Icons.content_cut_rounded),
    StreamDeckButtonModel(id: 'clear_alerts', label: 'Limpar Fila', icon: Icons.cleaning_services_rounded),
    StreamDeckButtonModel(id: 'mic_mute', label: 'Mutar Mic OBS', icon: Icons.mic_off_rounded),
    StreamDeckButtonModel(id: 'goal_bar', label: 'Barra Meta', icon: Icons.trending_up_rounded),
    StreamDeckButtonModel(id: 'end_stream', label: 'Fechar Live', icon: Icons.stop_circle_rounded),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HellTheme.bgDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: HellTheme.neonBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'HELL STREAM DECK (PAISAGEM)',
                style: TextStyle(
                  color: HellTheme.textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: HellTheme.cardElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HellTheme.neonBlue.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _gridOptionChip('4x', 4),
                    _gridOptionChip('5x', 5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              itemCount: _buttons.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: _columns == 5 ? 1.45 : 1.65,
              ),
              itemBuilder: (context, index) {
                final btn = _buttons[index];
                return GestureDetector(
                  onTap: () {
                    setState(() => btn.isActive = !btn.isActive);
                    widget.onDeckActionTriggered(btn.id, btn.label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: HellTheme.neonCard(
                      borderColor: HellTheme.neonBlue,
                      isActiveGreen: btn.isActive,
                      radius: 14,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: btn.isActive
                                  ? HellTheme.neonGreen
                                  : HellTheme.neonBlue.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                btn.icon,
                                color: btn.isActive ? HellTheme.neonGreen : HellTheme.neonBlue,
                                size: 26,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                btn.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: HellTheme.textWhite,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _gridOptionChip(String label, int cols) {
    final selected = _columns == cols;
    return GestureDetector(
      onTap: () => setState(() => _columns = cols),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? HellTheme.neonBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HellTheme.bgDark : HellTheme.textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
class CommunityAndPlansView extends StatefulWidget {
  final HellUserSession currentUser;

  const CommunityAndPlansView({
    super.key,
    required this.currentUser,
  });

  @override
  State<CommunityAndPlansView> createState() => _CommunityAndPlansViewState();
}

class _CommunityAndPlansViewState extends State<CommunityAndPlansView>
    with SingleTickerProviderStateMixin {
  late AnimationController _globeCtrl;
  String _generatedVipKey = '';
  bool _vipTrialActivated = false;

  static const String _nasaEarthTextureUrl =
      'https://nasa.gov';

  @override
  void initState() {
    super.initState();
    _globeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    super.dispose();
  }

  void _generateVipKey() {
    final code = 'HELL-VIP-${1000 + math.Random().nextInt(9000)}';
    setState(() => _generatedVipKey = code);
  }

  @override
  Widget build(BuildContext context) {
    final hasFreeAccess = widget.currentUser.hasFullFreeAccess;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _kpiBox('Seguidores', '14.820', Icons.people_alt_rounded),
            const SizedBox(width: 8),
            _kpiBox('Membros VIP', '342', Icons.workspace_premium_rounded),
            const SizedBox(width: 8),
            _kpiBox('Equipa STAFF', '6', Icons.shield_rounded),
          ],
        ),
        const SizedBox(height: 16),

        // Globo Terrestre Real da NASA com Missões Coletivas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GLOBO REAL NASA • MISSÕES DA COMUNIDADE',
                    style: TextStyle(
                      color: HellTheme.neonBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Icon(Icons.public_rounded, color: HellTheme.neonGreen, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              _buildRealNasaEarthGlobe(),
              const SizedBox(height: 14),
              const Text(
                'Missão Coletiva Ativa: 500 Rosas para desbloquear Especial 4 Horas',
                textAlign: TextAlign.center,
                style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  value: 0.74,
                  minHeight: 10,
                  backgroundColor: HellTheme.cardElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(HellTheme.neonBlue),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '370 / 500 concluído (74%) • Comunidade Global Conectada',
                style: TextStyle(color: HellTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gerador de Chaves VIP & Equipa STAFF
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comunidade VIP & Chaves de Acesso',
                style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gera chaves VIP para moderadores (STAFF) ou apoiantes especiais.',
                style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HellTheme.neonBlue,
                      foregroundColor: HellTheme.bgDark,
                    ),
                    onPressed: _generateVipKey,
                    icon: const Icon(Icons.vpn_key_rounded, size: 18),
                    label: const Text('Gerar Chave VIP', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  if (_generatedVipKey.isNotEmpty)
                    SelectableText(
                      _generatedVipKey,
                      style: const TextStyle(
                        color: HellTheme.neonGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Planos & Subscrições (Para Todos os Bolsos + Acesso Livre Donos/Equipa)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(isActiveGreen: hasFreeAccess),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Planos HELL CREATOR OS',
                      style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (hasFreeAccess)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: HellTheme.neonGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ACESSO GRATUITO DONO/EQUIPA',
                        style: TextStyle(color: HellTheme.bgDark, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _planTile('HELL STARTER', '0,00 € / mês', 'HELL VOICE PT-PT, Gaming Mode Invisível, Chat Unificado e Alertas Base.', true),
              _planTile('HELL CREATOR PRO', '9,99 € / mês', 'Clonagem de Voz (2 min), Automações Avançadas e Stream Deck 5x.', hasFreeAccess),
              _planTile('HELL CREATOR ELITE', '19,99 € / mês', 'IA Avançada, Content Factory e Relatórios Completos.', hasFreeAccess),
              _planTile('HELL AGENCY / STUDIO', '49,99 €+ / mês', 'Gestão Multi-Criador, Equipa STAFF e Permissões Granulares.', hasFreeAccess),
              if (!hasFreeAccess) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HellTheme.neonGreen,
                      foregroundColor: HellTheme.bgDark,
                    ),
                    onPressed: () => setState(() => _vipTrialActivated = true),
                    child: Text(
                      _vipTrialActivated
                          ? 'Teste Grátis de 3 Dias Ativo (0,00 €)'
                          : 'Ativar Estúdio VIP • 3 Dias Grátis (0,00 €)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealNasaEarthGlobe() {
    return SizedBox(
      width: 170,
      height: 170,
      child: AnimatedBuilder(
        animation: _globeCtrl,
        builder: (context, _) {
          final offsetFactor = _globeCtrl.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: HellTheme.neonBlue.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
              border: Border.all(color: HellTheme.neonBlue, width: 1.5),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FractionallySizedBox(
                    widthFactor: 2.2,
                    alignment: Alignment(-1.0 + (offsetFactor * 2.0), 0.0),
                    child: Image.network(
                      _nasaEarthTextureUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF03152E)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.public_rounded, color: HellTheme.neonBlue, size: 90),
                        ),
                      ),
                    ),
                  ),
                        
