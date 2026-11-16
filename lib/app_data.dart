import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class HellTheme {
  static const Color bgDark = Color(0xFF050811);
  static const Color cardDark = Color(0xFF0B1222);
  static const Color cardElevated = Color(0xFF101A30);
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF2979FF);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonRed = Color(0xFFFF1744);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8E9BB5);

  static BoxDecoration neonCard({
    Color borderColor = neonBlue,
    bool isActiveGreen = false,
    double radius = 16,
  }) {
    final activeColor = isActiveGreen ? neonGreen : borderColor;
    return BoxDecoration(
      color: isActiveGreen ? neonGreen.withValues(alpha: 0.12) : cardDark,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: activeColor.withValues(alpha: isActiveGreen ? 0.9 : 0.45),
        width: isActiveGreen ? 1.8 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: activeColor.withValues(alpha: isActiveGreen ? 0.28 : 0.12),
          blurRadius: isActiveGreen ? 16 : 10,
          spreadRadius: 1,
        ),
      ],
    );
  }
}

class HellAppInfo {
  static const String appName = 'HELL CREATOR OS';
  static const String slogan = 'One Creator. Every Platform. Total Control.';
  static const String subSlogan = 'Your Creator World. Under Control.';
  static const String supportEmail = 'hellcreatoros@gmail.com';
  static const List<String> owners = [
    'hellcreatoros@gmail.com',
    'hellgamer2026@gmail.com',
    'heldermsf_@hotmail.com',
  ];
}

class GiftItemHD {
  final String id;
  final String name;
  final double euroValue;
  final int coins;
  final IconData icon;
  final Color glowColor;
  final String soundId;

  const GiftItemHD({
    required this.id,
    required this.name,
    required this.euroValue,
    required this.coins,
    required this.icon,
    required this.glowColor,
    required this.soundId,
  });
}

class OnlineSoundItem {
  final String id;
  final String title;
  final String category;
  final String url;

  const OnlineSoundItem({
    required this.id,
    required this.title,
    required this.category,
    required this.url,
  });
}

class HellAudioEngine {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playUrl(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}

class HellLocaleManager {
  static String currentLocale = 'pt-PT';

  static const Map<String, Map<String, String>> supportedLanguages = {
    'pt-PT': {'name': 'Português (Portugal)', 'flag': '🇵🇹', 'tts': 'pt-PT'},
    'pt-BR': {'name': 'Português (Brasil)', 'flag': '🇧🇷', 'tts': 'pt-BR'},
    'en-US': {'name': 'English (Global)', 'flag': '🇬🇧', 'tts': 'en-US'},
    'es-ES': {'name': 'Español', 'flag': '🇪🇸', 'tts': 'es-ES'},
    'fr-FR': {'name': 'Français', 'flag': '🇫🇷', 'tts': 'fr-FR'},
  };

  static const Map<String, Map<String, String>> _translations = {
    'pt-PT': {
      'choose_lang': 'Escolhe o Idioma do Sistema',
      'continue_btn': 'Continuar em Português (PT)',
      'tab_command': 'Comando',
      'tab_voice': 'HELL Voice',
      'tab_deck': 'Stream Deck',
      'tab_studio': 'Estúdio',
      'tab_community': 'Comunidade',
      'tab_more': 'Mais',
      'gaming_active': 'GAMING MODE • ECRÃ LIMPO (SÓ ÁUDIO)',
      'welcome_back': 'Bem-vindo de volta',
      'login_google': 'Continuar com Google (1 Clique)',
      'login_sms': 'Entrar com SMS / Telemóvel',
      'create_account': 'Criar Conta com Email e PIN',
    },
    'pt-BR': {
      'choose_lang': 'Escolha o Idioma do Sistema',
      'continue_btn': 'Continuar em Português (BR)',
      'tab_command': 'Comando',
      'tab_voice': 'HELL Voice',
      'tab_deck': 'Stream Deck',
      'tab_studio': 'Estúdio',
      'tab_community': 'Comunidade',
      'tab_more': 'Mais',
      'gaming_active': 'MODO JOGO • TELA LIMPA (SÓ ÁUDIO)',
      'welcome_back': 'Bem-vindo de volta',
      'login_google': 'Continuar com Google (1 Clique)',
      'login_sms': 'Entrar com SMS / Celular',
      'create_account': 'Criar Conta com Email e PIN',
    },
    'en-US': {
      'choose_lang': 'Choose System Language',
      'continue_btn': 'Continue in English',
      'tab_command': 'Command',
      'tab_voice': 'HELL Voice',
      'tab_deck': 'Stream Deck',
      'tab_studio': 'Studio',
      'tab_community': 'Community',
      'tab_more': 'More',
      'gaming_active': 'GAMING MODE • CLEAN SCREEN (AUDIO ONLY)',
      'welcome_back': 'Welcome back',
      'login_google': 'Continue with Google (1-Click)',
      'login_sms': 'Sign in with SMS / Phone',
      'create_account': 'Create Account with Email & PIN',
    },
    'es-ES': {
      'choose_lang': 'Elige el Idioma del Sistema',
      'continue_btn': 'Continuar en Español',
      'tab_command': 'Comando',
      'tab_voice': 'HELL Voice',
      'tab_deck': 'Stream Deck',
      'tab_studio': 'Estudio',
      'tab_community': 'Comunidad',
      'tab_more': 'Más',
      'gaming_active': 'MODO JUEGO • PANTALLA LIMPIA (SOLO AUDIO)',
      'welcome_back': 'Bienvenido de nuevo',
      'login_google': 'Continuar con Google (1 Clic)',
      'login_sms': 'Entrar con SMS / Móvil',
      'create_account': 'Crear Cuenta con Email y PIN',
    },
    'fr-FR': {
      'choose_lang': 'Choisissez la Langue du Système',
      'continue_btn': 'Continuer en Français',
      'tab_command': 'Commande',
      'tab_voice': 'HELL Voice',
      'tab_deck': 'Stream Deck',
      'tab_studio': 'Studio',
      'tab_community': 'Communauté',
      'tab_more': 'Plus',
      'gaming_active': 'MODE JEU • ÉCRAN ÉPURÉ (AUDIO SEUL)',
      'welcome_back': 'Bon retour',
      'login_google': 'Continuer avec Google (1 Clic)',
      'login_sms': 'Connexion par SMS / Mobile',
      'create_account': 'Créer un Compte Email & PIN',
    },
  };

  static String t(String key) {
    return _translations[currentLocale]?[key] ??
        _translations['pt-PT']?[key] ??
        key;
  }

  static String get activeTtsLocale =>
      supportedLanguages[currentLocale]?['tts'] ?? 'pt-PT';
}
class HellBrandIcon extends StatelessWidget {
  final double size;
  final bool showGlow;

  const HellBrandIcon({
    super.key,
    this.size = 64,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF102244),
            Color(0xFF050811),
          ],
        ),
        border: Border.all(
          color: HellTheme.neonBlue,
          width: size * 0.048,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: HellTheme.neonBlue.withValues(alpha: 0.72),
                  blurRadius: size * 0.38,
                  spreadRadius: size * 0.05,
                ),
                BoxShadow(
                  color: HellTheme.electricBlue.withValues(alpha: 0.45),
                  blurRadius: size * 0.60,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Image.asset(
          'icon.png',
          width: size * 0.76,
          height: size * 0.76,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Text(
            'H',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.58,
              fontWeight: FontWeight.w900,
              height: 1.0,
              shadows: [
                Shadow(color: HellTheme.neonBlue, blurRadius: size * 0.28),
                Shadow(color: HellTheme.electricBlue, blurRadius: size * 0.45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppData {
  static const List<String> soundCategories = [
    'Todos',
    'Alertas Néon',
    'Rosas & Presentes',
    'Doações & Moedas',
    'Subscrições & VIP',
    'Raids & Épico',
    'Gaming & Retro',
    'Avisos Críticos',
  ];

  static const List<OnlineSoundItem> onlineSoundLibrary = [
    OnlineSoundItem(
      id: 'neon_ping',
      title: 'Pulso Néon Cristal',
      category: 'Alertas Néon',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'cyber_chime',
      title: 'Notificação Cibernética',
      category: 'Alertas Néon',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'rose_sparkle',
      title: 'Brilho Mágico de Rosa',
      category: 'Rosas & Presentes',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'gift_box',
      title: 'Presente Especial Surpresa',
      category: 'Rosas & Presentes',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'coin_euro',
      title: 'Moeda de Ouro & Euro HD',
      category: 'Doações & Moedas',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'cash_register',
      title: 'Doação Confirmada',
      category: 'Doações & Moedas',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'vip_fanfare',
      title: 'Fanfarra Membro VIP',
      category: 'Subscrições & VIP',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'level_up_sub',
      title: 'Subscrição Nível Acima',
      category: 'Subscrições & VIP',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'raid_horn',
      title: 'Entrada Épica de Raid',
      category: 'Raids & Épico',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'victory_synth',
      title: 'Vitória Synthwave HELL',
      category: 'Gaming & Retro',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'arcade_power',
      title: 'Power-Up Arcade',
      category: 'Gaming & Retro',
      url: 'https://mixkit.co',
    ),
    OnlineSoundItem(
      id: 'critical_disconnect',
      title: 'Alerta Crítico de Ligação',
      category: 'Avisos Críticos',
      url: 'https://mixkit.co',
    ),
  ];

  static const List<GiftItemHD> hdGifts = [
    GiftItemHD(id: 'rosa', name: 'Rosa Néon', euroValue: 0.05, coins: 1, icon: Icons.local_florist_rounded, glowColor: Color(0xFFFF4081), soundId: 'rose_sparkle'),
    GiftItemHD(id: 'coracao', name: 'Coração Cibernético', euroValue: 0.50, coins: 10, icon: Icons.favorite_rounded, glowColor: Color(0xFFFF1744), soundId: 'cyber_chime'),
    GiftItemHD(id: 'gg', name: 'Troféu GG', euroValue: 1.00, coins: 20, icon: Icons.emoji_events_rounded, glowColor: Color(0xFFFFD740), soundId: 'coin_euro'),
    GiftItemHD(id: 'foguete', name: 'Foguetão Orbital', euroValue: 5.00, coins: 100, icon: Icons.rocket_launch_rounded, glowColor: Color(0xFF00E5FF), soundId: 'vip_fanfare'),
    GiftItemHD(id: 'coroa', name: 'Coroa Suprema HELL', euroValue: 15.00, coins: 300, icon: Icons.workspace_premium_rounded, glowColor: Color(0xFF7C4DFF), soundId: 'level_up_sub'),
    GiftItemHD(id: 'leao', name: 'Leão Galáctico 3D', euroValue: 50.00, coins: 1000, icon: Icons.auto_awesome_rounded, glowColor: Color(0xFFFF9100), soundId: 'raid_horn'),
    GiftItemHD(id: 'universo', name: 'Universo HELL OS', euroValue: 100.00, coins: 2500, icon: Icons.public_rounded, glowColor: Color(0xFF00E676), soundId: 'victory_synth'),
  ];

  static String formatEuroSpeech(double amount) {
    if (amount <= 0) return 'zero euros';
    final euros = amount.floor();
    final centimos = ((amount - euros) * 100).round();

    String euroPart = '';
    if (euros == 1) {
      euroPart = 'um euro';
    } else if (euros > 1) {
      euroPart = '$euros euros';
    }

    String centPart = '';
    if (centimos == 1) {
      centPart = 'um cêntimo';
    } else if (centimos > 1) {
      centPart = '$centimos cêntimos';
    }

    if (euroPart.isNotEmpty && centPart.isNotEmpty) {
      return '$euroPart e $centPart';
    }
    return euroPart.isNotEmpty ? euroPart : centPart;
  }

  static const String voiceCloningScript2Min = '''
[0:00 - 0:25 | Tom Calmo e Natural]
Olá! Esta é a minha amostra oficial de voz para o HELL Creator OS. Estou a gravar este texto num ambiente tranquilo, falando de forma clara, natural e sem pressas, para que a inteligência artificial consiga captar cada detalhe do meu timbre, o meu ritmo de respiração e a minha pronúncia em português de Portugal. A partir de hoje, esta voz vai acompanhar todas as minhas transmissões em direto.

[0:25 - 0:50 | Entusiasmo e Celebração de Live]
Uau! Olha só quem acabou de chegar à live! Muito obrigado pelo apoio incrível, pessoal! Vocês são mesmo os melhores do mundo! Ena, pá, caiu uma chuva de rosas no ecrã! Que loucura absoluta! Assim vale mesmo a pena entrar em direto todos os dias. Vamos partir isto tudo e bater o nosso recorde de hoje!

[0:50 - 1:15 | Perguntas e Interação com o Chat]
Espera aí... viste aquela jogada mesmo agora? Como é que eu sobrevivi àquilo com apenas um ponto de vida? Digam-me lá no chat o que acharam desta estratégia! Será que arriscamos ir pelo meio ou esperamos pelo próximo círculo? Vocês é que mandam aqui no canal, por isso deixem a vossa opinião!

[1:15 - 1:40 | Foco Competitivo e Alertas Críticos]
Atenção máxima agora. Silêncio na equipa, ouvidos bem abertos porque estamos na reta final da partida. Cuidado à esquerda, temos movimento perto da zona segura. Aviso importante do sistema: a ligação da plataforma sofreu uma pequena falha, mas já estamos a recuperar o sinal.

[1:40 - 2:00 | Expressões Típicas e Fecho]
Bora lá, malta! Não há pai para nós hoje! Se correr bem, festejamos todos juntos; se correr mal, fazemos de conta que ninguém viu e tentamos outra vez! Obrigado por estarem desse lado a apoiar o projeto. Calibração concluída com sucesso. Estamos prontos para entrar no ar!
''';

  static const List<String> defaultCatchphrases = [
    'Bora lá, malta!',
    'Ena, pá, que apoio brutal!',
    'Não há pai para nós hoje!',
    'Obrigado pela força na live!',
  ];
}
