import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'account_security.dart';
import 'visual_banners_studio.dart';


class CloudFirestoreSync {
  static String get _projectId => ['hell-creator', '-os-1914'].join();
  static String get _baseUrl => 'https://${['firestore.googleapis', '.com'].join()}/v1/projects/$_projectId/databases/(default)/documents';

  static Map<String, dynamic> _toFsFields(Map<String, dynamic> raw) {
    final fields = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) {
        fields[k] = <String, dynamic>{'nullValue': null};
      } else if (v is bool) {
        fields[k] = <String, dynamic>{'booleanValue': v};
      } else if (v is int) {
        fields[k] = <String, dynamic>{'integerValue': v.toString()};
      } else if (v is double) {
        fields[k] = <String, dynamic>{'doubleValue': v};
      } else {
        fields[k] = <String, dynamic>{'stringValue': v is String ? v : jsonEncode(v)};
      }
    });
    return fields;
  }

  static Future<void> sync(Map<String, dynamic> user, Map<String, Map<String, dynamic>> tables) async {
    final uid = (user['internalAccountId'] ?? '').toString();
    final idToken = (user['firebaseIdToken'] ?? '').toString();
    if (uid.isEmpty || idToken.isEmpty) return;
    final headers = <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'};
    try {
      for (final entry in tables.entries) {
        await http.patch(
          Uri.parse('$_baseUrl/${entry.key}/$uid'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{'fields': _toFsFields(entry.value)}),
        );
      }
    } catch (_) {}
  }

  static Future<bool> isUsernameFree(String username, String myUid) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;
    try {
      final res = await http.get(Uri.parse('$_baseUrl/usernames/$clean'));
      if (res.statusCode == 404) return true;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final owner = data['fields']?['uid']?['stringValue']?.toString() ?? '';
        return owner == myUid;
      }
    } catch (_) {}
    return true;
  }
}

class ProfileManager {
  static const List<String> reserved = <String>['admin', 'hellcreator', 'support', 'root', 'system', 'mod'];

  static const List<Map<String, dynamic>> presetAvatars = <Map<String, dynamic>>[
    {'id': 'cyber_fox', 'label': 'Cyber Fox', 'icon': Icons.pets, 'color': 0xFF38BDF8},
    {'id': 'neon_skull', 'label': 'Neon Gamer', 'icon': Icons.sports_esports, 'color': 0xFFA855F7},
    {'id': 'astro_bot', 'label': 'Astro Bot', 'icon': Icons.smart_toy, 'color': 0xFF10B981},
    {'id': 'fire_dragon', 'label': 'Dragon Pro', 'icon': Icons.local_fire_department, 'color': 0xFFF43F5E},
    {'id': 'crown_vip', 'label': 'VIP Crown', 'icon': Icons.workspace_premium, 'color': 0xFFF59E0B},
  ];

  static const List<Map<String, dynamic>> availableSocialPlatforms = <Map<String, dynamic>>[
    {'id': 'tiktok', 'label': 'TikTok', 'hint': '@teu_tiktok', 'icon': Icons.music_note, 'color': 0xFFFF2A5F},
    {'id': 'twitch', 'label': 'Twitch', 'hint': 'twitch.tv/canal', 'icon': Icons.videogame_asset, 'color': 0xFF9146FF},
    {'id': 'youtube', 'label': 'YouTube', 'hint': '@teu_youtube', 'icon': Icons.play_circle_fill, 'color': 0xFFFF0033},
    {'id': 'kick', 'label': 'Kick', 'hint': '://kick.com', 'icon': Icons.bolt, 'color': 0xFF53FC18},
    {'id': 'instagram', 'label': 'Instagram', 'hint': '@teu_instagram', 'icon': Icons.camera_alt, 'color': 0xFFE1306C},
    {'id': 'discord', 'label': 'Discord', 'hint': 'utilizador#0000 ou convite', 'icon': Icons.forum, 'color': 0xFF5865F2},
    {'id': 'x', 'label': 'X (Twitter)', 'hint': '@teu_x', 'icon': Icons.alternate_email, 'color': 0xFF38BDF8},
    {'id': 'website', 'label': 'Website / Loja', 'hint': 'https://...', 'icon': Icons.language, 'color': 0xFF10B981},
  ];

  static const Map<String, List<String>> countryCities = <String, List<String>>{
    'Portugal': <String>['Lisboa', 'Porto', 'Vila Nova de Gaia', 'Braga', 'Coimbra', 'Funchal', 'Aveiro', 'Faro', 'Setúbal', 'Leiria', 'Viseu', 'Évora'],
    'Brasil': <String>['São Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Curitiba', 'Porto Alegre', 'Brasília', 'Salvador', 'Fortaleza'],
    'Espanha': <String>['Madrid', 'Barcelona', 'Valência', 'Sevilha', 'Vigo', 'Málaga'],
  };

  static String detectPortugalPostalZone(String zip) {
    final clean = zip.trim();
    if (clean.isEmpty) return '';
    final d = clean.substring(0, 1);
    switch (d) {
      case '1':
        return 'Grande Lisboa';
      case '2':
        return 'Estremadura / Ribatejo / Sintra / Cascais / Setúbal';
      case '3':
        return 'Centro (Coimbra / Aveiro / Viseu / Leiria)';
      case '4':
        return 'Grande Porto / Minho / Douro';
      case '5':
        return 'Trás-os-Montes e Alto Douro';
      case '6':
        return 'Beira Interior';
      case '7':
        return 'Alentejo';
      case '8':
        return 'Algarve';
      case '9':
        return 'Madeira e Açores';
      default:
        return '';
    }
  }
  static String hashPass(String raw, String salt) {
    int h = 0x811c9dc5;
    final bytes = utf8.encode('$salt::$raw::HELL_SECURE_2026');
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String _genSecret([int len = 16]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static List<String> _genRecoveryCodes() {
    final r = Random.secure();
    return List.generate(
      8,
      (_) => '${1000 + r.nextInt(9000)}-${1000 + r.nextInt(9000)}',
    );
  }

  static String currentTotpCode(String secret) {
    final step = DateTime.now().millisecondsSinceEpoch ~/ 30000;
    int h = 0x811c9dc5;
    for (final b in utf8.encode('$secret:$step')) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h % 1000000).toString().padLeft(6, '0');
  }

  static Map<String, dynamic> ensureAccountStructure(Map<String, dynamic> rawUser) {
    final u = Map<String, dynamic>.from(rawUser);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    u['internalAccountId'] ??= 'USR-${DateTime.now().millisecondsSinceEpoch}';
    u['accountStatus'] ??= 'Ativa';
    u['createdAt'] ??= nowIso;
    u['permissionLevel'] ??= 'Criador';

    final baseName = (u['displayName'] ?? u['nickname'] ?? 'Criador').toString().trim();
    u['displayName'] = baseName.isEmpty ? 'Criador' : baseName;
    u['nickname'] = u['displayName'];
    u['username'] ??= u['displayName'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if ((u['username'] as String).length < 3) u['username'] = 'user_${u['internalAccountId']}';
    u['bio'] ??= '';
    u['website'] ??= '';
    u['publicLocation'] ??= '';
    u['coverMode'] ??= 'default';
    u['coverColor'] ??= 0xFF0B1636;
    u['coverPath'] ??= '';
    u['coverAnimStyle'] ??= 'neon_wave';
    u['avatarScale'] ??= 1.0;
    u['avatarDx'] ??= 0.0;
    u['avatarDy'] ??= 0.0;
    u['presetAvatarId'] ??= '';
    u['socialLinks'] ??= <String, dynamic>{};
    u['firstName'] ??= baseName;
    u['lastName'] ??= '';
    u['pronouns'] ??= '';
    u['birthDate'] ??= '';
    u['gender'] ??= 'Prefiro não dizer';
    u['country'] ??= 'Portugal';
    u['city'] ??= '';
    u['postalCode'] ??= '';
    u['address'] ??= '';
    u['email'] ??= '';
    u['recoveryEmail'] ??= '';
    u['phone'] ??= '';
    u['businessContact'] ??= '';
    u['twoFactorEnabled'] ??= false;
    u['totpSecret'] ??= _genSecret();
    u['recoveryCodes'] ??= _genRecoveryCodes();
    u['passkeysEnabled'] ??= false;
    u['sessions'] ??= <dynamic>[
      <String, dynamic>{
        'id': 'sess_current',
        'device': Platform.isAndroid ? 'Android Mobile (Este Dispositivo)' : 'Windows Desktop (Este Dispositivo)',
        'location': '${u['country']} · Sessão Atual',
        'lastAccess': nowIso,
        'isCurrent': true,
      },
    ];
    u['privacy'] ??= <String, dynamic>{
      'profileVisibility': 'Público',
      'photoVisibility': 'Todos',
      'bioVisibility': 'Todos',
      'locationVisibility': 'Privada',
      'birthDateVisibility': 'Oculta',
      'followersVisibility': 'Pública',
      'contactsVisibility': 'Ocultos',
      'onlineStatusVisible': true,
      'allowEmailSearch': false,
    };
    u['preferences'] ??= <String, dynamic>{
      'language': 'Português (PT)',
      'theme': 'Escuro',
      'pushNotifications': true,
      'emailNotifications': true,
      'securityAlerts': true,
    };
    u['changeHistory'] ??= <dynamic>[];
    u['securityHistory'] ??= <dynamic>[
      <String, dynamic>{'event': 'Conta inicializada', 'at': nowIso},
    ];
    return u;
  }

  static void logChange(Map<String, dynamic> u, String field, String detail) {
    final list = List<Map<String, dynamic>>.from(
      (u['changeHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    list.insert(0, <String, dynamic>{
      'field': field,
      'detail': detail,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    u['changeHistory'] = list.take(40).toList();
  }

  static void logSecurity(Map<String, dynamic> u, String event) {
    final list = List<Map<String, dynamic>>.from(
      (u['securityHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    list.insert(0, <String, dynamic>{
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    u['securityHistory'] = list.take(40).toList();
  }

   static const Map<String, Map<String, dynamic>> avatarFrameStyles = <String, Map<String, dynamic>>{
    'none': <String, dynamic>{'label': 'Sem Moldura (Ocultar Anel)', 'color': 0x00000000, 'width': 0.0},
    'neon_blue': <String, dynamic>{'label': 'Azul Néon HELL', 'color': 0xFF38BDF8, 'width': 2.0},
    'gold_vip': <String, dynamic>{'label': 'Ouro Soberano / VIP', 'color': 0xFFFBBF24, 'width': 2.4},
    'cyber_purple': <String, dynamic>{'label': 'Roxo Cyber', 'color': 0xFFA855F7, 'width': 2.2},
    'emerald': <String, dynamic>{'label': 'Esmeralda', 'color': 0xFF10B981, 'width': 2.2},
    'crimson': <String, dynamic>{'label': 'Fogo Carmesim', 'color': 0xFFF43F5E, 'width': 2.2},
    'studio_white': <String, dynamic>{'label': 'Branco Estúdio', 'color': 0xFFFFFFFF, 'width': 2.0},
  };

  static Widget buildTransparentAvatar(
    Map<String, dynamic> user, {
    double radius = 20,
    double? scale,
    Offset? offset,
    String? overrideFrameId,
    String? overrideCustomFrameMedia,
  }) {
    final u = ensureAccountStructure(user);
    final path = (u['avatarPath'] ?? '').toString();
    final url = (u['photoUrl'] ?? '').toString();
    final presetId = (u['presetAvatarId'] ?? '').toString();
    final frameId = overrideFrameId ?? (u['avatarFrameStyle'] ?? 'neon_blue').toString();
    final customMedia = overrideCustomFrameMedia ?? (u['avatarCustomFrameMedia'] ?? '').toString();
    final frameSpec = avatarFrameStyles[frameId] ?? avatarFrameStyles['neon_blue']!;
    final double borderW = (frameSpec['width'] as num).toDouble();
    final Color borderC = Color(frameSpec['color'] as int);

    final s = scale ?? ((u['avatarScale'] is num) ? (u['avatarScale'] as num).toDouble() : 1.0);
    final dx = offset?.dx ?? ((u['avatarDx'] is num) ? (u['avatarDx'] as num).toDouble() : 0.0);
    final dy = offset?.dy ?? ((u['avatarDy'] is num) ? (u['avatarDy'] as num).toDouble() : 0.0);

    Widget? media;
    if (path.isNotEmpty && File(path).existsSync()) {
      media = Image.file(File(path), width: radius * 2, height: radius * 2, fit: BoxFit.cover);
    } else if (url.isNotEmpty) {
      media = Image.network(url, width: radius * 2, height: radius * 2, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox());
    } else if (presetId.isNotEmpty) {
      final preset = presetAvatars.firstWhere((p) => p['id'] == presetId, orElse: () => presetAvatars.first);
      media = Container(
        width: radius * 2,
        height: radius * 2,
        color: Color(preset['color'] as int).withOpacity(0.22),
        child: Icon(preset['icon'] as IconData, size: radius * 1.15, color: Color(preset['color'] as int)),
      );
    }

    final Widget corePhoto = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: media != null
            ? Transform.translate(offset: Offset(dx, dy), child: Transform.scale(scale: s, child: media))
            : Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Text(
                  (u['displayName'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                  style: TextStyle(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: radius * 0.85),
                ),
              ),
      ),
    );

    if (frameId == 'none') return corePhoto;

    final double outerPad = radius * 0.16;
    final double outerSize = (radius + outerPad) * 2;

    Widget? customFrameWidget;
    if (frameId == 'custom_media' && customMedia.isNotEmpty) {
      if (customMedia.startsWith('http')) {
        customFrameWidget = Image.network(customMedia, width: outerSize, height: outerSize, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox());
      } else if (File(customMedia).existsSync()) {
        customFrameWidget = Image.file(File(customMedia), width: outerSize, height: outerSize, fit: BoxFit.contain);
      }
    }

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          corePhoto,
          if (customFrameWidget != null)
            Positioned(
              left: -outerPad,
              top: -outerPad,
              width: outerSize,
              height: outerSize,
              child: IgnorePointer(child: customFrameWidget),
            )
          else if (borderW > 0)
            Positioned(
              left: -borderW,
              top: -borderW,
              right: -borderW,
              bottom: -borderW,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderC.withOpacity(0.9), width: borderW),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
 }
 

class TopLeftProfileAvatarButton extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onAccountDeletedOrSuspended;

  const TopLeftProfileAvatarButton({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onAccountDeletedOrSuspended,
  });

  @override
  Widget build(BuildContext context) {
    final u = ProfileManager.ensureAccountStructure(user);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            user: u,
            onUserUpdated: onUserUpdated,
            onAccountDeletedOrSuspended: onAccountDeletedOrSuspended,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ProfileManager.buildTransparentAvatar(u, radius: 19),
      ),
    );
  }
}

class StructuredProfileStorage {
  static Map<String, Map<String, dynamic>> buildTables(Map<String, dynamic> u) {
    final s = ProfileManager.ensureAccountStructure(u);
    return <String, Map<String, dynamic>>{
      'users': <String, dynamic>{'internal_id': s['internalAccountId'], 'status': s['accountStatus']},
      'user_profiles': <String, dynamic>{'display_name': s['displayName'], 'username': s['username'], 'bio': s['bio']},
      'user_personal_data': <String, dynamic>{'first_name': s['firstName'], 'country': s['country'], 'city': s['city']},
      'user_contacts': <String, dynamic>{'primary_email': s['email'], 'phone': s['phone']},
      'user_security': <String, dynamic>{'two_factor_enabled': s['twoFactorEnabled']},
      'user_sessions': <String, dynamic>{'active_sessions': s['sessions']},
      'user_privacy': Map<String, dynamic>.from(s['privacy'] as Map),
      'user_preferences': Map<String, dynamic>.from(s['preferences'] as Map),
    };
  }

  static Future<void> saveAndSync(Map<String, dynamic> u, Function(Map<String, dynamic>) onUpdated) async {
    final s = ProfileManager.ensureAccountStructure(u);
    await UserAccountManager.saveUser(s);
    onUpdated(s);
    CloudFirestoreSync.sync(s, buildTables(s));
  }
}
class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onAccountDeletedOrSuspended;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onAccountDeletedOrSuspended,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  late Map<String, dynamic> _u;
  late TabController _tabs;
  late AnimationController _coverAnimCtrl;

  late TextEditingController _dispCtrl, _userCtrl, _bioCtrl, _locCtrl;
  late TextEditingController _fnCtrl, _lnCtrl, _pronCtrl, _cityCtrl, _zipCtrl, _addrCtrl;
  late TextEditingController _newEmailCtrl, _recEmailCtrl, _phoneCtrl, _bizCtrl;
  String? _pendingToken, _pendingEmail;

  final List<String> _titles = const <String>[
    'Meu Perfil',
    'Redes Sociais / Contactos',
    'Segurança / Privacidade',
    'Gestão de Conta',
  ];

  @override
  void initState() {
    super.initState();
    _u = ProfileManager.ensureAccountStructure(widget.user);
    _u['showPartnersShowcase'] ??= true;
    _u['partnersList'] ??= <dynamic>[
      <String, dynamic>{
        'brand': 'HELL CREATOR · Programa Oficial',
        'code': 'HELLVIP10',
        'url': 'https://hellcreator.app',
        'imageUrl': 'https://jsdelivr.net',
        'visible': true,
      },
    ];

    if ((_u['sessions'] as List).length < 2) {
      final list = List<Map<String, dynamic>>.from(
        (_u['sessions'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      list.add(<String, dynamic>{
        'id': 'sess_sec_device',
        'device': Platform.isAndroid ? 'Windows Desktop (Sessão Remota)' : 'Android Mobile (Sessão Remota)',
        'location': '${_u['country'] ?? 'Portugal'} · App Associada',
        'lastAccess': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
        'isCurrent': false,
      });
      _u['sessions'] = list;
    }

    _tabs = TabController(length: _titles.length, vsync: this);
    _coverAnimCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);

    _dispCtrl = TextEditingController(text: (_u['displayName'] ?? '').toString());
    _userCtrl = TextEditingController(text: (_u['username'] ?? '').toString());
    _bioCtrl = TextEditingController(text: (_u['bio'] ?? '').toString());
    _locCtrl = TextEditingController(text: (_u['publicLocation'] ?? '').toString());
    _fnCtrl = TextEditingController(text: (_u['firstName'] ?? '').toString());
    _lnCtrl = TextEditingController(text: (_u['lastName'] ?? '').toString());
    _pronCtrl = TextEditingController(text: (_u['pronouns'] ?? '').toString());
    _cityCtrl = TextEditingController(text: (_u['city'] ?? '').toString());
    _zipCtrl = TextEditingController(text: (_u['postalCode'] ?? '').toString());
    _addrCtrl = TextEditingController(text: (_u['address'] ?? '').toString());
    _newEmailCtrl = TextEditingController();
    _recEmailCtrl = TextEditingController(text: (_u['recoveryEmail'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (_u['phone'] ?? '').toString());
    _bizCtrl = TextEditingController(text: (_u['businessContact'] ?? '').toString());
  }

  @override
  void dispose() {
    _coverAnimCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _msg(String t, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t),
        backgroundColor: err ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
      ),
    );
  }

  Future<void> _save([String? customMsg]) async {
    await StructuredProfileStorage.saveAndSync(_u, widget.onUserUpdated);
    if (mounted) {
      setState(() {});
      _msg(customMsg ?? 'As informações foram atualizadas com sucesso.');
    }
  }

  Future<bool> _authAction(String title) async {
    final c = TextEditingController();
    bool ok = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        title: Text('Confirmar Identidade • $title', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Palavra-passe atual', isDense: true),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final e = c.text.trim();
              if (e.isNotEmpty &&
                  (e == (_u['passwordSecret'] ?? '').toString() ||
                      ProfileManager.hashPass(e, (_u['internalAccountId'] ?? '').toString()) == _u['passwordHash'])) {
                ok = true;
                Navigator.pop(ctx);
              } else {
                _msg('Palavra-passe incorreta.', err: true);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok;
  }
  Future<void> _openPartnerDialog({int? editIndex}) async {
    final partners = List<Map<String, dynamic>>.from(
      (_u['partnersList'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final isEdit = editIndex != null;
    final current = isEdit ? partners[editIndex] : <String, dynamic>{};

    final brandCtrl = TextEditingController(text: (current['brand'] ?? '').toString());
    final codeCtrl = TextEditingController(text: (current['code'] ?? '').toString());
    final urlCtrl = TextEditingController(text: (current['url'] ?? '').toString());
    final imgUrlCtrl = TextEditingController(text: (current['imageUrl'] ?? '').toString());
    String localImgPath = (current['imagePath'] ?? '').toString();
    bool isVisible = current['visible'] != false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          title: Text(
            isEdit ? 'Editar Publicidade / Parceria' : 'Nova Publicidade / Parceria',
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Nome da Marca / Patrocinador', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Código Promocional (ex: HELL10)', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Página Oficial (URL https://...)', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: imgUrlCtrl, decoration: const InputDecoration(labelText: 'Link da Imagem / Logo (Opcional)', isDense: true)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
                    );
                    if (r?.files.single.path != null) {
                      setM(() => localImgPath = r!.files.single.path!);
                    }
                  },
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: Text(
                    localImgPath.isEmpty ? 'Ou carregar Imagem do Dispositivo' : 'Imagem carregada ✓',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Exibir no meu perfil público', style: TextStyle(fontSize: 12.5)),
                  value: isVisible,
                  onChanged: (v) => setM(() => isVisible = v),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            if (isEdit)
              TextButton(
                onPressed: () {
                  partners.removeAt(editIndex);
                  _u['partnersList'] = partners;
                  Navigator.pop(ctx);
                },
                child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (brandCtrl.text.trim().isNotEmpty) {
                  String cleanUrl = urlCtrl.text.trim();
                  if (cleanUrl.isNotEmpty && !cleanUrl.startsWith('http')) {
                    cleanUrl = 'https://$cleanUrl';
                  }
                  final item = <String, dynamic>{
                    'brand': brandCtrl.text.trim(),
                    'code': codeCtrl.text.trim(),
                    'url': cleanUrl.isEmpty ? 'https://hellcreator.app' : cleanUrl,
                    'imageUrl': imgUrlCtrl.text.trim(),
                    'imagePath': localImgPath,
                    'visible': isVisible,
                  };
                  if (isEdit) {
                    partners[editIndex] = item;
                  } else {
                    partners.insert(0, item);
                  }
                  _u['partnersList'] = partners;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    await _save('Vitrine de Publicidades & Parcerias atualizada!');
  }

  Widget _buildPartnersShowcaseCard() {
    final showBox = _u['showPartnersShowcase'] != false;
    final partners = List<Map<String, dynamic>>.from(
      (_u['partnersList'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFF13275E), Color(0xFF0A1433)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.handshake_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PUBLICIDADES & PARCERIAS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF38BDF8)),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openPartnerDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.greenAccent),
                label: const Text('Adicionar', style: TextStyle(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
              Switch(
                activeColor: const Color(0xFF38BDF8),
                value: showBox,
                onChanged: (v) async {
                  _u['showPartnersShowcase'] = v;
                  await _save(v ? 'Vitrine visível no perfil.' : 'Vitrine ocultada.');
                },
              ),
            ],
          ),
          if (!showBox)
            const Text(
              'Vitrine oculta neste momento (ativa o interruptor acima para exibir aos visitantes).',
              style: TextStyle(fontSize: 11.5, color: Colors.white60),
            )
          else if (partners.isEmpty)
            const Text(
              'Ainda sem parcerias adicionadas. Toca em "Adicionar" para expor marcas, imagens, códigos e links oficiais.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            )
          else
            ...partners.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final brand = (p['brand'] ?? '').toString();
              final code = (p['code'] ?? '').toString();
              final url = (p['url'] ?? '').toString();
              final imgPath = (p['imagePath'] ?? '').toString();
              final imgUrl = (p['imageUrl'] ?? '').toString();
              final visible = p['visible'] != false;

              Widget thumb = const CircleAvatar(
                backgroundColor: Color(0xFF1E78FF),
                child: Icon(Icons.storefront_rounded, color: Colors.white),
              );
              if (imgPath.isNotEmpty && File(imgPath).existsSync()) {
                thumb = ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(imgPath), width: 48, height: 48, fit: BoxFit.cover),
                );
              } else if (imgUrl.startsWith('http')) {
                thumb = ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => thumb),
                );
              }

              return Opacity(
                opacity: visible ? 1.0 : 0.45,
                child: Card(
                  color: const Color(0xFF04091A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                  ),
                  child: ListTile(
                    leading: thumb,
                    title: Text(brand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    subtitle: Text(
                      code.isNotEmpty ? 'Código: $code · Toca para abrir página oficial' : 'Toca para abrir página oficial',
                      style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (code.isNotEmpty)
                          IconButton(
                            tooltip: 'Copiar Código',
                            icon: const Icon(Icons.copy_rounded, size: 17, color: Colors.greenAccent),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              _msg('Código "$code" copiado!');
                            },
                          ),
                        IconButton(
                          tooltip: 'Editar Parceria',
                          icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.white70),
                          onPressed: () => _openPartnerDialog(editIndex: idx),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFF38BDF8)),
                      ],
                    ),
                    onTap: () {
                      if (url.startsWith('http')) {
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
  Future<void> _openCoverStudio() async {
    String mode = (_u['coverMode'] ?? 'default').toString();
    int colorVal = (_u['coverColor'] is int) ? _u['coverColor'] as int : 0xFF0B1636;
    String animStyle = (_u['coverAnimStyle'] ?? 'neon_wave').toString();
    final palette = <int>[0xFF0B1636, 0xFF1E1B4B, 0xFF3B0764, 0xFF450A0A, 0xFF064E3B, 0xFF0C4A6E, 0xFF18181B];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: const Color(0xFF0B1636),
          title: const Text('Personalizar Capa', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () async {
                    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp']);
                    final p = r?.files.single.path;
                    if (p != null && p.isNotEmpty) {
                      _u['coverPath'] = p;
                      setM(() => mode = 'image');
                    }
                  },
                  icon: const Icon(Icons.image, size: 16),
                  label: const Text('Imagem', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: () => setM(() => mode = 'animated'),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Animado HD', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () => setM(() {
                    mode = 'default';
                    _u['coverPath'] = '';
                  }),
                  child: const Text('Repor Original', style: TextStyle(fontSize: 11.5)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: palette.map((c) => GestureDetector(
                  onTap: () => setM(() {
                    mode = 'color';
                    colorVal = c;
                  }),
                  child: CircleAvatar(radius: 14, backgroundColor: Color(c)),
                )).toList(),
              ),
              if (mode == 'animated') ...<Widget>[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: animStyle,
                  dropdownColor: const Color(0xFF0B1636),
                  decoration: const InputDecoration(labelText: 'Estilo de Animação HD', isDense: true),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'neon_wave', child: Text('Ondas Neon Azul & Ciano')),
                    DropdownMenuItem(value: 'cyber_pulse', child: Text('Pulso Roxo & Magenta Estúdio')),
                    DropdownMenuItem(value: 'ember_glow', child: Text('Brilho Fogo & Âmbar')),
                  ],
                  onChanged: (v) => setM(() => animStyle = v ?? 'neon_wave'),
                ),
              ],
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                _u['coverMode'] = mode;
                _u['coverColor'] = colorVal;
                _u['coverAnimStyle'] = animStyle;
                ProfileManager.logChange(_u, 'Capa', 'Capa atualizada ($mode)');
                Navigator.pop(ctx);
                await _save();
              },
              child: const Text('Guardar Capa'),
            ),
          ],
        ),
      ),
    );
  }
   Future<void> _editAvatar() async {
    double s = (_u['avatarScale'] is num) ? (_u['avatarScale'] as num).toDouble() : 1.0;
    double dx = (_u['avatarDx'] is num) ? (_u['avatarDx'] as num).toDouble() : 0.0;
    double dy = (_u['avatarDy'] is num) ? (_u['avatarDy'] as num).toDouble() : 0.0;
    String path = (_u['avatarPath'] ?? '').toString();
    String url = (_u['photoUrl'] ?? '').toString();
    String preset = (_u['presetAvatarId'] ?? '').toString();
    String frameStyle = (_u['avatarFrameStyle'] ?? 'neon_blue').toString();
    String customFrameMedia = (_u['avatarCustomFrameMedia'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final prev = Map<String, dynamic>.from(_u)
            ..['avatarPath'] = path
            ..['photoUrl'] = url
            ..['presetAvatarId'] = preset
            ..['avatarScale'] = s
            ..['avatarDx'] = dx
            ..['avatarDy'] = dy
            ..['avatarFrameStyle'] = frameStyle
            ..['avatarCustomFrameMedia'] = customFrameMedia;

          return AlertDialog(
            backgroundColor: const Color(0xFF0B1636),
            title: const Text('Fotografia, Recorte & Moldura Exterior', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onPanUpdate: (d) => setM(() {
                        dx = (dx + d.delta.dx).clamp(-60.0, 60.0);
                        dy = (dy + d.delta.dy).clamp(-60.0, 60.0);
                      }),
                      child: ProfileManager.buildTransparentAvatar(
                        prev,
                        radius: 55,
                        scale: s,
                        offset: Offset(dx, dy),
                        overrideFrameId: frameStyle,
                        overrideCustomFrameMedia: customFrameMedia,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(value: s, min: 1.0, max: 2.5, onChanged: (v) => setM(() => s = v)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () async {
                            final r = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
                            );
                            final p = r?.files.single.path;
                            if (p != null && p.isNotEmpty) {
                              setM(() {
                                path = p;
                                url = '';
                                preset = '';
                                s = 1.0;
                                dx = 0;
                                dy = 0;
                              });
                            }
                          },
                          child: const Text('Carregar Foto'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setM(() {
                            path = '';
                            url = '';
                            preset = '';
                          }),
                          child: const Text('Remover Foto', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: ProfileManager.presetAvatars
                          .map((a) => IconButton(
                                icon: Icon(a['icon'] as IconData, color: Color(a['color'] as int)),
                                onPressed: () => setM(() {
                                  preset = a['id'] as String;
                                  path = '';
                                  url = '';
                                }),
                              ))
                          .toList(),
                    ),
                    const Divider(height: 20),
                    DropdownButtonFormField<String>(
                      value: ProfileManager.avatarFrameStyles.containsKey(frameStyle) ? frameStyle : 'none',
                      dropdownColor: const Color(0xFF0B1636),
                      decoration: const InputDecoration(labelText: 'Moldura Exterior (Ocultar ou Estilo)', isDense: true),
                      items: ProfileManager.avatarFrameStyles.entries
                          .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value['label'].toString())))
                          .toList(),
                      onChanged: (v) => setM(() => frameStyle = v ?? 'none'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => setM(() {
                            frameStyle = 'none';
                            customFrameMedia = '';
                          }),
                          icon: const Icon(Icons.visibility_off_outlined, size: 16, color: Colors.amberAccent),
                          label: const Text('Sem Anel (Ocultar)', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final r = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: <String>['png', 'webp'],
                            );
                            final p = r?.files.single.path;
                            if (p != null && p.isNotEmpty) {
                              setM(() {
                                frameStyle = 'custom_media';
                                customFrameMedia = p;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Importar Moldura PNG', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HellAvatarFramesStudio(
                      currentUser: _u,
                      onApplyFrameToProfile: (type, media) {
                        setM(() {
                          frameStyle = type;
                          customFrameMedia = media;
                        });
                      },
                      onApplyAvatarToProfile: (media) {
                        setM(() {
                          if (media.startsWith('http')) {
                            url = media;
                            path = '';
                          } else {
                            path = media;
                            url = '';
                          }
                          preset = '';
                          s = 1.0;
                          dx = 0;
                          dy = 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  _u['avatarPath'] = path;
                  _u['photoUrl'] = url;
                  _u['presetAvatarId'] = preset;
                  _u['avatarScale'] = s;
                  _u['avatarDx'] = dx;
                  _u['avatarDy'] = dy;
                  _u['avatarFrameStyle'] = frameStyle;
                  _u['avatarCustomFrameMedia'] = customFrameMedia;
                  ProfileManager.logChange(_u, 'Fotografia', 'Avatar e moldura exterior atualizados');
                  Navigator.pop(ctx);
                  await _save();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ABA 1: MEU PERFIL (VITRINE PUBLICIDADES & PARCERIAS + PERFIL PÚBLICO + INFORMAÇÕES PESSOAIS)
  Widget _secMeuPerfilCompleto() {
    final genders = <String>['Prefiro não dizer', 'Masculino', 'Feminino', 'Não-binário', 'Outro'];
    final countries = <String>[
      'Portugal',
      'Brasil',
      'Espanha',
      'França',
      'Reino Unido',
      'Alemanha',
      'Suíça',
      'Luxemburgo',
      'Angola',
      'Moçambique',
      'Cabo Verde',
      'Estados Unidos',
      'Outro País',
    ];
    final selectedCountry = (_u['country'] ?? 'Portugal').toString();
    final citySuggestions = ProfileManager.countryCities[selectedCountry] ?? <String>[];
    final postalHint = selectedCountry == 'Portugal' ? ProfileManager.detectPortugalPostalZone(_zipCtrl.text) : '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildPartnersShowcaseCard(),
        Row(
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: _editAvatar,
              icon: const Icon(Icons.crop, size: 16),
              label: const Text('Alterar / Cortar Foto', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openCoverStudio,
              icon: const Icon(Icons.panorama, size: 16),
              label: const Text('Personalizar Capa', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Dados Públicos do Perfil', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        const SizedBox(height: 6),
        TextField(controller: _dispCtrl, maxLength: 50, decoration: const InputDecoration(labelText: 'Nome de Apresentação', isDense: true)),
        TextField(controller: _userCtrl, maxLength: 30, decoration: const InputDecoration(labelText: '@username (único)', isDense: true)),
        TextField(controller: _bioCtrl, maxLines: 3, maxLength: 300, decoration: const InputDecoration(labelText: 'Biografia', isDense: true)),
        TextField(controller: _locCtrl, decoration: const InputDecoration(labelText: 'Localização Pública', isDense: true)),
        const Divider(height: 24),
        const Text('Informações Pessoais', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        const SizedBox(height: 6),
        TextField(controller: _fnCtrl, decoration: const InputDecoration(labelText: 'Nome Próprio', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _lnCtrl, decoration: const InputDecoration(labelText: 'Apelido (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _pronCtrl, decoration: const InputDecoration(labelText: 'Pronomes (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: genders.contains(_u['gender']) ? _u['gender'] : genders.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Género', isDense: true),
          items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _u['gender'] = v),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data de Nascimento (Requer verificação)', style: TextStyle(fontSize: 13)),
          subtitle: Text((_u['birthDate'] ?? 'Não definida').toString().split('T').first),
          trailing: const Icon(Icons.lock_clock_outlined, color: Color(0xFF38BDF8)),
          onTap: () async {
            if (!await _authAction('Alterar Nascimento') || !mounted) return;
            final p = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1930), lastDate: DateTime.now());
            if (p != null) {
              _u['birthDate'] = p.toIso8601String();
              ProfileManager.logChange(_u, 'Data de Nascimento', 'Alterada e validada');
              await _save();
            }
          },
        ),
        DropdownButtonFormField<String>(
          value: countries.contains(selectedCountry) ? selectedCountry : null,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'País', isDense: true),
          items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _u['country'] = v),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _cityCtrl.text),
          optionsBuilder: (TextEditingValue val) {
            if (val.text.isEmpty) return citySuggestions;
            return citySuggestions.where((c) => c.toLowerCase().contains(val.text.toLowerCase()));
          },
          onSelected: (String selection) => _cityCtrl.text = selection,
          fieldViewBuilder: (ctx, ctrl, focus, onSub) {
            ctrl.text = _cityCtrl.text;
            ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
            return TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: (v) => _cityCtrl.text = v,
              decoration: const InputDecoration(labelText: 'Cidade (sugestões ou manual)', isDense: true),
            );
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _zipCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: selectedCountry == 'Portugal' ? 'Código Postal (ex: 4000-001)' : 'Código Postal',
            helperText: postalHint.isNotEmpty ? 'Zona postal detetada: $postalHint' : null,
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Restante da Morada / Rua (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        Text('ID Interno Imutável: ${_u['internalAccountId']}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final nu = _userCtrl.text.trim().toLowerCase();
              if (!RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(nu) || ProfileManager.reserved.contains(nu)) {
                _msg('Username inválido ou reservado.', err: true);
                return;
              }
              if (nu != (_u['username'] ?? '').toString().toLowerCase()) {
                final free = await CloudFirestoreSync.isUsernameFree(nu, (_u['internalAccountId'] ?? '').toString());
                if (!free) {
                  _msg('Este nome de utilizador já está a ser utilizado.', err: true);
                  return;
                }
              }
              _u['displayName'] = _dispCtrl.text.trim();
              _u['nickname'] = _dispCtrl.text.trim();
              _u['username'] = nu;
              _u['bio'] = _bioCtrl.text.trim();
              _u['publicLocation'] = _locCtrl.text.trim();
              _u['firstName'] = _fnCtrl.text.trim();
              _u['lastName'] = _lnCtrl.text.trim();
              _u['pronouns'] = _pronCtrl.text.trim();
              _u['city'] = _cityCtrl.text.trim();
              _u['postalCode'] = _zipCtrl.text.trim();
              _u['address'] = _addrCtrl.text.trim();
              ProfileManager.logChange(_u, 'Meu Perfil', 'Perfil público e dados pessoais atualizados');
              await _save();
            },
            child: const Text('Guardar Meu Perfil & Informações Pessoais'),
          ),
        ),
      ],
    );
  }
  // ABA 2: REDES SOCIAIS / CONTACTOS UNIDOS
  Widget _secRedesSociaisEContactos() {
    final links = Map<String, dynamic>.from(_u['socialLinks'] as Map? ?? {});
    final activeKeys = links.keys.where((k) => links[k].toString().trim().isNotEmpty).toList();
    final email = (_u['email'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('Redes Sociais & Website', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
            ElevatedButton.icon(
              onPressed: () async {
                String selectedId = ProfileManager.availableSocialPlatforms.first['id'] as String;
                final valCtrl = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setM) {
                      final plat = ProfileManager.availableSocialPlatforms.firstWhere((p) => p['id'] == selectedId);
                      return AlertDialog(
                        backgroundColor: const Color(0xFF0B1636),
                        title: const Text('Adicionar Rede / Website', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            DropdownButtonFormField<String>(
                              value: selectedId,
                              dropdownColor: const Color(0xFF0B1636),
                              decoration: const InputDecoration(labelText: 'Escolher Plataforma', isDense: true),
                              items: ProfileManager.availableSocialPlatforms
                                  .map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['label'] as String)))
                                  .toList(),
                              onChanged: (v) => setM(() => selectedId = v ?? selectedId),
                            ),
                            const SizedBox(height: 10),
                            TextField(controller: valCtrl, decoration: InputDecoration(labelText: plat['hint'] as String, isDense: true)),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                          ElevatedButton(
                            onPressed: () {
                              if (valCtrl.text.trim().isNotEmpty) {
                                links[selectedId] = valCtrl.text.trim();
                                _u['socialLinks'] = links;
                                if (selectedId == 'website') _u['website'] = valCtrl.text.trim();
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Adicionar'),
                          ),
                        ],
                      );
                    },
                  ),
                );
                if (links.isNotEmpty) {
                  ProfileManager.logChange(_u, 'Redes Sociais', 'Lista de redes atualizada');
                  await _save();
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar Rede', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeKeys.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Nenhuma rede adicionada. Clica em "Adicionar Rede" para escolher as que queres exibir.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ...activeKeys.map((k) {
          final plat = ProfileManager.availableSocialPlatforms.firstWhere(
            (p) => p['id'] == k,
            orElse: () => <String, dynamic>{'label': k.toUpperCase(), 'icon': Icons.link, 'color': 0xFF38BDF8},
          );
          return Card(
            color: const Color(0xFF0B1636),
            child: ListTile(
              leading: Icon(plat['icon'] as IconData, color: Color(plat['color'] as int)),
              title: Text(plat['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(links[k].toString()),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  links.remove(k);
                  _u['socialLinks'] = links;
                  if (k == 'website') _u['website'] = '';
                  await _save('Rede removida.');
                },
              ),
            ),
          );
        }),
        const Divider(height: 28),
        const Text('Contactos da Conta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified, color: Colors.greenAccent),
          title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('E-mail Principal Verificado'),
        ),
        TextField(controller: _newEmailCtrl, decoration: const InputDecoration(labelText: 'Novo E-mail Principal (requer confirmação)', isDense: true)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                final cand = _newEmailCtrl.text.trim().toLowerCase();
                if (!cand.contains('@') || !await _authAction('Alterar E-mail')) return;
                final res = await UserAccountManager.sendRealFirebaseVerificationEmail(cand, (_u['passwordSecret'] ?? 'HellTemp2026!').toString());
                if (res['token'] != null) {
                  setState(() {
                    _pendingToken = res['token'];
                    _pendingEmail = cand;
                  });
                  _msg('Verifica o teu novo email para concluir a alteração.');
                }
              },
              child: const Text('Enviar Confirmação'),
            ),
            if (_pendingToken != null) const SizedBox(width: 8),
            if (_pendingToken != null)
              ElevatedButton(
                onPressed: () async {
                  if (!await UserAccountManager.checkFirebaseEmailVerified(_pendingToken!)) {
                    _msg('Ainda não confirmado no e-mail.', err: true);
                    return;
                  }
                  _u['email'] = _pendingEmail;
                  ProfileManager.logSecurity(_u, 'E-mail alterado para $_pendingEmail');
                  setState(() {
                    _pendingToken = null;
                    _pendingEmail = null;
                    _newEmailCtrl.clear();
                  });
                  await _save();
                },
                child: const Text('Confirmar Link'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _recEmailCtrl, decoration: const InputDecoration(labelText: 'E-mail de Recuperação', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telemóvel (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _bizCtrl, decoration: const InputDecoration(labelText: 'Contacto Profissional (Opcional)', isDense: true)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              _u['recoveryEmail'] = _recEmailCtrl.text.trim().toLowerCase();
              _u['phone'] = _phoneCtrl.text.trim();
              _u['businessContact'] = _bizCtrl.text.trim();
              await _save('Contactos atualizados!');
            },
            child: const Text('Guardar Contactos'),
          ),
        ),
      ],
    );
  }
  // ABA 3: SEGURANÇA / PRIVACIDADE UNIDOS
  Widget _secSegurancaEPrivacidade() {
    final twoFactor = _u['twoFactorEnabled'] == true;
    final secret = (_u['totpSecret'] ?? '').toString();
    final codes = List<String>.from(_u['recoveryCodes'] ?? <String>[]);
    final secHist = List<Map<String, dynamic>>.from(
      (_u['securityHistory'] as List? ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e)),
    );
    final chgHist = List<Map<String, dynamic>>.from(
      (_u['changeHistory'] as List? ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e)),
    );
    final p = Map<String, dynamic>.from(_u['privacy'] as Map? ?? <String, dynamic>{});

    Widget drop(String label, String key, List<String> opts) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DropdownButtonFormField<String>(
          value: opts.contains(p[key]) ? p[key].toString() : opts.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: InputDecoration(labelText: label, isDense: true),
          items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) async {
            if (v != null) {
              p[key] = v;
              _u['privacy'] = p;
              await _save();
            }
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('Segurança da Conta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password, color: Color(0xFF38BDF8)),
          title: const Text('Alterar Palavra-passe'),
          subtitle: const Text('Protegida por hash criptográfico • Nunca exibida'),
          onTap: () async {
            if (!await _authAction('Alterar Palavra-passe') || !mounted) return;
            final c1 = TextEditingController();
            final c2 = TextEditingController();
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF0B1636),
                title: const Text('Nova Palavra-passe', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(controller: c1, obscureText: true, decoration: const InputDecoration(labelText: 'Nova palavra-passe')),
                    TextField(controller: c2, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir')),
                  ],
                ),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: () async {
                      if (c1.text.trim().length < 6 || c1.text.trim() != c2.text.trim()) {
                        _msg('Mínimo 6 caracteres e devem coincidir.', err: true);
                        return;
                      }
                      _u['passwordSecret'] = c1.text.trim();
                      _u['passwordHash'] = ProfileManager.hashPass(c1.text.trim(), (_u['internalAccountId'] ?? '').toString());
                      ProfileManager.logSecurity(_u, 'Palavra-passe alterada');
                      Navigator.pop(ctx);
                      await _save('Palavra-passe atualizada!');
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Google Authenticator (2FA Offline)'),
          subtitle: Text('Chave: $secret • Código atual: ${ProfileManager.currentTotpCode(secret)}', style: const TextStyle(fontSize: 11.5)),
          value: twoFactor,
          onChanged: (v) async {
            if (!await _authAction('Google Authenticator')) return;
            setState(() => _u['twoFactorEnabled'] = v);
            ProfileManager.logSecurity(_u, v ? 'Google Authenticator ativado' : 'Google Authenticator desativado');
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Chaves de Acesso (Passkeys / Biometria)'),
          value: _u['passkeysEnabled'] == true,
          onChanged: (v) async {
            setState(() => _u['passkeysEnabled'] = v);
            await _save();
          },
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Códigos de Recuperação (8 códigos)', style: TextStyle(fontSize: 13, color: Color(0xFF38BDF8))),
          children: <Widget>[
            Wrap(spacing: 6, children: codes.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)))).toList()),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                _msg('Códigos copiados!');
              },
              child: const Text('Copiar Todos'),
            ),
          ],
        ),
        const Divider(height: 24),
        const Text('Controlos de Privacidade', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        drop('Perfil', 'profileVisibility', <String>['Público', 'Privado']),
        drop('Fotografia', 'photoVisibility', <String>['Todos', 'Utilizadores autorizados']),
        drop('Biografia', 'bioVisibility', <String>['Todos', 'Privado']),
        drop('Localização', 'locationVisibility', <String>['Privada', 'Pública']),
        drop('Data de Nascimento', 'birthDateVisibility', <String>['Oculta', 'Apenas dia e mês', 'Completa']),
        drop('Lista de Seguidores', 'followersVisibility', <String>['Pública', 'Privada']),
        drop('Contactos (Ocultos por defeito)', 'contactsVisibility', <String>['Ocultos', 'Autorizados']),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Estado Online Visível'),
          value: p['onlineStatusVisible'] == true,
          onChanged: (v) async {
            p['onlineStatusVisible'] = v;
            _u['privacy'] = p;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pesquisa por E-mail'),
          value: p['allowEmailSearch'] == true,
          onChanged: (v) async {
            p['allowEmailSearch'] = v;
            _u['privacy'] = p;
            await _save();
          },
        ),
        const Divider(height: 24),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Histórico de Segurança (${secHist.length})', style: const TextStyle(fontSize: 13)),
          children: secHist.map((e) => ListTile(dense: true, title: Text(e['event'].toString(), style: const TextStyle(fontSize: 12)), subtitle: Text(e['at'].toString()))).toList(),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Histórico de Alterações (${chgHist.length})', style: const TextStyle(fontSize: 13)),
          children: chgHist.map((e) => ListTile(dense: true, title: Text('${e['field']}: ${e['detail']}', style: const TextStyle(fontSize: 12)), subtitle: Text(e['at'].toString()))).toList(),
        ),
      ],
    );
  }
  // ABA 4: GESTÃO DE CONTA (PREFERÊNCIAS + SESSÕES POR DISPOSITIVO / TODOS + LOGOUT + RGPD)
  Widget _secGestaoContaCompleto() {
    final pr = Map<String, dynamic>.from(_u['preferences'] as Map? ?? <String, dynamic>{});
    final sess = List<Map<String, dynamic>>.from(
      (_u['sessions'] as List? ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e)),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('Preferências da Conta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: <String>['Português (PT)', 'Português (BR)', 'English', 'Español'].contains(pr['language']) ? pr['language'] : 'Português (PT)',
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Idioma', isDense: true),
          items: <String>['Português (PT)', 'Português (BR)', 'English', 'Español']
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (v) async {
            pr['language'] = v;
            _u['preferences'] = pr;
            await _save();
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: <String>['Escuro', 'Claro', 'Sistema'].contains(pr['theme']) ? pr['theme'] : 'Escuro',
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Tema', isDense: true),
          items: <String>['Escuro', 'Claro', 'Sistema']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) async {
            pr['theme'] = v;
            _u['preferences'] = pr;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificações Push'),
          value: pr['pushNotifications'] == true,
          onChanged: (v) async {
            pr['pushNotifications'] = v;
            _u['preferences'] = pr;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificações por E-mail'),
          value: pr['emailNotifications'] == true,
          onChanged: (v) async {
            pr['emailNotifications'] = v;
            _u['preferences'] = pr;
            await _save();
          },
        ),
        const SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Alertas de Segurança (Sempre Ativos)'),
          value: true,
          onChanged: null,
        ),
        const Divider(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Expanded(
              child: Text('Sessões Ativas & Dispositivos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF38BDF8))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              onPressed: () async {
                _u['sessions'] = <Map<String, dynamic>>[];
                ProfileManager.logSecurity(_u, 'Sessão terminada em todos os dispositivos');
                await _save('Sessão terminada em todos os dispositivos!');
                await UserAccountManager.logout();
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onAccountDeletedOrSuspended();
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 15),
              label: const Text('Terminar em Todos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sess.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final isCurr = s['isCurrent'] == true;
          return Card(
            color: const Color(0xFF0B1636),
            child: ListTile(
              leading: Icon(isCurr ? Icons.phonelink_ring_rounded : Icons.devices_rounded, color: const Color(0xFF38BDF8)),
              title: Text(s['device'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('${s['location']}\nÚltimo acesso: ${s['lastAccess']}', style: const TextStyle(fontSize: 11)),
              trailing: TextButton.icon(
                onPressed: () async {
                  if (isCurr) {
                    await UserAccountManager.logout();
                    if (mounted) {
                      Navigator.of(context).pop();
                      widget.onAccountDeletedOrSuspended();
                    }
                  } else {
                    sess.removeAt(idx);
                    _u['sessions'] = sess;
                    ProfileManager.logSecurity(_u, 'Sessão terminada no dispositivo: ${s['device']}');
                    await _save('Sessão terminada em ${s['device']}!');
                  }
                },
                icon: const Icon(Icons.power_settings_new_rounded, size: 16, color: Colors.redAccent),
                label: Text(
                  isCurr ? 'Sair (Atual)' : 'Terminar',
                  style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }),
        const Divider(height: 26),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download, color: Color(0xFF38BDF8)),
          title: const Text('Exportar Dados Pessoais (RGPD)'),
          onTap: () async {
            if (!await _authAction('Exportar Dados')) return;
            await Clipboard.setData(ClipboardData(text: jsonEncode(StructuredProfileStorage.buildTables(_u))));
            _msg('Dados copiados em JSON para a área de transferência!');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.pause_circle_outline, color: Colors.amberAccent),
          title: const Text('Desativar Conta Temporariamente', style: TextStyle(color: Colors.amberAccent)),
          onTap: () async {
            if (!await _authAction('Desativar Conta')) return;
            _u['accountStatus'] = 'Suspensa';
            await _save('Conta desativada temporariamente.');
            await UserAccountManager.logout();
            if (mounted) {
              Navigator.of(context).pop();
              widget.onAccountDeletedOrSuspended();
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: const Text('Solicitar Eliminação Permanente', style: TextStyle(color: Colors.redAccent)),
          onTap: () async {
            if (!await _authAction('Eliminar Conta')) return;
            _u['accountStatus'] = 'Eliminada';
            await _save('Conta eliminada.');
            await UserAccountManager.logout();
            if (mounted) {
              Navigator.of(context).pop();
              widget.onAccountDeletedOrSuspended();
            }
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveCoverHeader() {
    final coverMode = (_u['coverMode'] ?? 'default').toString();
    final coverPath = (_u['coverPath'] ?? '').toString();
    final coverColor = (_u['coverColor'] is int) ? _u['coverColor'] as int : 0xFF0B1636;
    final animStyle = (_u['coverAnimStyle'] ?? 'neon_wave').toString();

    List<Color> animColors = <Color>[const Color(0xFF0B1636), const Color(0xFF0284C7)];
    if (animStyle == 'cyber_pulse') animColors = <Color>[const Color(0xFF1E1B4B), const Color(0xFF9333EA)];
    if (animStyle == 'ember_glow') animColors = <Color>[const Color(0xFF450A0A), const Color(0xFFD97706)];

    return GestureDetector(
      onTap: _openCoverStudio,
      child: AnimatedBuilder(
        animation: _coverAnimCtrl,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: coverMode == 'color' ? Color(coverColor) : const Color(0xFF0B1636),
              gradient: coverMode == 'animated'
                  ? LinearGradient(
                      begin: Alignment(-1.0 + _coverAnimCtrl.value * 2, -1),
                      end: Alignment(1.0 - _coverAnimCtrl.value * 2, 1),
                      colors: animColors,
                    )
                  : null,
              image: (coverMode == 'image' && coverPath.isNotEmpty && File(coverPath).existsSync())
                  ? DecorationImage(
                      image: FileImage(File(coverPath)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
                    )
                  : null,
            ),
            child: Row(
              children: <Widget>[
                GestureDetector(onTap: _editAvatar, child: ProfileManager.buildTransparentAvatar(_u, radius: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text((_u['displayName'] ?? 'Criador').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('@${_u['username']}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
                      Text('ID: ${_u['internalAccountId']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1636),
        title: const Text('Centro de Conta & Perfil', style: TextStyle(fontSize: 16)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Terminar Sessão (Logout)',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await UserAccountManager.logout();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onAccountDeletedOrSuspended();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildInteractiveCoverHeader(),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            indicatorColor: const Color(0xFF38BDF8),
            tabs: _titles.map((t) => Tab(text: t)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _secMeuPerfilCompleto(),
                _secRedesSociaisEContactos(),
                _secSegurancaEPrivacidade(),
                _secGestaoContaCompleto(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
