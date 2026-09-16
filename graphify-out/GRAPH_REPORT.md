# Graph Report - worktree-calm-forest-f319  (2026-09-16)

## Corpus Check
- 177 files · ~349,702 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4136 nodes · 5783 edges · 171 communities (147 shown, 20 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9d7f98e5`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_fr.dart
- app_localizations_en.dart
- thumb_strip.dart
- reader_screen.dart
- models.dart
- session.dart
- theme.dart
- KavitaClient (lib/src/api/kavita_client.dart)
- catalogue_write_path_test.dart
- patra package manifest
- kavita_client.dart
- page_loading.dart
- settings_screen.dart
- measure_page_shapes.dart
- series_sections_test.dart
- series_detail_screen.dart
- _
- home_screen.dart
- static const
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- StatelessWidget
- package:patra/src/api/kavita_client.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_launch.dart
- profile_lock.dart
- ../theme.dart
- reader_test.dart
- Continuous vertical reader: zoom and navigation research
- magnify_gesture.dart
- connection_failure_test.dart
- series_hero_test.dart
- analyze job (pub get, analyze, test)
- page_loading_test.dart
- my_application.cc
- login_screen.dart
- build
- downloads_provider.dart
- Profile lock (lib/src/lock/profile_lock.dart)
- page_rail.dart
- app.dart
- reader_settings_sheet.dart
- launch_animation_test.dart
- image_cache_store.dart
- client_identity_test.dart
- catalogue_store.dart
- AppDelegate
- profile_picker_test.dart
- strip_geometry.dart
- main.dart
- session_scope.dart
- The profile picker (/profiles)
- auth_test.dart
- State
- graphify_merge_driver_test.dart
- series_offline_test.dart
- server_reachability_test.dart
- reading_settings.dart
- strip_width.dart
- catalogue_overlay_test.dart
- _
- strip_width_test.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- The per-profile catalogue
- book_page.dart
- patraAccent = progress/identity, patraOffline = downloads/offline
- DownloadsService (<documents>/downloads/<profile>/<chapterId>/)
- dart:convert
- resume_point.dart
- _ReaderScreenState
- cache_settings.dart
- home_hero_test.dart
- ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it
- ../auth/session.dart
- package:flutter_test/flutter_test.dart
- ConsumerWidget
- saved_copies_test.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- cover_placeholder.dart
- package:flutter/foundation.dart
- Compact three-blade frond variant (icons at or under 72px)
- test_support.dart
- 72px threshold: small icons render from the compact master
- keychain.dart
- A profile is exactly one Kavita account
- book_reader_test.dart
- profile_switch_test.dart
- page_rail_test.dart
- Map
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- magnify_gesture_test.dart
- ADR-0008 — Kavita paginates a book; the app parses no EPUB
- Patra Frond Mark (five-blade master, 1024px)
- library_scan_test.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- offlineProvider
- ProfilePreferencesStore (profile_preferences.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- strip_geometry_test.dart
- direction_icon.dart
- Patra
- AsyncValue.isResolvedFailure
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- package:flutter/material.dart
- MainActivity.kt
- dart:math
- image_cache_store_test.dart
- saved_chapters_per_profile_test.dart
- The graphify union merge driver (two halves)
- Issue tracker agent skill (GitHub issues via gh)
- Spread
- triage-labels.md
- @immutable
- gen-l10n configuration (non-nullable getter)
- bool?
- page_shape.dart
- profile_files.dart
- Where a page stops being a page: the vertical threshold
- api/models.dart
- ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series
- openapi_contract_test.dart
- catalogue_overlay.dart
- reading_direction.dart
- _ReaderSettings
- package:flutter_riverpod/flutter_riverpod.dart
- AuthNotifier
- downloads_provider_test.dart
- The Kavita API client
- routes.dart
- The catalogue
- The reader
- Preferences
- catalogue_reads.dart
- SKILL.md
- .github/CLAUDE.md
- entity_naming_test.dart
- CustomPainter
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- entity_naming.dart
- locale_settings.dart
- BookPageBody
- ADR-0011 — A second theme is deferred, not rejected
- patra_mark.dart
- ADR-0009 — A saved copy keeps the pagination it was made with
- _BookView
- _ThumbStripState
- return
- ADR-0010 — A book's page is drawn by the app, not handed to a web view
- _Strip
- BookPicture
- Credential
- UserDto.isAdmin (role read from the login response)
- gen_app_icons.sh
- downloads_service_test.dart
- StripWidthController
- reader_settings_sheet_test.dart
- String?
- _ProbeThumb

## God Nodes (most connected - your core abstractions)
1. `_` - 66 edges
2. `_` - 32 edges
3. `kavitaClientProvider` - 22 edges
4. `offlineProvider` - 21 edges
5. `authProvider` - 15 edges
6. `sessionProvider` - 14 edges
7. `_ReaderScreenState` - 14 edges
8. `build` - 13 edges
9. `Continuous vertical reader: zoom and navigation research` - 13 edges
10. `The per-profile catalogue` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Server version` --semantically_similar_to--> `pubspec version is only a local fallback`  [INFERRED] [semantically similar]
  CONTEXT.md → pubspec.yaml
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `Registered device` --conceptually_related_to--> `patra package manifest`  [INFERRED]
  CONTEXT.md → pubspec.yaml
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml

## Import Cycles
- None detected.

## Communities (171 total, 20 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (176): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+168 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (163): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+155 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (163): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+155 more)

### Community 3 - "thumb_strip.dart"
Cohesion: 0.02
Nodes (86): Animation, Duration, _accordion, _backfillConcurrent, _baseShare, _baseWidth, build, _centre (+78 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.02
Nodes (110): book_contents.dart, book_page.dart, anchor, _anchorFor, _anchors, aspectRatios, barHeight, BookPageKey (+102 more)

### Community 5 - "models.dart"
Cohesion: 0.02
Nodes (87): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, BookInfo, bookScrollId (+79 more)

### Community 6 - "session.dart"
Cohesion: 0.04
Nodes (55): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+47 more)

### Community 7 - "theme.dart"
Cohesion: 0.03
Nodes (60): base, body, build, color, colors, _controller, controlMaxWidth, copyWith (+52 more)

### Community 8 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.16
Nodes (16): ConnectionFailureKind.blockedByBrowser, ChapterDto.sortOrder is the reading order, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), The Kavita client is deliberately hand-written, android.permission.INTERNET in the main manifest, KavitaClient (lib/src/api/kavita_client.dart), Kavita (self-hosted server) (+8 more)

### Community 9 - "catalogue_write_path_test.dart"
Cohesion: 0.11
Nodes (18): package:patra/src/catalogue/catalogue_reads.dart, _Adapter, asked, client, close, container, fetch, _lea (+10 more)

### Community 10 - "patra package manifest"
Cohesion: 0.05
Nodes (50): Dependabot pub ecosystem (weekly), Administrator, Auth key, Avatar, Catalogue, Chapter, Continue (the promotion), Credential (+42 more)

### Community 11 - "kavita_client.dart"
Cohesion: 0.04
Nodes (55): Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient, baseUrl (+47 more)

### Community 12 - "page_loading.dart"
Cohesion: 0.10
Nodes (20): AlignmentGeometry, BoxFit, alignment, build, createState, dispose, explain, explainAfter (+12 more)

### Community 13 - "settings_screen.dart"
Cohesion: 0.05
Nodes (46): ConsumerStatefulWidget, ../../downloads/image_cache_store.dart, serverReachableProvider, serverVersionProvider, imageCacheSizeProvider, imageCacheStoreProvider, ReaderScreen, actionLabel (+38 more)

### Community 14 - "measure_page_shapes.dart"
Cohesion: 0.04
Nodes (45): HttpClient, _Api, apiKey, base, buffer, chapterInfo, chapters, _client (+37 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.06
Nodes (30): int? savedChapter,
  bool, NavigatorState, build, cacheDir, _chapter, client, close, delegates (+22 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.04
Nodes (55): ../../catalogue/catalogue_reads.dart, ../../entity_naming.dart, Chapter, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data (+47 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (38): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+30 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.08
Nodes (25): continue_hero.dart, Library, _cardMaxWidth, _cardSpacing, _cardWidth, columns, featured, label (+17 more)

### Community 19 - "static const"
Cohesion: 0.10
Nodes (18): dart:ui, build, gapEm, PatraLockup, size, leaf1, leaf2, markHeight (+10 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.03
Nodes (58): abstract class, bookLineHeight, bookLineHeightFor, bookReadingFace, bookReadingFaceFor, bookTextSize, bookTextSizeFor, build (+50 more)

### Community 21 - "test_support.dart"
Cohesion: 0.04
Nodes (48): MemoryKeychain? keychain,
  bool, required int chapterId,
  String, available, bytes, catalogueVolumesFixture, channel, chapter, close (+40 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.06
Nodes (35): appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey, deviceModel (+27 more)

### Community 23 - "StatelessWidget"
Cohesion: 0.05
Nodes (39): cover_placeholder.dart, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, BookPageUnavailable, _BottomChrome, _ReaderError, _SettingsCog (+31 more)

### Community 24 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.10
Nodes (19): Finder get, IconButton, package:patra/src/api/kavita_client.dart, package:patra/src/resume_point.dart, _Adapter, close, _cloud, _explanation (+11 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (31): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+23 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.04
Nodes (50): ChapterContent get, ../features/reader/book_page.dart, MangaFormat, bookScrollId, bytes, _carryPicture, chapterDir, chapterId (+42 more)

### Community 27 - "patra_launch.dart"
Cohesion: 0.06
Nodes (31): AnimationController, build, child, _controller, createState, didChangeDependencies, didUpdateWidget, dispose (+23 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.07
Nodes (27): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+19 more)

### Community 29 - "../theme.dart"
Cohesion: 0.06
Nodes (36): ../branding/patra_lockup.dart, ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, ../../l10n/generated/app_localizations.dart, SavedChapter, bytes (+28 more)

### Community 30 - "reader_test.dart"
Cohesion: 0.04
Nodes (46): CustomScrollView, Key? readerKey,
  int, NeverScrollableScrollPhysics, PageView, required int initialPage,
  
  
  
  ReadingDirection?, required int pagesRead,
  int, Scrollable, Slider (+38 more)

### Community 31 - "Continuous vertical reader: zoom and navigation research"
Cohesion: 0.04
Nodes (46): 1. State model, 2. Layout, 3. Gestures and alternate controls, 4. Current-page and progress stability, 5. Navigation target, 6. Delivery sequence, Acceptance and test matrix, `/api/Reader/file-dimensions` and chapter info (+38 more)

### Community 32 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (28): anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH, half (+20 more)

### Community 33 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 34 - "series_hero_test.dart"
Cohesion: 0.06
Nodes (34): CachedNetworkImage, LibraryType? libraryType,
  Locale, package:cached_network_image/cached_network_image.dart, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/theme.dart, package:patra/src/widgets/cover.dart, package:patra/src/widgets/cover_placeholder.dart, _channelGap (+26 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "page_loading_test.dart"
Cohesion: 0.19
Nodes (12): Image, ImageInfo, ImageProvider, package:patra/src/features/reader/page_loading.dart, _Arrives, _drawn, loadImage, main (+4 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "login_screen.dart"
Cohesion: 0.04
Nodes (65): ../../api/connection_failure.dart, FormState, authProvider, Profile, Session, profileCatalogueProvider, profileDownloadsProvider, scan (+57 more)

### Community 39 - "build"
Cohesion: 0.27
Nodes (11): _BookPage, bookPageProvider, build, chapterInfoProvider, bookLineHeightProvider, bookReadingFaceProvider, bookTextSizeProvider, _BookLineSpacingRow (+3 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.05
Nodes (41): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, clearPendingProgress, copyWith, _disposed (+33 more)

### Community 41 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.22
Nodes (13): ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), Credential (sealed password-or-authKey type), DeviceBiometrics (lib/src/lock/biometrics.dart), Domain docs (single-context CONTEXT.md and docs/adr/), imageCacheKey (one cover fetched once per household), The lock's copy refuses the sentence it would be easiest to write (+5 more)

### Community 42 - "page_rail.dart"
Cohesion: 0.06
Nodes (32): bottomGap, build, controller, createState, dispose, _documentAt, _dragging, _dragPage (+24 more)

### Community 43 - "app.dart"
Cohesion: 0.05
Nodes (42): ../../branding/patra_launch.dart, ConsumerState, double?, EdgeInsetsGeometry, features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart (+34 more)

### Community 44 - "reader_settings_sheet.dart"
Cohesion: 0.06
Nodes (33): direction_icon.dart, ../features/reader/reading_direction.dart, ../features/reader/strip_geometry.dart, _ActionRow, current, defaultValue, direction, _DirectionRows (+25 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.14
Nodes (14): package:patra/src/branding/patra_launch.dart, package:patra/src/features/launch/launch_animation.dart, static int, _app, build, createState, _Home, _HomeState (+6 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 47 - "client_identity_test.dart"
Cohesion: 0.09
Nodes (21): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, delete, _device, _DeviceAdapter (+13 more)

### Community 48 - "catalogue_store.dart"
Cohesion: 0.05
Nodes (40): _catalogueRoot, _deleteSeries, dirNameFor, _file, fromJson, isEmpty, libraries, loadOnDeck (+32 more)

### Community 49 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "profile_picker_test.dart"
Cohesion: 0.12
Nodes (16): CustomPaint, LoginResult, Opacity, package:patra/src/branding/patra_mark.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/widgets/dashed_border.dart, package:patra/src/widgets/patra_wordmark.dart, box (+8 more)

### Community 51 - "strip_geometry.dart"
Cohesion: 0.06
Nodes (30): double get, IndexedWidgetBuilder, anchorAt, build, childCount, decodeWidthFor, estimateMaxScrollOffset, fraction (+22 more)

### Community 52 - "main.dart"
Cohesion: 0.07
Nodes (26): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+18 more)

### Community 53 - "session_scope.dart"
Cohesion: 0.10
Nodes (20): catalogue/catalogue_provider.dart, features/launch/launch_animation.dart, auth, build, child, _container, createState, dispose (+12 more)

### Community 54 - "The profile picker (/profiles)"
Cohesion: 0.17
Nodes (13): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation, LaunchSlot registry (LaunchLogoSlot, LaunchWordmarkSlot), The outro adapts to the screen it lands on, not to a flag, Blades are turned like pages, not grown in place (+5 more)

### Community 55 - "auth_test.dart"
Cohesion: 0.09
Nodes (21): DioException get, Exception, SignInExpired, package:patra/src/keychain.dart, accountId, apiKey, call, calls (+13 more)

### Community 56 - "State"
Cohesion: 0.23
Nodes (13): PatraLaunch, _PatraLaunchState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState, _VerticalScrollView, _VerticalScrollViewState (+5 more)

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "series_offline_test.dart"
Cohesion: 0.04
Nodes (58): dart:io, FilledButton, InkWell, package:patra/src/catalogue/catalogue_provider.dart, package:patra/src/catalogue/catalogue_store.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/features/home/continue_hero.dart, package:patra/src/settings/reading_settings.dart (+50 more)

### Community 59 - "server_reachability_test.dart"
Cohesion: 0.10
Nodes (19): Container, _Adapter, _announcement, card, client, close, dot, _dotColor (+11 more)

### Community 60 - "reading_settings.dart"
Cohesion: 0.07
Nodes (27): leftToRight,
  rightToLeft,, atkinsonHyperlegibleNext, canSetItalic, defaultBookLineHeight, defaultBookReadingFace, defaultBookTextSize, directionNamed, family (+19 more)

### Community 61 - "strip_width.dart"
Cohesion: 0.04
Nodes (50): Drag?, _anchor, build, _capture, child, _clampedBy, clampWidthFactor, controller (+42 more)

### Community 62 - "catalogue_overlay_test.dart"
Cohesion: 0.04
Nodes (53): DioException, HttpClientAdapter, package:patra/src/catalogue/catalogue_overlay.dart, _BookAdapter, adapter, _AnswersThenFails, _AnswersThenHangs, calls (+45 more)

### Community 63 - "_"
Cohesion: 0.10
Nodes (23): AsyncValue, FutureProvider, ResolvedFailure, _, CatalogueDeps, CatalogueRead, _deps, _fetch (+15 more)

### Community 64 - "strip_width_test.dart"
Cohesion: 0.04
Nodes (47): dart:typed_data, package:flutter/rendering.dart, package:patra/src/features/reader/strip_width.dart, RenderBox, RenderSliverMultiBoxAdaptor?, required double to,
  int, _aspectRatioFor, bottom (+39 more)

### Community 65 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.13
Nodes (13): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, No invite flow is shipped, Why, ADR-0005 — The catalogue is what the device remembers, and it is files (+5 more)

### Community 66 - "The per-profile catalogue"
Cohesion: 0.15
Nodes (16): The entry round trip is hidden by the launch animation, Cache-first overlay precedence rule, The per-profile catalogue, A cover is never pinned; the answer is a real placeholder, drift (rejected, but not for the usual reason), Files, not a database, hive_ce (the near-free alternative, rejected), isResolvedFailure means something new (+8 more)

### Community 67 - "book_page.dart"
Cohesion: 0.03
Nodes (79): BookPage, EdgeInsets, Iterable, anchor, at, _attribute, _attributeMatch, _attributeOf (+71 more)

### Community 68 - "patraAccent = progress/identity, patraOffline = downloads/offline"
Cohesion: 0.16
Nodes (14): patraAccent = progress/identity, patraOffline = downloads/offline, /api/Series/currently-reading does not mean what it says, Claude Design handoff (.claude/design/HANDOFF.md), featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), markChapterRead (mark-multiple-read / -unread), POST /api/Series/on-deck, ProfileAvatar and _FaceBadge (+6 more)

### Community 69 - "DownloadsService (<documents>/downloads/<profile>/<chapterId>/)"
Cohesion: 0.10
Nodes (24): ADR-0001 reader magnify gesture, GET /api/Reader/chapter-info pageDimensions, A column of rows runs the full width at the app's gutter, DownloadsNotifier must re-read state.value after an await, DownloadsService (<documents>/downloads/<profile>/<chapterId>/), A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, ImageCacheStore.trim (a capped image cache) (+16 more)

### Community 70 - "dart:convert"
Cohesion: 0.06
Nodes (32): dart:convert, accountIdFrom, _padded, segments, NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/login/login_screen.dart (+24 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 72 - "_ReaderScreenState"
Cohesion: 0.21
Nodes (13): libraryNameProvider, bookContentsProvider, _buildBookReader, _buildReader, _onSettingsOutcome, _ReaderScreenState, chapterDirectionProvider, libraryDirectionsProvider (+5 more)

### Community 73 - "cache_settings.dart"
Cohesion: 0.16
Nodes (14): int get, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheSettingsProvider, ImageCacheSettingsStore (+6 more)

### Community 74 - "home_hero_test.dart"
Cohesion: 0.06
Nodes (31): LinearProgressIndicator, _backdrop, _chapter, client, close, fetch, _finishedBookVolume, _iPad (+23 more)

### Community 75 - "ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it"
Cohesion: 0.20
Nodes (9): ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it, Consequences, Considered options, and why not, Context, Cost, accepted, Decision, Prototype, Sources (+1 more)

### Community 76 - "../auth/session.dart"
Cohesion: 0.06
Nodes (35): ../api/kavita_client.dart, ../auth/session.dart, catalogue_store.dart, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, _done, markStored (+27 more)

### Community 77 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.18
Nodes (9): package:flutter_test/flutter_test.dart, package:patra/src/api/account_id.dart, package:patra/src/features/reader/spread_layout.dart, _jwt, main, seg, _chapter, copyWithoutDimensions (+1 more)

### Community 78 - "ConsumerWidget"
Cohesion: 0.08
Nodes (45): catalogue, ConsumerWidget, kavitaClientProvider, offlineProvider, chapterDirProvider, downloadsProvider, savedChapterProvider, _store (+37 more)

### Community 79 - "saved_copies_test.dart"
Cohesion: 0.07
Nodes (26): package:patra/src/features/downloads/downloads_screen.dart, _answer, _chapterId, client, close, container, dir, fetch (+18 more)

### Community 80 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "cover_placeholder.dart"
Cohesion: 0.09
Nodes (21): _apart, _bandFor, _brighter, build, choice, CoverPlaceholder, coverPlaceholderTones, _dimmest (+13 more)

### Community 82 - "package:flutter/foundation.dart"
Cohesion: 0.40
Nodes (4): _registered, registerPatraFontLicenses, package:flutter/foundation.dart, package:flutter/services.dart

### Community 83 - "Compact three-blade frond variant (icons at or under 72px)"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 84 - "test_support.dart"
Cohesion: 0.05
Nodes (43): package:patra/src/api/client_identity.dart, package:patra/src/api/models.dart, package:patra/src/auth/session.dart, package:patra/src/features/reader/reading_direction.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, package:patra/src/settings/cache_settings.dart, Profile? active,
  Map (+35 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "keychain.dart"
Cohesion: 0.18
Nodes (11): delete, Keychain, keychainProvider, read, readAll, SecureKeychain, _storage, write (+3 more)

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "book_reader_test.dart"
Cohesion: 0.05
Nodes (43): CachedNetworkImageProvider, MemoryImage, package:patra/src/features/reader/book_page.dart, RichText, ScrollableState, String? html,
  int, adapter, _addressedPicture (+35 more)

### Community 89 - "profile_switch_test.dart"
Cohesion: 0.06
Nodes (34): package:patra/src/session_scope.dart, required Credential credential,
  ClientIdentity, _app, attempts, close, fetch, identity, _lea (+26 more)

### Community 90 - "page_rail_test.dart"
Cohesion: 0.08
Nodes (23): package:patra/src/features/reader/page_rail.dart, package:patra/src/features/reader/strip_geometry.dart, ScrollController, 8, _bottomGap, geometry, _Harness, _heightAt (+15 more)

### Community 91 - "Map"
Cohesion: 0.18
Nodes (21): OfflineNotifier, sessionProvider, _ProfileFace, LibraryScanNotifier, PageShapesNotifier, ReadOverridesNotifier, BookLineHeightNotifier, BookReadingFaceNotifier (+13 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "magnify_gesture_test.dart"
Cohesion: 0.25
Nodes (7): package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 95 - "ADR-0008 — Kavita paginates a book; the app parses no EPUB"
Cohesion: 0.25
Nodes (7): ADR-0008 — Kavita paginates a book; the app parses no EPUB, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 96 - "Patra Frond Mark (five-blade master, 1024px)"
Cohesion: 0.40
Nodes (5): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed)

### Community 97 - "library_scan_test.dart"
Cohesion: 0.05
Nodes (41): Completer, dart:async, package:patra/src/features/reader/thumb_strip.dart, PopupMenuItem, required bool admin,
  bool, _Adapter, client, close (+33 more)

### Community 98 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 99 - "offlineProvider"
Cohesion: 0.15
Nodes (14): Android job: android/key.properties switch, KavitaClient._bearerIsIrrelevant, Build number is github.run_number, ClientDevice headers (client_device.dart), ClientIdentity (app version read off the binary), iOS job: signed TestFlight path or unsigned IPA fallback, MangaFormat.isImageReadable (PDF reads, EPUB cannot), offlineProvider (+6 more)

### Community 100 - "ProfilePreferencesStore (profile_preferences.dart)"
Cohesion: 0.16
Nodes (15): reading_settings.dart / locale_settings.dart as device defaults, LibraryTypeNaming (lib/src/entity_naming.dart), The fixed French glossary, _PatraShell._labelsFit (the bottom bar measures its labels), The language is the only preference written twice, LibraryType (Manga/Comic/Book/Image/LightNovel/ComicVine), localeProvider and languageEndonym, Localization (app_en.arb template, app_fr.arb) (+7 more)

### Community 101 - "A profile persists the auth key and nothing else"
Cohesion: 0.33
Nodes (7): apiKey is the opds auth key, one row not a concept, A profile persists the auth key and nothing else, Using the auth key as the request scheme (rejected alternative), LoginDto ignores username/password when ApiKey is passed, POST /api/Plugin/authenticate (rejected alternative), refresh-token on 0.9.0.x must not be leaned on, Token lifetimes are absent from the spec

### Community 102 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 103 - "strip_geometry_test.dart"
Cohesion: 0.08
Nodes (24): , 8, controller, fraction, geometry, _heightAt, images, main (+16 more)

### Community 104 - "direction_icon.dart"
Cohesion: 0.20
Nodes (9): ReadingDirection, build, color, direction, DirectionIcon, paint, shouldRepaint, size (+1 more)

### Community 105 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 106 - "AsyncValue.isResolvedFailure"
Cohesion: 0.21
Nodes (12): AuthState.atLaunch, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, isLaunchProvider, AsyncValue.isResolvedFailure, kavitaClientProvider, _OfflineHome (an empty state, not the banner returning), OfflineIndicator (a status in the app bar, not a banner) (+4 more)

### Community 107 - "ADR-0004 — The auth key is the only secret a profile keeps"
Cohesion: 0.33
Nodes (6): ADR-0004 — The auth key is the only secret a profile keeps, Consequences, Context, Cost, accepted, Decision, Why

### Community 108 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 109 - "AppLocalizations"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 110 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (37): build, dotScale, markEm, PatraWordmark, size, _tracking, package:dio/dio.dart, package:flutter/material.dart (+29 more)

### Community 112 - "dart:math"
Cohesion: 0.25
Nodes (7): Color, dart:math, color, paint, radius, shouldRepaint, strokeWidth

### Community 113 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 114 - "saved_chapters_per_profile_test.dart"
Cohesion: 0.11
Nodes (17): _catalogueRoot, client, close, fetch, _lea, locale, main, _profile (+9 more)

### Community 119 - "@immutable"
Cohesion: 0.50
Nodes (4): @immutable, BookAnchor, MagnifyGesture, MagnifyTransform

### Community 126 - "page_shape.dart"
Cohesion: 0.17
Nodes (11): build, isVertical, libraryType, measuredPagesNeeded, _median, middle, of, PageShape (+3 more)

### Community 128 - "Where a page stops being a page: the vertical threshold"
Cohesion: 0.15
Nodes (12): A second library, one anybody can re-run: Kavita's public demo, How to re-run it, Sources, The answer, The measurement — one real library, The question, What #57 implements, What is still thin (+4 more)

### Community 129 - "api/models.dart"
Cohesion: 0.08
Nodes (23): api/models.dart, BookContentsEntry, BookContentsButton, build, _contentsIndent, _ContentsList, depth, entries (+15 more)

### Community 130 - "ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series"
Cohesion: 0.17
Nodes (11): A direction per library, shipped (#65), ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series, Amendment — 2026-09-13 (#56), Amendment — 2026-09-13 (#57), Amendment — 2026-09-13 (#58), Amendment — 2026-09-13 (#58, shipped), Amendment — 2026-09-13 (#65), Consequences (+3 more)

### Community 131 - "openapi_contract_test.dart"
Cohesion: 0.25
Nodes (7): File, main, resolve, schema, schemas, spec, specName

### Community 132 - "catalogue_overlay.dart"
Cohesion: 0.11
Nodes (19): catalogue_provider.dart, fetch, held, heldSpine, live, onDeckOverlay, _onDeckReadProvider, overlaid (+11 more)

### Community 133 - "reading_direction.dart"
Cohesion: 0.10
Nodes (19): bool get, canPromoteToLibrary, ChapterDirection, ChapterDirectionKey, detected, detectedDirectionProvider, direction, hasLibraryDirection (+11 more)

### Community 134 - "_ReaderSettings"
Cohesion: 0.67
Nodes (3): _BookSettings, _PictureSettings, _ReaderSettings

### Community 135 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.28
Nodes (8): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart, FakeBiometrics

### Community 136 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 137 - "downloads_provider_test.dart"
Cohesion: 0.10
Nodes (19): adapter, _chapter, close, container, dir, fetch, gate, jsonDecode (+11 more)

### Community 138 - "The Kavita API client"
Cohesion: 0.50
Nodes (3): Kavita API client — deliberately hand-written, Reaching the server: cleartext, and saying what went wrong, The Kavita API client

### Community 139 - "routes.dart"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 141 - "The reader"
Cohesion: 0.50
Nodes (3): A book, Reader, The reader

### Community 143 - "catalogue_reads.dart"
Cohesion: 0.14
Nodes (13): catalogue_overlay.dart, catalogue_read.dart, Series, SeriesMetadata, libraries, libraryTypeProvider, list, onDeck (+5 more)

### Community 146 - "entity_naming_test.dart"
Cohesion: 0.25
Nodes (7): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main

### Community 147 - "CustomPainter"
Cohesion: 0.33
Nodes (6): CustomPainter, _LaunchPainter, _MarkPainter, _Hatch, DashedBorderPainter, _DirectionPainter

### Community 151 - "entity_naming.dart"
Cohesion: 0.15
Nodes (12): LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel, resumeTitle (+4 more)

### Community 152 - "locale_settings.dart"
Cohesion: 0.17
Nodes (11): ../keychain.dart, _key, _keychain, languageEndonym, load, localeSettingsProvider, LocaleSettingsStore, null (+3 more)

### Community 154 - "ADR-0011 — A second theme is deferred, not rejected"
Cohesion: 0.25
Nodes (7): ADR-0011 — A second theme is deferred, not rejected, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 155 - "patra_mark.dart"
Cohesion: 0.20
Nodes (9): build, color, height, paint, PatraMark, shouldRepaint, _wordBounds, patra_logo_paths.dart (+1 more)

### Community 156 - "ADR-0009 — A saved copy keeps the pagination it was made with"
Cohesion: 0.29
Nodes (6): ADR-0009 — A saved copy keeps the pagination it was made with, Consequence, Context, Cost, accepted, Decision, Why

### Community 158 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 159 - "return"
Cohesion: 0.06
Nodes (34): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:patra/src/features/home/home_screen.dart (+26 more)

### Community 160 - "ADR-0010 — A book's page is drawn by the app, not handed to a web view"
Cohesion: 0.29
Nodes (6): ADR-0010 — A book's page is drawn by the app, not handed to a web view, Consequence, Context, Cost, accepted, Decision, Why

### Community 162 - "BookPicture"
Cohesion: 0.50
Nodes (5): BookBlock, BookPicture, BookWords, endBlock, parseBookPage

### Community 163 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 164 - "UserDto.isAdmin (role read from the login response)"
Cohesion: 0.47
Nodes (6): Admin scan request from the Library tab's app-bar menu, AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, POST /api/Library/scan (admin only), LibraryScanNotifier, UserDto.isAdmin (role read from the login response)

### Community 165 - "gen_app_icons.sh"
Cohesion: 0.47
Nodes (5): The header draws the five-blade fan at 24pt, The palm frond mark (five-blade and compact three-blade), android_icon(), ios_icon(), gen_app_icons.sh script

### Community 168 - "downloads_service_test.dart"
Cohesion: 0.09
Nodes (21): DownloadsService, _book, _BookAdapter, _bookId, _bookPageHtml, _chapter, client, close (+13 more)

### Community 170 - "reader_settings_sheet_test.dart"
Cohesion: 0.14
Nodes (16): DirectionPicked, DirectionPromotedToLibrary, LibraryDirectionCleared, ReaderSettingsOutcome, SeriesDirectionCleared, package:patra/src/settings/profile_preferences.dart, package:patra/src/widgets/reader_settings_sheet.dart, _builtIn (+8 more)

### Community 171 - "String?"
Cohesion: 0.17
Nodes (11): int?, ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message (+3 more)

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **2930 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+2925 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3186 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `_` connect `_` to `api/models.dart`, `library_scan_test.dart`, `login_screen.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `page_rail.dart`, `String?`, `../auth/session.dart`, `app.dart`, `ConsumerWidget`, `package:flutter/material.dart`, `series_detail_screen.dart`, `home_screen.dart`, `static const`, `StatelessWidget`, `Map`, `../theme.dart`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `ProfilePreferencesStore (profile_preferences.dart)`, `patraAccent = progress/identity, patraOffline = downloads/offline`, `AsyncValue.isResolvedFailure`, `The profile picker (/profiles)`, `profile_lock_sheet.dart`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `UserDto.isAdmin (role read from the login response)`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _2930 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.011299435028248588 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.012195121951219513 - nodes in this community are weakly interconnected._