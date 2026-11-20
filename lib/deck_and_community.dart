import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'live_connectors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;


class StreamDeckScreen extends StatefulWidget {
  final IO.Socket socket;
  final String activeRoom;
  final String? generatedCode;
  final String? pairedRoom;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onGenerateCode;
  final Function(String) onJoinWithCode;
  final Function(String, dynamic) onSendCommand;
  final VoidCallback onMinimizeDeck;

  const StreamDeckScreen({
    super.key,
    required this.socket,
    required this.activeRoom,
    this.generatedCode,
    this.pairedRoom,
    required this.isMuted,
    required this.onToggleMute,
    required this.onGenerateCode,
    required this.onJoinWithCode,
    required this.onSendCommand,
    required this.onMinimizeDeck,
  });

  @override
  State<StreamDeckScreen> createState() => _StreamDeckScreenState();
}

class _StreamDeckScreenState extends State<StreamDeckScreen> {
  int _cols = 4;
  int _rows = 3;
  final Map<int, bool> _activeContinuousStates = {};
  final AudioPlayer _deckAudioPlayer = AudioPlayer();
  final FlutterTts _deckTts = FlutterTts();
  final AudioRecorder _deckRecorder = AudioRecorder();

  Future<void> _playDeckAudioOrTts({String? audioPath, String? ttsText}) async {
    try {
      await _deckAudioPlayer.stop();
      await _deckTts.stop();
      if (audioPath != null && audioPath.isNotEmpty) {
        if (audioPath.startsWith('http')) {
          await _deckAudioPlayer.play(UrlSource(audioPath));
        } else if (File(audioPath).existsSync()) {
          await _deckAudioPlayer.play(DeviceFileSource(audioPath));
        }
      }
      if (ttsText != null && ttsText.trim().isNotEmpty) {
        await _deckTts.setLanguage('pt-PT');
        await _deckTts.setSpeechRate(0.52);
        await _deckTts.speak(ttsText.trim());
      }
    } catch (_) {}
  }

  final Map<String, IconData> _iconCatalog = {
    'bolt': Icons.bolt_rounded,
    'mic': Icons.mic_rounded,
    'music': Icons.music_note_rounded,
    'skip': Icons.skip_next_rounded,
    'clap': Icons.celebration_rounded,
    'horn': Icons.campaign_rounded,
    'scene': Icons.videocam_rounded,
  };

  final List<Map<String, dynamic>> _buttons = [
    {'label': 'CORTAR SOM', 'cmd': 'toggle_mute', 'val': '', 'iconKey': 'mic', 'colorVal': 0xFFEF4444, 'isContinuous': true},
    {'label': 'CENA JOGO', 'cmd': 'scene_game', 'val': 'game', 'iconKey': 'scene', 'colorVal': 0xFF38BDF8, 'isContinuous': true},
    {'label': 'CÂMARA', 'cmd': 'scene_cam', 'val': 'cam', 'iconKey': 'scene', 'colorVal': 0xFF3B82F6, 'isContinuous': true},
    {'label': 'PAUSA', 'cmd': 'scene_brb', 'val': 'brb', 'iconKey': 'scene', 'colorVal': 0xFFF59E0B, 'isContinuous': true},
    {'label': 'PLAY / PAUSE', 'cmd': 'music_toggle', 'val': '', 'iconKey': 'music', 'colorVal': 0xFF10B981, 'isContinuous': false},
    {'label': 'PRÓXIMA', 'cmd': 'music_next', 'val': '', 'iconKey': 'skip', 'colorVal': 0xFF06B6D4, 'isContinuous': false},
    {'label': 'APLAUSOS', 'cmd': 'sound_clap', 'val': '', 'iconKey': 'clap', 'colorVal': 0xFF8B5CF6, 'isContinuous': false},
    {'label': 'BUZINA', 'cmd': 'sound_horn', 'val': '', 'iconKey': 'horn', 'colorVal': 0xFFF97316, 'isContinuous': false},
  ];

   void _executeKeyAction(int index, Map<String, dynamic> b) {
    _playDeckAudioOrTts(audioPath: b['soundPath']?.toString(), ttsText: b['ttsText']?.toString());
    if (b['cmd'] == 'play_sound_only') return;
    final cmd = (b['cmd'] ?? '').toString();
    final val = (b['val'] ?? '').toString();
    if (cmd == 'toggle_mute') {
      widget.onToggleMute();
      return;
    }
    if (b['isContinuous'] == true) {
      setState(() {
        _activeContinuousStates[index] = !(_activeContinuousStates[index] == true);
      });
    } else {
      setState(() => _activeContinuousStates[index] = true);
      Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _activeContinuousStates[index] = false);
      });
    }
    widget.onSendCommand(cmd, val);
    try {
      widget.socket.emit('deck_command', {'cmd': cmd, 'val': val});
    } catch (_) {}
  }

  void _addNewKey() => _openProKeyEditorModal(null);
  void _editKeyModal(int index) => _openProKeyEditorModal(index);

  void _openProKeyEditorModal(int? editIndex) {
    final isEditing = editIndex != null;
    final existing = isEditing ? Map<String, dynamic>.from(_buttons[editIndex]) : <String, dynamic>{};

    final labelCtrl = TextEditingController(text: (existing['label'] ?? '').toString());
    final valCtrl = TextEditingController(text: (existing['val'] ?? '').toString());
    final ttsCtrl = TextEditingController(text: (existing['ttsText'] ?? '').toString());
    String selectedCmd = (existing['cmd'] ?? 'scene_game').toString();
    String selectedIcon = (existing['iconKey'] ?? 'bolt').toString();
    int selectedColor = (existing['colorVal'] as int?) ?? 0xFF38BDF8;
    bool isContinuous = existing['isContinuous'] == true;
    String? imagePath = existing['imagePath']?.toString();
    String? soundPath = existing['soundPath']?.toString();
    bool fullCoverImg = existing['fullCoverImg'] == true;
    bool hideLabelOnImg = existing['hideLabelOnImg'] == true;
    bool isRecordingVoice = false;

    const actionsList = <Map<String, String>>[
      {'cmd': 'play_sound_only', 'name': '🔊 Tocar Som / Voz / TTS da Tecla'},
      {'cmd': 'scene_game', 'name': '🎮 Mudar para Cena Jogo'},
      {'cmd': 'scene_cam', 'name': '📷 Mudar para Câmara Full'},
      {'cmd': 'scene_brb', 'name': '⏸️ Mudar para Pausa / BRB'},
      {'cmd': 'toggle_mute', 'name': '🔇 Mutar / Ativar Microfone'},
      {'cmd': 'stream_start', 'name': '📡 Iniciar Transmissão Live'},
      {'cmd': 'stream_stop', 'name': '⏹️ Parar Transmissão Live'},
      {'cmd': 'save_clip', 'name': '🎬 Criar Clipe 9:16 Agora'},
      {'cmd': 'music_toggle', 'name': '🎵 Música Play / Pause'},
      {'cmd': 'music_next', 'name': '⏭️ Próxima Música'},
      {'cmd': 'spin_wheel', 'name': '🎡 Girar Roleta Interativa'},
      {'cmd': 'test_alert', 'name': '🔔 Disparar / Replay Alerta'},
      {'cmd': 'add_timer_60', 'name': '⏱️ Adicionar +1 Minuto Timer'},
      {'cmd': 'goal_add', 'name': '🎯 Somar +1 na Meta Ativa'},
      {'cmd': 'tts_toggle', 'name': '🗣️ Voz TTS Chat On / Off'},
      {'cmd': 'chat_reply', 'name': '💬 Enviar Mensagem no Chat'},
      {'cmd': 'open_url', 'name': '🌐 Abrir Link / Webhook HTTP'},
      {'cmd': 'custom_action', 'name': '⚡ Comando / Macro Personalizado'},
    ];

    if (!actionsList.any((a) => a['cmd'] == selectedCmd)) {
      selectedCmd = 'custom_action';
    }

    const palette = <int>[
      0xFF38BDF8, 0xFF1E7BFF, 0xFF22C55E, 0xFFEF4444,
      0xFFF59E0B, 0xFFA855F7, 0xFFEC4899, 0xFF14B8A6,
    ];

    Future<void> openOnlineSoundLibrary(StateSetter setParentDlg) async {
      final searchCtrl = TextEditingController(text: 'applause');
      List<Map<String, String>> results = [];
      bool loading = false;

      Future<void> searchOnline(String query, StateSetter setLib) async {
        setLib(() => loading = true);
        try {
          final uri = Uri.parse(
            'https://wikimedia.org{Uri.encodeComponent("$query filetype:audio")}&gsrnamespace=6&gsrlimit=25&prop=imageinfo&iiprop=url&format=json',
          );
          final res = await http.get(uri);
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final pages = (data['query']?['pages'] as Map<String, dynamic>?) ?? {};
            final list = <Map<String, String>>[];
            for (final entry in pages.values) {
              final title = (entry['title'] ?? '').toString().replaceFirst('File:', '');
              final info = (entry['imageinfo'] as List?)?.firstOrNull;
              final url = (info?['url'] ?? '').toString();
              if (url.isNotEmpty) list.add({'title': title, 'url': url});
            }
            setLib(() => results = list);
          }
        } catch (_) {}
        setLib(() => loading = false);
      }

      await showDialog(
        context: context,
        builder: (libCtx) => StatefulBuilder(
          builder: (libCtx, setLib) {
            if (results.isEmpty && !loading) {
              Future.microtask(() => searchOnline('applause', setLib));
            }
            return AlertDialog(
              backgroundColor: const Color(0xFF0B1636),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
              ),
              title: const Text('🌐 Biblioteca Online de Efeitos Sonoros', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
              content: SizedBox(
                width: 420,
                height: 360,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(hintText: 'Pesquisar som (ex: applause, horn, laugh, win)...', isDense: true),
                            onSubmitted: (v) => searchOnline(v, setLib),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                          onPressed: () => searchOnline(searchCtrl.text.trim(), setLib),
                        ),
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
                                  title: Text(item['title']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_filled, color: Colors.cyanAccent, size: 22),
                                        tooltip: 'Ouvir Prévia',
                                        onPressed: () => _playDeckAudioOrTts(audioPath: item['url']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded, color: Colors.greenAccent, size: 22),
                                        tooltip: 'Baixar & Usar na Tecla',
                                        onPressed: () async {
                                          try {
                                            final dir = await getApplicationDocumentsDirectory();
                                            final ext = item['url']!.split('.').last.split('?').first;
                                            final localFile = File('${dir.path}/deck_sfx_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                            final bytes = await http.readBytes(Uri.parse(item['url']!));
                                            await localFile.writeAsBytes(bytes);
                                            setParentDlg(() => soundPath = localFile.path);
                                            if (libCtx.mounted) Navigator.pop(libCtx);
                                          } catch (_) {}
                                        },
                                      ),
                                    ],
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
                    _deckAudioPlayer.stop();
                    Navigator.pop(libCtx);
                  },
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        ),
      );
    }


    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
          title: Text(
            isEditing ? '🎛️ Personalizar Tecla Pro' : '➕ Nova Tecla Stream Deck Pro',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Nome / Rótulo da Tecla', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCmd,
                  dropdownColor: const Color(0xFF050B1E),
                  decoration: const InputDecoration(labelText: 'Ação Principal da Tecla', isDense: true),
                  items: actionsList
                      .map((a) => DropdownMenuItem(value: a['cmd'], child: Text(a['name']!, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedCmd = v ?? 'scene_game'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parâmetro (Mensagem Chat, URL, Macro ou Valor)',
                    isDense: true,
                  ),
                ),
                                const SizedBox(height: 10),
                const Text('🔊 Som, Biblioteca Online, Voz Própria ou TTS:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13224D), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onPressed: () => openOnlineSoundLibrary(setDlg),
                      icon: const Icon(Icons.library_music_rounded, size: 16, color: Colors.cyanAccent),
                      label: const Text('Biblioteca Online', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13224D), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                        if (res != null && res.files.single.path != null) {
                          setDlg(() => soundPath = res.files.single.path);
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.amberAccent),
                      label: const Text('MP3/WAV Local', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRecordingVoice ? Colors.redAccent : const Color(0xFF13224D),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () async {
                        if (!isRecordingVoice) {
                          if (await _deckRecorder.hasPermission()) {
                            final dir = await getApplicationDocumentsDirectory();
                            final recPath = '${dir.path}/deck_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                            await _deckRecorder.start(const RecordConfig(), path: recPath);
                            setDlg(() => isRecordingVoice = true);
                          }
                        } else {
                          final saved = await _deckRecorder.stop();
                          setDlg(() {
                            isRecordingVoice = false;
                            if (saved != null) soundPath = saved;
                          });
                        }
                      },
                      icon: Icon(isRecordingVoice ? Icons.stop_rounded : Icons.mic_rounded, size: 16, color: Colors.white),
                      label: Text(isRecordingVoice ? 'Parar Gravação' : 'Gravar Voz', style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ],
                ),
                if (soundPath != null && soundPath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('✅ Áudio associado: ${soundPath!.split(Platform.pathSeparator).last}', style: const TextStyle(fontSize: 10.5, color: Colors.greenAccent), overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                          onPressed: () => setDlg(() => soundPath = null),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                TextField(
                  controller: ttsCtrl,
                  decoration: const InputDecoration(
                    labelText: '🗣️ Mensagem Falada pela Voz TTS (opcional)',
                    hintText: 'Ex: Obrigado pelo follow, bem-vindo à live!',
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13224D)),
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (res != null && res.files.single.path != null) {
                            setDlg(() => imagePath = res.files.single.path);
                          }
                        },
                        icon: const Icon(Icons.image_outlined, size: 17, color: Color(0xFF38BDF8)),
                        label: Text(
                          imagePath != null && imagePath!.isNotEmpty ? 'Trocar PNG HD' : 'Escolher Imagem PNG HD',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white),
                        ),
                      ),
                    ),
                    if (imagePath != null && imagePath!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Remover Imagem',
                        onPressed: () => setDlg(() => imagePath = null),
                      ),
                    ],
                  ],
                ),
                if (imagePath != null && imagePath!.isNotEmpty) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Imagem em Ecrã Total da Tecla (HD)', style: TextStyle(fontSize: 11.5)),
                    value: fullCoverImg,
                    onChanged: (v) => setDlg(() => fullCoverImg = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ocultar Texto sobre a Imagem', style: TextStyle(fontSize: 11.5)),
                    value: hideLabelOnImg,
                    onChanged: (v) => setDlg(() => hideLabelOnImg = v),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('Cor Neon da Tecla:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: palette.map((c) {
                    final active = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDlg(() => selectedColor = c),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: active ? Colors.white : Colors.transparent, width: 2.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo Contínuo / Toggle (Fica aceso ao ativar)', style: TextStyle(fontSize: 11.5)),
                  value: isContinuous,
                  onChanged: (v) => setDlg(() => isContinuous = v),
                ),
                                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      final testCmd = selectedCmd;
                      final testVal = valCtrl.text.trim().isEmpty ? 'true' : valCtrl.text.trim();
                                          _playDeckAudioOrTts(audioPath: soundPath, ttsText: ttsCtrl.text);
                    if (testCmd != 'play_sound_only')

                      widget.onSendCommand(testCmd, testVal);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('▶️ A pré-visualizar: ${labelCtrl.text.trim().isEmpty ? testCmd : labelCtrl.text.trim()}'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF1E7BFF),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF38BDF8), size: 20),
                    label: const Text('Pré-visualizar Som / Ação Agora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),

              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  setState(() => _buttons.removeAt(editIndex));
                  Navigator.pop(ctx);
                },
                child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7BFF)),
              onPressed: () {
                final newKey = <String, dynamic>{
                  'label': labelCtrl.text.trim().isEmpty ? 'Tecla Pro' : labelCtrl.text.trim(),
                  'cmd': selectedCmd,
                  'val': valCtrl.text.trim().isEmpty ? 'true' : valCtrl.text.trim(),
                  'iconKey': selectedIcon,
                  'colorVal': selectedColor,
                  'isContinuous': isContinuous,
                  'imagePath': imagePath,
                                  'soundPath': soundPath,
                'ttsText': ttsCtrl.text.trim(),

                  'fullCoverImg': fullCoverImg,
                  'hideLabelOnImg': hideLabelOnImg,
                };
                setState(() {
                  if (isEditing) {
                    _buttons[editIndex] = newKey;
                  } else {
                    _buttons.add(newKey);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar Tecla', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildSingleGlassDeckKey(int index, Map<String, dynamic> b) {
    final isMuteBtn = b['cmd'] == 'toggle_mute';
    final isContinuous = b['isContinuous'] == true;
    final isOn = isMuteBtn ? widget.isMuted : (_activeContinuousStates[index] == true);
    final Color accent = isMuteBtn
        ? (widget.isMuted ? Colors.redAccent : Colors.greenAccent)
        : Color((b['colorVal'] as int?) ?? 0xFF38BDF8);
    final IconData iconData = isMuteBtn
        ? (widget.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded)
        : (_iconCatalog[b['iconKey']] ?? Icons.bolt_rounded);
    final String? imgPath = b['imagePath']?.toString();
    final bool hasValidImg = imgPath != null && imgPath.isNotEmpty && File(imgPath).existsSync();
    final bool fullCover = b['fullCoverImg'] == true;
    final bool hideLabel = b['hideLabelOnImg'] == true && hasValidImg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOn
              ? [accent.withOpacity(0.55), accent.withOpacity(0.28), const Color(0xFF050B1E)]
              : [Colors.white.withOpacity(0.14), accent.withOpacity(0.14), const Color(0xFF050B1E).withOpacity(0.78)],
        ),
        border: Border.all(color: isOn ? Colors.white : accent.withOpacity(0.65), width: isOn ? 2.2 : 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(isOn ? 0.55 : 0.22), blurRadius: isOn ? 18 : 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasValidImg && fullCover)
              Image.file(File(imgPath), fit: BoxFit.cover),
            if (isContinuous)
              Positioned(
                top: 6,
                right: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: isOn ? Colors.greenAccent : Colors.white24, shape: BoxShape.circle),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasValidImg && !fullCover)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(imgPath), width: 38, height: 38, fit: BoxFit.cover),
                    )
                  else if (!hasValidImg)
                    Icon(iconData, size: _rows == 2 ? 32 : 24, color: isOn ? Colors.white : accent),
                  if (!hideLabel) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        isMuteBtn ? (widget.isMuted ? 'CORTADO' : 'SOM ATIVO') : (b['label'] ?? '').toString(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          color: Colors.white,
                          shadows: hasValidImg && fullCover ? const [Shadow(blurRadius: 6, color: Colors.black)] : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

   void _openSyncQrModal() {
    final code = widget.generatedCode ?? 'HELL-482910';
    final codeCtrl = TextEditingController();
    bool dialogOpen = true;

    LocalObsServer.onQrDeviceConnected = () {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 2.º Aparelho sincronizado em tempo real!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        title: const Text(
          '📱 Sincronizar 2.º Ecrã (QR / Código)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(
                data: 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/deck?room=$code',
                version: QrVersions.auto,
                size: 150,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              'Código: $code',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                hintText: 'Ou introduz código de outro aparelho...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              dialogOpen = false;
              Navigator.pop(ctx);
            },
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7BFF)),
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty) {
                dialogOpen = false;
                widget.onJoinWithCode(codeCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Validar Código', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) => dialogOpen = false);
  }


  bool _editMode = false;
bool _testMode = false;

  bool _showSecondScreen = false;
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final totalPerPage = _cols * _rows;
    final pageCount = (_buttons.length / totalPerPage).ceil().clamp(1, 20);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF09122C),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF38BDF8)),
                    tooltip: 'Retroceder / Minimizar',
                    onPressed: widget.onMinimizeDeck,
                  ),
                  Text(
                    _showSecondScreen ? '2.º ECRÃ LIVE' : 'STREAM DECK PRO (${_currentPage + 1}/$pageCount)',
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_showSecondScreen ? Icons.grid_view_rounded : Icons.monitor_rounded, color: const Color(0xFF38BDF8), size: 21),
                    tooltip: _showSecondScreen ? 'Voltar à Streamdeck' : 'Abrir 2.º Ecrã Completo',
                    onPressed: () => setState(() => _showSecondScreen = !_showSecondScreen),
                  ),
                  if (!_showSecondScreen) ...[
                                     IconButton(
                      icon: Icon(
                        _testMode ? Icons.play_circle_filled_rounded : Icons.play_circle_outline_rounded,
                        color: _testMode ? Colors.cyanAccent : Colors.white70,
                        size: 22,
                      ),
                      tooltip: _testMode ? 'Sair do Modo Pré-visualização' : 'Pré-visualizar / Testar Teclas',
                      onPressed: () => setState(() {
                        _testMode = !_testMode;
                        if (_testMode) _editMode = false;
                      }),
                    ),
                    IconButton(
                      icon: Icon(
                        _editMode ? Icons.check_circle_rounded : Icons.edit_rounded,
                        color: _editMode ? Colors.greenAccent : Colors.amberAccent,
                        size: 21,
                      ),
                      tooltip: _editMode ? 'Concluir Edição' : 'Editar Teclas',
                      onPressed: () => setState(() {
                        _editMode = !_editMode;
                        if (_editMode) _testMode = false;
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, color: Colors.greenAccent, size: 21),
                      tooltip: 'Adicionar Tecla',
                      onPressed: _addNewKey,
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF38BDF8), size: 21),
                      tooltip: 'Sincronizar 2.º Aparelho (QR)',
                      onPressed: _openSyncQrModal,
                    ),
                    DropdownButton<String>(
                      value: '${_cols}x$_rows',
                      dropdownColor: const Color(0xFF0B1636),
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: '4x2', child: Text('4x2')),
                        DropdownMenuItem(value: '4x3', child: Text('4x3')),
                        DropdownMenuItem(value: '4x4', child: Text('4x4')),
                        DropdownMenuItem(value: '5x2', child: Text('5x2')),
                        DropdownMenuItem(value: '5x3', child: Text('5x3')),
                        DropdownMenuItem(value: '5x4', child: Text('5x4')),
                      ],

                      onChanged: (v) {
                        if (v != null) {
                          final parts = v.split('x');
                          setState(() {
                            _cols = int.parse(parts.first);
                            _rows = int.parse(parts.last);
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _showSecondScreen
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1636),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('META ATIVA NA LIVE', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${LocalObsServer.latestGoal['title'] ?? 'Meta'}: ${LocalObsServer.latestGoal['current'] ?? 0} / ${LocalObsServer.latestGoal['target'] ?? 100}',
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1636),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('CRONÓMETRO / TIMER', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${((LocalObsServer.latestTimer['seconds'] ?? 1800) ~/ 60).toString().padLeft(2, '0')}:${((LocalObsServer.latestTimer['seconds'] ?? 1800) % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Opacity(
                            opacity: 0.14,
                            child: Image.asset(
                              'icon.png',
                              width: 240,
                              height: 240,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 200, color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ),
                        PageView.builder(
                          controller: _pageCtrl,
                          scrollDirection: Axis.horizontal,
                          onPageChanged: (p) => setState(() => _currentPage = p),
                          itemCount: pageCount,
                          itemBuilder: (context, pageIndex) {
                            final start = pageIndex * totalPerPage;
                            final end = (start + totalPerPage).clamp(0, _buttons.length);
                            final pageButtons = _buttons.sublist(start, end);

                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 20 : 12, vertical: 10),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  const spacing = 10.0;
                                  final tileW = (constraints.maxWidth - (spacing * (_cols - 1))) / _cols;
                                  final tileH = (constraints.maxHeight - (spacing * (_rows - 1))) / _rows;

                                  return GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: pageButtons.length,
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _cols,
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: spacing,
                                      childAspectRatio: tileW / tileH,
                                    ),
                                    itemBuilder: (ctx, idx) {
                                      final realIndex = start + idx;
                                      final b = _buttons[realIndex];

                                      return DragTarget<int>(
                                        onWillAcceptWithDetails: (details) => details.data != realIndex,
                                        onAcceptWithDetails: (details) {
                                          setState(() {
                                                                                        final moved = _buttons.removeAt(details.data);
                                            _buttons.insert(realIndex, moved);
                                          });
                                        },
                                        builder: (context, candidateData, rejectedData) {
                                          final keyWidget = GestureDetector(
                                                                                       onTap: () {
                                              if (_editMode) {
                                                _editKeyModal(realIndex);
                                              } else if (_testMode) {
                                                final cmd = (b['cmd'] ?? '').toString();
                                                final isCriticalLive = cmd == 'stream_start' || cmd == 'stream_stop';
                                                if (!isCriticalLive) {
                                                  _executeKeyAction(realIndex, b);
                                                }
                                                ScaffoldMessenger.of(context).clearSnackBars();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('▶️ PRÉ-VISUALIZAÇÃO: "${b['label']}" ➔ Ação [$cmd]'),
                                                    duration: const Duration(milliseconds: 1400),
                                                    backgroundColor: const Color(0xFF0E7490),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              } else {
                                                _executeKeyAction(realIndex, b);
                                              }
                                            },

                                            onDoubleTap: () => _editKeyModal(realIndex),
                                            child: Stack(
                                              children: [
                                                _buildSingleGlassDeckKey(realIndex, b),
                                                if (_editMode)
                                                  const Positioned(
                                                    top: 6,
                                                    left: 6,
                                                    child: Icon(Icons.edit, size: 15, color: Colors.amberAccent),
                                                  ),
                                              ],
                                            ),
                                          );

                                          return LongPressDraggable<int>(
                                            data: realIndex,
                                            feedback: SizedBox(
                                              width: tileW,
                                              height: tileH,
                                              child: Opacity(opacity: 0.85, child: _buildSingleGlassDeckKey(realIndex, b)),
                                            ),
                                            childWhenDragging: Opacity(opacity: 0.3, child: keyWidget),
                                            child: keyWidget,
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class CommunityGlobeScreen extends StatefulWidget {
  final String serverUrl;
  final bool isOwner;
  const CommunityGlobeScreen({super.key, required this.serverUrl, this.isOwner = false});

  @override
  State<CommunityGlobeScreen> createState() => _CommunityGlobeScreenState();
}

class _CommunityGlobeScreenState extends State<CommunityGlobeScreen> with SingleTickerProviderStateMixin {

  late AnimationController _globeCtrl;
  double _manualDragOffset = 0.0;
  bool _requireFollowAppSocials = false;
  final List<Map<String, String>> _appOfficialSocials = [
    {'platform': 'TikTok Oficial', 'handle': '@hellcreatoros', 'url': 'https://tiktok.com'},
    {'platform': 'Instagram Oficial', 'handle': '@hellcreatoros', 'url': 'https://instagram.com'},
    {'platform': 'Discord Oficial', 'handle': 'HELL CREATOR OS Community', 'url': 'https://discord.com'},
  ];

  final List<Map<String, String>> _globalCreators = [
    {'user': '@HellGamer2026', 'country': 'Portugal · Lisboa', 'platform': 'TikTok LIVE', 'viewers': '1.4K', 'url': 'https://tiktok.com'},
    {'user': '@SofiaStreamPT', 'country': 'Portugal · Porto', 'platform': 'Twitch', 'viewers': '820', 'url': 'https://twitch.tv'},
    {'user': '@KikoArena', 'country': 'Brasil · São Paulo', 'platform': 'Kick', 'viewers': '2.1K', 'url': 'https://kick.com'},
    {'user': '@LukaCyber', 'country': 'Espanha · Madrid', 'platform': 'YouTube LIVE', 'viewers': '960', 'url': 'https://youtube.com'},
  ];

  @override
  void initState() {
    super.initState();
    _globeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 32))..repeat();
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() => _manualDragOffset += d.delta.dx * 0.012),
          child: Container(
            height: 310,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.1,
                colors: [Color(0xFF0A1D42), Color(0xFF020612), Color(0xFF000208)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.55), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _globeCtrl,
                  builder: (_, __) {
                    final angle = (_globeCtrl.value * 2 * pi) + _manualDragOffset;
                    final shiftX = ((angle % (2 * pi)) / (2 * pi)) * 520.0;
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.45), blurRadius: 28, spreadRadius: 4),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            Positioned(
                              left: -shiftX,
                              top: 0,
                              bottom: 0,
                              width: 1040,
                              child: Row(
                                children: [
                                  Image.network(
                                    'https://wikimedia.org',
                                    width: 520,
                                    height: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F296E)),
                                  ),
                                  Image.network(
                                    'https://wikimedia.org',
                                    width: 520,
                                    height: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F296E)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.35, -0.35),
                                  radius: 1.05,
                                  colors: [
                                    Colors.white.withOpacity(0.16),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Positioned(
                  top: 12,
                  child: Text('🛰️ GLOBO TERRESTRE 3D REAL · ARRASTA PARA RODAR', style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: Color(0xFF7DD3FC), fontWeight: FontWeight.bold)),
                ),
                const Positioned(
                  bottom: 12,
                  child: Text('🌍 COMUNIDADE GLOBAL HELL CREATOR OS', style: TextStyle(fontSize: 11.5, letterSpacing: 1.8, color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF122E73), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text('👑 Criador & Fundador em Destaque', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Olá! Sou o criador do HELL CREATOR OS. Construí este ecossistema para ajudar todos os streamers e gamers a terem controlo total com pouco equipamento. Acompanha as minhas lives e junta-te à nossa família!',
                style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _appOfficialSocials.map((soc) => OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(soc['url']!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF38BDF8)),
                  label: Text('${soc['platform']} (${soc['handle']})', style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                )).toList(),
              ),
              if (widget.isOwner) ...[
                const Divider(color: Colors.white12),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('👑 Controlo Dono: Exigir seguir redes da app antes do chat', style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
                  value: _requireFollowAppSocials,
                  onChanged: (v) => setState(() => _requireFollowAppSocials = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('🔴 Criadores em Direto pelo Mundo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        ..._globalCreators.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0E1D47), Color(0xFF08112B)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E429F)),
              ),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1E78FF), child: Icon(Icons.public, color: Colors.white)),
                title: Text(s['user']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${s['country']} · ${s['platform']} (${s['viewers']} a assistir)', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                  onPressed: () async {
                                        final uri = Uri.tryParse(s['url']!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: const Text('Assistir', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            )),
      ],
    );
  }
}

class MarketplaceState {
  static final List<Map<String, dynamic>> items = [
    {
      'id': 'mp_1',
      'title': 'Pack Overlays Néon Cyber 3D',
      'creator': '@TugaStream',
      'category': 'Overlays 3D',
      'netPrice': 0.0,
      'desc': 'Moldura de câmara + barra de metas transparente para OBS e TikTok Live Studio.',
      'owned': true,
    },
    {
      'id': 'mp_2',
      'title': 'Plugin Auto-Clip & Highlight Detector',
      'creator': '@HELLDev',
      'category': 'Plugins & API',
      'netPrice': 5.0,
      'desc': 'Extensão oficial que marca picos de chat e guarda clips automáticos.',
      'owned': false,
    },
    {
      'id': 'mp_3',
      'title': 'Pack 15 Sons Épicos + Stickers 3D',
      'creator': '@KikoGamer',
      'category': 'Sons & GIFs',
      'netPrice': 10.0,
      'desc': 'Efeitos sonoros masterizados em MP3 e ícones 3D para alertas de presentes.',
      'owned': false,
    },
  ];
}

class MarketplacePublicScreen extends StatefulWidget {
  final bool hasFreeOwnerOrStaffAccess;
  const MarketplacePublicScreen({super.key, this.hasFreeOwnerOrStaffAccess = false});

  @override
  State<MarketplacePublicScreen> createState() => _MarketplacePublicScreenState();
}

class _MarketplacePublicScreenState extends State<MarketplacePublicScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final visible = MarketplaceState.items.where((it) {
      if (_filter == 'Grátis') return (it['netPrice'] as double) == 0.0;
      if (_filter == 'PRO') return (it['netPrice'] as double) > 0.0;
      return true;
    }).toList();

    final plans = [
      {'name': 'HELL STARTER', 'price': '0 € / mês', 'desc': 'Ferramentas essenciais, Dashboard básico e alertas iniciais.'},
      {'name': 'HELL CREATOR PRO', 'price': '9,99 € / mês', 'desc': 'Chat avançado, HELL VOICE personalizado, alertas avançados, automações e estatísticas.'},
      {'name': 'HELL CREATOR ELITE', 'price': '19,99 € / mês', 'desc': 'IA avançada, Fábrica de Conteúdos, Analytics avançados e ferramentas de comunidade.'},
      {'name': 'HELL AGENCY / STUDIO', 'price': '49,99 €+ / mês', 'desc': 'Vários criadores, gestão de equipa, permissões, relatórios e dashboard de agência.'},
    ];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '🛒 Market Place'),
              Tab(text: '🔌 Plugins & API'),
              Tab(text: '💎 Planos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. MARKET PLACE
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: ['Todos', 'Grátis', 'PRO'].map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        selectedColor: const Color(0xFF1E78FF),
                        onSelected: (_) => setState(() => _filter = f),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                    ...visible.map((item) {
                      final double net = (item['netPrice'] as num).toDouble();
                      final double consumerPrice = widget.hasFreeOwnerOrStaffAccess ? 0.0 : (net == 0.0 ? 0.0 : net * 1.30);
                      final bool owned = item['owned'] == true || widget.hasFreeOwnerOrStaffAccess;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                Text(
                                  consumerPrice == 0.0 ? 'GRÁTIS' : '${consumerPrice.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Por ${item['creator']} · ${item['category']}', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                            const SizedBox(height: 6),
                            Text(item['desc'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: owned ? Colors.green : const Color(0xFF1E78FF)),
                                onPressed: () => setState(() => item['owned'] = true),
                                child: Text(owned ? 'Ativo na Conta' : 'Transferir / Adquirir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),

                // 2. PLUGINS, API & WHITE-LABEL
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF38BDF8))),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🔌 Ecossistema de Extensões & API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF38BDF8))),
                          SizedBox(height: 8),
                          Text('• Plugins de Terceiros com permissões controladas e regras claras de segurança.\n• Extensões de alertas, áudio, vídeo e ferramentas de comunidade.\n• API oficial para programadores e soluções White-Label para agências.', style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. PLANOS & SUBSCRIÇÕES
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.hasFreeOwnerOrStaffAccess)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent)),
                        child: const Text('👑 Acesso Livre Total Ativo (Conta Dono / Equipa STAFF)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ),
                    ...plans.map((p) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E429F))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF38BDF8))),
                                  Text(widget.hasFreeOwnerOrStaffAccess ? '0,00 € (Livre)' : p['price']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(p['desc']!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        )),
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
