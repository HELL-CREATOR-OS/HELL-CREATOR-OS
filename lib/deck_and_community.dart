import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';
import 'account_security.dart';
import 'live_connectors.dart';

class MarketplaceStore {
  static final List<Map<String, dynamic>> items = [
    {
      'id': 'mp_ov1',
      'title': 'Overlay 3D Cyber Arena HUD',
      'creator': '@HELL_Studio',
      'category': 'Overlays 3D',
      'netPrice': 0.0,
      'desc': 'Overlay transparente Browser Source com brilho néon para OBS, Streamlabs e TikTok Live Studio.',
      'owned': true,
    },
    {
      'id': 'mp_bn1',
      'title': 'Banner Perfil Ultra Néon (Estático & GIF)',
      'creator': '@HELL_Studio',
      'category': 'Banners',
      'netPrice': 4.00,
      'desc': 'Banner animado em alta definição para destacar o teu perfil e Cartão Bio HELL.',
      'owned': false,
    },
    {
      'id': 'mp_sn1',
      'title': 'Pack 40 Sons Épicos de Alerta & Vitória',
      'creator': '@HELL_Studio',
      'category': 'Packs de Sons',
      'netPrice': 3.00,
      'desc': 'Efeitos sonoros cristalinos prontos a aplicar em presentes, seguidores e doações.',
      'owned': false,
    },
    {
      'id': 'mp_em1',
      'title': 'Pack Emojis Exclusivos Clube de Fãs HELL',
      'creator': '@HELL_Studio',
      'category': 'Emojis & Clube',
      'netPrice': 2.50,
      'desc': 'Emblemas e emojis personalizados para os membros do teu clube de fãs usarem no chat.',
      'owned': false,
    },
    {
      'id': 'mp_mr1',
      'title': 'Camisola Oficial Gaming HELL Live Pro',
      'creator': '@HELL_Oficial',
      'category': 'Merch Gaming',
      'netPrice': 19.00,
      'desc': 'T-shirt técnica respirável com estampa oficial HELL Live para streams e eventos.',
      'owned': false,
    },
    {
      'id': 'mp_mr2',
      'title': 'Caneca Térmica + Caneta Metálica Streamer',
      'creator': '@HELL_Oficial',
      'category': 'Merch Gaming',
      'netPrice': 11.00,
      'desc': 'Kit de secretária oficial HELL Live para acompanhar as tuas maratonas em direto.',
      'owned': false,
    },
  ];
}
class StreamDeckProScreen extends StatefulWidget {
  final Function(String cmd) onExecuteAction;
  const StreamDeckProScreen({super.key, required this.onExecuteAction});

  @override
  State<StreamDeckProScreen> createState() => _StreamDeckProScreenState();
}

class _StreamDeckProScreenState extends State<StreamDeckProScreen> {
  String _bgMode = 'icon';
  final List<Map<String, dynamic>> _keys = [
    {'label': 'Silenciar Voz', 'cmd': 'mute_all', 'icon': Icons.volume_off},
    {'label': 'Voz Grave Épica', 'cmd': 'mod_deep', 'icon': Icons.record_voice_over},
    {'label': 'Voz Robô', 'cmd': 'mod_robot', 'icon': Icons.smart_toy},
    {'label': 'Voz Normal', 'cmd': 'mod_normal', 'icon': Icons.mic},
    {'label': 'Girar Roleta 3D', 'cmd': 'spin_wheel', 'icon': Icons.casino},
    {'label': 'Aplausos Arena', 'cmd': 'sound_clap', 'icon': Icons.celebration},
    {'label': 'Buzina Épica', 'cmd': 'sound_horn', 'icon': Icons.campaign},
    {'label': 'Música Play/Pausa', 'cmd': 'music_toggle', 'icon': Icons.music_note},
    {'label': 'Música Seguinte', 'cmd': 'music_next', 'icon': Icons.skip_next},
    {'label': 'Créditos Fim Live', 'cmd': 'credits_roll', 'icon': Icons.movie_filter},
    {'label': 'Testar Alerta', 'cmd': 'test_alert', 'icon': Icons.notifications_active},
    {'label': 'Copiar Link OBS', 'cmd': 'copy_obs', 'icon': Icons.layers},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              const Expanded(child: Text('🎛️ Stream Deck Pro 3D', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
              ChoiceChip(label: const Text('Ícone H', style: TextStyle(fontSize: 11)), selected: _bgMode == 'icon', onSelected: (_) => setState(() => _bgMode = 'icon')),
              const SizedBox(width: 6),
              ChoiceChip(label: const Text('HELL Live', style: TextStyle(fontSize: 11)), selected: _bgMode == 'brand', onSelected: (_) => setState(() => _bgMode = 'brand')),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.22,
                child: _bgMode == 'icon'
                    ? Image.asset('icon.png', width: 220, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 160, color: Color(0xFF38BDF8)))
                    : const Text('HELL LIVE', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFF38BDF8))),
              ),
              GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _keys.length,
                itemBuilder: (_, i) {
                  final k = _keys[i];
                  return GestureDetector(
                    onTap: () => widget.onExecuteAction(k['cmd']),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white.withOpacity(0.16), const Color(0xFF0C1B44).withOpacity(0.75)],
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.4),
                        boxShadow: [BoxShadow(color: const Color(0xFF1E78FF).withOpacity(0.25), blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(k['icon'], color: const Color(0xFF38BDF8), size: 30),
                          const SizedBox(height: 6),
                          Text(k['label'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class CommunityGlobeScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const CommunityGlobeScreen({super.key, required this.currentUser});

  @override
  State<CommunityGlobeScreen> createState() => _CommunityGlobeScreenState();
}

class _CommunityGlobeScreenState extends State<CommunityGlobeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotCtrl;
  String _featuredCreator = '@HELL_Gamer';
  final _featureCtrl = TextEditingController();

  final List<Map<String, dynamic>> _liveNodes = [
    {'user': '@HELL_Gamer', 'platform': 'TikTok', 'viewers': 1420, 'lat': 0.25, 'lonOffset': 0.0, 'avatar': 'https://jsdelivr.net'},
    {'user': '@LunaStreamPT', 'platform': 'Twitch', 'viewers': 860, 'lat': -0.15, 'lonOffset': 1.2, 'avatar': 'https://jsdelivr.net'},
    {'user': '@KikoArenaBR', 'platform': 'YouTube', 'viewers': 2310, 'lat': 0.35, 'lonOffset': 2.5, 'avatar': 'https://jsdelivr.net'},
    {'user': '@VortexKick', 'platform': 'Kick', 'viewers': 640, 'lat': -0.30, 'lonOffset': 4.1, 'avatar': 'https://jsdelivr.net'},
    {'user': '@NovaQueen', 'platform': 'TikTok', 'viewers': 1190, 'lat': 0.10, 'lonOffset': 5.2, 'avatar': 'https://jsdelivr.net'},
  ];

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = DefaultMediaLibrary.isOwnerEmail(widget.currentUser['email']);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050B1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E78FF), width: 1.4),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🌍 Globo Terrestre Real · Ao Vivo', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF38BDF8), fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFACC15))),
                    child: Text('⭐ Destaque: $_featuredCreator', style: const TextStyle(color: Color(0xFFFACC15), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: _rotCtrl,
                  builder: (_, __) {
                    final angle = _rotCtrl.value * 2 * pi;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.45), blurRadius: 28, spreadRadius: 4)],
                          ),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FractionalTranslation(
                                  translation: Offset((_rotCtrl.value * 2) - 1.0, 0),
                                  child: Image.network(
                                    'https://wikimedia.org',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A2E5C)),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: const Alignment(-0.35, -0.35),
                                      radius: 0.95,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.68)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._liveNodes.map((node) {
                          final lon = angle + (node['lonOffset'] as double);
                          final visible = cos(lon) > -0.15;
                          if (!visible) return const SizedBox.shrink();
                          final dx = 92 * sin(lon);
                          final dy = 88 * (node['lat'] as double);
                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF00F2EA), width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 6)],
                                  ),
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: const Color(0xFF0B1636),
                                    backgroundImage: NetworkImage(node['avatar']),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                                  child: Text(node['user'], style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _featureCtrl, decoration: const InputDecoration(hintText: 'Fixar @Criador Recomendado no Globo...', isDense: true))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15)),
                      onPressed: () {
                        if (_featureCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _featuredCreator = _featureCtrl.text.trim();
                            _featureCtrl.clear();
                          });
                        }
                      },
                      child: const Text('Destacar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('📡 Canais em Direto na Rede HELL Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8))),
        const SizedBox(height: 8),
        ..._liveNodes.map((n) => Card(
              color: const Color(0xFF0B1636),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(n['avatar'])),
                title: Text(n['user'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Em direto no ${n['platform']}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: Text('🔴 ${n['viewers']}'),
                ),
              ),
            )),
      ],
    );
  }
}
class LojaHellScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const LojaHellScreen({super.key, required this.currentUser});

  @override
  State<LojaHellScreen> createState() => _LojaHellScreenState();
}

class _LojaHellScreenState extends State<LojaHellScreen> {
  String _selectedCat = 'Todos';

  @override
  Widget build(BuildContext context) {
    final isOwner = DefaultMediaLibrary.isOwnerEmail(widget.currentUser['email']);
    const categories = ['Todos', 'Overlays 3D', 'Banners', 'Packs de Sons', 'Emojis & Clube', 'Merch Gaming'];
    final filtered = MarketplaceStore.items.where((it) => _selectedCat == 'Todos' || it['category'] == _selectedCat).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF122E73), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOwner ? const Color(0xFFFACC15) : const Color(0xFF38BDF8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('🛍️ Loja Oficial HELL Live', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)))),
                  if (isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('👑 ACESSO LIVRE DONO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Overlays 3D, Banners, Packs de Sons, Emojis do Clube de Fãs e Merchandising Gaming & Streaming.', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles();
                  if (res != null && mounted) {
                    setState(() {
                      MarketplaceStore.items.insert(0, {
                        'id': 'ext_${DateTime.now().millisecondsSinceEpoch}',
                        'title': 'Overlay Externo: ${res.files.single.name}',
                        'creator': 'Importado Localmente',
                        'category': 'Overlays 3D',
                        'netPrice': 0.0,
                        'desc': 'Overlay de terceiros instalado diretamente a partir do teu dispositivo.',
                        'owned': true,
                      });
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overlay externo instalado na tua biblioteca!'), backgroundColor: Colors.green));
                  }
                },
                icon: const Icon(Icons.download_for_offline, color: Color(0xFF38BDF8)),
                label: const Text('Instalar Overlay Baixado do Equipamento', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((c) {
              final sel = _selectedCat == c;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11.5)),
                  selected: sel,
                  selectedColor: const Color(0xFF1E78FF),
                  onSelected: (_) => setState(() => _selectedCat = c),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        ...filtered.map((item) {
          final double net = (item['netPrice'] as num).toDouble();
          final double finalPrice = isOwner ? 0.0 : (net == 0 ? 0.0 : net * 1.30);
          final bool owned = item['owned'] == true || isOwner || finalPrice == 0.0;

          return Card(
            color: const Color(0xFF0B1636),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF122E73), borderRadius: BorderRadius.circular(8)),
                        child: Text(item['category'], style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8))),
                      ),
                    ],
                  ),
                  Text('Criador: ${item['creator']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 6),
                  Text(item['desc'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOwner ? 'GRÁTIS (Dono)' : (finalPrice == 0 ? 'GRATUITO' : '${finalPrice.toStringAsFixed(2)} € (IVA/Taxa inc.)'),
                        style: TextStyle(fontWeight: FontWeight.w900, color: owned ? Colors.greenAccent : const Color(0xFFFACC15)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: owned ? Colors.green : const Color(0xFF1E78FF)),
                        onPressed: () {
                          setState(() => item['owned'] = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(owned ? 'Ativo na tua conta HELL Live!' : 'Compra concluída com sucesso!')),
                          );
                        },
                        child: Text(owned ? 'Usar / Baixar' : 'Comprar Agora', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
class EstudioVipHellScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Function(Map<String, dynamic>) onUserUpdated;

  const EstudioVipHellScreen({
    super.key,
    required this.currentUser,
    required this.onUserUpdated,
  });

  @override
  State<EstudioVipHellScreen> createState() => _EstudioVipHellScreenState();
}

class _EstudioVipHellScreenState extends State<EstudioVipHellScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _netPriceCtrl = TextEditingController(text: '5.00');
  final _redeemCtrl = TextEditingController();
  String _category = 'Overlays 3D';
  String? _attachedFileName;

  bool _hasActiveVip() {
    if (DefaultMediaLibrary.isOwnerEmail(widget.currentUser['email'])) return true;
    if (widget.currentUser['isVip'] == true) return true;
    final trialIso = widget.currentUser['vipTrialExpires']?.toString();
    if (trialIso != null && trialIso.isNotEmpty) {
      final exp = DateTime.tryParse(trialIso);
      if (exp != null && exp.isAfter(DateTime.now())) return true;
    }
    return false;
  }

  Future<void> _activate3DayTrial() async {
    final updated = Map<String, dynamic>.from(widget.currentUser);
    updated['vipTrialExpires'] = DateTime.now().add(const Duration(days: 3)).toIso8601String();
    updated['vipTrialUsed'] = true;
    await UserAccountManager.registerOrUpdateAccount(updated);
    widget.onUserUpdated(updated);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Teste Grátis de 3 Dias VIP ativado! Aproveita todas as ferramentas!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = DefaultMediaLibrary.isOwnerEmail(widget.currentUser['email']);
    final hasVip = _hasActiveVip();
    final trialUsed = widget.currentUser['vipTrialUsed'] == true;
    final netVal = double.tryParse(_netPriceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final finalBuyerPrice = netVal * 1.30;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A103C), Color(0xFF08112B)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('👑 Estúdio VIP HELL Live', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFACC15)))),
                  if (hasVip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                      child: Text(isOwner ? 'DONO ILIMITADO' : 'VIP ATIVO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cria e publica Overlays 3D, Banners animados, Packs de Sons, Emojis de Clube de Fãs e Merchandising para multiplataformas.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (!hasVip) ...[
                const SizedBox(height: 12),
                if (!trialUsed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _activate3DayTrial,
                      icon: const Icon(Icons.star, color: Colors.black),
                      label: const Text('Experimentar Estúdio VIP Grátis por 3 Dias', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _redeemCtrl, decoration: const InputDecoration(hintText: 'Tens uma Chave VIP / Parceiro?', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF)),
                      onPressed: () async {
                        final ok = await UserAccountManager.redeemVipCode(_redeemCtrl.text, widget.currentUser);
                        if (ok) {
                          widget.onUserUpdated(widget.currentUser);
                          setState(() {});
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave VIP validada com sucesso!'), backgroundColor: Colors.green));
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave VIP inválida.'), backgroundColor: Colors.redAccent));
                        }
                      },
                      child: const Text('Ativar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (hasVip) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF0B1636), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF38BDF8))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🛠️ Publicar Nova Criação na Loja HELL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 14)),
                const SizedBox(height: 10),
                TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Título do Pack / Produto', isDense: true)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Categoria', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Overlays 3D', child: Text('Overlays 3D')),
                    DropdownMenuItem(value: 'Banners', child: Text('Banners (Estático / GIF)')),
                    DropdownMenuItem(value: 'Packs de Sons', child: Text('Packs de Sons')),
                    DropdownMenuItem(value: 'Emojis & Clube', child: Text('Emojis & Clube de Fãs')),
                    DropdownMenuItem(value: 'Merch Gaming', child: Text('Merch Gaming & Streaming')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'Overlays 3D'),
                ),
                const SizedBox(height: 8),
                TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição detalhada', isDense: true)),
                const SizedBox(height: 8),
                TextField(
                  controller: _netPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'O Teu Valor Líquido (€) — 0 para Grátis', isDense: true),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recebes líquido: ${netVal.toStringAsFixed(2)} €  |  Preço Loja (+30%): ${finalBuyerPrice.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles();
                    if (res != null) setState(() => _attachedFileName = res.files.single.name);
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(_attachedFileName ?? 'Anexar Ficheiros (PNG, GIF, MP3, ZIP)'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E78FF), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    if (_titleCtrl.text.trim().isEmpty) return;
                    MarketplaceStore.items.insert(0, {
                      'id': 'mp_${DateTime.now().millisecondsSinceEpoch}',
                      'title': _titleCtrl.text.trim(),
                      'creator': '@${widget.currentUser['nickname'] ?? 'CriadorVIP'}',
                      'category': _category,
                      'netPrice': netVal,
                      'desc': _descCtrl.text.trim().isEmpty ? 'Criação exclusiva Estúdio VIP HELL Live.' : _descCtrl.text.trim(),
                      'owned': true,
                    });
                    _titleCtrl.clear();
                    _descCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Publicado na Loja HELL com sucesso!'), backgroundColor: Colors.green));
                  },
                  icon: const Icon(Icons.publish, color: Colors.white),
                  label: const Text('Publicar na Loja HELL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
