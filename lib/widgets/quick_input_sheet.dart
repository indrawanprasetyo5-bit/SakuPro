import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../services/finance_controller.dart';
import '../services/quick_input_parser.dart';
import '../services/receipt_archive.dart';
import '../services/receipt_ocr_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'luxury_widgets.dart';
import 'wallet_brand_avatar.dart';

enum InputEntryMode { smartNlp, manualForm }

class QuickInputSheet extends StatefulWidget {
  const QuickInputSheet({
    super.key,
    required this.controller,
    this.existingTransaction,
    this.initialMode = InputEntryMode.smartNlp,
    this.initialKind = TransactionKind.expense,
    this.initialSmartText,
    this.initialSourceWalletId,
    this.autoScanSource,
    this.initialReceiptImagePath,
  });

  final FinanceController controller;
  final TransactionModel? existingTransaction;
  final InputEntryMode initialMode;
  final TransactionKind initialKind;
  final String? initialSmartText;
  final int? initialSourceWalletId;
  final ImageSource? autoScanSource;
  final String? initialReceiptImagePath;

  static Future<bool?> show(
    BuildContext context, {
    required FinanceController controller,
    TransactionModel? existingTransaction,
    InputEntryMode initialMode = InputEntryMode.smartNlp,
    TransactionKind initialKind = TransactionKind.expense,
    String? initialSmartText,
    int? initialSourceWalletId,
    ImageSource? autoScanSource,
    String? initialReceiptImagePath,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      sheetAnimationStyle: SakuMotion.sheetStyle,
      builder: (ctx) => QuickInputSheet(
        controller: controller,
        existingTransaction: existingTransaction,
        initialMode: existingTransaction != null
            ? InputEntryMode.manualForm
            : initialMode,
        initialKind: existingTransaction?.kind ?? initialKind,
        initialSmartText: initialSmartText,
        initialSourceWalletId: initialSourceWalletId,
        autoScanSource: autoScanSource,
        initialReceiptImagePath: initialReceiptImagePath,
      ),
    );
  }

  @override
  State<QuickInputSheet> createState() => _QuickInputSheetState();
}

class _QuickInputSheetState extends State<QuickInputSheet> {
  static const List<String> _samplePrompts = <String>[
    'kopi 22rb gopay',
    'bensin 50k cash',
    'makan siang 35000 dana',
    'gaji 5jt bca',
  ];

  static const List<int> _quickIncrements = <int>[
    10000,
    20000,
    50000,
    100000,
    500000,
  ];

  late InputEntryMode _mode;
  late final TextEditingController _smartController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _detailController;

  late TransactionKind _selectedKind;
  late String _selectedCategory;
  int? _selectedWalletId;
  int? _selectedTargetWalletId;
  int? _overrideSmartWalletId;
  late DateTime _selectedDate;
  String _pendingReceiptImagePath = '';
  bool _isSaving = false;
  bool _isScanningOcr = false;
  ScannedReceiptData? _lastScannedReceipt;
  String? _ocrInfoBanner;
  String? _formError;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final wallets = widget.controller.wallets;
    final existing = widget.existingTransaction;

    _mode = existing != null ? InputEntryMode.manualForm : widget.initialMode;
    _smartController = TextEditingController(
      text: widget.initialSmartText ?? '',
    );

    if (existing != null) {
      _selectedKind = existing.kind;
      _selectedCategory = existing.category;
      _selectedWalletId = existing.walletId;
      _selectedTargetWalletId = existing.toWalletId;
      _selectedDate = existing.transactionDate;
      _amountController = TextEditingController(
        text: existing.amount.toString(),
      );
      _noteController = TextEditingController(text: existing.note);
      _detailController = TextEditingController(text: existing.receiptDetail);
      _pendingReceiptImagePath = existing.receiptImagePath;
    } else {
      _selectedKind = widget.initialKind;
      _selectedCategory = CategoryCatalog.forKind(_selectedKind).first.name;
      _selectedWalletId =
          widget.initialSourceWalletId ??
          (wallets.isNotEmpty ? wallets.first.id : null);
      _selectedTargetWalletId = _pickDefaultTargetWallet(_selectedWalletId);
      _selectedDate = widget.controller.now;
      _amountController = TextEditingController();
      _noteController = TextEditingController();
      _detailController = TextEditingController();
      _pendingReceiptImagePath = '';
    }

    if (widget.initialReceiptImagePath != null && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleScanSharedFile(widget.initialReceiptImagePath!);
        }
      });
    } else if (widget.autoScanSource != null && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleScanReceipt(widget.autoScanSource!);
        }
      });
    }
  }

  int? _pickDefaultTargetWallet(int? sourceId) {
    for (final w in widget.controller.wallets) {
      if (w.id != sourceId) {
        return w.id;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _smartController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  ParsedQuickInput _currentParsed() {
    var parsed = QuickInputParser.parse(
      _smartController.text,
      widget.controller.wallets,
    );
    if (!parsed.hasExplicitCategory &&
        parsed.kind != TransactionKind.transfer &&
        parsed.note.isNotEmpty) {
      final learned = widget.controller.lookupLearnedCategory(parsed.note);
      if (learned != null) {
        parsed = ParsedQuickInput(
          rawText: parsed.rawText,
          kind: parsed.kind,
          amount: parsed.amount,
          category: learned,
          note: parsed.note,
          wallet: parsed.wallet,
          toWallet: parsed.toWallet,
          hasExplicitAmount: parsed.hasExplicitAmount,
          hasExplicitWallet: parsed.hasExplicitWallet,
          hasExplicitCategory: true,
        );
      }
    }
    if (_overrideSmartWalletId != null && !parsed.hasExplicitWallet) {
      final chosen = widget.controller.walletById(_overrideSmartWalletId);
      if (chosen != null) {
        return ParsedQuickInput(
          rawText: parsed.rawText,
          kind: parsed.kind,
          amount: parsed.amount,
          category: parsed.category,
          note: parsed.note,
          wallet: chosen,
          toWallet: parsed.toWallet,
          hasExplicitAmount: parsed.hasExplicitAmount,
          hasExplicitWallet: false,
          hasExplicitCategory: parsed.hasExplicitCategory,
        );
      }
    }
    return parsed;
  }

  void _transferSmartToManual(ParsedQuickInput parsed) {
    setState(() {
      _mode = InputEntryMode.manualForm;
      _selectedKind = parsed.kind;
      final validCategories = CategoryCatalog.forKind(parsed.kind);
      final matched = validCategories.any((c) => c.name == parsed.category);
      _selectedCategory = matched ? parsed.category : validCategories.first.name;
      if (parsed.amount != null && parsed.amount! > 0) {
        _amountController.text = parsed.amount.toString();
      }
      if (parsed.note.isNotEmpty) {
        _noteController.text = parsed.note;
      }
      if (parsed.wallet?.id != null) {
        _selectedWalletId = parsed.wallet!.id;
      }
      if (parsed.toWallet?.id != null) {
        _selectedTargetWalletId = parsed.toWallet!.id;
      } else {
        _selectedTargetWalletId ??= _pickDefaultTargetWallet(_selectedWalletId);
      }
      _formError = null;
    });
  }

  int _parseManualAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _incrementManualAmount(int addend) {
    final next = _parseManualAmount() + addend;
    setState(() {
      _amountController.text = next.toString();
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
      _formError = null;
    });
  }

  Future<void> _saveFromSmart(ParsedQuickInput parsed) async {
    if (!parsed.isReadyToSave || _isSaving) {
      setState(() {
        _formError =
            'Masukkan kalimat dengan nominal jelas, misalnya: kopi 22rb gopay';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _formError = null;
    });

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
        transactionDate: _selectedDate,
        createdAt: now,
      );
      await widget.controller.addTransaction(tx);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _formError = 'Gagal menyimpan transaksi: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _saveFromManual() async {
    if (_isSaving) {
      return;
    }
    final amount = _parseManualAmount();
    if (amount <= 0) {
      setState(() {
        _formError = 'Masukkan nominal lebih dari Rp 0.';
      });
      return;
    }
    if (_selectedWalletId == null) {
      setState(() {
        _formError = 'Pilih dompet terlebih dahulu.';
      });
      return;
    }
    if (_selectedKind == TransactionKind.transfer) {
      if (_selectedTargetWalletId == null ||
          _selectedTargetWalletId == _selectedWalletId) {
        setState(() {
          _formError = 'Pilih dompet tujuan yang berbeda dari dompet asal.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    try {
      final now = widget.controller.now;
      final cleanNote = _noteController.text.trim();
      final cleanDetail = _detailController.text.trim();
      final savedImagePath = _pendingReceiptImagePath.trim().isNotEmpty
          ? await ReceiptArchive.archiveIfNeeded(_pendingReceiptImagePath)
          : '';
      final category = _selectedKind == TransactionKind.transfer
          ? CategoryCatalog.transferMeta.name
          : _selectedCategory;

      if (_isEditing) {
        final existing = widget.existingTransaction!;
        final updated = existing.copyWith(
          kind: _selectedKind,
          amount: amount,
          category: category,
          note: cleanNote,
          walletId: _selectedWalletId!,
          toWalletId: _selectedKind == TransactionKind.transfer
              ? _selectedTargetWalletId
              : null,
          clearToWallet: _selectedKind != TransactionKind.transfer,
          transactionDate: _selectedDate,
          receiptDetail: cleanDetail,
          receiptImagePath: savedImagePath,
        );
        await widget.controller.updateTransaction(updated);
      } else {
        final tx = TransactionModel(
          kind: _selectedKind,
          amount: amount,
          category: category,
          note: cleanNote,
          walletId: _selectedWalletId!,
          toWalletId: _selectedKind == TransactionKind.transfer
              ? _selectedTargetWalletId
              : null,
          transactionDate: _selectedDate,
          createdAt: now,
          receiptDetail: cleanDetail,
          receiptImagePath: savedImagePath,
        );
        await widget.controller.addTransaction(tx);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _formError = 'Gagal menyimpan transaksi: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final current = _selectedDate;
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          current.hour,
          current.minute,
        );
      });
    }
  }

  Future<void> _handleScanReceipt(ImageSource source) async {
    if (_isScanningOcr) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isScanningOcr = true;
      _formError = null;
      _ocrInfoBanner = null;
      _lastScannedReceipt = null;
    });

    // Allow popup menu route and soft keyboard to settle before launching camera activity.
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) {
      return;
    }

    try {
      final result = await ReceiptOcrService.scanReceipt(source: source);
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() => _isScanningOcr = false);
        return;
      }

      _applyScannedResult(result);
    } on ReceiptOcrException catch (e) {
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
          _formError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
          _formError = 'Gagal membaca struk: $e';
        });
      }
    }
  }

  Future<void> _handleScanSharedFile(String filePath) async {
    if (_isScanningOcr) {
      return;
    }
    setState(() {
      _isScanningOcr = true;
      _mode = InputEntryMode.manualForm;
      _formError = null;
      _ocrInfoBanner = null;
      _lastScannedReceipt = null;
    });

    try {
      final result = await ReceiptOcrService.scanReceiptFile(filePath);
      if (!mounted) {
        return;
      }
      _applyScannedResult(result);
    } on ReceiptOcrException catch (e) {
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
          _formError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
          _formError = 'Gagal membaca gambar yang dibagikan: $e';
        });
      }
    }
  }

  int? _matchWalletIdByName(String? detectedName) {
    if (detectedName == null || detectedName.trim().isEmpty) {
      return null;
    }
    final normalized = detectedName.toLowerCase().trim();
    final aliases = <String>{
      normalized,
      if (normalized.contains('jago')) 'jago',
      if (normalized.contains('seabank')) 'seabank',
      if (normalized.contains('shopeepay')) 'shopee',
      if (normalized.contains('gopay')) 'gopay',
      if (normalized.contains('dana')) 'dana',
      if (normalized.contains('ovo')) 'ovo',
      if (normalized.contains('bca')) 'bca',
      if (normalized.contains('mandiri')) 'mandiri',
      if (normalized.contains('bri')) 'bri',
      if (normalized.contains('blu')) 'blu',
    };

    for (final w in widget.controller.wallets) {
      final wName = w.name.toLowerCase().trim();
      if (aliases.contains(wName)) {
        return w.id;
      }
    }
    for (final w in widget.controller.wallets) {
      final wName = w.name.toLowerCase().trim();
      if (wName.length < 3) {
        continue;
      }
      for (final alias in aliases) {
        if (wName.contains(alias) || alias.contains(wName)) {
          return w.id;
        }
      }
    }
    return null;
  }

  void _applyScannedResult(ScannedReceiptData result) {
    final detectedKind = result.suggestedKind;
    final validCategories = CategoryCatalog.forKind(detectedKind);

    String? pickValidLearned(String? text) {
      if (text == null || text.trim().isEmpty) {
        return null;
      }
      final candidate = widget.controller.lookupLearnedCategory(text);
      if (candidate != null &&
          validCategories.any((c) => c.name == candidate)) {
        return candidate;
      }
      return null;
    }

    final learned =
        pickValidLearned(result.merchantName) ??
        pickValidLearned(result.transferNote);
    final preferredCat = learned ?? result.suggestedCategory;
    final resolvedCategory = validCategories.any((c) => c.name == preferredCat)
        ? preferredCat
        : validCategories.first.name;
    final matchedWalletId = _matchWalletIdByName(result.detectedWalletName);

    final summaryBits = <String>[
      if (result.totalAmount != null) IdrFormat.currency(result.totalAmount!),
      resolvedCategory,
      if (result.items.isNotEmpty) '${result.items.length} item',
      if (result.detectedWalletName != null) result.detectedWalletName!,
    ];

    setState(() {
      _isScanningOcr = false;
      _lastScannedReceipt = result;
      _mode = InputEntryMode.manualForm;
      _selectedKind = detectedKind;
      _selectedCategory = resolvedCategory;
      if (matchedWalletId != null) {
        _selectedWalletId = matchedWalletId;
      }
      _noteController.text = result.merchantName;
      _detailController.text = result.receiptDetailText;
      _pendingReceiptImagePath = result.sourceImagePath ?? '';
      if (result.totalAmount != null && result.totalAmount! > 0) {
        _amountController.text = result.totalAmount.toString();
      }
      _ocrInfoBanner = result.totalAmount != null
          ? 'Struk "${result.merchantName}" terbaca (${summaryBits.join(' · ')}).'
          : 'Toko "${result.merchantName}" terbaca, silakan cek atau isi nominal total.';
    });
  }

  void _showScannedTextDialog(ScannedReceiptData data) {
    final previewText = data.reconstructedLines.isNotEmpty
        ? data.reconstructedLines.join('\n')
        : data.rawText;

    showSakuBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final saku = ctx.saku;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SakuSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Teks Hasil Scan Struk',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: saku.surfaceElevated,
                    borderRadius: BorderRadius.circular(SakuRadius.md),
                    border: Border.all(color: saku.border, width: 1),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      previewText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.48,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: previewText),
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Teks scan disalin ke clipboard.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Salin Teks'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final parsed = _currentParsed();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: saku.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Transaksi' : 'Catat Transaksi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!_isEditing)
                  PopupMenuButton<ImageSource>(
                    tooltip: 'Scan Struk Belanja',
                    enabled: !_isScanningOcr,
                    onSelected: _handleScanReceipt,
                    itemBuilder: (ctx) => const <PopupMenuEntry<ImageSource>>[
                      PopupMenuItem<ImageSource>(
                        value: ImageSource.camera,
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.photo_camera_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Foto Struk (Kamera)'),
                          ],
                        ),
                      ),
                      PopupMenuItem<ImageSource>(
                        value: ImageSource.gallery,
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.photo_library_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Pilih Foto Struk (Galeri)'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: saku.brandSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_isScanningOcr)
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: saku.brandInteractive,
                              ),
                            )
                          else
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 16,
                              color: saku.brandInteractive,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _isScanningOcr ? 'Memindai...' : 'Scan Struk',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: saku.brandInteractive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Tutup',
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            if (_ocrInfoBanner != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: saku.incomeSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: saku.income.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 17,
                            color: saku.income,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ocrInfoBanner!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: saku.income,
                            ),
                          ),
                        ),
                        if (_lastScannedReceipt != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _showScannedTextDialog(_lastScannedReceipt!),
                            child: Text(
                              'Lihat Teks',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: saku.income,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_lastScannedReceipt != null &&
                        _lastScannedReceipt!.amountCandidates.length >
                            1) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Kandidat nominal lain pada struk (ketuk untuk ganti):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: saku.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _lastScannedReceipt!.amountCandidates.map((
                          cand,
                        ) {
                          final isCurrent =
                              _parseManualAmount() == cand.amount;
                          return ChoiceChip(
                            label: Text(
                              '${cand.label} · ${IdrFormat.currency(cand.amount)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFeatures: AppTheme.tabularNums,
                              ),
                            ),
                            selected: isCurrent,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) {
                              setState(() {
                                _amountController.text = cand.amount.toString();
                                _amountController.selection =
                                    TextSelection.collapsed(
                                      offset: _amountController.text.length,
                                    );
                                _formError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (!_isEditing) ...<Widget>[
              const SizedBox(height: 8),
              _buildModeSelector(saku),
            ],
            const SizedBox(height: 16),
            if (_mode == InputEntryMode.smartNlp && !_isEditing)
              _buildSmartNlpBody(context, saku, parsed)
            else
              _buildManualFormBody(context, saku),
            if (_formError != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: saku.expenseSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: saku.expense,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: saku.expense,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(SakuColors saku) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: saku.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: saku.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeTabButton(
              label: 'Ketik Cepat (3 dtk)',
              icon: Icons.edit_note_rounded,
              selected: _mode == InputEntryMode.smartNlp,
              onTap: () => setState(() {
                _mode = InputEntryMode.smartNlp;
                _formError = null;
              }),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeTabButton(
              label: 'Form Lengkap',
              icon: Icons.tune_rounded,
              selected: _mode == InputEntryMode.manualForm,
              onTap: () => _transferSmartToManual(_currentParsed()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartNlpBody(
    BuildContext context,
    SakuColors saku,
    ParsedQuickInput parsed,
  ) {
    final kindColor = _colorForKind(saku, parsed.kind);
    final kindSoft = _softColorForKind(saku, parsed.kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Kalimat Transaksi',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smartController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _formError = null),
          onSubmitted: (_) => _saveFromSmart(_currentParsed()),
          decoration: InputDecoration(
            hintText: 'Ketik mis. "kopi 22rb gopay" atau "gaji 5jt bca"',
            prefixIcon: Icon(
              Icons.edit_note_rounded,
              color: saku.brandInteractive,
            ),
            suffixIcon: _smartController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Bersihkan teks',
                    onPressed: () => setState(() {
                      _smartController.clear();
                      _formError = null;
                    }),
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: saku.textMuted,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _samplePrompts.map((sample) {
            return ActionChip(
              label: Text(sample, style: const TextStyle(fontSize: 12.5)),
              backgroundColor: saku.surface,
              side: BorderSide(color: saku.border),
              onPressed: () {
                setState(() {
                  _smartController.text = sample;
                  _smartController.selection = TextSelection.collapsed(
                    offset: sample.length,
                  );
                  _formError = null;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: saku.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: parsed.isReadyToSave
                  ? saku.brandInteractive.withValues(alpha: 0.5)
                  : saku.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kindSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _iconForKind(parsed.kind),
                            size: 14,
                            color: kindColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              parsed.kind.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kindColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _transferSmartToManual(parsed),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Sesuaikan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parsed.amount != null
                    ? IdrFormat.currency(parsed.amount!)
                    : 'Nominal belum terdeteksi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: parsed.amount != null
                      ? saku.textPrimary
                      : saku.textMuted,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PreviewTag(
                    icon: CategoryCatalog.resolve(
                      parsed.kind,
                      parsed.category,
                    ).icon,
                    label: parsed.category,
                  ),
                  _PreviewTag(
                    icon: Icons.account_balance_wallet_outlined,
                    label: parsed.kind == TransactionKind.transfer
                        ? '${parsed.wallet?.name ?? '-'} -> ${parsed.toWallet?.name ?? '-'}'
                        : (parsed.wallet?.name ?? 'Pilih dompet'),
                  ),
                  if (parsed.note.isNotEmpty)
                    _PreviewTag(
                      icon: Icons.notes_rounded,
                      label: parsed.note,
                    ),
                ],
              ),
              if (!parsed.hasExplicitWallet &&
                  widget.controller.wallets.length > 1) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Dompet default dipilih otomatis, ketuk jika ingin ganti:',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.controller.wallets.map((w) {
                      final active = parsed.wallet?.id == w.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: WalletBrandAvatar.fromWallet(
                            w,
                            size: 20,
                            borderRadius: 6,
                          ),
                          label: Text(w.name),
                          selected: active,
                          onSelected: (_) => setState(() {
                            _overrideSmartWalletId = w.id;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: parsed.isReadyToSave && !_isSaving
              ? () => _saveFromSmart(parsed)
              : null,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: Text(
            parsed.isReadyToSave
                ? 'Simpan ${parsed.kind.label} (${IdrFormat.currency(parsed.amount!)})'
                : 'Ketik kalimat & nominal untuk menyimpan',
          ),
        ),
      ],
    );
  }

  Widget _buildManualFormBody(BuildContext context, SakuColors saku) {
    final categories = CategoryCatalog.forKind(_selectedKind);
    final manualAmount = _parseManualAmount();
    final dateLabel = DateFormat('dd MMM yyyy').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: TransactionKind.values.map((kind) {
            final isSelected = _selectedKind == kind;
            final activeColor = _colorForKind(saku, kind);
            final activeSoft = _softColorForKind(saku, kind);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: kind != TransactionKind.transfer ? 6 : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _selectedKind = kind;
                      final valid = CategoryCatalog.forKind(kind);
                      if (!valid.any((c) => c.name == _selectedCategory)) {
                        _selectedCategory = valid.first.name;
                      }
                      if (kind == TransactionKind.transfer &&
                          (_selectedTargetWalletId == null ||
                              _selectedTargetWalletId == _selectedWalletId)) {
                        _selectedTargetWalletId = _pickDefaultTargetWallet(
                          _selectedWalletId,
                        );
                      }
                      _formError = null;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? activeSoft : saku.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? activeColor : saku.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _iconForKind(kind),
                          size: 16,
                          color: isSelected ? activeColor : saku.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            kind.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? activeColor
                                  : saku.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedKind == TransactionKind.transfer) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: saku.transferSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: saku.transfer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transfer memindahkan saldo antar dompet tanpa dihitung sebagai pengeluaran.',
                    style: TextStyle(fontSize: 12, color: saku.transfer),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Nominal (Rp)', style: Theme.of(context).textTheme.labelLarge),
            if (manualAmount > 0)
              Text(
                IdrFormat.currency(manualAmount),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: saku.brandInteractive,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: saku.textPrimary,
            fontFeatures: AppTheme.tabularNums,
          ),
          onChanged: (_) => setState(() => _formError = null),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: saku.textSecondary,
            ),
            hintText: '0',
            suffixIcon: _amountController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Reset nominal',
                    onPressed: () => setState(() {
                      _amountController.clear();
                    }),
                    icon: Icon(
                      Icons.backspace_outlined,
                      size: 18,
                      color: saku.textMuted,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickIncrements.map((inc) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _incrementManualAmount(inc),
                  child: Text(
                    '+${IdrFormat.compact(inc).replaceFirst('Rp ', '')}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _selectedKind == TransactionKind.transfer ? 'Dari Dompet' : 'Dompet',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _WalletChipSelector(
          wallets: widget.controller.wallets,
          selectedId: _selectedWalletId,
          hideBalance: widget.controller.hideBalance,
          onSelect: (id) {
            setState(() {
              _selectedWalletId = id;
              if (_selectedKind == TransactionKind.transfer &&
                  _selectedTargetWalletId == id) {
                _selectedTargetWalletId = _pickDefaultTargetWallet(id);
              }
              _formError = null;
            });
          },
        ),
        if (_selectedKind == TransactionKind.transfer) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text('Ke Dompet', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed:
                    _selectedWalletId != null && _selectedTargetWalletId != null
                    ? () {
                        setState(() {
                          final tmp = _selectedWalletId;
                          _selectedWalletId = _selectedTargetWalletId;
                          _selectedTargetWalletId = tmp;
                        });
                      }
                    : null,
                icon: const Icon(Icons.swap_vert_rounded, size: 16),
                label: const Text(
                  'Tukar Posisi',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          _WalletChipSelector(
            wallets: widget.controller.wallets,
            selectedId: _selectedTargetWalletId,
            disabledId: _selectedWalletId,
            hideBalance: widget.controller.hideBalance,
            onSelect: (id) {
              setState(() {
                _selectedTargetWalletId = id;
                _formError = null;
              });
            },
          ),
        ] else ...<Widget>[
          const SizedBox(height: 14),
          Text('Kategori', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final active = cat.name == _selectedCategory;
              return ChoiceChip(
                avatar: Icon(
                  cat.icon,
                  size: 16,
                  color: active ? saku.brandInteractive : cat.color,
                ),
                label: Text(cat.name),
                selected: active,
                onSelected: (_) => setState(() {
                  _selectedCategory = cat.name;
                }),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _noteController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Mis. Kopi susu, makan siang...',
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _detailController,
          minLines: 2,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Rincian Struk / Detail Item (opsional)',
            hintText: 'Otomatis terisi saat scan struk atau bagikan resi e-wallet',
            alignLabelWithHint: true,
          ),
        ),
        if (_pendingReceiptImagePath.isNotEmpty &&
            ReceiptArchive.existsSync(_pendingReceiptImagePath)) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: saku.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: saku.border),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: ReceiptArchive.buildImage(
                      _pendingReceiptImagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Foto struk terlampir',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textPrimary,
                        ),
                      ),
                      Text(
                        'Bisa dilihat lagi di detail transaksi',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: saku.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus lampiran foto',
                  onPressed: () {
                    setState(() => _pendingReceiptImagePath = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: saku.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveFromManual,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: Text(
            _isEditing
                ? 'Simpan Perubahan'
                : _selectedKind == TransactionKind.transfer
                ? 'Proses Transfer Antar Dompet'
                : 'Simpan ${_selectedKind.label}',
          ),
        ),
      ],
    );
  }

  Color _colorForKind(SakuColors saku, TransactionKind kind) {
    switch (kind) {
      case TransactionKind.expense:
        return saku.expense;
      case TransactionKind.income:
        return saku.income;
      case TransactionKind.transfer:
        return saku.transfer;
    }
  }

  Color _softColorForKind(SakuColors saku, TransactionKind kind) {
    switch (kind) {
      case TransactionKind.expense:
        return saku.expenseSoft;
      case TransactionKind.income:
        return saku.incomeSoft;
      case TransactionKind.transfer:
        return saku.transferSoft;
    }
  }

  IconData _iconForKind(TransactionKind kind) {
    switch (kind) {
      case TransactionKind.expense:
        return Icons.south_west_rounded;
      case TransactionKind.income:
        return Icons.north_east_rounded;
      case TransactionKind.transfer:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return Material(
      color: selected ? saku.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected ? saku.brandInteractive : saku.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? saku.textPrimary : saku.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: saku.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: saku.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: saku.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletChipSelector extends StatelessWidget {
  const _WalletChipSelector({
    required this.wallets,
    required this.selectedId,
    required this.onSelect,
    required this.hideBalance,
    this.disabledId,
  });

  final List<WalletModel> wallets;
  final int? selectedId;
  final int? disabledId;
  final bool hideBalance;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: wallets.map((w) {
          final id = w.id;
          if (id == null) {
            return const SizedBox.shrink();
          }
          final selected = id == selectedId;
          final disabled = id == disabledId;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Opacity(
              opacity: disabled ? 0.45 : 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: disabled ? null : () => onSelect(id),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? saku.brandSoft : saku.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? saku.brandInteractive : saku.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      WalletBrandAvatar.fromWallet(
                        w,
                        size: 28,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            w.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: saku.textPrimary,
                            ),
                          ),
                          Text(
                            IdrFormat.compact(w.balance, hidden: hideBalance),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: saku.textSecondary,
                              fontFeatures: AppTheme.tabularNums,
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
        }).toList(),
      ),
    );
  }
}
