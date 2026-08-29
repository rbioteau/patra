import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the Claude Design handoff (`Verso Design System.dc.html`).
/// The app commits to a single dark look: the reader canvas is pure black and
/// the whole chrome is built around it.

const versoBg = Color(0xFF0E0E10);
const versoSurface = Color(0xFF1A1A1E);
const versoSurfaceHi = Color(0xFF222226);
const versoChrome = Color(0xFF141416); // bars

/// Reading progress + identity ONLY. Never for downloads.
const versoAccent = Color(0xFF7C5CFF);

/// Downloads / offline ONLY. Never for progress.
const versoOffline = Color(0xFF2DD4BF);

const versoOnline = Color(0xFF3DDC84);
const versoDanger = Color(0xFFFF7B92);
const versoText = Color(0xFFE8E8EA);

final versoTextMuted = versoText.withValues(alpha: .45);
final versoBorder = Colors.white.withValues(alpha: .08);

/// Radii
const radiusThumb = 6.0;
const radiusCover = 10.0; // covers, buttons, inputs
const radiusCard = 12.0;
const radiusPill = 999.0;

/// Spacing
const gutter = 20.0;
const sectionGap = 24.0;
const minHitTarget = 44.0;

/// Covers are always 2:3.
const coverAspectRatio = 2 / 3;

/// Text styles that the Material text theme cannot express on its own.
abstract final class VersoText {
  /// Titles of works, wordmark, reader page numbers — the only serif uses.
  static TextStyle serifTitle({double size = 21, Color? color}) =>
      GoogleFonts.sourceSerif4(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? versoText,
        height: 1.25,
      );

  static TextStyle sectionLabel() => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: versoTextMuted,
  );

  static TextStyle rowTitle({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: color ?? versoText,
  );

  static TextStyle body({Color? color}) =>
      GoogleFonts.spaceGrotesk(fontSize: 14, color: color ?? versoText);

  static TextStyle metadata({Color? color, double size = 11}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, color: color ?? versoTextMuted);

  /// Bottom navigation label. Exposed so the shell can measure it and decide
  /// whether the labels fit before showing them.
  static TextStyle navLabel({required bool selected}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? versoAccent : versoTextMuted,
      );

  /// Page numerals in the reader: serif, and always laid out left-to-right
  /// even when reading right-to-left.
  static TextStyle pageNumeral({Color? color}) => GoogleFonts.sourceSerif4(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: color ?? Colors.white,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData versoTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colors = ColorScheme.dark(
    primary: versoAccent,
    onPrimary: Colors.white,
    secondary: versoOffline,
    onSecondary: const Color(0xFF04322C),
    surface: versoSurface,
    onSurface: versoText,
    surfaceContainerHighest: versoSurfaceHi,
    error: versoDanger,
    onError: const Color(0xFF3A0512),
    outline: Colors.white.withValues(alpha: .08),
  );

  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: versoBg,
    canvasColor: versoBg,
    dividerColor: versoBorder,
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: versoText, displayColor: versoText),
    appBarTheme: AppBarTheme(
      backgroundColor: versoChrome,
      surfaceTintColor: Colors.transparent,
      foregroundColor: versoText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: versoText,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: versoChrome,
      surfaceTintColor: Colors.transparent,
      indicatorColor: versoAccent.withValues(alpha: .16),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? versoAccent
              : versoTextMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) =>
            VersoText.navLabel(selected: states.contains(WidgetState.selected)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: versoAccent,
      linearMinHeight: 3,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: versoSurface,
      hintStyle: VersoText.body(color: versoTextMuted),
      labelStyle: VersoText.body(color: versoTextMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: BorderSide(color: versoBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: BorderSide(color: versoBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: const BorderSide(color: versoAccent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: versoAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(minHitTarget + 4),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCover),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: versoText,
        side: BorderSide(color: versoBorder),
        minimumSize: const Size.fromHeight(minHitTarget),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCover),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: versoSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
        side: BorderSide(color: versoBorder),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 10,
      iconColor: versoTextMuted,
      titleTextStyle: VersoText.rowTitle(),
      subtitleTextStyle: VersoText.metadata(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: versoSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: versoAccent,
      inactiveTrackColor: Colors.white.withValues(alpha: .22),
      thumbColor: versoAccent,
      trackHeight: 3,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: versoSurfaceHi,
      contentTextStyle: VersoText.body(),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCover),
      ),
    ),
  );
}

/// A section header: uppercase, tracked, muted.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text.toUpperCase(), style: VersoText.sectionLabel()),
        ),
        ?trailing,
      ],
    );
  }
}

/// A 3px reading-progress bar pinned to the bottom edge of a cover.
class CoverProgressBar extends StatelessWidget {
  const CoverProgressBar({super.key, required this.progress});

  /// 0..1; nothing is drawn outside that open interval.
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 3,
        color: Colors.black.withValues(alpha: .45),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(color: versoAccent),
        ),
      ),
    );
  }
}

/// Shimmering placeholder used by the home skeletons.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.radius = radiusThumb,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 - 0.5;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(t - 1, 0),
                  end: Alignment(t, 0),
                  colors: [versoSurface, versoSurfaceHi, versoSurface],
                ),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}
