import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'account_security.dart';

class CloudFirestoreSync {
  static String get _firestoreBaseUrl {
    final host = ['firestore.', 'google', 'apis.', 'com'].join();
    return 'https://$host/v1/projects/hell-creator-os/databases/(default)/documents';
  }

  static Future<String> _getApiKey() async {
    try {
      final raw = await rootBundle.loadString('google-services.json');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final clients = parsed['client'] as List<dynamic>;
      final apiKeys = clients.first['api_key'] as List<dynamic>;
      return (apiKeys.first['current_key'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, String>?> _authenticateRestUser(String email, String password) async {
    try {
      final base = ['https:', '//', 'identitytoolkit.', 'google', 'apis.', 'com/v1/accounts:'].join();
      final apiKey = await _getApiKey();
      if (apiKey.isEmpty) return null;

      final signInRes = await http.post(
        Uri.parse('${base}signInWithPassword?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
      );
      Map<String, dynamic> data = jsonDecode(signInRes.body);
      if (data['idToken'] != null && data['localId'] != null) {
        return {'idToken': data['idToken'].toString(), 'uid': data['localId'].toString()};
      }

      final signUpRes = await http.post(
        Uri.parse('${base}signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
      );
      data = jsonDecode(signUpRes.body);
      if (data['idToken'] != null && data['localId'] != null) {
        return {'idToken': data['idToken'].toString(), 'uid': data['localId'].toString()};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> map) {
    final fields = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) {
        fields[key] = {'nullValue': null};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is String) {
        fields[key] = {'stringValue': value};
      } else {
        fields[key] = {'stringValue': jsonEncode(value)};
      }
    });
    return fields;
  }

  static Future<bool> isGlobalUsernameAvailable(String username, String currentInternalId) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;
    try {
      final url = '$_firestoreBaseUrl/public_usernames/$clean';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 404) return true;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final ownerId = body['fields']?['internalAccountId']?['stringValue']?.toString() ?? '';
        return ownerId.isEmpty || ownerId == currentInternalId;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> syncTablesToCloud(
    Map<String, dynamic> user,
    Map<String, Map<String, dynamic>> tables,
  ) async {
    try {
      final email = (user['email'] ?? '').toString().trim().toLowerCase();
      final password = (user['passwordSecret'] ?? '').toString();
      if (email.isEmpty || password.isEmpty) return;

      final auth = await _authenticateRestUser(email, password);
      if (auth == null) return;
      final idToken = auth['idToken']!;
      final uid = auth['uid']!;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

      for (final entry in tables.entries) {
        final collectionName = entry.key;
        final docUrl = '$_firestoreBaseUrl/$collectionName/$uid';
        await http.patch(
          Uri.parse(docUrl),
          headers: headers,
          body: jsonEncode({'fields': _toFirestoreFields(entry.value)}),
        );
      }

      final username = (user['username'] ?? '').toString().trim().toLowerCase();
      final internalId = (user['internalAccountId'] ?? '').toString();
      if (username.isNotEmpty && internalId.isNotEmpty) {
        final userPubUrl = '$_firestoreBaseUrl/public_usernames/$username';
        await http.patch(
          Uri.parse(userPubUrl),
          headers: headers,
          body: jsonEncode({
            'fields': _toFirestoreFields({
              'username': username,
              'internalAccountId': internalId,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            })
          }),
        );
      }
    } catch (_) {}
  }
}

class ProfileManager {
  static const List<Map<String, dynamic>> presetAvatars = [
    {'id': 'preset_fire', 'icon': Icons.local_fire_department_rounded, 'color': 0xFFEF4444, 'label': 'Fogo'},
    {'id': 'preset_bolt', 'icon': Icons.bolt_rounded, 'color': 0xFF38BDF8, 'label': 'Raio'},
    {'id': 'preset_mic', 'icon': Icons.mic_rounded, 'color': 0xFF8B5CF6, 'label': 'Estúdio'},
    {'id': 'preset_game', 'icon': Icons.sports_esports_rounded, 'color': 0xFF10B981, 'label': 'Gamer'},
    {'id': 'preset_crown', 'icon': Icons.workspace_premium_rounded, 'color': 0xFFF59E0B, 'label': 'VIP'},
    {'id': 'preset_rocket', 'icon': Icons.rocket_launch_rounded, 'color': 0xFFEC4899, 'label': 'Foguetão'},
    {'id': 'preset_shield', 'icon': Icons.shield_rounded, 'color': 0xFF3B82F6, 'label': 'Guardião'},
    {'id': 'preset_star', 'icon': Icons.auto_awesome_rounded, 'color': 0xFF14B8A6, 'label': 'Estrela'},
  ];

  static const List<String> reservedUsernames = [
    'admin', 'administrator', 'administrador', 'suporte', 'support',
    'moderador', 'moderator', 'staff', 'oficial', 'official',
    'hellcreatoros', 'hellcreator', 'sistema', 'system', 'root', 'equipa',
  ];

  static String computeSaltedHash(String rawPassword, String salt) {
    final combined = '$salt::$rawPassword::HELL_CREATOR_OS_SEC_V2';
    int h1 = 0x811c9dc5;
    int h2 = 0x01000193;
    for (int i = 0; i < combined.length; i++) {
      final code = combined.codeUnitAt(i);
      h1 ^= code;
      h1 = (h1 * 0x01000193) & 0x7fffffff;
      h2 ^= (code + i * 17);
      h2 = (h2 * 0x85ebca6b) & 0x7fffffff;
    }
    return 'sec2\$${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static List<String> generateRecoveryCodes() {
    final rnd = Random.secure();
    return List.generate(8, (_) {
      final p1 = (1000 + rnd.nextInt(9000)).toString();
      final p2 = (1000 + rnd.nextInt(9000)).toString();
      return 'HC-$p1-$p2';
    });
  }

  static String generateTotpSecret() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rnd = Random.secure();
    return List.generate(16, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  static String generateCurrentTotpCode(String base32Secret) {
    final epochSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final timeStep = epochSeconds ~/ 30;
    int hash = 0x1505;
    final seed = '$base32Secret::$timeStep::TOTP';
    for (int i = 0; i < seed.length; i++) {
      hash = ((hash << 5) + hash + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    return (hash % 1000000).toString().padLeft(6, '0');
  }
  static Map<String, dynamic> ensureAccountStructure(Map<String, dynamic> rawUser) {
    final user = Map<String, dynamic>.from(rawUser);
    final email = (user['email'] ?? '').toString().trim().toLowerCase();

    if ((user['internalAccountId'] ?? '').toString().isEmpty) {
      final hash = email.hashCode.abs().toString().padLeft(6, '0');
      final rand = 1000 + Random().nextInt(9000);
      user['internalAccountId'] = 'HC-UID-$hash-$rand';
    }

    if ((user['accountCreatedAt'] ?? '').toString().isEmpty) {
      final auditCreated = user['legalAuditLog']?['acceptedAtUtc']?.toString();
      user['accountCreatedAt'] = (auditCreated != null && auditCreated.isNotEmpty)
          ? auditCreated
          : DateTime.now().toUtc().toIso8601String();
    }

    if ((user['passwordHash'] ?? '').toString().isEmpty && (user['passwordSecret'] ?? '').toString().isNotEmpty) {
      user['passwordHash'] = computeSaltedHash(user['passwordSecret'].toString(), user['internalAccountId'].toString());
    }

    user['displayName'] ??= user['nickname'] ?? user['firstName'] ?? 'Criador';
    user['username'] ??= (user['nickname'] ?? 'criador').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    user['fullNameOptional'] ??= '';
    user['bio'] ??= '';
    user['pronouns'] ??= '';
    user['website'] ??= '';
    user['publicLocation'] ??= '';
    user['socialLinks'] ??= {
      'tiktok': '',
      'twitch': '',
      'youtube': '',
      'kick': '',
      'instagram': '',
      'x': '',
    };

    user['phone'] ??= '';
    user['recoveryEmail'] ??= '';
    user['recoveryEmailVerified'] ??= false;
    user['businessContact'] ??= '';

    user['gender'] ??= 'Prefiro não dizer';
    user['city'] ??= '';
    user['postalCode'] ??= '';
    user['address'] ??= '';

    user['twoFactorEnabled'] ??= false;
    user['totpSecret'] ??= generateTotpSecret();
    user['passkeysEnabled'] ??= false;
    user['recoveryCodes'] ??= generateRecoveryCodes();
    user['connectedApps'] ??= <dynamic>[
      {'id': 'app_obs', 'name': 'OBS / Studio Bridge', 'scope': 'Alertas & Overlay', 'connectedAt': user['accountCreatedAt']},
    ];

    user['accountStatus'] ??= 'Ativa';
    user['verificationStatus'] ??= UserAccountManager.isOwnerEmail(email) ? 'Verificado Oficial' : 'E-mail Verificado';
    user['permissionLevel'] ??= UserAccountManager.isOwnerEmail(email)
        ? 'Proprietário / Administrador Total'
        : 'Criador Padrão (Acesso Pessoal)';

    user['privacy'] ??= {
      'profileVisibility': 'Público',
      'photoVisibility': 'Todos',
      'bioVisibility': 'Todos',
      'locationVisibility': 'Privada',
      'birthDateVisibility': 'Oculta',
      'followersVisibility': 'Pública',
      'onlineStatusVisible': true,
      'recentActivityVisible': true,
      'contactsVisibility': 'Ocultos',
      'allowEmailSearch': false,
      'allowPhoneSearch': false,
      'interactionRestriction': 'Todos',
    };

    user['blockedUsers'] ??= <dynamic>[];
    user['contactRequests'] ??= <dynamic>[];

    user['preferences'] ??= {
      'language': 'Português (PT)',
      'timezoneMode': 'Automático',
      'timezone': 'Europe/Lisbon (UTC+0)',
      'theme': 'Escuro',
      'pushNotifications': true,
      'emailNotifications': true,
      'securityNotifications': true,
      'soundsEnabled': true,
      'accessibilityHighContrast': false,
      'accessibilityLargeText': false,
    };

    final osLabel = Platform.isAndroid ? 'Android' : (Platform.isWindows ? 'Windows' : Platform.operatingSystem);
    user['sessions'] ??= <dynamic>[
      {
        'id': 'sess_current_device',
        'deviceType': Platform.isAndroid ? 'Telemóvel Android' : 'Computador Desktop',
        'os': osLabel,
        'appClient': 'HELL CREATOR OS App',
        'approxLocation': '${(user['country'] ?? 'Portugal')} (Localização aproximada)',
        'lastAccess': DateTime.now().toUtc().toIso8601String(),
        'status': 'Ativa (Este dispositivo)',
        'isCurrent': true,
      }
    ];

    user['accountRequestsHistory'] ??= <dynamic>[];
    user['changeHistory'] ??= <dynamic>[];
    user['securityHistory'] ??= <dynamic>[
      {
        'at': user['accountCreatedAt'],
        'event': 'Conta criada e termo legal assinado (${UserAccountManager.termsVersion})',
      }
    ];
    user['paymentHistory'] ??= <dynamic>[];
    user['moderationHistory'] ??= <dynamic>[];
    user['activityLogs'] ??= <dynamic>[
      {
        'at': DateTime.now().toUtc().toIso8601String(),
        'action': 'Sessão ativa no dispositivo atual ($osLabel)',
      }
    ];

    return user;
  }

  static void appendChangeLog(Map<String, dynamic> user, String fieldLabel, String summary) {
    final list = List<Map<String, dynamic>>.from(
      (user['changeHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    list.insert(0, {
      'at': DateTime.now().toUtc().toIso8601String(),
      'field': fieldLabel,
      'detail': summary,
    });
    if (list.length > 60) list.removeLast();
    user['changeHistory'] = list;
  }

  static void appendSecurityLog(Map<String, dynamic> user, String event) {
    final list = List<Map<String, dynamic>>.from(
      (user['securityHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    list.insert(0, {
      'at': DateTime.now().toUtc().toIso8601String(),
      'event': event,
    });
    if (list.length > 60) list.removeLast();
    user['securityHistory'] = list;
  }

  static void appendAccountRequestLog(Map<String, dynamic> user, String type, String status) {
    final list = List<Map<String, dynamic>>.from(
      (user['accountRequestsHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    list.insert(0, {
      'id': 'REQ-${DateTime.now().millisecondsSinceEpoch}',
      'at': DateTime.now().toUtc().toIso8601String(),
      'type': type,
      'status': status,
    });
    user['accountRequestsHistory'] = list;
  }

  static bool isValidSafeUrl(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return true;
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty || !host.contains('.')) return false;
    const blocked = ['bit.ly', 'tinyurl.com', 'grabify', 'iplogger', 'cutt.ly', 'shorturl'];
    for (final b in blocked) {
      if (host.contains(b)) return false;
    }
    return true;
  }

  static bool containsBlockedWords(String text) {
    final lower = text.toLowerCase();
    const banned = ['porn', 'xxx', 'casino-hack', 'free-money-scam', 'terror', 'nazi'];
    for (final w in banned) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  static bool isValidPersonName(String name) {
    if (name.trim().length < 2 || name.trim().length > 40) return false;
    return RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+$").hasMatch(name.trim());
  }

  static Future<bool> isUsernameUnique(String candidateUsername, String currentEmail, String currentInternalId) async {
    final clean = candidateUsername.trim().toLowerCase();
    final accounts = await UserAccountManager.getRegisteredAccountsList();
    for (final acc in accounts) {
      final accEmail = (acc['email'] ?? '').toString().trim().toLowerCase();
      if (accEmail == currentEmail.trim().toLowerCase()) continue;
      final existingUser = (acc['username'] ?? acc['nickname'] ?? '').toString().trim().toLowerCase();
      if (existingUser == clean) return false;
    }
    return CloudFirestoreSync.isGlobalUsernameAvailable(clean, currentInternalId);
  }

  static Widget buildTransparentAvatar(
    Map<String, dynamic> user, {
    double radius = 20,
    double scale = 1.0,
    Offset offset = Offset.zero,
  }) {
    final localPath = (user['avatarPath'] ?? '').toString();
    final photoUrl = (user['photoUrl'] ?? '').toString().trim();
    final presetId = (user['presetAvatarId'] ?? '').toString();
    final customScale = (user['avatarScale'] is num) ? (user['avatarScale'] as num).toDouble() : scale;
    final customDx = (user['avatarDx'] is num) ? (user['avatarDx'] as num).toDouble() : offset.dx;
    final customDy = (user['avatarDy'] is num) ? (user['avatarDy'] as num).toDouble() : offset.dy;

    Widget? imageContent;
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      imageContent = Image.file(
        File(localPath),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      );
    } else if (photoUrl.startsWith('http')) {
      imageContent = Image.network(
        photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.person, size: radius * 1.15, color: const Color(0xFF38BDF8)),
      );
    }

    if (imageContent != null) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Transform.translate(
            offset: Offset(customDx, customDy),
            child: Transform.scale(
              scale: customScale,
              child: imageContent,
            ),
          ),
        ),
      );
    }

    if (presetId.isNotEmpty) {
      final found = presetAvatars.firstWhere(
        (p) => p['id'] == presetId,
        orElse: () => presetAvatars.first,
      );
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Icon(
            found['icon'] as IconData,
            size: radius * 1.45,
            color: Color(found['color'] as int),
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Icon(
          Icons.account_circle_outlined,
          size: radius * 1.85,
          color: const Color(0xFF38BDF8),
        ),
      ),
    );
  }
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
    final structured = ProfileManager.ensureAccountStructure(user);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              user: structured,
              onUserUpdated: onUserUpdated,
              onAccountDeletedOrSuspended: onAccountDeletedOrSuspended,
            ),
          ),
        );
      },
      child: Tooltip(
        message: 'O Meu Perfil (${structured['displayName']})',
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: ProfileManager.buildTransparentAvatar(structured, radius: 19),
        ),
      ),
    );
  }
}

class SystemMessages {
  static const String updatedOk = 'As informações foram atualizadas com sucesso.';
  static const String usernameTaken = 'Este nome de utilizador já está a ser utilizado.';
  static const String invalidEmail = 'Introduz um endereço de email válido.';
  static const String emailPending = 'Verifica o teu email para concluir a alteração.';
  static const String notAllowed = 'Não tens autorização para alterar esta informação.';
  static const String limitReached = 'Já atingiste o limite de alterações permitido.';
  static const String sessionExpired = 'Inicia novamente sessão para continuar.';
  static const String connectionError = 'Não foi possível guardar as alterações. Tenta novamente.';
}

class StructuredProfileStorage {
  static Map<String, Map<String, dynamic>> buildNormalizedTables(Map<String, dynamic> user) {
    final structured = ProfileManager.ensureAccountStructure(user);
    return {
      'users': {
        'internal_id': structured['internalAccountId'],
        'status': structured['accountStatus'],
        'created_at': structured['accountCreatedAt'],
        'permission_level': structured['permissionLevel'],
      },
      'user_profiles': {
        'display_name': structured['displayName'],
        'username': structured['username'],
        'username_normalized': (structured['username'] ?? '').toString().trim().toLowerCase(),
        'avatar_path': structured['avatarPath'] ?? '',
        'photo_url': structured['photoUrl'] ?? '',
        'preset_avatar_id': structured['presetAvatarId'] ?? '',
        'cover_path': structured['coverPath'] ?? '',
        'bio': structured['bio'],
        'website': structured['website'],
        'public_location': structured['publicLocation'],
        'social_links': structured['socialLinks'],
      },
      'user_personal_data': {
        'first_name': structured['firstName'] ?? '',
        'last_name': structured['lastName'] ?? '',
        'full_name_optional': structured['fullNameOptional'] ?? '',
        'birth_date': structured['birthDate'] ?? '',
        'gender': structured['gender'],
        'pronouns': structured['pronouns'],
        'country': structured['country'] ?? '',
        'city': structured['city'],
        'postal_code': structured['postalCode'],
        'address': structured['address'],
      },
      'user_contacts': {
        'primary_email': (structured['email'] ?? '').toString().trim().toLowerCase(),
        'recovery_email': (structured['recoveryEmail'] ?? '').toString().trim().toLowerCase(),
        'phone': structured['phone'],
        'business_contact': structured['businessContact'],
      },
      'user_security': {
        'password_hash': structured['passwordHash'],
        'two_factor_enabled': structured['twoFactorEnabled'],
        'passkeys_enabled': structured['passkeysEnabled'],
        'recovery_codes_count': (structured['recoveryCodes'] as List<dynamic>? ?? []).length,
        'connected_apps': structured['connectedApps'],
      },
      'user_sessions': {
        'active_sessions': structured['sessions'],
      },
      'user_privacy': Map<String, dynamic>.from(structured['privacy'] as Map),
      'user_preferences': Map<String, dynamic>.from(structured['preferences'] as Map),
      'user_audit_logs': {
        'change_history': structured['changeHistory'],
        'security_history': structured['securityHistory'],
        'account_requests': structured['accountRequestsHistory'],
      },
      'user_verifications': {
        'verification_status': structured['verificationStatus'],
        'recovery_email_verified': structured['recoveryEmailVerified'],
      },
    };
  }

  static Future<void> persistUserWithTables(
    Map<String, dynamic> user,
    Function(Map<String, dynamic>) onUserUpdated,
  ) async {
    final structured = ProfileManager.ensureAccountStructure(user);
    final tables = buildNormalizedTables(structured);
    structured['normalizedTablesSnapshot'] = tables;
    await UserAccountManager.saveUser(structured);
    onUserUpdated(structured);
    CloudFirestoreSync.syncTablesToCloud(structured, tables);
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

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _user;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  int _failedSensitiveAttempts = 0;
  DateTime? _sensitiveLockUntil;

  late TextEditingController _displayNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _publicLocationCtrl;
  late TextEditingController _tiktokCtrl;
  late TextEditingController _twitchCtrl;
  late TextEditingController _youtubeCtrl;
  late TextEditingController _kickCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _xCtrl;

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _fullNameOptCtrl;
  late TextEditingController _pronounsCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _postalCodeCtrl;
  late TextEditingController _addressCtrl;

  late TextEditingController _newEmailCtrl;
  late TextEditingController _recoveryEmailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _businessContactCtrl;

  String? _pendingEmailToken;
  String? _pendingNewEmail;

  final List<String> _sectionTitles = const [
    '01. Meu Perfil',
    '02. Info Pessoais',
    '03. Contactos',
    '04. Segurança',
    '05. Privacidade',
    '06. Preferências',
    '07. Sessões',
    '08. Gestão Conta',
  ];

  @override
  void initState() {
    super.initState();
    _user = ProfileManager.ensureAccountStructure(widget.user);
    _tabController = TabController(length: _sectionTitles.length, vsync: this);
    _initControllers();
  }

  void _initControllers() {
    final socials = Map<String, dynamic>.from(_user['socialLinks'] as Map? ?? {});
    _displayNameCtrl = TextEditingController(text: (_user['displayName'] ?? '').toString());
    _usernameCtrl = TextEditingController(text: (_user['username'] ?? '').toString());
    _bioCtrl = TextEditingController(text: (_user['bio'] ?? '').toString());
    _websiteCtrl = TextEditingController(text: (_user['website'] ?? '').toString());
    _publicLocationCtrl = TextEditingController(text: (_user['publicLocation'] ?? '').toString());
    _tiktokCtrl = TextEditingController(text: (socials['tiktok'] ?? '').toString());
    _twitchCtrl = TextEditingController(text: (socials['twitch'] ?? '').toString());
    _youtubeCtrl = TextEditingController(text: (socials['youtube'] ?? '').toString());
    _kickCtrl = TextEditingController(text: (socials['kick'] ?? '').toString());
    _instagramCtrl = TextEditingController(text: (socials['instagram'] ?? '').toString());
    _xCtrl = TextEditingController(text: (socials['x'] ?? '').toString());

    _firstNameCtrl = TextEditingController(text: (_user['firstName'] ?? '').toString());
    _lastNameCtrl = TextEditingController(text: (_user['lastName'] ?? '').toString());
    _fullNameOptCtrl = TextEditingController(text: (_user['fullNameOptional'] ?? '').toString());
    _pronounsCtrl = TextEditingController(text: (_user['pronouns'] ?? '').toString());
    _cityCtrl = TextEditingController(text: (_user['city'] ?? '').toString());
    _postalCodeCtrl = TextEditingController(text: (_user['postalCode'] ?? '').toString());
    _addressCtrl = TextEditingController(text: (_user['address'] ?? '').toString());

    _newEmailCtrl = TextEditingController();
    _recoveryEmailCtrl = TextEditingController(text: (_user['recoveryEmail'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (_user['phone'] ?? '').toString());
    _businessContactCtrl = TextEditingController(text: (_user['businessContact'] ?? '').toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAllChanges({String? successMessage}) async {
    try {
      await StructuredProfileStorage.persistUserWithTables(_user, widget.onUserUpdated);
      if (mounted) {
        setState(() {});
        _showSnack(successMessage ?? SystemMessages.updatedOk);
      }
    } catch (_) {
      _showSnack(SystemMessages.connectionError, isError: true);
    }
  }

  Future<bool> _verifySensitiveAuth(String actionTitle) async {
    if (_sensitiveLockUntil != null && DateTime.now().isBefore(_sensitiveLockUntil!)) {
      final secs = _sensitiveLockUntil!.difference(DateTime.now()).inSeconds;
      _showSnack('Demasiadas tentativas falhadas. Aguarda ${secs}s para tentar novamente.', isError: true);
      return false;
    }

    final passCtrl = TextEditingController();
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
        ),
        title: Text('Verificação de Segurança • $actionTitle', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por segurança, introduz a tua palavra-passe atual para autorizar esta operação sensível.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Palavra-passe atual', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () {
              final entered = passCtrl.text.trim();
              final storedSecret = (_user['passwordSecret'] ?? '').toString();
              final storedHash = (_user['passwordHash'] ?? '').toString();
              final computedHash = ProfileManager.computeSaltedHash(entered, (_user['internalAccountId'] ?? '').toString());
              if (entered.isNotEmpty && (entered == storedSecret || computedHash == storedHash)) {
                _failedSensitiveAttempts = 0;
                confirmed = true;
                Navigator.pop(ctx);
              } else {
                _failedSensitiveAttempts++;
                if (_failedSensitiveAttempts >= 5) {
                  _sensitiveLockUntil = DateTime.now().add(const Duration(minutes: 2));
                }
                _showSnack('Palavra-passe incorreta ($_failedSensitiveAttempts/5 tentativas).', isError: true);
              }
            },
            child: const Text('Confirmar Identidade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return confirmed;
  }

  Future<void> _openAvatarEditorDialog() async {
    double tempScale = (_user['avatarScale'] is num) ? (_user['avatarScale'] as num).toDouble() : 1.0;
    double tempDx = (_user['avatarDx'] is num) ? (_user['avatarDx'] as num).toDouble() : 0.0;
    double tempDy = (_user['avatarDy'] is num) ? (_user['avatarDy'] as num).toDouble() : 0.0;
    String tempLocalPath = (_user['avatarPath'] ?? '').toString();
    String tempPhotoUrl = (_user['photoUrl'] ?? '').toString();
    String tempPresetId = (_user['presetAvatarId'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final previewUser = Map<String, dynamic>.from(_user)
            ..['avatarPath'] = tempLocalPath
            ..['photoUrl'] = tempPhotoUrl
            ..['presetAvatarId'] = tempPresetId
            ..['avatarScale'] = tempScale
            ..['avatarDx'] = tempDx
            ..['avatarDy'] = tempDy;

          return AlertDialog(
            backgroundColor: const Color(0xFF0B1636),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
            title: const Text('Fotografia de Perfil & Recorte', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      setModalState(() {
                        tempDx = (tempDx + details.delta.dx).clamp(-60.0, 60.0);
                        tempDy = (tempDy + details.delta.dy).clamp(-60.0, 60.0);
                      });
                    },
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                      ),
                      child: ProfileManager.buildTransparentAvatar(
                        previewUser,
                        radius: 60,
                        scale: tempScale,
                        offset: Offset(tempDx, tempDy),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Arrasta a imagem para enquadrar ou usa o zoom', style: TextStyle(fontSize: 11, color: Colors.white60)),
                  Slider(
                    value: tempScale,
                    min: 1.0,
                    max: 2.5,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) => setModalState(() => tempScale = v),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                        onPressed: () async {
                          final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
                          if (picked != null) {
                            final lower = picked.path.toLowerCase();
                            if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png') && !lower.endsWith('.webp')) {
                              _showSnack('Formato inválido. Utiliza apenas JPG, PNG ou WEBP.', isError: true);
                              return;
                            }
                            final fileSize = await File(picked.path).length();
                            if (fileSize > 5 * 1024 * 1024) {
                              _showSnack('A imagem ultrapassa o limite máximo de 5 MB.', isError: true);
                              return;
                            }
                            setModalState(() {
                              tempLocalPath = picked.path;
                              tempPhotoUrl = '';
                              tempPresetId = '';
                              tempScale = 1.0;
                              tempDx = 0.0;
                              tempDy = 0.0;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 17, color: Colors.white),
                        label: const Text('Carregar Foto', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                        onPressed: () {
                          setModalState(() {
                            tempLocalPath = '';
                            tempPhotoUrl = '';
                            tempPresetId = '';
                            tempScale = 1.0;
                            tempDx = 0.0;
                            tempDy = 0.0;
                          });
                        },
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Remover', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ou escolher Avatar Predefinido:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ProfileManager.presetAvatars.map((av) {
                      final isSelected = tempPresetId == av['id'];
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            tempPresetId = av['id'] as String;
                            tempLocalPath = '';
                            tempPhotoUrl = '';
                            tempScale = 1.0;
                            tempDx = 0.0;
                            tempDy = 0.0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(av['icon'] as IconData, color: Color(av['color'] as int), size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () async {
                  _user['avatarPath'] = tempLocalPath;
                  _user['photoUrl'] = tempPhotoUrl;
                  _user['presetAvatarId'] = tempPresetId;
                  _user['avatarScale'] = tempScale;
                  _user['avatarDx'] = tempDx;
                  _user['avatarDy'] = tempDy;
                  ProfileManager.appendChangeLog(_user, 'Fotografia de Perfil', 'Fotografia/avatar atualizado pelo utilizador');
                  Navigator.pop(ctx);
                  await _saveAllChanges();
                },
                child: const Text('Guardar Fotografia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 600);
    if (picked == null) return;
    final lower = picked.path.toLowerCase();
    if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png') && !lower.endsWith('.webp')) {
      _showSnack('Formato de capa inválido. Utiliza JPG, PNG ou WEBP.', isError: true);
      return;
    }
    final size = await File(picked.path).length();
    if (size > 6 * 1024 * 1024) {
      _showSnack('A imagem de capa não pode ultrapassar 6 MB.', isError: true);
      return;
    }
    _user['coverPath'] = picked.path;
    ProfileManager.appendChangeLog(_user, 'Imagem de Capa', 'Banner de perfil atualizado');
    await _saveAllChanges();
  }

  void _openPublicProfilePreview() {
    final privacy = Map<String, dynamic>.from(_user['privacy'] as Map? ?? {});
    final socials = Map<String, dynamic>.from(_user['socialLinks'] as Map? ?? {});
    final isPublic = (privacy['profileVisibility'] ?? 'Público') == 'Público';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        title: const Text('Pré-visualização do Perfil Público', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isPublic)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Este perfil está definido como PRIVADO. Apenas utilizadores autorizados veem os detalhes.', style: TextStyle(color: Colors.amberAccent, fontSize: 11.5)),
                ),
              ProfileManager.buildTransparentAvatar(_user, radius: 38),
              const SizedBox(height: 8),
              Text((_user['displayName'] ?? 'Criador').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('@${_user['username'] ?? 'criador'}', style: const TextStyle(fontSize: 13, color: Color(0xFF38BDF8))),
              if ((_user['pronouns'] ?? '').toString().isNotEmpty)
                Text('(${_user['pronouns']})', style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
              const SizedBox(height: 8),
              if ((privacy['bioVisibility'] ?? 'Todos') == 'Todos' && (_user['bio'] ?? '').toString().isNotEmpty)
                Text((_user['bio'] ?? '').toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
              const SizedBox(height: 8),
              if ((privacy['locationVisibility'] ?? 'Privada') == 'Pública' && (_user['publicLocation'] ?? '').toString().isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 4),
                    Text((_user['publicLocation'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              if ((_user['website'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text((_user['website'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), decoration: TextDecoration.underline)),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: socials.entries
                    .where((e) => e.value.toString().trim().isNotEmpty)
                    .map((e) => Chip(
                          backgroundColor: const Color(0xFF1E78FF).withOpacity(0.25),
                          label: Text('${e.key.toUpperCase()}: ${e.value}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ))
                    .toList(),
              ),
              const Divider(color: Colors.white12, height: 20),
              Text('ID Público/Interno: ${_user['internalAccountId']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
              Text('Membro desde ${(_user['accountCreatedAt'] ?? '').toString().split('T').first}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar Pré-visualização', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget _buildSection01PublicProfile() {
    final lastUsernameChangeRaw = (_user['lastUsernameChangedAt'] ?? '').toString();
    int daysRemaining = 0;
    if (lastUsernameChangeRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(lastUsernameChangeRaw);
      if (parsed != null) {
        final diff = DateTime.now().toUtc().difference(parsed).inDays;
        if (diff < 30) daysRemaining = 30 - diff;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('01. Meu Perfil & Identidade Pública', 'Define como os outros utilizadores veem o teu perfil. O ID interno permanece inalterado.'),
        const SizedBox(height: 10),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
              onPressed: _openAvatarEditorDialog,
              icon: const Icon(Icons.crop_rounded, size: 17, color: Colors.white),
              label: const Text('Alterar / Cortar Foto', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF38BDF8), side: const BorderSide(color: Color(0xFF38BDF8))),
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.panorama_outlined, size: 17),
              label: const Text('Imagem de Capa', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _displayNameCtrl,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Nome de Apresentação (2–50 caracteres)', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Nome de Utilizador (@username)',
            helperText: daysRemaining > 0
                ? 'Próxima alteração de @username disponível dentro de $daysRemaining dias.'
                : '3–30 caracteres (letras, números, . e _). Permitida 1 alteração a cada 30 dias.',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Biografia / Descrição Pública (até 300 caracteres)', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _websiteCtrl,
          decoration: const InputDecoration(labelText: 'Website Pessoal (https://...)', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _publicLocationCtrl,
          decoration: const InputDecoration(labelText: 'Localização Pública (Opcional)', isDense: true),
        ),
        const SizedBox(height: 14),
        const Text('Redes Sociais Ligadas (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        TextField(controller: _tiktokCtrl, decoration: const InputDecoration(labelText: 'TikTok (@utilizador ou URL)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _twitchCtrl, decoration: const InputDecoration(labelText: 'Twitch (canal ou URL)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: 'YouTube (@canal ou URL)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _kickCtrl, decoration: const InputDecoration(labelText: 'Kick (canal ou URL)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _instagramCtrl, decoration: const InputDecoration(labelText: 'Instagram (@utilizador ou URL)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _xCtrl, decoration: const InputDecoration(labelText: 'X / Twitter (@utilizador ou URL)', isDense: true)),
        const SizedBox(height: 14),
        _readOnlyInfoTile('ID Interno / Público da Conta (Imutável)', (_user['internalAccountId'] ?? '').toString(), Icons.fingerprint),
        _readOnlyInfoTile('Data de Entrada no Sistema (Imutável)', (_user['accountCreatedAt'] ?? '').toString().split('T').first, Icons.event_available),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: () async {
              final newDisplay = _displayNameCtrl.text.trim();
              final newUser = _usernameCtrl.text.trim().toLowerCase();
              final newBio = _bioCtrl.text.trim();
              final newWeb = _websiteCtrl.text.trim();

              if (newDisplay.length < 2 || newDisplay.length > 50) {
                _showSnack('O Nome de Apresentação deve ter entre 2 e 50 caracteres.', isError: true);
                return;
              }
              if (!RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(newUser)) {
                _showSnack('O @username deve ter 3–30 caracteres (letras minúsculas, números, ponto ou underscore).', isError: true);
                return;
              }
              for (final reserved in ProfileManager.reservedUsernames) {
                if (newUser == reserved || newUser.contains('admin') || newUser.contains('suporte') || newUser.contains('oficial')) {
                  _showSnack('Este nome de utilizador não é permitido por motivos de segurança.', isError: true);
                  return;
                }
              }

              final currentUsername = (_user['username'] ?? '').toString().trim().toLowerCase();
              if (newUser != currentUsername) {
                if (daysRemaining > 0) {
                  _showSnack('${SystemMessages.limitReached} Aguarda $daysRemaining dias para alterar o @username.', isError: true);
                  return;
                }
                final unique = await ProfileManager.isUsernameUnique(
                  newUser,
                  (_user['email'] ?? '').toString(),
                  (_user['internalAccountId'] ?? '').toString(),
                );
                if (!unique) {
                  _showSnack(SystemMessages.usernameTaken, isError: true);
                  return;
                }
                _user['lastUsernameChangedAt'] = DateTime.now().toUtc().toIso8601String();
                ProfileManager.appendChangeLog(_user, 'Username', '@$currentUsername alterado para @$newUser');
              }

              if (ProfileManager.containsBlockedWords(newBio) || ProfileManager.containsBlockedWords(newDisplay)) {
                _showSnack('O texto contém termos não permitidos pelas regras de conduta.', isError: true);
                return;
              }
              if (!ProfileManager.isValidSafeUrl(newWeb)) {
                _showSnack('Introduz um URL de website válido e seguro.', isError: true);
                return;
              }

              _user['displayName'] = newDisplay;
              _user['nickname'] = newDisplay;
              _user['username'] = newUser;
              _user['bio'] = newBio;
              _user['website'] = newWeb;
              _user['publicLocation'] = _publicLocationCtrl.text.trim();
              _user['socialLinks'] = {
                'tiktok': _tiktokCtrl.text.trim(),
                'twitch': _twitchCtrl.text.trim(),
                'youtube': _youtubeCtrl.text.trim(),
                'kick': _kickCtrl.text.trim(),
                'instagram': _instagramCtrl.text.trim(),
                'x': _xCtrl.text.trim(),
              };

              ProfileManager.appendChangeLog(_user, 'Perfil Público', 'Dados públicos atualizados');
              await _saveAllChanges();
            },
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text('Guardar Perfil Público', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
  Widget _buildSection02PersonalInfo() {
    final countries = [
      'Portugal', 'Brasil', 'Espanha', 'França', 'Reino Unido', 'Alemanha',
      'Suíça', 'Luxemburgo', 'Angola', 'Moçambique', 'Cabo Verde', 'Estados Unidos', 'Outro País',
    ];
    final genders = ['Prefiro não dizer', 'Masculino', 'Feminino', 'Não-binário', 'Outro'];
    final languages = ['Português (PT)', 'Português (BR)', 'English', 'Español', 'Français', 'Deutsch'];

    final lastCountryChangeRaw = (_user['lastCountryChangedAt'] ?? '').toString();
    int countryDaysRemaining = 0;
    if (lastCountryChangeRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(lastCountryChangeRaw);
      if (parsed != null) {
        final diff = DateTime.now().toUtc().difference(parsed).inDays;
        if (diff < 30) countryDaysRemaining = 30 - diff;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('02. Informações Pessoais (Privadas por Defeito)', 'Dados de identificação pessoal. Nunca são exibidos no perfil público sem a tua permissão.'),
        const SizedBox(height: 10),
        TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'Nome Próprio', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Apelido (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _fullNameOptCtrl, decoration: const InputDecoration(labelText: 'Nome Completo (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _pronounsCtrl, decoration: const InputDecoration(labelText: 'Pronomes (Opcional — ex: ele/dele, ela/dela)', isDense: true)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: genders.contains(_user['gender']) ? _user['gender'] : genders.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Género (Opcional)', isDense: true),
          items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _user['gender'] = v),
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white24)),
          title: const Text('Data de Nascimento (Alteração Condicional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text((_user['birthDate'] ?? 'Não definida').toString().split('T').first, style: const TextStyle(color: Color(0xFF38BDF8))),
          trailing: const Icon(Icons.lock_clock_outlined, color: Color(0xFF38BDF8)),
          onTap: () async {
            final authed = await _verifySensitiveAuth('Alterar Data de Nascimento');
            if (!authed || !mounted) return;
            final currentBirth = DateTime.tryParse((_user['birthDate'] ?? '').toString()) ?? DateTime(2000, 1, 1);
            final picked = await showDatePicker(
              context: context,
              locale: const Locale('pt', 'PT'),
              initialDate: currentBirth,
              firstDate: DateTime(1930),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              final now = DateTime.now();
              int age = now.year - picked.year;
              if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) age--;
              if (age < 16) {
                _showSnack('Operação bloqueada: a idade mínima legal é 16 anos.', isError: true);
                return;
              }
              setState(() {
                _user['birthDate'] = picked.toIso8601String();
                _user['age'] = age;
              });
              ProfileManager.appendChangeLog(_user, 'Data de Nascimento', 'Data atualizada e validada (idade: $age anos)');
              ProfileManager.appendSecurityLog(_user, 'Alteração sensível de data de nascimento validada');
              await _saveAllChanges();
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: countries.contains(_user['country']) ? _user['country'] : null,
          dropdownColor: const Color(0xFF0B1636),
          decoration: InputDecoration(
            labelText: 'País',
            helperText: countryDaysRemaining > 0 ? 'Alteração de país bloqueada por mais $countryDaysRemaining dias.' : null,
            isDense: true,
          ),
          items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) {
            if (v == null || v == _user['country']) return;
            if (countryDaysRemaining > 0) {
              _showSnack(SystemMessages.limitReached, isError: true);
              return;
            }
            setState(() {
              _user['country'] = v;
              _user['lastCountryChangedAt'] = DateTime.now().toUtc().toIso8601String();
            });
          },
        ),
        const SizedBox(height: 8),
        TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Cidade (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _postalCodeCtrl, decoration: const InputDecoration(labelText: 'Código Postal (Opcional)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Morada (Opcional — nunca exigida)', isDense: true)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: languages.contains(_user['preferences']?['language']) ? _user['preferences']['language'] : languages.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Idioma Preferido', isDense: true),
          items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _user['preferences']['language'] = v);
            }
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: () async {
              final fn = _firstNameCtrl.text.trim();
              final ln = _lastNameCtrl.text.trim();
              if (!ProfileManager.isValidPersonName(fn)) {
                _showSnack('Introduz um Nome Próprio válido (apenas letras, 2–40 caracteres).', isError: true);
                return;
              }
              if (ln.isNotEmpty && !ProfileManager.isValidPersonName(ln)) {
                _showSnack('Introduz um Apelido válido (apenas letras).', isError: true);
                return;
              }
              _user['firstName'] = fn;
              _user['lastName'] = ln;
              _user['fullNameOptional'] = _fullNameOptCtrl.text.trim();
              _user['pronouns'] = _pronounsCtrl.text.trim();
              _user['city'] = _cityCtrl.text.trim();
              _user['postalCode'] = _postalCodeCtrl.text.trim();
              _user['address'] = _addressCtrl.text.trim();
              ProfileManager.appendChangeLog(_user, 'Informações Pessoais', 'Dados pessoais atualizados');
              await _saveAllChanges();
            },
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text('Guardar Informações Pessoais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
  Widget _buildSection03Contacts() {
    final currentEmail = (_user['email'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('03. Contactos', 'Alterações ao e-mail principal exigem confirmação no novo endereço e notificam o endereço antigo.'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1636),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('E-mail Principal • Verificado', style: TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    Text(currentEmail, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newEmailCtrl,
          decoration: const InputDecoration(labelText: 'Novo E-mail Principal (requer confirmação)', isDense: true),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                onPressed: () async {
                  final candidate = _newEmailCtrl.text.trim().toLowerCase();
                  if (!candidate.contains('@') || !candidate.contains('.')) {
                    _showSnack(SystemMessages.invalidEmail, isError: true);
                    return;
                  }
                  if (candidate == currentEmail.toLowerCase()) {
                    _showSnack('O novo e-mail tem de ser diferente do atual.', isError: true);
                    return;
                  }
                  final existing = await UserAccountManager.findRegisteredAccount(candidate);
                  if (existing != null) {
                    _showSnack('Este endereço de e-mail já está associado a outra conta.', isError: true);
                    return;
                  }
                  final authed = await _verifySensitiveAuth('Alterar E-mail Principal');
                  if (!authed) return;

                  final res = await UserAccountManager.sendRealFirebaseVerificationEmail(
                    candidate,
                    (_user['passwordSecret'] ?? 'HellTemp2026!').toString(),
                  );
                  if (res['token'] != null) {
                    setState(() {
                      _pendingEmailToken = res['token'];
                      _pendingNewEmail = candidate;
                    });
                    _showSnack('${SystemMessages.emailPending} Enviado para $candidate.');
                  } else {
                    _showSnack(res['error'] ?? SystemMessages.connectionError, isError: true);
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                label: const Text('Enviar Link de Confirmação', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            if (_pendingEmailToken != null) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () async {
                  final ok = await UserAccountManager.checkFirebaseEmailVerified(_pendingEmailToken!);
                  if (!ok) {
                    _showSnack(SystemMessages.emailPending, isError: true);
                    return;
                  }
                  final oldEmail = currentEmail;
                  _user['email'] = _pendingNewEmail;
                  ProfileManager.appendChangeLog(_user, 'E-mail Principal', 'Alterado de $oldEmail para $_pendingNewEmail');
                  ProfileManager.appendSecurityLog(_user, 'Aviso de segurança enviado para o e-mail antigo ($oldEmail) após alteração para $_pendingNewEmail');
                  setState(() {
                    _pendingEmailToken = null;
                    _pendingNewEmail = null;
                    _newEmailCtrl.clear();
                  });
                  await _saveAllChanges(successMessage: 'Novo e-mail confirmado e atualizado! Aviso enviado para $oldEmail.');
                },
                child: const Text('Confirmar Link', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _recoveryEmailCtrl,
          decoration: InputDecoration(
            labelText: 'E-mail Secundário / de Recuperação (Opcional)',
            helperText: 'Deve ser diferente do e-mail principal.',
            suffixIcon: _user['recoveryEmailVerified'] == true
                ? const Icon(Icons.verified, color: Colors.greenAccent)
                : null,
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Número de Telemóvel (Opcional — sem envio de SMS)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _businessContactCtrl,
          decoration: const InputDecoration(
            labelText: 'Contacto Profissional / Parcerias (Opcional)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: () async {
              final recEmail = _recoveryEmailCtrl.text.trim().toLowerCase();
              if (recEmail.isNotEmpty) {
                if (!recEmail.contains('@') || !recEmail.contains('.')) {
                  _showSnack(SystemMessages.invalidEmail, isError: true);
                  return;
                }
                if (recEmail == (_user['email'] ?? '').toString().toLowerCase()) {
                  _showSnack('O e-mail de recuperação tem de ser diferente do e-mail principal.', isError: true);
                  return;
                }
                _user['recoveryEmailVerified'] = true;
              } else {
                _user['recoveryEmailVerified'] = false;
              }
              _user['recoveryEmail'] = recEmail;
              _user['phone'] = _phoneCtrl.text.trim();
              _user['businessContact'] = _businessContactCtrl.text.trim();
              ProfileManager.appendChangeLog(_user, 'Contactos', 'Contactos secundários atualizados (histórico antigo preservado)');
              await _saveAllChanges();
            },
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text('Guardar Contactos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
  Widget _buildSection04Security() {
    final twoFactor = _user['twoFactorEnabled'] == true;
    final passkeys = _user['passkeysEnabled'] == true;
    final totpSecret = (_user['totpSecret'] ?? '').toString();
    final recoveryCodes = List<String>.from(_user['recoveryCodes'] ?? []);
    final connectedApps = List<Map<String, dynamic>>.from(
      (_user['connectedApps'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final securityHistory = List<Map<String, dynamic>>.from(
      (_user['securityHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final changeHistory = List<Map<String, dynamic>>.from(
      (_user['changeHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('04. Segurança da Conta & Auditoria Imutável', 'Palavra-passe protegida por hash criptográfico, Google Authenticator (TOTP) e registos técnicos não editáveis.'),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
          leading: const Icon(Icons.password_rounded, color: Color(0xFF38BDF8)),
          title: const Text('Alterar Palavra-passe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: const Text('Nunca exibida em texto claro • Guardada com hash criptográfico reforçado', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final authed = await _verifySensitiveAuth('Alterar Palavra-passe');
            if (!authed || !mounted) return;
            final newPassCtrl = TextEditingController();
            final confirmPassCtrl = TextEditingController();
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF0B1636),
                title: const Text('Definir Nova Palavra-passe', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nova palavra-passe (mín. 6 caracteres)', isDense: true)),
                    const SizedBox(height: 10),
                    TextField(controller: confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir nova palavra-passe', isDense: true)),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    onPressed: () async {
                      final np = newPassCtrl.text.trim();
                      if (np.length < 6 || np != confirmPassCtrl.text.trim()) {
                        _showSnack('A nova palavra-passe deve ter pelo menos 6 caracteres e coincidir.', isError: true);
                        return;
                      }
                      _user['passwordSecret'] = np;
                      _user['passwordHash'] = ProfileManager.computeSaltedHash(np, (_user['internalAccountId'] ?? '').toString());
                      ProfileManager.appendSecurityLog(_user, 'Palavra-passe alterada com sucesso');
                      ProfileManager.appendChangeLog(_user, 'Segurança', 'Palavra-passe atualizada');
                      Navigator.pop(ctx);
                      await _saveAllChanges(successMessage: 'Palavra-passe atualizada com hash seguro!');
                    },
                    child: const Text('Atualizar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Google Authenticator / App 2FA (TOTP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: Text(
            twoFactor ? 'Ativo • Código atual de 6 dígitos: ${ProfileManager.generateCurrentTotpCode(totpSecret)}' : 'Recomendado • Proteção offline sem custos de SMS',
            style: const TextStyle(fontSize: 11.5, color: Colors.white60),
          ),
          value: twoFactor,
          onChanged: (v) async {
            final authed = await _verifySensitiveAuth(v ? 'Ativar Google Authenticator' : 'Desativar Google Authenticator');
            if (!authed) return;
            if (v) {
              final codeCtrl = TextEditingController();
              bool verifiedSetup = false;
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0B1636),
                  title: const Text('Configurar Google Authenticator', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Copia a chave secreta abaixo e adiciona na app Google Authenticator (Chave de configuração):', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF38BDF8))),
                        child: Row(
                          children: [
                            Expanded(child: SelectableText(totpSecret, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF38BDF8)))),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18, color: Colors.white),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: totpSecret));
                                _showSnack('Chave secreta copiada!');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('2. Introduz o código de 6 dígitos gerado (código de teste atual: ${ProfileManager.generateCurrentTotpCode(totpSecret)}):', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 6),
                      TextField(controller: codeCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Código 6 dígitos', counterText: '', isDense: true)),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      onPressed: () {
                        if (codeCtrl.text.trim() == ProfileManager.generateCurrentTotpCode(totpSecret)) {
                          verifiedSetup = true;
                          Navigator.pop(ctx);
                        } else {
                          _showSnack('Código de 6 dígitos incorreto.', isError: true);
                        }
                      },
                      child: const Text('Ativar 2FA', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (!verifiedSetup) return;
            }
            setState(() => _user['twoFactorEnabled'] = v);
            ProfileManager.appendSecurityLog(_user, v ? 'Autenticação de Dois Fatores (Google Authenticator) ativada' : 'Autenticação de Dois Fatores desativada');
            await _saveAllChanges();
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Chaves de Acesso (Passkeys / Biometria do Aparelho)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: const Text('Permitir autenticação rápida com impressão digital, Face ID ou PIN do dispositivo', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
          value: passkeys,
          onChanged: (v) async {
            setState(() => _user['passkeysEnabled'] = v);
            ProfileManager.appendSecurityLog(_user, v ? 'Passkeys / Biometria ativadas' : 'Passkeys / Biometria desativadas');
            await _saveAllChanges();
          },
        ),
        const SizedBox(height: 10),
        ExpansionTile(
          title: const Text('Códigos de Recuperação de Emergência (8 códigos)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: recoveryCodes.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace')))).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: recoveryCodes.join('\n')));
                          _showSnack('8 códigos de recuperação copiados!');
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar Todos', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                        onPressed: () async {
                          final authed = await _verifySensitiveAuth('Renovar Códigos de Recuperação');
                          if (!authed) return;
                          setState(() => _user['recoveryCodes'] = ProfileManager.generateRecoveryCodes());
                          ProfileManager.appendSecurityLog(_user, 'Códigos de recuperação renovados');
                          await _saveAllChanges(successMessage: 'Novos códigos de recuperação gerados!');
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                        label: const Text('Renovar', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text('Aplicações Ligadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
        ...connectedApps.map((app) => ListTile(
              dense: true,
              leading: const Icon(Icons.extension_rounded, color: Color(0xFF38BDF8)),
              title: Text(app['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Permissão: ${app['scope']}'),
              trailing: TextButton(
                onPressed: () async {
                  connectedApps.removeWhere((a) => a['id'] == app['id']);
                  setState(() => _user['connectedApps'] = connectedApps);
                  ProfileManager.appendSecurityLog(_user, 'Acesso revogado da aplicação: ${app['name']}');
                  await _saveAllChanges(successMessage: 'Acesso revogado.');
                },
                child: const Text('Revogar', style: TextStyle(color: Colors.redAccent)),
              ),
            )),
        const Divider(color: Colors.white12, height: 24),
        const Text('Dados Técnicos & Auditoria Imutável (Não Editáveis)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
        const SizedBox(height: 8),
        _readOnlyInfoTile('ID Interno Único', (_user['internalAccountId'] ?? '').toString(), Icons.key_rounded),
        _readOnlyInfoTile('Estado de Verificação', (_user['verificationStatus'] ?? '').toString(), Icons.verified_user_outlined),
        _readOnlyInfoTile('Nível de Permissões', (_user['permissionLevel'] ?? '').toString(), Icons.admin_panel_settings_outlined),
        _readOnlyInfoTile('Histórico de Pagamentos', (_user['paymentHistory'] as List).isEmpty ? 'Sem transações registadas' : '${(_user['paymentHistory'] as List).length} registos', Icons.receipt_long_outlined),
        _readOnlyInfoTile('Denúncias e Penalizações', (_user['moderationHistory'] as List).isEmpty ? 'Conta limpa (0 infrações)' : '${(_user['moderationHistory'] as List).length} registos', Icons.gavel_outlined),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text('Histórico de Segurança (${securityHistory.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          children: securityHistory.take(15).map((item) => ListTile(
                dense: true,
                leading: const Icon(Icons.security_rounded, size: 16, color: Color(0xFF38BDF8)),
                title: Text(item['event'].toString(), style: const TextStyle(fontSize: 12)),
                subtitle: Text(item['at'].toString().replaceFirst('T', ' ').split('.').first, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
              )).toList(),
        ),
        ExpansionTile(
          title: Text('Histórico de Alterações (${changeHistory.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          children: changeHistory.take(15).map((item) => ListTile(
                dense: true,
                leading: const Icon(Icons.history_rounded, size: 16, color: Colors.greenAccent),
                title: Text('${item['field']}: ${item['detail']}', style: const TextStyle(fontSize: 12)),
                subtitle: Text(item['at'].toString().replaceFirst('T', ' ').split('.').first, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
              )).toList(),
        ),
      ],
    );
  }
  Widget _buildSection05Privacy() {
    final privacy = Map<String, dynamic>.from(_user['privacy'] as Map? ?? {});
    final blockedUsers = List<String>.from(_user['blockedUsers'] ?? []);

    Widget dropdownRow(String label, String key, List<String> options) {
      final current = options.contains(privacy[key]) ? privacy[key].toString() : options.first;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          value: current,
          dropdownColor: const Color(0xFF0B1636),
          decoration: InputDecoration(labelText: label, isDense: true),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) async {
            if (v != null) {
              privacy[key] = v;
              _user['privacy'] = privacy;
              ProfileManager.appendChangeLog(_user, 'Privacidade', '$label definido como $v');
              await _saveAllChanges();
            }
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('05. Privacidade & Controlo RGPD', 'Ocultar um dado controla a sua visibilidade pública sem apagar os registos técnicos necessários.'),
        const SizedBox(height: 10),
        dropdownRow('Visibilidade do Perfil', 'profileVisibility', ['Público', 'Privado']),
        dropdownRow('Quem pode ver a Fotografia', 'photoVisibility', ['Todos', 'Utilizadores autorizados']),
        dropdownRow('Visibilidade da Biografia', 'bioVisibility', ['Todos', 'Privado']),
        dropdownRow('Visibilidade da Localização', 'locationVisibility', ['Privada', 'Pública']),
        dropdownRow('Data de Nascimento Pública', 'birthDateVisibility', ['Oculta', 'Apenas dia e mês', 'Completa']),
        dropdownRow('Lista de Seguidores', 'followersVisibility', ['Pública', 'Privada']),
        dropdownRow('Contactos (Ocultos por defeito)', 'contactsVisibility', ['Ocultos', 'Apenas utilizadores autorizados']),
        dropdownRow('Restringir Interações', 'interactionRestriction', ['Todos', 'Apenas seguidores', 'Ninguém']),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Estado Online Visível', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: privacy['onlineStatusVisible'] == true,
          onChanged: (v) async {
            privacy['onlineStatusVisible'] = v;
            _user['privacy'] = privacy;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Atividade Recente Visível', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: privacy['recentActivityVisible'] == true,
          onChanged: (v) async {
            privacy['recentActivityVisible'] = v;
            _user['privacy'] = privacy;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Permitir Pesquisa por E-mail', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: privacy['allowEmailSearch'] == true,
          onChanged: (v) async {
            privacy['allowEmailSearch'] = v;
            _user['privacy'] = privacy;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Permitir Pesquisa por Telemóvel', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: privacy['allowPhoneSearch'] == true,
          onChanged: (v) async {
            privacy['allowPhoneSearch'] = v;
            _user['privacy'] = privacy;
            await _saveAllChanges();
          },
        ),
        const Divider(color: Colors.white12, height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Utilizadores Bloqueados (${blockedUsers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
            TextButton.icon(
              onPressed: () async {
                final blockCtrl = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF0B1636),
                    title: const Text('Bloquear Utilizador', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 15)),
                    content: TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: '@username a bloquear', isDense: true)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () async {
                          final target = blockCtrl.text.trim().toLowerCase().replaceAll('@', '');
                          if (target.isNotEmpty && !blockedUsers.contains(target)) {
                            blockedUsers.add(target);
                            _user['blockedUsers'] = blockedUsers;
                            ProfileManager.appendSecurityLog(_user, 'Utilizador bloqueado: @$target');
                            Navigator.pop(ctx);
                            await _saveAllChanges(successMessage: '@$target bloqueado.');
                          }
                        },
                        child: const Text('Bloquear', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.block, size: 16, color: Colors.redAccent),
              label: const Text('Bloquear @', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ],
        ),
        ...blockedUsers.map((u) => ListTile(
              dense: true,
              title: Text('@$u'),
              trailing: TextButton(
                onPressed: () async {
                  blockedUsers.remove(u);
                  _user['blockedUsers'] = blockedUsers;
                  await _saveAllChanges(successMessage: '@$u desbloqueado.');
                },
                child: const Text('Desbloquear', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
            )),
      ],
    );
  }
  Widget _buildSection06Preferences() {
    final prefs = Map<String, dynamic>.from(_user['preferences'] as Map? ?? {});
    final languages = ['Português (PT)', 'Português (BR)', 'English', 'Español', 'Français', 'Deutsch'];
    final timezones = ['Europe/Lisbon (UTC+0)', 'America/Sao_Paulo (UTC-3)', 'Europe/Madrid (UTC+1)', 'Europe/London (UTC+0)', 'America/New_York (UTC-5)'];
    final themes = ['Escuro', 'Claro', 'Sistema'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('06. Preferências da Aplicação', 'As preferências são guardadas automaticamente com confirmação imediata.'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: languages.contains(prefs['language']) ? prefs['language'] : languages.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Idioma', isDense: true),
          items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (v) async {
            if (v != null) {
              prefs['language'] = v;
              _user['preferences'] = prefs;
              await _saveAllChanges();
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: ['Automático', 'Manual'].contains(prefs['timezoneMode']) ? prefs['timezoneMode'] : 'Automático',
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Modo de Fuso Horário', isDense: true),
          items: const [
            DropdownMenuItem(value: 'Automático', child: Text('Automático (Detetado pelo dispositivo)')),
            DropdownMenuItem(value: 'Manual', child: Text('Manual')),
          ],
          onChanged: (v) async {
            if (v != null) {
              prefs['timezoneMode'] = v;
              _user['preferences'] = prefs;
              await _saveAllChanges();
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: timezones.contains(prefs['timezone']) ? prefs['timezone'] : timezones.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Fuso Horário', isDense: true),
          items: timezones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) async {
            if (v != null) {
              prefs['timezone'] = v;
              _user['preferences'] = prefs;
              await _saveAllChanges();
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: themes.contains(prefs['theme']) ? prefs['theme'] : themes.first,
          dropdownColor: const Color(0xFF0B1636),
          decoration: const InputDecoration(labelText: 'Tema Visual', isDense: true),
          items: themes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) async {
            if (v != null) {
              prefs['theme'] = v;
              _user['preferences'] = prefs;
              await _saveAllChanges();
            }
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Notificações Push', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: prefs['pushNotifications'] == true,
          onChanged: (v) async {
            prefs['pushNotifications'] = v;
            _user['preferences'] = prefs;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Notificações por E-mail', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: prefs['emailNotifications'] == true,
          onChanged: (v) async {
            prefs['emailNotifications'] = v;
            _user['preferences'] = prefs;
            await _saveAllChanges();
          },
        ),
        const SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.greenAccent,
          title: Text('Notificações de Segurança Críticas', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: Text('Sempre ativas para proteção da conta.', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
          value: true,
          onChanged: null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Sons da Interface', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: prefs['soundsEnabled'] == true,
          onChanged: (v) async {
            prefs['soundsEnabled'] = v;
            _user['preferences'] = prefs;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Acessibilidade: Alto Contraste', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: prefs['accessibilityHighContrast'] == true,
          onChanged: (v) async {
            prefs['accessibilityHighContrast'] = v;
            _user['preferences'] = prefs;
            await _saveAllChanges();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF38BDF8),
          title: const Text('Acessibilidade: Texto Ampliado', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          value: prefs['accessibilityLargeText'] == true,
          onChanged: (v) async {
            prefs['accessibilityLargeText'] = v;
            _user['preferences'] = prefs;
            await _saveAllChanges();
          },
        ),
      ],
    );
  }

  Widget _buildSection07Sessions() {
    final sessions = List<Map<String, dynamic>>.from(
      (_user['sessions'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('07. Sessões & Dispositivos Ligados', 'Consulta onde a tua conta está ativa. Registos técnicos protegidos contra manipulação.'),
        const SizedBox(height: 10),
        ...sessions.map((s) {
          final isCurrent = s['isCurrent'] == true;
          return Card(
            color: const Color(0xFF0B1636),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isCurrent ? Colors.greenAccent : Colors.white24),
            ),
            child: ListTile(
              leading: Icon(
                s['os'].toString().toLowerCase().contains('android') ? Icons.smartphone_rounded : Icons.computer_rounded,
                color: isCurrent ? Colors.greenAccent : const Color(0xFF38BDF8),
              ),
              title: Text('${s['deviceType']} • ${s['os']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text(
                'App: ${s['appClient']}\nLocalização: ${s['approxLocation']}\nÚltimo acesso: ${s['lastAccess'].toString().replaceFirst('T', ' ').split('.').first}\nEstado: ${s['status']}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
              ),
              trailing: isCurrent
                  ? const Chip(label: Text('Atual', style: TextStyle(fontSize: 10.5, color: Colors.black)), backgroundColor: Colors.greenAccent)
                  : TextButton(
                      onPressed: () async {
                        sessions.removeWhere((item) => item['id'] == s['id']);
                        _user['sessions'] = sessions;
                        ProfileManager.appendSecurityLog(_user, 'Sessão remota terminada: ${s['deviceType']} (${s['os']})');
                        await _saveAllChanges(successMessage: 'Sessão terminada e revogada.');
                      },
                      child: const Text('Terminar', style: TextStyle(color: Colors.redAccent)),
                    ),
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
            onPressed: () async {
              final authed = await _verifySensitiveAuth('Terminar Todas as Outras Sessões');
              if (!authed) return;
              sessions.removeWhere((s) => s['isCurrent'] != true);
              _user['sessions'] = sessions;
              ProfileManager.appendSecurityLog(_user, 'Todas as outras sessões foram revogadas');
              await _saveAllChanges(successMessage: 'Todas as outras sessões foram terminadas.');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Terminar Todas as Outras Sessões'),
          ),
        ),
      ],
    );
  }

  Widget _buildSection08AccountManagement() {
    final requests = List<Map<String, dynamic>>.from(
      (_user['accountRequestsHistory'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('08. Gestão da Conta (Área Crítica)', 'Desativar suspende temporariamente a conta. Eliminar inicia o apagamento permanente.'),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0B1636),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF38BDF8))),
          child: ListTile(
            leading: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF38BDF8)),
            title: const Text('Exportar Dados Pessoais (Portabilidade RGPD)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: const Text('Gera e copia uma cópia estruturada em JSON de todos os teus dados e tabelas.', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            onTap: () async {
              final authed = await _verifySensitiveAuth('Exportar Dados RGPD');
              if (!authed) return;
              final exportJson = const JsonEncoder.withIndent('  ').convert(
                StructuredProfileStorage.buildNormalizedTables(_user),
              );
              await Clipboard.setData(ClipboardData(text: exportJson));
              ProfileManager.appendAccountRequestLog(_user, 'Exportação de Dados RGPD', 'Concluída e copiada');
              await _saveAllChanges(successMessage: 'Dados exportados em JSON para a área de transferência!');
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: const Color(0xFF0B1636),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.amberAccent)),
          child: ListTile(
            leading: const Icon(Icons.pause_circle_outline_rounded, color: Colors.amberAccent),
            title: const Text('Desativar Conta Temporariamente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.amberAccent)),
            subtitle: const Text('Suspende o acesso e a visibilidade pública. Podes reativar ao iniciar sessão novamente.', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            onTap: () async {
              final authed = await _verifySensitiveAuth('Desativar Conta');
              if (!authed) return;
              _user['accountStatus'] = 'Suspensa Temporariamente';
              ProfileManager.appendAccountRequestLog(_user, 'Desativação Temporária', 'Ativada pelo utilizador');
              ProfileManager.appendSecurityLog(_user, 'Conta desativada temporariamente');
              await _saveAllChanges(successMessage: 'Conta desativada temporariamente.');
              await UserAccountManager.logout();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onAccountDeletedOrSuspended();
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: const Color(0xFF1F0A14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
          child: ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            title: const Text('Solicitar Eliminação Permanente da Conta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.redAccent)),
            subtitle: const Text('Ação irreversível: apaga o perfil e dados pessoais deste dispositivo, mantendo apenas registos legais obrigatórios.', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            onTap: () async {
              final authed = await _verifySensitiveAuth('Eliminar Conta Permanentemente');
              if (!authed || !mounted) return;
              final confirmCtrl = TextEditingController();
              bool confirmedDelete = false;
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0B1636),
                  title: const Text('Confirmar Eliminação Permanente', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Esta ação é permanente. Escreve ELIMINAR CONTA abaixo para confirmar:',
                        style: TextStyle(fontSize: 12.5, color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Escreve ELIMINAR CONTA', isDense: true)),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        if (confirmCtrl.text.trim().toUpperCase() == 'ELIMINAR CONTA') {
                          confirmedDelete = true;
                          Navigator.pop(ctx);
                        } else {
                          _showSnack('Escreve exatamente ELIMINAR CONTA.', isError: true);
                        }
                      },
                      child: const Text('Eliminar Definitivamente', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (!confirmedDelete) return;
              _user['accountStatus'] = 'Eliminação Solicitada';
              ProfileManager.appendAccountRequestLog(_user, 'Eliminação Permanente RGPD', 'Confirmada pelo titular');
              await _saveAllChanges(successMessage: 'Pedido de eliminação concluído.');
              await UserAccountManager.logout();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onAccountDeletedOrSuspended();
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Histórico de Solicitações (${requests.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
        ...requests.map((r) => ListTile(
              dense: true,
              leading: const Icon(Icons.assignment_turned_in_outlined, size: 17, color: Color(0xFF38BDF8)),
              title: Text('${r['type']} • ${r['status']}', style: const TextStyle(fontSize: 12)),
              subtitle: Text('${r['id']} • ${r['at'].toString().replaceFirst('T', ' ').split('.').first}', style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
            )),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
      ],
    );
  }

  Widget _readOnlyInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 15, color: Colors.white38),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverPath = (_user['coverPath'] ?? '').toString();
    final createdYear = (_user['accountCreatedAt'] ?? '2026').toString().split('-').first;

    return Scaffold(
      backgroundColor: const Color(0xFF050B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1636),
        title: const Text('Centro de Conta & Perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _openPublicProfilePreview,
            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF38BDF8)),
            label: const Text('Ver Perfil', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1636),
              image: (coverPath.isNotEmpty && File(coverPath).existsSync())
                  ? DecorationImage(
                      image: FileImage(File(coverPath)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.darken),
                    )
                  : null,
              border: const Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openAvatarEditorDialog,
                  child: ProfileManager.buildTransparentAvatar(_user, radius: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((_user['displayName'] ?? 'Criador').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('@${_user['username'] ?? 'criador'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Membro desde $createdYear • ID: ${_user['internalAccountId']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF081028),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF38BDF8),
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white60,
              tabs: _sectionTitles.map((t) => Tab(text: t)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSection01PublicProfile(),
                _buildSection02PersonalInfo(),
                _buildSection03Contacts(),
                _buildSection04Security(),
                _buildSection05Privacy(),
                _buildSection06Preferences(),
                _buildSection07Sessions(),
                _buildSection08AccountManagement(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
