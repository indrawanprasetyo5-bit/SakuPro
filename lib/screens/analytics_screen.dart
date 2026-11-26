import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/export_backup_service.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import '../widgets/luxury_widgets.dart';
import '../widgets/settings_sheet.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _fullMonths = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  DateTime? _selectedMonth;
  bool _isExportingExcel = false;

  DateTime _effectiveMonth() {
    final current = widget.controller.now;
    return _selectedMonth ?? DateTime(current.year, current.month);
  }

  String _chipLabel(DateTime dt) {
    final now = widget.controller.now;
    final short = '${_shortMonths[(dt.month - 1).clamp(0, 11)]} ${dt.year}';
    if (dt.year == now.year && dt.month == now.month) {
      return 'Bulan Ini · $short';
    }
    final prev = DateTime(now.year, now.month - 1);
    if (dt.year == prev.year && dt.month == prev.month) {
      return 'Bulan Lalu · $short';
    }
    return short;
  }

  String _fullMonthLabel(DateTime dt) {
    return '${_fullMonths[(dt.month - 1).clamp(0, 11)]} ${dt.year}';
  }

  Future<void> _exportExcel(MonthlyAnalyticsReport report) async {
    if (_isExportingExcel) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _isExportingExcel = true);
    try {
      final ctrl = widget.controller;
      await ExportBackupService.shareMonthlyExcel(
        month: report.month,
        monthTransactions: report.transactions,
        wallets: ctrl.wallets,
        netWorth: ctrl.netWorth,
        monthlyBudget: ctrl.monthlyBudget,
        categoryBudgets: ctrl.categoryBudgets,
        goals: ctrl.goals,
        bills: ctrl.bills,
        debts: ctrl.debts,
        previousMonthExpense: report.previousMonthExpense,
        insights: report.insights,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor Excel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingExcel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final ctrl = widget.controller;
    final hidden = ctrl.hideBalance;
    final activeMonth = _effectiveMonth();
    final months = ctrl.selectableMonths;
    final report = ctrl.buildMonthlyReport(activeMonth);
    final sixMonthTrend = ctrl.buildSixMonthTrend(activeMonth);
    final weekdayPattern = ctrl.buildWeekdaySpendPattern(activeMonth);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Analitik & Pengaturan'),
        actions: <Widget>[
          IconButton(
            tooltip: hidden ? 'Tampilkan nominal' : 'Sembunyikan nominal',
            onPressed: ctrl.toggleHideBalance,
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: saku.textPrimary,
            ),
          ),
          IconButton(
            tooltip: context.isDarkMode
                ? 'Pindah ke Mode Terang'
                : 'Pindah ke Mode Gelap',
            onPressed: ctrl.toggleThemeMode,
            icon: Icon(
              context.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: saku.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: months.map((m) {
                final isSelected =
                    m.year == activeMonth.year && m.month == activeMonth.month;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TactilePressScale(
                    child: ChoiceChip(
                      label: Text(
                        _chipLabel(m),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? saku.brandInteractive
                              : saku.textPrimary,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedMonth = m);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _CashflowComparisonCard(
            periodTitle: _fullMonthLabel(activeMonth),
            report: report,
            hideBalance: hidden,
            isExportingExcel: _isExportingExcel,
            onExportExcel: () => _exportExcel(report),
          ),
          const SizedBox(height: 14),
          _InsightsCard(insights: report.insights),
          const SizedBox(height: 14),
          _SixMonthTrendCard(
            points: sixMonthTrend,
            hideBalance: hidden,
          ),
          const SizedBox(height: 14),
          _WeekdayPatternCard(
            pattern: weekdayPattern,
            hideBalance: hidden,
          ),
          const SizedBox(height: 14),
          _CategoryChartCard(
            report: report,
            hideBalance: hidden,
          ),
          const SizedBox(height: 24),
          Text(
            'Pengaturan, Privasi & Backup',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          SettingsSectionPanel(controller: ctrl),
          const SizedBox(height: 14),
          LuxurySurfaceCard(
            padding: const EdgeInsets.all(14),
            radius: SakuRadius.md,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.storage_rounded,
                  size: 18,
                  color: saku.brandInteractive,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ctrl.isUsingInMemory
                        ? 'Penyimpanan: Preview Memori (${ctrl.wallets.length} dompet · ${ctrl.transactions.length} transaksi)'
                        : 'Penyimpanan: SQLite Offline di HP (${ctrl.wallets.length} dompet · ${ctrl.transactions.length} transaksi)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowComparisonCard extends StatelessWidget {
  const _CashflowComparisonCard({
    required this.periodTitle,
    required this.report,
    required this.hideBalance,
    required this.isExportingExcel,
    required this.onExportExcel,
  });

  final String periodTitle;
  final MonthlyAnalyticsReport report;
  final bool hideBalance;
  final bool isExportingExcel;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final maxVal = math.max(report.totalIncome, report.totalExpense);
    final incRatio = maxVal <= 0 ? 0.0 : report.totalIncome / maxVal;
    final expRatio = maxVal <= 0 ? 0.0 : report.totalExpense / maxVal;
    final net = report.totalIncome - report.totalExpense;

    return LuxurySurfaceCard(
      radius: SakuRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Arus Kas · $periodTitle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Selisih ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: saku.textMuted,
                        ),
                      ),
                      AnimatedCurrencyText(
                        amount: net,
                        hidden: hideBalance,
                        signed: true,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: net >= 0 ? saku.income : saku.expense,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TactilePressScale(
                child: FilledButton.tonalIcon(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll<Color>(
                      saku.brandSoft,
                    ),
                    foregroundColor: WidgetStatePropertyAll<Color>(
                      saku.brandInteractive,
                    ),
                  ),
                  onPressed: isExportingExcel ? null : onExportExcel,
                  icon: Icon(
                    isExportingExcel
                        ? Icons.hourglass_top_rounded
                        : Icons.table_view_outlined,
                    size: 17,
                  ),
                  label: Text(
                    isExportingExcel ? 'Menyiapkan...' : 'Export Excel (.xlsx)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ComparisonBarRow(
            label: 'Uang Masuk',
            amount: report.totalIncome,
            hidden: hideBalance,
            ratio: incRatio,
            color: saku.income,
          ),
          const SizedBox(height: 12),
          _ComparisonBarRow(
            label: 'Uang Keluar',
            amount: report.totalExpense,
            hidden: hideBalance,
            ratio: expRatio,
            color: saku.expense,
          ),
        ],
      ),
    );
  }
}

class _ComparisonBarRow extends StatelessWidget {
  const _ComparisonBarRow({
    required this.label,
    required this.amount,
    required this.hidden,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int amount;
  final bool hidden;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: saku.textSecondary,
              ),
            ),
            AnimatedCurrencyText(
              amount: amount,
              hidden: hidden,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SmoothProgressBar(value: ratio, color: color, height: 8),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return LuxurySurfaceCard(
      radius: SakuRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.insights_rounded,
                size: 19,
                color: saku.brandInteractive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Insight Otomatis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < insights.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: saku.brandInteractive,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insights[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChartCard extends StatelessWidget {
  const _CategoryChartCard({
    required this.report,
    required this.hideBalance,
  });

  final MonthlyAnalyticsReport report;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final slices = report.categorySlices;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return LuxurySurfaceCard(
      radius: SakuRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pengeluaran per Kategori',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada pengeluaran di bulan ini.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...<Widget>[
            Center(
              child: SizedBox(
                width: 184,
                height: 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      key: ValueKey<String>(
                        '${report.month.year}-${report.month.month}-${report.totalExpense}',
                      ),
                      tween: Tween<double>(
                        begin: disableAnim ? 1.0 : 0.0,
                        end: 1.0,
                      ),
                      duration: disableAnim
                          ? Duration.zero
                          : const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) {
                        return CustomPaint(
                          size: const Size(184, 184),
                          painter: _CategoryDonutPainter(
                            slices: slices,
                            trackColor: saku.surfaceElevated,
                            progress: progress,
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Total Keluar',
                            style: TextStyle(
                              fontSize: 12,
                              color: saku.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              IdrFormat.compact(
                                report.totalExpense,
                                hidden: hideBalance,
                              ),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: saku.textPrimary,
                                fontFeatures: AppTheme.tabularNums,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < slices.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 18, color: saku.border),
              _CategorySliceRow(
                slice: slices[i],
                hideBalance: hideBalance,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategorySliceRow extends StatelessWidget {
  const _CategorySliceRow({
    required this.slice,
    required this.hideBalance,
  });

  final CategorySpendSlice slice;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final pct = (slice.share * 100).round();

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: slice.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(slice.icon, size: 16, color: slice.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    slice.category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${slice.count} transaksi · $pct%',
                    style: TextStyle(
                      fontSize: 12,
                      color: saku.textMuted,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              IdrFormat.currency(slice.amount, hidden: hideBalance),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmoothProgressBar(
          value: slice.share.clamp(0.0, 1.0),
          color: slice.color,
          height: 6,
        ),
      ],
    );
  }
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter({
    required this.slices,
    required this.trackColor,
    required this.progress,
  });

  final List<CategorySpendSlice> slices;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 20.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty || progress <= 0.0) {
      return;
    }

    var startAngle = -math.pi / 2;
    final gapRadians = slices.length > 1 ? 0.035 : 0.0;

    for (final slice in slices) {
      final fullSweep = slice.share * 2 * math.pi * progress;
      final drawSweep = math.max(0.02 * progress, fullSweep - gapRadians);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, drawSweep, false, paint);
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progress != progress;
  }
}

class _SixMonthTrendCard extends StatefulWidget {
  const _SixMonthTrendCard({
    required this.points,
    required this.hideBalance,
  });

  final List<MonthlyTrendPoint> points;
  final bool hideBalance;

  @override
  State<_SixMonthTrendCard> createState() => _SixMonthTrendCardState();
}

class _SixMonthTrendCardState extends State<_SixMonthTrendCard> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    var maxValue = 0;
    for (final p in widget.points) {
      maxValue = math.max(maxValue, math.max(p.income, p.expense));
    }

    final maxIdx = math.max(0, widget.points.length - 1);
    final idx = (_selectedIdx ?? maxIdx).clamp(0, maxIdx).toInt();
    final activePoint = widget.points.isNotEmpty ? widget.points[idx] : null;

    return LuxurySurfaceCard(
      radius: SakuRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Tren 6 Bulan Terakhir',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _LegendDot(color: saku.income, label: 'Masuk'),
              const SizedBox(width: 10),
              _LegendDot(color: saku.expense, label: 'Keluar'),
            ],
          ),
          if (activePoint != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${activePoint.shortLabel} ${activePoint.month.year} · '
              'Masuk ${IdrFormat.compact(activePoint.income, hidden: widget.hideBalance)} · '
              'Keluar ${IdrFormat.compact(activePoint.expense, hidden: widget.hideBalance)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: saku.textSecondary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (maxValue <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Catat transaksi di beberapa bulan buat lihat tren arus kasmu.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              key: ValueKey<String>(
                widget.points
                    .map((e) => '${e.month.month}:${e.income}:${e.expense}')
                    .join('|'),
              ),
              tween: Tween<double>(begin: disableAnim ? 1.0 : 0.0, end: 1.0),
              duration: disableAnim
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return SizedBox(
                  height: 132,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List<Widget>.generate(widget.points.length, (i) {
                      final p = widget.points[i];
                      final selected = i == idx;
                      final incH = maxValue <= 0
                          ? 0.0
                          : (p.income / maxValue) * 92.0 * progress;
                      final expH = maxValue <= 0
                          ? 0.0
                          : (p.expense / maxValue) * 92.0 * progress;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIdx = i);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              SizedBox(
                                height: 96,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Container(
                                      width: 10,
                                      height: math.max(
                                        p.income > 0 ? 4.0 : 2.0,
                                        incH,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.income > 0
                                            ? saku.income.withValues(
                                                alpha: selected ? 1.0 : 0.55,
                                              )
                                            : saku.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 10,
                                      height: math.max(
                                        p.expense > 0 ? 4.0 : 2.0,
                                        expH,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.expense > 0
                                            ? saku.expense.withValues(
                                                alpha: selected ? 1.0 : 0.55,
                                              )
                                            : saku.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? saku.surfaceElevated
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.shortLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? saku.textPrimary
                                        : saku.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.saku.textMuted,
          ),
        ),
      ],
    );
  }
}

class _WeekdayPatternCard extends StatelessWidget {
  const _WeekdayPatternCard({
    required this.pattern,
    required this.hideBalance,
  });

  final WeekdaySpendPattern pattern;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final peak = pattern.peakBucket;
    final maxAmt = peak?.amount ?? 0;

    return LuxurySurfaceCard(
      radius: SakuRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pola Pengeluaran Harian',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            peak != null
                ? 'Paling boros di hari ${peak.fullLabel} (${IdrFormat.compact(peak.amount, hidden: hideBalance)} · ${peak.count}x transaksi).'
                : 'Belum ada data pengeluaran untuk pola harian di bulan ini.',
            style: TextStyle(
              fontSize: 12.5,
              color: saku.textSecondary,
              fontFeatures: AppTheme.tabularNums,
            ),
          ),
          if (maxAmt > 0) ...<Widget>[
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(pattern.totalExpense),
              tween: Tween<double>(begin: disableAnim ? 1.0 : 0.0, end: 1.0),
              duration: disableAnim
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return SizedBox(
                  height: 102,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: pattern.buckets.map((bucket) {
                      final isPeak =
                          peak != null && bucket.weekday == peak.weekday;
                      final ratio = maxAmt <= 0 ? 0.0 : bucket.amount / maxAmt;
                      final barH = math.max(
                        bucket.amount > 0 ? 6.0 : 3.0,
                        ratio * 68.0 * progress,
                      );
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              width: 18,
                              height: barH,
                              decoration: BoxDecoration(
                                color: bucket.amount == 0
                                    ? saku.surfaceElevated
                                    : isPeak
                                    ? saku.expense
                                    : saku.brandInteractive.withValues(
                                        alpha: 0.55,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              bucket.shortLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isPeak
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isPeak
                                    ? saku.expense
                                    : saku.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
