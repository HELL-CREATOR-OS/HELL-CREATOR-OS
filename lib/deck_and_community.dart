import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'live_connectors.dart';


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

  void _addNewKey() {
    final labelCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    bool isContinuous = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          title: const Text('+ Adicionar Tecla', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nome da Tecla', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Ação / Comando', isDense: true)),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo Contínuo (Fica aceso ao ativar)', style: TextStyle(fontSize: 12)),
                value: isContinuous,
                onChanged: (v) => setDlg(() => isContinuous = v),
              ),
            ],
          ),
   actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
              onPressed: () {
                if (labelCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _buttons.add({
                      'label': labelCtrl.text.trim(),
                      'cmd': 'custom_action',
                      'val': valCtrl.text.trim(),
                      'iconKey': 'bolt',
                      'colorVal': 0xFF38BDF8,
                      'isContinuous': isContinuous,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Adicionar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editKeyModal(int index) {
    final b = _buttons[index];
    final labelCtrl = TextEditingController(text: (b['label'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        title: const Text('Editar Tecla', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        content: TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nome da Tecla', isDense: true)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _buttons.removeAt(index));
              Navigator.pop(ctx);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              setState(() => b['label'] = labelCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget _buildSingleGlassDeckKey(int index, Map<String, dynamic> b) {
    final isMuteBtn = b['cmd'] == 'toggle_mute';
    final isContinuous = b['isContinuous'] == true;
    final isOn = isMuteBtn ? widget.isMuted : (_activeContinuousStates[index] == true);
    final Color accent = isMuteBtn ? (widget.isMuted ? Colors.redAccent : Colors.greenAccent) : Color(b['colorVal'] as int);
    final IconData iconData = isMuteBtn ? (widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded) : (_iconCatalog[b['iconKey']] ?? Icons.bolt_rounded);
    final String? imgPath = b['imagePath'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
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
      child: Stack(
        children: [
          if (isContinuous)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isOn ? Colors.greenAccent : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imgPath != null && File(imgPath).existsSync())
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(imgPath), width: 34, height: 34, fit: BoxFit.cover))
                else
                  Icon(iconData, size: _rows == 2 ? 32 : 24, color: isOn ? Colors.white : accent),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    isMuteBtn ? (widget.isMuted ? 'CORTADO' : 'SOM ATIVO') : (b['label'] as String),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSyncQrModal() {
    final code = widget.generatedCode ?? 'HELL-482910';
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
        title: const Text('📱 Sincronizar 2.º Ecrã (QR / Código)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: QrImageView(data: 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/deck?room=$code', version: QrVersions.auto, size: 150),
            ),
            const SizedBox(height: 10),
            SelectableText('Código: $code', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(hintText: 'Ou introduz código de outro aparelho...', isDense: true, border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty) {
                widget.onJoinWithCode(codeCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Validar Código', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

   bool _editMode = false;
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
                      icon: Icon(_editMode ? Icons.check_circle_rounded : Icons.edit_rounded, color: _editMode ? Colors.greenAccent : Colors.amberAccent, size: 21),
                      tooltip: _editMode ? 'Concluir Edição' : 'Editar Teclas',
                      onPressed: () => setState(() => _editMode = !_editMode),
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
                                            onTap: () => _editMode ? _editKeyModal(realIndex) : _executeKeyAction(realIndex, b),
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
1. 

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
