import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/connection_failure.dart';
import '../../auth/session.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/patra_frond.dart';
import '../../widgets/patra_wordmark.dart';
import '../launch/launch_animation.dart';
import '../../theme.dart';

/// Horizontal breathing room from the handoff's login screen — wider than the
/// app gutter, because this screen holds a single column and nothing else.
const _loginGutter = 32.0;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  /// The form replaces the profile list when adding or editing, and whenever
  /// there is no remembered profile at all.
  bool _showForm = false;
  bool _busy = false;

  /// The [Profile.id] of the profile whose sign-in is in flight, so its row
  /// can say so. Entering a remembered profile is a round trip now, not a
  /// state change — a row that looked inert for ten seconds would read as a
  /// dead tap. The id rather than the address, since two profiles can share
  /// one server and only one of them is signing in.
  String? _signingIn;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _openForm({Profile? prefill, bool focusPassword = false}) {
    _serverController.text = prefill?.baseUrl ?? '';
    _usernameController.text = prefill?.username ?? '';
    _passwordController.clear();
    setState(() {
      _showForm = true;
      _error = null;
    });
    if (focusPassword) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _passwordFocus.requestFocus(),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            baseUrl: _serverController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      // Redirection handled by the router.
    } catch (e) {
      // Guarded like the finally below: login has a 10s connect timeout, and
      // anything that tears the route down while it is outstanding would
      // otherwise land a setState on a disposed State.
      //
      // The raw error is a DioException naming a type, a URI and a socket
      // error under it — true, and useless to the person who just mistyped
      // a host. `ConnectionFailure` sorts it into the few cases that change
      // what they would do next, and only `unknown` still shows the text.
      final failure = ConnectionFailure.from(e);
      final host = serverHost(_serverController.text.trim());
      if (mounted) setState(() => _error = failure.message(l10n, host));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(Profile profile) async {
    if (_signingIn != null) return;
    if (!profile.hasCredential) {
      // Remembered but signed out: only the password is missing.
      _openForm(prefill: profile, focusPassword: true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _signingIn = profile.id;
      _error = null;
    });
    try {
      // One request, made with the stored auth key and no password.
      // Redirection is the router's, as it is after a sign-in.
      await ref.read(authProvider.notifier).resume(profile);
    } on SignInExpired {
      if (!mounted) return;
      // The key is refused, so the server is remembered and signed out and
      // the only thing still missing is the password: land on the form with
      // the address and the name already in it, rather than on a row that
      // would just fail again. `_openForm` clears the error, so it is set
      // after.
      //
      // Worded here rather than by `ConnectionFailure`, which sees the same
      // bare 401 a mistyped password earns: nothing the person typed was
      // rejected, because nothing they typed was sent.
      _openForm(prefill: profile, focusPassword: true);
      setState(
        () => _error = l10n.connectionSignInExpired(
          profile.displayName,
          profile.host,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // The key is untouched and the row still opens: say what happened and
      // leave the list as it is.
      setState(
        () => _error = ConnectionFailure.from(e).message(l10n, profile.host),
      );
    } finally {
      // Guarded: the router tears this route down on success, and the 10s
      // connect timeout gives it every chance to do so first.
      if (mounted) setState(() => _signingIn = null);
    }
  }

  Future<void> _forget(Profile profile) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(
          // Both halves: a server can hold several profiles, and it is one
          // of them being removed rather than the address.
          l10n.forgetProfileConfirm(profile.displayName, profile.host),
          style: PatraText.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.forgetProfile,
              style: PatraText.body(color: patraDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authProvider.notifier).forget(profile.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.watch(authProvider).profiles;
    final showList = profiles.isNotEmpty && !_showForm;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _loginGutter,
                    vertical: gutter,
                  ),
                  child: ConstrainedBox(
                    // Masthead and fields sit at the optical centre while they
                    // fit, and the column scrolls once the keyboard is up.
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0,
                        constraints.maxHeight - gutter * 2,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: showList
                            ? _buildProfileList(profiles)
                            : _buildForm(canGoBack: profiles.isNotEmpty),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The footer is pinned to the bottom edge, never centred with the
            // rest: it is a note about the app, not part of the form.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _loginGutter,
                8,
                _loginGutter,
                24,
              ),
              child: Text(
                l10n.loginFooter,
                textAlign: TextAlign.center,
                style: PatraText.metadata(
                  color: patraText.withValues(alpha: .35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(List<Profile> profiles) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Masthead(),
        const SizedBox(height: sectionGap * 1.5),
        // A sign-in can fail from here now, so the list needs somewhere to
        // say why — everything but a refused key leaves the rows as they are.
        if (_error != null) ...[
          _ErrorLine(_error!),
          const SizedBox(height: 12),
        ],
        SectionLabel(l10n.savedProfiles),
        const SizedBox(height: 12),
        for (final profile in profiles) ...[
          _ProfileRow(
            profile: profile,
            busy: profile.id == _signingIn,
            onTap: () => _connect(profile),
            onEdit: () => _openForm(prefill: profile, focusPassword: true),
            onForget: () => _forget(profile),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _AddProfileButton(onPressed: () => _openForm()),
      ],
    );
  }

  Widget _buildForm({required bool canGoBack}) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Masthead(),
          const SizedBox(height: sectionGap * 1.5),
          _Field(
            label: l10n.serverAddress,
            child: TextFormField(
              controller: _serverController,
              decoration: InputDecoration(hintText: l10n.serverAddressHint),
              keyboardType: TextInputType.url,
              autocorrect: false,
              autofillHints: const [AutofillHints.url],
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return l10n.serverAddressRequired;
                final uri = Uri.tryParse(value);
                // `hasScheme` alone let three bad addresses through, each of
                // which failed later as an unreadable dio error: a host with
                // a port and no scheme parses with a *scheme* of
                // "kavita.local", `ftp://x.y` has a scheme we cannot speak,
                // and `http://` has none of the host we need.
                if (uri == null ||
                    (uri.scheme != 'http' && uri.scheme != 'https') ||
                    uri.host.isEmpty) {
                  return l10n.serverAddressInvalid;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 6),
          // A self-hosted server is usually a bare IP with no certificate,
          // and nothing on this screen used to say that was allowed.
          Text(
            l10n.serverAddressLocalHint,
            style: PatraText.metadata(size: 11),
          ),
          const SizedBox(height: 14),
          _Field(
            label: l10n.username,
            child: TextFormField(
              controller: _usernameController,
              autocorrect: false,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? l10n.usernameRequired : null,
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: l10n.password,
            child: TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? l10n.passwordRequired : null,
            ),
          ),
          const SizedBox(height: gutter),
          if (_error != null) ...[
            _ErrorLine(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.signIn),
          ),
          // The way back sits under the button rather than in a top-left
          // arrow: the masthead owns the top of this screen.
          if (canGoBack) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _showForm = false;
                  _error = null;
                }),
                style: TextButton.styleFrom(foregroundColor: patraTextMuted),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: Text(l10n.backToProfiles),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The lockup and the tagline, aligned to the left edge of the column.
///
/// This is where the launch animation lands when the app opens on this screen,
/// which is what it does with no server configured. Both halves are slots, and
/// the wordmark being one is the point: it is drawn at the splash's own size,
/// so the word does not shrink into place, it travels — the splash's lockup
/// simply becomes this screen's. The frond is the same five-blade mark as the
/// header's, in the same proportion to the word beside it.
class _Masthead extends StatelessWidget {
  const _Masthead();

  static const _size = 40.0;

  /// The header's lockup at this screen's scale: the mark stands a little
  /// taller than the word so the five blades stay open.
  static const _markHeight = _size * 24 / 22;

  /// The gap is **tighter** here than the header's 0.81em, and deliberately so
  /// rather than by drift: spacing that reads as one lockup at 22pt opens into
  /// a gulf when the same ratio is scaled to 40pt. The mark and the word have
  /// to stay one thing at both sizes, which is the point being kept, not the
  /// number.
  static const _gap = _size * 0.65;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            LaunchLogoSlot(child: PatraFrond(height: _markHeight)),
            SizedBox(width: _gap),
            LaunchWordmarkSlot(child: PatraWordmark(size: _size)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.appTagline,
          style: PatraText.metadata(size: 13).copyWith(height: 1.5),
        ),
      ],
    );
  }
}

/// A field under its own uppercase label, rather than a floating one: the
/// labels stay readable while typing and line up with the section labels.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionLabel(label), const SizedBox(height: 7), child],
    );
  }
}

/// One remembered profile: who, on which server, and whether it opens with a
/// tap or wants a password first.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onForget,
    this.busy = false,
  });

  final Profile profile;

  /// Whether this profile's sign-in is in flight: the row says so and accepts
  /// nothing until it is not.
  final bool busy;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A profile holding its auth key opens with one tap; otherwise a password
    // is still needed, and both the chip and the call to action say so.
    final live = profile.hasCredential;
    // The person names the row and the server labels it underneath: two
    // accounts on one address are two rows that would otherwise read the
    // same word twice.
    final name = profile.displayName;
    // `characters`, not `substring(0, 1)`: a name starting with an astral
    // character — an emoji, some CJK extensions — would otherwise be cut in
    // half and drawn as a replacement glyph. The host this replaced was
    // effectively always plain ASCII; a username is whatever someone typed.
    final initial = name.isEmpty
        ? '?'
        : name.characters.first.toUpperCase();
    final cta = live ? l10n.openProfile : l10n.signIn;
    final ctaStyle = PatraText.metadata(
      size: 12,
      color: live ? patraAccent : patraTextMuted,
    ).copyWith(fontWeight: FontWeight.w600);

    return Material(
      color: patraSurface,
      borderRadius: BorderRadius.circular(radiusCard),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(radiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusCard),
            border: Border.all(color: patraBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The call to action is the first thing to go: "Se connecter" is
              // half again as long as "Sign in", and on a small phone it would
              // leave the name no room. The chip already says, in colour,
              // whether this profile opens straight away.
              final ctaWidth = _measureWidth(context, cta, ctaStyle);
              final showCta =
                  constraints.maxWidth - _profileRowFixedWidth - ctaWidth >=
                  _profileRowMinNameWidth;
              return Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: live ? patraAccent : patraSurfaceHi,
                      borderRadius: BorderRadius.circular(radiusCover),
                    ),
                    child: Text(
                      initial,
                      style: PatraText.rowTitle(
                        color: live ? Colors.white : patraTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PatraText.rowTitle(),
                        ),
                        if (name != profile.host) ...[
                          const SizedBox(height: 3),
                          Text(
                            profile.host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PatraText.metadata(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // The spinner takes the call to action's place whatever the
                  // width: it is narrower than the word it replaces, and it is
                  // the one thing on this row that must not be dropped.
                  if (busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: patraAccent,
                      ),
                    ),
                  ] else if (showCta) ...[
                    const SizedBox(width: 8),
                    Text(cta, style: ctaStyle),
                  ],
                  IconButton(
                    tooltip: l10n.editProfile,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: busy ? null : onEdit,
                  ),
                  IconButton(
                    tooltip: l10n.forgetProfile,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: busy ? null : onForget,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What went wrong, said the same way on the list and on the form — the two
/// places a sign-in can fail from now that entering a remembered profile is a
/// request of its own.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: PatraText.metadata(color: patraDanger));
}

/// Everything in a profile row that is not the name or the call to action:
/// the chip, its gaps and the two compact icon buttons.
const _profileRowFixedWidth = 12 + 38 + 12 + 8 + 40 + 40 + 4;

/// What the name is worth keeping, ellipsis included.
const _profileRowMinNameWidth = 96.0;

double _measureWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// The empty slot at the end of the profile list: dashed, so it reads as a
/// place to fill rather than as a second button competing with "Sign in".
class _AddProfileButton extends StatelessWidget {
  const _AddProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = patraText.withValues(alpha: .7);
    return SizedBox(
      height: minHitTarget + 6,
      child: CustomPaint(
        painter: DashedBorderPainter(color: patraText.withValues(alpha: .25)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radiusCard),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.addProfile,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.rowTitle(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
