import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/connection_failure.dart';
import '../../auth/session.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/patra_masthead.dart';

/// Signing in: the one screen that asks for a password.
///
/// It is reached three ways, and what it asks depends on which. Adding a
/// profile to a device that already knows **one** server asks for a username
/// and a password and nothing else — nobody should have to type an address
/// they have typed before — while a device that knows several has to be told
/// which one. Signing a remembered profile back in asks for the password
/// alone: everything else about that person is already here.
///
/// The list of profiles used to live here too, and is now the picker
/// ([ProfilePickerScreen]); [signedOutLocation] decides which of the two a
/// signed-out device lands on.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.profileId, this.expired = false});

  /// The [Profile.id] being signed back in, when this is a remembered person
  /// rather than a new one.
  final String? profileId;

  /// Whether the stored key was **refused** rather than merely absent, which
  /// is a different sentence: nothing the person typed was rejected, because
  /// nothing they typed was sent. The screen cannot work this out for itself
  /// — by the time it is drawn the key has already been dropped.
  final bool expired;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  String? _error;

  /// The profile being signed back in, resolved once: it is still remembered
  /// after its key was dropped, which is what makes this possible at all.
  Profile? _profile;

  /// Whether the address is one this screen does not need to ask for — this
  /// profile's own, or the only server the device knows.
  bool _serverIsKnown = false;

  /// Whether the refused-key sentence has been put up. Once only, so it is
  /// not rebuilt over whatever the form has said since.
  bool _explainedRefusal = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final id = widget.profileId;
    for (final profile in auth.profiles) {
      if (profile.id == id) _profile = profile;
    }
    final profile = _profile;
    if (profile != null) {
      _serverController.text = profile.baseUrl;
      _usernameController.text = profile.username;
      _serverIsKnown = true;
    } else {
      // Adding somebody. A device that knows exactly one server assumes it;
      // one that knows several has to be told which, and one that knows none
      // has to be told what.
      final servers = auth.servers;
      if (servers.length == 1) {
        _serverController.text = servers.single;
        _serverIsKnown = true;
      }
    }
    if (_serverIsKnown) {
      // Straight to the first empty field: the password for somebody the
      // device already knows, the name for somebody it is meeting.
      final focus = profile == null ? _usernameFocus : _passwordFocus;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => focus.requestFocus(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_explainedRefusal) return;
    _explainedRefusal = true;
    final profile = _profile;
    if (widget.expired && profile != null) {
      // Before the first build, so no setState: the form is drawn already
      // saying why it is asking.
      _error = AppLocalizations.of(
        context,
      ).connectionSignInExpired(profile.displayName, profile.host);
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Empties the form of everything it assumed, address field included.
  ///
  /// Small, and the only way out of a dead end. This screen assumes a server
  /// whenever it can, and on the path that assumes the most — the last
  /// remaining profile, signed out, which lands here prefilled — the device
  /// would otherwise be that person's for good: no address to change, no
  /// picker behind it to go back to, and no slot to add anybody. The list
  /// this screen replaced always carried one.
  ///
  /// The name goes with the address rather than staying behind it: a
  /// username belongs to the server that issued it, so keeping one while
  /// changing the other names nobody.
  void _askForServer() {
    _serverController.clear();
    _usernameController.clear();
    setState(() {
      _serverIsKnown = false;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _usernameFocus.unfocus(),
    );
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
            // The controller either way: where the field is not drawn it
            // holds the address this screen was opened for, so there is one
            // place the address comes from rather than two.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // There is somewhere to go back to exactly when a signed-out device would
    // have landed on the picker: this screen was reached from it.
    final canGoBack =
        signedOutLocation(ref.watch(authProvider)) == profilesLocation;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: gateGutter,
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
                        child: _buildForm(canGoBack: canGoBack),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The footer is pinned to the bottom edge, never centred with the
            // rest: it is a note about the app, not part of the form.
            Padding(
              padding: const EdgeInsets.fromLTRB(gateGutter, 8, gateGutter, 24),
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

  Widget _buildForm({required bool canGoBack}) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PatraMasthead(),
          const SizedBox(height: sectionGap * 1.5),
          if (!_serverIsKnown) ...[
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
          ],
          _Field(
            label: l10n.username,
            child: TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocus,
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
            Text(_error!, style: PatraText.metadata(color: patraDanger)),
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
          // The address this screen assumed, and the way to say it is the
          // wrong one. Offered wherever anything was assumed — including
          // while signing a remembered profile back in, which is the one
          // path with no picker behind it and so the one that would strand a
          // device on somebody else's server.
          if (_serverIsKnown) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _askForServer,
                style: TextButton.styleFrom(foregroundColor: patraTextMuted),
                child: Text(l10n.useAnotherServer),
              ),
            ),
          ],
          // The way back sits under the button rather than in a top-left
          // arrow: the masthead owns the top of this screen.
          if (canGoBack) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(profilesLocation),
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
