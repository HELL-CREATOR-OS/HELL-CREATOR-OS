import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

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
  final String voiceCode;
  final double playbackRate;
  final double fallbackPitch;
  final bool isCloned;
  final String? samplePath;

  const HellOriginalVoiceProfile({
    required this.id,
    required this.label,
    required this.gender,
    required this.voiceCode,
    this.playbackRate = 1.0,
    this.fallbackPitch = 1.0,
    this.isCloned = false,
    this.samplePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'gender': gender,
        'voiceCode': voiceCode,
        'playbackRate': playbackRate,
        'fallbackPitch': fallbackPitch,
        'isCloned': isCloned,
        'samplePath': samplePath,
      };
}

/// Motor Neural Online de Estúdio (PT-PT Duarte & Raquel + Multi-Idioma)
class HellEdgeNeuralOnlineEngine {
  static const String _trustedToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _chromiumVersion = '130.0.2849.68';

  static String _generateSecMsGec() {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    const winEpochOffset = 11644473600;
    var ticks = nowSeconds + winEpochOffset;
    ticks -= ticks % 300;
    final winTicks = ticks * 10000000;
    final strToHash = '$winTicks$_trustedToken';
    final digest = sha256.convert(utf8.encode(strToHash));
    return digest.toString().toUpperCase();
  }

  static String _voiceNameForId(String voiceId, String langCode) {
    final bool isFemale = voiceId == 'f_pt_lucia';
    if (langCode.startsWith('pt-BR')) {
      return isFemale ? 'pt-BR-FranciscaNeural' : 'pt-BR-AntonioNeural';
    }
    if (langCode.startsWith('en-US')) {
      return isFemale ? 'en-US-JennyNeural' : 'en-US-GuyNeural';
    }
    if (langCode.startsWith('en')) {
      return isFemale ? 'en-GB-SoniaNeural' : 'en-GB-RyanNeural';
    }
    if (langCode.startsWith('es')) {
      return isFemale ? 'es-ES-ElviraNeural' : 'es-ES-AlvaroNeural';
    }
    if (langCode.startsWith('fr')) {
      return isFemale ? 'fr-FR-DeniseNeural' : 'fr-FR-HenriNeural';
    }
    if (langCode.startsWith('de')) {
      return isFemale ? 'de-DE-KatjaNeural' : 'de-DE-ConradNeural';
    }
    if (langCode.startsWith('it')) {
      return isFemale ? 'it-IT-ElsaNeural' : 'it-IT-DiegoNeural';
    }
    // Padrão: Português de Portugal (Estúdio Limpo)
    return isFemale ? 'pt-PT-RaquelNeural' : 'pt-PT-DuarteNeural';
  }

  static Uri _buildWebSocketUri(String requestId, String gec) {
    final host = ['speech', 'platform', 'bing', 'com'].join('.');
    return Uri(
      scheme: 'wss',
      host: host,
      path: '/consumer/speech/synthesize/readaloud/edge/v1',
      queryParameters: {
        'TrustedClientToken': _trustedToken,
        'Sec-MS-GEC': gec,
        'Sec-MS-GEC-Version': '1-$_chromiumVersion',
        'ConnectionId': requestId,
      },
    );
  }

  static Future<String?> synthesizeToMp3({
    required String text,
    required String voiceId,
    required String langCode,
    required double speed,
  }) async {
    final voiceName = _voiceNameForId(voiceId, langCode);
    final ratePercent = ((speed - 1.0) * 100).round().clamp(-50, 100);
    final rateStr = ratePercent >= 0 ? '+$ratePercent%' : '$ratePercent%';

    final escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final ssml = "<speak version='1.0' xmlns='http://w3.org' xml:lang='$langCode'>"
        "<voice name='$voiceName'><prosody rate='$rateStr' pitch='+0Hz'>$escapedText</prosody></voice>"
        "</speak>";

    final requestId = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
    final gec = _generateSecMsGec();
    final wsUri = _buildWebSocketUri(requestId, gec);

    WebSocket? socket;
    try {
      socket = await WebSocket.connect(
        wsUri.toString(),
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
        },
      ).timeout(const Duration(seconds: 6));

      final timestamp = DateTime.now().toUtc().toIso8601String();
      socket.add(
        'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n',
      );

      socket.add(
        'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:$timestamp\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml',
      );

      final audioBytes = <int>[];
      await for (final event in socket.timeout(const Duration(seconds: 8))) {
        if (event is List<int>) {
          if (event.length > 2) {
            final headerLen = (event[0] << 8) | event[1];
            final dataStart = 2 + headerLen;
            if (dataStart < event.length) {
              audioBytes.addAll(event.sublist(dataStart));
            }
          }
        } else if (event is String && event.contains('Path:turn.end')) {
          break;
        }
      }

      await socket.close();
      if (audioBytes.isEmpty) return null;

      final tempDir = await getTemporaryDirectory();
      final mp3Path = '${tempDir.path}/hell_edge_${DateTime.now().microsecondsSinceEpoch}.mp3';
      await File(mp3Path).writeAsBytes(audioBytes);
      return mp3Path;
    } catch (_) {
      try {
        await socket?.close();
      } catch (_) {}
      return null;
    }
  }
}

/// Motor de Clonagem Vocal Real (Pocket TTS PT)
class HellPocketVoiceCloner {
  static sherpa_onnx.OfflineTts? _clonerTts;
  static bool _isDownloading = false;

  static final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  static final ValueNotifier<String> statusText = ValueNotifier<String>('Clonador pronto');

  static Uri _hfFileUri(String fileName) {
    final host = ['huggingface', 'co'].join('.');
    final path = [
      '',
      'haex-space',
      'pocket-tts-sherpa-onnx',
      'resolve',
      'main',
      'pt',
      fileName,
    ].join('/');
    return Uri.https(host, path);
  }

  static Future<bool> ensureClonerReady() async {
    if (_clonerTts != null) return true;
    if (_isDownloading) return false;
    _isDownloading = true;

    try {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory('${appDir.path}/tts_models/pocket_tts_pt');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      const files = [
        'lm_flow.int8.onnx',
        'lm_main.int8.onnx',
        'encoder.onnx',
        'decoder.int8.onnx',
        'text_conditioner.onnx',
        'vocab.json',
        'token_scores.json',
      ];

      for (int i = 0; i < files.length; i++) {
        final name = files[i];
        final target = File('${dir.path}/$name');
        if (!await target.exists() || await target.length() == 0) {
          statusText.value = 'A descarregar Clonador Neural PT (${i + 1}/${files.length})...';
          downloadProgress.value = (i + 1) / files.length;

          final request = http.Request('GET', _hfFileUri(name));
          final response = await http.Client().send(request);
          if (response.statusCode != 200) {
            throw Exception('Erro HTTP ${response.statusCode} ao baixar $name');
          }
          final sink = target.openWrite();
          await response.stream.pipe(sink);
        }
      }

      sherpa_onnx.initBindings();

      final pocketConfig = sherpa_onnx.OfflineTtsPocketModelConfig(
        lmFlow: '${dir.path}/lm_flow.int8.onnx',
        lmMain: '${dir.path}/lm_main.int8.onnx',
        encoder: '${dir.path}/encoder.onnx',
        decoder: '${dir.path}/decoder.int8.onnx',
        textConditioner: '${dir.path}/text_conditioner.onnx',
        vocabJson: '${dir.path}/vocab.json',
        tokenScoresJson: '${dir.path}/token_scores.json',
      );

      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        pocket: pocketConfig,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      _clonerTts = sherpa_onnx.OfflineTts(
        sherpa_onnx.OfflineTtsConfig(model: modelConfig),
      );

      downloadProgress.value = 1.0;
      statusText.value = 'Clonador de Voz Real PT Pronto ✓';
      return true;
    } catch (e) {
      statusText.value = 'Erro no clonador: $e';
      return false;
    } finally {
      _isDownloading = false;
    }
  }

class HellChatTtsController extends ChangeNotifier {
  static const List<HellOriginalVoiceProfile> builtInVoices = <HellOriginalVoiceProfile>[
    HellOriginalVoiceProfile(
      id: 'm_pt_helder',
      label: '🎙️ Masculina · Hélder (Estúdio PT-PT · Padrão)',
      gender: 'M',
      voiceCode: 'pt-PT',
      playbackRate: 1.0,
      fallbackPitch: 1.0,
    ),
    HellOriginalVoiceProfile(
      id: 'f_pt_lucia',
      label: '🎙️ Feminina · Lúcia (Estúdio PT-PT)',
      gender: 'F',
      voiceCode: 'pt-PT',
      playbackRate: 1.0,
      fallbackPitch: 1.0,
    ),
  ];

  static HellChatTtsController? activeInstance;

  static Future<void> speakGlobal(String text) async {
    if (activeInstance != null) {
      activeInstance!.enqueueSpeech(text);
      return;
    }
    final temp = HellChatTtsController();
    await temp.init();
    await temp.speakImmediateTest(text);
  }

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _offlineFallbackTts = FlutterTts();
  final List<HellLiveChatMessage> messages = <HellLiveChatMessage>[];
  final List<String> _speechQueue = <String>[];
  final List<String> musicRequests = <String>[];
  final List<HellOriginalVoiceProfile> clonedVoices = <HellOriginalVoiceProfile>[];

  static const Map<String, String> supportedLanguages = <String, String>{
    'pt-PT': '🇵🇹 Português (Portugal · Padrão)',
    'pt-BR': '🇧🇷 Português (Brasil)',
    'en-GB': '🇬🇧 Inglês (Reino Unido)',
    'en-US': '🇺🇸 Inglês (Estados Unidos)',
    'es-ES': '🇪🇸 Espanhol (Espanha)',
    'fr-FR': '🇫🇷 Francês (França)',
    'de-DE': '🇩🇪 Alemão (Alemanha)',
    'it-IT': '🇮🇹 Italiano (Itália)',
  };

  bool ttsEnabled = true;
  bool isSpeaking = false;
  String selectedLanguage = 'pt-PT';
  double customPitch = 1.0;
  double customSpeed = 1.0;
  String selectedVoiceId = 'm_pt_helder';
  String readFilter = 'all';
  int maxChars = 160;
  bool readSenderName = true;
  bool filterSpam = true;
  List<String> blockedWords = <String>['http://', 'https://', 'www.'];
  Map<String, String> chatCommands = <String, String>{
    '!discord': 'Entra na nossa comunidade oficial no Discord!',
    '!loja': 'Visita o Marketplace oficial HELL CREATOR na app!',
    '!comandos': 'Comandos disponíveis: !discord · !loja · !pedir <música> · !falar <texto>',
  };

  WebSocket? _twitchSocket;
  bool twitchConnected = false;
  String twitchChannel = '';
  String? _lastTempAudioPath;

  List<HellOriginalVoiceProfile> get allAvailableVoices =>
      <HellOriginalVoiceProfile>[...clonedVoices, ...builtInVoices];

  HellOriginalVoiceProfile get currentVoice => allAvailableVoices.firstWhere(
        (v) => v.id == selectedVoiceId,
        orElse: () => builtInVoices.first,
      );

  Future<void> init() async {
    activeInstance = this;
    final p = await SharedPreferences.getInstance();
    ttsEnabled = p.getBool('hell_tts_enabled_v3') ?? true;
    selectedVoiceId = p.getString('hell_tts_voice_id_v4') ?? 'm_pt_helder';
    selectedLanguage = p.getString('hell_tts_lang_v3') ?? 'pt-PT';
    customSpeed = p.getDouble('hell_tts_speed_v4') ?? 1.0;
    readFilter = p.getString('hell_tts_filter_v3') ?? 'all';
    maxChars = p.getInt('hell_tts_maxchars_v3') ?? 160;
    readSenderName = p.getBool('hell_tts_read_sender_v3') ?? true;
    twitchChannel = p.getString('hell_platform_handle_twitch') ?? '';

    final rawClones = p.getString('hell_cloned_voices_v4') ?? p.getString('hell_cloned_voices_v3');
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
            voiceCode: (m['voiceCode'] ?? 'pt-PT').toString(),
            playbackRate: ((m['playbackRate'] ?? 1.0) as num).toDouble(),
            fallbackPitch: ((m['fallbackPitch'] ?? 1.0) as num).toDouble(),
            isCloned: m['isCloned'] == true || m['id'].toString().startsWith('clone_'),
            samplePath: m['samplePath']?.toString(),
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
    String? recordedWavPath,
  }) async {
    final id = 'clone_${DateTime.now().millisecondsSinceEpoch}';
    final bool isMale = measuredPitchHz < 170;
    final profile = HellOriginalVoiceProfile(
      id: id,
      label: '🎙️ Voz Clonada · $name',
      gender: isMale ? 'M' : 'F',
      voiceCode: 'pt-PT',
      playbackRate: 1.0,
      fallbackPitch: 1.0,
      isCloned: true,
      samplePath: recordedWavPath,
    );
    clonedVoices.insert(0, profile);
    selectedVoiceId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'hell_cloned_voices_v4',
      jsonEncode(clonedVoices.map((v) => v.toJson()).toList()),
    );
    await p.setString('hell_tts_voice_id_v4', id);
    notifyListeners();
  }

  Future<bool> deleteClonedVoice(String voiceId) async {
    final index = clonedVoices.indexWhere((v) => v.id == voiceId);
    if (index == -1) return false;

    final removed = clonedVoices.removeAt(index);

    if (removed.samplePath != null && removed.samplePath!.isNotEmpty) {
      try {
        final f = File(removed.samplePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    final p = await SharedPreferences.getInstance();
    await p.setString(
      'hell_cloned_voices_v4',
      jsonEncode(clonedVoices.map((e) => e.toJson()).toList()),
    );

    await setSelectedVoice('m_pt_helder');
    notifyListeners();
    return true;
  }

  Future<void> setSelectedVoice(String voiceId) async {
    selectedVoiceId = voiceId;
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_tts_voice_id_v4', voiceId);
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

  Future<void> downloadAndApplyLanguage(String langCode) async {
    selectedLanguage = langCode;
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_tts_lang_v3', langCode);
    final shortCode = langCode.split('-').first.toLowerCase();
    await p.setString('app_lang', shortCode);
    try {
      await _offlineFallbackTts.setLanguage(langCode);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setCustomSpeed(double val) async {
    customSpeed = val.clamp(0.50, 1.80);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('hell_tts_speed_v4', customSpeed);
    notifyListeners();
  }

  Future<void> _speakOfflineFallback(String text, HellOriginalVoiceProfile v) async {
    try {
      await _offlineFallbackTts.stop();
      await _offlineFallbackTts.awaitSpeakCompletion(true);
      await _offlineFallbackTts.setLanguage(selectedLanguage);
      await _offlineFallbackTts.setPitch(v.gender == 'M' ? 0.82 : 1.15);
      await _offlineFallbackTts.setSpeechRate((customSpeed * 0.48).clamp(0.22, 0.90));
      await _offlineFallbackTts.speak(text);
    } catch (_) {}
    isSpeaking = false;
    notifyListeners();
    if (_speechQueue.isNotEmpty) {
      _processNextInQueue();
    }
  }

  Future<void> _playHumanAudio(String text) async {
    final v = currentVoice;

    try {
      if (_lastTempAudioPath != null) {
        try {
          final oldFile = File(_lastTempAudioPath!);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
      }

      String? audioPath;

      if (v.isCloned && v.samplePath != null && v.samplePath!.isNotEmpty) {
        audioPath = await HellPocketVoiceCloner.cloneSpeakToWav(
          text: text,
          referenceWavPath: v.samplePath!,
          speed: customSpeed,
        );
      } else {
        audioPath = await HellEdgeNeuralOnlineEngine.synthesizeToMp3(
          text: text,
          voiceId: v.id,
          langCode: selectedLanguage,
          speed: customSpeed,
        );
      }

      if (audioPath != null && File(audioPath).existsSync()) {
        _lastTempAudioPath = audioPath;
        await _player.stop();
        await _player.setPlaybackRate(1.0);
        await _player.play(DeviceFileSource(audioPath));
        return;
      }
