import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/kavita_client.dart';
import '../auth/session.dart';
import '../theme.dart';

/// The page reading resumes at, drawn behind a hero.
///
/// Two things it has to survive. A cover is dense colour; a page is usually
/// black line art on white, and a scrim alone cannot hold that down — the
/// words land on paper and vanish. So there is an ink floor under a
/// half-strength image, which gives the artwork a brightness ceiling it
/// cannot exceed whatever the page turns out to be.
///
/// And a page is portrait while a hero on a wide screen is a letterbox.
/// Covering that box scales the page to the *card's* width, which magnifies
/// one panel until a speech bubble fills the card. So the artwork's width is
/// capped against its own height, leaving it drawn at something near its
/// natural size, and hung on the trailing edge — the side the scrim thins out
/// for. Its leading edge is faded rather than cut, or the cap would show as a
/// seam down the middle of the card.
///
/// The scrim over it belongs here too rather than to either hero: it is what
/// makes a title legible over any page, and two heroes each keeping their own
/// copy of that judgement is two heroes that drift apart.
class PageBackdrop extends ConsumerWidget {
  const PageBackdrop({
    super.key,
    required this.seriesId,
    required this.chapterId,
    required this.page,
  });

  /// Only ever used for the cover that stands in for the page.
  final int seriesId;
  final int? chapterId;
  final int page;

  /// The fade's two stops. `BlendMode.dstIn` reads only the alpha channel, so
  /// these are opacity values wearing a Color's clothes — not colours, and so
  /// not something `theme.dart` has or wants a token for. `_shown` is also
  /// how much of the page shows through the ink beneath it: one mask does the
  /// fade and the half strength together, where there were two compositing
  /// layers before.
  static const _hidden = Color(0x00000000);
  static const _shown = Color(0x80000000);

  /// The widest the artwork may be drawn, against its own height. Chosen so a
  /// card in portrait is covered exactly as it was and only a letterbox is
  /// ever cut back.
  static const _maxAspect = 2.0;

  /// How much of the artwork's leading edge is spent fading it in.
  static const _fade = 0.35;

  /// Ink over the artwork: opaque where the words are, thinning towards the
  /// far edge so the page is still visible there. This is what makes the text
  /// legible over any page, which is why nothing is blurred.
  static final _scrim = [
    patraBg.withValues(alpha: .92),
    patraBg.withValues(alpha: .80),
    patraBg.withValues(alpha: .45),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: patraBg),
        _artwork(client),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: _scrim,
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _artwork(KavitaClient client) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: math.min(
          constraints.maxWidth,
          constraints.maxHeight * _maxAspect,
        ),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_hidden, _shown],
            stops: [0, _fade],
          ).createShader(bounds),
          child: CachedNetworkImage(
            key: const ValueKey('heroBackdrop'),
            imageUrl: chapterId == null
                ? client.seriesCoverUrl(seriesId)
                : client.readerImageUrl(chapterId!, page),
            httpHeaders: client.imageHeaders,
            fit: BoxFit.cover,
            // The top of a page is its most composed part; its middle is
            // wherever a panel happens to fall.
            alignment: Alignment.topCenter,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => _CoverBackdrop(seriesId: seriesId),
            errorWidget: (_, _, _) => _CoverBackdrop(seriesId: seriesId),
          ),
        ),
      ),
    ),
  );
}

/// The series cover, standing in behind the card until the page is known and
/// wherever the page will not load.
class _CoverBackdrop extends ConsumerWidget {
  const _CoverBackdrop({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    return CachedNetworkImage(
      imageUrl: client.seriesCoverUrl(seriesId),
      httpHeaders: client.imageHeaders,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, _) => const ColoredBox(color: patraSurface),
      errorWidget: (_, _, _) => const ColoredBox(color: patraSurface),
    );
  }
}
