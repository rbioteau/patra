import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks that this clone can merge the graph it tracks.
///
/// `graphify-out/graph.json` is committed, because it costs an LLM run to
/// make — and two branches that each rebuilt it would otherwise conflict on
/// tens of thousands of lines of machine-written JSON, which nobody can
/// resolve by hand. What prevents that is a union merge driver, and it is in
/// two halves: `.gitattributes` *names* one for the graph, and the name is all
/// a repository is able to carry. The command behind the name lives in the
/// clone's own `git config`, which is not cloned and not committable.
///
/// So the half that travels is checked always, and the half that does not is
/// checked wherever graphify is installed — which is exactly where the graph
/// is rebuilt, and therefore the only place a merge has anything to reconcile.
/// Elsewhere (CI, a clone that only reads the graph) there is nothing to
/// register and the check skips rather than failing for a setup nobody needs.
///
/// **A failure here is local setup, never the code.** `graphify hook install`
/// registers both halves; `graphify hook status` reports them.
void main() {
  /// The attribute is `graphify-out/graph.json merge=graphify`, written by
  /// graphify itself. Matched as fields rather than as a string so that
  /// whitespace and a second attribute on the line are not a failure.
  const graph = 'graphify-out/graph.json';

  final inRepo = _git(['rev-parse', '--is-inside-work-tree'])?.exitCode == 0;
  final driver = inRepo ? _config('merge.graphify.driver') : null;

  /// Whether this machine could run a driver at all. Looked up on PATH rather
  /// than by spawning it: no `.exe`/`.bat` suffix is tried, so on Windows this
  /// reads as "not installed" and the checks below skip — the safe direction
  /// for a check whose whole subject is a per-machine path.
  final installed = _onPath('graphify');

  test('the tracked graph asks for the union merge driver', () {
    final attributes = File('.gitattributes');
    expect(
      attributes.existsSync(),
      isTrue,
      reason: '.gitattributes is gone, and with it the only half of the merge '
          'driver a clone inherits',
    );
    final declared = attributes.readAsLinesSync().any((line) {
      final fields = line.trim().split(RegExp(r'\s+'));
      return fields.first == graph && fields.skip(1).contains('merge=graphify');
    });
    expect(
      declared,
      isTrue,
      reason: 'add `$graph merge=graphify` to .gitattributes, or run '
          '`graphify hook install`',
    );
  });

  test('the graph that attribute names is the graph we track', () {
    // The two are one decision. A driver declared for a file nobody tracks is
    // dead config, and a tracked graph with no driver is the unresolvable
    // conflict this exists to avoid — so neither is allowed to drift alone.
    expect(
      _git(['ls-files', '--error-unmatch', graph])?.exitCode,
      0,
      reason: '$graph is not tracked; either track it or drop the '
          '.gitattributes line that claims to merge it',
    );
  }, skip: inRepo ? null : 'not a git work tree');

  test('this clone has registered the driver the attribute names', () {
    // `merge=graphify` resolves through `merge.graphify.driver`, and git
    // falls back to an ordinary conflict when that key is absent — silently,
    // at the one moment it was supposed to help.
    expect(
      driver,
      isNotNull,
      reason: 'run `graphify hook install` to register '
          'merge.graphify.driver in this clone',
    );
    expect(
      _config('merge.graphify.name'),
      isNotNull,
      reason: 'merge.graphify.name is what `git config --list` and '
          '`graphify hook status` read back; run `graphify hook install`',
    );
  }, skip: _skipUnlessInstalled(inRepo, installed));

  test('the registered driver still points at something that exists', () {
    // graphify pins the interpreter by absolute path (so the driver works
    // when its launcher is not on PATH at merge time), which is precisely
    // what a pyenv or uv upgrade moves out from under it. Nothing reports
    // that until a merge tries to run it.
    final command = _command(driver!);
    expect(
      command.contains('/') || command.contains(r'\')
          ? File(command).existsSync()
          : _onPath(command),
      isTrue,
      reason: '`$command` is gone — the driver was pinned to an interpreter '
          'this machine no longer has. Re-run `graphify hook install`',
    );
  }, skip: driver == null ? 'no driver registered' : null);
}

String? _skipUnlessInstalled(bool inRepo, bool installed) {
  if (!inRepo) return 'not a git work tree';
  if (!installed) {
    return 'graphify is not installed here, so this clone never rebuilds the '
        'graph and has nothing to merge';
  }
  return null;
}

ProcessResult? _git(List<String> arguments) {
  try {
    return Process.runSync('git', arguments);
  } on ProcessException {
    return null; // No git on this machine; every check that needs it skips.
  }
}

/// The value of a git config key, or null when it is unset — which is what
/// `--get` reports through a non-zero exit rather than through empty output.
String? _config(String key) {
  final result = _git(['config', '--get', key]);
  if (result == null || result.exitCode != 0) return null;
  final value = (result.stdout as String).trim();
  return value.isEmpty ? null : value;
}

/// The executable out of a driver string. git runs it through a shell, and
/// graphify double-quotes the interpreter because a Windows profile path may
/// carry a space, so the quotes come back off here.
String _command(String driver) {
  final trimmed = driver.trim();
  if (trimmed.startsWith('"')) {
    final end = trimmed.indexOf('"', 1);
    if (end > 0) return trimmed.substring(1, end);
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

bool _onPath(String name) {
  final path = Platform.environment['PATH'];
  if (path == null) return false;
  for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
    if (directory.isEmpty) continue;
    if (File('$directory${Platform.pathSeparator}$name').existsSync()) {
      return true;
    }
  }
  return false;
}
