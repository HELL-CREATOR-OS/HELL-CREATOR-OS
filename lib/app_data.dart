class AppTranslations {
  static String t(String lang, String key) {
    final map = {
      'pt': {
        'automations': 'HELL Automações',
        'control_center': 'Centro de Controlo',
        'hell_voice': 'HELL Voz / Chat TTS',
        'game_mode': 'HELL Modo de Jogo',
        'second_screen': 'HELL Segundo Ecrã & Stream Deck Pro',
        'music': 'Música',
        'smart_brain': 'HELL Gestão IA',
        'content_factory': 'HELL Fábrica de Conteúdos',
        'community': 'HELL Comunidade',
        'growth': 'HELL Crescimento e Negócio',
        'business': 'HELL Gestão do Negócio',
        'plugins_market': 'HELL Plugins & Market Place',
        'info_hub': 'HELL Informações',
        'settings': 'Definições',
      },
      'en': {
        'automations': 'HELL Automations',
        'control_center': 'Control Center',
        'hell_voice': 'HELL Voice / Chat TTS',
        'game_mode': 'HELL Game Mode',
        'second_screen': 'HELL 2nd Screen & Stream Deck Pro',
        'music': 'Music',
        'smart_brain': 'HELL AI Management',
        'content_factory': 'HELL Content Factory',
        'community': 'HELL Community',
        'growth': 'HELL Growth & Analytics',
        'business': 'HELL Business Management',
        'plugins_market': 'HELL Plugins & Market Place',
        'info_hub': 'HELL Information',
        'settings': 'Settings',
      },
      'es': {
        'automations': 'HELL Automatizaciones',
        'control_center': 'Centro de Control',
        'hell_voice': 'HELL Voz / Chat TTS',
        'game_mode': 'HELL Modo Juego',
        'second_screen': 'HELL 2ª Pantalla y Stream Deck Pro',
        'music': 'Música',
        'smart_brain': 'HELL Gestión IA',
        'content_factory': 'HELL Fábrica de Contenidos',
        'community': 'HELL Comunidad',
        'growth': 'HELL Crecimiento y Negocio',
        'business': 'HELL Gestión de Negocio',
        'plugins_market': 'HELL Plugins y Market Place',
        'info_hub': 'HELL Información',
        'settings': 'Ajustes',
      },
    };
    return map[lang]?[key] ?? map['pt']![key] ?? key;
  }

  static String formatEuroNaturalPt(double value) {
    final euros = value.floor();
    final cents = ((value - euros) * 100).round();
    final euroPart = euros == 1 ? 'um euro' : '$euros euros';
    if (cents == 0) return euroPart;
    final centPart = cents == 1 ? 'um cêntimo' : '$cents cêntimos';
    return '$euroPart e $centPart';
  }
}

class DefaultMediaLibrary {
  static const String _cdn =
      'https://jsdelivr.net';
  static const String _sfx =
      'https://google.com';

  static const String voiceCloneScript3Min =
      'Olá pessoal, bem-vindos à nossa transmissão no HELL CREATOR OS! '
      'Hoje vamos ter muita ação, desafios em direto e momentos épicos com toda a comunidade. '
      'Fiquem bem, que jogada incrível! Malta, se estão a curtir a live, deixem o vosso gosto e partilhem com os amigos. '
      'Muito obrigado pelo apoio constante, pelas rosas, pelos presentes especiais e pelas mensagens no chat. '
      'Aqui somos um criador, várias plataformas e controlo total!';

  static final List<Map<String, dynamic>> fullTikTokPngSelectableList = [
    {'name': 'Rosa', 'coins': 1, 'png': '$_cdn/1f339.png'},
    {'name': 'Coração TikTok', 'coins': 1, 'png': '$_cdn/2764.png'},
    {'name': 'GG', 'coins': 1, 'png': '$_cdn/1f199.png'},
    {'name': 'Fogo', 'coins': 3, 'png': '$_cdn/1f525.png'},
    {'name': 'Microfone', 'coins': 5, 'png': '$_cdn/1f3a4.png'},
    {'name': 'Panda', 'coins': 5, 'png': '$_cdn/1f43c.png'},
    {'name': 'Café Expresso', 'coins': 10, 'png': '$_cdn/2615.png'},
    {'name': 'Coroa Real', 'coins': 99, 'png': '$_cdn/1f451.png'},
    {'name': 'Confetes Festa', 'coins': 100, 'png': '$_cdn/1f389.png'},
    {'name': 'Troféu Ouro', 'coins': 500, 'png': '$_cdn/1f3c6.png'},
    {'name': 'Diamante Azul', 'coins': 1000, 'png': '$_cdn/1f48e.png'},
    {'name': 'Galáxia', 'coins': 1000, 'png': '$_cdn/1f30c.png'},
    {'name': 'Foguetão Espacial', 'coins': 2000, 'png': '$_cdn/1f680.png'},
    {'name': 'Leão Rei', 'coins': 29999, 'png': '$_cdn/1f981.png'},
  ];

  static final List<Map<String, dynamic>> tiktokGiftsCatalog = [
    {'id': 'tk_rosa', 'name': 'Rosa', 'coins': 1, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f339.png', 'sound': '$_sfx/cartoon/pop.ogg'},
    {'id': 'tk_gg', 'name': 'GG', 'coins': 1, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f199.png', 'sound': '$_sfx/cartoon/clang_and_wobble.ogg'},
    {'id': 'tk_fogo', 'name': 'Fogo', 'coins': 5, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f525.png', 'sound': '$_sfx/ambiences/fire.ogg'},
    {'id': 'tk_coroa', 'name': 'Coroa Real', 'coins': 99, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f451.png', 'sound': '$_sfx/crowds/applause.ogg'},
    {'id': 'tk_galaxia', 'name': 'Galáxia', 'coins': 1000, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f30c.png', 'sound': '$_sfx/science_fiction/sci_fi_laser.ogg'},
    {'id': 'tk_leao', 'name': 'Leão Rei', 'coins': 29999, 'enabled': true, 'ttsThank': true, 'customVoicePath': null, 'png': '$_cdn/1f981.png', 'sound': '$_sfx/animals/lion_roar.ogg'},
  ];

  static final List<Map<String, String>> builtinGifsAndPngs = [
    {'name': 'Festa & Confetes HD', 'cat': 'Alertas', 'url': '$_cdn/1f389.png'},
    {'name': 'Troféu Campeão Ouro', 'cat': 'Metas', 'url': '$_cdn/1f3c6.png'},
    {'name': 'Estrela Brilhante 4K', 'cat': 'Badges', 'url': '$_cdn/1f31f.png'},
    {'name': 'Chama Néon Hype', 'cat': 'Hype', 'url': '$_cdn/1f525.png'},
    {'name': 'Coração Pulsante', 'cat': 'Presentes', 'url': '$_cdn/1f496.png'},
    {'name': 'Foguetão Espacial', 'cat': 'Hype', 'url': '$_cdn/1f680.png'},
    {'name': 'Diamante Azul VIP', 'cat': 'VIP', 'url': '$_cdn/1f48e.png'},
    {'name': 'Coroa Imperial', 'cat': 'VIP', 'url': '$_cdn/1f451.png'},
    {'name': 'Raio Elétrico', 'cat': 'Efeitos', 'url': '$_cdn/26a1.png'},
    {'name': 'Sino de Alerta Live', 'cat': 'Alertas', 'url': '$_cdn/1f514.png'},
    {'name': 'Comando Gaming Pro', 'cat': 'Gaming', 'url': '$_cdn/1f3ae.png'},
    {'name': 'Auscultadores Estúdio', 'cat': 'Gaming', 'url': '$_cdn/1f3a7.png'},
    {'name': 'Microfone Broadcast', 'cat': 'Estúdio', 'url': '$_cdn/1f3a4.png'},
    {'name': 'Câmara Cinema 4K', 'cat': 'Estúdio', 'url': '$_cdn/1f3a5.png'},
    {'name': 'Escudo Moderador', 'cat': 'Badges', 'url': '$_cdn/1f6e1.png'},
    {'name': 'Espadas Cruzadas PvP', 'cat': 'Gaming', 'url': '$_cdn/2694.png'},
    {'name': 'Alvo Precisão', 'cat': 'Gaming', 'url': '$_cdn/1f3af.png'},
    {'name': 'Explosão Épica', 'cat': 'Efeitos', 'url': '$_cdn/1f4a5.png'},
    {'name': 'Saco de Dinheiro', 'cat': 'Donation', 'url': '$_cdn/1f4b0.png'},
    {'name': 'Nota de Euro / Banco', 'cat': 'Donation', 'url': '$_cdn/1f4b6.png'},
    {'name': 'Galáxia Cósmica', 'cat': 'Presentes', 'url': '$_cdn/1f30c.png'},
    {'name': 'Dragão Lendário', 'cat': 'VIP', 'url': '$_cdn/1f409.png'},
    {'name': 'Caveira Hacker', 'cat': 'Badges', 'url': '$_cdn/1f480.png'},
    {'name': 'Robô IA Diretor', 'cat': 'Estúdio', 'url': '$_cdn/1f916.png'},
  ];

  static final List<Map<String, String>> builtInSounds = [
    {'name': 'Aplausos da Plateia', 'url': '$_sfx/crowds/applause.ogg'},
    {'name': 'Buzina MLG / Airhorn', 'url': '$_sfx/alarms/air_horn.ogg'},
    {'name': 'Alerta Espacial Sci-Fi', 'url': '$_sfx/alarms/spaceship_alarm.ogg'},
    {'name': 'Laser Futurista', 'url': '$_sfx/science_fiction/sci_fi_laser.ogg'},
    {'name': 'Pop Cristalino (Presente)', 'url': '$_sfx/cartoon/pop.ogg'},
    {'name': 'Sino Digital de Alerta', 'url': '$_sfx/alarms/digital_watch_alarm_long.ogg'},
    {'name': 'Rugido de Leão Épico', 'url': '$_sfx/animals/lion_roar.ogg'},
    {'name': 'Trovão Cinematográfico', 'url': '$_sfx/weather/thunder_crack.ogg'},
    {'name': 'Boing Cartoon', 'url': '$_sfx/cartoon/cartoon_boing.ogg'},
    {'name': 'Explosão de Ação', 'url': '$_sfx/impacts/crash.ogg'},
    {'name': 'Batida de Porta', 'url': '$_sfx/doors/front_door_slam.ogg'},
    {'name': 'Multidão a Celebrar', 'url': '$_sfx/crowds/battle_crowd_celebrate_stutter.ogg'},
  ];

  static final List<Map<String, String>> onlineSoundsRepository = [
    {'name': 'Aplausos da Plateia', 'cat': 'Festa', 'url': '$_sfx/crowds/applause.ogg'},
    {'name': 'Celebração de Estádio', 'cat': 'Festa', 'url': '$_sfx/crowds/battle_crowd_celebrate_stutter.ogg'},
    {'name': 'Buzina MLG (Airhorn)', 'cat': 'Hype', 'url': '$_sfx/alarms/air_horn.ogg'},
    {'name': 'Alarme Nave Espacial', 'cat': 'Alertas', 'url': '$_sfx/alarms/spaceship_alarm.ogg'},
    {'name': 'Sino Digital Alerta', 'cat': 'Alertas', 'url': '$_sfx/alarms/digital_watch_alarm_long.ogg'},
    {'name': 'Sirene Emergência', 'cat': 'Alertas', 'url': '$_sfx/alarms/alarm_clock.ogg'},
    {'name': 'Laser Sci-Fi', 'cat': 'Sci-Fi', 'url': '$_sfx/science_fiction/sci_fi_laser.ogg'},
    {'name': 'Teletransporte Futurista', 'cat': 'Sci-Fi', 'url': '$_sfx/science_fiction/alien_beam.ogg'},
    {'name': 'Pop Presente Rápido', 'cat': 'Presentes', 'url': '$_sfx/cartoon/pop.ogg'},
    {'name': 'Mola Boing Cartoon', 'cat': 'Memes', 'url': '$_sfx/cartoon/cartoon_boing.ogg'},
    {'name': 'Buzina Palhaço', 'cat': 'Memes', 'url': '$_sfx/cartoon/clown_horn.ogg'},
    {'name': 'Clang Metálico', 'cat': 'Memes', 'url': '$_sfx/cartoon/clang_and_wobble.ogg'},
    {'name': 'Rugido de Leão Rei', 'cat': 'VIP', 'url': '$_sfx/animals/lion_roar.ogg'},
    {'name': 'Uivo de Lobo', 'cat': 'VIP', 'url': '$_sfx/animals/wolf_howling.ogg'},
    {'name': 'Trovão Forte', 'cat': 'Efeitos', 'url': '$_sfx/weather/thunder_crack.ogg'},
    {'name': 'Impacto Explosivo', 'cat': 'Efeitos', 'url': '$_sfx/impacts/crash.ogg'},
  ];

  static final List<Map<String, String>> goalOverlaysCatalog = [
    {'type': 'tiktok_capsule', 'brand': 'TikTok Live Studio', 'name': 'Cápsula Oficial TikTok Studio', 'desc': 'Barra transparente com ícone à esquerda e contador limpo.'},
    {'type': 'tiktok_heart', 'brand': 'TikTok Live Studio', 'name': 'Barra Coração & Likes Studio', 'desc': 'Design nativo rosa/ciano com progresso arredondado.'},
    {'type': 'tikfinity_neon', 'brand': 'TikFinity PRO', 'name': 'Barra Néon Cyber Segmentada', 'desc': 'Blocos luminosos 3D com brilho azul elétrico.'},
    {'type': 'tikfinity_gold', 'brand': 'TikFinity PRO', 'name': 'Barra Ouro VIP Exclusivo', 'desc': 'Acabamento dourado metálico para metas de apoios.'},
  ];

  static final List<Map<String, String>> royaltyFreeMusicRepo = [
    {'title': 'Ambiente Chuva Suave de Estúdio', 'artist': 'HELL Beats · Sem Copyright', 'url': '$_sfx/weather/rain_heavy_loud.ogg'},
    {'title': 'Fogueira Relaxante (Just Chatting)', 'artist': 'HELL Beats · Sem Copyright', 'url': '$_sfx/ambiences/fire.ogg'},
    {'title': 'Ondas do Oceano Lo-Fi', 'artist': 'HELL Beats · Sem Copyright', 'url': '$_sfx/water/waves_crashing_on_rock_beach.ogg'},
    {'title': 'Vento Cósmico Sci-Fi', 'artist': 'HELL Beats · Sem Copyright', 'url': '$_sfx/weather/wind_synthetic.ogg'},
  ];

  static final List<Map<String, String>> profileBannersCatalog = [
    {'id': 'bn_cyber', 'name': 'Néon Cyber Azul 3D', 'type': 'Estático HD', 'primary': '0xFF0EA5E9', 'secondary': '0xFF1E3A8A'},
    {'id': 'bn_fire', 'name': 'Chama Épica Streamer', 'type': 'Animado', 'primary': '0xFFF97316', 'secondary': '0xFF7F1D1D'},
    {'id': 'bn_gold', 'name': 'Ouro VIP Exclusivo', 'type': 'Estático HD', 'primary': '0xFFFACC15', 'secondary': '0xFF422006'},
    {'id': 'bn_matrix', 'name': 'Matrix Esmeralda PRO', 'type': 'Animado', 'primary': '0xFF10B981', 'secondary': '0xFF064E3B'},
  ];

  static final List<Map<String, dynamic>> tikfinityOverlayCategories = [
    {
      'category': '🎨 Overlays HUD & Molduras 3D',
      'items': [
        {'name': 'HUD Câmara Néon 3D', 'desc': 'Moldura transparente com brilho azul elétrico para OBS.', 'scene': 'hud_cam', 'previewType': 'frame', 'price': 0.0},
        {'name': 'Barra de Metas TikTok Studio', 'desc': 'Cápsula oficial transparente com progresso ao vivo.', 'scene': 'goal_bar', 'previewType': 'bar', 'price': 0.0},
        {'name': 'Temporizador Subathon Sem Fundo', 'desc': 'Contagem regressiva transparente ("Tu controlas o tempo!").', 'scene': 'timer_hud', 'previewType': 'timer', 'price': 0.0},
        {'name': 'Roleta 3D Interativa', 'desc': 'Roda giratória 3D com prémios e efeitos sonoros.', 'scene': 'wheel_3d', 'previewType': 'wheel', 'price': 0.0},
        {'name': 'Pódio Top Apoiantes (Foto + Nome)', 'desc': 'Classificação em tempo real dos maiores apoiantes.', 'scene': 'podium_top', 'previewType': 'podium', 'price': 0.0},
      ],
    },
  ];
}
