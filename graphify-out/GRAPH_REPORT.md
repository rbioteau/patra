# Graph Report - patra  (2026-09-06)

## Corpus Check
- 129 files · ~159,643 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2091 nodes · 2811 edges · 98 communities (88 shown, 6 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 48 edges (avg confidence: 0.85)
- Token cost: 415,767 input · 0 output

## Community Hubs (Navigation)
- Localization String Catalogue
- French Translation Table
- English Translation Template
- Thumbnail Strip Accordion
- Reader Screen State
- Kavita DTO Models
- Launch Animation Widget
- Design Tokens and Theme
- Series Detail Sections
- Kavita HTTP Client
- Launch Composition Timeline
- Library Grid and Empty State
- Client Identity Headers
- Session and Server Storage
- Locale and Offline Tests
- Reader Widget Tests
- Magnify Gesture Geometry
- Home Shelves Screen
- Palm Frond Mark Painter
- Downloads Screen Rows
- Login Form Screen
- CI Build and Release Workflow
- Downloads Storage Service
- Linux GTK Runner
- App Shell and Provider Tests
- Client Auth Refresh Tests
- Series Sections Tests
- Settings Screen Rows
- Private Widget Fragments
- Auth and Library Refresh Tests
- Agent Docs and Triage Labels
- Router and Tab Shell
- Launch Animation Tests
- Downloads Provider Notifier
- iOS Runner App Delegate
- Reading Direction Settings
- Reader and Settings Providers
- Server Reachability Tests
- Image Cache Trimming
- Magnify ADR Decisions
- Model and OpenAPI Contract Tests
- Device Announcement Wiring
- Client Device Tests
- App Entrypoint Bootstrap
- Connection Failure Tests
- Reader Settings Sheet
- Image Cache Limit Setting
- Stateful Widget States
- Cover Image Widgets
- Series Hero Tests
- Tablet Layout Tests
- Hand-Written Client Rationale
- Entity Naming by Library Type
- Offline Indicator and Formatting
- PDF Page Loading Delay
- Downloads Service Tests
- Connection Failure Classifier
- Language Picker Settings
- About Version Tests
- Progress and Storage Invariants
- Magnify Design Space
- Two-Page Spread Layout
- Image Cache Store Tests
- Magnify Gesture Tests
- Reading Direction Icon
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- Patra Wordmark Lockup
- Entity Naming Tests
- Auth State and Retry Policy
- Reader Direction and Magnify
- Dashed Border Painter
- Login Screen Consumer
- Series Detail Providers
- Handoff and Tablet Rules
- Localization Delegate
- Launch Slot Registry
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- Custom Painters
- Auth and Identity Providers
- App Icon Generation Script
- Offline and Magnify Notifiers
- Dependency and Icon Tooling
- Android Main Activity
- Thumb Strip State
- Store Delivery Paths
- Patra and Kavita Identity
- Launch Scope Inherited Widget
- Localization Codegen Config
- Server Entry and Session
- Optimistic Read Overrides

## God Nodes (most connected - your core abstractions)
1. `kavitaClientProvider` - 16 edges
2. `build` - 13 edges
3. `offlineProvider` - 11 edges
4. `ADR-0001 — one-finger drag magnifies the page` - 10 edges
5. `_ReaderScreenState` - 9 edges
6. `downloadsProvider` - 8 edges
7. `build` - 8 edges
8. `Triage label role mapping table` - 8 edges
9. `AppLocalizations` - 7 edges
10. `authProvider` - 7 edges

## Surprising Connections (you probably didn't know these)
- `One-hand reading constraint (pinch needs two thumbs)` --semantically_similar_to--> `Reader (three reading directions)`  [INFERRED] [semantically similar]
  docs/adr/0001-reader-magnify-gesture.md → README.md
- `serverReachableProvider (GET /api/Health probe)` --implements--> `Offline`  [INFERRED]
  CLAUDE.md → CONTEXT.md
- `LibraryTypeNaming / entity_naming.dart` --implements--> `The fixed French glossary`  [EXTRACTED]
  CLAUDE.md → CONTEXT.md
- `Patra (Flutter Kavita client)` --conceptually_related_to--> `docs/adr/ decision record directory`  [AMBIGUOUS]
  README.md → docs/agents/domain.md
- `flutter_lints config with platform dirs excluded` --conceptually_related_to--> `analyze job (pub get, analyze, test)`  [INFERRED]
  analysis_options.yaml → .github/workflows/build.yml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Tag-driven release pipeline (one tag, one run number, two stores)** — claude_release_by_tag, claude_build_number, claude_ios_signing_paths, claude_android_signing, claude_play_internal_track, claude_client_identity [EXTRACTED 1.00]
- **The launch lockup: ink, frond, slots and wordmark** — claude_launch_screen_ink, claude_launch_animation, claude_launch_slot, claude_patra_frond, claude_patra_wordmark_lockup, claude_splash_material_ancestor [EXTRACTED 1.00]
- **Reader layout-safety rules (no rebuild inside a layout)** — claude_reader_no_layoutbuilder, claude_thumb_strip, claude_paged_view_seek_guard, claude_vertical_scroll_view, claude_progress_post_queue [INFERRED 0.85]
- **The four prototyped answers to the edge problem** — docs_adr_0001_reader_magnify_gesture_answer_finger_gives_way, docs_adr_0001_reader_magnify_gesture_answer_gesture_gives_way, docs_adr_0001_reader_magnify_gesture_answer_magnification_gives_way, docs_adr_0001_reader_magnify_gesture_answer_aim_a_loupe, docs_adr_0001_reader_magnify_gesture_border_constraint, docs_adr_0001_reader_magnify_gesture_prototype_branch [EXTRACTED 1.00]
- **Wayfinding flow: map to claim to resolve** — docs_agents_issue_tracker_wayfinder_map, docs_agents_issue_tracker_child_ticket, docs_agents_issue_tracker_blocking_dependencies, docs_agents_issue_tracker_frontier_query, docs_agents_issue_tracker_claim, docs_agents_issue_tracker_resolve [EXTRACTED 1.00]
- **The five canonical triage roles** — docs_agents_triage_labels_needs_triage, docs_agents_triage_labels_needs_info, docs_agents_triage_labels_ready_for_agent, docs_agents_triage_labels_ready_for_human, docs_agents_triage_labels_wontfix [EXTRACTED 1.00]
- **Tag-driven release pipeline** — _github_workflows_build_analyze, _github_workflows_build_build_android, _github_workflows_build_build_ios, _github_workflows_build_tag_is_the_version, _github_workflows_build_run_number_as_build_number, pubspec_version_fallback [EXTRACTED 1.00]
- **iOS signing and TestFlight flow** — _github_workflows_build_import_certificate, _github_workflows_build_export_options_plist, _github_workflows_build_release_xcconfig_signing, _github_workflows_build_testflight_upload, _github_workflows_build_forget_signing_material [EXTRACTED 1.00]
- **Linux desktop build graph** — linux_cmakelists_binary_name, linux_cmakelists_apply_standard_settings, linux_cmakelists_install_bundle, linux_flutter_cmakelists_flutter_assemble, linux_flutter_cmakelists_flutter_library, linux_runner_cmakelists_runner_executable [EXTRACTED 1.00]
- **Two masters, one size rule for every rendered icon** — assets_icon_patra_1024_patra_frond_mark, assets_icon_patra_compact_1024_patra_frond_compact_mark, assets_icon_patra_compact_1024_small_size_master_rule, assets_icon_patra_1024_five_blade_fan_geometry [INFERRED 0.85]
- **Shared visual language of the Patra mark** — assets_icon_patra_1024_accent_centre_blade, assets_icon_patra_1024_parchment_alpha_ladder, assets_icon_patra_1024_patra_ink_ground, assets_icon_patra_1024_five_blade_fan_geometry [INFERRED 0.85]

## Communities (98 total, 6 thin omitted)

### Community 0 - "Localization String Catalogue"
Cohesion: 0.02
Nodes (128): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem (+120 more)

### Community 1 - "French Translation Table"
Cohesion: 0.02
Nodes (115): app_localizations.dart, aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan (+107 more)

### Community 2 - "English Translation Template"
Cohesion: 0.02
Nodes (115): aboutSectionLabel, aboutVersion, addServer, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToServers (+107 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "Kavita DTO Models"
Cohesion: 0.03
Nodes (71): adminRole, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters, ClientDeviceDto (+63 more)

### Community 6 - "Launch Animation Widget"
Cohesion: 0.04
Nodes (49): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+41 more)

### Community 7 - "Design Tokens and Theme"
Cohesion: 0.04
Nodes (48): AnimationController, base, body, build, colors, _controller, copyWith, coverAspectRatio (+40 more)

### Community 8 - "Series Detail Sections"
Cohesion: 0.05
Nodes (44): ../../entity_naming.dart, Chapter, _actionMaxWidth, _Buckets, _buildSections, _bySortOrder, chapter, _ChapterRow (+36 more)

### Community 9 - "Kavita HTTP Client"
Cohesion: 0.05
Nodes (39): Dio, Dio get, allSeriesForLibrary, apiKey, baseUrl, chapterCoverUrl, chapterInfo, clientDevices (+31 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "Library Grid and Empty State"
Cohesion: 0.07
Nodes (36): ../../api/connection_failure.dart, kavitaClientProvider, sessionProvider, save, _Shelf, available, build, createState (+28 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "Session and Server Storage"
Cohesion: 0.06
Nodes (35): ../api/client_device.dart, ../api/client_identity.dart, _activeKey, activeUrl, apiKey, baseUrl, build, _commit (+27 more)

### Community 14 - "Locale and Offline Tests"
Cohesion: 0.07
Nodes (31): Finder get, IconButton, package:flutter/material.dart, package:flutter_riverpod/flutter_riverpod.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/features/reader/thumb_strip.dart (+23 more)

### Community 15 - "Reader Widget Tests"
Cohesion: 0.06
Nodes (33): Image, NeverScrollableScrollPhysics, package:patra/src/features/reader/reader_screen.dart, package:patra/src/settings/reading_settings.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape (+25 more)

### Community 16 - "Magnify Gesture Geometry"
Cohesion: 0.06
Nodes (33): @immutable, double get, anchor, _band, contain, content, _degenerate, drawnContent (+25 more)

### Community 17 - "Home Shelves Screen"
Cohesion: 0.08
Nodes (32): AsyncValue, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+24 more)

### Community 18 - "Palm Frond Mark Painter"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 19 - "Downloads Screen Rows"
Cohesion: 0.08
Nodes (30): ConsumerWidget, ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter (+22 more)

### Community 20 - "Login Form Screen"
Cohesion: 0.06
Nodes (30): FormState, _buildForm, _buildServerList, _busy, child, createState, dispose, _error (+22 more)

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
Cohesion: 0.08
Nodes (24): Future, NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/features/login/login_screen.dart, ProviderContainer, adapter (+16 more)

### Community 25 - "Client Auth Refresh Tests"
Cohesion: 0.08
Nodes (24): HttpClientAdapter, _DeviceAdapter, _KavitaLikeAdapter, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch (+16 more)

### Community 26 - "Series Sections Tests"
Cohesion: 0.08
Nodes (24): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+16 more)

### Community 27 - "Settings Screen Rows"
Cohesion: 0.08
Nodes (23): ../../downloads/image_cache_store.dart, actionLabel, children, createState, didChangeAppLifecycleState, dispose, host, icon (+15 more)

### Community 28 - "Private Widget Fragments"
Cohesion: 0.09
Nodes (23): _FlyingFrond, _SplashWordmark, _AddServerButton, _Field, _Masthead, _ServerRow, _BottomChrome, _ReaderError (+15 more)

### Community 29 - "Auth and Library Refresh Tests"
Cohesion: 0.09
Nodes (20): package:patra/src/api/kavita_client.dart, package:patra/src/auth/session.dart, package:patra/src/features/library/library_screen.dart, _a, _b, _container, main, _Adapter (+12 more)

### Community 30 - "Agent Docs and Triage Labels"
Cohesion: 0.12
Nodes (22): CONTEXT-MAP.md (multi-context repo marker), CONTEXT.md (glossary / domain model), Domain docs consumption protocol, /domain-modeling skill (lazy doc creation), Use the glossary's vocabulary, never a synonym, Proceed silently on missing domain docs, Native issue dependencies (blocked_by), Child ticket (GitHub sub-issue) (+14 more)

### Community 31 - "Router and Tab Shell"
Cohesion: 0.10
Nodes (21): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/launch/launch_animation.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+13 more)

### Community 32 - "Launch Animation Tests"
Cohesion: 0.09
Nodes (21): Opacity, package:flutter/rendering.dart, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size (+13 more)

### Community 33 - "Downloads Provider Notifier"
Cohesion: 0.12
Nodes (20): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+12 more)

### Community 34 - "iOS Runner App Delegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 35 - "Reading Direction Settings"
Cohesion: 0.11
Nodes (19): bool get, leftToRight,
  rightToLeft,, build, DefaultReadingDirectionNotifier, initialReadingDirectionProvider, isRightToLeft, isVerticalScroll, _key (+11 more)

### Community 36 - "Reader and Settings Providers"
Cohesion: 0.13
Nodes (20): ConsumerStatefulWidget, serverReachableProvider, savedChapterProvider, imageCacheSizeProvider, imageCacheStoreProvider, build, chapterInfoProvider, initState (+12 more)

### Community 37 - "Server Reachability Tests"
Cohesion: 0.11
Nodes (18): Container, _announcement, card, client, close, dot, _dotColor, fetch (+10 more)

### Community 38 - "Image Cache Trimming"
Cohesion: 0.11
Nodes (18): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, _lastTrim, _measure (+10 more)

### Community 39 - "Magnify ADR Decisions"
Cohesion: 0.13
Nodes (19): Cog icon correction (Icons.tune was wrong), ADR-0001 — one-finger drag magnifies the page, Inert magnify switch says so while reading vertically, One-hand reading constraint (pinch needs two thumbs), Reference point from pointer-down, not onPanStart, Side-zone tap page-turn bug uncovered and fixed, Swipe page-turn lost while magnify is on, Vertical scrolling excluded from magnify (+11 more)

### Community 40 - "Model and OpenAPI Contract Tests"
Cohesion: 0.12
Nodes (15): dart:convert, File, package:flutter_test/flutter_test.dart, package:patra/src/api/models.dart, package:patra/src/features/reader/spread_layout.dart, main, main, resolve (+7 more)

### Community 41 - "Device Announcement Wiring"
Cohesion: 0.12
Nodes (15): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+7 more)

### Community 42 - "Client Device Tests"
Cohesion: 0.12
Nodes (16): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, _device, fetch, _landscape (+8 more)

### Community 43 - "App Entrypoint Bootstrap"
Cohesion: 0.12
Nodes (15): auth, cacheLimit, identity, imageCache, locale, magnify, main, readingDirection (+7 more)

### Community 44 - "Connection Failure Tests"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:flutter/widgets.dart, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType (+6 more)

### Community 45 - "Reader Settings Sheet"
Cohesion: 0.14
Nodes (14): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+6 more)

### Community 46 - "Image Cache Limit Setting"
Cohesion: 0.15
Nodes (14): int get, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, ImageCacheSettingsStore, initialImageCacheLimitProvider (+6 more)

### Community 47 - "Stateful Widget States"
Cohesion: 0.20
Nodes (15): LaunchAnimation, _LaunchAnimationState, PageLoading, _PageLoadingState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState (+7 more)

### Community 48 - "Cover Image Widgets"
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

### Community 52 - "Entity Naming by Library Type"
Cohesion: 0.15
Nodes (12): ../../api/models.dart, LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel (+4 more)

### Community 53 - "Offline Indicator and Formatting"
Cohesion: 0.17
Nodes (11): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, offlineProvider, _ErrorState, formatBytes, gb, mb, sizeBytes (+3 more)

### Community 54 - "PDF Page Loading Delay"
Cohesion: 0.15
Nodes (12): dart:async, build, createState, dispose, explain, explainAfter, _explaining, initState (+4 more)

### Community 55 - "Downloads Service Tests"
Cohesion: 0.15
Nodes (12): DioException, DownloadsService, _chapter, client, close, failOnPage, fetch, main (+4 more)

### Community 56 - "Connection Failure Classifier"
Cohesion: 0.17
Nodes (11): int?, ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message (+3 more)

### Community 57 - "Language Picker Settings"
Cohesion: 0.18
Nodes (11): build, initialLocaleProvider, _key, languageEndonym, load, LocaleNotifier, LocaleSettingsStore, save (+3 more)

### Community 58 - "About Version Tests"
Cohesion: 0.17
Nodes (11): package:patra/src/api/client_identity.dart, package:patra/src/features/settings/settings_screen.dart, _Adapter, client, close, fetch, main, pumpAndSettle (+3 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 60 - "Magnify Design Space"
Cohesion: 0.20
Nodes (11): Absolute travel distance (2.5x over 400 logical pixels), Anchor clamped to travel/(maxScale-1) band, Anchor-exhaustive sweep test, Answer 4 — aim a loupe (rejected), Answer 1 — the finger gives way (accepted), Answer 2 — the gesture gives way (rejected), Answer 3 — the magnification gives way (rejected), Border constraint (never show anything that is not page) (+3 more)

### Community 61 - "Two-Page Spread Layout"
Cohesion: 0.20
Nodes (9): firstOf, indexOf, length, of, _slotOfPage, slots, spanOf, SpreadLayout (+1 more)

### Community 62 - "Image Cache Store Tests"
Cohesion: 0.22
Nodes (8): dart:io, Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "Magnify Gesture Tests"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "Reading Direction Icon"
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

### Community 69 - "Patra Wordmark Lockup"
Cohesion: 0.25
Nodes (7): build, dotScale, PatraWordmark, size, _tracking, static const, ../theme.dart

### Community 70 - "Entity Naming Tests"
Cohesion: 0.25
Nodes (7): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "Dashed Border Painter"
Cohesion: 0.29
Nodes (6): Color, color, paint, radius, shouldRepaint, strokeWidth

### Community 74 - "Login Screen Consumer"
Cohesion: 0.29
Nodes (7): ConsumerState, authProvider, build, _connect, _forget, LoginScreen, _LoginScreenState

### Community 75 - "Series Detail Providers"
Cohesion: 0.38
Nodes (7): libraryTypeProvider, build, SeriesDetailScreen, _SeriesHero, seriesMetadataProvider, seriesProvider, seriesVolumesProvider

### Community 76 - "Handoff and Tablet Rules"
Cohesion: 0.33
Nodes (6): ClientIdentity / ClientDevice headers, Claude Design handoff as source of truth, System chrome comes and goes with the reader's own, isTabletLayout — three shapes, three answers, ThumbStrip (accordion scrubber drawn at a computed offset), Registered device

### Community 77 - "Localization Delegate"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 78 - "Launch Slot Registry"
Cohesion: 0.33
Nodes (6): LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, W

### Community 79 - "Tag-Driven Release Rules"
Cohesion: 0.60
Nodes (5): Android signing switch via android/key.properties, Build number stays github.run_number, iOS job's two signing paths, Play internal-track upload as a third gated state, Releases are cut by a tag, not by a push

### Community 80 - "Reader Layout Safety Rules"
Cohesion: 0.50
Nodes (5): _PagedView seek guard (_seeking, _reported), The reader must never wrap itself in a LayoutBuilder, SpreadLayout (two-page spreads and wide pages), Spread, Wide page

### Community 81 - "Custom Painters"
Cohesion: 0.40
Nodes (5): CustomPainter, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, _FrondPainter

### Community 82 - "Auth and Identity Providers"
Cohesion: 0.40
Nodes (5): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, _AppVersion

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "Offline and Magnify Notifiers"
Cohesion: 0.50
Nodes (4): OfflineNotifier, initialMagnifyProvider, MagnifyNotifier, Notifier

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "Thumb Strip State"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 88 - "Store Delivery Paths"
Cohesion: 1.00
Nodes (3): Android signed App Bundle / Play internal track, iOS TestFlight / unsigned IPA fallback, Releases cut by a v* tag

## Ambiguous Edges - Review These
- `Patra (Flutter Kavita client)` → `docs/adr/ decision record directory`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1394 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+1389 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1552 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Patra (Flutter Kavita client)` and `docs/adr/ decision record directory`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Answer 1 — the finger gives way (accepted)` connect `Magnify Design Space` to `Magnify Gesture Geometry`, `Magnify ADR Decisions`?**
  _High betweenness centrality (0.040) - this node is a cross-community bridge._
- **Why does `ADR-0001 — one-finger drag magnifies the page` connect `Magnify ADR Decisions` to `Magnify Design Space`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `docs/adr/ decision record directory` connect `Magnify ADR Decisions` to `Agent Docs and Triage Labels`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _1394 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization String Catalogue` be split into smaller, more focused modules?**
  _Cohesion score 0.015503875968992248 - nodes in this community are weakly interconnected._