# Graph Report - feat-home-page-hero-section  (2026-09-06)

## Corpus Check
- 102 files · ~168,988 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2201 nodes · 2967 edges · 99 communities (90 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1012585e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_fr.dart
- app_localizations_en.dart
- Thumbnail Strip Accordion
- Reader Screen State
- models.dart
- Launch Animation Widget
- theme.dart
- series_detail_screen.dart
- kavita_client.dart
- Launch Composition Timeline
- library_screen.dart
- Client Identity Headers
- session.dart
- package:flutter/material.dart
- reader_test.dart
- magnify_gesture.dart
- home_screen.dart
- Palm Frond Mark Painter
- downloads_screen.dart
- login_screen.dart
- CI Build and Release Workflow
- downloads_service.dart
- Linux GTK Runner
- downloads_provider_test.dart
- kavita_client_test.dart
- Series Sections Tests
- settings_screen.dart
- StatelessWidget
- empty_library_test.dart
- continue_hero.dart
- app.dart
- Launch Animation Tests
- downloads_provider.dart
- iOS Runner App Delegate
- reading_settings.dart
- _ReaderScreenState
- Server Reachability Tests
- Image Cache Trimming
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- page_backdrop.dart
- package:dio/dio.dart
- client_identity_test.dart
- main.dart
- resume_point.dart
- reader_settings_sheet.dart
- return
- StatefulWidget
- cover.dart
- series_hero_test.dart
- tablet_layout_test.dart
- Hand-Written Client Rationale
- entity_naming.dart
- build
- PDF Page Loading Delay
- downloads_service_test.dart
- home_hero_test.dart
- about_version_test.dart
- Progress and Storage Invariants
- cache_settings.dart
- dart:io
- magnify_gesture_test.dart
- ../theme.dart
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- static const
- Domain Docs
- Auth State and Retry Policy
- Reader Direction and Magnify
- spread_layout.dart
- ConsumerWidget
- Handoff and Tablet Rules
- Localization Delegate
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- client_device.dart
- Notifier
- App Icon Generation Script
- ../../l10n/generated/app_localizations.dart
- Dependency and Icon Tooling
- Android Main Activity
- _ServerCardState
- _SlotState
- Patra and Kavita Identity
- Launch Scope Inherited Widget
- Localization Codegen Config
- Patra
- Optimistic Read Overrides
- ADR-0002 — One rule decides where reading resumes, and it is ours
- Issue tracker: GitHub
- _ThumbStripState
- triage-labels.md
- dart:convert

## God Nodes (most connected - your core abstractions)
1. `kavitaClientProvider` - 21 edges
2. `build` - 13 edges
3. `offlineProvider` - 11 edges
4. `_ReaderScreenState` - 9 edges
5. `downloadsProvider` - 8 edges
6. `build` - 8 edges
7. `AppLocalizations` - 7 edges
8. `authProvider` - 7 edges
9. `build` - 7 edges
10. `SettingsScreen` - 7 edges

## Surprising Connections (you probably didn't know these)
- `flutter_lints config with platform dirs excluded` --conceptually_related_to--> `analyze job (pub get, analyze, test)`  [INFERRED]
  analysis_options.yaml → .github/workflows/build.yml
- `pubspec version is only a local-build fallback` --conceptually_related_to--> `The tag is the version`  [INFERRED]
  pubspec.yaml → .github/workflows/build.yml
- `LibraryTypeNaming / entity_naming.dart` --implements--> `The fixed French glossary`  [EXTRACTED]
  CLAUDE.md → CONTEXT.md
- `serverReachableProvider (GET /api/Health probe)` --implements--> `Offline`  [INFERRED]
  CLAUDE.md → CONTEXT.md
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **iOS signing and TestFlight flow** — _github_workflows_build_import_certificate, _github_workflows_build_export_options_plist, _github_workflows_build_release_xcconfig_signing, _github_workflows_build_testflight_upload, _github_workflows_build_forget_signing_material [EXTRACTED 1.00]
- **The launch lockup: ink, frond, slots and wordmark** — claude_launch_screen_ink, claude_launch_animation, claude_launch_slot, claude_patra_frond, claude_patra_wordmark_lockup, claude_splash_material_ancestor [EXTRACTED 1.00]
- **Linux desktop build graph** — linux_cmakelists_binary_name, linux_cmakelists_apply_standard_settings, linux_cmakelists_install_bundle, linux_flutter_cmakelists_flutter_assemble, linux_flutter_cmakelists_flutter_library, linux_runner_cmakelists_runner_executable [EXTRACTED 1.00]
- **Tag-driven release pipeline (one tag, one run number, two stores)** — claude_release_by_tag, claude_build_number, claude_ios_signing_paths, claude_android_signing, claude_play_internal_track, claude_client_identity [EXTRACTED 1.00]
- **Tag-driven release pipeline** — _github_workflows_build_analyze, _github_workflows_build_build_android, _github_workflows_build_build_ios, _github_workflows_build_tag_is_the_version, _github_workflows_build_run_number_as_build_number, pubspec_version_fallback [EXTRACTED 1.00]
- **Two masters, one size rule for every rendered icon** — assets_icon_patra_1024_patra_frond_mark, assets_icon_patra_compact_1024_patra_frond_compact_mark, assets_icon_patra_compact_1024_small_size_master_rule, assets_icon_patra_1024_five_blade_fan_geometry [INFERRED 0.85]
- **Shared visual language of the Patra mark** — assets_icon_patra_1024_accent_centre_blade, assets_icon_patra_1024_parchment_alpha_ladder, assets_icon_patra_1024_patra_ink_ground, assets_icon_patra_1024_five_blade_fan_geometry [INFERRED 0.85]
- **Reader layout-safety rules (no rebuild inside a layout)** — claude_reader_no_layoutbuilder, claude_thumb_strip, claude_paged_view_seek_guard, claude_vertical_scroll_view, claude_progress_post_queue [INFERRED 0.85]

## Communities (99 total, 5 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.02
Nodes (129): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem (+121 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.02
Nodes (116): app_localizations.dart, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan (+108 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.02
Nodes (116): aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToServers (+108 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (73): adminRole, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters, ClientDeviceDto (+65 more)

### Community 6 - "Launch Animation Widget"
Cohesion: 0.04
Nodes (49): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+41 more)

### Community 7 - "theme.dart"
Cohesion: 0.04
Nodes (51): AnimationController, base, body, build, color, colors, _controller, copyWith (+43 more)

### Community 8 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (40): Chapter, _actionMaxWidth, _Buckets, _buildSections, chapter, _ChapterRow, child, clear (+32 more)

### Community 9 - "kavita_client.dart"
Cohesion: 0.05
Nodes (41): account_id.dart, Dio, Dio get, accountId, allSeriesForLibrary, apiKey, baseUrl, chapterCoverUrl (+33 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "library_screen.dart"
Cohesion: 0.09
Nodes (26): ../../api/connection_failure.dart, available, build, createState, _EmptyBody, _gridColumns, _gridDelegate, _gridSpacing (+18 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "session.dart"
Cohesion: 0.05
Nodes (37): ../api/client_device.dart, ../api/client_identity.dart, _activeKey, activeUrl, apiKey, baseUrl, build, _commit (+29 more)

### Community 14 - "package:flutter/material.dart"
Cohesion: 0.07
Nodes (34): Finder get, IconButton, package:flutter/material.dart, package:flutter_riverpod/flutter_riverpod.dart, package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/features/reader/page_loading.dart (+26 more)

### Community 15 - "reader_test.dart"
Cohesion: 0.06
Nodes (33): Image, NeverScrollableScrollPhysics, package:patra/src/features/reader/reader_screen.dart, package:patra/src/settings/reading_settings.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape (+25 more)

### Community 16 - "magnify_gesture.dart"
Cohesion: 0.06
Nodes (30): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+22 more)

### Community 17 - "home_screen.dart"
Cohesion: 0.07
Nodes (36): AsyncValue, continue_hero.dart, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth (+28 more)

### Community 18 - "Palm Frond Mark Painter"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 19 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (28): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter, build (+20 more)

### Community 20 - "login_screen.dart"
Cohesion: 0.06
Nodes (36): FormState, authProvider, build, _buildForm, _buildServerList, _busy, child, _connect (+28 more)

### Community 21 - "CI Build and Release Workflow"
Cohesion: 0.09
Nodes (30): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+22 more)

### Community 22 - "downloads_service.dart"
Cohesion: 0.07
Nodes (28): bytes, chapterDir, chapterId, copyWith, _deleteQuietly, download, fromJson, isRead (+20 more)

### Community 23 - "Linux GTK Runner"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "downloads_provider_test.dart"
Cohesion: 0.08
Nodes (24): Future, NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/features/login/login_screen.dart, ProviderContainer, adapter (+16 more)

### Community 25 - "kavita_client_test.dart"
Cohesion: 0.08
Nodes (24): HttpClientAdapter, _DeviceAdapter, _KavitaLikeAdapter, _HomeAdapter, authenticatedStatus, client, close, _FakeKavitaAdapter (+16 more)

### Community 26 - "Series Sections Tests"
Cohesion: 0.08
Nodes (24): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+16 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.08
Nodes (23): ../../downloads/image_cache_store.dart, actionLabel, children, createState, didChangeAppLifecycleState, dispose, host, icon (+15 more)

### Community 28 - "StatelessWidget"
Cohesion: 0.08
Nodes (25): _LibraryCard, _Wordmark, _FlyingFrond, _SplashWordmark, _AddServerButton, _Field, _Masthead, _ServerRow (+17 more)

### Community 29 - "empty_library_test.dart"
Cohesion: 0.09
Nodes (20): package:patra/src/api/kavita_client.dart, package:patra/src/auth/session.dart, package:patra/src/features/library/library_screen.dart, _a, _b, _container, main, _Adapter (+12 more)

### Community 30 - "continue_hero.dart"
Cohesion: 0.09
Nodes (22): ../../entity_naming.dart, Series, _actionMaxWidth, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data (+14 more)

### Community 31 - "app.dart"
Cohesion: 0.04
Nodes (46): DioExceptionType?, features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/launch/launch_animation.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart (+38 more)

### Community 32 - "Launch Animation Tests"
Cohesion: 0.09
Nodes (21): Opacity, package:flutter/rendering.dart, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size (+13 more)

### Community 33 - "downloads_provider.dart"
Cohesion: 0.12
Nodes (20): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+12 more)

### Community 34 - "iOS Runner App Delegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 35 - "reading_settings.dart"
Cohesion: 0.10
Nodes (21): bool get, leftToRight,
  rightToLeft,, build, DefaultReadingDirectionNotifier, initialMagnifyProvider, initialReadingDirectionProvider, isRightToLeft, isVerticalScroll (+13 more)

### Community 36 - "_ReaderScreenState"
Cohesion: 0.25
Nodes (9): savedChapterProvider, build, chapterInfoProvider, initState, ReaderScreen, _ReaderScreenState, _saveProgress, _pickDirection (+1 more)

### Community 37 - "Server Reachability Tests"
Cohesion: 0.11
Nodes (18): Container, _announcement, card, client, close, dot, _dotColor, fetch (+10 more)

### Community 38 - "Image Cache Trimming"
Cohesion: 0.11
Nodes (18): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, _lastTrim, _measure (+10 more)

### Community 39 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 40 - "page_backdrop.dart"
Cohesion: 0.13
Nodes (14): ../api/kavita_client.dart, int?, SelectedLibraryNotifier, _artwork, chapterId, _fade, _hidden, _maxAspect (+6 more)

### Community 41 - "package:dio/dio.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 42 - "client_identity_test.dart"
Cohesion: 0.04
Nodes (43): File, ReadOverridesNotifier, Map, package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/api/client_device.dart, package:patra/src/api/models.dart, package:patra/src/entity_naming.dart (+35 more)

### Community 43 - "main.dart"
Cohesion: 0.07
Nodes (26): dart:async, auth, cacheLimit, identity, imageCache, locale, magnify, main (+18 more)

### Community 44 - "resume_point.dart"
Cohesion: 0.15
Nodes (12): bySortOrder, entries, inVolumes, loose, orderedChapters, ResumeEntry, ResumePoint, sortedChapters (+4 more)

### Community 45 - "reader_settings_sheet.dart"
Cohesion: 0.14
Nodes (14): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+6 more)

### Community 46 - "return"
Cohesion: 0.25
Nodes (7): package:flutter/services.dart, return, channel, dir, mockPathProvider, mockSecureStorage, values

### Community 47 - "StatefulWidget"
Cohesion: 0.20
Nodes (15): LaunchAnimation, _LaunchAnimationState, PageLoading, _PageLoadingState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState (+7 more)

### Community 48 - "cover.dart"
Cohesion: 0.14
Nodes (13): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+5 more)

### Community 49 - "series_hero_test.dart"
Cohesion: 0.13
Nodes (14): CachedNetworkImage, package:patra/src/features/series/series_detail_screen.dart, cacheDir, _chapter, client, close, fetch, main (+6 more)

### Community 50 - "tablet_layout_test.dart"
Cohesion: 0.12
Nodes (15): package:patra/src/widgets/cover.dart, _acrossOneRow, client, close, count, fetch, _iPad, libraries (+7 more)

### Community 51 - "Hand-Written Client Rationale"
Cohesion: 0.19
Nodes (14): We do not generate a client, KavitaClient (lib/src/api/kavita_client.dart), LibraryTypeNaming / entity_naming.dart, MangaFormat and the PDF/EPUB split, The OpenAPI spec as an oracle (openapi_contract_test), Kavita sentinel numbers (ParserConstants), We deliberately do not call /api/Series/series-detail, Chapter (+6 more)

### Community 52 - "entity_naming.dart"
Cohesion: 0.14
Nodes (13): api/models.dart, LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel (+5 more)

### Community 53 - "build"
Cohesion: 0.53
Nodes (6): imageCacheSizeProvider, imageCacheStoreProvider, build, _pickLimit, _StorageRows, imageCacheLimitProvider

### Community 54 - "PDF Page Loading Delay"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 55 - "downloads_service_test.dart"
Cohesion: 0.15
Nodes (12): DioException, DownloadsService, _chapter, client, close, failOnPage, fetch, main (+4 more)

### Community 56 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (27): Completer, FilledButton, NavigatorState, package:patra/src/features/home/continue_hero.dart, _backdrop, _chapter, client, close (+19 more)

### Community 58 - "about_version_test.dart"
Cohesion: 0.17
Nodes (11): package:patra/src/api/client_identity.dart, package:patra/src/features/settings/settings_screen.dart, _Adapter, client, close, fetch, main, pumpAndSettle (+3 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 61 - "cache_settings.dart"
Cohesion: 0.15
Nodes (14): int get, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, ImageCacheSettingsStore, initialImageCacheLimitProvider (+6 more)

### Community 62 - "dart:io"
Cohesion: 0.22
Nodes (8): dart:io, Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "magnify_gesture_test.dart"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "../theme.dart"
Cohesion: 0.10
Nodes (20): Color, CustomPainter, _UnfurlPainter, color, DashedBorderPainter, paint, radius, shouldRepaint (+12 more)

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

### Community 69 - "static const"
Cohesion: 0.29
Nodes (6): build, dotScale, PatraWordmark, size, _tracking, static const

### Community 70 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "spread_layout.dart"
Cohesion: 0.20
Nodes (9): firstOf, indexOf, length, of, _slotOfPage, slots, spanOf, SpreadLayout (+1 more)

### Community 75 - "ConsumerWidget"
Cohesion: 0.14
Nodes (22): ConsumerWidget, kavitaClientProvider, sessionProvider, save, build, ContinueHero, _Details, _LibrariesSection (+14 more)

### Community 76 - "Handoff and Tablet Rules"
Cohesion: 0.33
Nodes (6): ClientIdentity / ClientDevice headers, Claude Design handoff as source of truth, System chrome comes and goes with the reader's own, isTabletLayout — three shapes, three answers, ThumbStrip (accordion scrubber drawn at a computed offset), Registered device

### Community 77 - "Localization Delegate"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 79 - "Tag-Driven Release Rules"
Cohesion: 0.60
Nodes (5): Android signing switch via android/key.properties, Build number stays github.run_number, iOS job's two signing paths, Play internal-track upload as a third gated state, Releases are cut by a tag, not by a push

### Community 80 - "Reader Layout Safety Rules"
Cohesion: 0.50
Nodes (5): _PagedView seek guard (_seeking, _reported), The reader must never wrap itself in a LayoutBuilder, SpreadLayout (two-page spreads and wide pages), Spread, Wide page

### Community 81 - "client_device.dart"
Cohesion: 0.25
Nodes (7): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart

### Community 82 - "Notifier"
Cohesion: 0.29
Nodes (7): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, OfflineNotifier, _AppVersion, Notifier

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.17
Nodes (11): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, offlineProvider, _ErrorState, formatBytes, gb, mb, sizeBytes (+3 more)

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "_ServerCardState"
Cohesion: 0.29
Nodes (8): ConsumerState, ConsumerStatefulWidget, serverReachableProvider, _EmptyLibrary, _EmptyLibraryState, _ServerCard, _ServerCardState, WidgetsBindingObserver

### Community 88 - "_SlotState"
Cohesion: 0.33
Nodes (6): LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, W

### Community 92 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 93 - "Optimistic Read Overrides"
Cohesion: 0.67
Nodes (3): @immutable, MagnifyGesture, MagnifyTransform

### Community 98 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.29
Nodes (6): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Cost, accepted, Decision, Why

### Community 99 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 100 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 103 - "dart:convert"
Cohesion: 0.20
Nodes (8): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, _jwt, main, seg

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1514 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+1509 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1673 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `kavitaClientProvider` connect `ConsumerWidget` to `downloads_provider.dart`, `_ReaderScreenState`, `series_detail_screen.dart`, `library_screen.dart`, `session.dart`, `home_screen.dart`, `_ServerCardState`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `KavitaClient` connect `kavita_client.dart` to `Reader Screen State`, `session.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `_UnfurlPainter` connect `../theme.dart` to `Launch Animation Widget`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _1514 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.015384615384615385 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017094017094017096 - nodes in this community are weakly interconnected._