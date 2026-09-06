import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../theme.dart';

/// A profile's face: the avatar Kavita holds for the account, or its initial
/// on the colour Kavita paints that account in.
///
/// Everything it draws comes off the [Profile] itself, and that is what makes
/// the picker work with no network: the colour and whether there is a picture
/// at all were learned at the last sign-in and written down, and the picture
/// itself comes out of the image cache.
///
/// The picture is the one part that can go missing. It shares the ordinary
/// image cache, which `ImageCacheStore.trim` sweeps oldest-first against the
/// budget in Settings — and an avatar is written once and never rewritten, so
/// it is among the first files out. That is accepted rather than worked
/// around with a store of its own: online the next draw fetches it again, and
/// offline the face falls back to the initial on its colour, which is what
/// this screen is specified to do for an account that never had a picture.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.size = 72,
    this.dimmed = false,
  });

  final Profile profile;
  final double size;

  /// Whether this profile is drawn as needing something before it opens — a
  /// key the server has refused, which costs a password. The face is still
  /// recognisably itself, only quieter.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = profileColor(profile.color);
    final url = profile.avatarUrl;
    final face = DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: url == null
              ? _Initial(profile: profile, size: size, on: color)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  // Both fall back to the initial rather than to a spinner or
                  // a broken-image glyph: a face that has not arrived is
                  // still this person, and offline it never arrives at all.
                  placeholder: (_, _) =>
                      _Initial(profile: profile, size: size, on: color),
                  errorWidget: (_, _, _) =>
                      _Initial(profile: profile, size: size, on: color),
                ),
        ),
      ),
    );
    return dimmed ? Opacity(opacity: .45, child: face) : face;
  }
}

/// The letter a face falls back to, drawn to read against whatever colour
/// Kavita gave the account.
class _Initial extends StatelessWidget {
  const _Initial({required this.profile, required this.size, required this.on});

  final Profile profile;
  final double size;
  final Color on;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName;
    // `characters`, not `substring(0, 1)`: a name starting with an astral
    // character — an emoji, some CJK extensions — would otherwise be cut in
    // half and drawn as a replacement glyph, and a username is whatever
    // somebody typed into Kavita.
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      // A Container rather than a bare Center: the colour is drawn here as
      // well as behind the image, so the letter has its ground even where an
      // avatar was expected and never arrived.
      decoration: BoxDecoration(color: on, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: PatraText.rowTitle(
          size: size * .4,
          // Kavita lets an account pick its own colour, so nothing here can
          // assume a dark one: ask which of black or white reads on it.
          color: ThemeData.estimateBrightnessForColor(on) == Brightness.dark
              ? Colors.white
              : patraInk,
        ),
      ),
    );
  }
}

/// The colour Kavita gave an account, as a colour.
///
/// Kavita writes it the way CSS does (`#4AC694`) and the value reaches us
/// verbatim, so this is where it is understood — or not: anything unreadable,
/// and an account that never picked one, falls back to [patraAccent], which
/// is the app's own colour for identity. Never to a neutral: a face with no
/// colour would be one that fails to be told apart.
Color profileColor(String value) {
  final hex = value.trim().replaceFirst('#', '');
  final rgb = int.tryParse(hex, radix: 16);
  if (rgb == null) return patraAccent;
  return switch (hex.length) {
    6 => Color(0xFF000000 | rgb),
    8 => Color(rgb),
    _ => patraAccent,
  };
}
