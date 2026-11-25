import 'package:material_ui/material_ui.dart';

import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_input_sheet.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'pin_lock_screen.dart';
import 'plan_screen.dart';
import 'wallets_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  Future<void> _openQuickInput() async {
    final saved = await QuickInputSheet.show(
      context,
      controller: widget.controller,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil dicatat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Menyiapkan brankas lokal SakuProWann...'),
                ],
              ),
            ),
          );
        }

        if (widget.controller.errorMessage != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: context.saku.expense,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: widget.controller.initialize,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (widget.controller.isSessionLocked) {
          return PinLockScreen(controller: widget.controller);
        }

        final pages = <Widget>[
          HomeScreen(
            controller: widget.controller,
            onNavigateToWallets: () => setState(() => _currentIndex = 1),
          ),
          WalletsScreen(controller: widget.controller),
          PlanScreen(controller: widget.controller),
          AnalyticsScreen(controller: widget.controller),
        ];

        final width = MediaQuery.sizeOf(context).width;
        if (width >= 700) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: <Widget>[
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) =>
                        setState(() => _currentIndex = idx),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FloatingActionButton(
                        onPressed: _openQuickInput,
                        tooltip: 'Catat Transaksi Cepat',
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.add_rounded, size: 28),
                      ),
                    ),
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Beranda'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        label: Text('Dompet'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fact_check_outlined),
                        selectedIcon: Icon(Icons.fact_check_rounded),
                        label: Text('Rencana'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights_rounded),
                        label: Text('Analitik'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(index: _currentIndex, children: pages),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: pages),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: SizedBox(
            width: 58,
            height: 58,
            child: FloatingActionButton(
              onPressed: _openQuickInput,
              tooltip: 'Catat Transaksi Cepat',
              elevation: 3,
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
          ),
          bottomNavigationBar: _SakuBottomBar(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
          ),
        );
      },
    );
  }
}

class _SakuBottomBar extends StatelessWidget {
  const _SakuBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return Container(
      decoration: BoxDecoration(
        color: saku.surface,
        border: Border(top: BorderSide(color: saku.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavBarItem(
                  label: 'Beranda',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  selected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavBarItem(
                  label: 'Dompet',
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  selected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _NavBarItem(
                  label: 'Rencana',
                  icon: Icons.fact_check_outlined,
                  activeIcon: Icons.fact_check_rounded,
                  selected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ),
              Expanded(
                child: _NavBarItem(
                  label: 'Analitik',
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  selected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final color = selected ? saku.brandInteractive : saku.textMuted;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? saku.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
