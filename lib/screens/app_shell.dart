import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../services/automation_bridge_service.dart';
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isHandlingExternalIntent = false;
  bool _wasReadyForIntents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerStateChanged);
    AutomationBridgeService.setHandlers(
      onSharedImageReceived: _handleSharedImagePath,
      onLaunchAction: _handleWidgetLaunchAction,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndConsumeExternalIntents();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    AutomationBridgeService.setHandlers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onControllerStateChanged() {
    _checkAndConsumeExternalIntents();
  }

  void _checkAndConsumeExternalIntents() {
    final readyNow =
        !widget.controller.isLoading && !widget.controller.isSessionLocked;
    if (readyNow && !_wasReadyForIntents) {
      _wasReadyForIntents = true;
      unawaited(_consumePendingExternalIntents());
    } else if (!readyNow) {
      _wasReadyForIntents = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncIncomingBankNotifications();
      unawaited(_consumePendingExternalIntents());
    }
  }

  Future<void> _consumePendingExternalIntents() async {
    if (widget.controller.isLoading ||
        widget.controller.isSessionLocked ||
        widget.controller.isUsingInMemory) {
      return;
    }
    final sharedPath =
        await AutomationBridgeService.consumePendingSharedImage();
    if (sharedPath != null && sharedPath.isNotEmpty) {
      await _handleSharedImagePath(sharedPath);
      return;
    }
    final action = await AutomationBridgeService.consumePendingLaunchAction();
    if (action != null && action.isNotEmpty) {
      await _handleWidgetLaunchAction(action);
    }
  }

  Future<void> _handleSharedImagePath(String filePath) async {
    if (!mounted || _isHandlingExternalIntent || widget.controller.isSessionLocked) {
      return;
    }
    _isHandlingExternalIntent = true;
    try {
      final saved = await QuickInputSheet.show(
        context,
        controller: widget.controller,
        initialMode: InputEntryMode.manualForm,
        initialReceiptImagePath: filePath,
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi dari bukti transfer sudah tersimpan.'),
          ),
        );
      }
    } finally {
      _isHandlingExternalIntent = false;
    }
  }

  Future<void> _handleWidgetLaunchAction(String action) async {
    if (!mounted || _isHandlingExternalIntent || widget.controller.isSessionLocked) {
      return;
    }
    _isHandlingExternalIntent = true;
    try {
      if (action == 'scan_receipt') {
        final saved = await QuickInputSheet.show(
          context,
          controller: widget.controller,
          initialMode: InputEntryMode.manualForm,
          autoScanSource: ImageSource.camera,
        );
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi dari struk tersimpan.')),
          );
        }
      } else if (action == 'quick_input') {
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
    } finally {
      _isHandlingExternalIntent = false;
    }
  }

  Future<void> _syncIncomingBankNotifications() async {
    await widget.controller.refreshNotificationPermission();
    await widget.controller.refreshPostNotificationPermission();

    final recurring = await widget.controller.runRecurringAutomations();
    if (recurring.totalRecorded > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-Catat Rutin: ${recurring.totalRecorded} transaksi terjadwal tercatat.',
          ),
        ),
      );
    }

    if (!widget.controller.autoCaptureEnabled) {
      return;
    }
    final captured = await widget.controller.drainNativeNotifications();
    if (captured > 0 && mounted) {
      final mode = widget.controller.autoCaptureMode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == AutoCaptureMode.autoSave
                ? '$captured transaksi QRIS/bank otomatis tercatat.'
                : '$captured transaksi QRIS/bank masuk antrean konfirmasi.',
          ),
        ),
      );
    }
  }

  Future<void> _openQuickInput() async {
    HapticFeedback.lightImpact();
    final saved = await QuickInputSheet.show(
      context,
      controller: widget.controller,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi masuk buku kas.')),
      );
    }
  }

  void _selectTab(int idx) {
    if (_currentIndex == idx) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDark = context.isDarkMode;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: context.saku.surface,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: context.saku.surface,
              );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.controller.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Membuka catatan keuanganmu...'),
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
        onNavigateToWallets: () => _selectTab(1),
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
                onDestinationSelected: _selectTab,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded),
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
                child: _SeamlessTabStack(
                  currentIndex: _currentIndex,
                  children: pages,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final saku = context.saku;

    return Scaffold(
      body: _SeamlessTabStack(
        currentIndex: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF0F766E).withValues(alpha: 0.34),
              offset: const Offset(0, 8),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openQuickInput,
          tooltip: 'Catat Transaksi Cepat',
          elevation: 0,
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
            side: BorderSide(
              color: saku.goldAccent.withValues(alpha: 0.55),
              width: 1.1,
            ),
          ),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: _SakuBottomBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class _SeamlessTabStack extends StatelessWidget {
  const _SeamlessTabStack({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(index: currentIndex, children: children);
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    if (disableAnim) {
      return stack;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(currentIndex),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: stack,
      builder: (context, t, child) {
        return Opacity(
          opacity: 0.82 + (0.18 * t),
          child: Transform.translate(
            offset: Offset(0, 8.0 * (1.0 - t)),
            child: child,
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
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: saku.surface,
        border: Border(top: BorderSide(color: saku.border)),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: saku.cardShadow,
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
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
              const SizedBox(width: 76),
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
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? saku.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
