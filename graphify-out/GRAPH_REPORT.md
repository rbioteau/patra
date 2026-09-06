# Graph Report - feat-server-version  (2026-09-06)

## Corpus Check
- 95 files · ~165,032 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2117 nodes · 2838 edges · 99 communities (90 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b4b6e98d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_fr.dart
- app_localizations_en.dart
- Thumbnail Strip Accordion
- Reader Screen State
- Kavita DTO Models
- launch_animation.dart
- Design Tokens and Theme
- series_detail_screen.dart
- kavita_client.dart
- Launch Composition Timeline
- library_screen.dart
- Client Identity Headers
- Session and Server Storage
- package:flutter/material.dart
- Reader Widget Tests
- magnify_gesture.dart
- home_screen.dart
- patra_frond.dart
- downloads_screen.dart
- login_screen.dart
- CI Build and Release Workflow
- Downloads Storage Service
- Linux GTK Runner
- App Shell and Provider Tests
- about_version_test.dart
- Series Sections Tests
- settings_screen.dart
- StatelessWidget
- package:flutter_riverpod/flutter_riverpod.dart
- page_loading.dart
- app.dart
- launch_animation_test.dart
- downloads_provider.dart
- iOS Runner App Delegate
- Reading Direction Settings
- build
- Server Reachability Tests
- Image Cache Trimming
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- dart:io
- package:dio/dio.dart
- client_identity_test.dart
- main.dart
- connection_failure_test.dart
- reader_settings_sheet.dart
- locale_settings.dart
- StatefulWidget
- cover.dart
- Series Hero Tests
- Tablet Layout Tests
- Hand-Written Client Rationale
- entity_naming.dart
- Issue tracker: GitHub
- graphify_merge_driver_test.dart
- downloads_service_test.dart
- connection_failure.dart
- widget_test.dart
- offline_indicator_test.dart
- Progress and Storage Invariants
- server_version_test.dart
- triage-labels.md
- image_cache_store_test.dart
- Magnify Gesture Tests
- direction_icon.dart
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- static const
- Domain Docs
- Auth State and Retry Policy
- Reader Direction and Magnify
- HttpClientAdapter
- spread_layout.dart
- ../../l10n/generated/app_localizations.dart
- Handoff and Tablet Rules
- Localization Delegate
- entity_naming_test.dart
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- dashed_border.dart
- Notifier
- App Icon Generation Script
- build
- Dependency and Icon Tooling
- Android Main Activity
- Thumb Strip State
- package:patra/src/api/models.dart
- Patra and Kavita Identity
- Launch Scope Inherited Widget
- Localization Codegen Config
- Patra
- Optimistic Read Overrides
- CustomPainter

## God Nodes (most connected - your core abstractions)
1. `kavitaClientProvider` - 16 edges
2. `build` - 14 edges
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
Nodes (130): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem (+122 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.02
Nodes (117): app_localizations.dart, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan (+109 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.02
Nodes (117): aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToServers (+109 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "Kavita DTO Models"
Cohesion: 0.03
Nodes (71): adminRole, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters, ClientDeviceDto (+63 more)

### Community 6 - "launch_animation.dart"
Cohesion: 0.04
Nodes (51): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+43 more)

### Community 7 - "Design Tokens and Theme"
Cohesion: 0.04
Nodes (48): AnimationController, base, body, build, colors, _controller, copyWith, coverAspectRatio (+40 more)

### Community 8 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (44): ../../entity_naming.dart, Chapter, _actionMaxWidth, _Buckets, _buildSections, _bySortOrder, chapter, _ChapterRow (+36 more)

### Community 9 - "kavita_client.dart"
Cohesion: 0.05
Nodes (41): Dio, Dio get, allSeriesForLibrary, apiKey, baseUrl, _bearerIsIrrelevant, chapterCoverUrl, chapterInfo (+33 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "library_screen.dart"
Cohesion: 0.07
Nodes (36): ../../api/connection_failure.dart, kavitaClientProvider, sessionProvider, save, _Shelf, available, build, createState (+28 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "Session and Server Storage"
Cohesion: 0.05
Nodes (37): ../api/client_device.dart, ../api/client_identity.dart, _activeKey, activeUrl, apiKey, baseUrl, build, _commit (+29 more)

### Community 14 - "package:flutter/material.dart"
Cohesion: 0.09
Nodes (21): dart:async, package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/features/reader/thumb_strip.dart, package:patra/src/theme.dart, main (+13 more)

### Community 15 - "Reader Widget Tests"
Cohesion: 0.06
Nodes (30): Image, NeverScrollableScrollPhysics, package:patra/src/features/reader/reader_screen.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set (+22 more)

### Community 16 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (29): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+21 more)

### Community 17 - "home_screen.dart"
Cohesion: 0.08
Nodes (32): AsyncValue, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+24 more)

### Community 18 - "patra_frond.dart"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 19 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (30): ConsumerWidget, ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter (+22 more)

### Community 20 - "login_screen.dart"
Cohesion: 0.06
Nodes (37): ConsumerState, FormState, authProvider, build, _buildForm, _buildServerList, _busy, child (+29 more)

### Community 21 - "CI Build and Release Workflow"
Cohesion: 0.09
Nodes (30): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+22 more)

### Community 22 - "Downloads Storage Service"
Cohesion: 0.07
Nodes (29): ../../api/kavita_client.dart, bytes, chapterDir, chapterId, copyWith, _deleteQuietly, download, fromJson (+21 more)

### Community 23 - "Linux GTK Runner"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "App Shell and Provider Tests"
Cohesion: 0.14
Nodes (13): Future, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+5 more)

### Community 25 - "about_version_test.dart"
Cohesion: 0.08
Nodes (23): package:patra/src/api/client_identity.dart, package:patra/src/api/kavita_client.dart, package:patra/src/features/settings/settings_screen.dart, _Adapter, client, close, fetch, main (+15 more)

### Community 26 - "Series Sections Tests"
Cohesion: 0.08
Nodes (24): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+16 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.08
Nodes (23): ../../downloads/image_cache_store.dart, actionLabel, children, createState, didChangeAppLifecycleState, dispose, host, icon (+15 more)

### Community 28 - "StatelessWidget"
Cohesion: 0.09
Nodes (23): _FlyingFrond, _SplashWordmark, _AddServerButton, _Field, _Masthead, _ServerRow, _BottomChrome, _ReaderError (+15 more)

### Community 29 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.10
Nodes (22): dart:convert, package:flutter_riverpod/flutter_riverpod.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/library/library_screen.dart, package:patra/src/settings/locale_settings.dart, package:patra/src/settings/reading_settings.dart, _Adapter, client (+14 more)

### Community 30 - "page_loading.dart"
Cohesion: 0.15
Nodes (13): build, createState, dispose, explain, explainAfter, _explaining, initState, PageImageBuilder (+5 more)

### Community 31 - "app.dart"
Cohesion: 0.10
Nodes (21): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/launch/launch_animation.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+13 more)

### Community 32 - "launch_animation_test.dart"
Cohesion: 0.08
Nodes (23): Opacity, package:flutter/rendering.dart, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size (+15 more)

### Community 33 - "downloads_provider.dart"
Cohesion: 0.07
Nodes (33): AsyncNotifier, downloads_service.dart, int get, build, cancel, _cancelTokens, copyWith, _disposed (+25 more)

### Community 34 - "iOS Runner App Delegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 35 - "Reading Direction Settings"
Cohesion: 0.10
Nodes (21): bool get, leftToRight,
  rightToLeft,, build, DefaultReadingDirectionNotifier, initialMagnifyProvider, initialReadingDirectionProvider, isRightToLeft, isVerticalScroll (+13 more)

### Community 36 - "build"
Cohesion: 0.13
Nodes (21): ConsumerStatefulWidget, serverReachableProvider, serverVersionProvider, savedChapterProvider, imageCacheSizeProvider, imageCacheStoreProvider, build, chapterInfoProvider (+13 more)

### Community 37 - "Server Reachability Tests"
Cohesion: 0.11
Nodes (18): Container, _announcement, card, client, close, dot, _dotColor, fetch (+10 more)

### Community 38 - "Image Cache Trimming"
Cohesion: 0.11
Nodes (18): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, _lastTrim, _measure (+10 more)

### Community 39 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 40 - "dart:io"
Cohesion: 0.18
Nodes (10): dart:io, File, ReadOverridesNotifier, Map, main, resolve, schema, schemas (+2 more)

### Community 41 - "package:dio/dio.dart"
Cohesion: 0.12
Nodes (15): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+7 more)

### Community 42 - "client_identity_test.dart"
Cohesion: 0.12
Nodes (16): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, _device, fetch, _landscape (+8 more)

### Community 43 - "main.dart"
Cohesion: 0.12
Nodes (15): auth, cacheLimit, identity, imageCache, locale, magnify, main, readingDirection (+7 more)

### Community 44 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 45 - "reader_settings_sheet.dart"
Cohesion: 0.14
Nodes (14): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+6 more)

### Community 46 - "locale_settings.dart"
Cohesion: 0.15
Nodes (13): build, initialLocaleProvider, _key, languageEndonym, load, LocaleNotifier, LocaleSettingsStore, save (+5 more)

### Community 47 - "StatefulWidget"
Cohesion: 0.15
Nodes (19): LaunchAnimation, _LaunchAnimationState, LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, _MagnifyPage (+11 more)

### Community 48 - "cover.dart"
Cohesion: 0.13
Nodes (14): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+6 more)

### Community 49 - "Series Hero Tests"
Cohesion: 0.13
Nodes (14): package:patra/src/features/series/series_detail_screen.dart, package:patra/src/widgets/cover.dart, cacheDir, _chapter, client, close, fetch, main (+6 more)

### Community 50 - "Tablet Layout Tests"
Cohesion: 0.13
Nodes (14): _acrossOneRow, client, close, count, fetch, _iPad, libraries, main (+6 more)

### Community 51 - "Hand-Written Client Rationale"
Cohesion: 0.19
Nodes (14): We do not generate a client, KavitaClient (lib/src/api/kavita_client.dart), LibraryTypeNaming / entity_naming.dart, MangaFormat and the PDF/EPUB split, The OpenAPI spec as an oracle (openapi_contract_test), Kavita sentinel numbers (ParserConstants), We deliberately do not call /api/Series/series-detail, Chapter (+6 more)

### Community 52 - "entity_naming.dart"
Cohesion: 0.15
Nodes (12): ../../api/models.dart, LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel (+4 more)

### Community 53 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 54 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 55 - "downloads_service_test.dart"
Cohesion: 0.15
Nodes (12): DioException, DownloadsService, package:patra/src/downloads/downloads_service.dart, _chapter, client, close, failOnPage, fetch (+4 more)

### Community 56 - "connection_failure.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 57 - "widget_test.dart"
Cohesion: 0.17
Nodes (11): NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/login/login_screen.dart, _app, client, close, fetch (+3 more)

### Community 58 - "offline_indicator_test.dart"
Cohesion: 0.11
Nodes (16): Finder get, IconButton, package:patra/src/auth/session.dart, _a, _b, _container, main, _Adapter (+8 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 60 - "server_version_test.dart"
Cohesion: 0.11
Nodes (17): Completer, card, client, close, dot, _dotColor, fetch, held (+9 more)

### Community 62 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "Magnify Gesture Tests"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "direction_icon.dart"
Cohesion: 0.22
Nodes (8): build, color, direction, DirectionIcon, paint, shouldRepaint, size, ../settings/reading_settings.dart

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
Cohesion: 0.25
Nodes (7): build, dotScale, PatraWordmark, size, _tracking, static const, ../theme.dart

### Community 70 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "HttpClientAdapter"
Cohesion: 0.17
Nodes (12): HttpClientAdapter, _DeviceAdapter, _KavitaLikeAdapter, _PageAdapter, _FakeKavitaAdapter, _RecordingAdapter, _ReaderAdapter, _SeriesAdapter (+4 more)

### Community 74 - "spread_layout.dart"
Cohesion: 0.20
Nodes (9): firstOf, indexOf, length, of, _slotOfPage, slots, spanOf, SpreadLayout (+1 more)

### Community 75 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.17
Nodes (11): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, offlineProvider, _ErrorState, formatBytes, gb, mb, sizeBytes (+3 more)

### Community 76 - "Handoff and Tablet Rules"
Cohesion: 0.33
Nodes (6): ClientIdentity / ClientDevice headers, Claude Design handoff as source of truth, System chrome comes and goes with the reader's own, isTabletLayout — three shapes, three answers, ThumbStrip (accordion scrubber drawn at a computed offset), Registered device

### Community 77 - "Localization Delegate"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 78 - "entity_naming_test.dart"
Cohesion: 0.25
Nodes (7): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main

### Community 79 - "Tag-Driven Release Rules"
Cohesion: 0.60
Nodes (5): Android signing switch via android/key.properties, Build number stays github.run_number, iOS job's two signing paths, Play internal-track upload as a third gated state, Releases are cut by a tag, not by a push

### Community 80 - "Reader Layout Safety Rules"
Cohesion: 0.50
Nodes (5): _PagedView seek guard (_seeking, _reported), The reader must never wrap itself in a LayoutBuilder, SpreadLayout (two-page spreads and wide pages), Spread, Wide page

### Community 81 - "dashed_border.dart"
Cohesion: 0.29
Nodes (6): Color, color, paint, radius, shouldRepaint, strokeWidth

### Community 82 - "Notifier"
Cohesion: 0.22
Nodes (9): int?, AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, OfflineNotifier, SelectedLibraryNotifier, _AppVersion (+1 more)

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "build"
Cohesion: 0.38
Nodes (7): libraryTypeProvider, build, SeriesDetailScreen, _SeriesHero, seriesMetadataProvider, seriesProvider, seriesVolumesProvider

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "Thumb Strip State"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 88 - "package:patra/src/api/models.dart"
Cohesion: 0.33
Nodes (5): package:patra/src/api/models.dart, package:patra/src/features/reader/spread_layout.dart, _chapter, copyWithoutDimensions, main

### Community 92 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 93 - "Optimistic Read Overrides"
Cohesion: 0.67
Nodes (3): @immutable, MagnifyGesture, MagnifyTransform

### Community 98 - "CustomPainter"
Cohesion: 0.40
Nodes (5): CustomPainter, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, _FrondPainter

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1457 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+1452 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1607 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `KavitaClient` connect `kavita_client.dart` to `Reader Screen State`, `Session and Server Storage`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `SavedChapter` connect `downloads_screen.dart` to `Reader Screen State`, `Downloads Storage Service`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `kavitaClientProvider` connect `library_screen.dart` to `downloads_provider.dart`, `build`, `series_detail_screen.dart`, `Session and Server Storage`, `home_screen.dart`, `build`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _1457 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.015267175572519083 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.01694915254237288 - nodes in this community are weakly interconnected._