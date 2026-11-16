import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';

class PlatformAccountConfig {
  final String id;
  final String name;
  final Color brandColor;
  final IconData emblemIcon;
  String usernameOrKey;
  bool isConnected;

  PlatformAccountConfig({
    required this.id,
    required this.name,
    required this.brandColor,
    required this.emblemIcon,
    this.usernameOrKey = '',
    this.isConnected = false,
  });

  bool get hasCredentials => usernameOrKey.trim().isNotEmpty;
}

class PlatformLogosGrid extends StatefulWidget {
  final Function(PlatformAccountConfig) onPlatformToggled;
  final List<PlatformAccountConfig> platforms;

  const PlatformLogosGrid({
    super.key,
    required this.platforms,
    required this.onPlatformToggled,
  });

  @override
  State<PlatformLogosGrid> createState() => _PlatformLogosGridState();
}

class _PlatformLogosGridState extends State<PlatformLogosGrid> {
  Future<void> _savePlatformCredential(PlatformAccountConfig platform, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hell_plat_${platform.id}_user', value.trim());
    setState(() {
      platform.usernameOrKey = value.trim();
      platform.isConnected = value.trim().isNotEmpty;
    });
    widget.onPlatformToggled(platform);
  }

  void _handleSquareTap(PlatformAccountConfig platform) {
    if (platform.hasCredentials) {
      setState(() {
        platform.isConnected = !platform.isConnected;
      });
      widget.onPlatformToggled(platform);
      return;
    }

    final ctrl = TextEditingController(text: platform.usernameOrKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HellTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HellTheme.neonBlue, width: 1.5),
        ),
        title: Row(
          children: [
            _build3DPlatformLogo(platform, size: 32),
            const SizedBox(width: 10),
            Text(
              'Ligar ${platform.name}',
              style: const TextStyle(color: HellTheme.textWhite, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configura apenas uma vez. Nas próximas lives basta tocar no quadrado para ligar (ON) ou desligar (OFF).',
              style: TextStyle(color: HellTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: HellTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'Canal / @Utilizador ou Chave API',
                labelStyle: const TextStyle(color: HellTheme.neonBlue, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: HellTheme.neonBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: HellTheme.neonGreen, width: 1.8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: HellTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HellTheme.neonGreen,
              foregroundColor: HellTheme.bgDark,
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _savePlatformCredential(platform, ctrl.text);
              }
            },
            child: const Text('Guardar e Ligar ON', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _openEditCredentials(PlatformAccountConfig platform) {
    final ctrl = TextEditingController(text: platform.usernameOrKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HellTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HellTheme.neonBlue),
        ),
        title: Text('Editar ${platform.name}', style: const TextStyle(color: HellTheme.textWhite, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: HellTheme.textWhite),
          decoration: const InputDecoration(
            labelText: 'Canal / @Utilizador',
            labelStyle: TextStyle(color: HellTheme.neonBlue),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _savePlatformCredential(platform, '');
            },
            child: const Text('Remover Conta', style: TextStyle(color: HellTheme.neonRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HellTheme.neonBlue, foregroundColor: HellTheme.bgDark),
            onPressed: () {
              Navigator.pop(ctx);
              _savePlatformCredential(platform, ctrl.text);
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Widget _build3DPlatformLogo(PlatformAccountConfig platform, {double size = 45}) {
    final scaledSize = size * 1.25;
    return Container(
      width: scaledSize,
      height: scaledSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            platform.brandColor.withValues(alpha: 0.95),
            platform.brandColor.withValues(alpha: 0.45),
            HellTheme.bgDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: platform.brandColor.withValues(alpha: 0.55),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(-2, -2),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Center(
        child: _platformCustomGlyph(platform.id, scaledSize * 0.56),
      ),
    );
  }

  Widget _platformCustomGlyph(String id, double iconSize) {
    switch (id) {
      case 'tiktok':
        return Icon(Icons.music_note_rounded, color: Colors.white, size: iconSize);
      case 'twitch':
        return Icon(Icons.videogame_asset_rounded, color: Colors.white, size: iconSize);
      case 'youtube':
        return Icon(Icons.play_arrow_rounded, color: Colors.white, size: iconSize * 1.15);
      case 'kick':
        return Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: iconSize * 0.95,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))],
          ),
        );
      default:
        return Icon(Icons.live_tv_rounded, color: Colors.white, size: iconSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.platforms.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final plat = widget.platforms[index];
        final isOn = plat.isConnected;

        return GestureDetector(
          onTap: () => _handleSquareTap(plat),
          onLongPress: () => _openEditCredentials(plat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: HellTheme.neonCard(
              borderColor: HellTheme.neonBlue,
              isActiveGreen: isOn,
              radius: 14,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOn ? HellTheme.neonGreen : HellTheme.cardElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOn ? HellTheme.neonGreen : HellTheme.textMuted.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: isOn ? HellTheme.bgDark : HellTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _build3DPlatformLogo(plat, size: 38),
                      const SizedBox(height: 6),
                      Text(
                        plat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOn ? HellTheme.textWhite : HellTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
