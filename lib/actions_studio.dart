import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'app_data.dart';
import 'live_connectors.dart';

class ActionsStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> giftsList;
  final List<Map<String, dynamic>> alertsList;
  final List<Map<String, dynamic>> goalsList;
  final List<Map<String, String>> mediaLibrary;
  final List<Map<String, String>> sounds;
  final AudioPlayer sfxPlayer;
  final Function(String) onSpeakVoice;
  final VoidCallback onStateChanged;

  const ActionsStudioScreen({
    super.key,
    required this.giftsList,
    required this.alertsList,
    required this.goalsList,
    required this.mediaLibrary,
    required this.sounds,
    required this.sfxPlayer,
    required this.onSpeakVoice,
    required this.onStateChanged,
  });

  @override
  State<ActionsStudioScreen> createState() => _ActionsStudioScreenState();
}

class _ActionsStudioScreenState extends State<ActionsStudioScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentlyPlayingUrl;
  bool _refreshingOnlineRepos = false;

  BoxDecoration _neonCard() => BoxDecoration(
        color: const Color(0xFF0B1636),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E78FF), width: 1.2),
      );

  Future<void> _refreshOnlineRepositories() async {
    setState(() => _refreshingOnlineRepos = true);
    try {
      const topics = ['gaming', 'fire', 'crown', 'trophy', 'rocket', 'heart', 'music', 'star'];
      for (final topic in topics) {
        final res = await http.get(Uri.parse('https://api.iconify.design/search?query=$topic&limit=18'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final icons = List<String>.from(data['icons'] ?? []);
          for (final ic in icons) {
            final parts = ic.split(':');
            if (parts.length == 2) {
              final url = 'https://api.iconify.design/${parts.first}/${parts.last}.png?height=96';
              if (!widget.mediaLibrary.any((m) => m['url'] == url)) {
                widget.mediaLibrary.add({'name': '${parts.last} ($topic)', 'url': url});
              }
            }
          }
        }
      }
      final soundRes = await http.get(Uri.parse('https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=filetype:audio+alert+OR+bell+OR+applause+OR+fanfare&srnamespace=6&srlimit=25&format=json'));
      if (soundRes.statusCode == 200) {
        final sData = jsonDecode(soundRes.body);
        final hits = List<Map<String, dynamic>>.from(sData['query']?['search'] ?? []);
        for (final h in hits) {
          final title = (h['title'] ?? '').toString().replaceFirst('File:', '');
          if (title.isNotEmpty) {
            final url = 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(title)}';
            if (!widget.sounds.any((s) => s['url'] == url)) {
              widget.sounds.add({'name': title.replaceAll('_', ' '), 'url': url});
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repositórios atualizados: ${widget.mediaLibrary.length} imagens e ${widget.sounds.length} sons prontos!'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _refreshingOnlineRepos = false);
  }

  Future<List<Map<String, String>>> _searchIconifyOnline(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final results = <Map<String, String>>[];
    try {
      final res = await http.get(Uri.parse('https://api.iconify.design/search?query=${Uri.encodeComponent(clean)}&limit=30'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final icons = List<String>.from(data['icons'] ?? []);
        for (final ic in icons) {
          final parts = ic.split(':');
          if (parts.length == 2) {
            results.add({
              'name': parts.last,
              'url': 'https://api.iconify.design/${parts.first}/${parts.last}.png?height=96',
            });
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Widget _renderMediaThumb(String path, {double size = 48}) {
    if (path.isEmpty) return Icon(Icons.image_outlined, color: const Color(0xFF38BDF8), size: size);
    if (path.startsWith('http')) {
      return Image.network(path, width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: size));
    }
    return Image.file(File(path), width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.image, size: size));
  }

  Future<void> _togglePlayAudio(String path, {bool isLocal = false, VoidCallback? onUpdate}) async {
    if (_currentlyPlayingUrl == path) {
      await widget.sfxPlayer.stop();
      setState(() => _currentlyPlayingUrl = null);
      onUpdate?.call();
      return;
    }
    await widget.sfxPlayer.stop();
    setState(() => _currentlyPlayingUrl = path);
    onUpdate?.call();
    try {
      if (isLocal || !path.startsWith('http')) {
        await widget.sfxPlayer.play(DeviceFileSource(path));
      } else {
        await widget.sfxPlayer.play(UrlSource(path));
      }
      widget.sfxPlayer.onPlayerComplete.listen((_) {
        if (mounted && _currentlyPlayingUrl == path) {
          setState(() => _currentlyPlayingUrl = null);
          onUpdate?.call();
        }
      });
    } catch (_) {
      setState(() => _currentlyPlayingUrl = null);
    }
  }

  void _openImagePicker(String currentMedia, Function(String) onPicked) {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> onlineResults = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF08112B),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final allItems = [...onlineResults, ...widget.mediaLibrary];
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SizedBox(
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('🖼️ Alterar Imagem · Repositórios Online', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
                      IconButton(
                        tooltip: 'Atualizar Repositório Online',
                        icon: _refreshingOnlineRepos
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
                        onPressed: () async {
                          await _refreshOnlineRepositories();
                          setModalState(() {});
                        },
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (res != null && res.files.single.path != null) {
                            onPicked(res.files.single.path!);
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Galeria / PC', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(hintText: 'Pesquisar milhares de imagens online...', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                        onPressed: () async {
                          setModalState(() => searching = true);
                          final hits = await _searchIconifyOnline(searchCtrl.text);
                          setModalState(() {
                            onlineResults = hits;
                            searching = false;
                          });
                        },
                        child: const Text('Buscar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (searching) const LinearProgressIndicator(),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: allItems.length,
                      itemBuilder: (_, i) {
                        final item = allItems[i];
                        final isSel = item['url'] == currentMedia;
                        return GestureDetector(
                          onTap: () {
                            onPicked(item['url']!);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF122E73) : const Color(0xFF0B1636),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? Colors.greenAccent : Colors.white12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(child: _renderMediaThumb(item['url']!, size: 38)),
                                Text(item['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openActionCustomizer({
    required String title,
    required String initialMedia,
    required String initialSound,
    required String? initialVoicePath,
    required bool initialTtsThank,
    required bool initialAutoRecognize,
    required String initialCode,
    required String? initialMsg,
    required String defaultTemplate,
    required Function(String media, String sound, String? voicePath, bool tts, bool autoRec, String code, String msg) onSave,
  }) {
    String chosenMedia = initialMedia;
    String chosenSound = initialSound;
    String? customVoicePath = initialVoicePath;
    bool ttsThank = initialTtsThank;
    bool autoRecognize = initialAutoRecognize;
    bool isRecording = false;
    final codeCtrl = TextEditingController(text: initialCode);
    final msgCtrl = TextEditingController(text: (initialMsg == null || initialMsg.isEmpty) ? defaultTemplate : initialMsg);
    final soundSearchCtrl = TextEditingController();
    String soundFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF08112B),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredSounds = widget.sounds.where((s) => soundFilter.isEmpty || (s['name'] ?? '').toLowerCase().contains(soundFilter.toLowerCase())).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SizedBox(
              height: 540,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Configurar: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
                      IconButton(
                        tooltip: 'Atualizar Repositórios de Sons & Imagens',
                        icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
                        onPressed: () async {
                          await _refreshOnlineRepositories();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: _neonCard(), child: _renderMediaThumb(chosenMedia, size: 52)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                          onPressed: () => _openImagePicker(chosenMedia, (newImg) => setModalState(() => chosenMedia = newImg)),
                          icon: const Icon(Icons.image, color: Colors.white),
                          label: const Text('Alterar Imagem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reconhecimento Automático na Live (Gatilho Ativo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Deteta o código/nome em direto e dispara som + voz.', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    value: autoRecognize,
                    onChanged: (v) => setModalState(() => autoRecognize = v),
                  ),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Código / Palavra-chave de Reconhecimento (ex: rose, lion, follow)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Agradecimento Automático por Voz Google', style: TextStyle(fontSize: 13)),
                    value: ttsThank,
                    onChanged: (v) => setModalState(() => ttsThank = v),
                  ),
                  TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(labelText: 'Mensagem Lida na Live (usa {user} para o nome)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : const Color(0xFF122E73)),
                        onPressed: () async {
                          if (!isRecording) {
                            if (await _recorder.hasPermission()) {
                              final dir = await getTemporaryDirectory();
                              final p = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                              await _recorder.start(const RecordConfig(), path: p);
                              setModalState(() => isRecording = true);
                            }
                          } else {
                            final path = await _recorder.stop();
                            setModalState(() {
                              isRecording = false;
                              if (path != null) {
                                customVoicePath = path;
                                chosenSound = '';
                              }
                            });
                          }
                        },
                        icon: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 18),
                        label: Text(isRecording ? 'Parar' : 'Gravar Voz Própria', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                          if (res != null && res.files.single.path != null) {
                            setModalState(() {
                              chosenSound = res.files.single.path!;
                              customVoicePath = null;
                              widget.sounds.insert(0, {'name': res.files.single.name, 'url': res.files.single.path!});
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('+ Som/Música', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: soundSearchCtrl,
                    onChanged: (v) => setModalState(() => soundFilter = v),
                    decoration: const InputDecoration(hintText: 'Filtrar biblioteca de sons...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 6),
                  ...filteredSounds.take(25).map((s) {
                    final url = s['url']!;
                    final isSel = chosenSound == url;
                    final isPlay = _currentlyPlayingUrl == url;
                    return ListTile(
                      dense: true,
                      leading: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSel ? Colors.greenAccent : const Color(0xFF38BDF8)),
                      title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: Icon(isPlay ? Icons.stop_circle : Icons.play_circle_fill, color: isPlay ? Colors.redAccent : Colors.greenAccent),
                        onPressed: () => _togglePlayAudio(url, onUpdate: () => setModalState(() {})),
                      ),
                      onTap: () => setModalState(() {
                        chosenSound = url;
                        customVoicePath = null;
                      }),
                    );
                  }),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: () async {
                      await widget.sfxPlayer.stop();
                      setState(() => _currentlyPlayingUrl = null);
                      onSave(chosenMedia, chosenSound, customVoicePath, ttsThank, autoRecognize, codeCtrl.text.trim(), msgCtrl.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Guardar Configuração', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalOverlayWidget(String type, double pct, String title, int current, int target) {
    final pctInt = (pct * 100).round();
    final isGold = type == 'gold_vip';
    final accent = isGold ? const Color(0xFFFACC15) : const Color(0xFF38BDF8);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050B1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 13.5)),
              Text('$current / $target ($pctInt%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 14,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniformItemCard({
    required String title,
    required String subtitle,
    required String mediaUrl,
    required bool enabled,
    required VoidCallback onEdit,
    required VoidCallback onPlay,
    required VoidCallback onDelete,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: _neonCard(),
      child: Row(
        children: [
          GestureDetector(onTap: onEdit, child: _renderMediaThumb(mediaUrl, size: 46)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent), onPressed: onPlay),
          IconButton(icon: const Icon(Icons.tune, color: Color(0xFF38BDF8)), onPressed: onEdit),
          Switch(value: enabled, activeColor: const Color(0xFF38BDF8), onChanged: onToggle),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: onDelete),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayGoalsUrl = 'http://${LocalObsServer.localIp}:${LocalObsServer.port}/overlay?widget=goals';
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                const Expanded(child: Text('⚡ Ações & Reconhecimento Automático', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
                IconButton(
                  tooltip: 'Atualizar Repositórios Online (Imagens & Sons)',
                  icon: _refreshingOnlineRepos
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
                  onPressed: _refreshOnlineRepositories,
                ),
              ],
            ),
          ),
          const TabBar(
            indicatorColor: Color(0xFF38BDF8),
            labelColor: Color(0xFF38BDF8),
            unselectedLabelColor: Colors.white60,
            tabs: [Tab(text: 'Presentes'), Tab(text: 'Alertas'), Tab(text: 'Metas & Overlay')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                      onPressed: () => setState(() {
                        widget.giftsList.insert(0, {
                          'id': 'g_${DateTime.now().millisecondsSinceEpoch}',
                          'code': 'custom_gift',
                          'name': 'Novo Presente Especial',
                          'coins': 10,
                          'enabled': true,
                          'autoRecognize': true,
                          'ttsThank': true,
                          'customMessage': 'Obrigado {user} pelo presente especial!',
                          'customVoicePath': null,
                          'png': DefaultMediaLibrary.builtInGifsAndPngs.first['url']!,
                          'sound': '',
                        });
                      }),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('+ Adicionar Presente para Reconhecimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    ...widget.giftsList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final g = entry.value;
                      return _buildUniformItemCard(
                        title: '${g['name']} (${g['coins']} moedas)',
                        subtitle: 'Código: ${g['code']} · ${g['autoRecognize'] == true ? "Reconhecimento Auto ATIVO" : "Manual"}',
                        mediaUrl: g['png'] ?? '',
                        enabled: g['enabled'] == true,
                        onDelete: () => setState(() => widget.giftsList.removeAt(idx)),
                        onToggle: (v) => setState(() => g['enabled'] = v),
                        onPlay: () {
                          final msg = (g['customMessage'] ?? 'Obrigado {user} pelo ${g['name']}!').toString().replaceAll('{user}', 'Apoiante');
                          LocalObsServer.pushAlert('${g['name']}', msg, g['png'] ?? '');
                          if ((g['sound'] ?? '').toString().isNotEmpty) _togglePlayAudio(g['sound']);
                          if (g['ttsThank'] == true) widget.onSpeakVoice(msg);
                        },
                        onEdit: () => _openActionCustomizer(
                          title: g['name'] ?? 'Presente',
                          initialMedia: g['png'] ?? '',
                          initialSound: g['sound'] ?? '',
                          initialVoicePath: g['customVoicePath'],
                          initialTtsThank: g['ttsThank'] ?? true,
                          initialAutoRecognize: g['autoRecognize'] ?? true,
                          initialCode: g['code'] ?? '',
                          initialMsg: g['customMessage'],
                          defaultTemplate: 'Muito obrigado {user} pelo ${g['name']}!',
                          onSave: (m, s, vp, tts, autoR, code, msg) => setState(() {
                            g['png'] = m;
                            g['sound'] = s;
                            g['customVoicePath'] = vp;
                            g['ttsThank'] = tts;
                            g['autoRecognize'] = autoR;
                            g['code'] = code;
                            g['customMessage'] = msg;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                      onPressed: () => setState(() {
                        widget.alertsList.insert(0, {
                          'id': 'al_${DateTime.now().millisecondsSinceEpoch}',
                          'trigger': 'follow',
                          'name': 'Novo Alerta Automático',
                          'enabled': true,
                          'autoRecognize': true,
                          'ttsThank': true,
                          'customMessage': 'Bem-vindo {user}! Obrigado pelo apoio!',
                          'customVoicePath': null,
                          'media': DefaultMediaLibrary.builtInGifsAndPngs.first['url']!,
                          'sound': '',
                        });
                      }),
                      icon: const Icon(Icons.add_alert, color: Colors.white),
                      label: const Text('+ Criar Novo Alerta Automático', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    ...widget.alertsList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final al = entry.value;
                      return _buildUniformItemCard(
                        title: al['name'] ?? 'Alerta',
                        subtitle: 'Gatilho: ${al['trigger']} · ${al['autoRecognize'] != false ? "Auto ATIVO" : "Manual"}',
                        mediaUrl: al['media'] ?? '',
                        enabled: al['enabled'] == true,
                        onDelete: () => setState(() => widget.alertsList.removeAt(idx)),
                        onToggle: (v) => setState(() => al['enabled'] = v),
                        onPlay: () {
                          final msg = (al['customMessage'] ?? '{user} ativou ${al['name']}!').toString().replaceAll('{user}', 'Apoiante');
                          LocalObsServer.pushAlert('${al['name']}', msg, al['media'] ?? '');
                          if ((al['sound'] ?? '').toString().isNotEmpty) _togglePlayAudio(al['sound']);
                          if (al['ttsThank'] == true) widget.onSpeakVoice(msg);
                        },
                        onEdit: () => _openActionCustomizer(
                          title: al['name'] ?? 'Alerta',
                          initialMedia: al['media'] ?? '',
                          initialSound: al['sound'] ?? '',
                          initialVoicePath: al['customVoicePath'],
                          initialTtsThank: al['ttsThank'] ?? true,
                          initialAutoRecognize: al['autoRecognize'] ?? true,
                          initialCode: al['trigger'] ?? 'follow',
                          initialMsg: al['customMessage'],
                          defaultTemplate: 'Obrigado {user}! ${al['name']}!',
                          onSave: (m, s, vp, tts, autoR, code, msg) => setState(() {
                            al['media'] = m;
                            al['sound'] = s;
                            al['customVoicePath'] = vp;
                            al['ttsThank'] = tts;
                            al['autoRecognize'] = autoR;
                            al['trigger'] = code;
                            al['customMessage'] = msg;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _neonCard(),
                      child: Row(
                        children: [
                          const Icon(Icons.layers, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Overlay Metas OBS / Studio:
$overlayGoalsUrl', style: const TextStyle(fontSize: 11.5))),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Color(0xFF38BDF8)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: overlayGoalsUrl));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link Overlay Metas copiado!')));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...widget.goalsList.map((goal) {
                      final cur = goal['current'] ?? 0;
                      final tgt = (goal['target'] ?? 1000) == 0 ? 1000 : goal['target'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildGoalOverlayWidget(goal['overlayType'] ?? 'neon', (cur / tgt).clamp(0.0, 1.0), goal['title'] ?? 'Meta', cur, tgt),
                      );
                    }),
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
