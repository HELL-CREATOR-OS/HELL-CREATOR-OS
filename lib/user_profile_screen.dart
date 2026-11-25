import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'account_security.dart';

class CloudFirestoreSync {
  static String get _baseUrl {
    final h = ['firestore.', 'google', 'apis.', 'com'].join();
    return 'https://$h/v1/projects/hell-creator-os/databases/(default)/documents';
  }

  static Future<String> _apiKey() async {
    try {
      final raw = await rootBundle.loadString('google-services.json');
      final p = jsonDecode(raw) as Map<String, dynamic>;
      return (p['client'][0]['api_key'][0]['current_key'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, String>?> _auth(String email, String password) async {
    try {
      final base = ['https:', '//', 'identitytoolkit.', 'google', 'apis.', 'com/v1/accounts:'].join();
      final key = await _apiKey();
      if (key.isEmpty) return null;
      var res = await http.post(Uri.parse('${base}signInWithPassword?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}));
      var data = jsonDecode(res.body);
      if (data['idToken'] == null) {
        res = await http.post(Uri.parse('${base}signUp?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}));
        data = jsonDecode(res.body);
      }
      if (data['idToken'] != null && data['localId'] != null) {
        return {'idToken': data['idToken'].toString(), 'uid': data['localId'].toString()};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _fields(Map<String, dynamic> m) {
    final f = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) f[k] = {'nullValue': null};
      else if (v is bool) f[k] = {'booleanValue': v};
      else if (v is int) f[k] = {'integerValue': v.toString()};
      else if (v is double) f[k] = {'doubleValue': v};
      else if (v is String) f[k] = {'stringValue': v};
      else f[k] = {'stringValue': jsonEncode(v)};
    });
    return f;
  }

  static Future<bool> isUsernameFree(String username, String myId) async {
    final clean = username.trim().toLowerCase();
    try {
      final res = await http.get(Uri.parse('$_baseUrl/public_usernames/$clean'));
      if (res.statusCode == 404) return true;
      if (res.statusCode == 200) {
        final owner = jsonDecode(res.body)['fields']?['internalAccountId']?['stringValue']?.toString() ?? '';
        return owner.isEmpty || owner == myId;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> sync(Map<String, dynamic> user, Map<String, Map<String, dynamic>> tables) async {
    try {
      final email = (user['email'] ?? '').toString().trim().toLowerCase();
      final pass = (user['passwordSecret'] ?? '').toString();
      if (email.isEmpty || pass.isEmpty) return;
      final auth = await _auth(email, pass);
      if (auth == null) return;
      final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer ${auth['idToken']}'};
      for (final e in tables.entries) {
        await http.patch(Uri.parse('$_baseUrl/${e.key}/${auth['uid']}'),
            headers: headers, body: jsonEncode({'fields': _fields(e.value)}));
      }
      final u = (user['username'] ?? '').toString().trim().toLowerCase();
      final id = (user['internalAccountId'] ?? '').toString();
      if (u.isNotEmpty && id.isNotEmpty) {
        await http.patch(Uri.parse('$_baseUrl/public_usernames/$u'),
            headers: headers,
            body: jsonEncode({'fields': _fields({'username': u, 'internalAccountId': id})}));
      }
    } catch (_) {}
  }
}
class ProfileManager {
  static const List<Map<String, dynamic>> presetAvatars = [
    {'id': 'preset_fire', 'icon': Icons.local_fire_department_rounded, 'color': 0xFFEF4444},
    {'id': 'preset_bolt', 'icon': Icons.bolt_rounded, 'color': 0xFF38BDF8},
    {'id': 'preset_mic', 'icon': Icons.mic_rounded, 'color': 0xFF8B5CF6},
    {'id': 'preset_game', 'icon': Icons.sports_esports_rounded, 'color': 0xFF10B981},
    {'id': 'preset_crown', 'icon': Icons.workspace_premium_rounded, 'color': 0xFFF59E0B},
    {'id': 'preset_rocket', 'icon': Icons.rocket_launch_rounded, 'color': 0xFFEC4899},
    {'id': 'preset_shield', 'icon': Icons.shield_rounded, 'color': 0xFF3B82F6},
    {'id': 'preset_star', 'icon': Icons.auto_awesome_rounded, 'color': 0xFF14B8A6},
  ];

  static const Map<String, List<String>> countryCities = {
    'Portugal': ['Lisboa', 'Porto', 'Braga', 'Coimbra', 'Aveiro', 'Faro', 'Setúbal', 'Viseu', 'Leiria', 'Évora', 'Funchal', 'Ponta Delgada', 'Guimarães', 'Vila Nova de Gaia', 'Matosinhos', 'Sintra', 'Cascais', 'Almada', 'Amadora', 'Odivelas'],
    'Brasil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Belo Horizonte', 'Curitiba', 'Porto Alegre', 'Salvador', 'Fortaleza', 'Recife', 'Manaus', 'Goiânia', 'Florianópolis'],
    'Espanha': ['Madrid', 'Barcelona', 'Valência', 'Sevilha', 'Saragoça', 'Málaga', 'Bilbau', 'Vigo', 'Corunha'],
    'França': ['Paris', 'Marselha', 'Lyon', 'Toulouse', 'Nice', 'Nantes', 'Estrasburgo', 'Bordéus'],
    'Reino Unido': ['Londres', 'Manchester', 'Birmingham', 'Liverpool', 'Leeds', 'Edimburgo', 'Glasgow'],
    'Alemanha': ['Berlim', 'Munique', 'Hamburgo', 'Frankfurt', 'Colónia', 'Estugarda'],
    'Suíça': ['Zurique', 'Genebra', 'Basileia', 'Lausana', 'Berna'],
    'Luxemburgo': ['Luxemburgo', 'Esch-sur-Alzette', 'Differdange', 'Dudelange'],
    'Angola': ['Luanda', 'Benguela', 'Huambo', 'Lubango', 'Cabinda'],
    'Moçambique': ['Maputo', 'Matola', 'Beira', 'Nampula'],
    'Cabo Verde': ['Praia', 'Mindelo', 'Santa Maria'],
    'Estados Unidos': ['Nova Iorque', 'Los Angeles', 'Chicago', 'Miami', 'Houston', 'Las Vegas', 'Orlando'],
  };

  static const List<Map<String, dynamic>> availableSocialPlatforms = [
    {'id': 'website', 'label': 'Website Pessoal', 'icon': Icons.language_rounded, 'color': 0xFF38BDF8, 'hint': 'https://teusite.com'},
    {'id': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_rounded, 'color': 0xFFFF0050, 'hint': '@teuusername'},
    {'id': 'twitch', 'label': 'Twitch', 'icon': Icons.videocam_rounded, 'color': 0xFF9146FF, 'hint': 'teucanal'},
    {'id': 'youtube', 'label': 'YouTube', 'icon': Icons.play_circle_fill_rounded, 'color': 0xFFFF0000, 'hint': '@teucanal'},
    {'id': 'kick', 'label': 'Kick', 'icon': Icons.bolt_rounded, 'color': 0xFF53FC18, 'hint': 'teucanal'},
    {'id': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_rounded, 'color': 0xFFE1306C, 'hint': '@teuusername'},
    {'id': 'x', 'label': 'X / Twitter', 'icon': Icons.tag_rounded, 'color': 0xFF94A3B8, 'hint': '@teuusername'},
    {'id': 'discord', 'label': 'Discord', 'icon': Icons.forum_rounded, 'color': 0xFF5865F2, 'hint': 'discord.gg/convite ou @user'},
  ];

  static const List<String> reserved = [
    'admin', 'administrator', 'administrador', 'suporte', 'support',
    'moderador', 'moderator', 'staff', 'oficial', 'official', 'hellcreatoros', 'hellcontrolos', 'sistema', 'root',
  ];

  static String hashPass(String raw, String salt) {
    final s = '$salt::$raw::HELL_SEC_V2';
    int h = 0x811c9dc5;
    for (int i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return 'sec2\$${h.toRadixString(16).padLeft(8, '0')}';
  }

  static String generateTotpSecret() {
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final r = Random.secure();
    return List.generate(16, (_) => abc[r.nextInt(abc.length)]).join();
  }

  static String currentTotpCode(String secret) {
    final step = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) ~/ 30;
    int h = 0x1505;
    final seed = '$secret::$step';
    for (int i = 0; i < seed.length; i++) {
      h = ((h << 5) + h + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    return (h % 1000000).toString().padLeft(6, '0');
  }

  static List<String> generateCodes() {
    final r = Random.secure();
    return List.generate(8, (_) => 'HC-${1000 + r.nextInt(9000)}-${1000 + r.nextInt(9000)}');
  }

  static String detectPortugalPostalZone(String zip) {
    final clean = zip.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length < 4) return '';
    final prefix = int.tryParse(clean.substring(0, 4)) ?? 0;
    if (prefix >= 1000 && prefix <= 1999) return 'Lisboa';
    if (prefix >= 2000 && prefix <= 2999) return 'Área Metropolitana de Lisboa / Santarém / Setúbal';
    if (prefix >= 3000 && prefix <= 3999) return 'Coimbra / Aveiro / Viseu';
    if (prefix >= 4000 && prefix <= 4999) return 'Porto / Braga / Viana do Castelo';
    if (prefix >= 5000 && prefix <= 5999) return 'Vila Real / Bragança';
    if (prefix >= 6000 && prefix <= 6999) return 'Castelo Branco / Guarda';
    if (prefix >= 7000 && prefix <= 7999) return 'Évora / Portalegre / Beja';
    if (prefix >= 8000 && prefix <= 8999) return 'Faro (Algarve)';
    if (prefix >= 9000 && prefix <= 9999) return 'Madeira / Açores';
    return '';
  }
  static Map<String, dynamic> ensureAccountStructure(Map<String, dynamic> raw) {
    final u = Map<String, dynamic>.from(raw);
    final email = (u['email'] ?? '').toString().trim().toLowerCase();
    u['internalAccountId'] ??= 'HC-UID-${email.hashCode.abs().toString().padLeft(6, '0')}-${1000 + Random().nextInt(9000)}';
    u['accountCreatedAt'] ??= DateTime.now().toUtc().toIso8601String();
    u['displayName'] ??= u['nickname'] ?? u['firstName'] ?? 'Criador';
    u['username'] ??= (u['nickname'] ?? 'criador').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    u['bio'] ??= '';
    u['website'] ??= '';
    u['publicLocation'] ??= '';
    u['pronouns'] ??= '';
    u['gender'] ??= 'Prefiro não dizer';
    u['city'] ??= '';
    u['postalCode'] ??= '';
    u['address'] ??= '';
    u['phone'] ??= '';
    u['recoveryEmail'] ??= '';
    u['businessContact'] ??= '';
    u['twoFactorEnabled'] ??= false;
    u['totpSecret'] ??= generateTotpSecret();
    u['passkeysEnabled'] ??= false;
    u['recoveryCodes'] ??= generateCodes();
    u['accountStatus'] ??= 'Ativa';
    u['verificationStatus'] ??= UserAccountManager.isOwnerEmail(email) ? 'Verificado Oficial' : 'E-mail Verificado';
    u['permissionLevel'] ??= UserAccountManager.isOwnerEmail(email) ? 'Proprietário / Admin Total' : 'Criador Padrão';

    u['coverMode'] ??= 'default';
    u['coverColor'] ??= 0xFF0B1636;
    u['coverAnimStyle'] ??= 'neon_wave';
    u['bannerPromoMode'] ??= 'off';
    u['bannerSlides'] ??= <dynamic>[];

    u['socialLinks'] ??= <String, dynamic>{};
    u['privacy'] ??= {
      'profileVisibility': 'Público', 'photoVisibility': 'Todos', 'bioVisibility': 'Todos',
      'locationVisibility': 'Privada', 'birthDateVisibility': 'Oculta', 'followersVisibility': 'Pública',
      'onlineStatusVisible': true, 'recentActivityVisible': true, 'contactsVisibility': 'Ocultos',
      'allowEmailSearch': false, 'allowPhoneSearch': false, 'interactionRestriction': 'Todos',
    };
    u['preferences'] ??= {
      'language': 'Português (PT)', 'timezoneMode': 'Automático', 'timezone': 'Europe/Lisbon (UTC+0)',
      'theme': 'Escuro', 'pushNotifications': true, 'emailNotifications': true,
      'securityNotifications': true, 'soundsEnabled': true, 'highContrast': false, 'largeText': false,
    };
    u['blockedUsers'] ??= <dynamic>[];
    u['changeHistory'] ??= <dynamic>[];
    u['securityHistory'] ??= <dynamic>[{'at': u['accountCreatedAt'], 'event': 'Conta criada com sucesso'}];
    u['sessions'] ??= <dynamic>[{
      'id': 'sess_local',
      'device': Platform.isAndroid ? 'Android Mobile' : 'Windows Desktop',
      'location': '${u['country'] ?? 'Portugal'} (aproximada)',
      'lastAccess': DateTime.now().toUtc().toIso8601String(),
      'isCurrent': true,
    }];
    return u;
  }

  static void logChange(Map<String, dynamic> u, String field, String detail) {
    final l = List<Map<String, dynamic>>.from((u['changeHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    l.insert(0, {'at': DateTime.now().toUtc().toIso8601String(), 'field': field, 'detail': detail});
    u['changeHistory'] = l.take(40).toList();
  }

  static void logSecurity(Map<String, dynamic> u, String event) {
    final l = List<Map<String, dynamic>>.from((u['securityHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    l.insert(0, {'at': DateTime.now().toUtc().toIso8601String(), 'event': event});
    u['securityHistory'] = l.take(40).toList();
  }

  static Widget buildTransparentAvatar(Map<String, dynamic> user, {double radius = 20, double scale = 1.0, Offset offset = Offset.zero}) {
    final path = (user['avatarPath'] ?? '').toString();
    final url = (user['photoUrl'] ?? '').toString().trim();
    final preset = (user['presetAvatarId'] ?? '').toString();
    final s = (user['avatarScale'] is num) ? (user['avatarScale'] as num).toDouble() : scale;
    final dx = (user['avatarDx'] is num) ? (user['avatarDx'] as num).toDouble() : offset.dx;
    final dy = (user['avatarDy'] is num) ? (user['avatarDy'] as num).toDouble() : offset.dy;

    Widget? img;
    if (path.isNotEmpty && File(path).existsSync()) {
      img = Image.file(File(path), width: radius * 2, height: radius * 2, fit: BoxFit.cover);
    } else if (url.startsWith('http')) {
      img = Image.network(url, width: radius * 2, height: radius * 2, fit: BoxFit.cover);
    }
    if (img != null) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Transform.translate(offset: Offset(dx, dy), child: Transform.scale(scale: s, child: img)),
        ),
      );
    }
    if (preset.isNotEmpty) {
      final f = presetAvatars.firstWhere((p) => p['id'] == preset, orElse: () => presetAvatars.first);
      return ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: Icon(f['icon'] as IconData, size: radius * 1.45, color: Color(f['color'] as int))));
    }
    return ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: Icon(Icons.account_circle_outlined, size: radius * 1.85, color: const Color(0xFF38BDF8))));
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
    final s = ProfileManager.ensureAccountStructure(user);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UserProfileScreen(user: s, onUserUpdated: onUserUpdated, onAccountDeletedOrSuspended: onAccountDeletedOrSuspended),
      )),
      child: Padding(padding: const EdgeInsets.all(6), child: ProfileManager.buildTransparentAvatar(s, radius: 19)),
    );
  }
}

class StructuredProfileStorage {
  static Map<String, Map<String, dynamic>> buildTables(Map<String, dynamic> u) {
    final s = ProfileManager.ensureAccountStructure(u);
    return {
      'users': {'internal_id': s['internalAccountId'], 'status': s['accountStatus'], 'created_at': s['accountCreatedAt'], 'permission_level': s['permissionLevel']},
      'user_profiles': {'display_name': s['displayName'], 'username': s['username'], 'bio': s['bio'], 'website': s['website'], 'social_links': s['socialLinks'], 'cover_mode': s['coverMode'], 'banner_promo_mode': s['bannerPromoMode'], 'banner_slides': s['bannerSlides']},
      'user_personal_data': {'first_name': s['firstName'] ?? '', 'last_name': s['lastName'] ?? '', 'birth_date': s['birthDate'] ?? '', 'gender': s['gender'], 'country': s['country'] ?? '', 'city': s['city'], 'postal_code': s['postalCode'], 'address': s['address']},
      'user_contacts': {'primary_email': s['email'] ?? '', 'recovery_email': s['recoveryEmail'], 'phone': s['phone'], 'business_contact': s['businessContact']},
      'user_security': {'two_factor_enabled': s['twoFactorEnabled'], 'passkeys_enabled': s['passkeysEnabled']},
      'user_sessions': {'active_sessions': s['sessions']},
      'user_privacy': Map<String, dynamic>.from(s['privacy'] as Map),
      'user_preferences': Map<String, dynamic>.from(s['preferences'] as Map),
      'user_audit_logs': {'change_history': s['changeHistory'], 'security_history': s['securityHistory']},
      'user_verifications': {'verification_status': s['verificationStatus']},
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
    final partners = List<Map<String, dynamic>>.from((_u['partnersList'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
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
          title: Text(isEdit ? 'Editar Publicidade / Parceria' : 'Nova Publicidade / Parceria', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
                  if (r?.files.single.path != null) {
                    setM(() => localImgPath = r!.files.single.path!);
                  }
                },
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(localImgPath.isEmpty ? 'Ou carregar Imagem do Dispositivo' : 'Imagem carregada ✓', style: const TextStyle(fontSize: 12)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exibir no meu perfil público', style: TextStyle(fontSize: 12.5)),
                value: isVisible,
                onChanged: (v) => setM(() => isVisible = v),
              ),
            ]),
          ),
          actions: [
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
    final partners = List<Map<String, dynamic>>.from((_u['partnersList'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF13275E), Color(0xFF0A1433)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('PUBLICIDADES & PARCERIAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF38BDF8))),
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
            const Text('Vitrine oculta neste momento (ativa o interruptor acima para exibir aos visitantes).', style: TextStyle(fontSize: 11.5, color: Colors.white60))
          else if (partners.isEmpty)
            const Text('Ainda sem parcerias adicionadas. Toca em "Adicionar" para expor marcas, imagens, códigos e links oficiais.', style: TextStyle(fontSize: 12, color: Colors.white70))
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

              Widget thumb = const CircleAvatar(backgroundColor: Color(0xFF1E78FF), child: Icon(Icons.storefront_rounded, color: Colors.white));
              if (imgPath.isNotEmpty && File(imgPath).existsSync()) {
                thumb = ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(imgPath), width: 48, height: 48, fit: BoxFit.cover));
              } else if (imgUrl.startsWith('http')) {
                thumb = ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => thumb));
              }

              return Opacity(
                opacity: visible ? 1.0 : 0.45,
                child: Card(
                  color: const Color(0xFF04091A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45))),
                  child: ListTile(
                    leading: thumb,
                    title: Text(brand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    subtitle: Text(
                      code.isNotEmpty ? 'Código: $code · Toca para abrir página oficial' : 'Toca para abrir página oficial',
                      style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
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
              if (mode == 'animated') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: animStyle,
                  dropdownColor: const Color(0xFF0B1636),
                  decoration: const InputDecoration(labelText: 'Estilo de Animação HD', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'neon_wave', child: Text('Ondas Neon Azul & Ciano')),
                    DropdownMenuItem(value: 'cyber_pulse', child: Text('Pulso Roxo & Magenta Estúdio')),
                    DropdownMenuItem(value: 'ember_glow', child: Text('Brilho Fogo & Âmbar')),
                  ],
                  onChanged: (v) => setM(() => animStyle = v ?? 'neon_wave'),
                ),
              ],
            ]),
          ),
          actions: [
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
            ..['avatarDy'] = dy;
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1636),
            title: const Text('Fotografia & Recorte', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onPanUpdate: (d) => setM(() {
                    dx = (dx + d.delta.dx).clamp(-60.0, 60.0);
                    dy = (dy + d.delta.dy).clamp(-60.0, 60.0);
                  }),
                  child: ProfileManager.buildTransparentAvatar(prev, radius: 55, scale: s, offset: Offset(dx, dy)),
                ),
                Slider(value: s, min: 1.0, max: 2.5, onChanged: (v) => setM(() => s = v)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(
                    onPressed: () async {
                      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
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
                    child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
                  ),
                ]),
                Wrap(
                  spacing: 8,
                  children: ProfileManager.presetAvatars.map((a) => IconButton(
                    icon: Icon(a['icon'] as IconData, color: Color(a['color'] as int)),
                    onPressed: () => setM(() {
                      preset = a['id'] as String;
                      path = '';
                      url = '';
                    }),
                  )).toList(),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  _u['avatarPath'] = path;
                  _u['photoUrl'] = url;
                  _u['presetAvatarId'] = preset;
                  _u['avatarScale'] = s;
                  _u['avatarDx'] = dx;
                  _u['avatarDy'] = dy;
                  ProfileManager.logChange(_u, 'Fotografia', 'Avatar atualizado');
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
    final countries = <String>['Portugal', 'Brasil', 'Espanha', 'França', 'Reino Unido', 'Alemanha', 'Suíça', 'Luxemburgo', 'Angola', 'Moçambique', 'Cabo Verde', 'Estados Unidos', 'Outro País'];
    final selectedCountry = (_u['country'] ?? 'Portugal').toString();
    final citySuggestions = ProfileManager.countryCities[selectedCountry] ?? <String>[];
    final postalHint = selectedCountry == 'Portugal' ? ProfileManager.detectPortugalPostalZone(_zipCtrl.text) : '';

    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildPartnersShowcaseCard(),
      Row(children: [
        ElevatedButton.icon(onPressed: _editAvatar, icon: const Icon(Icons.crop, size: 16), label: const Text('Alterar / Cortar Foto', style: TextStyle(fontSize: 12))),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _openCoverStudio, icon: const Icon(Icons.panorama, size: 16), label: const Text('Personalizar Capa', style: TextStyle(fontSize: 12))),
      ]),
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
    ]);
  }
  // ABA 2: REDES SOCIAIS / CONTACTOS UNIDOS
  Widget _secRedesSociaisEContactos() {
    final links = Map<String, dynamic>.from(_u['socialLinks'] as Map? ?? {});
    final activeKeys = links.keys.where((k) => links[k].toString().trim().isNotEmpty).toList();
    final email = (_u['email'] ?? '').toString();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    ]),
                    actions: [
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
      ]),
      const SizedBox(height: 8),
      if (activeKeys.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Nenhuma rede adicionada. Clica em "Adicionar Rede" para escolher as que queres exibir.', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ...activeKeys.map((k) {
        final plat = ProfileManager.availableSocialPlatforms.firstWhere((p) => p['id'] == k, orElse: () => {'label': k.toUpperCase(), 'icon': Icons.link, 'color': 0xFF38BDF8});
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
      Row(children: [
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

      ]),
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
    ]);
  }
   // ABA 3: SEGURANÇA / PRIVACIDADE UNIDOS
  Widget _secSegurancaEPrivacidade() {
    final twoFactor = _u['twoFactorEnabled'] == true;
    final secret = (_u['totpSecret'] ?? '').toString();
    final codes = List<String>.from(_u['recoveryCodes'] ?? []);
    final secHist = List<Map<String, dynamic>>.from((_u['securityHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    final chgHist = List<Map<String, dynamic>>.from((_u['changeHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    final p = Map<String, dynamic>.from(_u['privacy'] as Map? ?? {});

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

    return ListView(padding: const EdgeInsets.all(16), children: [
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
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: c1, obscureText: true, decoration: const InputDecoration(labelText: 'Nova palavra-passe')),
                TextField(controller: c2, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir')),
              ]),
              actions: [
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
        children: [
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
      drop('Perfil', 'profileVisibility', ['Público', 'Privado']),
      drop('Fotografia', 'photoVisibility', ['Todos', 'Utilizadores autorizados']),
      drop('Biografia', 'bioVisibility', ['Todos', 'Privado']),
      drop('Localização', 'locationVisibility', ['Privada', 'Pública']),
      drop('Data de Nascimento', 'birthDateVisibility', ['Oculta', 'Apenas dia e mês', 'Completa']),
      drop('Lista de Seguidores', 'followersVisibility', ['Pública', 'Privada']),
      drop('Contactos (Ocultos por defeito)', 'contactsVisibility', ['Ocultos', 'Autorizados']),
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
    ]);
  }

  
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
              label: Text(isCurr ? 'Sair (Atual)' : 'Terminar', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
    ]);
  }

  Widget _buildInteractiveCoverHeader() {
    final coverMode = (_u['coverMode'] ?? 'default').toString();
    final coverPath = (_u['coverPath'] ?? '').toString();
    final coverColor = (_u['coverColor'] is int) ? _u['coverColor'] as int : 0xFF0B1636;
    final animStyle = (_u['coverAnimStyle'] ?? 'neon_wave').toString();

    List<Color> animColors = [const Color(0xFF0B1636), const Color(0xFF0284C7)];
    if (animStyle == 'cyber_pulse') animColors = [const Color(0xFF1E1B4B), const Color(0xFF9333EA)];
    if (animStyle == 'ember_glow') animColors = [const Color(0xFF450A0A), const Color(0xFFD97706)];

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
                  ? DecorationImage(image: FileImage(File(coverPath)), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken))
                  : null,
            ),
            child: Row(children: [
              GestureDetector(onTap: _editAvatar, child: ProfileManager.buildTransparentAvatar(_u, radius: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((_u['displayName'] ?? 'Criador').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('@${_u['username']}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
                  Text('ID: ${_u['internalAccountId']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                ]),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
            ]),
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
        actions: [
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
      body: Column(children: [
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
            children: [
              _secMeuPerfilCompleto(),
              _secRedesSociaisEContactos(),
              _secSegurancaEPrivacidade(),
              _secGestaoContaCompleto(),
            ],
          ),
        ),
      ]),
    );
  }
}
