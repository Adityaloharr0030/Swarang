import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Full-screen immersive lyrics reader.
///
/// Tap anywhere to toggle the top/bottom control bars.
/// Supports font-size adjustment and three background reading modes.
class LyricsFullScreen extends StatefulWidget {
  const LyricsFullScreen({
    super.key,
    required this.title,
    required this.lyrics,
  });

  final String title;
  final String lyrics;

  /// Push this screen over [context] with a fade transition.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String lyrics,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => LyricsFullScreen(title: title, lyrics: lyrics),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  State<LyricsFullScreen> createState() => _LyricsFullScreenState();
}

class _LyricsFullScreenState extends State<LyricsFullScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late AnimationController _barsAnim;

  bool _barsVisible = true;
  double _fontSize = 18.0;

  // 0 = dark, 1 = warm dim, 2 = warm light
  int _bgMode = 0;

  static const _bgColors = [
    Color(0xFF0D0D0D),
    Color(0xFF1C1A14),
    Color(0xFFFFF8F0),
  ];
  static const _textColors = [
    Color(0xFFF0E6D3),
    Color(0xFFE8D8B8),
    Color(0xFF2C1A0E),
  ];
  static const _bgLabels = ['Dark', 'Dim', 'Light'];
  static const _bgIcons = [
    Icons.nights_stay_rounded,
    Icons.brightness_4_rounded,
    Icons.wb_sunny_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _barsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _barsAnim.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
    _barsVisible ? _barsAnim.forward() : _barsAnim.reverse();
  }

  void _changeFontSize(double delta) =>
      setState(() => _fontSize = (_fontSize + delta).clamp(12.0, 38.0));

  void _cycleBg() => setState(() => _bgMode = (_bgMode + 1) % 3);

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[_bgMode];
    final textColor = _textColors[_bgMode];

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: _toggleBars,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Lyrics
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 110, 24, 130),
                child: Text(
                  widget.lyrics,
                  style: TextStyle(
                    color: textColor,
                    fontSize: _fontSize,
                    height: 2.0,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _barsAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _barsAnim, curve: Curves.easeOut)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [bg, bg.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1.0],
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      8,
                      MediaQuery.of(context).padding.top + 8,
                      8,
                      28,
                    ),
                    child: Row(
                      children: [
                        _CircleBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          color: textColor,
                          bg: textColor.withValues(alpha: 0.12),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CircleBtn(
                          icon: Icons.copy_rounded,
                          color: textColor,
                          bg: textColor.withValues(alpha: 0.12),
                          size: 19,
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: '${widget.title}\n\n${widget.lyrics}'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _barsAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _barsAnim, curve: Curves.easeOut)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [bg.withValues(alpha: 0.0), bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5],
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      MediaQuery.of(context).padding.bottom + 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundedBtn(
                          icon: Icons.text_decrease_rounded,
                          onTap: () => _changeFontSize(-2),
                          textColor: textColor,
                          bg: textColor.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_fontSize.toInt()}',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _RoundedBtn(
                          icon: Icons.text_increase_rounded,
                          onTap: () => _changeFontSize(2),
                          textColor: textColor,
                          bg: textColor.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: _cycleBg,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.songsGradientStart
                                  .withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_bgIcons[_bgMode],
                                    color: textColor, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _bgLabels[_bgMode],
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.size = 20,
  });
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _RoundedBtn extends StatelessWidget {
  const _RoundedBtn({
    required this.icon,
    required this.onTap,
    required this.textColor,
    required this.bg,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: textColor, size: 22),
      ),
    );
  }
}
