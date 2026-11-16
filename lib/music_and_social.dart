import 'package:flutter/material.dart';
import 'app_data.dart';

class MusicBusinessAndHelpView extends StatefulWidget {
  final Function(String speechText) onSpeakAlert;

  const MusicBusinessAndHelpView({
    super.key,
    required this.onSpeakAlert,
  });

  @override
  State<MusicBusinessAndHelpView> createState() => _MusicBusinessAndHelpViewState();
}

class _MusicBusinessAndHelpViewState extends State<MusicBusinessAndHelpView> {
  int _section = 0; // 0 = Música Embutida, 1 = Creator Business, 2 = Sobre Nós & Ajuda IA (Robô)

  String _activeMusicSource = 'HELL Lo-Fi Gaming Radio';
  bool _isPlayingMusic = false;
  double _musicVolume = 0.65;

  final TextEditingController _aiInputCtrl = TextEditingController();
  final List<Map<String, String>> _aiMessages = [
    {
      'sender': 'bot',
      'text': 'Olá! Sou o Assistente IA do HELL CREATOR OS. Como posso ajudar na tua live hoje?',
    },
  ];

  int _infoBottomTab = 0; // 0 = FAQ & Sobre, 1 = Assistente IA (Robô), 2 = Suporte

  void _sendAiMessage(String query) {
    final text = query.trim();
    if (text.isEmpty) return;

    setState(() {
      _aiMessages.add({'sender': 'user', 'text': text});
      _aiInputCtrl.clear();

      String reply;
      final q = text.toLowerCase();
      if (q.contains('voz') || q.contains('clonar')) {
        reply = 'Para clonar a tua voz em PT-PT, vai à aba HELL Voice e lê o guião oficial de 2 minutos. Depois podes aplicar efeitos e expressões típicas!';
      } else if (q.contains('gaming') || q.contains('segundo plano')) {
        reply = 'Ativa o Gaming Mode no topo: o ecrã fica 100% limpo sem distrações e recebes apenas voz e sons de alerta nos auriculares.';
      } else if (q.contains('stream deck') || q.contains('paisagem')) {
        reply = 'Ao abrir o Stream Deck, o ecrã roda automaticamente para paisagem e podes alternar entre grelha 4x e 5x.';
      } else {
        reply = 'Analisei o teu ecossistema HELL CREATOR OS: tens o motor PT-PT ativo, a biblioteca sonora online pronta e todas as plataformas sincronizadas!';
      }
      _aiMessages.add({'sender': 'bot', 'text': reply});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(child: _topPill('Música In-App', 0)),
              const SizedBox(width: 6),
              Expanded(child: _topPill('Business & €', 1)),
              const SizedBox(width: 6),
              Expanded(child: _topPill('Sobre & IA', 2)),
            ],
          ),
        ),
        Expanded(
          child: _section == 0
              ? _buildEmbeddedMusicPlayer()
              : _section == 1
                  ? _buildCreatorBusiness()
                  : _buildAboutAndRobotHelp(),
        ),
      ],
    );
  }

  Widget _topPill(String title, int index) {
    final selected = _section == index;
    return GestureDetector(
      onTap: () => setState(() => _section = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: HellTheme.neonCard(radius: 10).copyWith(
          color: selected ? HellTheme.neonBlue : HellTheme.cardDark,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? HellTheme.bgDark : HellTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedMusicPlayer() {
    final tracks = [
      {
        'title': 'HELL Lo-Fi Gaming Radio (Sem Copyright)',
        'source': 'Canal Interno HELL',
        'url': 'https://mixkit.co',
      },
      {
        'title': 'Synthwave Néon Focus 2026',
        'source': 'Player Integrado',
        'url': 'https://mixkit.co',
      },
      {
        'title': 'YouTube Music Stream Embed (In-App)',
        'source': 'Sessão Embutida',
        'url': 'https://mixkit.co',
      },
      {
        'title': 'Spotify Playlist Criador (In-App)',
        'source': 'Sessão Embutida',
        'url': 'https://mixkit.co',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: HellTheme.neonCard(isActiveGreen: _isPlayingMusic),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: HellTheme.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: HellTheme.neonBlue),
                    ),
                    child: Icon(
                      _isPlayingMusic ? Icons.equalizer_rounded : Icons.music_note_rounded,
                      color: _isPlayingMusic ? HellTheme.neonGreen : HellTheme.neonBlue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LEITOR EMBUTIDO (SEM SAIR DA APP)',
                          style: TextStyle(color: HellTheme.neonBlue, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _activeMusicSource,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _isPlayingMusic ? 'A reproduzir dentro do HELL CREATOR OS' : 'Em pausa • Pronto a tocar',
                          style: const TextStyle(color: HellTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 40,
                    color: _isPlayingMusic ? HellTheme.neonGreen : HellTheme.neonBlue,
                    icon: Icon(_isPlayingMusic ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                    onPressed: () {
                      setState(() => _isPlayingMusic = !_isPlayingMusic);
                      if (!_isPlayingMusic) HellAudioEngine.stop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: HellTheme.textMuted, size: 18),
                  Expanded(
                    child: Slider(
                      value: _musicVolume,
                      activeColor: HellTheme.neonBlue,
                      onChanged: (v) => setState(() => _musicVolume = v),
                    ),
                  ),
                  Text('${(_musicVolume * 100).round()}%', style: const TextStyle(color: HellTheme.textWhite, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Fontes de Áudio Integradas (Não abre apps externas)',
          style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...tracks.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: HellTheme.neonCard(radius: 12),
              child: ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: HellTheme.neonBlue),
                title: Text(t['title']!, style: const TextStyle(color: HellTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(t['source']!, style: const TextStyle(color: HellTheme.textMuted, fontSize: 11)),
                onTap: () {
                  setState(() {
                    _activeMusicSource = t['title']!;
                    _isPlayingMusic = true;
                  });
                  HellAudioEngine.playUrl(t['url']!);
                },
              ),
            )),
      ],
    );
  }
  Widget _buildCreatorBusiness() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CREATOR BUSINESS • FINANÇAS & DOAÇÕES',
                style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '1.485,50 €',
                style: TextStyle(color: HellTheme.neonGreen, fontWeight: FontWeight.w900, fontSize: 28),
              ),
              const Text(
                'Saldo acumulado (Doações /donate, Presentes e Subscrições)',
                style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HellTheme.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HellTheme.neonBlue.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: HellTheme.neonBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'hellcreator.os/donate (MB WAY, PayPal, Cartão, Apple/Google Pay)',
                        style: TextStyle(color: HellTheme.textWhite, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Testar Leitura Natural de Euros',
                      icon: const Icon(Icons.record_voice_over_rounded, color: HellTheme.neonGreen),
                      onPressed: () => widget.onSpeakAlert(
                        'Nova doação recebida no valor de ${AppData.formatEuroSpeech(25.50)}! Muito obrigado pelo apoio!',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: HellTheme.neonCard(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestão Profissional & Agências', style: TextStyle(color: HellTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 8),
              Text('• Patrocinadores & Contratos Ativos: 3 campanhas em curso', style: TextStyle(color: HellTheme.textMuted, fontSize: 12)),
              SizedBox(height: 4),
              Text('• Despesas de Equipamento / Software: 49,90 € este mês', style: TextStyle(color: HellTheme.textMuted, fontSize: 12)),
              SizedBox(height: 4),
              Text('• Agency Dashboard: Gestão multi-criador e permissões STAFF', style: TextStyle(color: HellTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutAndRobotHelp() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: HellTheme.neonCard(radius: 10),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_rounded, color: HellTheme.neonBlue, size: 16),
              SizedBox(width: 8),
              SelectableText(
                'Contacto Oficial: ${HellAppInfo.supportEmail}',
                style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _infoBottomTab == 0
              ? _buildAboutContent()
              : _infoBottomTab == 1
                  ? _buildRobotAiChat()
                  : _buildSupportTicketView(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: HellTheme.cardDark,
            border: Border(top: BorderSide(color: HellTheme.neonBlue, width: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(child: _bottomInfoBtn('FAQ & Sobre', Icons.info_outline_rounded, 0)),
              const SizedBox(width: 8),
              Expanded(child: _bottomInfoBtn('Assistente IA', Icons.smart_toy_rounded, 1)),
              const SizedBox(width: 8),
              Expanded(child: _bottomInfoBtn('Suporte', Icons.support_agent_rounded, 2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomInfoBtn(String label, IconData icon, int tab) {
    final active = _infoBottomTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _infoBottomTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? HellTheme.neonBlue.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? HellTheme.neonBlue : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? HellTheme.neonBlue : HellTheme.textMuted, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? HellTheme.textWhite : HellTheme.textMuted,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: HellTheme.neonCard(),
          child: const Column(
            children: [
              HellBrandIcon(size: 56),
              SizedBox(height: 10),
              Text(
                'HELL CREATOR OS',
                style: TextStyle(
                  color: HellTheme.textWhite,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'ONE CREATOR. EVERY PLATFORM. TOTAL CONTROL.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HellTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              Text(
                'Um ecossistema completo para streamers, criadores de conteúdo e profissionais digitais.\n\n'
                'Não precisas de ter um estúdio profissional para ter ferramentas profissionais. O HELL CREATOR OS funciona mesmo que tenhas apenas um telemóvel ou portátil, acompanhando-te por voz natural (HELL VOICE) em Web, Android e Windows, com expansão futura para o ecossistema Apple.\n\n'
                '• Plataformas: TikTok LIVE, Twitch, YouTube LIVE e Kick\n'
                '• Para iniciantes, gamers mobile/PC, criadores multiplataforma, equipas e agências.',
                style: TextStyle(color: HellTheme.textWhite, fontSize: 12.5, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRobotAiChat() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: HellTheme.neonCard(),
          child: Row(
            children: [
              _buildHellNeonRobotAvatar(),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HELL AI • AJUDA EM TEMPO REAL',
                      style: TextStyle(color: HellTheme.neonBlue, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pronto para ajudar na configuração, vozes PT-PT, Stream Deck e estratégia da live.',
                      style: TextStyle(color: HellTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _aiMessages.length,
            itemBuilder: (context, index) {
              final msg = _aiMessages[index];
              final isBot = msg['sender'] == 'bot';
              return Align(
                alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: isBot ? HellTheme.cardElevated : HellTheme.neonBlue,
                    borderRadius: BorderRadius.circular(14),
                    border: isBot ? Border.all(color: HellTheme.neonBlue.withValues(alpha: 0.5)) : null,
                  ),
                  child: Text(
