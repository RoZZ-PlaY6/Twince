import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Draws a Material icon.
///
/// Android keeps the framework [Icon] widget. Web draws the same code point
/// from [TwinceIcons], the full icon font, because the tree-shaken
/// `MaterialIcons` face is not the family name CanvasKit uses for those glyphs.
class MaterialIcon extends StatelessWidget {
  const MaterialIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
  });

  static const webFontFamily = 'TwinceIcons';

  @visibleForTesting
  static TextStyle glyphStyle({
    required Color? color,
    required double size,
    required bool web,
  }) {
    final family = web ? webFontFamily : 'MaterialIcons';
    return TextStyle(
      inherit: false,
      color: color,
      fontSize: size,
      height: 1,
      fontFamily: family,
      fontFamilyFallback: const <String>[webFontFamily, 'MaterialIcons'],
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Icon(icon, size: size, color: color);
    }
    final iconTheme = IconTheme.of(context);
    final iconSize = size ?? iconTheme.size ?? 24;
    final iconColor = color ?? iconTheme.color;
    final glyph = String.fromCharCode(icon.codePoint);
    Widget painted = Text(
      glyph,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: glyphStyle(color: iconColor, size: iconSize, web: true),
    );
    if (icon.matchTextDirection &&
        Directionality.of(context) == TextDirection.rtl) {
      painted = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: painted,
      );
    }
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Center(child: painted),
    );
  }
}
