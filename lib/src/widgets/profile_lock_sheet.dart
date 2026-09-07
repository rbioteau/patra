/// The one surface a PIN is ever typed on — asking for it, and setting it.
///
/// Both flows are the same four dots and the same pad, because they are the
/// same secret: a person choosing a PIN is rehearsing the gesture they will
/// make to get back in, and a second layout would be a second thing to learn.
/// What differs is the heading and what happens when the fourth digit lands.
///
/// A **pad rather than a text field**. The PIN is four digits and nothing
/// else, so a keyboard would offer punctuation, a return key and a candidate
/// bar for none of them — and on the picker it would slide up over the faces
/// the sheet is drawn in front of.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/session.dart';
import '../lock/biometrics.dart';
import '../lock/profile_lock.dart';
import '../theme.dart';

/// Asks for [profile]'s PIN, and answers whether it was given.
///
/// The device's own prompt is offered **first** where there is one, because
/// it is the faster of the two and the PIN is what it falls back to — the pad
/// is already on screen behind it, so a prompt that is cancelled, refused or
/// never shown costs nothing but the tap that was going to be typed anyway.
Future<bool> askProfilePin(BuildContext context, Profile profile) async =>
    await _show(context, profile, choosing: false) ?? false;

/// Asks for a new PIN twice and gives [profile] the lock it makes.
///
/// Answers nothing, deliberately: what the row that opened this draws is the
/// lock itself, watched through the provider, so a sheet backed out of leaves
/// the switch where it was without anybody having to carry the news back.
Future<void> chooseProfilePin(BuildContext context, Profile profile) =>
    _show(context, profile, choosing: true);

Future<bool?> _show(
  BuildContext context,
  Profile profile, {
  required bool choosing,
}) => showModalBottomSheet<bool>(
  context: context,
  backgroundColor: patraSurface,
  isScrollControlled: true,
  builder: (sheetContext) =>
      _LockSheet(profile: profile, choosing: choosing),
);

class _LockSheet extends ConsumerStatefulWidget {
  const _LockSheet({required this.profile, required this.choosing});

  final Profile profile;

  /// Setting a PIN rather than being asked for one: two steps instead of one,
  /// and no biometrics — there is nothing to recognise anybody against yet.
  final bool choosing;

  @override
  ConsumerState<_LockSheet> createState() => _LockSheetState();
}

class _LockSheetState extends ConsumerState<_LockSheet> {
  String _typed = '';

  /// The first of the two PINs while one is being chosen, and null while the
  /// first is still being typed.
  String? _first;
  String? _error;

  /// Whether this device can be asked to recognise its owner. Null while the
  /// question is still out, which is why the button is not drawn yet.
  bool? _biometrics;

  @override
  void initState() {
    super.initState();
    if (!widget.choosing) unawaited(_offerBiometrics());
  }

  /// Asks the device, and asks it again for every subsequent try by hand.
  Future<void> _offerBiometrics() async {
    final biometrics = ref.read(biometricsProvider);
    final available = await biometrics.available();
    if (!mounted) return;
    setState(() => _biometrics = available);
    if (available) await _promptBiometrics();
  }

  Future<void> _promptBiometrics() async {
    final l10n = AppLocalizations.of(context);
    final recognised = await ref
        .read(biometricsProvider)
        .prompt(l10n.profileLockBiometricReason(widget.profile.displayName));
    if (!mounted) return;
    // A refusal is not an error worth a sentence: the pad is right there, and
    // saying "that did not work" over a prompt the person may simply have
    // dismissed is noise.
    if (recognised) Navigator.of(context).pop(true);
  }

  void _press(String digit) {
    if (_typed.length >= ProfileLock.pinLength) return;
    setState(() {
      _typed += digit;
      _error = null;
    });
    if (_typed.length == ProfileLock.pinLength) _submit();
  }

  void _backspace() {
    if (_typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final typed = _typed;
    final locks = ref.read(profileLocksProvider.notifier);

    if (!widget.choosing) {
      if (locks.unlocks(widget.profile.id, typed)) {
        Navigator.of(context).pop(true);
        return;
      }
      // Refused and asked again, in place: there is no attempt to count and
      // nothing to lock out. What this stands between is family members, and
      // a device that punished a mistyped digit would be punishing its owner.
      setState(() {
        _typed = '';
        _error = l10n.profileLockWrong;
      });
      return;
    }

    final first = _first;
    if (first == null) {
      setState(() {
        _first = typed;
        _typed = '';
      });
      return;
    }
    if (first != typed) {
      // Back to the beginning rather than to the second step: the PIN that is
      // wrong is whichever of the two was mistyped, and there is no way to
      // know which.
      setState(() {
        _first = null;
        _typed = '';
        _error = l10n.profileLockMismatch;
      });
      return;
    }
    // Only on a lock that really was set: the pad cannot produce anything
    // else, but a sheet that closed on a refusal would leave a profile open
    // having just told somebody it was locked.
    final locked = await locks.set(widget.profile.id, typed);
    if (mounted) Navigator.of(context).pop(locked);
  }

  String _heading(AppLocalizations l10n) {
    if (!widget.choosing) {
      return l10n.profileLockEnterFor(widget.profile.displayName);
    }
    return _first == null ? l10n.profileLockChoose : l10n.profileLockRepeat;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A sentence rather than a `SectionLabel`: that one uppercases,
            // which names a setting well and shouts a person's name.
            Text(
              _heading(l10n),
              textAlign: TextAlign.center,
              style: PatraText.body(),
            ),
            const SizedBox(height: 18),
            _PinDots(filled: _typed.length),
            const SizedBox(height: 10),
            // The line is always there, empty or not: a message that appears
            // pushes the pad down under the finger that is about to use it.
            SizedBox(
              height: 18,
              child: Text(
                _error ?? '',
                style: PatraText.metadata(color: patraDanger),
              ),
            ),
            const SizedBox(height: 6),
            _PinPad(
              onDigit: _press,
              onBackspace: _backspace,
              onBiometrics: _biometrics == true ? _promptBiometrics : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// How much of the PIN has been typed, and nothing about what it is.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < ProfileLock.pinLength; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? patraAccent : Colors.transparent,
              border: Border.all(
                color: i < filled ? patraAccent : patraTrack,
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ten digits, a backspace, and — where the device offers one — a way back to
/// its own prompt.
///
/// Held to [controlMaxWidth] like every other button in this app: a pad given
/// a tablet's width to fill puts its digits an arm apart, and the whole point
/// of a pad is that a thumb can reach all of them.
class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometrics,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Null where the device cannot be asked, which is the ordinary case.
  final VoidCallback? onBiometrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: controlMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                children: [
                  for (final digit in row)
                    Expanded(
                      child: _PadKey(
                        onPressed: () => onDigit(digit),
                        child: Text(digit, style: PatraText.body()),
                      ),
                    ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: switch (onBiometrics) {
                    // No sensor, or one the app cannot use: the key is left
                    // blank rather than drawn dead, and the pad keeps its
                    // shape either way.
                    null => const SizedBox(height: minHitTarget),
                    final ask => _PadKey(
                      tooltip: l10n.profileLockUseBiometrics,
                      onPressed: ask,
                      child: const Icon(
                        Icons.fingerprint,
                        size: 22,
                        color: patraAccent,
                      ),
                    ),
                  },
                ),
                Expanded(
                  child: _PadKey(
                    onPressed: () => onDigit('0'),
                    child: Text('0', style: PatraText.body()),
                  ),
                ),
                Expanded(
                  child: _PadKey(
                    tooltip: l10n.profileLockBackspace,
                    onPressed: onBackspace,
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.onPressed, required this.child, this.tooltip});

  final VoidCallback onPressed;
  final Widget child;

  /// Names the two keys that are not a digit; a digit says what it is.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final key = InkWell(
      onTap: () {
        // The pad has no sound and no shape under the finger, so the tick is
        // the only feedback that a digit landed.
        unawaited(HapticFeedback.selectionClick());
        onPressed();
      },
      borderRadius: BorderRadius.circular(radiusPill),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        child: child,
      ),
    );
    final labelled = tooltip == null
        ? key
        : Tooltip(message: tooltip!, child: key);
    return Padding(padding: const EdgeInsets.all(4), child: labelled);
  }
}
