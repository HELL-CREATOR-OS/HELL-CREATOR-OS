import 'package:flutter/material.dart';

class PlatformBrandLogo extends StatelessWidget {
  final String platform;
  final double size;

  const PlatformBrandLogo({
    super.key,
    required this.platform,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final p = platform.toLowerCase();
    if (p == 'tiktok') {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: _TikTokLogoPainter()));
    } else if (p == 'twitch') {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: _TwitchLogoPainter()));
    } else if (p == 'youtube') {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: _YouTubeLogoPainter()));
    } else {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: _KickLogoPainter()));
    }
  }
}

class PlatformGlassTile extends StatelessWidget {
  final String platform;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const PlatformGlassTile({
    super.key,
    required this.platform,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  Color _accent() {
    switch (platform.toLowerCase()) {
      case 'tiktok':
        return const Color(0xFF00F2EA);
      case 'twitch':
        return const Color(0xFFA970FF);
      case 'youtube':
        return const Color(0xFFFF2A2A);
      default:
        return const Color(0xFF53FC18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [accent.withOpacity(0.32), const Color(0xFF0D2052), const Color(0xFF060E26)]
                : [Colors.white.withOpacity(0.14), const Color(0xFF0C1B44).withOpacity(0.88), const Color(0xFF050B1E)],
          ),
          border: Border.all(
            color: isActive ? accent : Colors.white.withOpacity(0.24),
            width: isActive ? 2.2 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? accent.withOpacity(0.45) : Colors.black.withOpacity(0.55),
              blurRadius: isActive ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlatformBrandLogo(platform: platform, size: 54),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? accent : Colors.white,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                child: const Text('AO VIVO', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class _TikTokLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = Paint()..color = const Color(0xFF0A0A0E);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.24)), bg);

    void drawNote(Color color, double dx, double dy) {
      final p = Paint()..color = color;
      canvas.drawCircle(Offset(s * 0.40 + dx, s * 0.66 + dy), s * 0.16, p);
      final hole = Paint()..color = const Color(0xFF0A0A0E);
      canvas.drawCircle(Offset(s * 0.40 + dx, s * 0.66 + dy), s * 0.065, hole);
      canvas.drawRect(Rect.fromLTWH(s * 0.47 + dx, s * 0.22 + dy, s * 0.095, s * 0.44), p);
      final arcPath = Path()
        ..moveTo(s * 0.47 + dx, s * 0.22 + dy)
        ..quadraticBezierTo(s * 0.56 + dx, s * 0.37 + dy, s * 0.74 + dx, s * 0.37 + dy)
        ..lineTo(s * 0.74 + dx, s * 0.46 + dy)
        ..quadraticBezierTo(s * 0.58 + dx, s * 0.46 + dy, s * 0.47 + dx, s * 0.33 + dy)
        ..close();
      canvas.drawPath(arcPath, p);
    }

    drawNote(const Color(0xFF00F2EA), -s * 0.03, -s * 0.025);
    drawNote(const Color(0xFFFF0050), s * 0.03, s * 0.025);
    drawNote(Colors.white, 0, 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TwitchLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = Paint()..color = const Color(0xFF9146FF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.24)), bg);

    final white = Paint()..color = Colors.white;
    final box = Path()
      ..moveTo(s * 0.24, s * 0.18)
      ..lineTo(s * 0.80, s * 0.18)
      ..lineTo(s * 0.80, s * 0.58)
      ..lineTo(s * 0.62, s * 0.76)
      ..lineTo(s * 0.46, s * 0.76)
      ..lineTo(s * 0.34, s * 0.86)
      ..lineTo(s * 0.34, s * 0.76)
      ..lineTo(s * 0.24, s * 0.76)
      ..close();
    canvas.drawPath(box, white);

    final eye = Paint()..color = const Color(0xFF9146FF);
    canvas.drawRect(Rect.fromLTWH(s * 0.45, s * 0.33, s * 0.075, s * 0.20), eye);
    canvas.drawRect(Rect.fromLTWH(s * 0.61, s * 0.33, s * 0.075, s * 0.20), eye);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YouTubeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = Paint()..color = const Color(0xFFFF0000);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.24)), bg);

    final white = Paint()..color = Colors.white;
    final play = Path()
      ..moveTo(s * 0.40, s * 0.30)
      ..lineTo(s * 0.70, s * 0.50)
      ..lineTo(s * 0.40, s * 0.70)
      ..close();
    canvas.drawPath(play, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KickLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = Paint()..color = const Color(0xFF0B0E11);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.24)), bg);

    final green = Paint()..color = const Color(0xFF53FC18);
    canvas.drawRect(Rect.fromLTWH(s * 0.24, s * 0.22, s * 0.16, s * 0.56), green);
    final kArm = Path()
      ..moveTo(s * 0.40, s * 0.44)
      ..lineTo(s * 0.62, s * 0.22)
      ..lineTo(s * 0.78, s * 0.22)
      ..lineTo(s * 0.55, s * 0.48)
      ..lineTo(s * 0.78, s * 0.78)
      ..lineTo(s * 0.62, s * 0.78)
      ..lineTo(s * 0.40, s * 0.54)
      ..close();
    canvas.drawPath(kArm, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
