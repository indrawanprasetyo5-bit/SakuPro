import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/finance_controller.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_widgets.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final FocusNode _focusNode = FocusNode();
  String _entered = '';
  String? _errorMessage;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    if (!widget.controller.biometricEnabled) {
      return;
    }
    final available = await BiometricAuthService.isBiometricAvailable();
    if (!mounted) {
      return;
    }
    setState(() => _biometricSupported = available);
    if (available) {
      await _triggerBiometric();
    }
  }

  Future<void> _triggerBiometric() async {
    final ok = await BiometricAuthService.authenticateUser();
    if (ok && mounted) {
      widget.controller.unlockByBiometrics();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_entered.length >= 4) {
      return;
    }
    HapticFeedback.selectionClick();
    final next = '$_entered$digit';
    setState(() {
      _entered = next;
      _errorMessage = null;
    });

    if (next.length == 4) {
      final unlocked = widget.controller.verifyPinAndUnlock(next);
      if (!unlocked && mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _errorMessage = 'PIN salah, silakan coba kembali.';
        });
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _errorMessage = null;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final label = event.logicalKey.keyLabel;
    if (label.length == 1 && RegExp(r'^[0-9]$').hasMatch(label)) {
      _onDigit(label);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: saku.surface,
                        borderRadius: BorderRadius.circular(SakuRadius.lg),
                        border: Border.all(color: saku.borderStrong, width: 1),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 28,
                        color: saku.brandInteractive,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SakuProWann Terkunci',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan PIN 4 digit buat buka catatan keuanganmu.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(4, (index) {
                        final filled = index < _entered.length;
                        return AnimatedContainer(
                          duration: SakuMotion.fast,
                          curve: SakuMotion.curveOut,
                          margin: const EdgeInsets.symmetric(horizontal: 9),
                          width: filled ? 16 : 14,
                          height: filled ? 16 : 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? saku.brandInteractive
                                : Colors.transparent,
                            border: Border.all(
                              color: filled
                                  ? saku.brandInteractive
                                  : saku.borderStrong,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 22,
                      child: _errorMessage != null
                          ? Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: saku.expense,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    for (final row in const <List<String>>[
                      <String>['1', '2', '3'],
                      <String>['4', '5', '6'],
                      <String>['7', '8', '9'],
                    ]) ...<Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((digit) {
                          return _KeypadButton(
                            label: digit,
                            onTap: () => _onDigit(digit),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        if (widget.controller.biometricEnabled &&
                            _biometricSupported)
                          _KeypadIconButton(
                            icon: Icons.fingerprint_rounded,
                            tooltip: 'Gunakan Sidik Jari / Biometrik',
                            onTap: _triggerBiometric,
                          )
                        else
                          const SizedBox(width: 68, height: 68),
                        _KeypadButton(
                          label: '0',
                          onTap: () => _onDigit('0'),
                        ),
                        _KeypadIconButton(
                          icon: Icons.backspace_outlined,
                          tooltip: 'Hapus digit',
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return TactilePressScale(
      pressedScale: 0.92,
      child: Material(
        color: saku.surface,
        shape: CircleBorder(side: BorderSide(color: saku.border, width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: saku.textPrimary,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  const _KeypadIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return TactilePressScale(
      pressedScale: 0.92,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: saku.surfaceElevated,
          shape: CircleBorder(side: BorderSide(color: saku.border, width: 1)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(icon, size: 24, color: saku.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
