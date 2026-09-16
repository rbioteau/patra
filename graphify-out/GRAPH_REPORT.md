# Graph Report - patra  (2026-09-16)

## Corpus Check
- 176 files · ~343,003 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4078 nodes · 5708 edges · 167 communities (145 shown, 18 thin omitted)
- Extraction: 98% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f5abe9bb`
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
- patra_logo_paths.dart
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- StatelessWidget
- package:flutter_test/flutter_test.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_launch.dart
- profile_lock.dart
- downloads_screen.dart
- reader_test.dart
- Continuous vertical reader: zoom and navigation research
- magnify_gesture.dart
- patra_mark.dart
- List
- analyze job (pub get, analyze, test)
- server_version_test.dart
- my_application.cc
- login_screen.dart
- package:flutter/material.dart
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
- LaunchAnimation
- auth_test.dart
- State
- graphify_merge_driver_test.dart
- return
- server_reachability_test.dart
- reading_settings.dart
- strip_width.dart
- HttpClientAdapter
- _
- strip_width_test.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- The per-profile catalogue
- book_page.dart
- patraAccent = progress/identity, patraOffline = downloads/offline
- magnify_gesture.dart (one-finger drag magnifier)
- profile_switch_test.dart
- resume_point.dart
- _ReaderScreenState
- cache_settings.dart
- home_hero_test.dart
- ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it
- catalogue_provider.dart
- page_loading_test.dart
- ConsumerWidget
- saved_copies_test.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- cover_placeholder.dart
- package:flutter/foundation.dart
- Compact three-blade frond variant (icons at or under 72px)
- profile_lock_ui_test.dart
- 72px threshold: small icons render from the compact master
- Keychain
- A profile is exactly one Kavita account
- book_reader_test.dart
- direction_icon.dart
- page_rail_test.dart
- Map
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- dart:math
- ADR-0008 — Kavita paginates a book; the app parses no EPUB
- Patra Frond Mark (five-blade master, 1024px)
- dart:convert
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- Android job: android/key.properties switch
- ConnectionFailure (connection_failure.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- strip_geometry_test.dart
- catalogue_overlay_test.dart
- Patra
- UserDto.isAdmin (role read from the login response)
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- package:flutter_riverpod/flutter_riverpod.dart
- MainActivity.kt
- profile_picker_screen.dart
- profile_avatar.dart
- DownloadsService (<documents>/downloads/<profile>/<chapterId>/)
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
- biometrics.dart
- AuthNotifier
- downloads_provider_test.dart
- The Kavita API client
- routes.dart
- The catalogue
- The reader
- Preferences
- dart:async
- SKILL.md
- .github/CLAUDE.md
- isTabletLayout(context)
- series_offline_test.dart
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- entity_naming.dart
- locale_settings.dart
- static const
- dashed_border.dart
- ADR-0009 — A saved copy keeps the pagination it was made with
- cover.dart
- _ThumbStripState
- package:patra/src/api/kavita_client.dart
- ADR-0010 — A book's page is drawn by the app, not handed to a web view
- BookPicture
- Credential
- Profile
- package:dio/dio.dart
- StripWidthController
- reader_settings_sheet_test.dart
- SignInExpired

## God Nodes (most connected - your core abstractions)
1. `_` - 66 edges
2. `_` - 32 edges
3. `kavitaClientProvider` - 22 edges
4. `offlineProvider` - 21 edges
5. `authProvider` - 15 edges
6. `_ReaderScreenState` - 14 edges
7. `sessionProvider` - 13 edges
8. `build` - 13 edges
9. `Continuous vertical reader: zoom and navigation research` - 13 edges
10. `The per-profile catalogue` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Server version` --semantically_similar_to--> `pubspec version is only a local fallback`  [INFERRED] [semantically similar]
  CONTEXT.md → pubspec.yaml
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `Registered device` --conceptually_related_to--> `patra package manifest`  [INFERRED]
  CONTEXT.md → pubspec.yaml
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/home_offline_test.dart → lib/src/auth/session.dart

## Import Cycles
- None detected.

## Communities (167 total, 18 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (170): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+162 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (157): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+149 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (157): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+149 more)

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
Cohesion: 0.04
Nodes (56): base, body, build, color, colors, _controller, controlMaxWidth, copyWith (+48 more)

### Community 8 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.12
Nodes (23): ADR-0001 reader magnify gesture, ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), KavitaClient._bearerIsIrrelevant, ChapterDto.sortOrder is the reading order, ClientDevice headers (client_device.dart), Credential (sealed password-or-authKey type) (+15 more)

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
Cohesion: 0.11
Nodes (18): AlignmentGeometry, BoxFit, alignment, build, createState, dispose, explain, explainAfter (+10 more)

### Community 13 - "settings_screen.dart"
Cohesion: 0.05
Nodes (46): ConsumerStatefulWidget, ../../downloads/image_cache_store.dart, serverReachableProvider, serverVersionProvider, imageCacheSizeProvider, imageCacheStoreProvider, ReaderScreen, actionLabel (+38 more)

### Community 14 - "measure_page_shapes.dart"
Cohesion: 0.04
Nodes (45): HttpClient, _Api, apiKey, base, buffer, chapterInfo, chapters, _client (+37 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.06
Nodes (30): int? savedChapter,
  bool, LinearProgressIndicator, build, cacheDir, _chapter, client, close, delegates (+22 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.04
Nodes (56): ../../catalogue/catalogue_reads.dart, ../../entity_naming.dart, Chapter, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data (+48 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (38): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+30 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.07
Nodes (26): AsyncValue, continue_hero.dart, Library, ResolvedFailure, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+18 more)

### Community 19 - "patra_logo_paths.dart"
Cohesion: 0.17
Nodes (11): dart:ui, leaf1, leaf2, markHeight, markWidth, PatraLogoPaths, splitX, wordmark (+3 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.04
Nodes (55): abstract class, bookLineHeight, bookLineHeightFor, bookTextSize, bookTextSizeFor, build, _byProfile, clearLibraryDirection (+47 more)

### Community 21 - "test_support.dart"
Cohesion: 0.04
Nodes (48): MemoryKeychain? keychain,
  bool, required int chapterId,
  String, available, bytes, catalogueVolumesFixture, channel, chapter, close (+40 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.06
Nodes (35): appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey, deviceModel (+27 more)

### Community 23 - "StatelessWidget"
Cohesion: 0.08
Nodes (24): _LibraryCard, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, BookPageUnavailable, _BottomChrome, _ReaderError, _SettingsCog (+16 more)

### Community 24 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (55): package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/api/client_identity.dart, package:patra/src/api/models.dart, package:patra/src/auth/session.dart, package:patra/src/entity_naming.dart, package:patra/src/features/reader/page_shape.dart (+47 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (31): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+23 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.04
Nodes (50): ChapterContent get, ../features/reader/book_page.dart, MangaFormat, bookScrollId, bytes, _carryPicture, chapterDir, chapterId (+42 more)

### Community 27 - "patra_launch.dart"
Cohesion: 0.07
Nodes (27): AnimationController, build, child, _controller, createState, didChangeDependencies, didUpdateWidget, dispose (+19 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.08
Nodes (25): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+17 more)

### Community 29 - "downloads_screen.dart"
Cohesion: 0.07
Nodes (29): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, ../../l10n/generated/app_localizations.dart, SavedChapter, bytes, chapter (+21 more)

### Community 30 - "reader_test.dart"
Cohesion: 0.04
Nodes (48): CustomScrollView, Key? readerKey,
  int, NeverScrollableScrollPhysics, PageView, required int initialPage,
  
  
  
  ReadingDirection?, required int pagesRead,
  int, Scrollable, Slider (+40 more)

### Community 31 - "Continuous vertical reader: zoom and navigation research"
Cohesion: 0.04
Nodes (46): 1. State model, 2. Layout, 3. Gestures and alternate controls, 4. Current-page and progress stability, 5. Navigation target, 6. Delivery sequence, Acceptance and test matrix, `/api/Reader/file-dimensions` and chapter info (+38 more)

### Community 32 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (29): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+21 more)

### Community 33 - "patra_mark.dart"
Cohesion: 0.20
Nodes (9): build, color, height, paint, PatraMark, shouldRepaint, _wordBounds, patra_logo_paths.dart (+1 more)

### Community 34 - "List"
Cohesion: 0.13
Nodes (14): BookContentsEntry, BookContentsButton, build, _contentsIndent, _ContentsList, depth, entries, entry (+6 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "server_version_test.dart"
Cohesion: 0.11
Nodes (17): Completer, card, client, close, dot, _dotColor, fetch, held (+9 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "login_screen.dart"
Cohesion: 0.07
Nodes (28): ../../api/connection_failure.dart, ConsumerState, FormState, _askForServer, _buildForm, _busy, child, createState (+20 more)

### Community 39 - "package:flutter/material.dart"
Cohesion: 0.06
Nodes (36): CachedNetworkImage, LibraryType? libraryType,
  Locale, package:cached_network_image/cached_network_image.dart, package:flutter/material.dart, package:patra/src/features/reader/thumb_strip.dart, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/widgets/cover.dart, package:patra/src/widgets/cover_placeholder.dart (+28 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.09
Nodes (27): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, clearPendingProgress, copyWith, _disposed (+19 more)

### Community 41 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.22
Nodes (13): AuthState.atLaunch, reading_settings.dart / locale_settings.dart as device defaults, DeviceBiometrics (lib/src/lock/biometrics.dart), The language is the only preference written twice, localeProvider and languageEndonym, mockSecureStorage() in test_support.dart, PendingLink (a link waits for a profile), Profile lock (lib/src/lock/profile_lock.dart) (+5 more)

### Community 42 - "page_rail.dart"
Cohesion: 0.06
Nodes (32): bottomGap, build, controller, createState, dispose, _documentAt, _dragging, _dragPage (+24 more)

### Community 43 - "app.dart"
Cohesion: 0.05
Nodes (40): ../../branding/patra_launch.dart, double?, EdgeInsetsGeometry, features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart (+32 more)

### Community 44 - "reader_settings_sheet.dart"
Cohesion: 0.06
Nodes (30): direction_icon.dart, ../features/reader/reading_direction.dart, ../features/reader/strip_geometry.dart, _ActionRow, current, defaultValue, direction, _DirectionRows (+22 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.14
Nodes (14): package:patra/src/branding/patra_launch.dart, package:patra/src/features/launch/launch_animation.dart, static int, _app, build, createState, _Home, _HomeState (+6 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Directory, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

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
Cohesion: 0.11
Nodes (17): Container, CustomPaint, LoginResult, Opacity, package:patra/src/branding/patra_mark.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/widgets/dashed_border.dart, package:patra/src/widgets/patra_wordmark.dart (+9 more)

### Community 51 - "strip_geometry.dart"
Cohesion: 0.07
Nodes (29): IndexedWidgetBuilder, anchorAt, build, childCount, decodeWidthFor, estimateMaxScrollOffset, fraction, geometry (+21 more)

### Community 52 - "main.dart"
Cohesion: 0.07
Nodes (26): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+18 more)

### Community 53 - "session_scope.dart"
Cohesion: 0.10
Nodes (20): catalogue/catalogue_provider.dart, features/launch/launch_animation.dart, auth, build, child, _container, createState, dispose (+12 more)

### Community 54 - "LaunchAnimation"
Cohesion: 0.13
Nodes (17): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, The header draws the five-blade fan at 24pt, isLaunchProvider, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation, LaunchSlot registry (LaunchLogoSlot, LaunchWordmarkSlot) (+9 more)

### Community 55 - "auth_test.dart"
Cohesion: 0.10
Nodes (19): DioException get, package:patra/src/keychain.dart, accountId, apiKey, call, calls, color, _container (+11 more)

### Community 56 - "State"
Cohesion: 0.16
Nodes (19): PatraLaunch, _PatraLaunchState, BookPageBody, _BookPageBodyState, PageImage, _PageImageState, _BookView, _BookViewState (+11 more)

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "return"
Cohesion: 0.04
Nodes (60): dart:io, ImageCacheStore, Locale, package:patra/src/catalogue/catalogue_provider.dart, package:patra/src/catalogue/catalogue_store.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/downloads/image_cache_store.dart, package:patra/src/features/home/continue_hero.dart (+52 more)

### Community 59 - "server_reachability_test.dart"
Cohesion: 0.06
Nodes (31): package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/settings/settings_screen.dart, package:patra/src/settings/locale_settings.dart, _Adapter, client, close, fetch, main (+23 more)

### Community 60 - "reading_settings.dart"
Cohesion: 0.10
Nodes (20): bool get, leftToRight,
  rightToLeft,, defaultBookLineHeight, defaultBookTextSize, directionNamed, isRightToLeft, isVerticalScroll, _keychain (+12 more)

### Community 61 - "strip_width.dart"
Cohesion: 0.04
Nodes (50): Drag?, _anchor, build, _capture, child, _clampedBy, clampWidthFactor, controller (+42 more)

### Community 62 - "HttpClientAdapter"
Cohesion: 0.04
Nodes (47): DioExceptionType?, HttpClientAdapter, Object?, package:patra/src/api/connection_failure.dart, _BookAdapter, _AnswersThenHangs, _Adapter, body (+39 more)

### Community 63 - "_"
Cohesion: 0.10
Nodes (22): catalogue_overlay.dart, FutureProvider, _, CatalogueDeps, CatalogueRead, _deps, _fetch, into (+14 more)

### Community 64 - "strip_width_test.dart"
Cohesion: 0.04
Nodes (49): dart:typed_data, package:flutter/rendering.dart, package:patra/src/features/reader/strip_width.dart, RenderBox, RenderSliverMultiBoxAdaptor?, required double to,
  int, _aspectRatioFor, bottom (+41 more)

### Community 65 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.13
Nodes (13): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, No invite flow is shipped, Why, ADR-0005 — The catalogue is what the device remembers, and it is files (+5 more)

### Community 66 - "The per-profile catalogue"
Cohesion: 0.15
Nodes (16): The entry round trip is hidden by the launch animation, Cache-first overlay precedence rule, The per-profile catalogue, A cover is never pinned; the answer is a real placeholder, drift (rejected, but not for the usual reason), Files, not a database, hive_ce (the near-free alternative, rejected), isResolvedFailure means something new (+8 more)

### Community 67 - "book_page.dart"
Cohesion: 0.03
Nodes (78): BookPage, EdgeInsets, Iterable, anchor, at, _attribute, _attributeMatch, _attributeOf (+70 more)

### Community 68 - "patraAccent = progress/identity, patraOffline = downloads/offline"
Cohesion: 0.20
Nodes (12): patraAccent = progress/identity, patraOffline = downloads/offline, /api/Series/currently-reading does not mean what it says, Claude Design handoff (.claude/design/HANDOFF.md), featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), markChapterRead (mark-multiple-read / -unread), POST /api/Series/on-deck, readOverridesProvider (optimistic progress writes) (+4 more)

### Community 69 - "magnify_gesture.dart (one-finger drag magnifier)"
Cohesion: 0.19
Nodes (13): GET /api/Reader/chapter-info pageDimensions, magnify_gesture.dart (one-finger drag magnifier), Serialized progress posts and the last-page rule, The reader must never wrap itself in a LayoutBuilder, The reader's cog and reader_settings_sheet.dart, The system's chrome comes and goes with the reader's, ReadingDirection (verticalScroll is a direction, not a mode), _PagedView._reported must be set in initState, not by a late initialiser (+5 more)

### Community 70 - "profile_switch_test.dart"
Cohesion: 0.03
Nodes (64): NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/reader/reader_screen.dart, package:patra/src/routes.dart, package:patra/src/session_scope.dart, required Credential credential,
  ClientIdentity (+56 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 72 - "_ReaderScreenState"
Cohesion: 0.13
Nodes (22): libraryNameProvider, bookContentsProvider, _BookPage, bookPageProvider, build, _buildBookReader, _buildReader, chapterInfoProvider (+14 more)

### Community 73 - "cache_settings.dart"
Cohesion: 0.15
Nodes (15): int get, ../keychain.dart, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheSettingsProvider (+7 more)

### Community 74 - "home_hero_test.dart"
Cohesion: 0.06
Nodes (33): LibraryType, LibraryTypeNaming, NavigatorState, _backdrop, _chapter, client, close, fetch (+25 more)

### Community 75 - "ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it"
Cohesion: 0.20
Nodes (9): ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it, Consequences, Considered options, and why not, Context, Cost, accepted, Decision, Prototype, Sources (+1 more)

### Community 76 - "catalogue_provider.dart"
Cohesion: 0.13
Nodes (14): catalogue_store.dart, _storeOrNull, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, catalogueStoreProvider, _done, markStored (+6 more)

### Community 77 - "page_loading_test.dart"
Cohesion: 0.19
Nodes (12): Image, ImageInfo, ImageProvider, package:patra/src/features/reader/page_loading.dart, _Arrives, _drawn, loadImage, main (+4 more)

### Community 78 - "ConsumerWidget"
Cohesion: 0.08
Nodes (44): catalogue, ConsumerWidget, kavitaClientProvider, offlineProvider, chapterDirProvider, downloadsProvider, savedChapterProvider, _store (+36 more)

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

### Community 84 - "profile_lock_ui_test.dart"
Cohesion: 0.11
Nodes (18): package:patra/src/lock/biometrics.dart, _Adapter, call, client, close, entered, fetch, main (+10 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "Keychain"
Cohesion: 0.50
Nodes (4): Keychain, SecureKeychain, _NoKeychain, MemoryKeychain

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "book_reader_test.dart"
Cohesion: 0.05
Nodes (39): CachedNetworkImageProvider, MemoryImage, package:patra/src/features/reader/book_page.dart, ScrollableState, String? html,
  int, adapter, _addressedPicture, _answer (+31 more)

### Community 89 - "direction_icon.dart"
Cohesion: 0.20
Nodes (9): ReadingDirection, build, color, direction, DirectionIcon, paint, shouldRepaint, size (+1 more)

### Community 90 - "page_rail_test.dart"
Cohesion: 0.08
Nodes (23): , package:patra/src/features/reader/page_rail.dart, ScrollController, 8, _bottomGap, geometry, _Harness, _heightAt (+15 more)

### Community 91 - "Map"
Cohesion: 0.20
Nodes (19): OfflineNotifier, sessionProvider, PageShapesNotifier, ReadOverridesNotifier, ProfileLocksNotifier, profileLockStoreProvider, BookLineHeightNotifier, BookTextSizeNotifier (+11 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "dart:math"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 95 - "ADR-0008 — Kavita paginates a book; the app parses no EPUB"
Cohesion: 0.25
Nodes (7): ADR-0008 — Kavita paginates a book; the app parses no EPUB, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 96 - "Patra Frond Mark (five-blade master, 1024px)"
Cohesion: 0.40
Nodes (5): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed)

### Community 97 - "dart:convert"
Cohesion: 0.06
Nodes (28): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, PopupMenuItem, required bool admin,
  bool, _jwt (+20 more)

### Community 98 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 99 - "Android job: android/key.properties switch"
Cohesion: 0.33
Nodes (7): Android job: android/key.properties switch, Build number is github.run_number, ClientIdentity (app version read off the binary), iOS job: signed TestFlight path or unsigned IPA fallback, Play upload to the internal track, Releases are cut by a tag, not by a push, ios/Flutter/Release.xcconfig (Runner-target signing scope)

### Community 100 - "ConnectionFailure (connection_failure.dart)"
Cohesion: 0.14
Nodes (16): ConnectionFailureKind.blockedByBrowser, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), LibraryTypeNaming (lib/src/entity_naming.dart), The fixed French glossary, android.permission.INTERNET in the main manifest, Kavita (self-hosted server), _PatraShell._labelsFit (the bottom bar measures its labels) (+8 more)

### Community 101 - "A profile persists the auth key and nothing else"
Cohesion: 0.33
Nodes (7): apiKey is the opds auth key, one row not a concept, A profile persists the auth key and nothing else, Using the auth key as the request scheme (rejected alternative), LoginDto ignores username/password when ApiKey is passed, POST /api/Plugin/authenticate (rejected alternative), refresh-token on 0.9.0.x must not be leaned on, Token lifetimes are absent from the spec

### Community 102 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 103 - "strip_geometry_test.dart"
Cohesion: 0.08
Nodes (24): package:patra/src/features/reader/strip_geometry.dart, 8, controller, fraction, geometry, _heightAt, images, main (+16 more)

### Community 104 - "catalogue_overlay_test.dart"
Cohesion: 0.10
Nodes (19): package:patra/src/catalogue/catalogue_overlay.dart, adapter, _AnswersThenFails, calls, client, close, container, expectLater (+11 more)

### Community 105 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 106 - "UserDto.isAdmin (role read from the login response)"
Cohesion: 0.17
Nodes (15): Admin scan request from the Library tab's app-bar menu, AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, AsyncValue.isResolvedFailure, POST /api/Library/scan (admin only), LibraryScanNotifier (+7 more)

### Community 107 - "ADR-0004 — The auth key is the only secret a profile keeps"
Cohesion: 0.33
Nodes (6): ADR-0004 — The auth key is the only secret a profile keeps, Consequences, Context, Cost, accepted, Decision, Why

### Community 108 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 109 - "AppLocalizations"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 110 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.05
Nodes (40): delete, keychainProvider, read, readAll, _storage, write, package:flutter_riverpod/flutter_riverpod.dart, package:flutter_secure_storage/flutter_secure_storage.dart (+32 more)

### Community 112 - "profile_picker_screen.dart"
Cohesion: 0.06
Nodes (38): authProvider, profileCatalogueProvider, profileDownloadsProvider, _ProfileFace, LibraryScanNotifier, scan, build, initState (+30 more)

### Community 113 - "profile_avatar.dart"
Cohesion: 0.17
Nodes (11): ../api/kavita_client.dart, build, dimmed, hex, _Initial, on, profile, ProfileAvatar (+3 more)

### Community 114 - "DownloadsService (<documents>/downloads/<profile>/<chapterId>/)"
Cohesion: 0.22
Nodes (10): DownloadsNotifier must re-read state.value after an await, DownloadsService (<documents>/downloads/<profile>/<chapterId>/), ImageCacheStore.trim (a capped image cache), kavitaClientProvider, No migration into the profiles storage layout, Profile.id = (baseUrl, accountId), SessionScope (entering a profile rebuilds the whole app), ThumbLoadQueue (+2 more)

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
Cohesion: 0.20
Nodes (9): api/models.dart, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+1 more)

### Community 130 - "ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series"
Cohesion: 0.17
Nodes (11): A direction per library, shipped (#65), ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series, Amendment — 2026-09-13 (#56), Amendment — 2026-09-13 (#57), Amendment — 2026-09-13 (#58), Amendment — 2026-09-13 (#58, shipped), Amendment — 2026-09-13 (#65), Consequences (+3 more)

### Community 131 - "openapi_contract_test.dart"
Cohesion: 0.25
Nodes (7): File, main, resolve, schema, schemas, spec, specName

### Community 132 - "catalogue_overlay.dart"
Cohesion: 0.12
Nodes (17): catalogue_provider.dart, fetch, held, heldSpine, live, onDeckOverlay, _onDeckReadProvider, overlaid (+9 more)

### Community 133 - "reading_direction.dart"
Cohesion: 0.10
Nodes (19): canPromoteToLibrary, ChapterDirection, ChapterDirectionKey, detected, detectedDirectionProvider, direction, hasLibraryDirection, hasSeriesDirection (+11 more)

### Community 134 - "_ReaderSettings"
Cohesion: 0.67
Nodes (3): _BookSettings, _PictureSettings, _ReaderSettings

### Community 135 - "biometrics.dart"
Cohesion: 0.32
Nodes (7): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:local_auth/local_auth.dart, FakeBiometrics

### Community 136 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 137 - "downloads_provider_test.dart"
Cohesion: 0.10
Nodes (20): Future, adapter, _chapter, close, container, dir, fetch, gate (+12 more)

### Community 138 - "The Kavita API client"
Cohesion: 0.50
Nodes (3): Kavita API client — deliberately hand-written, Reaching the server: cleartext, and saying what went wrong, The Kavita API client

### Community 139 - "routes.dart"
Cohesion: 0.12
Nodes (15): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+7 more)

### Community 141 - "The reader"
Cohesion: 0.50
Nodes (3): A book, Reader, The reader

### Community 143 - "dart:async"
Cohesion: 0.14
Nodes (13): catalogue_read.dart, dart:async, Series, SeriesMetadata, libraries, libraryTypeProvider, list, onDeck (+5 more)

### Community 146 - "isTabletLayout(context)"
Cohesion: 0.47
Nodes (6): A column of rows runs the full width at the app's gutter, A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, isTabletLayout(context), A swipe pane and a button must never scale with the screen, _SqueezedByPane

### Community 147 - "series_offline_test.dart"
Cohesion: 0.10
Nodes (19): FilledButton, InkWell, package:patra/src/widgets/save_pill.dart, _chapter, _fillAll, main, _metadata, _profileId (+11 more)

### Community 151 - "entity_naming.dart"
Cohesion: 0.18
Nodes (10): chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, numberedChapterLabel, resumeTitle, specialsTitle, storylineTitle (+2 more)

### Community 152 - "locale_settings.dart"
Cohesion: 0.18
Nodes (10): _key, _keychain, languageEndonym, load, localeSettingsProvider, LocaleSettingsStore, null, save (+2 more)

### Community 153 - "static const"
Cohesion: 0.06
Nodes (34): ../auth/session.dart, ../branding/patra_lockup.dart, build, gapEm, PatraLockup, size, build, OfflineIndicator (+26 more)

### Community 155 - "dashed_border.dart"
Cohesion: 0.15
Nodes (12): Color, CustomPainter, _LaunchPainter, _MarkPainter, _Hatch, color, DashedBorderPainter, paint (+4 more)

### Community 156 - "ADR-0009 — A saved copy keeps the pagination it was made with"
Cohesion: 0.29
Nodes (6): ADR-0009 — A saved copy keeps the pagination it was made with, Consequence, Context, Cost, accepted, Decision, Why

### Community 157 - "cover.dart"
Cohesion: 0.12
Nodes (15): cover_placeholder.dart, build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress (+7 more)

### Community 158 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 159 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.06
Nodes (29): Finder get, IconButton, package:patra/src/api/kavita_client.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/resume_point.dart, _Adapter, close, _cloud (+21 more)

### Community 160 - "ADR-0010 — A book's page is drawn by the app, not handed to a web view"
Cohesion: 0.29
Nodes (6): ADR-0010 — A book's page is drawn by the app, not handed to a web view, Consequence, Context, Cost, accepted, Decision, Why

### Community 162 - "BookPicture"
Cohesion: 0.50
Nodes (5): BookBlock, BookPicture, BookWords, endBlock, parseBookPage

### Community 163 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 168 - "package:dio/dio.dart"
Cohesion: 0.05
Nodes (38): client_identity.dart, DioException, int?, kavita_client.dart, announceDevice, identity, null, renameTarget (+30 more)

### Community 170 - "reader_settings_sheet_test.dart"
Cohesion: 0.15
Nodes (15): DirectionPicked, DirectionPromotedToLibrary, LibraryDirectionCleared, ReaderSettingsOutcome, SeriesDirectionCleared, package:patra/src/widgets/reader_settings_sheet.dart, _builtIn, libraryName (+7 more)

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **2881 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+2876 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3134 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `KavitaClient (lib/src/api/kavita_client.dart)`, `profile_lock_sheet.dart`, `DownloadsService (<documents>/downloads/<profile>/<chapterId>/)`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `KavitaClient (lib/src/api/kavita_client.dart)` to `Profile lock (lib/src/lock/profile_lock.dart)`, `UserDto.isAdmin (role read from the login response)`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `api/models.dart`, `catalogue_overlay.dart`, `resume_point.dart`, `catalogue_provider.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `profile_avatar.dart`, `home_screen.dart`, `static const`, `return`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _2881 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.011695906432748537 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.012658227848101266 - nodes in this community are weakly interconnected._