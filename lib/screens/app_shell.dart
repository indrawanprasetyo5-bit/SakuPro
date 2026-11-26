import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/transaction_item.dart';
import '../services/automation_bridge_service.dart';
import '../services/finance_controller.dart';
import '../services/quick_input_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import '../widgets/luxury_widgets.dart';
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

  bool _isQuickTyping = false;
  bool _isSavingInline = false;
  final TextEditingController _quickBarController = TextEditingController();
  final FocusNode _quickBarFocusNode = FocusNode();

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
    _quickBarController.dispose();
    _quickBarFocusNode.dispose();
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
      _syncAutomationsOnResume();
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
    if (!mounted ||
        _isHandlingExternalIntent ||
        widget.controller.isSessionLocked) {
      return;
    }
    _closeQuickTyping();
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
    if (!mounted ||
        _isHandlingExternalIntent ||
        widget.controller.isSessionLocked) {
      return;
    }
    _closeQuickTyping();
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
            const SnackBar(content: Text('Struk berhasil dicatat.')),
          );
        }
      } else if (action == 'quick_input') {
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
    } finally {
      _isHandlingExternalIntent = false;
    }
  }

  Future<void> _syncAutomationsOnResume() async {
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
  }

  void _openQuickTyping() {
    HapticFeedback.selectionClick();
    setState(() => _isQuickTyping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isQuickTyping) {
        _quickBarFocusNode.requestFocus();
      }
    });
  }

  void _closeQuickTyping() {
    if (!_isQuickTyping) {
      return;
    }
    _quickBarFocusNode.unfocus();
    setState(() {
      _isQuickTyping = false;
      _quickBarController.clear();
    });
  }

  Future<void> _submitInlineQuickAdd() async {
    if (_isSavingInline) {
      return;
    }
    final raw = _quickBarController.text.trim();
    if (raw.isEmpty) {
      _closeQuickTyping();
      return;
    }

    final parsed = QuickInputParser.parse(raw, widget.controller.wallets);
    if (!parsed.isReadyToSave) {
      // Fall back to the full interactive sheet prefilled with their text
      // when an amount or destination wallet needs confirmation.
      _closeQuickTyping();
      final saved = await QuickInputSheet.show(
        context,
        controller: widget.controller,
        initialSmartText: raw,
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi masuk buku kas.')),
        );
      }
      return;
    }

    setState(() => _isSavingInline = true);
    try {
      final now = widget.controller.now;
      final tx = TransactionModel(
        kind: parsed.kind,
        amount: parsed.amount!,
        category: parsed.category,
        note: parsed.note,
        walletId: parsed.wallet!.id!,
        toWalletId: parsed.kind == TransactionKind.transfer
            ? parsed.toWallet?.id
            : null,
        transactionDate: now,
        createdAt: now,
      );
      await widget.controller.addTransaction(tx);
      HapticFeedback.lightImpact();

      final savedTx = widget.controller.transactions.isNotEmpty
          ? widget.controller.transactions.first
          : null;

      if (mounted) {
        _closeQuickTyping();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Tercatat: ${tx.displayTitle} · ${IdrFormat.currency(tx.amount)}',
              ),
              action: savedTx?.id != null
                  ? SnackBarAction(
                      label: 'Urungkan',
                      onPressed: () {
                        widget.controller.deleteTransaction(savedTx!.id!);
                      },
                    )
                  : null,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingInline = false);
      }
    }
  }

  Future<void> _openQuickInput() async {
    _closeQuickTyping();
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
    _closeQuickTyping();
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
                systemNavigationBarColor: context.saku.background,
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
      return const BentoSkeletonScreen();
    }

    if (widget.controller.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LuxurySurfaceCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
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
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
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

    final saku = context.saku;
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 700) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              NavigationRail(
                backgroundColor: saku.background,
                selectedIndex: _currentIndex,
                onDestinationSelected: _selectTab,
                labelType: NavigationRailLabelType.all,
                indicatorColor: saku.brandSoft,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: TactilePressScale(
                    child: FloatingActionButton(
                      onPressed: _openQuickInput,
                      tooltip: 'Catat Transaksi Cepat',
                      elevation: 0,
                      backgroundColor: saku.brandPrimary,
                      foregroundColor: saku.brandOnPrimary,
                      child: const Icon(Icons.add_rounded, size: 28),
                    ),
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
              VerticalDivider(width: 1, color: saku.border),
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

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          _SeamlessTabStack(
            currentIndex: _currentIndex,
            children: pages,
          ),
          if (_isQuickTyping)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeQuickTyping,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_currentIndex <= 1 || _isQuickTyping)
              _QuickAddDockBar(
                controller: widget.controller,
                textController: _quickBarController,
                focusNode: _quickBarFocusNode,
                isTyping: _isQuickTyping,
                isSaving: _isSavingInline,
                onActivateTyping: _openQuickTyping,
                onCloseTyping: _closeQuickTyping,
                onSubmitInline: _submitInlineQuickAdd,
                onOpenFullSheet: _openQuickInput,
              ),
            if (!_isQuickTyping)
              _SakuBottomBar(
                currentIndex: _currentIndex,
                onTap: _selectTab,
                showTopBorder: _currentIndex > 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddDockBar extends StatefulWidget {
  const _QuickAddDockBar({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.isTyping,
    required this.isSaving,
    required this.onActivateTyping,
    required this.onCloseTyping,
    required this.onSubmitInline,
    required this.onOpenFullSheet,
  });

  final FinanceController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final bool isTyping;
  final bool isSaving;
  final VoidCallback onActivateTyping;
  final VoidCallback onCloseTyping;
  final VoidCallback onSubmitInline;
  final VoidCallback onOpenFullSheet;

  @override
  State<_QuickAddDockBar> createState() => _QuickAddDockBarState();
}

class _QuickAddDockBarState extends State<_QuickAddDockBar> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _QuickAddDockBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applyPreset(String phrase) {
    HapticFeedback.selectionClick();
    widget.textController.text = phrase;
    widget.textController.selection = TextSelection.collapsed(
      offset: phrase.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final raw = widget.textController.text.trim();
    final parsed = widget.isTyping && raw.isNotEmpty
        ? QuickInputParser.parse(raw, widget.controller.wallets)
        : null;
    final presets = widget.isTyping && raw.isEmpty
        ? widget.controller.smartQuickPresets
        : const <QuickHabitPreset>[];

    return Container(
      decoration: BoxDecoration(
        color: saku.background.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: saku.border, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        widget.isTyping ? 10 : 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (presets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: presets.map((preset) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TactilePressScale(
                        child: ActionChip(
                          avatar: preset.isLearned
                              ? Icon(
                                  Icons.history_rounded,
                                  size: 14,
                                  color: saku.brandInteractive,
                                )
                              : null,
                          label: Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: saku.textPrimary,
                              fontFeatures: AppTheme.tabularNums,
                            ),
                          ),
                          onPressed: () => _applyPreset(preset.phrase),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (parsed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: saku.surface,
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  border: Border.all(
                    color: parsed.isReadyToSave
                        ? saku.brandInteractive.withValues(alpha: 0.45)
                        : saku.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      parsed.isReadyToSave
                          ? Icons.check_circle_rounded
                          : Icons.edit_note_rounded,
                      size: 16,
                      color: parsed.isReadyToSave
                          ? saku.brandInteractive
                          : saku.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        parsed.isReadyToSave
                            ? '${parsed.category} · ${parsed.wallet?.name ?? 'Dompet'}'
                            : 'Tambah nominal, misal: kopi 25rb gopay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: parsed.isReadyToSave
                              ? saku.textPrimary
                              : saku.textSecondary,
                        ),
                      ),
                    ),
                    if (parsed.isReadyToSave && parsed.amount != null) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        IdrFormat.currency(
                          parsed.kind == TransactionKind.expense
                              ? -parsed.amount!
                              : parsed.amount!,
                          signed: parsed.kind == TransactionKind.income,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: parsed.kind == TransactionKind.income
                              ? saku.income
                              : parsed.kind == TransactionKind.transfer
                              ? saku.transfer
                              : saku.expense,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: widget.isTyping
                    ? Container(
                        decoration: BoxDecoration(
                          color: saku.surface,
                          borderRadius: BorderRadius.circular(SakuRadius.pill),
                          border: Border.all(
                            color: saku.brandInteractive,
                            width: 1.4,
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: widget.textController,
                                focusNode: widget.focusNode,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => widget.onSubmitInline(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: saku.textPrimary,
                                  fontFeatures: AppTheme.tabularNums,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  hintText: 'Ketik cepat: kopi 25rb gopay',
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: saku.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tutup',
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              onPressed: widget.onCloseTyping,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: saku.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TactilePressScale(
                        pressedScale: 0.98,
                        child: Material(
                          color: saku.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SakuRadius.pill),
                            side: BorderSide(color: saku.border, width: 1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(SakuRadius.pill),
                            onTap: widget.onActivateTyping,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 11,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 19,
                                    color: saku.brandInteractive,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Ketik cepat... kopi 25rb gopay',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: saku.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              TactilePressScale(
                child: Material(
                  color: saku.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SakuRadius.pill),
                  ),
                  child: IconButton(
                    tooltip: widget.isTyping
                        ? 'Kirim Transaksi'
                        : 'Catat Transaksi Cepat',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: widget.isSaving
                        ? null
                        : widget.isTyping
                        ? widget.onSubmitInline
                        : widget.onOpenFullSheet,
                    icon: Icon(
                      widget.isTyping
                          ? Icons.arrow_upward_rounded
                          : Icons.add_rounded,
                      size: 24,
                      color: saku.brandOnPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      duration: SakuMotion.normal,
      curve: SakuMotion.curveOut,
      child: stack,
      builder: (context, t, child) {
        return Opacity(
          opacity: 0.85 + (0.15 * t),
          child: Transform.translate(
            offset: Offset(0, 6.0 * (1.0 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class _SakuBottomBar extends StatelessWidget {
  const _SakuBottomBar({
    required this.currentIndex,
    required this.onTap,
    this.showTopBorder = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return Container(
      decoration: BoxDecoration(
        color: saku.background,
        border: showTopBorder
            ? Border(top: BorderSide(color: saku.border, width: 1))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
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
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: SakuMotion.fast,
              curve: SakuMotion.curveOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? saku.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(SakuRadius.pill),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
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
