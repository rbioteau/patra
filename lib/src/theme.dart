import 'package:flutter/material.dart';

/// Design tokens for the Patra brand kit — gold on night blue.
/// The app commits to a single dark look: the reader canvas is pure black and
/// the whole chrome is built around it.

/// The four faces the app ships, and the only ones it draws with.
///
/// All four are bundled rather than fetched — a reader is opened on a train,
/// and a book saved for one (#77) opens in the face its reader chose with no
/// server to ask. Every one is **variable**, so one file answers every
/// weight. Two of them ship with their italic as well; Space Grotesk has
/// none at all and Source Serif 4's is deliberately not bundled (see
/// [ReadingFace.canSetItalic]).
///
/// The first two are the **app's own** — the interface is drawn in the sans
/// and the serif is reserved for titles of works, the wordmark and the
/// reader's page numerals. The other two are a book's alone: they are
/// offered nowhere but in the reader's sheet, and the only place the serif
/// rule of this file is deliberately broken on purpose (see the reader's
/// rules).
const fontSpaceGrotesk = 'Space Grotesk';
const fontSourceSerif4 = 'Source Serif 4';
const fontLiterata = 'Literata';
const fontAtkinsonHyperlegibleNext = 'Atkinson Hyperlegible Next';

/// The two the interface is drawn in, by the only names the rest of this
/// file needs to know them by.
const _sans = fontSpaceGrotesk;
const _serif = fontSourceSerif4;

/// The page. Also the ground of every app icon and of the window the OS
/// paints while the process starts, which is what makes the launch read as a
/// lift out of the same colour rather than a cut to a different one.
const patraBg = Color(0xFF111722);

/// Cards, sheets, tiles — a surface raised off the page.
const patraSurface = Color(0xFF1C293E);
const patraSurfaceHi = Color(0xFF26354B);
const patraChrome = Color(0xFF172131); // bars

/// Reading progress + identity ONLY. Never for downloads.
const patraAccent = Color(0xFFD7B976);

/// What goes on gold. Dark, not white: the accent is a light ink and text
/// laid on it has to be read against it rather than through it.
const patraOnAccent = Color(0xFF241D10);

/// Downloads / offline ONLY. Never for progress.
const patraOffline = Color(0xFF8EACD8);

const patraOnline = Color(0xFF3DDC84);
const patraDanger = Color(0xFFFFB4AB);
const patraText = Color(0xFFF3EEE3);
const patraTextMuted = Color(0xFFAFB8C7);

/// The unfilled part of a progress track drawn on its own, away from a cover
/// (where [CoverProgressBar] sits on the artwork and uses black instead).
final patraTrack = patraText.withValues(alpha: .14);

/// Secondary text laid over artwork rather than over a surface. [patraTextMuted]
/// is tuned against a flat dark panel and disappears on a page, which may be
/// anything from black ink to bare white paper.
final patraTextOnArt = patraText.withValues(alpha: .78);
const patraBorder = Color(0xFF35445A);

/// A control laid over a page, which is what the reader's chrome sits on.
///
/// Shares of white rather than colours of ours, because what is underneath
/// is a scan or a photograph and may be anything from black ink to bare
/// white paper: a fill that is a share of white reads as a control on all of
/// them. The reader draws two of them — the cog in the top bar, and, for a
/// book, the control that opens its contents.
final patraOnPageFill = Colors.white.withValues(alpha: .12);
final patraOnPageOutline = Colors.white.withValues(alpha: .18);

/// Radii

const radiusThumb = 6.0;
const radiusCover = 10.0; // covers, buttons, inputs
const radiusCard = 12.0;
const radiusPill = 999.0;

/// Spacing
const gutter = 20.0;

/// The wider gutter of the two screens that stand in front of the app — the
/// picker and the sign-in form. Both hold a single column on an otherwise
/// empty screen, and both are the handoff's login screen at heart, so the
/// number lives here rather than once in each of them.
const gateGutter = 32.0;
const sectionGap = 24.0;
const minHitTarget = 44.0;

/// Past this, a control stops reading as one and becomes a banner or a rule
/// across the screen. Shared, because the numbers drifted when the series
/// hero and the home hero each held their own — the same reason
/// [rowCoverWidth] is not written twice.
const controlMaxWidth = 280.0;

/// A progress track drawn on its own, away from a cover.
const radiusTrack = 2.0;

/// Covers are always 2:3.
const coverAspectRatio = 2 / 3;

/// The cover on a row of a column of rows — a chapter, a saved chapter.
///
/// The tablet pair was sized as a share of a *capped* column — ~13% of it,
/// the proportion a phone gives the cover. That cap is gone: a row now takes
/// the full width at the app's margin, so the cover is a smaller share of it
/// again. These sizes stay because they read well at arm's length; the right
/// answer for a tablet's width is a grid, not a wider row.
///
/// Both the series screen and the Downloads tab draw the same conceptual row,
/// so the numbers live here: kept separately they drifted, and the same row
/// was drawn at two sizes on two tabs.
const rowCoverWidth = 46.0;
const rowCoverHeight = 66.0;
const rowCoverWidthTablet = 80.0;
const rowCoverHeightTablet = 115.0;

/// The Material tablet breakpoint, asked of the *shortest* side so a phone
/// held in landscape is still a phone — the same question `ClientMetrics`
/// answers when it tells Kavita what kind of device this is.
const tabletBreakpoint = 600.0;

/// True where the screen is a tablet's, and the phone-sized furniture of the
/// handoff has room to grow.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

/// Text styles that the Material text theme cannot express on its own.
abstract final class PatraText {
  /// Titles of works, wordmark, reader page numbers — the only serif uses.
  static TextStyle serifTitle({double size = 21, Color? color}) => TextStyle(
    fontFamily: _serif,
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? patraText,
    height: 1.25,
  );

  static TextStyle sectionLabel({Color? color}) => TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: color ?? patraTextMuted,
  );

  static TextStyle rowTitle({Color? color, double size = 13.5}) => TextStyle(
    fontFamily: _sans,
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? patraText,
  );

  static TextStyle body({Color? color}) =>
      TextStyle(fontFamily: _sans, fontSize: 14, color: color ?? patraText);

  static TextStyle metadata({Color? color, double size = 11}) => TextStyle(
    fontFamily: _sans,
    fontSize: size,
    color: color ?? patraTextMuted,
  );

  /// Bottom navigation label. Exposed so the shell can measure it and decide
  /// whether the labels fit before showing them.
  static TextStyle navLabel({required bool selected}) => TextStyle(
    fontFamily: _sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: selected ? patraAccent : patraTextMuted,
  );

  /// Page numerals in the reader: serif, and always laid out left-to-right
  /// even when reading right-to-left.
  static TextStyle pageNumeral({Color? color}) => TextStyle(
    fontFamily: _serif,
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
    onPrimary: patraOnAccent,
    secondary: patraOffline,
    onSecondary: const Color(0xFF10243E),
    surface: patraSurface,
    onSurface: patraText,
    onSurfaceVariant: patraTextMuted,
    surfaceContainer: patraSurface,
    surfaceContainerHigh: patraSurfaceHi,
    surfaceContainerHighest: patraSurfaceHi,
    error: patraDanger,
    onError: const Color(0xFF690005),
    outline: const Color(0xFF79879B),
    outlineVariant: patraBorder,
  );

  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: patraBg,
    textTheme: base.textTheme.apply(
      fontFamily: _sans,
      bodyColor: patraText,
      displayColor: patraText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: patraChrome,
      surfaceTintColor: Colors.transparent,
      foregroundColor: patraText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _sans,
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
        foregroundColor: patraOnAccent,
        minimumSize: const Size.fromHeight(minHitTarget + 4),
        textStyle: const TextStyle(
          fontFamily: _sans,
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
        textStyle: const TextStyle(
          fontFamily: _sans,
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
      // The action is the one thing in the bar to tap, and the accent is what
      // marks a text control here (the fold's Show/Hide, a setting's value).
      // Left unset, Material 3 takes `inversePrimary`, a darkened gold that
      // cannot be read on the raised surface.
      actionTextColor: patraAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCover),
      ),
    ),
  );
}

/// A section header: uppercase, tracked, muted.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;

  /// Muted unless a screen says otherwise — the Continue hero's eyebrow is
  /// the accent, which is what marks it as being about reading progress.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: PatraText.sectionLabel(color: color),
          ),
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
