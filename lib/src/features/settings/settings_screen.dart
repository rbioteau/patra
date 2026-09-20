import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/client_identity.dart';
import '../../auth/session.dart';
import '../../branding/patra_lockup.dart';
import '../../catalogue/catalogue_provider.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/image_cache_store.dart';
import '../../format.dart';
import '../../lifecycle.dart';
import '../../lock/profile_lock.dart';
import '../../settings/cache_settings.dart';
import '../../settings/locale_settings.dart';
import '../../settings/profile_preferences.dart';
import '../../theme.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/profile_lock_sheet.dart';
import '../downloads/resume_strip.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        // The strip a cold start draws, above this screen's own body.
        child: DownloadsResumeStrip(
          child: ListView(
            padding: const EdgeInsets.only(bottom: sectionGap),
            children: [
              // One heading for one subject: who is reading, on what server,
              // and who else this device knows. It said "Server" while the
              // card below described a server and borrowed a verb about a
              // profile, which is where its label ran off the row.
              _Section(label: l10n.profilesSectionLabel),
              if (session != null) ...[
                _ActiveProfileCard(
                  profile: session,
                  onTap: () => ref.read(authProvider.notifier).switchProfile(),
                ),
                _ProfileLockRow(profile: session),
              ],
              const _OtherProfiles(),
              // With the people it is about, rather than after the licences.
              // It kept its shape — a bordered button and not one of the
              // icons the rows above carry — because forgetting the profile
              // being read as ends the session, which the other verb does
              // not.
              if (session != null) ...[
                const SizedBox(height: 12),
                _ForgetProfile(profile: session),
              ],

              _Section(label: l10n.generalSectionLabel),
              _SettingRow(
                icon: const Icon(Icons.language, size: 18, color: patraAccent),
                title: l10n.appLanguage,
                value: locale == null
                    ? l10n.appLanguageSystem
                    : languageEndonym(locale),
                onTap: () => _pickLanguage(context, ref, locale),
              ),

              // There is no reading section here any more (#58): everything the
              // reader's preferences can be is set from the reader's own sheet,
              // which is where somebody notices they want them. What this held
              // was a default for every series at once, which is precisely the
              // wrong shape for a direction (ADR-0007).
              _Section(label: l10n.storageSectionLabel),
              const _StorageRows(),

              _Section(label: l10n.aboutSectionLabel),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: gutter,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const PatraLockup(size: 18),
                        const SizedBox(width: 10),
                        // The tagline is a sentence: it wraps here rather than
                        // running off the row.
                        Expanded(
                          child: Text(
                            l10n.appTagline,
                            style: PatraText.metadata(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _AppVersion(),
                  ],
                ),
              ),

              // What the app is built from, reachable. The bundled faces
              // register their OFL notices into Flutter's `LicenseRegistry` and
              // every package's own licence arrives in the `NOTICES` asset the
              // build writes, and neither is worth much if a reader cannot open
              // it: this row is the attribution MIT and BSD ask for, and the
              // OFL with it.
              _SettingRow(
                // Neither progress nor a download, so no colour — the palette's
                // two hard rules say which of the two a row is, and this is
                // neither. The same reason the cached-images row has none.
                icon: const Icon(Icons.description_outlined, size: 18),
                title: l10n.licensesTitle,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: ClientIdentity.appName,
                  applicationVersion: ref
                      .watch(clientIdentityProvider)
                      .appVersion,
                  // On the root navigator, as `/series` and `/reader` are
                  // declared outside the shell: this is a page of its own
                  // rather than a tab's child, and a bar of tabs under a
                  // document that scrolls for pages says otherwise.
                  useRootNavigator: true,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  /// The languages this build ships, under their own names, with the device's
  /// own choice at the top.
  ///
  /// The list is derived from `supportedLocales` rather than written out, so a
  /// new translation appears here by existing. Each is named in its own
  /// language and never translated: someone who has landed in a language they
  /// cannot read has to be able to find their way out of it.
  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Null is a value here, not the absence of one, so the sheet answers with
    // whether a choice was made rather than with the choice itself.
    final picked = await showModalBottomSheet<({Locale? locale})>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _SheetColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
              child: SectionLabel(l10n.appLanguage),
            ),
            for (final option in <Locale?>[
              null,
              ...AppLocalizations.supportedLocales,
            ])
              _LanguageTile(
                label: option == null
                    ? l10n.appLanguageSystem
                    : languageEndonym(option),
                selected: option == current,
                onTap: () => Navigator.of(sheetContext).pop((locale: option)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(localeProvider.notifier).set(picked.locale);
    }
  }
}

/// Removing a profile from the device, credential and all — the confirmation
/// that stands in front of every path to it.
///
/// The whole of the guard lives here rather than on the picker, and the move
/// is the point rather than a tidy-up: the picker stands in front of every
/// session and asks for nothing, so the press that used to be there let
/// anybody holding the device remove anybody. Reaching Settings means having
/// entered a profile, which means holding a credential on this device.
///
/// It names the person *and* the server, because one server holds several
/// profiles and it is one of them being removed rather than the address —
/// and it names the **saved reading** that goes with them. Those files
/// belong to this profile alone, so once it is gone nothing on any screen
/// could reach them or explain them: what is about to be deleted has to be
/// said while there is still somebody to say it to. A profile holding
/// nothing saved is told nothing, since a "0 MB" line is a sentence about
/// an absence.
Future<void> _confirmForget(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final l10n = AppLocalizations.of(context);
  // The store of the profile being removed, which is not necessarily the one
  // doing the removing: Settings tidies up every face this device holds,
  // including one nothing can sign into any more.
  final downloads = ref.read(profileDownloadsProvider(profile.id));
  final saved = await downloads.savedTotals();
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: patraSurface,
      title: Text(
        l10n.forgetProfileConfirm(profile.displayName, profile.host),
        style: PatraText.body(),
      ),
      content: saved.chapters == 0
          ? null
          : Text(
              l10n.forgetProfileDownloads(
                saved.chapters,
                formatBytes(l10n, saved.bytes),
              ),
              style: PatraText.metadata(),
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
    // The lock goes with the profile, before the profile does. One that
    // outlived it would sit in the keychain pointing at nobody — and would
    // lock this same person out on the day they sign back in, behind a PIN
    // nothing remembers asking them to choose.
    await ref.read(profileLocksProvider.notifier).clear(profile.id);
    // And what they had chosen for themselves, for the same reason: a row
    // left behind points at nobody, and would come back to whoever next signs
    // in under that id as a device they have never used.
    await ref.read(profilePreferencesStoreProvider).forget(profile.id);
    // The files first: forgetting the profile being read as ends the session
    // that owns the store, and a deletion asked for after that would be
    // asking a container on its way out. This is the only path to `forget`,
    // and has to stay so — a profile removed anywhere else would leave its
    // chapters on disk with nothing left that could reach or explain them.
    await downloads.removeAll();
    // And what the device remembered of their shelves, which is theirs alone
    // for the same reason. Deliberately **not** named in the confirmation
    // above: that copy lists what a person chose to keep and what losing it
    // costs them, and a catalogue is neither — every byte of it is one
    // refresh away from coming back.
    await ref.read(profileCatalogueProvider(profile.id)).removeAll();
    // That person alone: the others on their server stay, because somebody
    // leaving the household is not the server being forgotten. Removing the
    // profile being read as ends the session, and the redirect then lands on
    // whichever gate the device now belongs at.
    await ref.read(authProvider.notifier).forget(profile.id);
  }
}

/// Everybody else this device remembers, so that a profile can be removed
/// without being signed into first.
///
/// This is what makes "profile management lives in Settings" true rather than
/// half true. Removing only the *active* profile would mean a household of
/// four signing into each in turn to tidy up — and a profile nothing can sign
/// into any more (an account deleted on the server) could never be removed at
/// all, which is a face stuck on the picker for good.
///
/// Renders nothing on a device holding one profile: an empty section under a
/// heading says less than no section.
class _OtherProfiles extends ConsumerWidget {
  const _OtherProfiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final others = [
      for (final profile in auth.profiles)
        if (profile.id != auth.activeId) profile,
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    // The same rule the picker follows: the host tells two faces apart, and
    // with one server remembered it is the same word under every one.
    final showHost = auth.servers.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(label: l10n.otherProfilesSectionLabel),
        for (final profile in others)
          _OtherProfileRow(profile: profile, showHost: showHost),
      ],
    );
  }
}

class _OtherProfileRow extends ConsumerWidget {
  const _OtherProfileRow({required this.profile, required this.showHost});

  final Profile profile;
  final bool showHost;

  /// Big enough to recognise a face by, small enough to read as a row rather
  /// than as the picker's own faces, which are what a person taps to enter.
  static const _avatarSize = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
      // One stop for a screen reader, announced whole: the name, the server
      // where there is one worth saying, and the one thing that can be done
      // about it.
      child: MergeSemantics(
        child: Row(
          children: [
            ProfileAvatar(profile: profile, size: _avatarSize),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.rowTitle(),
                  ),
                  if (showHost) ...[
                    const SizedBox(height: 2),
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
            // No tap on the row itself: entering a profile is the picker's
            // job, and a row that both opened and removed a person would be
            // one gesture away from the wrong one.
            IconButton(
              tooltip: l10n.forgetProfile,
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 20,
                color: patraDanger,
              ),
              onPressed: () => _confirmForget(context, ref, profile),
            ),
          ],
        ),
      ),
    );
  }
}

/// Removing the profile the app is being read as, which ends the session.
class _ForgetProfile extends ConsumerWidget {
  const _ForgetProfile({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter),
      child: Align(
        child: ConstrainedBox(
          // One short phrase; a button as wide as the screen reads as a
          // banner rather than as something to press.
          constraints: const BoxConstraints(maxWidth: 280),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmForget(context, ref, profile),
              style: OutlinedButton.styleFrom(
                foregroundColor: patraDanger,
                side: BorderSide(color: patraDanger.withValues(alpha: .45)),
              ),
              child: Text(l10n.forgetThisProfile),
            ),
          ),
        ),
      ),
    );
  }
}

/// The PIN in front of the profile being read as.
///
/// A switch rather than a row that opens a menu, because there are two states
/// and the third thing a person might want — a different PIN — is a line of
/// its own underneath rather than a mode of the same control.
///
/// It lives here and not on the picker for the same reason removing a profile
/// does: the picker stands in front of every session and asks for nothing, so
/// a lock that could be set or taken off from there would be one anybody
/// holding the device could take off. Reaching Settings means having got
/// past this lock already, which is also why changing or clearing it does not
/// ask for the current PIN a second time.
///
/// **Only the profile being read as**, which is the one place Settings does
/// *not* manage every remembered face — and the asymmetry is the whole point.
/// A lock is chosen by the person it stands in front of: setting one on
/// somebody else's face would shut them out behind a PIN nobody told them,
/// and clearing one would be taking their lock off for them. Removing a
/// profile stays the household-wide verb it was, and takes that person's
/// lock with it.
class _ProfileLockRow extends ConsumerWidget {
  const _ProfileLockRow({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locked = ref.watch(profileLocksProvider).containsKey(profile.id);

    Future<void> change(bool on) async {
      if (!on) {
        // The lock alone. Taking a PIN off is not removing the profile, and
        // what that person has chosen for themselves is none of its business.
        await ref.read(profileLocksProvider.notifier).clear(profile.id);
        return;
      }
      // Nothing is read back: the switch draws the lock itself, watched
      // above, so a PIN sheet backed out of leaves the profile unlocked and
      // the switch where it was.
      await chooseProfilePin(context, profile);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwitchRow(
          icon: Icon(
            locked ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 18,
            color: patraAccent,
          ),
          title: l10n.profileLock,
          // Says what it does *and* what it is not. The auth key this device
          // keeps for the profile is a whole Kavita account and only its
          // owner can rotate one (ADR-0004), so a lock that let anybody read
          // it as protection for a lost device would be a lie the app told.
          subtitle: l10n.profileLockExplained,
          value: locked,
          onChanged: change,
        ),
        if (locked)
          _UnderRow(
            child: InkWell(
              onTap: () => chooseProfilePin(context, profile),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.profileLockChange,
                  style: PatraText.metadata(color: patraAccent),
                ),
              ),
            ),
          )
        // Suggested to a profile the server holds back from nothing — an
        // administrator counted among them whatever rating is set on it,
        // since an admin can edit any account's restriction including their
        // own. **Never** to a restricted one: that account is already
        // limited by the server, and what its restriction cannot do is
        // anything at all once its owner is reading inside somebody else's
        // session (ADR-0003).
        else if (suggestsLock(profile))
          _UnderRow(
            child: Text(
              l10n.profileLockSuggested,
              style: PatraText.metadata(color: patraAccent),
            ),
          ),
      ],
    );
  }
}

/// A line that belongs to the row above it: indented past that row's icon so
/// it reads as part of it rather than as a row of its own.
class _UnderRow extends StatelessWidget {
  const _UnderRow({required this.child});

  final Widget child;

  /// The gutter plus the width a [_SwitchRow] gives its icon and the gap
  /// after it, so this line starts where that row's text does.
  static const _indent = gutter + 36;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(_indent, 0, gutter, 10),
    child: child,
  );
}

/// A setting that is simply on or off, with a line saying what turning it on
/// changes. The subtitle is not decoration here: this one takes the swipe that
/// turns a page away, and a switch alone would not say so.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: minHitTarget),
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        // The switch is the control, and the row is one thing to a screen
        // reader rather than a label and a toggle announced apart.
        child: MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PatraText.body()),
                    const SizedBox(height: 2),
                    Text(subtitle, style: PatraText.metadata()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the app is keeping on the device, and the one thing worth clearing.
class _StorageRows extends ConsumerWidget {
  const _StorageRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final downloads = ref.watch(downloadsProvider).value;
    final cacheSize = ref.watch(imageCacheSizeProvider);
    final cacheLimit = ref.watch(imageCacheLimitProvider);
    final batchSize = ref.watch(batchDownloadSizeProvider);

    return Column(
      children: [
        // Saved chapters: shown for context, managed in the Downloads tab.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                child: Icon(Icons.download_done, size: 18, color: patraOffline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.downloadedChapters(downloads?.saved.length ?? 0),
                  style: PatraText.body(),
                ),
              ),
              Text(
                formatBytes(l10n, downloads?.totalBytes ?? 0),
                style: PatraText.metadata(),
              ),
            ],
          ),
        ),
        // What one tap on a series saves for the road (#101). A person's,
        // behind a device default of three — see `lib/src/settings/CLAUDE.md`
        // — and under Storage rather than General because it is a choice
        // about what goes on the disk. In the offline blue: it is about
        // downloads, like the row above it.
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 22,
                child: Icon(
                  Icons.playlist_add_check,
                  size: 18,
                  color: patraOffline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _pickBatchSize(context, ref, batchSize),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.batchDownloadSize,
                                style: PatraText.body(),
                              ),
                            ),
                            Text(
                              l10n.batchDownloadSizeOption(batchSize.value),
                              style: PatraText.metadata(color: patraAccent),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      l10n.batchDownloadSizeCaption,
                      style: PatraText.metadata(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 22,
                child: Icon(Icons.image_outlined, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.imageCacheLabel,
                            style: PatraText.body(),
                          ),
                        ),
                        Text(
                          formatBytes(l10n, cacheSize.value ?? 0),
                          style: PatraText.metadata(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.imageCacheCaption, style: PatraText.metadata()),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _pickLimit(context, ref, cacheLimit),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.imageCacheLimit,
                                style: PatraText.body(),
                              ),
                            ),
                            Text(
                              formatBytes(l10n, cacheLimit.bytes),
                              style: PatraText.metadata(color: patraAccent),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      l10n.imageCacheLimitCaption,
                      style: PatraText.metadata(),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(imageCacheStoreProvider).clear();
                        ref.invalidate(imageCacheSizeProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(l10n.clearCache),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The same sheet as the budget's, over the four sizes #101 names.
  Future<void> _pickBatchSize(
    BuildContext context,
    WidgetRef ref,
    BatchDownloadSize current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<BatchDownloadSize>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _SheetColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
              child: SectionLabel(l10n.batchDownloadSize),
            ),
            for (final option in BatchDownloadSize.values)
              ListTile(
                title: Text(
                  l10n.batchDownloadSizeOption(option.value),
                  style: PatraText.body(
                    color: option == current ? patraAccent : patraText,
                  ),
                ),
                trailing: option == current
                    ? const Icon(Icons.check, color: patraAccent, size: 18)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(batchDownloadSizeProvider.notifier).set(picked);
  }

  /// Picking a smaller budget has to bite right away, not on the next launch.
  Future<void> _pickLimit(
    BuildContext context,
    WidgetRef ref,
    ImageCacheLimit current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<ImageCacheLimit>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _SheetColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
              child: SectionLabel(l10n.imageCacheLimit),
            ),
            for (final option in ImageCacheLimit.values)
              ListTile(
                title: Text(
                  formatBytes(l10n, option.bytes),
                  style: PatraText.body(
                    color: option == current ? patraAccent : patraText,
                  ),
                ),
                trailing: option == current
                    ? const Icon(Icons.check, color: patraAccent, size: 18)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(imageCacheLimitProvider.notifier).set(picked);
    await ref.read(imageCacheStoreProvider).trim(picked.bytes);
    ref.invalidate(imageCacheSizeProvider);
  }
}

/// The rows of a bottom sheet, held to the same column as the screen behind
/// it: a full-width tablet sheet puts its ticks against the far edge.
class _SheetColumn extends StatelessWidget {
  const _SheetColumn({required this.mainAxisSize, required this.children});

  final MainAxisSize mainAxisSize;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: mainAxisSize, children: children);
}

/// Which Patra this is.
///
/// Read off the binary rather than compiled in: CI passes the release tag to
/// `--build-name`, so what is shown here is the version that shipped, with
/// nothing in the repository to keep in step with it.
class _AppVersion extends ConsumerWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.aboutVersion(ref.watch(clientIdentityProvider).appVersion),
      style: PatraText.metadata(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
      child: SectionLabel(label),
    );
  }
}

/// The active server, with an indicator saying whether it is actually there.
///
/// The dot used to be a `const` [patraOnline]: it said "connected" from the
/// moment the screen was drawn, with nothing behind it. It now reads a real
/// probe, and re-runs it when the app comes back to the foreground — which
/// is where connectivity usually changes, and the four tabs live in an
/// `IndexedStack`, so this card is never rebuilt from scratch and nothing
/// else would think to ask again.
/// The profile being read as, and the server it is on.
///
/// It was a card about the **server** that borrowed a verb about a
/// **profile**, and the two together are what broke it: the verb sat in the
/// row as a `Text` with no flex of its own, so "Switch profile" took its
/// intrinsic width, squeezed what was beside it and then ran off the row
/// outright under a large system font. Shortening the word would have moved
/// that threshold rather than removed it.
///
/// Drawn as a profile instead, the verb has nothing to say: a face that opens
/// opens the [[Picker]], which is exactly what the face on the Home bar
/// already means, and the chevron alone carries it. What is left is
/// `avatar + Expanded(text) + chevron`, a row with no competitor for width,
/// which cannot overflow however the type is scaled — pinned at 320pt by
/// `test/settings_test.dart`.
///
/// The state dot went down with the host it qualifies. It is about the
/// **server**, and above the host it would have read as a state of the
/// person; an avatar is also where the picker draws its own badge, and two
/// vocabularies on one face is one too many.
class _ActiveProfileCard extends ConsumerStatefulWidget {
  const _ActiveProfileCard({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  ConsumerState<_ActiveProfileCard> createState() => _ActiveProfileCardState();
}

class _ActiveProfileCardState extends ConsumerState<_ActiveProfileCard> {
  /// Larger than the 32 an other-profile row carries: this is the face the
  /// app is being read as, and the card is the one place it is stated.
  static const _avatarSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Coming back to the foreground is when a server that was upgraded has to
    // be asked again: Kavita pushes `UpdateAvailable` to admins only and has
    // no restart event at all, so a spell of unreachability and a return is
    // the only thing noticing it can be made of. Listened to rather than
    // watched, and through the app's one lifecycle seam (`appLifecycleProvider`)
    // rather than an observer of its own — two answers to one platform fact
    // is how they come to disagree.
    ref.listen(appLifecycleProvider, (_, state) {
      if (state != AppLifecycleState.resumed) return;
      ref.invalidate(serverReachableProvider);
      ref.invalidate(serverVersionProvider);
    });
    // A request that has just failed is fresher news than a probe that
    // succeeded a while ago, so being offline outranks a stale success.
    // Null is "not known yet", which is neither colour.
    final probe = ref.watch(serverReachableProvider);
    final offline = ref.watch(offlineProvider);
    final reachable = offline ? false : probe.value;
    // `.value` rather than a pattern match on the state, so a refresh keeps
    // painting the last answer instead of blanking the line on every
    // foreground. Offline suppresses it outright: a version is only ever
    // true of a server we can reach right now, and a card that reads
    // "Kavita 0.9.1.4 · Offline" asserts a fact about the server in the
    // same breath as admitting it cannot reach it.
    final version = reachable == false
        ? null
        : ref.watch(serverVersionProvider).value;
    final (dotColor, status) = switch (reachable) {
      true => (patraOnline, l10n.serverOnline),
      false => (patraDanger, l10n.serverOffline),
      null => (patraTextMuted, l10n.serverChecking),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter),
      child: Material(
        color: patraSurface,
        borderRadius: BorderRadius.circular(radiusCard),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radiusCard),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusCard),
              border: Border.all(color: patraBorder),
            ),
            // One stop for a screen reader, announced whole: whose profile
            // this is, where it lives, and how that server is answering.
            child: MergeSemantics(
              child: Row(
                children: [
                  ProfileAvatar(profile: widget.profile, size: _avatarSize),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // The same name the rows underneath use. A server
                          // has no business being named two ways on one
                          // screen, and `username` was the other way.
                          widget.profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PatraText.rowTitle(),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // The state reaches a screen reader as a word; an
                            // 8pt dot that only changes colour reaches no one
                            // who cannot tell these two colours apart.
                            Semantics(
                              label: status,
                              child: Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Flexible(
                              // Always drawn, unlike the host under an other
                              // profile's name, which only appears where the
                              // device knows several servers: this is the one
                              // card carrying a server's state, and a dot with
                              // nothing beside it qualifies nothing.
                              child: Text(
                                widget.profile.host,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PatraText.metadata(),
                              ),
                            ),
                            // Not flexible: eight characters that a long host
                            // should shorten around rather than push off the
                            // row. It can never share the line with the
                            // status word — being offline is what takes the
                            // version away.
                            if (version != null) ...[
                              Text(' · ', style: PatraText.metadata()),
                              Text(
                                l10n.serverVersion(version),
                                style: PatraText.metadata(),
                              ),
                            ],
                            // Said in words only when it is bad news: a green
                            // dot needs no caption, an unreachable server
                            // does.
                            if (reachable == false) ...[
                              Text(' · ', style: PatraText.metadata()),
                              Text(
                                status,
                                style: PatraText.metadata(color: patraDanger),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the language sheet. The device's own choice carries no flag or
/// globe of its own: a language is not a country, and picking an icon for one
/// is picking a country for it.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: PatraText.body(color: selected ? patraAccent : patraText),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: patraAccent, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  final Widget icon;
  final String title;

  /// What the row has to report, on the trailing edge — the language in force,
  /// and so on. A row that only opens a page has nothing to report, and says
  /// so with the chevron alone rather than an empty gap where a value goes.
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHitTarget),
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 22, child: Center(child: icon)),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: PatraText.body())),
            if (value != null) ...[
              Text(value!, style: PatraText.metadata()),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
