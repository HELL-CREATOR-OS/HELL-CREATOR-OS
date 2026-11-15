class AppTranslations {
  static const Map<String, Map<String, String>> strings = {
    'pt': {
      'actions': 'Ações',
      'chat_tts': 'Chat TTS & Vozes',
      'donation': 'Donation',
      'music': 'Música e Playlists',
      'interaction': 'Interações',
      'loja_hell': 'Loja HELL',
      'estudio_vip': 'Estúdio VIP HELL Live',
      'stream_deck': 'Stream Deck Pro',
      'community': 'Comunidade Global',
      'about': 'Quem Somos Nós & Ajuda',
      'settings': 'Definições e Idiomas',
      'connect': 'Ligar',
      'connected': 'Em Direto',
    },
    'en': {
      'actions': 'Actions',
      'chat_tts': 'Chat TTS & Voices',
      'donation': 'Donation',
      'music': 'Music & Playlists',
      'interaction': 'Interactions',
      'loja_hell': 'HELL Store',
      'estudio_vip': 'HELL Live VIP Studio',
      'stream_deck': 'Stream Deck Pro',
      'community': 'Global Community',
      'about': 'About Us & Help',
      'settings': 'Settings & Languages',
      'connect': 'Connect',
      'connected': 'Live',
    },
    'es': {
      'actions': 'Acciones',
      'chat_tts': 'Chat TTS y Voces',
      'donation': 'Donaciones',
      'music': 'Música y Playlists',
      'interaction': 'Interacciones',
      'loja_hell': 'Tienda HELL',
      'estudio_vip': 'Estudio VIP HELL Live',
      'stream_deck': 'Stream Deck Pro',
      'community': 'Comunidad Global',
      'about': 'Quiénes Somos y Ayuda',
      'settings': 'Ajustes e Idiomas',
      'connect': 'Conectar',
      'connected': 'En Vivo',
    },
  };

  static String t(String lang, String key) {
    return strings[lang]?[key] ?? strings['pt']![key] ?? key;
  }
}

class DefaultMediaLibrary {
  static const String brandOfficialEmail = 'helllive.app@gmail.com';
  static const List<String> ownerPersonalEmails = [
    'hellgamer2026@gmail.com',
    'heldermsf_@hotmail.com',
  ];

  static bool isOwnerEmail(String? email) {
    if (email == null) return false;
    return ownerPersonalEmails.contains(email.trim().toLowerCase());
  }

  static String formatEuroSpeech(double amount) {
    final euros = amount.floor();
    final cents = ((amount - euros) * 100).round();
    if (euros == 0 && cents > 0) return '$cents cêntimos';
    if (euros == 1 && cents == 0) return '1 euro';
    if (euros == 1 && cents == 50) return '1 euro e meio';
    if (cents == 0) return '$euros euros';
    if (cents == 50) return '$euros euros e meio';
    return '$euros euros e $cents cêntimos';
  }
  static const String legalTermsAndResponsibilityText = '''
TERMOS DE UTILIZAÇÃO, REGRAS DA COMUNIDADE E ISENÇÃO DE RESPONSABILIDADE — HELL LIVE

1. IDENTIFICAÇÃO E ACEITAÇÃO DOS TERMOS
A aplicação e plataforma HELL Live (contacto oficial: helllive.app@gmail.com) disponibiliza ferramentas de apoio à transmissão em direto, interação com audiências, gestão de overlays, controlo remoto e comércio digital para criadores de conteúdo. Ao criar uma conta, aceder ou utilizar qualquer funcionalidade da HELL Live, o utilizador declara ter lido, compreendido e aceitado integralmente o presente documento, bem como todas as leis aplicáveis na União Europeia e no seu país de residência.

2. AUTONOMIA E ISENÇÃO DE RESPONSABILIDADE SOBRE TRANSMISSÕES AO VIVO
A HELL Live atua exclusivamente como ferramenta técnica auxiliar e não possui qualquer vínculo institucional, parceria oficial ou controlo editorial sobre plataformas de terceiros (incluindo, sem limitar, TikTok, Twitch, YouTube, Kick, OBS Studio ou Streamlabs).
O utilizador é o único e exclusivo responsável:
a) Por todo o conteúdo áudio, vídeo, texto, imagens, GIFs ou mensagens lidas por síntese de voz (Chat TTS) exibidas nas suas transmissões;
b) Pelo cumprimento rigoroso dos Termos de Serviço e Diretrizes da Comunidade das plataformas onde transmite, isentando a HELL Live e os seus fundadores de qualquer suspensão, banimento, restrição de monetização ou penalização aplicada por terceiros;
c) Pela verificação e titularidade dos direitos de autor (copyright) sobre músicas, efeitos sonoros, logótipos ou ficheiros carregados a partir do seu equipamento ou de links externos.

3. RESPONSABILIDADE SOBRE DADOS PESSOAIS E PRIVACIDADE (RGPD)
Em conformidade com o Regulamento Geral sobre a Proteção de Dados (RGPD), a HELL Live recolhe apenas os dados estritamente necessários para autenticação, segurança da conta e funcionamento das ferramentas solicitadas.
O utilizador pode configurar a visibilidade do seu perfil público. Caso opte voluntariamente por tornar visíveis dados pessoais ou de contacto (tais como cidade, telefone, e-mail ou redes sociais), o utilizador assume inteira e exclusiva responsabilidade por essa exposição pública, isentando a HELL Live de qualquer contacto indevido efetuado por terceiros.

4. DOAÇÕES DIRETAS E TRANSAÇÕES FINANCEIRAS
A funcionalidade "Donation" limita-se a exibir alertas visuais/sonoros e a disponibilizar links configurados pelo próprio criador (MB WAY, PayPal, Revolut, PIX ou equivalentes). A HELL Live não processa, retém, intermedia nem garante pagamentos de doações entre espectadores e criadores, sendo qualquer litígio, estorno ou obrigação fiscal da exclusiva responsabilidade das partes envolvidas.

5. LOJA HELL, ESTÚDIO VIP E PROPRIEDADE INTELECTUAL
Os criadores com subscrição ativa no Estúdio VIP HELL Live podem publicar pacotes digitais (overlays, banners, sons, emojis) na Loja HELL, definindo o seu valor líquido de venda, ao qual a plataforma acrescenta automaticamente a taxa de serviço e manutenção de 30% (trinta por cento) no preço final ao comprador.
O criador garante sob compromisso de honra que todo o material submetido é de sua autoria original e não viola direitos de imagem, marcas registadas ou propriedade intelectual de terceiros. Cada utilizador é integralmente responsável pelo cumprimento das suas obrigações fiscais e declarativas junto das autoridades tributárias do seu país.

6. REGRAS DE CONDUTA E SUSPENSÃO DE ACESSO
É estritamente proibido utilizar a HELL Live para:
a) Difundir discurso de ódio, assédio, difamação, ameaças, conteúdo ilegal, exploração ou fraude;
b) Tentar contornar sistemas de segurança, explorar vulnerabilidades, copiar código-fonte ou distribuir ficheiros maliciosos;
c) Falsificar identidade de fundadores, administradores ou outros criadores.
A administração da HELL Live reserva-se o direito de suspender ou encerrar definitivamente qualquer conta que viole estas regras, sem direito a reembolso em caso de infração comprovada.

7. LIMITAÇÃO GERAL DE RESPONSABILIDADE E ALTERAÇÕES
O software é fornecido "tal como está" ("as is"). A HELL Live não responde por falhas de ligação à internet do utilizador, alterações técnicas nas APIs externas das plataformas de streaming ou danos indiretos decorrentes da utilização da aplicação. Os presentes termos podem ser atualizados periodicamente, sendo a continuação da utilização da aplicação considerada como aceitação das versões revistas.
''';
  static const List<Map<String, dynamic>> defaultGiftsCatalog = [
    {
      'id': 'g_rose',
      'code': 'rose',
      'name': 'Rosa',
      'coins': 1,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Muito obrigado {user} pela Rosa!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_heart',
      'code': 'finger_heart',
      'name': 'Coração com os Dedos',
      'coins': 5,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Obrigado {user} pelo Coração!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_gg',
      'code': 'gg',
      'name': 'GG',
      'coins': 1,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'GG {user}! Obrigado pelo apoio!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_perfume',
      'code': 'perfume',
      'name': 'Perfume',
      'coins': 20,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Que cheiro a vitória! Obrigado {user} pelo Perfume!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_crown',
      'code': 'crown',
      'name': 'Coroa Real',
      'coins': 99,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Rei na área! Muito obrigado {user} pela Coroa Real!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_rocket',
      'code': 'rocket',
      'name': 'Foguetão',
      'coins': 500,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Descolámos! Obrigado {user} pelo Foguetão!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_galaxy',
      'code': 'galaxy',
      'name': 'Galáxia',
      'coins': 1000,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'Incrível! {user} enviou uma Galáxia inteira para a live!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
    {
      'id': 'g_lion',
      'code': 'lion',
      'name': 'Leão',
      'coins': 29999,
      'enabled': true,
      'autoRecognize': true,
      'ttsThank': true,
      'customMessage': 'O REI DA SELVA CHEGOU! Muito obrigado {user} pelo Leão!',
      'customVoicePath': null,
      'png': 'https://jsdelivr.net',
      'sound': '',
    },
  ];
  static const List<Map<String, String>> builtInGifsAndPngs = [
    {'name': 'Fogo Néon', 'url': 'https://jsdelivr.net'},
    {'name': 'Troféu Ouro', 'url': 'https://jsdelivr.net'},
    {'name': 'Diamante VIP', 'url': 'https://jsdelivr.net'},
    {'name': 'Coroa Imperial', 'url': 'https://jsdelivr.net'},
    {'name': 'Foguetão Turbo', 'url': 'https://jsdelivr.net'},
    {'name': 'Raio Elétrico', 'url': 'https://jsdelivr.net'},
    {'name': 'Estrela Brilhante', 'url': 'https://jsdelivr.net'},
    {'name': 'Festa Confetis', 'url': 'https://jsdelivr.net'},
    {'name': 'Comando Gaming', 'url': 'https://jsdelivr.net'},
    {'name': 'Alvo Certeiro', 'url': 'https://jsdelivr.net'},
    {'name': 'Saco de Dinheiro', 'url': 'https://jsdelivr.net'},
    {'name': 'Mega-fone Alerta', 'url': 'https://jsdelivr.net'},
    {'name': 'Leão Rei', 'url': 'https://jsdelivr.net'},
    {'name': 'Dragão Místico', 'url': 'https://jsdelivr.net'},
    {'name': 'Lobo Alfa', 'url': 'https://jsdelivr.net'},
    {'name': 'Águia Real', 'url': 'https://jsdelivr.net'},
    {'name': 'OVNI Espacial', 'url': 'https://jsdelivr.net'},
    {'name': 'Galáxia Espiral', 'url': 'https://jsdelivr.net'},
    {'name': 'Coração Flamejante', 'url': 'https://jsdelivr.net'},
    {'name': 'Medalha 1.º Lugar', 'url': 'https://jsdelivr.net'},
  ];

  static const List<Map<String, String>> onlineSoundsRepository = [
    {'name': 'Alerta Cristal Limpo', 'url': 'https://google.com'},
    {'name': 'Moeda & Vitória', 'url': 'https://google.com'},
    {'name': 'Buzina de Arena', 'url': 'https://google.com'},
    {'name': 'Impacto Épico', 'url': 'https://google.com'},
    {'name': 'Campainha VIP', 'url': 'https://google.com'},
    {'name': 'Aplausos Multidão', 'url': 'https://google.com'},
    {'name': 'Nave Espacial Laser', 'url': 'https://google.com'},
    {'name': 'Tambor de Suspense', 'url': 'https://google.com'},
    {'name': 'Sino de Notificação', 'url': 'https://google.com'},
    {'name': 'Turbo Motor', 'url': 'https://google.com'},
    {'name': 'Explosão de Energia', 'url': 'https://google.com'},
    {'name': 'Magia & Brilho', 'url': 'https://google.com'},
  ];
  static const List<Map<String, String>> royaltyFreeMusicRepo = [
    {
      'title': 'Neon Cyber Stream (Lo-Fi Gaming)',
      'artist': 'HELL Live Studio Audio',
      'url': 'https://soundhelix.com',
    },
    {
      'title': 'Arena Battle Synthwave',
      'artist': 'HELL Live Studio Audio',
      'url': 'https://soundhelix.com',
    },
    {
      'title': 'Chill Night Broadcast',
      'artist': 'HELL Live Studio Audio',
      'url': 'https://soundhelix.com',
    },
    {
      'title': 'Victory Overdrive Beat',
      'artist': 'HELL Live Studio Audio',
      'url': 'https://soundhelix.com',
    },
  ];
}
