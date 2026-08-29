import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/session.dart';
import '../../theme.dart';

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

  /// The form replaces the server list when adding or editing, and whenever
  /// there is no saved server at all.
  bool _showForm = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _openForm({ServerEntry? prefill, bool focusPassword = false}) {
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
      if (mounted) setState(() => _error = l10n.loginFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(ServerEntry server) async {
    if (server.hasSession) {
      await ref.read(authProvider.notifier).resume(server);
      return;
    }
    // Remembered but signed out: only the password is missing.
    _openForm(prefill: server, focusPassword: true);
  }

  Future<void> _forget(ServerEntry server) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(
          l10n.forgetServerConfirm(server.host),
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
              l10n.forgetServer,
              style: PatraText.body(color: patraDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authProvider.notifier).forget(server.baseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(authProvider).servers;
    final showList = servers.isNotEmpty && !_showForm;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: showList
                  ? _buildServerList(servers)
                  : _buildForm(canGoBack: servers.isNotEmpty),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerList(List<ServerEntry> servers) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Masthead(),
        const SizedBox(height: sectionGap * 1.5),
        SectionLabel(l10n.savedServers),
        const SizedBox(height: 12),
        for (final server in servers) ...[
          _ServerRow(
            server: server,
            onTap: () => _connect(server),
            onEdit: () => _openForm(prefill: server, focusPassword: true),
            onForget: () => _forget(server),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.addServer),
        ),
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
          if (canGoBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _showForm = false;
                  _error = null;
                }),
              ),
            ),
          const _Masthead(),
          const SizedBox(height: sectionGap * 1.5),
          TextFormField(
            controller: _serverController,
            decoration: InputDecoration(
              labelText: l10n.serverAddress,
              hintText: l10n.serverAddressHint,
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return l10n.serverAddressRequired;
              final uri = Uri.tryParse(value);
              if (uri == null || !uri.hasScheme) {
                return l10n.serverAddressInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.username),
            autocorrect: false,
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? l10n.usernameRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            decoration: InputDecoration(labelText: l10n.password),
            obscureText: true,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                (v?.isEmpty ?? true) ? l10n.passwordRequired : null,
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
        ],
      ),
    );
  }
}

/// Wordmark plus tagline: lowercase serif "patra" and the accent period.
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: 'patra',
            style: PatraText.serifTitle(size: 40),
            children: [
              TextSpan(
                text: '.',
                style: PatraText.serifTitle(size: 40, color: patraAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.appTagline, style: PatraText.metadata()),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.onTap,
    required this.onEdit,
    required this.onForget,
  });

  final ServerEntry server;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: patraSurface,
      borderRadius: BorderRadius.circular(radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusCard),
            border: Border.all(color: patraBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  // A live session opens with one tap; otherwise a password
                  // is still needed.
                  color: server.hasSession ? patraOnline : patraTextMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.rowTitle(),
                    ),
                    if (server.username.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(server.username, style: PatraText.metadata()),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.editServer,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: l10n.forgetServer,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onForget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
