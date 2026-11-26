import 'episode_recorder_studio.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'app_data.dart';

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
  final Map<int, bool> _activeContinuousStates = <int, bool>{};
  final AudioPlayer _deckAudioPlayer = AudioPlayer();
  final FlutterTts _deckTts = FlutterTts();
  final AudioRecorder _deckRecorder = AudioRecorder();
  bool _isFullScreenDeck = false;
  bool _showTopBarInFull = false;
  bool _orientationLocked = false;
  bool _editMode = false;
  bool _previewPopupEnabled = true;
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static String get _sfxBase => 'https://${['actions.', 'google.', 'com'].join()}/sounds/v1';

  @override
  void dispose() {
    _deckAudioPlayer.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openPairDeviceDialog() {
    final code = widget.generatedCode ?? 'HELL-482910';
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1433),
        title: const Text('Emparelhar 2.º Dispositivo', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CÓDIGO DESTE DISPOSITIVO:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ElevatedButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  child: const Text('Copiar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: InputDecoration(labelText: 'Colar código do principal', hintText: code)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty) {
                widget.onJoinWithCode(codeCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _playDeckAudioOrTts({String? audioPath, String? ttsText}) async {
    try {
      await _deckAudioPlayer.stop();
      await _deckTts.stop();
      if (audioPath != null && audioPath.isNotEmpty) {
        if (audioPath.startsWith('http')) {
          await _deckAudioPlayer.play(UrlSource(audioPath));
        } else if (audioPath.startsWith('sounds/')) {
          await _deckAudioPlayer.play(AssetSource(audioPath));
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

  final Map<String, IconData> _iconCatalog = <String, IconData>{
    'bolt': Icons.bolt_rounded,
    'mic': Icons.mic_rounded,
    'music': Icons.music_note_rounded,
    'skip': Icons.skip_next_rounded,
    'clap': Icons.celebration_rounded,
    'horn': Icons.campaign_rounded,
    'scene': Icons.videocam_rounded,
  };

  late final List<Map<String, dynamic>> _buttons = <Map<String, dynamic>>[
    {'label': 'CORTAR SOM', 'cmd': 'toggle_mute', 'val': '', 'iconKey': 'mic', 'colorVal': 0xFFEF4444, 'isContinuous': true, 'soundPath': 'sounds/tap_pulse.wav', 'scenePreview': 'Microfone da transmissão silenciado/reativado.'},
    {'label': 'CENA JOGO', 'cmd': 'scene_game', 'val': 'game', 'iconKey': 'scene', 'colorVal': 0xFF38BDF8, 'isContinuous': true, 'soundPath': 'sounds/tap_cyber.wav', 'scenePreview': 'Transição 4K para Ecrã de Jogo + Câmara + Alertas.'},
    {'label': 'CÂMARA FULL', 'cmd': 'scene_cam', 'val': 'cam', 'iconKey': 'scene', 'colorVal': 0xFF3B82F6, 'isContinuous': true, 'soundPath': 'sounds/tap_glass.wav', 'scenePreview': 'Câmara em Ecrã Inteiro com moldura Néon HDR.'},
    {'label': 'PAUSA / BRB', 'cmd': 'scene_brb', 'val': 'brb', 'iconKey': 'scene', 'colorVal': 0xFFF59E0B, 'isContinuous': true, 'soundPath': 'sounds/tap_zerog.wav', 'scenePreview': 'Ecrã animado "JÁ VOLTAMOS" com música ambiente.'},
    {'label': 'PLAY / PAUSE', 'cmd': 'music_toggle', 'val': '', 'iconKey': 'music', 'colorVal': 0xFF10B981, 'isContinuous': false, 'soundPath': 'sounds/tap_glass.wav', 'scenePreview': 'Alterna reprodução da rádio/música de fundo.'},
    {'label': 'PRÓXIMA FAIXA', 'cmd': 'music_next', 'val': '', 'iconKey': 'skip', 'colorVal': 0xFF06B6D4, 'isContinuous': false, 'soundPath': 'sounds/tap_cyber.wav', 'scenePreview': 'Avança para a próxima rádio ou faixa.'},
    {'label': 'APLAUSOS', 'cmd': 'sound_clap', 'val': '', 'iconKey': 'clap', 'colorVal': 0xFF8B5CF6, 'isContinuous': false, 'soundPath': '$_sfxBase/crowds/applause.ogg', 'scenePreview': 'Efeito sonoro Aplausos da Plateia reproduzido!'},
    {'label': 'BUZINA MLG', 'cmd': 'sound_horn', 'val': '', 'iconKey': 'horn', 'colorVal': 0xFFF97316, 'isContinuous': false, 'soundPath': '$_sfxBase/alarms/air_horn.ogg', 'scenePreview': 'Efeito sonoro Buzina Épica disparado!'},
  ];

  void _executeKeyAction(int index, Map<String, dynamic> b) {
    final cmd = (b['cmd'] ?? '').toString();
    final val = (b['val'] ?? '').toString();
    final label = (b['label'] ?? 'Tecla').toString();
    final color = Color((b['colorVal'] as int?) ?? 0xFF38BDF8);
    final soundPath = (b['soundPath'] ?? 'sounds/tap_cyber.wav').toString();
    final ttsText = (b['ttsText'] ?? '').toString();
    final previewDesc = (b['scenePreview'] ?? 'Ação [$cmd] executada com sucesso na transmissão!').toString();

    _playDeckAudioOrTts(audioPath: soundPath, ttsText: ttsText);

    if (cmd == 'toggle_mute') {
      widget.onToggleMute();
    } else {
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

    if (_previewPopupEnabled && mounted) {
      LiveActionSimulator.showSimulatedOverlay(
        context,
        category: 'STREAM DECK · $label',
        title: label,
        subtitle: previewDesc,
        mediaUrl: b['imagePath']?.toString().startsWith('http') == true ? b['imagePath'].toString() : null,
        accent: color,
      );
    }
  }

  void _openProKeyEditorModal(int? editIndex) {
    final isEditing = editIndex != null;
    final existing = isEditing ? Map<String, dynamic>.from(_buttons[editIndex]) : <String, dynamic>{};

    final labelCtrl = TextEditingController(text: (existing['label'] ?? '').toString());
    final ttsCtrl = TextEditingController(text: (existing['ttsText'] ?? '').toString());
    final descCtrl = TextEditingController(text: (existing['scenePreview'] ?? '').toString());
    String selectedCmd = (existing['cmd'] ?? 'scene_game').toString();
    int selectedColor = (existing['colorVal'] as int?) ?? 0xFF38BDF8;
    bool isContinuous = existing['isContinuous'] == true;
    String? imagePath = existing['imagePath']?.toString();
    String? soundPath = existing['soundPath']?.toString();
    bool isRecordingVoice = false;

    const actionsList = <Map<String, String>>[
      {'cmd': 'play_sound_only', 'name': '🔊 Tocar Som / Voz / TTS'},
      {'cmd': 'scene_game', 'name': '🎮 Mudar para Cena Jogo'},
      {'cmd': 'scene_cam', 'name': '📷 Mudar para Câmara Full'},
      {'cmd': 'scene_brb', 'name': '⏸️ Mudar para Pausa / BRB'},
      {'cmd': 'toggle_mute', 'name': '🔇 Mutar / Ativar Microfone'},
      {'cmd': 'save_clip', 'name': '🎬 Criar Clipe 9:16 Agora'},
      {'cmd': 'music_toggle', 'name': '🎵 Música / Rádio Play / Pause'},
      {'cmd': 'music_next', 'name': '⏭️ Próxima Música / Rádio'},
      {'cmd': 'spin_wheel', 'name': '🎡 Girar Roleta 3D'},
      {'cmd': 'test_alert', 'name': '🔔 Disparar Alerta na Live'},
    ];

    if (!actionsList.any((a) => a['cmd'] == selectedCmd)) selectedCmd = 'play_sound_only';
    const palette = <int>[0xFF38BDF8, 0xFF1E78FF, 0xFF22C55E, 0xFFEF4444, 0xFFF59E0B, 0xFFA855F7, 0xFFEC4899, 0xFF14B8A6];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          title: Text(isEditing ? '🎛️ Personalizar Tecla' : '➕ Nova Tecla', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nome da Tecla', isDense: true)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCmd,
                  dropdownColor: const Color(0xFF050B1E),
                  decoration: const InputDecoration(labelText: 'Ação da Tecla', isDense: true),
                  items: actionsList.map((a) => DropdownMenuItem(value: a['cmd'], child: Text(a['name']!, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDlg(() => selectedCmd = v ?? 'scene_game'),
                ),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição da Cena na Pré-visualização', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: ttsCtrl, decoration: const InputDecoration(labelText: '🗣️ Frase Falada pela Voz TTS', isDense: true)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await OnlineMediaRepository.openOnlineLibraryPicker(context, initialTab: 'sounds', previewPlayer: _deckAudioPlayer);
                        if (picked != null && picked['url'] != null) setDlg(() => soundPath = picked['url']);
                      },
                      icon: const Icon(Icons.library_music_rounded, size: 15),
                      label: const Text('Sons Online', style: TextStyle(fontSize: 11)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await OnlineMediaRepository.openOnlineLibraryPicker(context, initialTab: 'gifs');
                        if (picked != null && picked['url'] != null) setDlg(() => imagePath = picked['url']);
                      },
                      icon: const Icon(Icons.gif_box_outlined, size: 15),
                      label: const Text('GIF / Imagem', style: TextStyle(fontSize: 11)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!isRecordingVoice) {
                          if (await _deckRecorder.hasPermission()) {
                            final dir = await getApplicationDocumentsDirectory();
                            await _deckRecorder.start(const RecordConfig(), path: '${dir.path}/deck_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
                      icon: Icon(isRecordingVoice ? Icons.stop : Icons.mic, size: 15),
                      label: Text(isRecordingVoice ? 'Parar' : 'Gravar Voz', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: palette.map((c) => GestureDetector(
                        onTap: () => setDlg(() => selectedColor = c),
                        child: CircleAvatar(radius: 12, backgroundColor: Color(c)),
                      )).toList(),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo Contínuo', style: TextStyle(fontSize: 11.5)),
                  value: isContinuous,
                  onChanged: (v) => setDlg(() => isContinuous = v),
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
              onPressed: () {
                final newKey = <String, dynamic>{
                  'label': labelCtrl.text.trim().isEmpty ? 'Tecla Pro' : labelCtrl.text.trim(),
                  'cmd': selectedCmd,
                  'val': 'true',
                  'iconKey': 'bolt',
                  'colorVal': selectedColor,
                  'isContinuous': isContinuous,
                  'imagePath': imagePath,
                  'soundPath': soundPath,
                  'ttsText': ttsCtrl.text.trim(),
                  'scenePreview': descCtrl.text.trim().isEmpty ? 'Simulação da ação "${labelCtrl.text.trim()}"!' : descCtrl.text.trim(),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleGlassDeckKey(int index, Map<String, dynamic> b) {
    final isMuteBtn = b['cmd'] == 'toggle_mute';
    final isOn = isMuteBtn ? widget.isMuted : (_activeContinuousStates[index] == true);
    final Color accent = isMuteBtn ? (widget.isMuted ? Colors.redAccent : Colors.greenAccent) : Color((b['colorVal'] as int?) ?? 0xFF38BDF8);
    final IconData iconData = isMuteBtn ? (widget.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded) : (_iconCatalog[b['iconKey']] ?? Icons.bolt_rounded);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOn
              ? [accent.withOpacity(0.58), accent.withOpacity(0.24), const Color(0xFF050B1E)]
              : [const Color(0xFF15285E).withOpacity(0.45), accent.withOpacity(0.14), const Color(0xFF04091A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOn ? Colors.white : accent.withOpacity(0.65), width: isOn ? 2.2 : 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: _rows >= 4 ? 22 : 28, color: isOn ? Colors.white : accent),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              isMuteBtn ? (widget.isMuted ? 'CORTADO' : 'SOM ATIVO') : (b['label'] ?? '').toString(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPerPage = _cols * _rows;
    final pageCount = (_buttons.length / totalPerPage).ceil().clamp(1, 20);

    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: const Color(0xFF0A122C),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF38BDF8)), onPressed: widget.onMinimizeDeck),
                  Expanded(child: Center(child: Text('STREAM DECK HELL · PÁG ${_currentPage + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)))),
                             IconButton(
             tooltip: 'Gravador de Episódios & Replay (0 MB no Telemóvel)',
             icon: const Icon(Icons.video_library_rounded, color: Colors.redAccent, size: 21),
             onPressed: () => showModalBottomSheet(
               context: context,
               isScrollControlled: true,
               backgroundColor: const Color(0xFF050B1E),
               builder: (_) => Padding(
                 padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                 child: SingleChildScrollView(
                   child: HellEpisodeRecorderPanel(onSendDeckCommand: widget.onSendCommand),

                 ),
               ),
             ),
           ),

                  IconButton(
                    icon: Icon(_previewPopupEnabled ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.cyanAccent, size: 20),
                    onPressed: () => setState(() => _previewPopupEnabled = !_previewPopupEnabled),
                  ),
                  IconButton(
                    icon: Icon(_editMode ? Icons.check_circle_rounded : Icons.edit_rounded, color: Colors.amberAccent, size: 20),
                    onPressed: () => setState(() => _editMode = !_editMode),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, color: Colors.greenAccent, size: 20),
                    onPressed: () => _openProKeyEditorModal(null),
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 20),
                    onPressed: _openPairDeviceDialog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemCount: pageCount,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * totalPerPage;
                  final end = (start + totalPerPage).clamp(0, _buttons.length);
                  final pageButtons = _buttons.sublist(start, end);
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pageButtons.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols, crossAxisSpacing: 10, mainAxisSpacing: 10),
                      itemBuilder: (ctx, idx) {
                        final realIndex = start + idx;
                        final b = _buttons[realIndex];
                        return GestureDetector(
                          onTap: () => _editMode ? _openProKeyEditorModal(realIndex) : _executeKeyAction(realIndex, b),
                          onLongPress: () => _openProKeyEditorModal(realIndex),
                          child: _buildSingleGlassDeckKey(realIndex, b),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceState {
  static final List<Map<String, dynamic>> studioPacks = <Map<String, dynamic>>[
    {'id': 'mp_1', 'title': 'Pack Overlays Néon Cyber 3D + Webcam HUD', 'creator': '@HELLCreator', 'category': 'Overlays & Webcam', 'price': 0.0, 'desc': 'Moldura webcam + barra de metas transparente.', 'owned': true},
    {'id': 'mp_2', 'title': 'Pack 25 Efeitos Sonoros & Alertas Épicos', 'creator': '@SofiaLive (VIP)', 'category': 'Sons & Áudio', 'price': 4.99, 'desc': 'Efeitos masterizados prontos a usar.', 'owned': false},
  ];

  static final List<Map<String, dynamic>> vipMerchProducts = <Map<String, dynamic>>[
    {'title': 'T-Shirt Oficial HELL CREATOR', 'seller': '@HELLCreator (VIP)', 'price': 24.90, 'desc': 'Algodão orgânico preto com emblema H Azul Néon.', 'url': 'https://hellcreator.app'},
    {'title': 'Caneca Térmica Streamer Pro', 'seller': '@SofiaLive (VIP)', 'price': 14.50, 'desc': 'Caneca preta fosca para lives.', 'url': 'https://hellcreator.app'},
  ];
}

class MarketplacePublicScreen extends StatefulWidget {
  final bool hasFreeOwnerOrStaffAccess;
  const MarketplacePublicScreen({super.key, this.hasFreeOwnerOrStaffAccess = false});

  @override
  State<MarketplacePublicScreen> createState() => _MarketplacePublicScreenState();
}

class _MarketplacePublicScreenState extends State<MarketplacePublicScreen> {
  String _billingCycle = 'Mensal';
  bool _isVipUnlocked = false;
  final TextEditingController _packTitleCtrl = TextEditingController();
  final TextEditingController _packPriceCtrl = TextEditingController(text: '5.00');
  final TextEditingController _merchTitleCtrl = TextEditingController();
  final TextEditingController _merchPriceCtrl = TextEditingController(text: '19.90');

  @override
  void dispose() {
    _packTitleCtrl.dispose();
    _packPriceCtrl.dispose();
    _merchTitleCtrl.dispose();
    _merchPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool vipActive = widget.hasFreeOwnerOrStaffAccess || _isVipUnlocked;
    final vipPrice = _billingCycle == '6 Meses' ? '49,99 € / 6 meses' : (_billingCycle == 'Anual' ? '89,99 € / ano' : '9,99 € / mês');
    final agencyPrice = _billingCycle == '6 Meses' ? '199,99 € / 6 meses' : (_billingCycle == 'Anual' ? '349,99 € / ano' : '39,99 € / mês');

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Color(0xFF38BDF8),
            tabs: [Tab(text: '🛒 Overlays & Sons'), Tab(text: '👕 Loja Merch VIP'), Tab(text: '👑 VIP & Agências'), Tab(text: '📢 Espaço Publicitário')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'ESTÚDIO DE CRIAÇÃO VIP · VENDER PACKS (APP RETÉM 30%)',
                      icon: Icons.design_services_rounded,
                      accent: const Color(0xFFA855F7),
                      badge: vipActive ? 'DESBLOQUEADO' : 'EXCLUSIVO VIP',
                      child: vipActive
                          ? Column(
                              children: [
                                TextField(controller: _packTitleCtrl, decoration: const InputDecoration(labelText: 'Nome do Overlay / Pack', isDense: true)),
                                const SizedBox(height: 6),
                                TextField(controller: _packPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (€) - App retém 30%', isDense: true)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (_packTitleCtrl.text.trim().isNotEmpty) {
                                      setState(() {
                                        MarketplaceState.studioPacks.insert(0, {
                                          'id': 'mp_${DateTime.now().millisecondsSinceEpoch}',
                                          'title': _packTitleCtrl.text.trim(),
                                          'creator': '@Tu (VIP)',
                                          'category': 'Overlays & Sons',
                                          'price': double.tryParse(_packPriceCtrl.text.replaceAll(',', '.')) ?? 5.0,
                                          'desc': 'Comissão plataforma 30% aplicada.',
                                          'owned': true,
                                        });
                                        _packTitleCtrl.clear();
                                      });
                                    }
                                  },
                                  child: const Text('Publicar na Loja'),
                                ),
                              ],
                            )
                          : const Text('A app base é gratuita! Assina o plano VIP para criar e vender overlays e sons na loja (70% para ti / 30% app).'),
                    ),
                    const SizedBox(height: 10),
                    ...MarketplaceState.studioPacks.map((item) => Card(
                          color: const Color(0xFF0B1636),
                          child: ListTile(
                            title: Text(item['title']),
                            subtitle: Text('${item['creator']} · ${item['desc']}'),
                            trailing: Text((item['price'] as num) == 0 ? 'GRÁTIS' : '${(item['price'] as num).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ),
                        )),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (vipActive) ...[
                      TextField(controller: _merchTitleCtrl, decoration: const InputDecoration(labelText: 'Nome do Produto (Camisola, Caneca...)', isDense: true)),
                      const SizedBox(height: 6),
                      TextField(controller: _merchPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (€)', isDense: true)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_merchTitleCtrl.text.trim().isNotEmpty) {
                            setState(() {
                              MarketplaceState.vipMerchProducts.insert(0, {
                                'title': _merchTitleCtrl.text.trim(),
                                'seller': '@Tu (VIP)',
                                'price': double.tryParse(_merchPriceCtrl.text.replaceAll(',', '.')) ?? 19.90,
                                'desc': 'Artigo oficial dentro das normas de segurança.',
                                'url': 'https://hellcreator.app',
                              });
                              _merchTitleCtrl.clear();
                            });
                          }
                        },
                        child: const Text('Adicionar à Minha Loja VIP'),
                      ),
                    ],
                    ...MarketplaceState.vipMerchProducts.map((prod) => Card(
                          color: const Color(0xFF0B1636),
                          child: ListTile(
                            title: Text(prod['title']),
                            subtitle: Text('${prod['seller']} · ${prod['desc']}'),
                            trailing: Text('${(prod['price'] as num).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            onTap: () => launchUrl(Uri.parse(prod['url']), mode: LaunchMode.externalApplication),
                          ),
                        )),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: <String>['Mensal', '6 Meses', 'Anual']
                          .map((c) => ChoiceChip(label: Text(c), selected: _billingCycle == c, onSelected: (_) => setState(() => _billingCycle = c)))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    HellCockpitWindow(
                      title: 'HELL VIP CRIADOR · $vipPrice',
                      icon: Icons.verified_rounded,
                      accent: const Color(0xFF38BDF8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• Símbolo VIP verificado no nome + Prioridade de destaque na Comunidade\n• Estúdio de criação de overlays/sons + Loja Pessoal Merch'),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: () => setState(() => _isVipUnlocked = true), child: Text(vipActive ? '✓ VIP Ativo' : 'Ativar VIP')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    HellCockpitWindow(
                      title: 'HELL AGÊNCIAS · $agencyPrice',
                      icon: Icons.apartment_rounded,
                      accent: const Color(0xFFA855F7),
                      child: const Text('Gestão e supervisão multi-criador para agências e equipas profissionais.'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    HellCockpitWindow(
                      title: 'PUBLICIDADE NO RODAPÉ DA APP',
                      icon: Icons.campaign_rounded,
                      accent: const Color(0xFF10B981),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• Starter Banner: 19,90 € / mês\n• Pro Destaque: 49,90 € / mês\n• Patrocinador Oficial: 129,90 € / mês'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => launchUrl(Uri.parse('mailto:hellcreatoros@gmail.com')),
                            child: const Text('Comprar Espaço Publicitário'),
                          ),
                        ],
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

