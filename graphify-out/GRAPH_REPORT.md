# Graph Report - feat-17-deep-link-waits-for-profile  (2026-09-07)

## Corpus Check
- 120 files · ~213,498 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2683 nodes · 3728 edges · 128 communities (116 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `07eca93a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_fr.dart
- app_localizations_en.dart
- Thumbnail Strip Accordion
- reader_screen.dart
- models.dart
- launch_animation.dart
- theme.dart
- series_detail_screen.dart
- kavita_client.dart
- Launch Composition Timeline
- library_screen.dart
- Client Identity Headers
- session.dart
- profile_lock_sheet.dart
- reader_test.dart
- magnify_gesture.dart
- home_screen.dart
- patra_frond.dart
- downloads_screen.dart
- login_screen.dart
- CI Build and Release Workflow
- downloads_service.dart
- Linux GTK Runner
- cache_settings.dart
- kavita_client_test.dart
- series_sections_test.dart
- settings_screen.dart
- StatelessWidget
- test_support.dart
- continue_hero.dart
- app.dart
- launch_animation_test.dart
- downloads_provider.dart
- AppDelegate
- reading_settings.dart
- session_scope.dart
- server_reachability_test.dart
- image_cache_store.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- profile_switch_test.dart
- package:dio/dio.dart
- HttpClientAdapter
- main.dart
- resume_point.dart
- reader_settings_sheet.dart
- auth_test.dart
- package:flutter_test/flutter_test.dart
- cover.dart
- series_hero_test.dart
- static const
- Hand-Written Client Rationale
- profile_avatar.dart
- locale_settings.dart
- graphify_merge_driver_test.dart
- profile_lock_ui_test.dart
- home_hero_test.dart
- ../../l10n/generated/app_localizations.dart
- _ReaderScreenState
- Progress and Storage Invariants
- server_version_test.dart
- downloads_provider_test.dart
- image_cache_store_test.dart
- magnify_gesture_test.dart
- saved_chapters_per_profile_test.dart
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- deep_link_test.dart
- Domain Docs
- Auth State and Retry Policy
- Reader Direction and Magnify
- connection_failure_test.dart
- routes.dart
- ConsumerWidget
- Handoff and Tablet Rules
- Localization Delegate
- profile_picker_screen.dart
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- downloads_service_test.dart
- AuthNotifier
- App Icon Generation Script
- tablet_layout_test.dart
- Dependency and Icon Tooling
- MainActivity.kt
- List
- direction_icon.dart
- Patra and Kavita Identity
- ../theme.dart
- Localization Codegen Config
- Patra
- dart:convert
- ADR-0002 — One rule decides where reading resumes, and it is ours
- Issue tracker: GitHub
- build
- triage-labels.md
- entity_naming.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- package:flutter/material.dart
- profile_lock.dart
- connection_failure.dart
- _ServerCardState
- StatefulWidget
- patra_masthead.dart
- page_backdrop.dart
- _LockSheetState
- client_identity_test.dart
- _ThumbStripState
- LaunchScope
- Credential
- Profile
- page_loading.dart
- Map
- LockVault
- package:flutter_riverpod/flutter_riverpod.dart
- localeProvider
- bool?
- _SlotState
- ConsumerState
- CustomPainter
- MagnifyGesture
- SignInExpired

## God Nodes (most connected - your core abstractions)
1. `kavitaClientProvider` - 21 edges
2. `build` - 15 edges
3. `authProvider` - 13 edges
4. `offlineProvider` - 13 edges
5. `build` - 12 edges
6. `downloadsProvider` - 10 edges
7. `_ReaderScreenState` - 9 edges
8. `profileLocksProvider` - 9 edges
9. `sessionProvider` - 8 edges
10. `build` - 8 edges

## Surprising Connections (you probably didn't know these)
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml
- `The tag is the version` --conceptually_related_to--> `pubspec version is only a local-build fallback`  [INFERRED]
  .github/workflows/build.yml → pubspec.yaml
- `LibraryTypeNaming / entity_naming.dart` --implements--> `The fixed French glossary`  [EXTRACTED]
  CLAUDE.md → CONTEXT.md
- `serverReachableProvider (GET /api/Health probe)` --implements--> `Offline`  [INFERRED]
  CLAUDE.md → CONTEXT.md
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart

## Import Cycles
- None detected.

## Communities (128 total, 8 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (149): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+141 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (136): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+128 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (136): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+128 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (77): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters (+69 more)

### Community 6 - "launch_animation.dart"
Cohesion: 0.04
Nodes (53): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+45 more)

### Community 7 - "theme.dart"
Cohesion: 0.04
Nodes (54): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+46 more)

### Community 8 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (39): AsyncValue, Chapter, ResolvedFailure, _Buckets, _buildSections, chapter, child, clear (+31 more)

### Community 9 - "kavita_client.dart"
Cohesion: 0.04
Nodes (48): account_id.dart, Dio, Dio get, accountId, allSeriesForLibrary, apiKey, authKey, _bareDio (+40 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "library_screen.dart"
Cohesion: 0.09
Nodes (25): available, build, createState, _EmptyBody, _EmptyLibrary, _EmptyLibraryState, _gridColumns, _gridDelegate (+17 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "session.dart"
Cohesion: 0.04
Nodes (55): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+47 more)

### Community 14 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (28): askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing, createState (+20 more)

### Community 15 - "reader_test.dart"
Cohesion: 0.07
Nodes (29): Image, NeverScrollableScrollPhysics, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set, Switch (+21 more)

### Community 16 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (29): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+21 more)

### Community 17 - "home_screen.dart"
Cohesion: 0.07
Nodes (37): continue_hero.dart, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+29 more)

### Community 18 - "patra_frond.dart"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 19 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (29): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter, build (+21 more)

### Community 20 - "login_screen.dart"
Cohesion: 0.08
Nodes (24): FormState, _askForServer, _buildForm, _busy, child, createState, didChangeDependencies, dispose (+16 more)

### Community 21 - "CI Build and Release Workflow"
Cohesion: 0.09
Nodes (30): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+22 more)

### Community 22 - "downloads_service.dart"
Cohesion: 0.06
Nodes (32): bytes, chapterDir, chapterId, copyWith, _deleteQuietly, dirNameFor, download, _downloadsRoot (+24 more)

### Community 23 - "Linux GTK Runner"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "cache_settings.dart"
Cohesion: 0.16
Nodes (13): int get, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, ImageCacheSettingsStore, initialImageCacheLimitProvider (+5 more)

### Community 25 - "kavita_client_test.dart"
Cohesion: 0.10
Nodes (19): int?, SelectedLibraryNotifier, apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch (+11 more)

### Community 26 - "series_sections_test.dart"
Cohesion: 0.08
Nodes (25): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+17 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.06
Nodes (31): ../../downloads/image_cache_store.dart, actionLabel, _avatarSize, child, children, confirmed, createState, didChangeAppLifecycleState (+23 more)

### Community 28 - "StatelessWidget"
Cohesion: 0.09
Nodes (22): _LibraryCard, _Wordmark, _FlyingFrond, _SplashWordmark, _BottomChrome, _ReaderError, _SettingsCog, _SpineShadow (+14 more)

### Community 29 - "test_support.dart"
Cohesion: 0.06
Nodes (31): required int chapterId,
  String, available, bytes, channel, chapter, clear, clears, dir (+23 more)

### Community 30 - "continue_hero.dart"
Cohesion: 0.10
Nodes (19): ../../entity_naming.dart, Series, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+11 more)

### Community 31 - "app.dart"
Cohesion: 0.10
Nodes (19): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+11 more)

### Community 32 - "launch_animation_test.dart"
Cohesion: 0.09
Nodes (21): package:flutter/rendering.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size, _app, _appOpacity (+13 more)

### Community 33 - "downloads_provider.dart"
Cohesion: 0.10
Nodes (24): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+16 more)

### Community 34 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 35 - "reading_settings.dart"
Cohesion: 0.10
Nodes (23): bool get, leftToRight,
  rightToLeft,, OfflineNotifier, build, DefaultReadingDirectionNotifier, initialMagnifyProvider, initialReadingDirectionProvider, isRightToLeft (+15 more)

### Community 36 - "session_scope.dart"
Cohesion: 0.11
Nodes (18): auth, build, child, _container, createState, dispose, _entered, initState (+10 more)

### Community 37 - "server_reachability_test.dart"
Cohesion: 0.11
Nodes (17): _announcement, card, client, close, dot, _dotColor, fetch, handle (+9 more)

### Community 38 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 39 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 40 - "profile_switch_test.dart"
Cohesion: 0.06
Nodes (35): package:patra/src/session_scope.dart, package:patra/src/widgets/offline_indicator.dart, required Credential credential,
  ClientIdentity, _app, attempts, close, fetch, identity (+27 more)

### Community 41 - "package:dio/dio.dart"
Cohesion: 0.10
Nodes (19): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+11 more)

### Community 42 - "HttpClientAdapter"
Cohesion: 0.14
Nodes (14): HttpClientAdapter, _StubAdapter, _KavitaLikeAdapter, _HomeAdapter, _Adapter, _UnreachableAdapter, _Adapter, _Adapter (+6 more)

### Community 43 - "main.dart"
Cohesion: 0.10
Nodes (19): auth, cacheLimit, identity, imageCache, load, locale, locks, magnify (+11 more)

### Community 44 - "resume_point.dart"
Cohesion: 0.15
Nodes (12): bySortOrder, entries, inVolumes, loose, orderedChapters, ResumeEntry, ResumePoint, sortedChapters (+4 more)

### Community 45 - "reader_settings_sheet.dart"
Cohesion: 0.17
Nodes (11): direction_icon.dart, build, current, direction, onPicked, picked, ReadingDirectionRows, _SheetLabel (+3 more)

### Community 46 - "auth_test.dart"
Cohesion: 0.11
Nodes (18): DioException get, accountId, apiKey, call, calls, color, _container, fails (+10 more)

### Community 47 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.06
Nodes (33): Finder get, IconButton, package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/settings/locale_settings.dart, package:patra/src/settings/reading_settings.dart (+25 more)

### Community 48 - "cover.dart"
Cohesion: 0.14
Nodes (13): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+5 more)

### Community 49 - "series_hero_test.dart"
Cohesion: 0.12
Nodes (15): package:patra/src/features/series/series_detail_screen.dart, package:patra/src/widgets/cover.dart, cacheDir, _chapter, client, close, fetch, main (+7 more)

### Community 50 - "static const"
Cohesion: 0.29
Nodes (6): build, dotScale, PatraWordmark, size, _tracking, static const

### Community 51 - "Hand-Written Client Rationale"
Cohesion: 0.19
Nodes (14): We do not generate a client, KavitaClient (lib/src/api/kavita_client.dart), LibraryTypeNaming / entity_naming.dart, MangaFormat and the PDF/EPUB split, The OpenAPI spec as an oracle (openapi_contract_test), Kavita sentinel numbers (ParserConstants), We deliberately do not call /api/Series/series-detail, Chapter (+6 more)

### Community 52 - "profile_avatar.dart"
Cohesion: 0.17
Nodes (11): build, dimmed, hex, _Initial, on, profile, ProfileAvatar, profileColor (+3 more)

### Community 53 - "locale_settings.dart"
Cohesion: 0.15
Nodes (13): build, initialLocaleProvider, _key, languageEndonym, load, LocaleNotifier, LocaleSettingsStore, save (+5 more)

### Community 54 - "graphify_merge_driver_test.dart"
Cohesion: 0.05
Nodes (34): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, package:patra/src/features/reader/spread_layout.dart, package:patra/src/resume_point.dart, chapter, en, fr (+26 more)

### Community 55 - "profile_lock_ui_test.dart"
Cohesion: 0.06
Nodes (35): package:patra/src/api/client_identity.dart, package:patra/src/auth/session.dart, package:patra/src/features/settings/settings_screen.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, _Adapter, client, close (+27 more)

### Community 56 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (27): FilledButton, NavigatorState, package:patra/src/features/home/continue_hero.dart, _backdrop, _chapter, client, close, continueReading (+19 more)

### Community 57 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.20
Nodes (8): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, formatBytes, gb, mb, sizeBytes, build, OfflineIndicator

### Community 58 - "_ReaderScreenState"
Cohesion: 0.20
Nodes (11): ConsumerStatefulWidget, savedChapterProvider, build, chapterInfoProvider, initState, ReaderScreen, _ReaderScreenState, _saveProgress (+3 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 60 - "server_version_test.dart"
Cohesion: 0.11
Nodes (17): Completer, card, client, close, dot, _dotColor, fetch, held (+9 more)

### Community 61 - "downloads_provider_test.dart"
Cohesion: 0.13
Nodes (14): package:patra/src/downloads/downloads_provider.dart, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+6 more)

### Community 62 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "magnify_gesture_test.dart"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "saved_chapters_per_profile_test.dart"
Cohesion: 0.13
Nodes (14): _Adapter, client, close, fetch, _lea, locale, main, _profile (+6 more)

### Community 65 - "Icon Master Artwork"
Cohesion: 0.39
Nodes (8): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed), Patra Frond Compact Mark (three-blade master, 1024px), Size rule: compact master at or below 72px, Widened blade spread of the compact fan

### Community 66 - "Launch Screen and Mark Assets"
Cohesion: 0.32
Nodes (8): Android adaptive icon (patra_mark.xml vector), LaunchAnimation and launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchSlot registry (LaunchLogoSlot / LaunchWordmarkSlot), The palm frond mark and its two masters, PatraFrond widget (lib/src/widgets/patra_frond.dart), PatraWordmark lockup at two scales, The splash is outside every Material in the app

### Community 67 - "Network Permissions and Scan"
Cohesion: 0.25
Nodes (8): android.permission.INTERNET in the main manifest, Cleartext HTTP permitted on both platforms, ConnectionFailure classifier, An empty library is a state, not a blank screen, Library scan is admin-only, Library, Library type, Series

### Community 68 - "Locale, Offline and Navigation"
Cohesion: 0.32
Nodes (8): localeProvider — forcing the language from Settings, Localization (en template, fr), StatefulShellRoute navigation (four tabs), OfflineIndicator (status in the app bar), offlineProvider, serverReachableProvider (GET /api/Health probe), The fixed French glossary, Offline

### Community 69 - "deep_link_test.dart"
Cohesion: 0.06
Nodes (36): dart:io, File, NavigationBar, package:patra/src/api/models.dart, package:patra/src/app.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/features/reader/reader_screen.dart (+28 more)

### Community 70 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 74 - "routes.dart"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 75 - "ConsumerWidget"
Cohesion: 0.13
Nodes (25): ConsumerWidget, kavitaClientProvider, offlineProvider, save, build, ContinueHero, _Details, _LibrariesSection (+17 more)

### Community 76 - "Handoff and Tablet Rules"
Cohesion: 0.33
Nodes (6): ClientIdentity / ClientDevice headers, Claude Design handoff as source of truth, System chrome comes and goes with the reader's own, isTabletLayout — three shapes, three answers, ThumbStrip (accordion scrubber drawn at a computed offset), Registered device

### Community 77 - "Localization Delegate"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 78 - "profile_picker_screen.dart"
Cohesion: 0.09
Nodes (22): ../../api/connection_failure.dart, _AddFace, _avatarSize, busy, createState, _entering, _error, _Face (+14 more)

### Community 79 - "Tag-Driven Release Rules"
Cohesion: 0.60
Nodes (5): Android signing switch via android/key.properties, Build number stays github.run_number, iOS job's two signing paths, Play internal-track upload as a third gated state, Releases are cut by a tag, not by a push

### Community 80 - "Reader Layout Safety Rules"
Cohesion: 0.50
Nodes (5): _PagedView seek guard (_seeking, _reported), The reader must never wrap itself in a LayoutBuilder, SpreadLayout (two-page spreads and wide pages), Spread, Wide page

### Community 81 - "downloads_service_test.dart"
Cohesion: 0.12
Nodes (15): DioException, DownloadsService, package:patra/src/downloads/downloads_service.dart, _chapter, client, close, failOnPage, fetch (+7 more)

### Community 82 - "AuthNotifier"
Cohesion: 0.33
Nodes (7): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, resume, signInProvider, _AppVersion

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "tablet_layout_test.dart"
Cohesion: 0.09
Nodes (21): package:patra/src/api/kavita_client.dart, package:patra/src/features/library/library_screen.dart, close, failing, fetch, main, _acrossOneRow, _Adapter (+13 more)

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "List"
Cohesion: 0.20
Nodes (9): firstOf, indexOf, length, of, _slotOfPage, slots, spanOf, SpreadLayout (+1 more)

### Community 88 - "direction_icon.dart"
Cohesion: 0.22
Nodes (8): build, color, direction, DirectionIcon, paint, shouldRepaint, size, ../settings/reading_settings.dart

### Community 90 - "../theme.dart"
Cohesion: 0.25
Nodes (7): Color, color, paint, radius, shouldRepaint, strokeWidth, ../theme.dart

### Community 92 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 93 - "dart:convert"
Cohesion: 0.20
Nodes (8): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, _jwt, main, seg

### Community 98 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.29
Nodes (6): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Cost, accepted, Decision, Why

### Community 99 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 100 - "build"
Cohesion: 0.12
Nodes (24): authProvider, sessionProvider, profileDownloadsProvider, imageCacheSizeProvider, imageCacheStoreProvider, _ProfileFace, _scan, build (+16 more)

### Community 102 - "entity_naming.dart"
Cohesion: 0.14
Nodes (13): api/models.dart, LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel (+5 more)

### Community 103 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.14
Nodes (12): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, Why, ADR-0004 — The auth key is the only secret a profile keeps, Consequences (+4 more)

### Community 104 - "package:flutter/material.dart"
Cohesion: 0.10
Nodes (20): CachedNetworkImage, Container, CustomPaint, dart:async, LoginResult, Opacity, package:flutter/material.dart, package:patra/src/features/launch/launch_animation.dart (+12 more)

### Community 105 - "profile_lock.dart"
Cohesion: 0.07
Nodes (28): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+20 more)

### Community 106 - "connection_failure.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 107 - "_ServerCardState"
Cohesion: 0.50
Nodes (4): serverReachableProvider, serverVersionProvider, _ServerCardState, WidgetsBindingObserver

### Community 108 - "StatefulWidget"
Cohesion: 0.23
Nodes (13): LaunchAnimation, _LaunchAnimationState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState, _VerticalScrollView, _VerticalScrollViewState (+5 more)

### Community 109 - "patra_masthead.dart"
Cohesion: 0.20
Nodes (9): ../features/launch/launch_animation.dart, build, _gap, _markHeight, PatraMasthead, showTagline, _size, patra_frond.dart (+1 more)

### Community 110 - "page_backdrop.dart"
Cohesion: 0.15
Nodes (12): ../api/kavita_client.dart, _artwork, build, chapterId, _fade, _hidden, _maxAspect, page (+4 more)

### Community 111 - "_LockSheetState"
Cohesion: 0.50
Nodes (4): biometricsProvider, _LockSheet, _LockSheetState, _offerBiometrics

### Community 112 - "client_identity_test.dart"
Cohesion: 0.11
Nodes (17): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, _device, _DeviceAdapter, fetch (+9 more)

### Community 113 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 115 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 117 - "page_loading.dart"
Cohesion: 0.17
Nodes (12): build, createState, dispose, explain, explainAfter, _explaining, initState, PageImageBuilder (+4 more)

### Community 118 - "Map"
Cohesion: 0.50
Nodes (4): ReadOverridesNotifier, ProfileLocksNotifier, profileLockStoreProvider, Map

### Community 119 - "LockVault"
Cohesion: 0.67
Nodes (3): LockVault, SecureLockVault, MemoryLockVault

### Community 120 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.28
Nodes (8): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart, FakeBiometrics

### Community 121 - "localeProvider"
Cohesion: 0.38
Nodes (7): build, PatraApp, _routerProvider, isLaunchProvider, _pickLanguage, localeProvider, main

### Community 123 - "_SlotState"
Cohesion: 0.33
Nodes (6): LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, W

### Community 124 - "ConsumerState"
Cohesion: 0.40
Nodes (5): ConsumerState, LoginScreen, _LoginScreenState, ProfilePickerScreen, _ProfilePickerScreenState

### Community 125 - "CustomPainter"
Cohesion: 0.40
Nodes (5): CustomPainter, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, _FrondPainter

### Community 126 - "MagnifyGesture"
Cohesion: 0.67
Nodes (3): @immutable, MagnifyGesture, MagnifyTransform

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1891 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+1886 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2062 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `ReaderScreen` connect `_ReaderScreenState` to `reader_screen.dart`, `deep_link_test.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `Profile` connect `Profile` to `session.dart`, `profile_picker_screen.dart`, `profile_lock_sheet.dart`, `login_screen.dart`, `profile_avatar.dart`, `settings_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `AppLocalizations` connect `Localization Delegate` to `app_localizations.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _1891 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.013333333333333334 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.014598540145985401 - nodes in this community are weakly interconnected._