import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';

class LuxurySurfaceCard extends StatelessWidget {
  const LuxurySurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: saku.border),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: saku.cardShadow,
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
      ),
      child: child,
    );
  }
}

class SmoothProgressBar extends StatelessWidget {
  const SmoothProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final clamped = value.clamp(0.0, 1.0);
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    if (disableAnim) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: clamped,
          minHeight: height,
          backgroundColor: saku.surfaceMuted,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clamped),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: height,
            backgroundColor: saku.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      },
    );
  }
}

class WealthMetalCard extends StatelessWidget {
  const WealthMetalCard({
    super.key,
    required this.netWorth,
    required this.hidden,
    required this.activeWalletCount,
    required this.onToggleHidden,
    required this.onManageWallets,
  });

  final int netWorth;
  final bool hidden;
  final int activeWalletCount;
  final VoidCallback onToggleHidden;
  final VoidCallback onManageWallets;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF062E2C).withValues(alpha: 0.28),
            offset: const Offset(0, 12),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const <double>[0.0, 0.52, 1.0],
                    colors: <Color>[saku.heroStart, saku.heroMid, saku.heroEnd],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MetalCardContourPainter(
                  accentColor: saku.goldAccent,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: saku.goldAccent.withValues(alpha: 0.38),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: saku.goldAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total Saldo Bersih',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: saku.heroMutedText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggleHidden();
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 40,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hidden ? 'Tampilkan' : 'Sembunyikan',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        IdrFormat.currency(netWorth, hidden: hidden),
                        key: ValueKey<String>('$hidden-$netWorth'),
                        style: const TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                          color: Colors.white,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: saku.goldAccent,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$activeWalletCount dompet terhubung',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: saku.heroMutedText,
                                  fontFeatures: AppTheme.tabularNums,
                                ),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onManageWallets();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text(
                                  'Kelola Dompet',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: saku.goldAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetalCardContourPainter extends CustomPainter {
  const _MetalCardContourPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final goldArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.14);

    final softArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.06);

    final center = Offset(size.width * 0.92, size.height * 0.12);
    for (var i = 1; i <= 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: i * 44.0),
        math.pi * 0.45,
        math.pi * 0.9,
        false,
        i == 2 ? goldArc : softArc,
      );
    }

    final subtleGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.18),
          radius: size.width * 0.48,
        ),
      );
    canvas.drawRect(Offset.zero & size, subtleGlow);
  }

  @override
  bool shouldRepaint(covariant _MetalCardContourPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class QuickActionSpec {
  const QuickActionSpec({
    required this.label,
    required this.icon,
    required this.color,
    required this.softBg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color softBg;
  final VoidCallback onTap;
}

class LuxuryQuickActionBar extends StatelessWidget {
  const LuxuryQuickActionBar({super.key, required this.actions});

  final List<QuickActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;

    return Row(
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: saku.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: saku.border),
              ),
              elevation: isDark ? 0 : 0.4,
              shadowColor: saku.cardShadow,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  actions[i].onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: actions[i].softBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          actions[i].icon,
                          size: 20,
                          color: actions[i].color,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        actions[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
