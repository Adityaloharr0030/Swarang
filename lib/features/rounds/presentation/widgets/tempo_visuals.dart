import 'package:flutter/material.dart';

/// Master configuration for Garba performance song tempos.
///
/// In Garba performances, songs naturally progress through 3 core phases:
/// 1. Slow (2-Taali / ધીમી - બે તાળી): Graceful warm-up and traditional cadence
/// 2. Medium (3-Taali / મધ્યમ - ત્રણ તાળી): Energizing 3-clap circular groove
/// 3. Fast (Titodo & Sanedo / ઝડપી - તીટોડો): High-adrenaline climax & whirlwind
class GarbaTempoConfig {
  const GarbaTempoConfig({
    required this.value,
    required this.label,
    required this.garbaType,
    required this.gujarati,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.speedLevel,
  });

  final String value;
  final String label;
  final String garbaType;
  final String gujarati;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final int speedLevel; // 1 = Slow, 2 = Medium, 3 = Fast

  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color cardBorderColor(bool isDark) =>
      color.withValues(alpha: isDark ? 0.32 : 0.22);

  Color subtleBgColor(bool isDark) =>
      color.withValues(alpha: isDark ? 0.08 : 0.04);

  static const slow = GarbaTempoConfig(
    value: 'slow',
    label: 'Slow',
    garbaType: '2-Taali',
    gujarati: '૨-તાળી (ધીમી)',
    description: 'Graceful rhythm • Devotional warm-up',
    icon: Icons.waves_rounded,
    color: Color(0xFF0288D1),
    gradientColors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
    speedLevel: 1,
  );

  static const medium = GarbaTempoConfig(
    value: 'medium',
    label: 'Medium',
    garbaType: '3-Taali',
    gujarati: '૩-તાળી (મધ્યમ)',
    description: 'Building energy • Spirited clapping groove',
    icon: Icons.bolt_rounded,
    color: Color(0xFF2E7D32),
    gradientColors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
    speedLevel: 2,
  );

  static const fast = GarbaTempoConfig(
    value: 'fast',
    label: 'Fast',
    garbaType: 'Titodo / Climax',
    gujarati: 'તીટોડો (ઝડપી)',
    description: 'High adrenaline • Climax & whirlwind spins',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFE53935),
    gradientColors: [Color(0xFFFF7043), Color(0xFFD32F2F)],
    speedLevel: 3,
  );

  static const List<GarbaTempoConfig> all = [slow, medium, fast];

  static GarbaTempoConfig from(String? val) {
    if (val == null) return medium;
    final match = val.trim().toLowerCase();
    return all.firstWhere(
      (t) => t.value == match,
      orElse: () => medium,
    );
  }
}

// ─── Speed Meter (Equalizer / Speedometer Bars) ─────────────────────────────

/// Visual 3-bar speed meter indicating tempo velocity.
class TempoSpeedMeter extends StatelessWidget {
  const TempoSpeedMeter({
    super.key,
    required this.tempo,
    this.barWidth = 3.5,
    this.maxHeight = 16,
    this.spacing = 2.5,
    this.colorOverride,
  });

  final String tempo;
  final double barWidth;
  final double maxHeight;
  final double spacing;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    final cfg = GarbaTempoConfig.from(tempo);
    final activeColor = colorOverride ?? cfg.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.12);

    final heights = [
      maxHeight * 0.5,
      maxHeight * 0.75,
      maxHeight,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final isLit = i < cfg.speedLevel;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? spacing : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: barWidth,
            height: heights[i],
            decoration: BoxDecoration(
              color: isLit ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isLit
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─── Tempo Badge Chip ────────────────────────────────────────────────────────

/// Prominent badge highlighting the song tempo with icon, label, and speed bars.
class TempoBadge extends StatelessWidget {
  const TempoBadge({
    super.key,
    required this.tempo,
    this.onTap,
    this.showSpeedMeter = true,
    this.showSubtitle = false,
    this.compact = false,
  });

  final String tempo;
  final VoidCallback? onTap;
  final bool showSpeedMeter;
  final bool showSubtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cfg = GarbaTempoConfig.from(tempo);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(
          color: cfg.color.withValues(alpha: isDark ? 0.35 : 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: compact ? 13 : 15, color: cfg.color),
          SizedBox(width: compact ? 4 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                showSubtitle ? '${cfg.label} • ${cfg.garbaType}' : cfg.label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  color: cfg.color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (showSpeedMeter) ...[
            SizedBox(width: compact ? 6 : 8),
            TempoSpeedMeter(
              tempo: tempo,
              maxHeight: compact ? 13 : 15,
              barWidth: compact ? 3 : 3.5,
              colorOverride: cfg.color,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return badge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        splashColor: cfg.color.withValues(alpha: 0.2),
        highlightColor: cfg.color.withValues(alpha: 0.1),
        child: badge,
      ),
    );
  }
}

// ─── Tempo Distribution Bar (Performance Energy Arc) ─────────────────────────

/// A multi-segmented progress bar showing the distribution of Slow, Medium, and Fast songs.
class TempoDistributionBar extends StatelessWidget {
  const TempoDistributionBar({
    super.key,
    required this.slowCount,
    required this.mediumCount,
    required this.fastCount,
    this.height = 6,
    this.showLabels = true,
  });

  final int slowCount;
  final int mediumCount;
  final int fastCount;
  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final total = slowCount + mediumCount + fastCount;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    final slowRatio = slowCount / total;
    final mediumRatio = mediumCount / total;
    final fastRatio = fastCount / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            child: Row(
              children: [
                if (slowCount > 0)
                  Expanded(
                    flex: (slowRatio * 1000).toInt(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
                        ),
                      ),
                    ),
                  ),
                if (mediumCount > 0)
                  Expanded(
                    flex: (mediumRatio * 1000).toInt(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                        ),
                      ),
                    ),
                  ),
                if (fastCount > 0)
                  Expanded(
                    flex: (fastRatio * 1000).toInt(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7043), Color(0xFFD32F2F)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              _tempoMiniLabel(
                icon: GarbaTempoConfig.slow.icon,
                count: slowCount,
                label: 'Slow',
                color: GarbaTempoConfig.slow.color,
              ),
              const SizedBox(width: 10),
              _tempoMiniLabel(
                icon: GarbaTempoConfig.medium.icon,
                count: mediumCount,
                label: 'Medium',
                color: GarbaTempoConfig.medium.color,
              ),
              const SizedBox(width: 10),
              _tempoMiniLabel(
                icon: GarbaTempoConfig.fast.icon,
                count: fastCount,
                label: 'Fast',
                color: GarbaTempoConfig.fast.color,
              ),
              const Spacer(),
              Text(
                '$total songs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tempoMiniLabel({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Tempo Selector Bottom Sheet ─────────────────────────────────────────────

/// Full interactive selector modal allowing user to pick or update song tempo.
class TempoSelectorSheet extends StatelessWidget {
  const TempoSelectorSheet({
    super.key,
    required this.selectedTempo,
    required this.onSelect,
    this.title = 'Select Song Tempo',
    this.subtitle = 'Garba performance rhythm & speed',
  });

  final String selectedTempo;
  final ValueChanged<String> onSelect;
  final String title;
  final String subtitle;

  static Future<String?> show(
    BuildContext context, {
    required String currentTempo,
    String? title,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TempoSelectorSheet(
        selectedTempo: currentTempo,
        title: title ?? 'Change Song Tempo',
        onSelect: (val) => Navigator.of(ctx).pop(val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3 Large interactive tempo option cards
          ...GarbaTempoConfig.all.map((cfg) {
            final isSelected =
                cfg.value == selectedTempo.trim().toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(cfg.value),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: cfg.color.withValues(alpha: 0.15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cfg.color.withValues(alpha: isDark ? 0.18 : 0.10)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? cfg.color
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06)),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: cfg.color.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Icon circle with gradient
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? cfg.gradient
                                : LinearGradient(
                                    colors: [
                                      cfg.color.withValues(alpha: 0.15),
                                      cfg.color.withValues(alpha: 0.08),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            cfg.icon,
                            color: isSelected ? Colors.white : cfg.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title, Subtitle, Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    cfg.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? cfg.color
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cfg.color
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cfg.garbaType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: cfg.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cfg.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Speed meter & selection indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TempoSpeedMeter(
                              tempo: cfg.value,
                              maxHeight: 18,
                              barWidth: 4,
                              colorOverride: cfg.color,
                            ),
                            const SizedBox(height: 6),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: cfg.color,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
