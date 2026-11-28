import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
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
  final String voiceCode; // Voz humana masculina/feminina real
  final double playbackRate; // Velocidade real de reprodução no AudioPlayer
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


class HellHumanNeuralVoiceEngine {
  static Future<String> synthesizeHellOwnVoiceFile({
    required String rawText,
    required HellOriginalVoiceProfile profile,
    required String langCode,
    required double speedMultiplier,
    required double pitchMultiplier,
  }) async {
    final clean = rawText
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final String text = clean.isEmpty ? 'Olá, bem-vindos à transmissão!' : (clean.length > 200 ? clean.substring(0, 200) : clean);
    final bool isFemale = profile.gender == 'F' || profile.id == 'child_voice';
    final String targetLang = langCode.isEmpty ? 'pt-PT' : langCode;

    final dir = await getTemporaryDirectory();
    final outFile = File('${dir.path}/hell_voice_${DateTime.now().microsecondsSinceEpoch}.mp3');

    final uri = Uri.https('://googleapis.com', '/translate_tts', <String, String>{
      'ie': 'UTF-8',
      'client': 'gtx',
      'tl': isFemale ? targetLang : (targetLang.startsWith('pt') ? 'pt-PT' : targetLang),
      'q': text,
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final req = await client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0');
    final res = await req.close();
    if (res.statusCode == 200) {
      final bytes = await res.fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      client.close();
      if (bytes.length > 400) {
        await outFile.writeAsBytes(bytes, flush: true);
        return outFile.path;
      }
    }
    client.close();
    throw Exception('Sem ligação de voz');
  }

  static double computePlaybackRate({
    required HellOriginalVoiceProfile profile,
    required double speedMultiplier,
    required double pitchMultiplier,
  }) {
    final double genderFactor = profile.id == 'child_voice'
        ? 1.24
        : (profile.gender == 'F' ? 1.06 : 0.84);
    final double pitchFactor = (pitchMultiplier / 1.0).clamp(0.75, 1.35);
    return (genderFactor * speedMultiplier * pitchFactor).clamp(0.55, 1.75);
  }
}

/// Função isolada para extrair o .tar.bz2 fora da thread principal (evita crash de RAM)
Future<void> _extractTarBz2InBackground(Map<String, String> paths) async {
  final tarBz2File = File(paths['archivePath']!);
  final extractRootPath = paths['extractRoot']!;

  final compressedBytes = await tarBz2File.readAsBytes();
  final tarBytes = BZip2Decoder().decodeBytes(compressedBytes);
  final archive = TarDecoder().decodeBytes(tarBytes);

  final extractRoot = Directory(extractRootPath);
  if (!await extractRoot.exists()) {
    await extractRoot.create(recursive: true);
  }

  for (final file in archive) {
    final outPath = '$extractRootPath/${file.name}';
    if (file.isFile) {
      final outFile = File(outPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      await Directory(outPath).create(recursive: true);
    }
  }
}

class HellSherpaOfflineEngine {
  static final Map<String, sherpa_onnx.OfflineTts> _engines = {};
  static bool _isInitializing = false;
  static bool _bindingsInitialized = false;

  static final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  static final ValueNotifier<String> statusText = ValueNotifier<String>('Motor offline pronto');

  static Uri _buildReleaseUri(String archiveFileName) {
    final host = ['github', 'com'].join('.');
    final path = [
      '',
      'k2-fsa',
      'sherpa-onnx',
      'releases',
      'download',
      'tts-models',
      archiveFileName,
    ].join('/');
    return Uri.https(host, path);
  }

  /// Usa apenas modelos Piper leves e estáveis (evita crash de memória no Android/Windows)
  static Map<String, dynamic> _specForVoice(String voiceId, {String langCode = 'pt-PT'}) {
    if (langCode.startsWith('en')) {
      return {
        'key': 'en_alba',
        'dir': 'vits-piper-en_GB-alba-medium',
        'onnx': 'en_GB-alba-medium.onnx',
        'archive': 'vits-piper-en_GB-alba-medium.tar.bz2',
        'sid': 0,
        'label': 'English (UK)',
      };
    }
    if (langCode.startsWith('es')) {
      return {
        'key': 'es_davefx',
        'dir': 'vits-piper-es_ES-davefx-medium',
        'onnx': 'es_ES-davefx-medium.onnx',
        'archive': 'vits-piper-es_ES-davefx-medium.tar.bz2',
        'sid': 0,
        'label': 'Español (ES)',
      };
    }
    if (langCode.startsWith('fr')) {
      return {
        'key': 'fr_siwis',
        'dir': 'vits-piper-fr_FR-siwis-medium',
        'onnx': 'fr_FR-siwis-medium.onnx',
        'archive': 'vits-piper-fr_FR-siwis-medium.tar.bz2',
        'sid': 0,
        'label': 'Français (FR)',
      };
    }

    switch (voiceId) {
     
      case 'f_pt_lucia':
        return {
          'key': 'pt_dii',
          'dir': 'vits-piper-pt_PT-dii-high',
          'onnx': 'pt_PT-dii-high.onnx',
          'archive': 'vits-piper-pt_PT-dii-high.tar.bz2',
          'sid': 0,
          'label': 'Lúcia (PT-PT HD)',
        };
      case 'm_pt_helder':
      default:
        return {
          'key': 'pt_miro',
          'dir': 'vits-piper-pt_PT-miro-high',
          'onnx': 'pt_PT-miro-high.onnx',
          'archive': 'vits-piper-pt_PT-miro-high.tar.bz2',
          'sid': 0,
          'label': 'Hélder (PT-PT HD)',
        };
    }
  }


  static void _safeInitBindings() {
    if (!_bindingsInitialized) {
      sherpa_onnx.initBindings();
      _bindingsInitialized = true;
    }
  }

  static Future<sherpa_onnx.OfflineTts?> _loadEngineForSpec(Map<String, dynamic> spec) async {
    final String key = spec['key'];
    if (_engines.containsKey(key)) return _engines[key];

    // Mantém no máximo 1 motor carregado na RAM ao mesmo tempo para não fechar a app
    if (_engines.isNotEmpty) {
      for (final oldTts in _engines.values) {
        oldTts.free();
      }
      _engines.clear();
    }

    final String dirName = spec['dir'];
    final String onnxFileName = spec['onnx'];
    final String archiveName = spec['archive'];
    final String label = spec['label'];

    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appDir.path}/tts_models/$dirName');
    final modelFile = File('${modelDir.path}/$onnxFileName');
    final tokensFile = File('${modelDir.path}/tokens.txt');
    final espeakDir = Directory('${modelDir.path}/espeak-ng-data');

    final bool needsDownload = !await modelFile.exists() ||
        !await tokensFile.exists() ||
        !await espeakDir.exists();

    if (needsDownload) {
      statusText.value = 'A descarregar voz de $label...';
      downloadProgress.value = 0.08;

      final tarBz2File = File('${appDir.path}/$archiveName');
      final request = http.Request('GET', _buildReleaseUri(archiveName));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Erro HTTP ${response.statusCode} ao descarregar $label');
      }

      final contentLength = response.contentLength ?? 60000000;
      int downloaded = 0;
      final sink = tarBz2File.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        downloadProgress.value = (downloaded / contentLength).clamp(0.08, 0.85);
      }
      await sink.close();

      statusText.value = 'A extrair voz de $label (aguarde)...';
      downloadProgress.value = 0.90;

      // Extrai em Isolate separado para não estourar a RAM da UI
      await compute(_extractTarBz2InBackground, {
        'archivePath': tarBz2File.path,
        'extractRoot': '${appDir.path}/tts_models',
      });

      if (await tarBz2File.exists()) {
        await tarBz2File.delete();
      }
    }

    _safeInitBindings();

         final vitsConfig = sherpa_onnx.OfflineTtsVitsModelConfig(
      model: modelFile.path,
      tokens: tokensFile.path,
      dataDir: espeakDir.path,
    );



    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      vits: vitsConfig,
      numThreads: 1, // 1 thread evita picos de CPU/RAM em telemóveis
      debug: false,
      provider: 'cpu',
    );

    final tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model: modelConfig));
    _engines[key] = tts;
    return tts;
  }

  static Future<bool> ensureVoiceReady(String voiceId) async {
    if (_isInitializing) return false;
    _isInitializing = true;
    try {
      final spec = _specForVoice(voiceId);
      final engine = await _loadEngineForSpec(spec);
      downloadProgress.value = 1.0;
      statusText.value = 'Voz de ${spec['label']} pronta ✓';
      return engine != null;
    } catch (e) {
      statusText.value = 'Erro ao carregar voz: $e';
      return false;
    } finally {
      _isInitializing = false;
    }
  }
  static Float32List _cleanStudioSamples(Float32List rawSamples) {
    final out = Float32List(rawSamples.length);
    const double noiseGateThreshold = 0.014;
    double prev = 0.0;

    for (int i = 0; i < rawSamples.length; i++) {
      double s = rawSamples[i];
      if (s.abs() < noiseGateThreshold) {
        s *= 0.15;
      }
      final filtered = (s * 0.78) + (prev * 0.22);
      prev = filtered;
      out[i] = filtered.clamp(-0.98, 0.98);
    }
    return out;
  }


  static Future<String?> synthesizeToWav({
    required String text,
    required String voiceId,
    required double speed,
  }) async {
    if (_isInitializing) return null;
    final spec = _specForVoice(voiceId);
    final engine = await _loadEngineForSpec(spec);
    if (engine == null) return null;

    final generated = engine.generate(
      text: text,
      sid: spec['sid'] as int,
      speed: speed.clamp(0.55, 1.85),
    );

    if (generated.samples.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final wavPath = '${tempDir.path}/hell_sherpa_${voiceId}_${DateTime.now().microsecondsSinceEpoch}.wav';

       final cleanSamples = _cleanStudioSamples(generated.samples);

       final written = sherpa_onnx.writeWave(
      filename: wavPath,
      samples: generated.samples,
      sampleRate: generated.sampleRate,
    );



    return written ? wavPath : null;
  }
}

class HellPocketVoiceCloner {
  static sherpa_onnx.OfflineTts? _clonerTts;
  static bool _isDownloading = false;

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
          HellSherpaOfflineEngine.statusText.value =
              'A descarregar Clonador Neural PT (${i + 1}/${files.length})...';
          HellSherpaOfflineEngine.downloadProgress.value = (i + 1) / files.length;

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

      HellSherpaOfflineEngine.downloadProgress.value = 1.0;
      HellSherpaOfflineEngine.statusText.value = 'Clonador de Voz Real PT Pronto ✓';
      return true;
    } catch (e) {
      HellSherpaOfflineEngine.statusText.value = 'Erro no clonador: $e';
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  static Future<String?> cloneSpeakToWav({
    required String text,
    required String referenceWavPath,
    required double speed,
  }) async {
    final refFile = File(referenceWavPath);
    if (!await refFile.exists()) return null;

    final ready = await ensureClonerReady();
    if (!ready || _clonerTts == null) return null;

    final waveData = sherpa_onnx.readWave(referenceWavPath);
    if (waveData.samples.isEmpty) return null;

    final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
      sid: 0,
      speed: speed.clamp(0.60, 1.80),
      referenceAudio: waveData.samples,
      referenceSampleRate: waveData.sampleRate,
      numSteps: 5,
    );

    final generated = _clonerTts!.generateWithConfig(
      text: text,
      config: genConfig,
    );

    if (generated.samples.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/hell_clone_out_${DateTime.now().microsecondsSinceEpoch}.wav';

    final ok = sherpa_onnx.writeWave(
      filename: outPath,
      samples: generated.samples,
      sampleRate: generated.sampleRate,
    );

    return ok ? outPath : null;
  }
}


class HellChatTtsController extends ChangeNotifier {
  static const List<HellOriginalVoiceProfile> builtInVoices = <HellOriginalVoiceProfile>[
    HellOriginalVoiceProfile(
      id: 'm_pt_helder',
      label: '🎙️ Masculina · Hélder (Alta Definição · Padrão)',
      gender: 'M',
      voiceCode: 'pt-PT',
      playbackRate: 1.0,
      fallbackPitch: 1.0,
    ),
    HellOriginalVoiceProfile(
      id: 'f_pt_lucia',
      label: '🎙️ Feminina · Lúcia (Alta Definição)',
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
    'nl-NL': '🇳🇱 Holandês (Países Baixos)',
    'pl-PL': '🇵🇱 Polaco (Polónia)',
    'ru-RU': '🇷🇺 Russo (Rússia)',
    'ja-JP': '🇯🇵 Japonês (Japão)',
    'ko-KR': '🇰🇷 Coreano (Coreia do Sul)',
    'zh-CN': '🇨🇳 Chinês (Mandarim)',
    'ar-SA': '🇸🇦 Árabe',
    'hi-IN': '🇮🇳 Hindi',
  };

  bool ttsEnabled = true;
  bool isSpeaking = false;
  String selectedLanguage = 'pt-PT';
  double customPitch = 0.85;
  double customSpeed = 0.96;
  String selectedVoiceId = 'm_pt_helder';
  String readFilter = 'all';
  int maxChars = 140;
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
    HellSherpaOfflineEngine.ensureVoiceReady(selectedVoiceId);
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
      playbackRate: measuredSpeedFactor.clamp(0.85, 1.15),
      fallbackPitch: (measuredPitchHz / 150.0).clamp(0.75, 1.35),
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




   Future<void> setSelectedVoice(String voiceId) async {
    selectedVoiceId = voiceId;
    final v = currentVoice;
    customPitch = v.fallbackPitch;
    customSpeed = v.playbackRate;
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

     final FlutterTts _offlineFallbackTts = FlutterTts();

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

  Future<void> setCustomPitch(double val) async {
    customPitch = val.clamp(0.50, 1.75);
    notifyListeners();
  }

  Future<void> setCustomSpeed(double val) async {
    customSpeed = val.clamp(0.50, 1.80);
    notifyListeners();
  }

   Future<void> _selectGenderVoiceInEngine(HellOriginalVoiceProfile v) async {
    try {
      await _offlineFallbackTts.setLanguage(selectedLanguage);
      final rawVoices = await _offlineFallbackTts.getVoices;
      if (rawVoices is List) {
        final langPrefix = selectedLanguage.split('-').first.toLowerCase();
        final femaleKeys = <String>['sfb', 'pte', 'afs', 'female', 'feminina', 'raquel', 'francisca', 'joana', 'maria', 'ines', 'luciana', 'heloisa', 'zira', 'hortensia', 'camila', 'vitoria', 'wavenet-a', 'wavenet-c', 'neural2-a'];
        final maleKeys = <String>['ptd', 'ptm', 'male', 'masculina', 'duarte', 'cristiano', 'daniel', 'antonio', 'david', 'pablo', 'ricardo', 'thiago', 'pedro', 'joao', 'wavenet-b', 'wavenet-d', 'neural2-b'];
        final targetKeys = (v.gender == 'F' || v.id == 'child_voice') ? femaleKeys : maleKeys;

        Map<String, String>? chosen;
        for (final item in rawVoices) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            final locale = (item['locale'] ?? '').toString().toLowerCase();
            final lowerName = name.toLowerCase();
                        final normTarget = selectedLanguage.toLowerCase().replaceAll('_', '-');
            final normLocale = locale.replaceAll('_', '-');
            if (normLocale == normTarget && targetKeys.any((k) => lowerName.contains(k))) {

              chosen = <String, String>{'name': name, 'locale': (item['locale'] ?? selectedLanguage).toString()};
              break;
            }
          }
        }
        if (chosen != null) {
          await _offlineFallbackTts.setVoice(chosen);
        }
      }
    } catch (_) {}
  }


   Future<void> _speakOfflineFallback(String text, HellOriginalVoiceProfile v) async {
    try {
      await _offlineFallbackTts.stop();
      await _offlineFallbackTts.awaitSpeakCompletion(true);
      await _selectGenderVoiceInEngine(v);

      double effectivePitch;
      if (v.gender == 'M') {
        final double mult = v.id == 'm_pt_profundo'
            ? 0.62
            : (v.id == 'm_pt_locutor' ? 0.72 : (v.id == 'm_pt_porto' ? 0.76 : 0.84));
        effectivePitch = (customPitch * mult).clamp(0.42, 0.88);
      } else {
        final double floorPitch = v.id == 'f_pt_doce'
            ? 1.46
            : (v.id == 'f_pt_suave' ? 1.35 : (v.id == 'f_pt_locutora' ? 1.28 : 1.18));
        effectivePitch = (customPitch < floorPitch ? floorPitch : customPitch).clamp(1.12, 1.75);
      }

      final double effectiveRate = (customSpeed * 0.48).clamp(0.22, 0.90);
      await _offlineFallbackTts.setPitch(effectivePitch);
      await _offlineFallbackTts.setSpeechRate(effectiveRate);
      await _offlineFallbackTts.speak(text);
    } catch (_) {}
    isSpeaking = false;
    notifyListeners();
    if (_speechQueue.isNotEmpty) {
      _processNextInQueue();
    }
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



       String? _lastTempWavPath;

  Future<void> _playHumanAudio(String text) async {
    final v = currentVoice;

    try {
      if (_lastTempWavPath != null) {
        try {
          final oldFile = File(_lastTempWavPath!);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
      }

      String? wavPath;

      if (v.isCloned && v.samplePath != null && v.samplePath!.isNotEmpty) {
        wavPath = await HellPocketVoiceCloner.cloneSpeakToWav(
          text: text,
          referenceWavPath: v.samplePath!,
          speed: customSpeed,
        );
      } else {
        wavPath = await HellSherpaOfflineEngine.synthesizeToWav(
          text: text,
          voiceId: v.id,
          speed: customSpeed,
        );
      }

      if (wavPath != null && File(wavPath).existsSync()) {
        _lastTempWavPath = wavPath;
        await _player.stop();
        await _player.setPlaybackRate(1.0);
        await _player.play(DeviceFileSource(wavPath));
        return;
      }
    } catch (_) {}

    await _speakOfflineFallback(text, v);
  }




  Future<void> speakImmediateTest(String sampleText) async {
    await _player.stop();
    isSpeaking = true;
    notifyListeners();
    await _playHumanAudio(sampleText);
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
      await _playHumanAudio(nextText);
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
               onVoiceCloned: (name, pitchHz, formantShift, speedFactor, wavPath) async {
          await _ctrl.saveClonedVoice(
            name: name,
            measuredPitchHz: pitchHz,
            measuredFormantShift: formantShift,
            measuredSpeedFactor: speedFactor,
            recordedWavPath: wavPath,
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
                        Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: voices.any((v) => v.id == _ctrl.selectedVoiceId) ? _ctrl.selectedVoiceId : voices.first.id,
                      dropdownColor: const Color(0xFF0B1636),
                      decoration: const InputDecoration(labelText: 'Voz Ativa (Nativas PT-PT & Clonadas)', isDense: true),
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
                  ),
                  if (_ctrl.currentVoice.isCloned) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Excluir voz clonada',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.15),
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () async {
                        final voiceName = _ctrl.currentVoice.label;
                        final ok = await _ctrl.deleteClonedVoice(_ctrl.selectedVoiceId);
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🗑️ Voz clonada "$voiceName" excluída!')),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),

                        const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: HellChatTtsController.supportedLanguages.containsKey(_ctrl.selectedLanguage)
                      ? _ctrl.selectedLanguage
                      : 'pt-PT',
                  dropdownColor: const Color(0xFF0B1636),
                  decoration: const InputDecoration(labelText: 'Idioma da Voz & App', isDense: true),
                  items: HellChatTtsController.supportedLanguages.entries
                      .map((e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _ctrl.selectedLanguage = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
                              ElevatedButton.icon(
                onPressed: () async {
                  await _ctrl.downloadAndApplyLanguage(_ctrl.selectedLanguage);
                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF0B1636),
                      title: Text('A Instalar Voz · ${_ctrl.currentVoice.label.split('·').last.trim()}', style: const TextStyle(fontSize: 14, color: Color(0xFF38BDF8))),
                      content: ValueListenableBuilder<double>(
                        valueListenable: HellSherpaOfflineEngine.downloadProgress,
                        builder: (_, progress, __) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(value: progress, color: const Color(0xFF38BDF8)),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<String>(
                              valueListenable: HellSherpaOfflineEngine.statusText,
                              builder: (_, status, __) => Text(status, style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final ok = await HellSherpaOfflineEngine.ensureVoiceReady(_ctrl.selectedVoiceId);

                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '✅ Voz instalada e pronta offline!'
                              : '⚠️ Não foi possível descarregar agora. Verifica a internet.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download_done_rounded, size: 16),
                label: const Text('Baixar e Aplicar', style: TextStyle(fontSize: 11.5)),
              ),

            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text('Velocidade: ${_ctrl.customSpeed.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 11.5)),
              Expanded(
                child: Slider(
                  value: _ctrl.customSpeed,
                  min: 0.50,
                  max: 1.80,
                  divisions: 26,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) => _ctrl.setCustomSpeed(v),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const Icon(Icons.graphic_eq_rounded, size: 16, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                _ctrl.customPitch < 0.90
                    ? 'Tom: Grave (${_ctrl.customPitch.toStringAsFixed(2)})'
                    : (_ctrl.customPitch > 1.12
                        ? 'Tom: Agudo (${_ctrl.customPitch.toStringAsFixed(2)})'
                        : 'Tom: Normal (${_ctrl.customPitch.toStringAsFixed(2)})'),
                style: const TextStyle(fontSize: 11.5),
              ),
              Expanded(
                child: Slider(
                  value: _ctrl.customPitch,
                  min: 0.50,
                  max: 1.75,
                  divisions: 25,
                  activeColor: Colors.amberAccent,
                  onChanged: (v) => _ctrl.setCustomPitch(v),
                ),
              ),
            ],
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
  final Future<void> Function(String name, double pitchHz, double formantShift, double speedFactor, String? wavPath) onVoiceCloned;


  const HellVoiceCloneTeleprompterDialog({
    super.key,
    required this.defaultOwnerName,
    required this.onVoiceCloned,
  });

  @override
  State<HellVoiceCloneTeleprompterDialog> createState() => _HellVoiceCloneTeleprompterDialogState();
}

class _HellVoiceCloneTeleprompterDialogState extends State<HellVoiceCloneTeleprompterDialog> {
  static const List<String> _teleprompterShortLines = <String>[
    'Olá a todos e sejam muito bem-vindos à live.',
    'Hoje vamos conversar com calma e partilhar boas ideias.',
    'Sintam-se em casa e puxem uma cadeira.',
    'Digam no chat de onde nos estão a acompanhar.',
    'Quando começamos um projeto digital do zero,',
    'cada pequeno detalhe faz toda a diferença.',
    'A clareza da voz e o ritmo natural das palavras',
    'criam uma ligação verdadeira com quem assiste.',
    'Não precisamos de falar depressa nem forçar nada.',
    'Basta sermos autênticos e manter o nosso estilo.',
    'Esta semana preparámos novidades incríveis para criadores.',
    'Alertas interativos e leitura inteligente de mensagens.',
    'Imaginem ouvir os comentários com toda a naturalidade,',
    'sem interromper o raciocínio durante um jogo intenso.',
    'É para isso que serve esta gravação vocal.',
    'Captar o timbre real e a cadência da tua voz.',
    'Agora vamos variar um pouco a entoação.',
    'Primeiro num tom sereno e muito confiante:',
    'Tudo está a funcionar perfeitamente e com som limpo.',
    'Agora com um pouco mais de entusiasmo e energia:',
    'Que jogada espetacular, muito obrigado pelo apoio!',
    'Obrigado pelos presentes enviados agora mesmo no chat!',
    'E agora em tom de pergunta para a comunidade:',
    'Qual é a vossa opinião sobre esta nova função?',
    'Nos dias mais longos de transmissão ao vivo,',
    'a voz fica naturalmente mais tranquila e pausada.',
    'Respirar fundo entre frases ajuda no conforto vocal.',
    'Nos momentos de celebração com a comunidade,',
    'o sorriso nota-se logo na forma como falamos.',
    'Estamos quase a concluir a leitura de calibração.',
    'Obrigado por dedicares este tempo com tanta calma.',
    'O sistema vai analisar a frequência e o ritmo,',
    'criando um perfil exclusivo pronto para as tuas lives.',
    'Até já no estúdio oficial HELL CREATOR!',
  ];

  final AudioRecorder _recorder = AudioRecorder();
  late final TextEditingController _voiceNameCtrl;
  bool _legalConsentAccepted = false;
  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  int _currentLineIndex = 0;
  double _secondsPerLine = 3.8;
  double _lineTimerAcc = 0.0;
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
    final dir = await getApplicationSupportDirectory();

    final path = '${dir.path}/hell_clone_sample_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 24000, numChannels: 1),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _currentLineIndex = 0;
      _lineTimerAcc = 0.0;
      _recordedFilePath = path;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_isPaused) return;

      _lineTimerAcc += 0.5;
      if (_lineTimerAcc >= _secondsPerLine) {
        _lineTimerAcc = 0.0;
        if (_currentLineIndex < _teleprompterShortLines.length - 1) {
          _currentLineIndex++;
        }
      }

      if ((t.tick % 2) == 0) {
        _elapsedSeconds++;
      }
      setState(() {});

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
    double measuredSpeed = 0.96;

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
            measuredSpeed = (0.86 + density * 0.28).clamp(0.85, 1.16);
          }
        }
      }
    } catch (_) {}

    final name = _voiceNameCtrl.text.trim().isEmpty ? widget.defaultOwnerName : _voiceNameCtrl.text.trim();
          await widget.onVoiceCloned(name, measuredPitch, measuredFormant, measuredSpeed, stoppedPath);


    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final int mins = _elapsedSeconds ~/ 60;
    final int secs = _elapsedSeconds % 60;
    final String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} / 02:00';
    final String currentLine = _teleprompterShortLines[_currentLineIndex];
    final String nextLine = (_currentLineIndex + 1 < _teleprompterShortLines.length)
        ? _teleprompterShortLines[_currentLineIndex + 1]
        : 'Fim do texto — podes concluir quando quiseres!';

    return AlertDialog(
      backgroundColor: const Color(0xFF0B1636),
      title: const Text(
        '🎙️ CLONAGEM VOCAL · TELEPONTO LENTO POR FRASES',
        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13.5, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 500,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Ritmo: ${_secondsPerLine.toStringAsFixed(1)}s / frase', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => setState(() => _secondsPerLine = (_secondsPerLine + 0.6).clamp(2.2, 7.0)),
                        child: const Text('+ Mais Lento', style: TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8))),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _secondsPerLine = (_secondsPerLine - 0.6).clamp(2.2, 7.0)),
                        child: const Text('- Mais Rápido', style: TextStyle(fontSize: 11.5, color: Colors.amberAccent)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF04091A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isRecording ? Colors.redAccent : const Color(0xFF38BDF8).withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Frase ${_currentLineIndex + 1} de ${_teleprompterShortLines.length}:',
                      style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentLine,
                      style: const TextStyle(fontSize: 19, height: 1.45, color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const Divider(height: 22, color: Colors.white12),
                    Text(
                      'A seguir: $nextLine',
                      style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.white54),
                    ),
                  ],
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
        if (_isRecording)
          TextButton(
            onPressed: () => setState(() => _isPaused = !_isPaused),
            child: Text(_isPaused ? 'Retomar' : 'Pausar', style: const TextStyle(color: Colors.amberAccent)),
          ),
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
            onPressed: _elapsedSeconds >= 12 ? _finishAndAnalyzeVoice : null,
            icon: const Icon(Icons.check_circle, size: 16),
            label: Text(_elapsedSeconds >= 12 ? 'Concluir e Criar Voz' : 'Lê pelo menos 12s...'),
          ),
      ],
    );
  }
}
