# Graph Report - patra  (2026-09-08)

## Corpus Check
- 124 files · ~226,342 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2806 nodes · 3906 edges · 124 communities (111 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aa7977c6`
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
- _
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
- authProvider
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
- profile_picker_test.dart
- cache_settings.dart
- main.dart
- profile_preferences.dart
- package:flutter_riverpod/flutter_riverpod.dart
- auth_test.dart
- library_scan_test.dart
- cover.dart
- series_hero_test.dart
- static const
- Hand-Written Client Rationale
- profile_avatar.dart
- package:flutter_test/flutter_test.dart
- graphify_merge_driver_test.dart
- profile_lock_ui_test.dart
- home_hero_test.dart
- _ReaderScreenState
- build
- Progress and Storage Invariants
- server_version_test.dart
- downloads_service_test.dart
- image_cache_store_test.dart
- magnify_gesture_test.dart
- package:dio/dio.dart
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- deep_link_test.dart
- Domain Docs
- Auth State and Retry Policy
- Reader Direction and Magnify
- downloads_provider_test.dart
- routes.dart
- ../../auth/session.dart
- Handoff and Tablet Rules
- Localization Delegate
- profile_picker_screen.dart
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- resume_point.dart
- AuthNotifier
- App Icon Generation Script
- connection_failure_test.dart
- Dependency and Icon Tooling
- MainActivity.kt
- List
- reader_settings_sheet.dart
- Patra and Kavita Identity
- ../../../l10n/generated/app_localizations.dart
- Localization Codegen Config
- Patra
- return
- ADR-0002 — One rule decides where reading resumes, and it is ours
- Issue tracker: GitHub
- direction_icon.dart
- triage-labels.md
- tablet_layout_test.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- HttpClientAdapter
- profile_lock.dart
- connection_failure.dart
- package:flutter/material.dart
- StatefulWidget
- dart:io
- build
- page_backdrop.dart
- client_identity_test.dart
- _ThumbStripState
- ConsumerWidget
- LockVault
- PreferencesVault
- SignInExpired
- Notifier
- LibraryType
- ProfilePreferencesStore
- bool?
- Credential
- LaunchScope

## God Nodes (most connected - your core abstractions)
1. `_` - 67 edges
2. `kavitaClientProvider` - 15 edges
3. `authProvider` - 15 edges
4. `build` - 15 edges
5. `build` - 11 edges
6. `offlineProvider` - 11 edges
7. `downloadsProvider` - 10 edges
8. `build` - 9 edges
9. `profileLocksProvider` - 9 edges
10. `_ReaderScreenState` - 9 edges

## Surprising Connections (you probably didn't know these)
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml
- `The tag is the version` --conceptually_related_to--> `pubspec version is only a local-build fallback`  [INFERRED]
  .github/workflows/build.yml → pubspec.yaml
- `LibraryTypeNaming / entity_naming.dart` --implements--> `The fixed French glossary`  [EXTRACTED]
  CLAUDE.md → CONTEXT.md
- `serverReachableProvider (GET /api/Health probe)` --implements--> `Offline`  [INFERRED]
  CLAUDE.md → CONTEXT.md

## Import Cycles
- None detected.

## Communities (124 total, 9 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (152): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+144 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (139): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+131 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (139): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+131 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (79): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, Chapter, ChapterInfo (+71 more)

### Community 6 - "launch_animation.dart"
Cohesion: 0.04
Nodes (53): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+45 more)

### Community 7 - "theme.dart"
Cohesion: 0.04
Nodes (54): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+46 more)

### Community 8 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (38): Chapter, _Buckets, _buildSections, chapter, child, clear, _confirmRemove, _coverHeight (+30 more)

### Community 9 - "kavita_client.dart"
Cohesion: 0.04
Nodes (48): Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient, baseUrl (+40 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "_"
Cohesion: 0.07
Nodes (41): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+33 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "session.dart"
Cohesion: 0.04
Nodes (56): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+48 more)

### Community 14 - "profile_lock_sheet.dart"
Cohesion: 0.06
Nodes (32): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+24 more)

### Community 15 - "reader_test.dart"
Cohesion: 0.07
Nodes (29): Image, NeverScrollableScrollPhysics, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set, Switch (+21 more)

### Community 16 - "magnify_gesture.dart"
Cohesion: 0.06
Nodes (32): @immutable, double get, anchor, _band, contain, content, _degenerate, drawnContent (+24 more)

### Community 17 - "home_screen.dart"
Cohesion: 0.06
Nodes (32): AsyncValue, continue_hero.dart, ../launch/launch_animation.dart, Library, ResolvedFailure, _cardMaxWidth, _cardSpacing, _cardWidth (+24 more)

### Community 18 - "patra_frond.dart"
Cohesion: 0.05
Nodes (36): Color get, CustomPainter, double?, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, alpha, bladeHalfWidth (+28 more)

### Community 19 - "downloads_screen.dart"
Cohesion: 0.09
Nodes (23): ../../downloads/downloads_provider.dart, ../../downloads/downloads_service.dart, ../../format.dart, IconData, SavedChapter, bytes, chapter, chapters (+15 more)

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

### Community 24 - "authProvider"
Cohesion: 0.15
Nodes (17): ConsumerState, authProvider, profileDownloadsProvider, scan, build, initState, LoginScreen, _LoginScreenState (+9 more)

### Community 25 - "kavita_client_test.dart"
Cohesion: 0.11
Nodes (17): apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch, loginReturnsGarbage, logins (+9 more)

### Community 26 - "series_sections_test.dart"
Cohesion: 0.08
Nodes (25): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+17 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.06
Nodes (35): ../../downloads/image_cache_store.dart, actionLabel, _avatarSize, child, children, confirmed, createState, didChangeAppLifecycleState (+27 more)

### Community 28 - "StatelessWidget"
Cohesion: 0.08
Nodes (24): _Wordmark, _FlyingFrond, _SplashWordmark, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, _BottomChrome, _ReaderError (+16 more)

### Community 29 - "test_support.dart"
Cohesion: 0.05
Nodes (37): MemoryPreferencesVault? vault,
  ReadingDirection, required int chapterId,
  String, available, bytes, channel, chapter, clear, clears (+29 more)

### Community 30 - "continue_hero.dart"
Cohesion: 0.10
Nodes (19): ../../entity_naming.dart, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date, featuredSeries (+11 more)

### Community 31 - "app.dart"
Cohesion: 0.10
Nodes (22): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+14 more)

### Community 32 - "launch_animation_test.dart"
Cohesion: 0.09
Nodes (22): Opacity, package:flutter/rendering.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size, _app (+14 more)

### Community 33 - "downloads_provider.dart"
Cohesion: 0.10
Nodes (24): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+16 more)

### Community 34 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 35 - "reading_settings.dart"
Cohesion: 0.12
Nodes (16): bool get, leftToRight,
  rightToLeft,, directionNamed, isRightToLeft, isVerticalScroll, _key, label, _legacyNames (+8 more)

### Community 36 - "session_scope.dart"
Cohesion: 0.11
Nodes (18): auth, build, child, _container, createState, dispose, _entered, initState (+10 more)

### Community 37 - "server_reachability_test.dart"
Cohesion: 0.11
Nodes (17): _announcement, card, client, close, dot, _dotColor, fetch, handle (+9 more)

### Community 38 - "image_cache_store.dart"
Cohesion: 0.11
Nodes (18): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, _lastTrim, _measure (+10 more)

### Community 39 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 40 - "profile_switch_test.dart"
Cohesion: 0.06
Nodes (35): package:patra/src/session_scope.dart, package:patra/src/widgets/offline_indicator.dart, required Credential credential,
  ClientIdentity, _app, attempts, close, fetch, identity (+27 more)

### Community 41 - "profile_picker_test.dart"
Cohesion: 0.12
Nodes (15): Container, CustomPaint, LoginResult, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/widgets/dashed_border.dart, box, _dimming (+7 more)

### Community 42 - "cache_settings.dart"
Cohesion: 0.16
Nodes (13): build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, ImageCacheSettingsStore, initialImageCacheLimitProvider, _key (+5 more)

### Community 43 - "main.dart"
Cohesion: 0.06
Nodes (31): dart:async, auth, cacheLimit, identity, imageCache, load, locks, main (+23 more)

### Community 44 - "profile_preferences.dart"
Cohesion: 0.06
Nodes (35): build, _byProfile, clear, copyWith, deviceDirection, deviceLanguage, deviceMagnify, direction (+27 more)

### Community 45 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.28
Nodes (8): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart, FakeBiometrics

### Community 46 - "auth_test.dart"
Cohesion: 0.11
Nodes (18): DioException get, accountId, apiKey, call, calls, color, _container, fails (+10 more)

### Community 47 - "library_scan_test.dart"
Cohesion: 0.10
Nodes (19): PopupMenuItem, required bool admin,
  bool, client, close, _container, empty, fetch, _item (+11 more)

### Community 48 - "cover.dart"
Cohesion: 0.14
Nodes (13): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+5 more)

### Community 49 - "series_hero_test.dart"
Cohesion: 0.08
Nodes (24): CachedNetworkImage, CoverImage, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/widgets/cover.dart, cacheDir, _chapter, client, close (+16 more)

### Community 50 - "static const"
Cohesion: 0.09
Nodes (21): ../features/launch/launch_animation.dart, color, paint, radius, shouldRepaint, strokeWidth, build, _gap (+13 more)

### Community 51 - "Hand-Written Client Rationale"
Cohesion: 0.19
Nodes (14): We do not generate a client, KavitaClient (lib/src/api/kavita_client.dart), LibraryTypeNaming / entity_naming.dart, MangaFormat and the PDF/EPUB split, The OpenAPI spec as an oracle (openapi_contract_test), Kavita sentinel numbers (ParserConstants), We deliberately do not call /api/Series/series-detail, Chapter (+6 more)

### Community 52 - "profile_avatar.dart"
Cohesion: 0.14
Nodes (13): api/kavita_client.dart, Profile, Session, build, dimmed, hex, _Initial, on (+5 more)

### Community 53 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.10
Nodes (18): package:flutter_test/flutter_test.dart, package:patra/src/api/account_id.dart, package:patra/src/api/kavita_client.dart, package:patra/src/api/models.dart, package:patra/src/features/reader/spread_layout.dart, package:patra/src/resume_point.dart, _jwt, main (+10 more)

### Community 54 - "graphify_merge_driver_test.dart"
Cohesion: 0.07
Nodes (24): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main, _command (+16 more)

### Community 55 - "profile_lock_ui_test.dart"
Cohesion: 0.07
Nodes (28): dart:convert, accountIdFrom, _padded, segments, package:patra/src/auth/session.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, lea (+20 more)

### Community 56 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (29): FilledButton, NavigatorState, package:patra/src/features/home/continue_hero.dart, _backdrop, _chapter, client, close, fetch (+21 more)

### Community 57 - "_ReaderScreenState"
Cohesion: 0.20
Nodes (11): ConsumerStatefulWidget, savedChapterProvider, build, chapterInfoProvider, initState, ReaderScreen, _ReaderScreenState, _saveProgress (+3 more)

### Community 58 - "build"
Cohesion: 0.29
Nodes (10): serverReachableProvider, serverVersionProvider, imageCacheSizeProvider, imageCacheStoreProvider, build, _pickLimit, _ServerCardState, _StorageRows (+2 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 60 - "server_version_test.dart"
Cohesion: 0.11
Nodes (17): Completer, card, client, close, dot, _dotColor, fetch, held (+9 more)

### Community 61 - "downloads_service_test.dart"
Cohesion: 0.13
Nodes (14): DioException, DownloadsService, package:patra/src/downloads/downloads_service.dart, _chapter, client, close, failOnPage, fetch (+6 more)

### Community 62 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "magnify_gesture_test.dart"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "package:dio/dio.dart"
Cohesion: 0.06
Nodes (32): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+24 more)

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
Cohesion: 0.07
Nodes (27): NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/reader/reader_screen.dart, package:patra/src/routes.dart, required Directory downloadsRoot,
  bool, _app (+19 more)

### Community 70 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "downloads_provider_test.dart"
Cohesion: 0.12
Nodes (15): Future, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+7 more)

### Community 74 - "routes.dart"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 75 - "../../auth/session.dart"
Cohesion: 0.23
Nodes (12): ../../auth/session.dart, offlineProvider, build, continueHeroProvider, HomeScreen, onDeckProvider, _refresh, librariesProvider (+4 more)

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

### Community 81 - "resume_point.dart"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 82 - "AuthNotifier"
Cohesion: 0.33
Nodes (7): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, resume, signInProvider, _AppVersion

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "List"
Cohesion: 0.18
Nodes (10): int get, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+2 more)

### Community 88 - "reader_settings_sheet.dart"
Cohesion: 0.13
Nodes (15): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+7 more)

### Community 90 - "../../../l10n/generated/app_localizations.dart"
Cohesion: 0.11
Nodes (16): api/models.dart, ../../../l10n/generated/app_localizations.dart, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, numberedChapterLabel, resumeTitle (+8 more)

### Community 92 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 93 - "return"
Cohesion: 0.08
Nodes (23): _key, languageEndonym, load, LocaleSettingsStore, null, save, _storage, supportedLocale (+15 more)

### Community 98 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.29
Nodes (6): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Cost, accepted, Decision, Why

### Community 99 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 100 - "direction_icon.dart"
Cohesion: 0.20
Nodes (9): Color, build, color, direction, DirectionIcon, paint, shouldRepaint, size (+1 more)

### Community 102 - "tablet_layout_test.dart"
Cohesion: 0.12
Nodes (15): _acrossOneRow, _Adapter, client, close, count, fetch, _iPad, libraries (+7 more)

### Community 103 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.14
Nodes (12): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, Why, ADR-0004 — The auth key is the only secret a profile keeps, Consequences (+4 more)

### Community 104 - "HttpClientAdapter"
Cohesion: 0.06
Nodes (30): HttpClientAdapter, package:patra/src/features/library/library_screen.dart, _StubAdapter, _PageAdapter, _Adapter, client, close, fetch (+22 more)

### Community 105 - "profile_lock.dart"
Cohesion: 0.07
Nodes (31): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+23 more)

### Community 106 - "connection_failure.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 107 - "package:flutter/material.dart"
Cohesion: 0.06
Nodes (33): Finder get, IconButton, package:flutter/material.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/features/reader/thumb_strip.dart, package:patra/src/settings/locale_settings.dart (+25 more)

### Community 108 - "StatefulWidget"
Cohesion: 0.15
Nodes (19): LaunchAnimation, _LaunchAnimationState, LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, _MagnifyPage (+11 more)

### Community 109 - "dart:io"
Cohesion: 0.22
Nodes (8): dart:io, File, main, resolve, schema, schemas, spec, specName

### Community 110 - "build"
Cohesion: 0.23
Nodes (14): kavitaClientProvider, build, ContinueHero, _Details, build, _ChapterRow, SeriesDetailScreen, _SeriesHero (+6 more)

### Community 111 - "page_backdrop.dart"
Cohesion: 0.11
Nodes (19): int?, kavitaClientProvider, save, _Shelf, SelectedLibraryNotifier, didChangeDependencies, _artwork, build (+11 more)

### Community 112 - "client_identity_test.dart"
Cohesion: 0.11
Nodes (17): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, _device, _DeviceAdapter, fetch (+9 more)

### Community 113 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 114 - "ConsumerWidget"
Cohesion: 0.21
Nodes (12): ConsumerWidget, chapterDirProvider, downloadsProvider, build, DownloadsScreen, _SavedRow, _LibrariesSection, _OfflineHome (+4 more)

### Community 115 - "LockVault"
Cohesion: 0.67
Nodes (3): LockVault, SecureLockVault, MemoryLockVault

### Community 116 - "PreferencesVault"
Cohesion: 0.67
Nodes (3): PreferencesVault, SecurePreferencesVault, MemoryPreferencesVault

### Community 118 - "Notifier"
Cohesion: 0.23
Nodes (12): OfflineNotifier, sessionProvider, _ProfileFace, LibraryScanNotifier, ReadOverridesNotifier, DefaultReadingDirectionNotifier, LocaleNotifier, MagnifyNotifier (+4 more)

### Community 123 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1989 isolated node(s):** `best`, `date`, `incumbent`, `ContinueHeroData`, `data` (+1984 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2171 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `_` connect `_` to `connection_failure.dart`, `../../auth/session.dart`, `package:flutter/material.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `profile_picker_screen.dart`, `page_backdrop.dart`, `home_screen.dart`, `ConsumerWidget`, `downloads_screen.dart`, `static const`, `Notifier`, `List`, `authProvider`, `../../../l10n/generated/app_localizations.dart`, `reader_settings_sheet.dart`, `StatelessWidget`, `continue_hero.dart`, `app.dart`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `LibraryType` connect `LibraryType` to `series_sections_test.dart`, `models.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `Profile` connect `profile_avatar.dart` to `session.dart`, `profile_picker_screen.dart`, `profile_lock_sheet.dart`, `login_screen.dart`, `settings_screen.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `best`, `date`, `incumbent` to the rest of the system?**
  _1989 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.013071895424836602 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.014285714285714285 - nodes in this community are weakly interconnected._