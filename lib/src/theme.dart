import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the Claude Design handoff (`.claude/design/HANDOFF.md`).
/// The app commits to a single dark look: the reader canvas is pure black and
/// the whole chrome is built around it.

const patraBg = Color(0xFF0E0E10);
const patraSurface = Color(0xFF1A1A1E);
const patraSurfaceHi = Color(0xFF222226);
const patraChrome = Color(0xFF141416); // bars

/// Reading progress + identity ONLY. Never for downloads.
const patraAccent = Color(0xFF7C5CFF);

/// Downloads / offline ONLY. Never for progress.
const patraOffline = Color(0xFF2DD4BF);

const patraOnline = Color(0xFF3DDC84);
const patraDanger = Color(0xFFFF7B92);
const patraText = Color(0xFFE8E8EA);

final patraTextMuted = patraText.withValues(alpha: .45);
final patraBorder = Colors.white.withValues(alpha: .08);

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

/// The Material tablet breakpoint, asked of the *shortest* side so a phone
/// held in landscape is still a phone — the same question `ClientMetrics`
/// answers when it tells Kavita what kind of device this is.
const tabletBreakpoint = 600.0;

/// Where a column of rows stops growing. Past this the parts of a row drift
/// apart — cover against one edge, save pill against the other, a gulf in
/// between — so the extra width is spent on the margins instead.
///
/// The cap is set by the *shortest* row we draw, not by the longest. A
/// chapter row carries "Tome 1 · 218 pages" and a pill: at 680 that left it
/// with 318pt of nothing in the middle (measured, 820pt portrait), which is
/// the very drift this number exists to prevent. What a settings row could
/// have filled, a chapter row cannot.
const contentMaxWidth = 560.0;

/// True where the screen is a tablet's, and the phone-sized furniture of the
/// handoff has room to grow.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

/// Text styles that the Material text theme cannot express on its own.
abstract final class PatraText {
  /// Titles of works, wordmark, reader page numbers — the only serif uses.
  static TextStyle serifTitle({double size = 21, Color? color}) =>
      GoogleFonts.sourceSerif4(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? patraText,
        height: 1.25,
      );

  static TextStyle sectionLabel() => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: patraTextMuted,
  );

  static TextStyle rowTitle({Color? color, double size = 13.5}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? patraText,
      );

  static TextStyle body({Color? color}) =>
      GoogleFonts.spaceGrotesk(fontSize: 14, color: color ?? patraText);

  static TextStyle metadata({Color? color, double size = 11}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, color: color ?? patraTextMuted);

  /// Bottom navigation label. Exposed so the shell can measure it and decide
  /// whether the labels fit before showing them.
  static TextStyle navLabel({required bool selected}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? patraAccent : patraTextMuted,
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

ThemeData patraTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colors = ColorScheme.dark(
    primary: patraAccent,
    onPrimary: Colors.white,
    secondary: patraOffline,
    onSecondary: const Color(0xFF04322C),
    surface: patraSurface,
    onSurface: patraText,
    surfaceContainerHighest: patraSurfaceHi,
    error: patraDanger,
    onError: const Color(0xFF3A0512),
    outline: Colors.white.withValues(alpha: .08),
  );

  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: patraBg,
    canvasColor: patraBg,
    dividerColor: patraBorder,
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: patraText, displayColor: patraText),
    appBarTheme: AppBarTheme(
      backgroundColor: patraChrome,
      surfaceTintColor: Colors.transparent,
      foregroundColor: patraText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: patraText,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: patraChrome,
      surfaceTintColor: Colors.transparent,
      indicatorColor: patraAccent.withValues(alpha: .16),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? patraAccent
              : patraTextMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) =>
            PatraText.navLabel(selected: states.contains(WidgetState.selected)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: patraAccent,
      linearMinHeight: 3,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: patraSurface,
      hintStyle: PatraText.body(color: patraTextMuted),
      labelStyle: PatraText.body(color: patraTextMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: BorderSide(color: patraBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: BorderSide(color: patraBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusCover),
        borderSide: const BorderSide(color: patraAccent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: patraAccent,
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
        foregroundColor: patraText,
        side: BorderSide(color: patraBorder),
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
      color: patraSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
        side: BorderSide(color: patraBorder),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 10,
      iconColor: patraTextMuted,
      titleTextStyle: PatraText.rowTitle(),
      subtitleTextStyle: PatraText.metadata(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: patraSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: patraAccent,
      inactiveTrackColor: Colors.white.withValues(alpha: .22),
      thumbColor: patraAccent,
      trackHeight: 3,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: patraSurfaceHi,
      contentTextStyle: PatraText.body(),
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
          child: Text(text.toUpperCase(), style: PatraText.sectionLabel()),
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
          child: Container(color: patraAccent),
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
                  colors: [patraSurface, patraSurfaceHi, patraSurface],
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
