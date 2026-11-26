import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HellRecordedEpisode {
  final String id;
  String title;
  final String mode; // 'pc_obs', 'pc_tiktok_studio', 'mobile_markers'
  final DateTime startedAt;
  final int durationSeconds;

  HellRecordedEpisode({
    required this.id,
    required this.title,
    required this.mode,
    required this.startedAt,
    required this.durationSeconds,
  });

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'mode': mode,
        'startedAt': startedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory HellRecordedEpisode.fromJson(Map<String, dynamic> m) => HellRecordedEpisode(
        id: m['id'].toString(),
        title: m['title'].toString(),
        mode: (m['mode'] ?? 'pc_obs').toString(),
        startedAt: DateTime.tryParse(m['startedAt'].toString()) ?? DateTime.now(),
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
      );
}

class HellEpisodeLang {
  static String t(String lang, String key) {
    final code = lang.startsWith('en')
        ? 'en'
        : (lang.startsWith('es') ? 'es' : (lang.startsWith('fr') ? 'fr' : 'pt'));

    const Map<String, Map<String, String>> dict = <String, Map<String, String>>{
      'pt': <String, String>{
        'studio_title': 'GRAVADOR DE EPISÓDIOS & REPLAY (0 MB NO TELEMÓVEL)',
        'dest_label': 'Destino de Gravação (Sem encher a memória do telemóvel)',
        'mode_obs': 'PC · OBS Studio / Streamlabs (Grava direto no Disco do PC)',
        'mode_tiktok': 'PC · TikTok Live Studio (Comando Remoto para o PC)',
        'mode_markers': 'Telemóvel / Tablet · Apenas Marcadores Leves (< 5 KB)',
        'pc_ip': 'IP do Computador na Rede Wi-Fi (ex: 192.168.1.50)',
        'ep_name': 'Nome do Episódio Atual',
        'btn_start': 'Iniciar Episódio',
        'btn_split': 'Guardar Episódio & Novo',
        'btn_stop': 'Parar Gravação',
        'btn_replay': 'Guardar Repetição (Clip)',
        'saved_list': 'Episódios & Capítulos Guardados',
        'copy_chapters': 'Copiar Capítulos (YouTube / Editor)',
        'copied_msg': 'Lista de episódios copiada para a área de transferência!',
        'empty_list': 'Ainda não gravaste episódios nesta sessão.',
        'zero_mb_hint': 'Zero megabytes ocupados no telemóvel/tablet: o vídeo é gravado diretamente no disco do teu PC.',
      },
      'en': <String, String>{
        'studio_title': 'EPISODE RECORDER & REPLAY (0 MB ON PHONE)',
        'dest_label': 'Recording Target (Zero Phone Storage Used)',
        'mode_obs': 'PC · OBS Studio / Streamlabs (Saves directly to PC Drive)',
        'mode_tiktok': 'PC · TikTok Live Studio (Remote PC Command)',
        'mode_markers': 'Phone / Tablet · Lightweight Chapter Markers Only (< 5 KB)',
        'pc_ip': 'PC Wi-Fi IP Address (e.g. 192.168.1.50)',
        'ep_name': 'Current Episode Title',
        'btn_start': 'Start Episode',
        'btn_split': 'Save Episode & Start Next',
        'btn_stop': 'Stop Recording',
        'btn_replay': 'Save Instant Replay',
        'saved_list': 'Saved Episodes & Chapters',
        'copy_chapters': 'Copy Chapters (YouTube / Editor)',
        'copied_msg': 'Episode chapters copied to clipboard!',
        'empty_list': 'No episodes recorded yet.',
        'zero_mb_hint': 'Zero megabytes used on your phone/tablet: video is saved directly to your PC storage.',
      },
      'es': <String, String>{
        'studio_title': 'GRABADORA DE EPISODIOS Y REPLAY (0 MB EN EL MÓVIL)',
        'dest_label': 'Destino de Grabación (Sin llenar la memoria del móvil)',
        'mode_obs': 'PC · OBS Studio / Streamlabs (Graba directo en el Disco del PC)',
        'mode_tiktok': 'PC · TikTok Live Studio (Comando Remoto al PC)',
        'mode_markers': 'Móvil / Tablet · Solo Marcadores Ligeros (< 5 KB)',
        'pc_ip': 'IP del Ordenador en Wi-Fi (ej: 192.168.1.50)',
        'ep_name': 'Nombre del Episodio Actual',
        'btn_start': 'Iniciar Episodio',
        'btn_split': 'Guardar Episodio y Nuevo',
        'btn_stop': 'Detener Grabación',
        'btn_replay': 'Guardar Repetición (Clip)',
        'saved_list': 'Episodios y Capítulos Guardados',
        'copy_chapters': 'Copiar Capítulos (YouTube / Editor)',
        'copied_msg': '¡Lista de episodios copiada al portapapeles!',
        'empty_list': 'Aún no has grabado episodios en esta sesión.',
        'zero_mb_hint': 'Cero megabytes usados en tu móvil/tablet: el vídeo se guarda directamente en el disco de tu PC.',
      },
      'fr': <String, String>{
        'studio_title': 'ENREGISTREUR D\'ÉPISODES & REPLAY (0 MO SUR MOBILE)',
        'dest_label': 'Destination d\'Enregistrement (Sans remplir le téléphone)',
        'mode_obs': 'PC · OBS Studio / Streamlabs (Enregistre sur le disque PC)',
        'mode_tiktok': 'PC · TikTok Live Studio (Commande à distance PC)',
        'mode_markers': 'Mobile / Tablette · Marqueurs Légers Uniquement (< 5 Ko)',
        'pc_ip': 'Adresse IP Wi-Fi du PC (ex: 192.168.1.50)',
        'ep_name': 'Titre de l\'Épisode Actuel',
        'btn_start': 'Démarrer l\'Épisode',
        'btn_split': 'Sauver l\'Épisode & Suivant',
        'btn_stop': 'Arrêter l\'Enregistrement',
        'btn_replay': 'Sauver le Replay (Clip)',
        'saved_list': 'Épisodes & Chapitres Enregistrés',
        'copy_chapters': 'Copier les Chapitres (YouTube / Montage)',
        'copied_msg': 'Liste des épisodes copiée dans le presse-papiers !',
        'empty_list': 'Aucun épisode enregistré pour le moment.',
        'zero_mb_hint': 'Zéro mégaoctet utilisé sur votre mobile/tablette : la vidéo est enregistrée directement sur votre PC.',
      },
    };
    return dict[code]?[key] ?? dict['pt']![key] ?? key;
  }
}
class HellEpisodeRecorderPanel extends StatefulWidget {
  final void Function(String cmd, dynamic val)? onSendDeckCommand;
  const HellEpisodeRecorderPanel({super.key, this.onSendDeckCommand});

  @override
  State<HellEpisodeRecorderPanel> createState() => _HellEpisodeRecorderPanelState();
}

class _HellEpisodeRecorderPanelState extends State<HellEpisodeRecorderPanel> {
  String _lang = 'pt';
  String _mode = 'pc_obs';
  bool _isRecordingEpisode = false;
  int _episodeSeconds = 0;
  int _episodeCounter = 1;
  DateTime? _episodeStartTime;
  Timer? _timer;

  final TextEditingController _pcIpCtrl = TextEditingController(text: '192.168.1.50');
  final TextEditingController _epTitleCtrl = TextEditingController(text: 'Episódio 01');
  final List<HellRecordedEpisode> _episodes = <HellRecordedEpisode>[];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final savedLang = p.getString('app_lang') ?? 'pt';
    final savedIp = p.getString('hell_pc_deck_ip') ?? '192.168.1.50';
    final savedMode = p.getString('hell_episode_rec_mode') ?? 'pc_obs';
    final rawList = p.getString('hell_recorded_episodes_v1');

    if (rawList != null && rawList.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawList) as List;
        _episodes.clear();
        for (final item in decoded) {
          _episodes.add(HellRecordedEpisode.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _episodeCounter = _episodes.length + 1;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _lang = savedLang;
        _pcIpCtrl.text = savedIp;
        _mode = savedMode;
        _epTitleCtrl.text = 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveEpisodesList() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_recorded_episodes_v1', jsonEncode(_episodes.map((e) => e.toJson()).toList()));
  }

  Future<void> _dispatchRemotePcCommand(String cmd, String value) async {
    widget.onSendDeckCommand?.call(cmd, value);
    if (_mode == 'mobile_markers') return;
    final ip = _pcIpCtrl.text.trim();
    if (ip.isEmpty) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('http://$ip:8785/api/deck-cmd?cmd=$cmd&val=${Uri.encodeComponent(value)}');
      final req = await client.getUrl(uri);
      await req.close();
      client.close();
    } catch (_) {}
  }

  void _startTimerLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecordingEpisode) {
        setState(() => _episodeSeconds++);
      }
    });
  }

  Future<void> _startEpisode() async {
    final title = _epTitleCtrl.text.trim().isEmpty
        ? 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}'
        : _epTitleCtrl.text.trim();
    setState(() {
      _isRecordingEpisode = true;
      _episodeSeconds = 0;
      _episodeStartTime = DateTime.now();
    });
    _startTimerLoop();
    await _dispatchRemotePcCommand('start_episode', '$_mode|$title');
  }

  Future<void> _saveCurrentAndStartNext() async {
    if (!_isRecordingEpisode) return;
    final finishedTitle = _epTitleCtrl.text.trim().isEmpty
        ? 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}'
        : _epTitleCtrl.text.trim();
    final ep = HellRecordedEpisode(
      id: 'ep_${DateTime.now().millisecondsSinceEpoch}',
      title: finishedTitle,
      mode: _mode,
      startedAt: _episodeStartTime ?? DateTime.now(),
      durationSeconds: _episodeSeconds,
    );
    _episodeCounter++;
    setState(() {
      _episodes.insert(0, ep);
      _episodeSeconds = 0;
      _episodeStartTime = DateTime.now();
      _epTitleCtrl.text = 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}';
    });
    await _saveEpisodesList();
    await _dispatchRemotePcCommand('save_split_episode', '$_mode|$finishedTitle');
  }

  Future<void> _stopAndSaveEpisode() async {
    if (!_isRecordingEpisode) return;
    _timer?.cancel();
    final finishedTitle = _epTitleCtrl.text.trim().isEmpty
        ? 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}'
        : _epTitleCtrl.text.trim();
    final ep = HellRecordedEpisode(
      id: 'ep_${DateTime.now().millisecondsSinceEpoch}',
      title: finishedTitle,
      mode: _mode,
      startedAt: _episodeStartTime ?? DateTime.now(),
      durationSeconds: _episodeSeconds,
    );
    _episodeCounter++;
    setState(() {
      _isRecordingEpisode = false;
      _episodes.insert(0, ep);
      _episodeSeconds = 0;
      _epTitleCtrl.text = 'Episódio ${_episodeCounter.toString().padLeft(2, '0')}';
    });
    await _saveEpisodesList();
    await _dispatchRemotePcCommand('stop_episode', '$_mode|$finishedTitle');
  }

  Future<void> _saveInstantReplay() async {
    await _dispatchRemotePcCommand('save_replay', _mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚡ ${HellEpisodeLang.t(_lang, 'btn_replay')}!')),
      );
    }
  }

  String _formatCurrentTimer() {
    final h = _episodeSeconds ~/ 3600;
    final m = (_episodeSeconds % 3600) ~/ 60;
    final s = _episodeSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pcIpCtrl.dispose();
    _epTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k) => HellEpisodeLang.t(_lang, k);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1636),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isRecordingEpisode ? Colors.redAccent : const Color(0xFF38BDF8).withOpacity(0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _isRecordingEpisode ? Icons.fiber_manual_record : Icons.video_library_rounded,
                color: _isRecordingEpisode ? Colors.redAccent : const Color(0xFF38BDF8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('studio_title'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Color(0xFF38BDF8)),
                ),
              ),
              if (_isRecordingEpisode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'REC ${_formatCurrentTimer()}',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(t('zero_mb_hint'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _mode,
            dropdownColor: const Color(0xFF0B1636),
            decoration: InputDecoration(labelText: t('dest_label'), isDense: true),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'pc_obs', child: Text(t('mode_obs'), style: const TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'pc_tiktok_studio', child: Text(t('mode_tiktok'), style: const TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'mobile_markers', child: Text(t('mode_markers'), style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _mode = v);
              final p = await SharedPreferences.getInstance();
              await p.setString('hell_episode_rec_mode', v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (_mode != 'mobile_markers') ...<Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pcIpCtrl,
                    decoration: InputDecoration(labelText: t('pc_ip'), isDense: true),
                    onChanged: (val) async {
                      final p = await SharedPreferences.getInstance();
                      await p.setString('hell_pc_deck_ip', val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _epTitleCtrl,
                  decoration: InputDecoration(labelText: t('ep_name'), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!_isRecordingEpisode)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: _startEpisode,
                  icon: const Icon(Icons.fiber_manual_record, size: 16),
                  label: Text(t('btn_start'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else ...<Widget>[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _saveCurrentAndStartNext,
                  icon: const Icon(Icons.content_cut_rounded, size: 16),
                  label: Text(t('btn_split'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  onPressed: _stopAndSaveEpisode,
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(t('btn_stop'), style: const TextStyle(fontSize: 12)),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _saveInstantReplay,
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amberAccent),
                label: Text(t('btn_replay'), style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
              ),
            ],
          ),
          if (_episodes.isNotEmpty) ...<Widget>[
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('${t('saved_list')} (${_episodes.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                TextButton.icon(
                  onPressed: () {
                    final lines = _episodes.reversed
                        .map((e) => '• ${e.title} (${e.formattedDuration})')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: lines));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('copied_msg'))));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(t('copy_chapters'), style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            ..._episodes.take(6).map((ep) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.movie_creation_outlined, size: 14, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(ep.title, style: const TextStyle(fontSize: 12))),
                      Text(ep.formattedDuration, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
