import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';

Future<T?> showSakuBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool enableDrag = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    useSafeArea: true,
    sheetAnimationStyle: SakuMotion.sheetStyle,
    builder: builder,
  );
}

class SakuSheetHandle extends StatelessWidget {
  const SakuSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: saku.borderStrong,
          borderRadius: BorderRadius.circular(SakuRadius.pill),
        ),
      ),
    );
  }
}

class TactilePressScale extends StatefulWidget {
  const TactilePressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<TactilePressScale> createState() => _TactilePressScaleState();
}

class _TactilePressScaleState extends State<TactilePressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _controller.animateTo(
      widget.pressedScale,
      duration: SakuMotion.press,
      curve: Curves.easeOutCubic,
    );
  }

  void _release() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        SakuMotion.springTactile,
        _controller.value,
        1.0,
        0.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _pressDown(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value.clamp(0.92, 1.04),
            child: child,
          );
        },
      ),
    );
  }
}

class AnimatedCurrencyText extends StatefulWidget {
  const AnimatedCurrencyText({
    super.key,
    required this.amount,
    required this.style,
    this.hidden = false,
    this.signed = false,
    this.maxLines = 1,
  });

  final int amount;
  final TextStyle style;
  final bool hidden;
  final bool signed;
  final int maxLines;

  @override
  State<AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<AnimatedCurrencyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.amount.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      final disableAnim = MediaQuery.disableAnimationsOf(context);
      if (disableAnim || widget.hidden) {
        _controller.value = widget.amount.toDouble();
      } else {
        _controller.animateWith(
          SpringSimulation(
            SakuMotion.springFluid,
            _controller.value,
            widget.amount.toDouble(),
            0.0,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mergedStyle = widget.style.copyWith(
      fontFeatures: AppTheme.tabularNums,
    );

    if (widget.hidden) {
      return Text(
        IdrFormat.currency(
          widget.amount,
          hidden: true,
          signed: widget.signed,
        ),
        maxLines: widget.maxLines,
        style: mergedStyle,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Text(
          IdrFormat.currency(
            _controller.value.round(),
            signed: widget.signed,
          ),
          maxLines: widget.maxLines,
          style: mergedStyle,
        );
      },
    );
  }
}

class LuxurySurfaceCard extends StatelessWidget {
  const LuxurySurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = SakuRadius.lg,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? saku.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? saku.border, width: 1),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: saku.cardShadow,
                  offset: const Offset(0, 2),
                  blurRadius: 10,
                ),
              ],
      ),
      child: child,
    );
  }
}

class SmoothProgressBar extends StatefulWidget {
  const SmoothProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.backgroundColor,
  });

  final double value;
  final Color color;
  final double height;
  final Color? backgroundColor;

  @override
  State<SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.value.clamp(0.0, 1.0),
    );
  }

  @override
  void didUpdateWidget(covariant SmoothProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value.clamp(0.0, 1.0);
    if ((oldWidget.value.clamp(0.0, 1.0) - next).abs() > 0.001) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = next;
      } else {
        _controller.animateWith(
          SpringSimulation(
            SakuMotion.springFluid,
            _controller.value,
            next,
            0.0,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final fill = _controller.value.clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: widget.backgroundColor ?? saku.surfaceElevated,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fill,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BentoSkeletonScreen extends StatefulWidget {
  const BentoSkeletonScreen({super.key});

  @override
  State<BentoSkeletonScreen> createState() => _BentoSkeletonScreenState();
}

class _BentoSkeletonScreenState extends State<BentoSkeletonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return Scaffold(
      backgroundColor: saku.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value;
            final bone = Color.lerp(
              saku.surfaceElevated.withValues(alpha: 0.55),
              saku.surfaceElevated,
              t,
            )!;

            Widget bar(double width, double height, {double radius = 8}) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: bone,
                  borderRadius: BorderRadius.circular(radius),
                ),
              );
            }

            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    bar(36, 36, radius: 11),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        bar(112, 16),
                        const SizedBox(height: 6),
                        bar(148, 11),
                      ],
                    ),
                    const Spacer(),
                    bar(34, 34, radius: 10),
                    const SizedBox(width: 8),
                    bar(34, 34, radius: 10),
                  ],
                ),
                const SizedBox(height: 20),
                LuxurySurfaceCard(
                  radius: SakuRadius.xl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          bar(150, 14),
                          const Spacer(),
                          bar(66, 24, radius: SakuRadius.pill),
                        ],
                      ),
                      const SizedBox(height: 16),
                      bar(220, 36, radius: 10),
                      const SizedBox(height: 18),
                      bar(double.infinity, 8, radius: 4),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          bar(160, 12),
                          const Spacer(),
                          bar(84, 28, radius: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LuxurySurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          bar(110, 12),
                          const SizedBox(height: 8),
                          bar(168, 24),
                        ],
                      ),
                      const Spacer(),
                      bar(86, 34, radius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: LuxurySurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            bar(78, 12),
                            const SizedBox(height: 12),
                            bar(112, 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LuxurySurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            bar(84, 12),
                            const SizedBox(height: 12),
                            bar(112, 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: List<Widget>.generate(4, (idx) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: idx == 0 ? 0 : 10),
                        child: LuxurySurfaceCard(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          radius: SakuRadius.md,
                          child: Column(
                            children: <Widget>[
                              bar(36, 36, radius: 10),
                              const SizedBox(height: 8),
                              bar(44, 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                bar(136, 16),
                const SizedBox(height: 12),
                LuxurySurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: List<Widget>.generate(3, (idx) {
                      return Padding(
                        padding: EdgeInsets.only(top: idx == 0 ? 0 : 14),
                        child: Row(
                          children: <Widget>[
                            bar(42, 42, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  bar(124, 14),
                                  const SizedBox(height: 6),
                                  bar(86, 11),
                                ],
                              ),
                            ),
                            bar(76, 14),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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

    return LuxurySurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      radius: SakuRadius.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Total Saldo Bersih',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: saku.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(SakuRadius.pill),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggleHidden();
                      },
                      child: Tooltip(
                        message: hidden
                            ? 'Tampilkan saldo'
                            : 'Sembunyikan saldo',
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: saku.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCurrencyText(
                    amount: netWorth,
                    hidden: hidden,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: saku.textPrimary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TactilePressScale(
            child: Material(
              color: saku.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SakuRadius.pill),
                side: BorderSide(color: saku.border, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(SakuRadius.pill),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onManageWallets();
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$activeWalletCount dompet',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textPrimary,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: saku.brandInteractive,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    return Row(
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: TactilePressScale(
              child: Material(
                color: saku.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  side: BorderSide(color: saku.border, width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    actions[i].onTap();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 66),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: actions[i].softBg,
                            borderRadius: BorderRadius.circular(SakuRadius.sm),
                          ),
                          child: Icon(
                            actions[i].icon,
                            size: 18,
                            color: actions[i].color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          actions[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
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
          ),
        ],
      ],
    );
  }
}
