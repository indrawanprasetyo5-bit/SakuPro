import 'package:material_ui/material_ui.dart';

import '../models/wallet.dart';

enum WalletBrandId {
  seabank,
  dana,
  gopay,
  jago,
  bca,
  mandiri,
  bri,
  ovo,
  shopeepay,
  blu,
  cash,
  savings,
  custom,
}

class WalletBrandSpec {
  const WalletBrandSpec({
    required this.id,
    required this.displayName,
    required this.walletKind,
    required this.primaryColor,
    required this.secondaryColor,
    required this.foregroundColor,
    required this.badgeText,
    required this.accentColor,
    this.italicText = false,
  });

  final WalletBrandId id;
  final String displayName;
  final WalletKind walletKind;
  final Color primaryColor;
  final Color secondaryColor;
  final Color foregroundColor;
  final String badgeText;
  final Color accentColor;
  final bool italicText;
}

class WalletBrandCatalog {
  WalletBrandCatalog._();

  static const List<WalletBrandSpec> quickPresets = <WalletBrandSpec>[
    seabank,
    dana,
    gopay,
    jago,
    bca,
    mandiri,
    bri,
    ovo,
    shopeepay,
    blu,
  ];

  static const WalletBrandSpec seabank = WalletBrandSpec(
    id: WalletBrandId.seabank,
    displayName: 'SeaBank',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFEA580C),
    foregroundColor: Colors.white,
    badgeText: 'Sea',
    accentColor: Color(0xFFFDE68A),
  );

  static const WalletBrandSpec dana = WalletBrandSpec(
    id: WalletBrandId.dana,
    displayName: 'DANA',
    walletKind: WalletKind.ewallet,
    primaryColor: Color(0xFF118EEA),
    secondaryColor: Color(0xFF0A6EC2),
    foregroundColor: Colors.white,
    badgeText: 'DANA',
    accentColor: Color(0xFFBAE6FD),
  );

  static const WalletBrandSpec gopay = WalletBrandSpec(
    id: WalletBrandId.gopay,
    displayName: 'GoPay',
    walletKind: WalletKind.ewallet,
    primaryColor: Color(0xFF00AED6),
    secondaryColor: Color(0xFF0086A8),
    foregroundColor: Colors.white,
    badgeText: 'gopay',
    accentColor: Color(0xFFA5F3FC),
  );

  static const WalletBrandSpec jago = WalletBrandSpec(
    id: WalletBrandId.jago,
    displayName: 'Bank Jago',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFFFACC15),
    secondaryColor: Color(0xFFF59E0B),
    foregroundColor: Color(0xFF1E1B4B),
    badgeText: 'Jago',
    accentColor: Color(0xFF7C3AED),
  );

  static const WalletBrandSpec bca = WalletBrandSpec(
    id: WalletBrandId.bca,
    displayName: 'BCA',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFF00529C),
    secondaryColor: Color(0xFF00376B),
    foregroundColor: Colors.white,
    badgeText: 'BCA',
    accentColor: Color(0xFF60A5FA),
    italicText: true,
  );

  static const WalletBrandSpec mandiri = WalletBrandSpec(
    id: WalletBrandId.mandiri,
    displayName: 'Mandiri',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFF003D79),
    secondaryColor: Color(0xFF002752),
    foregroundColor: Colors.white,
    badgeText: 'bmri',
    accentColor: Color(0xFFFBBF24),
  );

  static const WalletBrandSpec bri = WalletBrandSpec(
    id: WalletBrandId.bri,
    displayName: 'BRI',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFF00529C),
    secondaryColor: Color(0xFF003A70),
    foregroundColor: Colors.white,
    badgeText: 'BRI',
    accentColor: Color(0xFFF97316),
  );

  static const WalletBrandSpec ovo = WalletBrandSpec(
    id: WalletBrandId.ovo,
    displayName: 'OVO',
    walletKind: WalletKind.ewallet,
    primaryColor: Color(0xFF5B3FA8),
    secondaryColor: Color(0xFF3E2480),
    foregroundColor: Colors.white,
    badgeText: 'OVO',
    accentColor: Color(0xFFD8B4FE),
  );

  static const WalletBrandSpec shopeepay = WalletBrandSpec(
    id: WalletBrandId.shopeepay,
    displayName: 'ShopeePay',
    walletKind: WalletKind.ewallet,
    primaryColor: Color(0xFFEE4D2D),
    secondaryColor: Color(0xFFC93418),
    foregroundColor: Colors.white,
    badgeText: 'SPay',
    accentColor: Color(0xFFFED7AA),
  );

  static const WalletBrandSpec blu = WalletBrandSpec(
    id: WalletBrandId.blu,
    displayName: 'blu',
    walletKind: WalletKind.bank,
    primaryColor: Color(0xFF00C2E0),
    secondaryColor: Color(0xFF0284C7),
    foregroundColor: Colors.white,
    badgeText: 'blu',
    accentColor: Color(0xFFE0F2FE),
  );

  static const WalletBrandSpec cash = WalletBrandSpec(
    id: WalletBrandId.cash,
    displayName: 'Cash',
    walletKind: WalletKind.cash,
    primaryColor: Color(0xFF0F766E),
    secondaryColor: Color(0xFF0B4F4A),
    foregroundColor: Colors.white,
    badgeText: 'Rp',
    accentColor: Color(0xFF99F6E4),
  );

  static const WalletBrandSpec savings = WalletBrandSpec(
    id: WalletBrandId.savings,
    displayName: 'Tabungan',
    walletKind: WalletKind.savings,
    primaryColor: Color(0xFFC59D47),
    secondaryColor: Color(0xFF977428),
    foregroundColor: Colors.white,
    badgeText: 'SAVE',
    accentColor: Color(0xFFFEF3C7),
  );

  static WalletBrandSpec? matchByName(String rawName, {WalletKind? kind}) {
    final lower = rawName.trim().toLowerCase();
    if (lower.contains('seabank') || lower == 'sea') {
      return seabank;
    }
    if (lower.contains('dana')) {
      return dana;
    }
    if (lower.contains('gopay') || lower.contains('gojek')) {
      return gopay;
    }
    if (lower.contains('jago')) {
      return jago;
    }
    if (RegExp(r'\bblu\b').hasMatch(lower) || lower.contains('bca digital')) {
      return blu;
    }
    if (lower.contains('bca') || lower.contains('mybca')) {
      return bca;
    }
    if (lower.contains('mandiri') || lower.contains('livin')) {
      return mandiri;
    }
    if (RegExp(r'\bbri\b').hasMatch(lower) || lower.contains('brimo')) {
      return bri;
    }
    if (RegExp(r'\bovo\b').hasMatch(lower)) {
      return ovo;
    }
    if (lower.contains('shopee') || lower.contains('spay')) {
      return shopeepay;
    }
    if (lower == 'cash' || lower.contains('tunai')) {
      return cash;
    }
    if (lower.contains('tabungan') ||
        lower.contains('darurat') ||
        kind == WalletKind.savings) {
      return savings;
    }
    if (kind == WalletKind.cash) {
      return cash;
    }
    return null;
  }
}

class WalletBrandAvatar extends StatelessWidget {
  const WalletBrandAvatar({
    super.key,
    required this.name,
    this.kind,
    this.fallbackColor,
    this.fallbackIcon,
    this.size = 46,
    this.borderRadius,
  });

  factory WalletBrandAvatar.fromWallet(
    WalletModel wallet, {
    Key? key,
    double size = 46,
    double? borderRadius,
  }) {
    return WalletBrandAvatar(
      key: key,
      name: wallet.name,
      kind: wallet.kind,
      fallbackColor: wallet.color,
      fallbackIcon: wallet.icon,
      size: size,
      borderRadius: borderRadius,
    );
  }

  final String name;
  final WalletKind? kind;
  final Color? fallbackColor;
  final IconData? fallbackIcon;
  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final brand = WalletBrandCatalog.matchByName(name, kind: kind);
    final radius = borderRadius ?? (size * 0.28).clamp(6.0, 14.0);

    if (brand == null) {
      final color = fallbackColor ?? const Color(0xFF0F766E);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(
          fallbackIcon ?? Icons.account_balance_wallet_outlined,
          color: color,
          size: size * 0.48,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[brand.primaryColor, brand.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: size >= 34
            ? <BoxShadow>[
                BoxShadow(
                  color: brand.secondaryColor.withValues(alpha: 0.28),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(painter: _BrandBackdropPainter(brand)),
            ),
            _buildBrandGlyph(brand),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandGlyph(WalletBrandSpec brand) {
    if (brand.id == WalletBrandId.cash) {
      return Icon(
        Icons.payments_rounded,
        color: brand.foregroundColor,
        size: size * 0.50,
      );
    }
    if (brand.id == WalletBrandId.savings) {
      return Icon(
        Icons.savings_rounded,
        color: brand.foregroundColor,
        size: size * 0.50,
      );
    }

    final compact = size < 28;
    final label = compact && brand.badgeText.length > 3
        ? switch (brand.id) {
            WalletBrandId.dana => 'DN',
            WalletBrandId.gopay => 'GP',
            WalletBrandId.jago => 'J',
            WalletBrandId.mandiri => 'M',
            WalletBrandId.shopeepay => 'SP',
            _ => brand.badgeText,
          }
        : brand.badgeText;

    final fontSize = compact
        ? size * (label.length <= 1 ? 0.52 : 0.36)
        : size *
              (label.length <= 3
                  ? 0.30
                  : label.length == 4
                  ? 0.25
                  : 0.22);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: brand.foregroundColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontStyle: brand.italicText ? FontStyle.italic : FontStyle.normal,
            letterSpacing: label.length >= 4 ? -0.4 : -0.1,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _BrandBackdropPainter extends CustomPainter {
  const _BrandBackdropPainter(this.brand);

  final WalletBrandSpec brand;

  @override
  void paint(Canvas canvas, Size size) {
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.12),
      size.width * 0.44,
      highlight,
    );

    final accent = Paint()
      ..color = brand.accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    switch (brand.id) {
      case WalletBrandId.mandiri:
      case WalletBrandId.bri:
      case WalletBrandId.bca:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.16,
              size.height * 0.78,
              size.width * 0.68,
              size.height * 0.08,
            ),
            Radius.circular(size.height * 0.04),
          ),
          accent,
        );
      case WalletBrandId.jago:
      case WalletBrandId.gopay:
      case WalletBrandId.seabank:
        canvas.drawCircle(
          Offset(size.width * 0.80, size.height * 0.22),
          size.width * 0.09,
          accent,
        );
      case WalletBrandId.dana:
      case WalletBrandId.ovo:
      case WalletBrandId.shopeepay:
      case WalletBrandId.blu:
      case WalletBrandId.cash:
      case WalletBrandId.savings:
      case WalletBrandId.custom:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BrandBackdropPainter oldDelegate) =>
      oldDelegate.brand.id != brand.id;
}
