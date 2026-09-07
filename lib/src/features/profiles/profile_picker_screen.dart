import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/connection_failure.dart';
import '../../auth/session.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/patra_masthead.dart';
import '../../widgets/profile_avatar.dart';

/// Who is reading, asked once, on the way in.
///
/// A shared device opens here rather than in whoever read last, and
/// everything on the screen is drawn from what the device already remembers:
/// a face is a cached avatar or an initial on the colour Kavita gave the
/// account, and neither costs a request. That is deliberate rather than
/// incidental — the picker is what stands between a person and their saved
/// chapters on a train, so it must never be a screen that waits for a server.
///
/// The one thing that does reach the network is a **tap**: entering a profile
/// signs in again with its stored key. Even that has an answer offline (the
/// session opens on the key it already holds), so the only failure that
/// changes anything here is a key the server refuses, which lands on the form
/// with the password focused.
///
/// A device holding one profile never sees this screen; [signedOutLocation]
/// is where that is decided.
///
/// **Entering a profile is all it does.** Removing one is in Settings, which
/// asks for a credential this screen cannot — see `_confirmForget` there for
/// why the press that used to be here had to go.
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  /// The [Profile.id] whose sign-in is in flight, so its face can say so and
  /// the others stop accepting taps. The id rather than the address: two
  /// faces can share one server and only one of them is being entered.
  String? _entering;
  String? _error;

  Future<void> _enter(Profile profile) async {
    if (_entering != null) return;
    if (!profile.hasCredential) {
      // Remembered, and the only thing missing is the password.
      context.push(loginLocation(profile: profile));
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _entering = profile.id;
      _error = null;
    });
    try {
      // One request, made with the stored key and no password. Redirection is
      // the router's, here as after a sign-in.
      await ref.read(authProvider.notifier).resume(profile);
    } on SignInExpired {
      // The key is refused, so this profile is now remembered and signed out.
      // The form takes it from there with the address and the name already
      // in it, and says why it is asking — worded there rather than by
      // `ConnectionFailure`, which sees the same bare 401 a mistyped password
      // earns.
      if (mounted) {
        context.push(loginLocation(profile: profile, expired: true));
      }
    } catch (e) {
      // The key is untouched and the face still opens: say what happened and
      // leave the picker as it is.
      if (mounted) {
        setState(
          () => _error = ConnectionFailure.from(e).message(l10n, profile.host),
        );
      }
    } finally {
      // Guarded: the router tears this route down on success, and login's 10s
      // connect timeout gives it every chance to do so first.
      if (mounted) setState(() => _entering = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.watch(authProvider).profiles;
    // The host is what tells two faces apart, and only then: with one server
    // remembered it is the same word under every face, saying nothing.
    //
    // Asked of the **label**, not of the address behind it: `Profile.host`
    // drops the port, so two Kavita servers on one machine are one word here
    // — and a subtitle that prints the same word twice is exactly the thing
    // this rule exists to avoid.
    final showHost = profiles.map((p) => p.host).toSet().length > 1;

    return Scaffold(
      body: SafeArea(
        // A sliver rather than the sign-in form's `LayoutBuilder` around a
        // scroll view: `SliverFillRemaining` centres the column while it fits
        // and scrolls once a device holds more faces than a screen, and it
        // does it **without** running this subtree's builds during layout.
        // What is under here is a `CachedNetworkImage` per face, an `InkWell`
        // per face, a `setState` on every tap, and the two slots the launch
        // animation measures by render box on its way out — precisely the
        // company CLAUDE.md says never to keep inside a `LayoutBuilder`.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: gateGutter,
                vertical: gutter,
              ),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PatraMasthead(showTagline: false),
                      const SizedBox(height: sectionGap * 1.5),
                      SectionLabel(l10n.whoIsReading),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: PatraText.metadata(color: patraDanger),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Uncapped, and the faces are one size on every screen:
                      // a wider screen takes another column, which is what
                      // the library grid does with the same width and the
                      // reason nothing here is centred in a 560pt ribbon.
                      Wrap(
                        spacing: _faceGap,
                        runSpacing: _faceGap,
                        children: [
                          for (final profile in profiles)
                            _Face(
                              profile: profile,
                              showHost: showHost,
                              busy: profile.id == _entering,
                              onTap: () => _enter(profile),
                            ),
                          _AddFace(onTap: () => context.push(loginLocation())),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A face, and how wide a face's worth of screen is. The face is wider than
/// the avatar so a name has somewhere to go without pushing its neighbours
/// apart, and both are the same on every screen: a tablet's answer to width
/// is another column, never a bigger face.
const _avatarSize = 72.0;
const _faceWidth = 88.0;
const _faceGap = 20.0;

/// One person, drawn from what the device remembers about them.
class _Face extends StatelessWidget {
  const _Face({
    required this.profile,
    required this.showHost,
    required this.busy,
    required this.onTap,
  });

  final Profile profile;

  /// Whether the server is worth naming under this face — true only where the
  /// device remembers more than one.
  final bool showHost;

  /// Whether this profile's sign-in is in flight.
  final bool busy;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = profile.displayName;
    // A key the server has already refused costs a password, and saying so
    // here is what makes that knowable before the tap rather than halfway
    // through it.
    final needsPassword = !profile.hasCredential;

    return Semantics(
      button: true,
      label: [
        name,
        if (showHost) profile.host,
        if (needsPassword) l10n.signIn,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(radiusCard),
        child: SizedBox(
          width: _faceWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: _avatarSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProfileAvatar(
                        profile: profile,
                        size: _avatarSize,
                        dimmed: needsPassword || busy,
                      ),
                      if (busy)
                        const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      // Not while a sign-in is in flight: the spinner is
                      // already saying what this face is doing, and the two
                      // marks in one circle would be a busy face and a
                      // stalled one at once.
                      else if (needsPassword)
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: _StaleKeyBadge(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PatraText.rowTitle(),
                ),
                if (showHost) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PatraText.metadata(),
                  ),
                ],
                if (needsPassword) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.signIn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PatraText.metadata(color: patraAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark on a face whose key the server has stopped accepting.
///
/// The dimming says *something* is different about this face; the badge says
/// what, and it is on the avatar because that is where a reader choosing
/// between faces is looking — the word under the name is read after the
/// choice, not while making it. Both stay: the handoff's rule is that a cost
/// is always worded and never icon-only, and a struck-through key says
/// nothing to a screen reader, which takes the whole face as one label.
///
/// In [patraAccent] rather than [patraDanger]: nothing has gone wrong and
/// nothing is being destroyed — this profile still opens, and what it costs
/// is a password. Purple is identity here, which is exactly what is being
/// asked for again.
class _StaleKeyBadge extends StatelessWidget {
  const _StaleKeyBadge();

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: patraSurface,
        shape: BoxShape.circle,
        // The ring is the page's own ground, so the badge reads as sitting in
        // front of the face rather than as a hole punched in it — whatever
        // colour Kavita gave the account underneath.
        border: Border.all(color: patraBg, width: 2),
      ),
      child: const Icon(Icons.key_off_outlined, size: 13, color: patraAccent),
    );
  }
}

/// The empty place at the end of the faces: dashed, because the handoff draws
/// a place to fill that way and an enclosure of something already there with
/// a solid line.
class _AddFace extends StatelessWidget {
  const _AddFace({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = patraText.withValues(alpha: .7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusCard),
      child: SizedBox(
        width: _faceWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _avatarSize,
                child: CustomPaint(
                  // A full pill radius on a square is a circle: the same
                  // dashes as the "add a server" slot, in the shape of the
                  // faces it stands beside.
                  painter: DashedBorderPainter(
                    color: patraText.withValues(alpha: .25),
                    radius: radiusPill,
                  ),
                  child: Center(child: Icon(Icons.add, size: 26, color: color)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.addProfile,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PatraText.rowTitle(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
