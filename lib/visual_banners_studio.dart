import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HellOwnerAndVipPolicy {
  // Conta Mestra Suprema da Marca — 100% Intocável e Inalienável
  static const String supremeBrandEmail = 'hellcreatoros@gmail.com';

  // E-mails Pessoais Iniciais do Fundador (podem ser geridos/sucedidos sob protocolo jurídico)
  static const List<String> initialPersonalOwnerEmails = <String>[
    'heldermsf_@hotmail.com',
    'hellgamer2026@gmail.com',
    'hell_@outlook.pt',
  ];

  static const String _kSovereignOwnersKey = 'hell_sovereign_owners_list_v3';
  static const String _kTeamEmailsKey = 'hell_owner_team_emails_v3';
  static const String _kDevModeKey = 'hell_owner_dev_mode_active_v3';
  static const String _kAcceptedTermsKey = 'hell_team_accepted_terms_v3';
  static const String _kCustomTermsTextKey = 'hell_team_custom_terms_text_v3';
  static const String _kPendingApprovalsKey = 'hell_owner_pending_approvals_v3';
  static const String _kGovernanceAuditKey = 'hell_governance_audit_log_v3';

  static List<String> _sovereignPersonalOwners = List<String>.from(initialPersonalOwnerEmails);
  static List<String> _cachedTeamEmails = <String>[];
  static bool _devModeActive = false;
  static Map<String, String> _acceptedTermsLog = <String, String>{};
  static List<Map<String, dynamic>> _pendingApprovals = <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> _governanceAuditLog = <Map<String, dynamic>>[];
  static String _customLegalTerms = '';

  static const String defaultEuropeanGlobalLegalTerms = '''
ACORDO JURÍDICO DE GOVERNANÇA, SUCESSÃO, DESENVOLVIMENTO, CONFIDENCIALIDADE (NDA) E RESPONSABILIDADE CIVIL/PENAL — HELL CREATOR

1. CONTA MESTRA SUPREMA E TITULARIDADE DA MARCA
A conta oficial da marca (hellcreatoros@gmail.com), o nome HELL CREATOR, o ecossistema HELL CREATOR OS, o código-fonte, bases de dados e ativos digitais constituem propriedade exclusiva e inalienável da Marca e dos seus Proprietários Soberanos legítimos. A Conta Mestra Suprema é tecnicamente e juridicamente intocável.

2. SUCESSÃO SOBERANA E PROTEÇÃO CONTRA ABUSO DE DIREITO
Os Proprietários Soberanos podem designar sucessores legítimos (nomeadamente herdeiros diretos) para assegurar a continuidade da plataforma. É estritamente proibida qualquer tentativa de exclusão arbitrária, golpe interno ou eliminação total de administradores sem justa causa comprovada, sob pena de nulidade absoluta do ato ao abrigo dos princípios europeus da Boa-Fé Contratual e Proibição do Abuso de Direito.

3. PROTOCOLO JURÍDICO DE REMOÇÃO E RESPONSABILIDADE DO EXECUTANTE
Qualquer remoção de Co-Proprietário ou Membro da Equipa exige registo formal de justa causa legal (sucessão/falecimento, pedido do titular, abandono comprovado ou violação grave de segurança/NDA). O autor da remoção assume plena responsabilidade civil, patrimonial e criminal pela veracidade dos factos invocados, respondendo por perdas e danos perante o visado e perante a Marca em caso de falsidade ou má-fé.

4. CONTROLO DE APROVAÇÃO PRÉVIA (ANTI-SABOTAGEM)
Todas as alterações submetidas por membros da equipa ficam sujeitas à aprovação expressa de um Proprietário Soberano antes da publicação.

5. DIREITO APLICÁVEL (UNIÃO EUROPEIA E TRATADOS INTERNACIONAIS)
Regido pelo Regulamento (UE) 2016/679 (RGPD), Diretiva (UE) 2022/2555 (NIS2), Diretiva (UE) 2019/790, Convenção de Berna e tratados da OMPI. Qualquer ato doloso, sabotagem ou fuga de dados implica responsabilidade civil e penal internacional.
''';

  static const String removalLegalDeclarationText = '''
DECLARAÇÃO LEGAL DE REVOGAÇÃO DE ACESSO E ASSUNÇÃO DE RESPONSABILIDADE JURÍDICA

Ao confirmar esta remoção, declaro sob compromisso de honra e responsabilidade legal (nos termos do Direito Civil e Penal da União Europeia, RGPD Regulamento (UE) 2016/679 e Diretiva NIS2):
1. Que esta exclusão baseia-se exclusivamente em justa causa legítima e documentada (sucessão hereditária/familiar, renúncia expressa do titular, inatividade grave ou violação comprovada de segurança/NDA);
2. Que não estou a agir com abuso de direito, má-fé ou intenção de apropriação indevida da plataforma;
3. Que assumo integral responsabilidade civil, financeira e criminal perante o titular removido, terceiros e a Conta Mestra Suprema (hellcreatoros@gmail.com) caso esta remoção venha a ser declarada ilícita ou infundada;
4. Que o titular removido mantém intactos todos os direitos legais de defesa, auditoria e recurso judicial, permanecendo apenas sujeito ao dever de sigilo (NDA) sobre dados confidenciais da marca.
''';

  static Future<void> loadOwnerState() async {
    final p = await SharedPreferences.getInstance();
    final savedOwners = p.getStringList(_kSovereignOwnersKey);
    if (savedOwners != null && savedOwners.isNotEmpty) {
      _sovereignPersonalOwners = savedOwners;
    } else {
      _sovereignPersonalOwners = List<String>.from(initialPersonalOwnerEmails);
    }
    _cachedTeamEmails = p.getStringList(_kTeamEmailsKey) ?? <String>[];
    _devModeActive = p.getBool(_kDevModeKey) ?? false;
    _customLegalTerms = p.getString(_kCustomTermsTextKey) ?? '';

    final rawAcc = p.getString(_kAcceptedTermsKey);
    if (rawAcc != null && rawAcc.isNotEmpty) {
      try {
        _acceptedTermsLog = Map<String, String>.from(jsonDecode(rawAcc) as Map);
      } catch (_) {}
    }

    final rawPend = p.getString(_kPendingApprovalsKey);
    if (rawPend != null && rawPend.isNotEmpty) {
      try {
        _pendingApprovals = List<Map<String, dynamic>>.from(
          (jsonDecode(rawPend) as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } catch (_) {}
    }

    final rawAudit = p.getString(_kGovernanceAuditKey);
    if (rawAudit != null && rawAudit.isNotEmpty) {
      try {
        _governanceAuditLog = List<Map<String, dynamic>>.from(
          (jsonDecode(rawAudit) as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } catch (_) {}
    }
  }

  static bool isSupremeBrandAccount(Map<String, dynamic>? user) {
    final email = (user?['email'] ?? '').toString().trim().toLowerCase();
    return email == supremeBrandEmail;
  }

  static bool isSovereignOwner(Map<String, dynamic>? user) {
    if (user == null) return false;
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    return email == supremeBrandEmail || _sovereignPersonalOwners.contains(email);
  }

  static List<String> getSovereignPersonalOwners() => List<String>.from(_sovereignPersonalOwners);
  static List<Map<String, dynamic>> getGovernanceAuditLog() => List<Map<String, dynamic>>.from(_governanceAuditLog);

  static Future<void> _recordAudit({
    required String action,
    required String actorEmail,
    required String targetEmail,
    required String legalGround,
    required String justification,
  }) async {
    _governanceAuditLog.insert(0, <String, dynamic>{
      'action': action,
      'actorEmail': actorEmail,
      'targetEmail': targetEmail,
      'legalGround': legalGround,
      'justification': justification,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGovernanceAuditKey, jsonEncode(_governanceAuditLog.take(100).toList()));
  }

  static Future<String?> addSovereignSuccessorOwner({
    required Map<String, dynamic>? actor,
    required String newOwnerEmail,
    required String relationOrNote,
  }) async {
    if (!isSovereignOwner(actor)) return 'Apenas um Proprietário Soberano pode nomear sucessores.';
    final clean = newOwnerEmail.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) return 'E-mail inválido.';
    if (clean == supremeBrandEmail || _sovereignPersonalOwners.contains(clean)) {
      return 'Este e-mail já possui estatuto de Proprietário Soberano.';
    }
    _sovereignPersonalOwners.add(clean);
    _cachedTeamEmails.remove(clean);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSovereignOwnersKey, _sovereignPersonalOwners);
    await p.setStringList(_kTeamEmailsKey, _cachedTeamEmails);
    await _recordAudit(
      action: 'NOMEAÇÃO DE PROPRIETÁRIO SOBERANO / SUCESSOR',
      actorEmail: (actor?['email'] ?? '').toString(),
      targetEmail: clean,
      legalGround: 'Sucessão / Co-Propriedade Autorizada',
      justification: relationOrNote.trim().isEmpty ? 'Designado pelo Proprietário Soberano' : relationOrNote.trim(),
    );
    return null;
  }

  static Future<String?> removeSovereignOwnerWithLegalProtocol({
    required Map<String, dynamic>? actor,
    required String targetEmail,
    required String legalGround,
    required String justification,
  }) async {
    if (!isSovereignOwner(actor)) return 'Sem permissão soberana.';
    final clean = targetEmail.trim().toLowerCase();
    if (clean == supremeBrandEmail) {
      return 'BLOQUEADO: A Conta Mestra Suprema ($supremeBrandEmail) é intocável e nunca pode ser removida.';
    }
    if (_sovereignPersonalOwners.length <= 1 && _sovereignPersonalOwners.contains(clean)) {
      return 'BLOQUEADO POR SEGURANÇA: Deve existir sempre pelo menos 1 Proprietário Soberano pessoal ativo além da Conta Mestra.';
    }
    if (justification.trim().length < 25) {
      return 'A justificação jurídica detalhada deve ter pelo menos 25 caracteres.';
    }
    _sovereignPersonalOwners.remove(clean);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSovereignOwnersKey, _sovereignPersonalOwners);
    await _recordAudit(
      action: 'REMOÇÃO DE CO-PROPRIETÁRIO SOBERANO',
      actorEmail: (actor?['email'] ?? '').toString(),
      targetEmail: clean,
      legalGround: legalGround,
      justification: justification.trim(),
    );
    return null;
  }
  static String getLegalTermsText() =>
      _customLegalTerms.trim().isNotEmpty ? _customLegalTerms : defaultEuropeanGlobalLegalTerms;

  static Future<void> updateLegalTermsByOwner(Map<String, dynamic>? user, String newText) async {
    if (!isSovereignOwner(user)) return;
    _customLegalTerms = newText.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCustomTermsTextKey, _customLegalTerms);
    await _recordAudit(
      action: 'ATUALIZAÇÃO DO CONTRATO JURÍDICO DA EQUIPA',
      actorEmail: (user?['email'] ?? '').toString(),
      targetEmail: 'Contrato Global HELL CREATOR',
      legalGround: 'Poder Soberano do Proprietário',
      justification: 'Texto legal atualizado pelo Proprietário Soberano',
    );
  }

  static bool isTeamMember(Map<String, dynamic>? user) {
    if (user == null) return false;
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    return _cachedTeamEmails.contains(email) && !isSovereignOwner(user);
  }

  static bool isOwnerOrTeam(Map<String, dynamic>? user) =>
      isSovereignOwner(user) || isTeamMember(user);

  static bool hasTeamAcceptedTerms(Map<String, dynamic>? user) {
    if (isSovereignOwner(user)) return true;
    final email = (user?['email'] ?? '').toString().trim().toLowerCase();
    return email.isNotEmpty && _acceptedTermsLog.containsKey(email);
  }

  static Map<String, String> getAcceptedTermsLog() => Map<String, String>.from(_acceptedTermsLog);

  static Future<void> acceptTeamTerms(Map<String, dynamic>? user) async {
    final email = (user?['email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty) return;
    _acceptedTermsLog[email] = DateTime.now().toUtc().toIso8601String();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAcceptedTermsKey, jsonEncode(_acceptedTermsLog));
    await _recordAudit(
      action: 'ACEITAÇÃO FORMAL DE CONTRATO JURÍDICO E NDA',
      actorEmail: email,
      targetEmail: email,
      legalGround: 'Aceitação Obrigatória com Leitura Integral',
      justification: 'O membro da equipa leu até ao fim e aceitou juridicamente os termos',
    );
  }

  static List<String> getTeamEmails() => List<String>.from(_cachedTeamEmails);
  static bool isDevModeActive() => _devModeActive;

  static Future<void> setDevModeActive(bool active) async {
    _devModeActive = active;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDevModeKey, active);
  }

  static Future<String?> addTeamEmail(Map<String, dynamic>? actor, String email, String roleNote) async {
    if (!isSovereignOwner(actor)) return 'Apenas Proprietários Soberanos podem adicionar equipa.';
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) return 'E-mail inválido.';
    if (isSovereignOwner(<String, dynamic>{'email': clean})) return 'Este e-mail já é Proprietário Soberano.';
    if (!_cachedTeamEmails.contains(clean)) {
      _cachedTeamEmails.add(clean);
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kTeamEmailsKey, _cachedTeamEmails);
      await _recordAudit(
        action: 'ADMISSÃO NA EQUIPA DE DESENVOLVIMENTO / GESTÃO',
        actorEmail: (actor?['email'] ?? '').toString(),
        targetEmail: clean,
        legalGround: 'Autorização de Proprietário Soberano',
        justification: roleNote.trim().isEmpty ? 'Admitido na equipa sob aceitação obrigatória dos Termos Legais' : roleNote.trim(),
      );
    }
    return null;
  }

  static Future<String?> removeTeamMemberWithLegalProtocol({
    required Map<String, dynamic>? actor,
    required String targetEmail,
    required String legalGround,
    required String justification,
  }) async {
    if (!isSovereignOwner(actor)) return 'Apenas Proprietários Soberanos podem remover membros da equipa.';
    if (justification.trim().length < 25) {
      return 'A justificação jurídica detalhada deve ter pelo menos 25 caracteres.';
    }
    final clean = targetEmail.trim().toLowerCase();
    _cachedTeamEmails.remove(clean);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kTeamEmailsKey, _cachedTeamEmails);
    await _recordAudit(
      action: 'REVOGAÇÃO DE MEMBRO DA EQUIPA',
      actorEmail: (actor?['email'] ?? '').toString(),
      targetEmail: clean,
      legalGround: legalGround,
      justification: justification.trim(),
    );
    return null;
  }

  static List<Map<String, dynamic>> getPendingApprovals() => List<Map<String, dynamic>>.from(_pendingApprovals);

  static Future<void> submitBannerChange({
    required Map<String, dynamic>? actor,
    required String menuId,
    required String newValue,
    required String description,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (isSovereignOwner(actor)) {
      await p.setString('hell_official_banner_$menuId', newValue);
      return;
    }
    if (isTeamMember(actor)) {
      _pendingApprovals.insert(0, <String, dynamic>{
        'id': 'apr_${DateTime.now().millisecondsSinceEpoch}',
        'menuId': menuId,
        'newValue': newValue,
        'description': description,
        'submittedBy': (actor?['email'] ?? '').toString(),
        'submittedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await p.setString(_kPendingApprovalsKey, jsonEncode(_pendingApprovals));
    }
  }

  static Future<void> approvePendingChange(Map<String, dynamic>? owner, String approvalId) async {
    if (!isSovereignOwner(owner)) return;
    final idx = _pendingApprovals.indexWhere((e) => e['id'] == approvalId);
    if (idx == -1) return;
    final item = _pendingApprovals.removeAt(idx);
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_official_banner_${item['menuId']}', (item['newValue'] ?? '').toString());
    await p.setString(_kPendingApprovalsKey, jsonEncode(_pendingApprovals));
  }

  static Future<void> rejectPendingChange(Map<String, dynamic>? owner, String approvalId) async {
    if (!isSovereignOwner(owner)) return;
    _pendingApprovals.removeWhere((e) => e['id'] == approvalId);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPendingApprovalsKey, jsonEncode(_pendingApprovals));
  }

  static bool hasVipOrOwnerAccess(Map<String, dynamic>? user) {
    if (isOwnerOrTeam(user)) return true;
    if (user == null) return false;
    return user['isVip'] == true ||
        user['vipActive'] == true ||
        (user['subscriptionTier'] ?? '').toString().toLowerCase() == 'vip';
  }
}
class HellOfficialMenuBanner extends StatefulWidget {
  final String menuId;
  final Map<String, dynamic>? currentUser;
  final String? customTitle;
  final String? customSubtitle;

  const HellOfficialMenuBanner({
    super.key,
    required this.menuId,
    this.currentUser,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  State<HellOfficialMenuBanner> createState() => _HellOfficialMenuBannerState();
}

class _HellOfficialMenuBannerState extends State<HellOfficialMenuBanner> {
  String _overrideMedia = '';

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    await HellOwnerAndVipPolicy.loadOwnerState();
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _overrideMedia = p.getString('hell_official_banner_${widget.menuId}') ?? '');
    }
  }

  static Map<String, dynamic> _spec(String id) {
    switch (id) {
      case 'control_center':
        return <String, dynamic>{
          'title': 'CENTRO DE CONTROLO HELL CREATOR',
          'subtitle': 'Comando central em tempo real · Estado da live, cenas e sistemas',
          'icon': Icons.dashboard_customize_rounded,
          'colors': <Color>[const Color(0xFF0A193E), const Color(0xFF0284C7), const Color(0xFF040B1E)],
          'accent': const Color(0xFF38BDF8),
          'badge': 'OFICIAL',
        };
      case 'stream_deck':
        return <String, dynamic>{
          'title': 'STREAM DECK HELL PRO',
          'subtitle': 'Botões táteis instantâneos · Cenas, áudio, macros e atalhos',
          'icon': Icons.grid_view_rounded,
          'colors': <Color>[const Color(0xFF1E1B4B), const Color(0xFF4F46E5), const Color(0xFF060B22)],
          'accent': const Color(0xFF818CF8),
          'badge': 'DECK HD',
        };
      case 'automations':
        return <String, dynamic>{
          'title': 'ESTÚDIO DE AUTOMAÇÕES & ALERTAS',
          'subtitle': 'Presentes, TTS, sons, metas e eventos interativos automáticos',
          'icon': Icons.auto_awesome_rounded,
          'colors': <Color>[const Color(0xFF062C43), const Color(0xFF0E7490), const Color(0xFF04091A)],
          'accent': const Color(0xFF22D3EE),
          'badge': 'LIVE FX',
        };
      case 'voice_tts':
        return <String, dynamic>{
          'title': 'CHAT & VOZ TTS INTELIGENTE',
          'subtitle': 'Leitura de chat em tempo real, vozes neurais e filtros anti-spam',
          'icon': Icons.record_voice_over_rounded,
          'colors': <Color>[const Color(0xFF09254A), const Color(0xFF2563EB), const Color(0xFF04091A)],
          'accent': const Color(0xFF60A5FA),
          'badge': 'VOZ IA',
        };
      case 'music':
        return <String, dynamic>{
          'title': 'MÚSICA, RÁDIOS & EFEITOS DE ESTÚDIO',
          'subtitle': 'Rádios 24/7 sem direitos, faixas locais e controlo flutuante',
          'icon': Icons.radio_rounded,
          'colors': <Color>[const Color(0xFF042F2E), const Color(0xFF0D9488), const Color(0xFF04091A)],
          'accent': const Color(0xFF2DD4BF),
          'badge': 'ÁUDIO HD',
        };
      case 'content_factory':
        return <String, dynamic>{
          'title': 'FÁBRICA DE CONTEÚDOS & BANNERS IA',
          'subtitle': 'Criação visual oficial, clips virais e publicação no Marketplace',
          'icon': Icons.auto_fix_high_rounded,
          'colors': <Color>[const Color(0xFF172554), const Color(0xFF0284C7), const Color(0xFF04091A)],
          'accent': const Color(0xFF38BDF8),
          'badge': 'ESTÚDIO IA',
        };
      case 'community':
        return <String, dynamic>{
          'title': 'COMUNIDADE & FEED HELL CREATOR',
          'subtitle': 'Partilha conquistas, parcerias, lives e novidades com criadores',
          'icon': Icons.groups_rounded,
          'colors': <Color>[const Color(0xFF0C2340), const Color(0xFF0369A1), const Color(0xFF04091A)],
          'accent': const Color(0xFF38BDF8),
          'badge': 'COMUNIDADE',
        };
      case 'marketplace':
        return <String, dynamic>{
          'title': 'MARKETPLACE OFICIAL & BANNERS',
          'subtitle': 'Recursos gratuitos da comunidade e criações exclusivas VIP',
          'icon': Icons.storefront_rounded,
          'colors': <Color>[const Color(0xFF1E1B4B), const Color(0xFF0284C7), const Color(0xFF04091A)],
          'accent': const Color(0xFFFBBF24),
          'badge': 'LOJA OFICIAL',
        };
      default:
        return <String, dynamic>{
          'title': 'HELL CREATOR · ESTÚDIO OFICIAL',
          'subtitle': 'Ecossistema profissional para criadores e streamers',
          'icon': Icons.bolt_rounded,
          'colors': <Color>[const Color(0xFF0B1636), const Color(0xFF0284C7), const Color(0xFF04091A)],
          'accent': const Color(0xFF38BDF8),
          'badge': 'HELL PRO',
        };
    }
  }
  Future<bool> _ensureTeamTermsAcceptedBeforeAction() async {
    if (HellOwnerAndVipPolicy.hasTeamAcceptedTerms(widget.currentUser)) return true;
    final scrollCtrl = ScrollController();
    bool reachedEnd = false;
    bool accepted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          scrollCtrl.addListener(() {
            if (scrollCtrl.hasClients &&
                scrollCtrl.position.pixels >= scrollCtrl.position.maxScrollExtent - 24 &&
                !reachedEnd) {
              setM(() => reachedEnd = true);
            }
          });
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1636),
            title: const Text(
              'CONTRATO JURÍDICO OBRIGATÓRIO — EQUIPA HELL CREATOR',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 480,
              height: 310,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Lê integralmente até ao fim para desbloquear a aceitação legal:',
                    style: TextStyle(fontSize: 11.5, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF04091A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollCtrl,
                        child: Text(
                          HellOwnerAndVipPolicy.getLegalTermsText(),
                          style: const TextStyle(fontSize: 12, height: 1.45, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Recusar e Sair')),
              ElevatedButton(
                onPressed: reachedEnd
                    ? () async {
                        await HellOwnerAndVipPolicy.acceptTeamTerms(widget.currentUser);
                        accepted = true;
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    : null,
                child: Text(reachedEnd ? 'Li até ao Fim e Aceito Legalmente' : 'Faz scroll até ao fim...'),
              ),
            ],
          );
        },
      ),
    );
    return accepted;
  }

  Future<void> _openBrandBannerUpdater() async {
    if (!await _ensureTeamTermsAcceptedBeforeAction() || !mounted) return;
    final aiPromptCtrl = TextEditingController();
    final isOwner = HellOwnerAndVipPolicy.isSovereignOwner(widget.currentUser);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1636),
        title: Text(
          isOwner
              ? 'Atualizar Banner Oficial (${widget.menuId})'
              : 'Propor Banner Oficial (Sujeito a Aprovação do Dono)',
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: aiPromptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gerar Tema Oficial com IA (ex: Natal Néon, Halloween, Verão)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: () async {
                      final prompt = aiPromptCtrl.text.trim().isEmpty
                          ? 'HELL CREATOR ${widget.menuId} banner cyberpunk'
                          : aiPromptCtrl.text.trim();
                      final url = 'https://pollinations.ai{Uri.encodeComponent('$prompt, ultra hd 4k, dark neon blue studio banner, no text')}?width=1280&height=360&nologo=true';
                      await HellOwnerAndVipPolicy.submitBannerChange(
                        actor: widget.currentUser,
                        menuId: widget.menuId,
                        newValue: url,
                        description: 'Banner IA Oficial: $prompt',
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadBanner();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isOwner
                                  ? 'Banner oficial atualizado de imediato!'
                                  : 'Proposta enviada para aprovação do Proprietário Soberano!',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Gerar Banner IA', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final r = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
                      );
                      final path = r?.files.single.path;
                      if (path != null && path.isNotEmpty) {
                        await HellOwnerAndVipPolicy.submitBannerChange(
                          actor: widget.currentUser,
                          menuId: widget.menuId,
                          newValue: path,
                          description: 'Upload de Banner Oficial (${widget.menuId})',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadBanner();
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Carregar Imagem', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await HellOwnerAndVipPolicy.submitBannerChange(
                        actor: widget.currentUser,
                        menuId: widget.menuId,
                        newValue: '',
                        description: 'Repor Banner Oficial Padrão',
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadBanner();
                    },
                    child: const Text('Repor Original', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final s = _spec(widget.menuId);
    final colors = s['colors'] as List<Color>;
    final accent = s['accent'] as Color;
    final canEdit = HellOwnerAndVipPolicy.isOwnerOrTeam(widget.currentUser) && HellOwnerAndVipPolicy.isDevModeActive();

    DecorationImage? bgImg;
    if (_overrideMedia.startsWith('http')) {
      bgImg = DecorationImage(
        image: NetworkImage(_overrideMedia),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
      );
    } else if (_overrideMedia.isNotEmpty && File(_overrideMedia).existsSync()) {
      bgImg = DecorationImage(
        image: FileImage(File(_overrideMedia)),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: bgImg == null ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        image: bgImg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.3),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.5)),
            ),
            child: Icon(s['icon'] as IconData, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: accent.withOpacity(0.22), borderRadius: BorderRadius.circular(5)),
                      child: Text(s['badge'].toString(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: accent)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.customTitle ?? s['title'].toString(),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.customSubtitle ?? s['subtitle'].toString(),
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Atualizar Banner Oficial (Modo Desenvolvedor)',
              icon: const Icon(Icons.brush_rounded, color: Colors.amberAccent, size: 20),
              onPressed: _openBrandBannerUpdater,
            ),
        ],
      ),
    );
  }
}

class HellCommunityBannersRepository {
  static const String _kBannersKey = 'hell_marketplace_ai_banners_v1';

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kBannersKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveAll(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBannersKey, jsonEncode(list));
  }
}
class HellAiBannerMarketplaceStudio extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const HellAiBannerMarketplaceStudio({super.key, this.currentUser});

  @override
  State<HellAiBannerMarketplaceStudio> createState() => _HellAiBannerMarketplaceStudioState();
}

class _HellAiBannerMarketplaceStudioState extends State<HellAiBannerMarketplaceStudio> {
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController(text: '0');
  bool _isPrivate = false;
  bool _isForSale = false;
  List<Map<String, dynamic>> _banners = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await HellOwnerAndVipPolicy.loadOwnerState();
    final items = await HellCommunityBannersRepository.loadAll();
    if (mounted) setState(() => _banners = items);
  }

  Future<void> _generateAndPublishBanner() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descreve primeiro o banner que queres criar com IA.')),
      );
      return;
    }
    final isVip = HellOwnerAndVipPolicy.hasVipOrOwnerAccess(widget.currentUser);
    final bool finalPrivate = isVip ? _isPrivate : false;
    final bool finalForSale = isVip ? _isForSale : false;
    final double price = finalForSale ? (double.tryParse(_priceCtrl.text.trim()) ?? 5.0) : 0.0;

    final imageUrl =
      final imageUrl = 'https://pollinations.ai{Uri.encodeComponent("$prompt, gaming streamer banner ultra hd 4k, clean neon art, no watermark")}?width=1280&height=420&nologo=true';


    final item = <String, dynamic>{
      'id': 'bnr_${DateTime.now().millisecondsSinceEpoch}',
      'title': _titleCtrl.text.trim().isEmpty ? prompt : _titleCtrl.text.trim(),
      'prompt': prompt,
      'imageUrl': imageUrl,
      'authorEmail': (widget.currentUser?['email'] ?? 'criador@hellcreator.app').toString(),
      'authorName': (widget.currentUser?['displayName'] ?? 'Criador HELL').toString(),
      'isPrivate': finalPrivate,
      'isForSale': finalForSale,
      'price': price,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    _banners.insert(0, item);
    await HellCommunityBannersRepository.saveAll(_banners);
    _promptCtrl.clear();
    _titleCtrl.clear();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            finalPrivate
                ? 'Banner IA criado e guardado como Privado (VIP)!'
                : finalForSale
                    ? 'Banner IA publicado à venda no Marketplace (€${price.toStringAsFixed(2)})!'
                    : 'Banner IA gerado e publicado gratuitamente para toda a comunidade no Marketplace!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVip = HellOwnerAndVipPolicy.hasVipOrOwnerAccess(widget.currentUser);
    final isOwner = HellOwnerAndVipPolicy.isSovereignOwner(widget.currentUser);
    final myEmail = (widget.currentUser?['email'] ?? '').toString().trim().toLowerCase();

    final visibleBanners = _banners.where((b) {
      final priv = b['isPrivate'] == true;
      final author = (b['authorEmail'] ?? '').toString().trim().toLowerCase();
      return !priv || author == myEmail || isOwner;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GERADOR DE BANNERS IA · PUBLICAÇÃO AUTOMÁTICA NO MARKETPLACE',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF38BDF8)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isVip ? Colors.amber.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOwner ? '👑 DONO SOBERANO' : isVip ? '👑 MEMBRO VIP' : 'CONTA GRATUITA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: isVip ? Colors.amberAccent : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Título do Banner (ex: Overlay Cyberpunk Azul)', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descreve o Banner para a IA gerar (ex: dragão neon azul e roxo 4k)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.amberAccent,
                title: Row(
                  children: <Widget>[
                    const Text('Manter Banner Privado (Só para mim)', style: TextStyle(fontSize: 12.5)),
                    const SizedBox(width: 6),
                    if (!isVip)
                      const Text('👑 Exclusivo VIP', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                value: isVip ? _isPrivate : false,
                onChanged: (v) {
                  if (!isVip) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tornar banners privados é exclusivo para Membros VIP Assinantes.')),
                    );
                    return;
                  }
                  setState(() {
                    _isPrivate = v;
                    if (v) _isForSale = false;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.greenAccent,
                title: Row(
                  children: <Widget>[
                    const Text('Colocar à Venda no Marketplace', style: TextStyle(fontSize: 12.5)),
                    const SizedBox(width: 6),
                    if (!isVip)
                      const Text('👑 Exclusivo VIP', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                value: isVip ? _isForSale : false,
                onChanged: (v) {
                  if (!isVip) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vender banners no Marketplace é exclusivo para Membros VIP Assinantes.')),
                    );
                    return;
                  }
                  setState(() {
                    _isForSale = v;
                    if (v) _isPrivate = false;
                  });
                },
              ),
              if (isVip && _isForSale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Preço de Venda (€)', isDense: true),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateAndPublishBanner,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    isVip && _isPrivate
                        ? 'Gerar Banner IA Privado'
                        : isVip && _isForSale
                            ? 'Gerar e Colocar à Venda'
                            : 'Gerar Banner IA & Publicar Grátis no Marketplace',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'BANNERS DA COMUNIDADE & VIP (${visibleBanners.length})',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF38BDF8)),
        ),
        const SizedBox(height: 8),
        ...visibleBanners.map((b) {
          final forSale = b['isForSale'] == true;
          final priv = b['isPrivate'] == true;
          final price = (b['price'] is num) ? (b['price'] as num).toDouble() : 0.0;
          final url = (b['imageUrl'] ?? '').toString();
          return Card(
            color: const Color(0xFF0B1636),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: forSale ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFF38BDF8).withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (url.startsWith('http'))
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(url, height: 110, width: double.infinity, fit: BoxFit.cover),
                  ),
                ListTile(
                  title: Text((b['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    'Por ${b['authorName']} · ${priv ? 'Privado (VIP)' : forSale ? 'À Venda: €${price.toStringAsFixed(2)}' : 'Grátis para toda a comunidade'}',
                    style: TextStyle(fontSize: 11.5, color: forSale ? Colors.amberAccent : Colors.greenAccent),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Copiar Link do Banner',
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF38BDF8)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link do banner copiado!')),
                          );
                        },
                      ),
                      if (isOwner)
                        IconButton(
                          tooltip: 'Moderação Dono: Remover Banner',
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () async {
                            _banners.removeWhere((x) => x['id'] == b['id']);
                            await HellCommunityBannersRepository.saveAll(_banners);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
class HellGovernanceAndDevPanel extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final VoidCallback? onStateChanged;

  const HellGovernanceAndDevPanel({
    super.key,
    this.currentUser,
    this.onStateChanged,
  });

  @override
  State<HellGovernanceAndDevPanel> createState() => _HellGovernanceAndDevPanelState();
}

class _HellGovernanceAndDevPanelState extends State<HellGovernanceAndDevPanel> {
  final TextEditingController _teamEmailCtrl = TextEditingController();
  final TextEditingController _teamRoleCtrl = TextEditingController();
  final TextEditingController _successorEmailCtrl = TextEditingController();
  final TextEditingController _successorNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await HellOwnerAndVipPolicy.loadOwnerState();
    if (mounted) setState(() {});
  }

  Future<void> _openLegalRemovalDialog({
    required String targetEmail,
    required bool isRemovingCoOwner,
  }) async {
    final scrollCtrl = ScrollController();
    final justCtrl = TextEditingController();
    String selectedGround = 'Sucessão / Renúncia expressa do titular';
    bool scrolledToBottom = false;

    final grounds = <String>[
      'Sucessão / Renúncia expressa do titular',
      'Inatividade prolongada / Falecimento',
      'Violação grave de segurança ou confidencialidade (NDA)',
      'Abandono de funções ou incumprimento contratual',
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          scrollCtrl.addListener(() {
            if (scrollCtrl.hasClients &&
                scrollCtrl.position.pixels >= scrollCtrl.position.maxScrollExtent - 20 &&
                !scrolledToBottom) {
              setM(() => scrolledToBottom = true);
            }
          });
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1636),
            title: Text(
              isRemovingCoOwner
                  ? 'PROTOCOLO JURÍDICO · REMOVER CO-PROPRIETÁRIO ($targetEmail)'
                  : 'PROTOCOLO JURÍDICO · REMOVER MEMBRO DA EQUIPA ($targetEmail)',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF04091A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollCtrl,
                        child: const Text(
                          HellOwnerAndVipPolicy.removalLegalDeclarationText,
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedGround,
                      dropdownColor: const Color(0xFF0B1636),
                      decoration: const InputDecoration(labelText: 'Fundamento Legal Obrigatório', isDense: true),
                      items: grounds.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setM(() => selectedGround = v ?? selectedGround),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: justCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ata / Justificação Jurídica Detalhada (mín. 25 caracteres)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: scrolledToBottom
                    ? () async {
                        final err = isRemovingCoOwner
                            ? await HellOwnerAndVipPolicy.removeSovereignOwnerWithLegalProtocol(
                                actor: widget.currentUser,
                                targetEmail: targetEmail,
                                legalGround: selectedGround,
                                justification: justCtrl.text,
                              )
                            : await HellOwnerAndVipPolicy.removeTeamMemberWithLegalProtocol(
                                actor: widget.currentUser,
                                targetEmail: targetEmail,
                                legalGround: selectedGround,
                                justification: justCtrl.text,
                              );
                        if (!mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                        widget.onStateChanged?.call();
                      }
                    : null,
                child: Text(scrolledToBottom ? 'Assinar e Executar Remoção' : 'Lê a declaração até ao fim...'),
              ),
            ],
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isOwner = HellOwnerAndVipPolicy.isSovereignOwner(widget.currentUser);
    final isTeamOrOwner = HellOwnerAndVipPolicy.isOwnerOrTeam(widget.currentUser);
    if (!isTeamOrOwner) return const SizedBox.shrink();

    final owners = HellOwnerAndVipPolicy.getSovereignPersonalOwners();
    final team = HellOwnerAndVipPolicy.getTeamEmails();
    final pending = HellOwnerAndVipPolicy.getPendingApprovals();
    final audit = HellOwnerAndVipPolicy.getGovernanceAuditLog();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1636),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GOVERNANÇA SOBERANA, EQUIPA & MODO DESENVOLVEDOR',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.amberAccent),
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () async {
                    final ctrl = TextEditingController(text: HellOwnerAndVipPolicy.getLegalTermsText());
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0B1636),
                        title: const Text('Editar Contrato Jurídico da Equipa (Exclusivo Dono)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14)),
                        content: SizedBox(width: 500, child: TextField(controller: ctrl, maxLines: 14, style: const TextStyle(fontSize: 12))),
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                          ElevatedButton(
                            onPressed: () async {
                              await HellOwnerAndVipPolicy.updateLegalTermsByOwner(widget.currentUser, ctrl.text);
                              if (ctx.mounted) Navigator.pop(ctx);
                              setState(() {});
                            },
                            child: const Text('Guardar Contrato'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.gavel_rounded, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Editar Termos', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.amberAccent,
            title: const Text('Modo Desenvolvedor / Editor Visual da Marca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text('Ativa o botão de atualização nos banners oficiais dos menus (exclusivo Dono & Equipa)', style: TextStyle(fontSize: 11)),
            value: HellOwnerAndVipPolicy.isDevModeActive(),
            onChanged: (v) async {
              await HellOwnerAndVipPolicy.setDevModeActive(v);
              setState(() {});
              widget.onStateChanged?.call();
            },
          ),
          if (isOwner && pending.isNotEmpty) ...<Widget>[
            const Divider(),
            Text('ALTERAÇÕES DA EQUIPA A AGUARDAR APROVAÇÃO (${pending.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.orangeAccent)),
            ...pending.map((item) => Card(
                  color: const Color(0xFF04091A),
                  child: ListTile(
                    title: Text('${item['description']} (${item['menuId']})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    subtitle: Text('Submetido por: ${item['submittedBy']} · ${item['submittedAt']}', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Aprovar e Publicar',
                          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                          onPressed: () async {
                            await HellOwnerAndVipPolicy.approvePendingChange(widget.currentUser, item['id'].toString());
                            setState(() {});
                            widget.onStateChanged?.call();
                          },
                        ),
                        IconButton(
                          tooltip: 'Rejeitar',
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () async {
                            await HellOwnerAndVipPolicy.rejectPendingChange(widget.currentUser, item['id'].toString());
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          if (isOwner) ...<Widget>[
            const Divider(),
            const Text('PROPRIETÁRIOS SOBERANOS & SUCESSÃO FAMILIAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF38BDF8))),
            const ListTile(
              dense: true,
              leading: Icon(Icons.verified_user, color: Colors.amberAccent, size: 18),
              title: Text('${HellOwnerAndVipPolicy.supremeBrandEmail} (Conta Mestra Suprema · Intocável)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ...owners.map((e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.shield, color: Color(0xFF38BDF8), size: 18),
                  title: Text(e, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Remover sob Protocolo Jurídico',
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => _openLegalRemovalDialog(targetEmail: e, isRemovingCoOwner: true),
                  ),
                )),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _successorEmailCtrl, decoration: const InputDecoration(labelText: 'Novo E-mail Sucessor / Co-Proprietário', isDense: true))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _successorNoteCtrl, decoration: const InputDecoration(labelText: 'Nota (ex: Herdeiro / Filho)', isDense: true))),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.greenAccent),
                  onPressed: () async {
                    final err = await HellOwnerAndVipPolicy.addSovereignSuccessorOwner(
                      actor: widget.currentUser,
                      newOwnerEmail: _successorEmailCtrl.text,
                      relationOrNote: _successorNoteCtrl.text,
                    );
                    if (!mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else {
                      _successorEmailCtrl.clear();
                      _successorNoteCtrl.clear();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            const Text('EQUIPA DE DESENVOLVEDORES & GERENTES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF38BDF8))),
            ...team.map((e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.engineering, color: Colors.white70, size: 18),
                  title: Text(e, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Revogar Acesso sob Protocolo Jurídico',
                    icon: const Icon(Icons.person_remove, color: Colors.redAccent, size: 18),
                    onPressed: () => _openLegalRemovalDialog(targetEmail: e, isRemovingCoOwner: false),
                  ),
                )),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _teamEmailCtrl, decoration: const InputDecoration(labelText: 'E-mail do Membro da Equipa', isDense: true))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _teamRoleCtrl, decoration: const InputDecoration(labelText: 'Função (ex: Dev Flutter / Designer)', isDense: true))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                  onPressed: () async {
                    final err = await HellOwnerAndVipPolicy.addTeamEmail(widget.currentUser, _teamEmailCtrl.text, _teamRoleCtrl.text);
                    if (!mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else {
                      _teamEmailCtrl.clear();
                      _teamRoleCtrl.clear();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ],
          const Divider(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Termos Legais & Acordo de Equipa (Afixados)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF04091A), borderRadius: BorderRadius.circular(8)),
                child: Text(HellOwnerAndVipPolicy.getLegalTermsText(), style: const TextStyle(fontSize: 11.5, height: 1.4)),
              ),
              if (audit.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text('Registo de Auditoria Jurídica:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                ...audit.take(10).map((a) => ListTile(
                      dense: true,
                      title: Text('${a['action']} → ${a['targetEmail']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      subtitle: Text('Por ${a['actorEmail']} · ${a['legalGround']}\n${a['justification']} (${a['at']})', style: const TextStyle(fontSize: 10.5)),
                    )),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
class HellSeasonalAppIconStudio extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const HellSeasonalAppIconStudio({super.key, this.currentUser});

  @override
  State<HellSeasonalAppIconStudio> createState() => _HellSeasonalAppIconStudioState();
}

class _HellSeasonalAppIconStudioState extends State<HellSeasonalAppIconStudio> {
  final TextEditingController _seasonCtrl = TextEditingController(text: 'Edição Oficial Natal');
  final TextEditingController _ghTokenCtrl = TextEditingController();
  String _selectedIconPath = '';
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedIconPath = p.getString('hell_active_seasonal_icon_path') ?? '';
        _ghTokenCtrl.text = p.getString('hell_owner_github_pat_token') ?? '';
      });
    }
  }

  Future<void> _pickIconFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['png', 'jpg', 'jpeg', 'webp'],
    );
    final path = r?.files.single.path;
    if (path != null && path.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString('hell_active_seasonal_icon_path', path);
      if (mounted) setState(() => _selectedIconPath = path);
    }
  }

  Future<void> _publishIconToAppAndGithub() async {
    if (!HellOwnerAndVipPolicy.isSovereignOwner(widget.currentUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apenas Proprietários Soberanos podem publicar o ícone oficial da app.')),
      );
      return;
    }
    if (_selectedIconPath.isEmpty || !File(_selectedIconPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe primeiro a imagem do novo ícone sazonal (PNG 1024x1024).')),
      );
      return;
    }

    setState(() => _publishing = true);
    final p = await SharedPreferences.getInstance();
    await p.setString('hell_active_seasonal_icon_path', _selectedIconPath);
    final token = _ghTokenCtrl.text.trim();
    if (token.isNotEmpty) {
      await p.setString('hell_owner_github_pat_token', token);
    }

    if (token.isEmpty) {
      setState(() => _publishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ícone atualizado dentro da app! Cola o Token GitHub para enviar também para Android/Windows.')),
        );
      }
      return;
    }

    try {
      final bytes = await File(_selectedIconPath).readAsBytes();
      final b64Content = base64Encode(bytes);
      const apiUrl = 'https://github.com';

      final client = HttpClient();
      final getReq = await client.getUrl(Uri.parse(apiUrl));
      getReq.headers.set('Authorization', 'Bearer $token');
      getReq.headers.set('Accept', 'application/vnd.github+json');
      getReq.headers.set('User-Agent', 'HELL-CREATOR-APP');
      final getRes = await getReq.close();
      final getBody = await getRes.transform(utf8.decoder).join();
      final currentSha = (jsonDecode(getBody) as Map)['sha']?.toString() ?? '';

      final putReq = await client.putUrl(Uri.parse(apiUrl));
      putReq.headers.set('Authorization', 'Bearer $token');
      putReq.headers.set('Accept', 'application/vnd.github+json');
      putReq.headers.set('User-Agent', 'HELL-CREATOR-APP');
      putReq.headers.set('Content-Type', 'application/json');
      putReq.write(jsonEncode(<String, dynamic>{
        'message': 'Atualizar icon.png oficial (${_seasonCtrl.text.trim()})',
        'content': b64Content,
        if (currentSha.isNotEmpty) 'sha': currentSha,
      }));
      final putRes = await putReq.close();
      client.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              putRes.statusCode == 200 || putRes.statusCode == 201
                  ? 'Ícone oficial atualizado dentro da app e enviado ao GitHub (Android & Windows a compilar)!'
                  : 'Ícone atualizado na app, mas o GitHub devolveu código ${putRes.statusCode}. Verifica o token.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ícone aplicado dentro da app. Erro de ligação GitHub: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!HellOwnerAndVipPolicy.isSovereignOwner(widget.currentUser) || !HellOwnerAndVipPolicy.isDevModeActive()) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF04091A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ESTÚDIO DE ÍCONE OFICIAL SAZONAL (NATAL / ANIVERSÁRIO / EVENTOS)',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (_selectedIconPath.isNotEmpty && File(_selectedIconPath).existsSync())
                    ? Image.file(File(_selectedIconPath), width: 54, height: 54, fit: BoxFit.cover)
                    : Image.asset('icon.png', width: 54, height: 54, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _seasonCtrl,
                      decoration: const InputDecoration(labelText: 'Nome da Edição (ex: Natal 2026, Aniversário)', isDense: true),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ghTokenCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'GitHub Token (1 toque para Android & Windows)', isDense: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _pickIconFile,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Escolher Ícone', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _publishing ? null : _publishIconToAppAndGithub,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                  label: Text(_publishing ? 'A publicar...' : 'Atualizar Ícone Dentro & Fora da App', style: const TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
