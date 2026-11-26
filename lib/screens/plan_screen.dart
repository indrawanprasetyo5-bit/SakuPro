import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/plan_bills_tab.dart';
import '../widgets/plan_budgets_tab.dart';
import '../widgets/plan_debts_tab.dart';
import '../widgets/plan_goals_tab.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Text('Rencana Keuangan'),
          actions: <Widget>[
            IconButton(
              tooltip: hidden ? 'Tampilkan nominal' : 'Sembunyikan nominal',
              onPressed: controller.toggleHideBalance,
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
              onPressed: controller.toggleThemeMode,
              icon: Icon(
                context.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: saku.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: saku.border, width: 1)),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: (_) => HapticFeedback.selectionClick(),
                labelColor: saku.brandInteractive,
                unselectedLabelColor: saku.textMuted,
                indicatorColor: saku.brandInteractive,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const <Widget>[
                  Tab(text: 'Budget'),
                  Tab(text: 'Goals'),
                  Tab(text: 'Tagihan'),
                  Tab(text: 'Hutang & Piutang'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            PlanBudgetsTab(controller: controller),
            PlanGoalsTab(controller: controller),
            PlanBillsTab(controller: controller),
            PlanDebtsTab(controller: controller),
          ],
        ),
      ),
    );
  }
}
