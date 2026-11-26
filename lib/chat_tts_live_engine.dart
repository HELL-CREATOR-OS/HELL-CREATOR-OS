import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HellLiveChatMessage {
  final String id;
  final String platform; // 'tiktok', 'twitch', 'youtube', 'kick'
  final String sender;
  final String text;
  final String badge; // 'VIP', 'MOD', 'SUB', 'GIFT', ''
  final bool isGiftOrDonation;
  final String giftInfo;
  final DateTime timestamp;

  HellLiveChatMessage({
    required this.id,
    required this.platform,
    required this.sender,
    required this.text,
    this.badge = '',
    this.isGiftOrDonation = false,
    this.giftInfo = '',
    required this.timestamp,
  });
}

class HellOriginalVoiceProfile {
  final String id;
  final String label;
  final String gender; // 'M' ou 'F'
  final double basePitchHz;
  final double formantShift;
  final double speedFactor;
  final double wobbleIntensity;

  const HellOriginalVoiceProfile({
    required this.id,
    required this.label,
    required this.gender,
    required this.basePitchHz,
    required this.formantShift,
    required this.speedFactor,
    this.wobbleIntensity = 0.0,
  });
}

class HellOriginalVoiceSynthesizer {
  static Future<String> synthesizeToWavFile(String rawText, HellOriginalVoiceProfile profile) async {
    const int sampleRate = 22050;
    final clean = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zàáâãéêíóôõúüç0-9\s\.,!\?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final String text = clean.isEmpty ? 'olá' : clean;
    final List<int> pcmSamples = <int>[];
    final math.Random rng = math.Random(text.hashCode);

    double phase = 0.0;
    int globalSample = 0;

    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (ch == ' ') {
        final int pauseSamples = (sampleRate * 0.065 / profile.speedFactor).round();
        pcmSamples.addAll(List<int>.filled(pauseSamples, 0));
        globalSample += pauseSamples;
        continue;
      }
      if (ch == ',' || ch == '.' || ch == '!' || ch == '?') {
        final int punctSamples = (sampleRate * 0.16 / profile.speedFactor).round();
        pcmSamples.addAll(List<int>.filled(punctSamples, 0));
        globalSample += punctSamples;
        continue;
      }

      final bool isVowel = 'aàáâãeéêiíoóôõuúü'.contains(ch);
      final double charDurSec = (isVowel ? 0.088 : 0.052) / profile.speedFactor;
      final int numSamples = (sampleRate * charDurSec).round();

      double f1 = 500.0 * profile.formantShift;
      double f2 = 1500.0 * profile.formantShift;
      if ('aàáâã'.contains(ch)) {
        f1 = 730.0 * profile.formantShift;
        f2 = 1090.0 * profile.formantShift;
      } else if ('eéê'.contains(ch)) {
        f1 = 530.0 * profile.formantShift;
        f2 = 1840.0 * profile.formantShift;
      } else if ('ií'.contains(ch)) {
        f1 = 270.0 * profile.formantShift;
        f2 = 2290.0 * profile.formantShift;
      } else if ('oóôõ'.contains(ch)) {
        f1 = 570.0 * profile.formantShift;
        f2 = 840.0 * profile.formantShift;
      } else if ('uúü'.contains(ch)) {
        f1 = 300.0 * profile.formantShift;
        f2 = 870.0 * profile.formantShift;
      }

      for (int s = 0; s < numSamples; s++) {
        final double t = globalSample / sampleRate;
        final double env = math.sin((s / numSamples) * math.pi);

        double pitchMod = 1.0 - (i / math.max(1, text.length)) * 0.08;
        if (profile.wobbleIntensity > 0) {
          pitchMod += math.sin(t * 7.5) * profile.wobbleIntensity;
        }
        final double f0 = (profile.basePitchHz * pitchMod).clamp(65.0, 420.0);
        phase += (2.0 * math.pi * f0) / sampleRate;

        final double glottal = math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase);
        final double formantWave = 0.6 * math.sin(2 * math.pi * f1 * t) + 0.35 * math.sin(2 * math.pi * f2 * t);
        final double consonantNoise = isVowel ? 0.0 : (rng.nextDouble() * 2.0 - 1.0) * 0.28;

        final double sampleVal = ((glottal * 0.45 + formantWave * 0.45 + consonantNoise) * env * 14500.0).clamp(-32000.0, 32000.0);
        pcmSamples.add(sampleVal.round());
        globalSample++;
      }
    }

    final int dataByteLen = pcmSamples.length * 2;
    final ByteData header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big);
    header.setUint32(4, 36 + dataByteLen, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big);
    header.setUint32(12, 0x666d7420, Endian.big);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint32(36, 0x64617461, Endian.big);
    header.setUint32(40, dataByteLen, Endian.little);

    final BytesBuilder out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    final ByteData pcmBytes = ByteData(dataByteLen);
    for (int k = 0; k < pcmSamples.length; k++) {
      pcmBytes.setInt16(k * 2, pcmSamples[k], Endian.little);
    }
    out.add(pcmBytes.buffer.asUint8List());

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hell_voice_${DateTime.now().microsecondsSinceEpoch}.wav');
    await file.writeAsBytes(out.toBytes(), flush: true);
    return file.path;
  }
}
class HellChatTtsController extends ChangeNotifier {
  static const List<HellOriginalVoiceProfile> builtInVoices = <HellOriginalVoiceProfile>[
    HellOriginalVoiceProfile(
      id: 'adult_announcer_m',
      label: 'Adulto Locutor (Masculina Real)',
      gender: 'M',
      basePitchHz: 106.0,
      formantShift: 0.86,
      speedFactor: 0.96,
    ),
    HellOriginalVoiceProfile(
      id: 'young_energetic_m',
      label: 'Jovem Enérgico (Masculina)',
      gender: 'M',
      basePitchHz: 142.0,
      formantShift: 0.95,
      speedFactor: 1.18,
    ),
    HellOriginalVoiceProfile(
      id: 'adult_calm_m',
      label: 'Adulto Calmo (Masculina)',
      gender: 'M',
      basePitchHz: 116.0,
      formantShift: 0.89,
      speedFactor: 0.84,
    ),
    HellOriginalVoiceProfile(
      id: 'adult_stressed_m',
      label: 'Adulto Stressado (Masculina)',
      gender: 'M',
      basePitchHz: 164.0,
      formantShift: 0.98,
      speedFactor: 1.28,
      wobbleIntensity: 0.08,
    ),
    HellOriginalVoiceProfile(
      id: 'adult_tipsy_m',
      label: 'Adulto Embriagado · Humor Live',
      gender: 'M',
      basePitchHz: 104.0,
      formantShift: 0.85,
      speedFactor: 0.72,
      wobbleIntensity: 0.18,
    ),
    HellOriginalVoiceProfile(
      id: 'adult_tired_m',
      label: 'Adulto Cansado / Sonolento',
      gender: 'M',
      basePitchHz: 96.0,
      formantShift: 0.84,
      speedFactor: 0.76,
    ),
    HellOriginalVoiceProfile(
      id: 'child_voice',
      label: 'Criança / Juvenil (Aguda)',
      gender: 'F',
      basePitchHz: 285.0,
      formantShift: 1.24,
      speedFactor: 1.14,
    ),
    HellOriginalVoiceProfile(
      id: 'adult_announcer_f',
      label: 'Adulta Locutora (Feminina Real)',
      gender: 'F',
      basePitchHz: 215.0,
      formantShift: 1.12,
      speedFactor: 1.00,
    ),
  ];

  final AudioPlayer _player = AudioPlayer();
  final List<HellLiveChatMessage> messages = <HellLiveChatMessage>[];
  final List<String> _speechQueue = <String>[];
  final List<String> musicRequests = <String>[];
  final List<HellOriginalVoiceProfile> clonedVoices = <HellOriginalVoiceProfile>[];

  bool ttsEnabled = true;
  bool isSpeaking = false;
  String selectedVoiceId = 'adult_announcer_m';
  String readFilter = 'all';
  int maxChars = 140;
  bool readSenderName = true;
  bool filterSpam = true;

  List<String> blockedWords = <String>['http://', 'https://', 'www.'];
  Map<String, String> chatCommands = <String>{
    '!discord': 'Entra na nossa comunidade oficial no Discord!',
    '!loja': 'Visita o Marketplace oficial HELL CREATOR na app!',
    '!comandos': 'Comandos disponíveis: !discord · !loja · !pedir <música> · !falar <texto>',
  };

  WebSocket? _twitchSocket;
  bool twitchConnected = false;
  String twitchChannel = '';

  List<HellOriginalVoiceProfile> get allAvailableVoices =>
      <HellOriginalVoiceProfile>[...clonedVoices, ...builtInVoices];

  HellOriginalVoiceProfile get currentVoice => allAvailableVoices.firstWhere(
        (v) => v.id == selectedVoiceId,
        orElse: () => builtInVoices.first,
      );

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    ttsEnabled = p.getBool('hell_tts_enabled_v3') ?? true;
    selectedVoiceId = p.getString('hell_tts_voice_id_v3') ?? 'adult_announcer_m';
    readFilter = p.getString('hell_tts_filter_v3') ?? 'all';
    maxChars = p.getInt('hell_tts_maxchars_v3') ?? 140;
    readSenderName = p.getBool('hell_tts_read_sender_v3') ?? true;
    twitchChannel = p.getString('hell_platform_handle_twitch') ?? '';

    final rawClones = p.getString('hell_cloned_voices_v3');
    if (rawClones != null && rawClones.isNotEmpty) {
      try {
        final list = jsonDecode(rawClones) as List;
        clonedVoices.clear();
        for (final item in list) {
          final m = Map<String, dynamic>.from(item as Map);
          clonedVoices.add(HellOriginalVoiceProfile(
            id: m['id'].toString(),
            label: m['label'].toString(),
            gender: (m['gender'] ?? 'M').toString(),
            basePitchHz: (m['basePitchHz'] as num).toDouble(),
            formantShift: (m['formantShift'] as num).toDouble(),
            speedFactor: (m['speedFactor'] as num).toDouble(),
          ));
        }
      } catch (_) {}
    }

    _player.onPlayerComplete.listen((_) {
      isSpeaking = false;
      _processNextInQueue();
    });
    notifyListeners();
  }

  Future<void> saveClonedVoice({
    required String name,
    required double measuredPitchHz,
    required double measuredFormantShift,
    required double measuredSpeedFactor,
  }) async {
    final id = 'clone_${DateTime.now().millisecondsSinceEpoch}';
    final profile = HellOriginalVoiceProfile(
      id: id,
      label: '🎙️ Voz Clonada · $name',
      gender: measuredPitchHz < 170 ? 'M' : 'F',
      basePitchHz: measuredPitchHz.clamp(85.0, 260.0),
      formantShift: measuredFormantShift.clamp(0.82, 1.20),
      speedFactor: measuredSpeedFactor.clamp(0.80, 1.25),
    );
    clonedVoices.insert(0, profile);
    selectedVoiceId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'hell_cloned_voices_v3',
      jsonEncode(clonedVoices
          .map((v) => <String, dynamic>{
                'id': v.id,
                'label': v.label,
                'gender': v.gender,
                'basePitchHz': v.basePitchHz,
                'formantShift': v.formantShift,
                'speedFactor': v.speedFactor,
              })
          .toList()),
    );
    await p.setString('hell_tts_voice_id_v3', id);
    notifyListeners();
  }
  Future<void> setSelectedVoice(String voiceId) async {
    selectedVoiceId = voiceId;
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_tts_voice_id_v3', voiceId);
    notifyListeners();
  }

  Future<void> toggleTts(bool value) async {
    ttsEnabled = value;
    if (!value) await stopAndClearQueue();
    final p = await SharedPreferences.getInstance();
    await p.setBool('hell_tts_enabled_v3', value);
    notifyListeners();
  }

  Future<void> stopAndClearQueue() async {
    _speechQueue.clear();
    await _player.stop();
    isSpeaking = false;
    notifyListeners();
  }

  Future<void> skipCurrentSpeech() async {
    await _player.stop();
    isSpeaking = false;
    _processNextInQueue();
  }

  String _sanitizeForSpeech(String raw) {
    String clean = raw.trim();
    for (final bad in blockedWords) {
      if (bad.isNotEmpty && clean.toLowerCase().contains(bad.toLowerCase())) {
        return '';
      }
    }
    if (filterSpam) {
      clean = clean.replaceAllMapped(RegExp(r'(.)\1{3,}'), (m) => '${m.group(1)}${m.group(1)}');
    }
    clean = clean
        .replaceAll(RegExp(r'\bpq\b', caseSensitive: false), 'porque')
        .replaceAll(RegExp(r'\bvc\b', caseSensitive: false), 'você')
        .replaceAll(RegExp(r'\btb\b', caseSensitive: false), 'também')
        .replaceAll(RegExp(r'\bmt\b', caseSensitive: false), 'muito')
        .replaceAll(RegExp(r'\bvlw\b', caseSensitive: false), 'valeu')
        .replaceAll(RegExp(r'\bobs\b', caseSensitive: false), 'ó bê ésse');

    if (clean.length > maxChars) {
      clean = clean.substring(0, maxChars);
    }
    return clean.trim();
  }

  Future<void> speakImmediateTest(String sampleText) async {
    await _player.stop();
    isSpeaking = true;
    notifyListeners();
    try {
      final wavPath = await HellOriginalVoiceSynthesizer.synthesizeToWavFile(sampleText, currentVoice);
      await _player.play(DeviceFileSource(wavPath));
    } catch (_) {
      isSpeaking = false;
      notifyListeners();
    }
  }

  void enqueueSpeech(String text) {
    if (!ttsEnabled || text.trim().isEmpty) return;
    _speechQueue.add(text.trim());
    if (!isSpeaking) {
      _processNextInQueue();
    }
  }

  Future<void> _processNextInQueue() async {
    if (_speechQueue.isEmpty || !ttsEnabled) {
      isSpeaking = false;
      notifyListeners();
      return;
    }
    isSpeaking = true;
    notifyListeners();
    final nextText = _speechQueue.removeAt(0);
    try {
      final wavPath = await HellOriginalVoiceSynthesizer.synthesizeToWavFile(nextText, currentVoice);
      await _player.play(DeviceFileSource(wavPath));
    } catch (_) {
      isSpeaking = false;
      _processNextInQueue();
    }
  }

  void ingestIncomingMessage(HellLiveChatMessage msg) {
    messages.insert(0, msg);
    if (messages.length > 150) {
      messages.removeLast();
    }

    final lower = msg.text.trim().toLowerCase();
    if (lower.startsWith('!pedir ')) {
      final song = msg.text.trim().substring(7).trim();
      if (song.isNotEmpty) {
        musicRequests.insert(0, '$song (pedido por ${msg.sender})');
      }
    }

    bool allowedByFilter = true;
    if (readFilter == 'vip_sub') {
      allowedByFilter = msg.badge == 'VIP' || msg.badge == 'SUB' || msg.badge == 'MOD' || msg.isGiftOrDonation;
    } else if (readFilter == 'gifts') {
      allowedByFilter = msg.isGiftOrDonation;
    } else if (readFilter == 'command') {
      allowedByFilter = lower.startsWith('!falar ');
    }

    if (allowedByFilter && ttsEnabled) {
      String textToRead = lower.startsWith('!falar ') ? msg.text.trim().substring(7) : msg.text;
      final sanitized = _sanitizeForSpeech(textToRead);
      if (sanitized.isNotEmpty) {
        final prefix = msg.isGiftOrDonation
            ? '${msg.sender} enviou ${msg.giftInfo}. '
            : (readSenderName ? '${msg.sender} disse: ' : '');
        enqueueSpeech('$prefix$sanitized');
      }
    }
    notifyListeners();
  }

  Future<void> connectTwitchPublicChat(String rawChannel) async {
    final clean = rawChannel.replaceAll('@', '').trim().toLowerCase();
    if (clean.isEmpty) return;
    await disconnectTwitchChat();
    twitchChannel = clean;
    try {
      _twitchSocket = await WebSocket.connect('wss://irc-ws.chat.twitch.tv:443');
      _twitchSocket!.add('CAP REQ :twitch.tv/tags twitch.tv/commands');
      _twitchSocket!.add('PASS SCHMOOPIIE');
      _twitchSocket!.add('NICK justinfan${DateTime.now().millisecondsSinceEpoch % 89999 + 10000}');
      _twitchSocket!.add('JOIN #$clean');
      twitchConnected = true;
      notifyListeners();

      _twitchSocket!.listen(
        (dynamic data) {
          final lines = data.toString().split('\r\n');
          for (final line in lines) {
            if (line.startsWith('PING')) {
              _twitchSocket?.add('PONG :tmi.twitch.tv');
            } else if (line.contains(' PRIVMSG #$clean :')) {
              final msgIdx = line.indexOf(' PRIVMSG #$clean :');
              final text = line.substring(msgIdx + ' PRIVMSG #$clean :'.length).trim();
              String sender = 'ViewerTwitch';
              final userMatch = RegExp(r':([^!]+)!').firstMatch(line);
              if (userMatch != null) sender = userMatch.group(1) ?? sender;
              String badge = '';
              if (line.contains('moderator=1')) badge = 'MOD';
              else if (line.contains('subscriber=1')) badge = 'SUB';
              else if (line.contains('vip/1')) badge = 'VIP';

              ingestIncomingMessage(HellLiveChatMessage(
                id: 'tw_${DateTime.now().microsecondsSinceEpoch}',
                platform: 'twitch',
                sender: sender,
                text: text,
                badge: badge,
                timestamp: DateTime.now(),
              ));
            }
          }
        },
        onDone: () {
          twitchConnected = false;
          notifyListeners();
        },
        onError: (_) {
          twitchConnected = false;
          notifyListeners();
        },
      );
    } catch (_) {
      twitchConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnectTwitchChat() async {
    await _twitchSocket?.close();
    _twitchSocket = null;
    twitchConnected = false;
    notifyListeners();
  }
}
class HellChatAndTtsLiveScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const HellChatAndTtsLiveScreen({super.key, this.currentUser});

  @override
  State<HellChatAndTtsLiveScreen> createState() => _HellChatAndTtsLiveScreenState();
}

class _HellChatAndTtsLiveScreenState extends State<HellChatAndTtsLiveScreen> {
  final HellChatTtsController _ctrl = HellChatTtsController();
  final TextEditingController _twitchCtrl = TextEditingController();
  final TextEditingController _testMsgCtrl = TextEditingController(
    text: 'Bem-vindos à live oficial HELL CREATOR! Como está toda a gente hoje?',
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onUpdate);
    _ctrl.init().then((_) {
      if (mounted) _twitchCtrl.text = _ctrl.twitchChannel;
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    _ctrl.disconnectTwitchChat();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openVoiceCloningTeleprompter() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HellVoiceCloneTeleprompterDialog(
        defaultOwnerName: (widget.currentUser?['displayName'] ?? 'Criador').toString(),
        onVoiceCloned: (name, pitchHz, formantShift, speedFactor) async {
          await _ctrl.saveClonedVoice(
            name: name,
            measuredPitchHz: pitchHz,
            measuredFormantShift: formantShift,
            measuredSpeedFactor: speedFactor,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('🎙️ Voz clonada "$name" criada e selecionada com sucesso!')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voices = _ctrl.allAvailableVoices;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1636),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'MOTOR DE VOZES ORIGINAIS HELL & CLONAGEM IA',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF38BDF8)),
                    ),
                  ),
                  Switch(
                    value: _ctrl.ttsEnabled,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) => _ctrl.toggleTts(v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: voices.any((v) => v.id == _ctrl.selectedVoiceId) ? _ctrl.selectedVoiceId : voices.first.id,
                dropdownColor: const Color(0xFF0B1636),
                decoration: const InputDecoration(labelText: 'Voz Ativa (Masculinas, Femininas & Clonadas)', isDense: true),
                items: voices
                    .map((v) => DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(v.label, style: const TextStyle(fontSize: 12.5)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _ctrl.setSelectedVoice(v);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ctrl.speakImmediateTest(_testMsgCtrl.text),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Testar Voz Agora', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      onPressed: _openVoiceCloningTeleprompter,
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('Clonar Minha Voz (2m)', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _testMsgCtrl,
                decoration: const InputDecoration(labelText: 'Frase de Teste da Voz', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ctrl.readFilter,
                      dropdownColor: const Color(0xFF0B1636),
                      decoration: const InputDecoration(labelText: 'Quem a Voz Lê no Chat', isDense: true),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'all', child: Text('Todas as Mensagens', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'vip_sub', child: Text('Apenas VIPs, Subs e Presentes', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'gifts', child: Text('Apenas Presentes / Doações', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'command', child: Text('Apenas Comando !falar', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() => _ctrl.readFilter = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Saltar Mensagem Atual',
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.amberAccent),
                    onPressed: _ctrl.skipCurrentSpeech,
                  ),
                  IconButton(
                    tooltip: 'Silenciar e Limpar Fila',
                    icon: const Icon(Icons.volume_off_rounded, color: Colors.redAccent),
                    onPressed: _ctrl.stopAndClearQueue,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1636),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'CHAT UNIFICADO AO VIVO (TWITCH REAL + SIMULADOR DE TESTE)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _twitchCtrl,
                      decoration: const InputDecoration(labelText: 'Canal Twitch (Chat Real ao Vivo)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ctrl.twitchConnected ? Colors.redAccent : Colors.green,
                    ),
                    onPressed: () {
                      if (_ctrl.twitchConnected) {
                        _ctrl.disconnectTwitchChat();
                      } else {
                        _ctrl.connectTwitchPublicChat(_twitchCtrl.text);
                      }
                    },
                    child: Text(_ctrl.twitchConnected ? 'Desligar' : 'Ligar Chat', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _ctrl.ingestIncomingMessage(HellLiveChatMessage(
                      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
                      platform: 'tiktok',
                      sender: 'SeguidorVIP',
                      text: 'Grande live hoje! Continua assim!',
                      badge: 'VIP',
                      timestamp: DateTime.now(),
                    )),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: const Text('Simular Chat TikTok', style: TextStyle(fontSize: 11.5)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _ctrl.ingestIncomingMessage(HellLiveChatMessage(
                      id: 'gift_${DateTime.now().millisecondsSinceEpoch}',
                      platform: 'tiktok',
                      sender: 'SuperApoiante',
                      text: 'Toma lá um presente para animar a live!',
                      badge: 'GIFT',
                      isGiftOrDonation: true,
                      giftInfo: 'Leão Dourado',
                      timestamp: DateTime.now(),
                    )),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.amberAccent),
                    label: const Text('Simular Presente', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
              const Divider(height: 18),
              if (_ctrl.messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Nenhuma mensagem no feed ainda. Liga o teu canal ou testa com os botões acima.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                )
              else
                ..._ctrl.messages.take(30).map((m) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: m.isGiftOrDonation ? Colors.amber.withOpacity(0.25) : const Color(0xFF0284C7).withOpacity(0.25),
                        child: Text(m.platform.substring(0, 2).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        '${m.sender} ${m.badge.isNotEmpty ? "[${m.badge}]" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: m.isGiftOrDonation ? Colors.amberAccent : const Color(0xFF38BDF8),
                        ),
                      ),
                      subtitle: Text(m.text, style: const TextStyle(fontSize: 12)),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class HellVoiceCloneTeleprompterDialog extends StatefulWidget {
  final String defaultOwnerName;
  final Future<void> Function(String name, double pitchHz, double formantShift, double speedFactor) onVoiceCloned;

  const HellVoiceCloneTeleprompterDialog({
    super.key,
    required this.defaultOwnerName,
    required this.onVoiceCloned,
  });

  @override
  State<HellVoiceCloneTeleprompterDialog> createState() => _HellVoiceCloneTeleprompterDialogState();
}

class _HellVoiceCloneTeleprompterDialogState extends State<HellVoiceCloneTeleprompterDialog> {
  static const String _teleprompterScript435Words = '''
Olá a todos e sejam muito bem-vindos a mais uma transmissão ao vivo aqui no nosso canal. Hoje vamos conversar com calma, partilhar boas ideias, responder às vossas perguntas no chat e testar novas ferramentas criativas para melhorar ainda mais a qualidade das nossas lives. Sintam-se em casa, puxem uma cadeira, ajustem o volume do vosso dispositivo e digam de onde nos estão a acompanhar neste momento.

Quando começamos um projeto digital do zero, cada pequeno detalhe faz toda a diferença no resultado final. A clareza da voz, o ritmo natural das palavras, a energia com que cumprimentamos quem chega pela primeira vez e a atenção que damos à nossa comunidade criam uma ligação verdadeira. Não precisamos de falar depressa nem de forçar expressões artificiais; basta sermos autênticos, transparentes e mantermos sempre o nosso estilo próprio.

Ao longo desta semana estivemos a preparar novidades incríveis para os criadores de conteúdo, desde alertas interativos em tempo real até sistemas inteligentes de leitura de mensagens. Imaginem poder ouvir os comentários dos seguidores com naturalidade, sem interromper o vosso raciocínio durante um jogo intenso ou uma conversa importante. É exatamente para isso que serve esta gravação: captar o timbre real, a cadência e a personalidade única da tua voz.

Vamos agora variar um pouco a entoação para registar diferentes emoções e registos vocais. Primeiro, num tom sereno e confiante: tudo está a funcionar perfeitamente e o som está limpo e equilibrado. Agora, com um pouco mais de entusiasmo e energia: que jogada espetacular, muito obrigado pelo apoio incrível e pelos presentes enviados agora mesmo no chat! E em tom de pergunta: qual é a vossa opinião sobre esta funcionalidade?

Nos dias mais longos, quando já estamos há várias horas em direto, a voz fica naturalmente mais tranquila, pausada e grave. Respirar fundo entre frases ajuda a manter o conforto vocal e evita qualquer cansaço desnecessário. Por outro lado, nos momentos de celebração com a comunidade, o sorriso nota-se logo na forma como pronunciamos cada sílaba, tornando a experiência muito mais próxima e envolvente para quem assiste.

Estamos quase a concluir estes dois minutos de leitura contínua. Obrigado por dedicares este tempo a calibrar a tua assinatura vocal com tanta atenção e cuidado. Assim que terminares, o sistema vai analisar a frequência, o ritmo e as características naturais da tua fala para criar um perfil exclusivo, pronto a ser utilizado sempre que quiseres nas tuas transmissões. Até já no estúdio!
''';

  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scrollCtrl = ScrollController();
  late final TextEditingController _voiceNameCtrl;
  bool _legalConsentAccepted = false;
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  String _recordedFilePath = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _voiceNameCtrl = TextEditingController(text: widget.defaultOwnerName);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _scrollCtrl.dispose();
    _voiceNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecordingWithTeleprompter() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de microfone necessária para gravar a tua voz.')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/hell_clone_sample_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 22050, numChannels: 1),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
      _recordedFilePath = path;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
        final target = (_elapsedSeconds / 120.0).clamp(0.0, 1.0) * _scrollCtrl.position.maxScrollExtent;
        _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.linear);
      }
      if (_elapsedSeconds >= 120) {
        await _finishAndAnalyzeVoice();
      }
    });
  }

  Future<void> _finishAndAnalyzeVoice() async {
    _timer?.cancel();
    final stoppedPath = await _recorder.stop() ?? _recordedFilePath;
    setState(() => _isRecording = false);

    double measuredPitch = 118.0;
    double measuredFormant = 0.90;
    double measuredSpeed = 1.00;

    try {
      final f = File(stoppedPath);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 4400) {
          final bd = ByteData.sublistView(bytes);
          int zeroCrossings = 0;
          int prev = 0;
          int activeSamples = 0;
          final int totalSamples = (bytes.length - 44) ~/ 2;
          for (int i = 0; i < totalSamples; i++) {
            final int sample = bd.getInt16(44 + i * 2, Endian.little);
            if (sample.abs() > 900) {
              activeSamples++;
              if ((prev < 0 && sample >= 0) || (prev >= 0 && sample < 0)) {
                zeroCrossings++;
              }
            }
            prev = sample;
          }
          if (activeSamples > 1000) {
            final double activeSec = activeSamples / 22050.0;
            final double estHz = (zeroCrossings / 2.0) / activeSec;
            measuredPitch = (estHz * 0.42).clamp(88.0, 245.0);
            measuredFormant = (0.82 + ((measuredPitch - 88.0) / 157.0) * 0.34).clamp(0.82, 1.18);
            final double density = activeSamples / totalSamples;
            measuredSpeed = (0.85 + density * 0.35).clamp(0.82, 1.22);
          }
        }
      }
    } catch (_) {}

    final name = _voiceNameCtrl.text.trim().isEmpty ? widget.defaultOwnerName : _voiceNameCtrl.text.trim();
    await widget.onVoiceCloned(name, measuredPitch, measuredFormant, measuredSpeed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final int mins = _elapsedSeconds ~/ 60;
    final int secs = _elapsedSeconds % 60;
    final String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} / 02:00';

    return AlertDialog(
      backgroundColor: const Color(0xFF0B1636),
      title: const Text(
        '🎙️ ESTÚDIO DE CLONAGEM VOCAL · TELEPONTO (2 MINUTOS)',
        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _voiceNameCtrl,
                enabled: !_isRecording,
                decoration: const InputDecoration(labelText: 'Nome da Tua Voz Clonada', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_elapsedSeconds / 120.0).clamp(0.0, 1.0),
                      color: Colors.redAccent,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 210,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF04091A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isRecording ? Colors.redAccent : const Color(0xFF38BDF8).withOpacity(0.5)),
                ),
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  child: const Text(
                    _teleprompterScript435Words,
                    style: TextStyle(fontSize: 15.5, height: 1.65, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _legalConsentAccepted,
                activeColor: const Color(0xFF38BDF8),
                onChanged: _isRecording ? null : (v) => setState(() => _legalConsentAccepted = v ?? false),
                title: const Text(
                  'Declaro legalmente que estou a gravar e clonar apenas a minha própria voz (RGPD / Direitos de Voz).',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (!_isRecording)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (!_isRecording)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: _legalConsentAccepted ? _startRecordingWithTeleprompter : null,
            icon: const Icon(Icons.fiber_manual_record, size: 16),
            label: const Text('Iniciar Gravação & Teleponto'),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _elapsedSeconds >= 15 ? _finishAndAnalyzeVoice : null,
            icon: const Icon(Icons.check_circle, size: 16),
            label: Text(_elapsedSeconds >= 15 ? 'Concluir e Criar Voz' : 'Lê pelo menos 15s...'),
          ),
      ],
    );
  }
}
