import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class AppTranslations {
    static List<String> get voiceCloneScript2Min => ['Olá! Bem-vindo ao HELL CREATOR!'];

  static String t(String lang, String key) {
    final map = {
      'pt': {
        'automations': 'Automações',
        'control_center': 'Centro de Controlo',
        'hell_voice': 'Chat e Voz TTS',
        'game_mode': 'Modo de Jogo',
        'second_screen': 'Stream Deck HELL',
        'music': 'Música',
        'smart_brain': 'Gestão IA',
        'content_factory': 'Fábrica de Conteúdos',
        'community': 'Comunidade',
        'growth': 'Crescimento e Negócio',
        'business': 'Gestão do Negócio',
        'plugins_market': 'Marketplace',
        'info_hub': 'Informações',
        'settings': 'Configurações',
      },
      'en': {
        'automations': 'Automations',
        'control_center': 'Control Center',
        'hell_voice': 'Chat & TTS Voice',
        'game_mode': 'Game Mode',
        'second_screen': 'Stream Deck HELL',
        'music': 'Music',
        'smart_brain': 'AI Management',
        'content_factory': 'Content Factory',
        'community': 'Community',
        'growth': 'Growth & Analytics',
        'business': 'Business Management',
        'plugins_market': 'Marketplace',
        'info_hub': 'Information',
        'settings': 'Settings',
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

class OnlineMediaRepository {
  static Future<List<Map<String, String>>> searchGifs(String query) async {
    final q = query.trim().isEmpty ? 'gaming hype' : query.trim();
    try {
      final host = ['g.', 'tenor.', 'com'].join();
      final uri = Uri.https(host, '/v1/search', {
        'q': q,
        'key': 'LIVDSRZULELA',
        'limit': '30',
        'media_filter': 'minimal',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['results'] as List?) ?? [];
        final out = <Map<String, String>>[];
        for (final it in items) {
          final mediaList = it['media'] as List?;
          final m = (mediaList != null && mediaList.isNotEmpty) ? mediaList.first as Map<String, dynamic> : null;
          final url = (m?['tinygif']?['url'] ?? m?['gif']?['url'] ?? '').toString();
          if (url.isNotEmpty) {
            out.add({'name': (it['content_description'] ?? q).toString(), 'url': url, 'type': 'gif'});
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return DefaultMediaLibrary.builtInGifsAndPngs;
  }

  static Future<List<Map<String, String>>> searchImages(String query) async {
    final q = query.trim().isEmpty ? 'trophy gold icon' : query.trim();
    try {
      final host = ['commons.', 'wikimedia.', 'org'].join();
      final uri = Uri.https(host, '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$q filetype:bitmap',
        'gsrnamespace': '6',
        'gsrlimit': '30',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '320',
        'format': 'json',
      });
      final res = await http.get(uri, headers: {'User-Agent': 'HellCreator/1.0'}).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = (data['query']?['pages'] as Map<String, dynamic>?) ?? {};
        final out = <Map<String, String>>[];
        for (final entry in pages.values) {
          final title = (entry['title'] ?? '').toString().replaceFirst('File:', '');
          final info = (entry['imageinfo'] as List?)?.firstOrNull;
          final url = (info?['thumburl'] ?? info?['url'] ?? '').toString();
          if (url.isNotEmpty) {
            out.add({'name': title, 'url': url, 'type': 'image'});
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return DefaultMediaLibrary.builtInGifsAndPngs;
  }
  static Future<List<Map<String, String>>> searchSounds(String query) async {
    final q = query.trim().isEmpty ? 'applause' : query.trim();
    try {
      final host = ['commons.', 'wikimedia.', 'org'].join();
      final uri = Uri.https(host, '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$q filetype:audio',
        'gsrnamespace': '6',
        'gsrlimit': '30',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'format': 'json',
      });
      final res = await http.get(uri, headers: {'User-Agent': 'HellCreator/1.0'}).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = (data['query']?['pages'] as Map<String, dynamic>?) ?? {};
        final out = <Map<String, String>>;
        for (final entry in pages.values) {
          final title = (entry['title'] ?? '').toString().replaceFirst('File:', '');
          final info = (entry['imageinfo'] as List?)?.firstOrNull;
          final url = (info?['url'] ?? '').toString();
          if (url.isNotEmpty && (url.endsWith('.ogg') || url.endsWith('.mp3') || url.endsWith('.wav'))) {
            out.add({'name': title, 'url': url, 'type': 'audio'});
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return DefaultMediaLibrary.onlineSoundsRepository;
  }

    static Future<Map<String, String>?> openOnlineLibraryPicker(
    BuildContext context, {
    required String initialTab,
    AudioPlayer? previewPlayer,
  }) async {
    String currentTab = initialTab;
    final searchCtrl = TextEditingController(
      text: initialTab == 'sounds' ? 'applause' : (initialTab == 'gifs' ? 'celebration' : 'crown neon'),
    );
    List<Map<String, String>> results = [];
    bool loading = true;
    bool initialized = false;

    Future<void> runSearch(StateSetter setModal) async {
      setModal(() => loading = true);
      List<Map<String, String>> list;
      if (currentTab == 'gifs') {
        list = await searchGifs(searchCtrl.text);
      } else if (currentTab == 'images') {
        list = await searchImages(searchCtrl.text);
      } else {
        list = await searchSounds(searchCtrl.text);
      }
      setModal(() {
        results = list;
        loading = false;
      });
    }

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          if (!initialized) {
            initialized = true;
            Future.microtask(() => runSearch(setModal));
          }
          return AlertDialog(
            backgroundColor: const Color(0xFF0A1433),
            title: const Text('Biblioteca Online Gratuita', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 460,
              height: 410,
              child: Column(
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('GIFs'),
                        selected: currentTab == 'gifs',
                        onSelected: (_) {
                          currentTab = 'gifs';
                          runSearch(setModal);
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Imagens'),
                        selected: currentTab == 'images',
                        onSelected: (_) {
                          currentTab = 'images';
                          runSearch(setModal);
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Sons'),
                        selected: currentTab == 'sounds',
                        onSelected: (_) {
                          currentTab = 'sounds';
                          runSearch(setModal);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(hintText: 'Pesquisar milhares online...', isDense: true),
                          onSubmitted: (_) => runSearch(setModal),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.search), onPressed: () => runSearch(setModal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final item = results[i];
                              return ListTile(
                                dense: true,
                                title: Text(item['name'] ?? 'Recurso', maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    previewPlayer?.stop();
                                    Navigator.pop(ctx, item);
                                  },
                                  child: const Text('Usar'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  previewPlayer?.stop();
                  Navigator.pop(ctx);
                },
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }
}


class DefaultMediaLibrary {
  static String get _cdn {
    final h = ['cdn.', 'jsdelivr.', 'net'].join();
    return 'https://$h/gh/twitter/twemoji@14.0.2/assets/72x72';
  }

  static String get _sfx {
    final h = ['actions.', 'google.', 'com'].join();
    return 'https://$h/sounds/v1';
  }

  static List<Map<String, String>> get builtInGifsAndPngs => [
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
    {'name': 'Galáxia Cósmica', 'cat': 'Presentes', 'url': '$_cdn/1f30c.png'},
    {'name': 'Leão Rei Lendário', 'cat': 'VIP', 'url': '$_cdn/1f981.png'},
    {'name': 'Rosa Vermelha', 'cat': 'Presentes', 'url': '$_cdn/1f339.png'},
  ];

  static List<Map<String, String>> get builtInSounds => [
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
  ];

  static List<Map<String, String>> get onlineSoundsRepository => [
    {'name': 'Aplausos da Plateia', 'cat': 'Festa', 'url': '$_sfx/crowds/applause.ogg'},
    {'name': 'Celebração de Estádio', 'cat': 'Festa', 'url': '$_sfx/crowds/battle_crowd_celebrate_stutter.ogg'},
    {'name': 'Buzina MLG (Airhorn)', 'cat': 'Hype', 'url': '$_sfx/alarms/air_horn.ogg'},
    {'name': 'Alarme Nave Espacial', 'cat': 'Alertas', 'url': '$_sfx/alarms/spaceship_alarm.ogg'},
    {'name': 'Sino Digital Alerta', 'cat': 'Alertas', 'url': '$_sfx/alarms/digital_watch_alarm_long.ogg'},
    {'name': 'Laser Sci-Fi', 'cat': 'Sci-Fi', 'url': '$_sfx/science_fiction/sci_fi_laser.ogg'},
    {'name': 'Pop Presente Rápido', 'cat': 'Presentes', 'url': '$_sfx/cartoon/pop.ogg'},
    {'name': 'Mola Boing Cartoon', 'cat': 'Memes', 'url': '$_sfx/cartoon/cartoon_boing.ogg'},
    {'name': 'Rugido de Leão Rei', 'cat': 'VIP', 'url': '$_sfx/animals/lion_roar.ogg'},
    {'name': 'Trovão Forte', 'cat': 'Efeitos', 'url': '$_sfx/weather/thunder_crack.ogg'},
  ];
}

class LiveActionSimulator {
  static Future<void> showSimulatedOverlay(
    BuildContext context, {
    required String category,
    required String title,
    required String subtitle,
    String? mediaUrl,
    Color accent = const Color(0xFF38BDF8),
    String? soundPathOrUrl,
    String? spokenText,
    AudioPlayer? audioPlayer,
    Function(String)? onSpeakVoice,
    Widget? customPreviewBody,
  }) async {
    try {
      final p = audioPlayer ?? AudioPlayer();
      await p.stop();
      if (soundPathOrUrl != null && soundPathOrUrl.isNotEmpty) {
        if (soundPathOrUrl.startsWith('http')) {
          await p.play(UrlSource(soundPathOrUrl));
        } else if (soundPathOrUrl.startsWith('sounds/')) {
          await p.play(AssetSource(soundPathOrUrl));
        } else {
          await p.play(DeviceFileSource(soundPathOrUrl));
        }
      }
    } catch (_) {}

    if (spokenText != null && spokenText.trim().isNotEmpty && onSpeakVoice != null) {
      onSpeakVoice(spokenText);
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF04091A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: accent, width: 1.8),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.redAccent),
              ),
              child: const Text('SIMULAÇÃO EM LIVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [accent.withOpacity(0.28), const Color(0xFF0A1433), const Color(0xFF030714)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.75), width: 1.5),
          ),
          child: customPreviewBody ??
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mediaUrl != null && mediaUrl.startsWith('http'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Image.network(mediaUrl, height: 88, width: 88, fit: BoxFit.contain),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Icon(Icons.auto_awesome_rounded, size: 60, color: accent),
                    ),
                  Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent)),
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar Pré-visualização')),
        ],
      ),
    );
  }
}

class HellFeedbackEngine {
  static bool soundEnabled = true;
  static bool vibrationEnabled = true;
  static String tapSoundAsset = 'sounds/tap_cyber.wav';
  static double tapVolume = 0.55;
  static final List<AudioPlayer> _pool = [AudioPlayer(), AudioPlayer(), AudioPlayer()];
  static int _idx = 0;

  static bool get isMobileDevice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> triggerTap() async {
    if (!isMobileDevice) return;
    if (vibrationEnabled) HapticFeedback.lightImpact();
    if (soundEnabled && tapSoundAsset.isNotEmpty) {
      try {
        final p = _pool[_idx % _pool.length];
        _idx++;
        await p.setVolume(tapVolume);
        await p.stop();
        await p.play(AssetSource(tapSoundAsset));
      } catch (_) {}
    }
  }
}

class HellCockpitWindow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;
  final String? badge;
  final VoidCallback? onTestPressed;
  final String testLabel;
  final VoidCallback? onExpandOfficialScreen;

  const HellCockpitWindow({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
    this.badge,
    this.onTestPressed,
    this.testLabel = 'Pré-visualizar',
    this.onExpandOfficialScreen,
  });

  void _defaultExpand(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF04091A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08122E),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12255B), Color(0xFF091330), Color(0xFF04091A)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis)),
              if (onTestPressed != null)
                TextButton.icon(
                  onPressed: onTestPressed,
                  icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.greenAccent),
                  label: Text(testLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(999)),
                  child: Text(badge!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: accent)),
                ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.open_in_full_rounded, size: 16, color: Colors.white),
                onPressed: onExpandOfficialScreen ?? () => _defaultExpand(context),
              ),
            ],
          ),
          const Divider(height: 14, color: Colors.white12),
          child,
        ],
      ),
    );
  }
}
