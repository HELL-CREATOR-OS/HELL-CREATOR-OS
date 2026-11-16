import 'package:flutter/material.dart';
import 'app_data.dart';

class HellLiveEvent {
  final String id;
  final String platform;
  final String type; // follow, gift, sub, raid, chat, disconnect
  final String username;
  final String message;
  final double euroValue;
  final int count;
  final DateTime timestamp;

  HellLiveEvent({
    required this.id,
    required this.platform,
    required this.type,
    required this.username,
    required this.message,
    this.euroValue = 0.0,
    this.count = 1,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class HellAutomationRule {
  final String id;
  String triggerName;
  String triggerType;
  String actionDescription;
  String assignedSoundId;
  bool enabled;

  HellAutomationRule({
    required this.id,
    required this.triggerName,
    required this.triggerType,
    required this.actionDescription,
    required this.assignedSoundId,
    this.enabled = true,
  });
}

class ActionsAndAutomationsView extends StatefulWidget {
  final List<HellLiveEvent> eventHistory;
  final Function(HellLiveEvent) onTriggerTestEvent;
  final VoidCallback onRefreshLibrary;

  const ActionsAndAutomationsView({
    super.key,
    required this.eventHistory,
    required this.onTriggerTestEvent,
    required this.onRefreshLibrary,
  });

  @override
  State<ActionsAndAutomationsView> createState() => _ActionsAndAutomationsViewState();
}

class _ActionsAndAutomationsViewState extends State<ActionsAndAutomationsView> {
  bool _refreshing = false;
  String _selectedSoundCategory = 'Todos';
  String _soundSearchQuery = '';
  String _playingSoundId = '';

  final List<HellAutomationRule> _rules = [
    HellAutomationRule(
      id: 'rule_follow',
      triggerName: 'Novo Seguidor',
      triggerType: 'follow',
      actionDescription: 'HELL VOICE anuncia o nome + Som Alerta',
      assignedSoundId: 'neon_ping',
      enabled: true,
    ),
    HellAutomationRule(
      id: 'rule_rose',
      triggerName: 'Presente / Rosa Recebida',
      triggerType: 'gift',
      actionDescription: 'Agrupar na Voice Queue + Alerta Visual na Live',
      assignedSoundId: 'rose_sparkle',
      enabled: true,
    ),
    HellAutomationRule(
      id: 'rule_sub',
      triggerName: 'Novo Membro / Subscrição',
      triggerType: 'sub',
      actionDescription: 'Voz prioritária + Fanfarra + Destaque Pódio',
      assignedSoundId: 'vip_fanfare',
      enabled: true,
    ),
    HellAutomationRule(
      id: 'rule_raid',
      triggerName: 'Raid Recebida',
      triggerType: 'raid',
      actionDescription: 'Anunciar número de viewers + Som Épico',
      assignedSoundId: 'raid_horn',
      enabled: true,
    ),
    HellAutomationRule(
      id: 'rule_disconnect',
      triggerName: 'Queda de Ligação na Live',
      triggerType: 'disconnect',
      actionDescription: 'Alerta crítico imediato nos auriculares',
      assignedSoundId: 'critical_disconnect',
      enabled: true,
    ),
  ];

  void _runRefresh() async {
    setState(() => _refreshing = true);
    widget.onRefreshLibrary();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _previewOnlineSound(OnlineSoundItem sound) async {
    setState(() => _playingSoundId = sound.id);
    await HellAudioEngine.playUrl(sound.url);
  }

  void _assignSoundToRule(OnlineSoundItem sound) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HellTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HellTheme.neonBlue),
        ),
        title: Text(
          'Associar "${sound.title}"',
          style: const TextStyle(color: HellTheme.textWhite, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _rules.map((r) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.bolt_rounded, color: HellTheme.neonGreen),
              title: Text(r.triggerName, style: const TextStyle(color: HellTheme.textWhite, fontSize: 13)),
              onTap: () {
                setState(() => r.assignedSoundId = sound.id);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final filteredSounds = AppData.onlineSoundLibrary.where((s) {
      final matchesCat = _selectedSoundCategory == 'Todos' || s.category == _selectedSoundCategory;
      final matchesQuery = _soundSearchQuery.isEmpty ||
          s.title.toLowerCase().contains(_soundSearchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'UNIVERSAL EVENT ENGINE & BIBLIOTECA SONORA',
                style: TextStyle(
                  color: HellTheme.neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar Bibliotecas Online',
              onPressed: _runRefresh,
              icon: AnimatedRotation(
                turns: _refreshing ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: const Icon(Icons.refresh_rounded, color: HellTheme.neonBlue, size: 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Simulador Rápido de Eventos (Live + HELL VOICE + Som Real)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Testar Alerta (Live + HELL VOICE + Som)',
                style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _testChip('Seguidor', Icons.person_add_rounded, () {
                    HellAudioEngine.playUrl(AppData.onlineSoundLibrary[0].url);
                    widget.onTriggerTestEvent(HellLiveEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      platform: 'TikTok',
                      type: 'follow',
                      username: 'Miguel_PT',
                      message: 'O Miguel começou a seguir-te!',
                    ));
                  }),
                  _testChip('30 Rosas', Icons.local_florist_rounded, () {
                    HellAudioEngine.playUrl(AppData.onlineSoundLibrary[2].url);
                    widget.onTriggerTestEvent(HellLiveEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      platform: 'TikTok',
                      type: 'gift',
                      username: 'Ana_Gamer',
                      count: 30,
                      euroValue: 1.50,
                      message: 'Recebeste 30 rosas de Ana_Gamer!',
                    ));
                  }),
                  _testChip('Doação 12,50 €', Icons.euro_rounded, () {
                    HellAudioEngine.playUrl(AppData.onlineSoundLibrary[4].url);
                    widget.onTriggerTestEvent(HellLiveEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      platform: 'YouTube',
                      type: 'gift',
                      username: 'Pedro_Silva',
                      euroValue: 12.50,
                      message: 'Doação de ${AppData.formatEuroSpeech(12.50)} de Pedro_Silva!',
                    ));
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Biblioteca Sonora Online com Pré-Escuta (▶)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Biblioteca Sonora Online (Ouvir e Associar)',
                style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(color: HellTheme.textWhite, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Pesquisar efeito sonoro...',
                  hintStyle: const TextStyle(color: HellTheme.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: HellTheme.neonBlue, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: HellTheme.cardElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _soundSearchQuery = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppData.soundCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final cat = AppData.soundCategories[idx];
                    final sel = cat == _selectedSoundCategory;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 11, color: sel ? HellTheme.bgDark : HellTheme.textWhite)),
                      selected: sel,
                      selectedColor: HellTheme.neonBlue,
                      backgroundColor: HellTheme.cardElevated,
                      onSelected: (_) => setState(() => _selectedSoundCategory = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ...filteredSounds.map((sound) {
                final isPlaying = _playingSoundId == sound.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HellTheme.cardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPlaying ? HellTheme.neonGreen : HellTheme.neonBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                          color: isPlaying ? HellTheme.neonGreen : HellTheme.neonBlue,
                        ),
                        onPressed: () => _previewOnlineSound(sound),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sound.title, style: const TextStyle(color: HellTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(sound.category, style: const TextStyle(color: HellTheme.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _assignSoundToRule(sound),
                        child: const Text('Associar', style: TextStyle(color: HellTheme.neonBlue, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Regras Automáticas ("Quando acontecer X -> Faz Y")
        const Text(
          'Regras Automáticas Ativas',
          style: TextStyle(color: HellTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._rules.map((rule) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: HellTheme.neonCard(isActiveGreen: rule.enabled),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QUANDO: ${rule.triggerName}', style: const TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('FAZ: ${rule.actionDescription}', style: const TextStyle(color: HellTheme.neonBlue, fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    activeColor: HellTheme.neonGreen,
                    onChanged: (val) => setState(() => rule.enabled = val),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _testChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, color: HellTheme.bgDark, size: 15),
      label: Text(label, style: const TextStyle(color: HellTheme.bgDark, fontWeight: FontWeight.bold, fontSize: 11)),
      backgroundColor: HellTheme.neonBlue,
      onPressed: onTap,
    );
  }
}
