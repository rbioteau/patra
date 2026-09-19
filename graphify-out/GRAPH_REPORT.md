# Graph Report - patra  (2026-09-19)

## Corpus Check
- 188 files · ~401,814 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4618 nodes · 6462 edges · 180 communities (157 shown, 19 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `72bf7e90`
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
- package:patra/src/theme.dart
- patra package manifest
- kavita_client.dart
- page_loading.dart
- settings_screen.dart
- measure_page_shapes.dart
- series_sections_test.dart
- series_detail_screen.dart
- _
- home_screen.dart
- auth_test.dart
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- static const
- series_list_views_test.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_launch.dart
- profile_lock.dart
- package:dio/dio.dart
- reader_test.dart
- Continuous vertical reader: zoom and navigation research
- magnify_gesture.dart
- client_identity_test.dart
- package:patra/src/api/kavita_client.dart
- analyze job (pub get, analyze, test)
- home_hero_test.dart
- my_application.cc
- test_support.dart
- _ReaderScreenState
- downloads_provider.dart
- Profile lock (lib/src/lock/profile_lock.dart)
- page_rail.dart
- app.dart
- reader_settings_sheet.dart
- launch_animation_test.dart
- image_cache_store.dart
- download_pill.dart
- catalogue_store.dart
- AppDelegate
- session_scope.dart
- strip_geometry.dart
- main.dart
- ConsumerWidget
- The profile picker (/profiles)
- patra_logo_paths.dart
- return
- graphify_merge_driver_test.dart
- continue_hero.dart
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
- deep_link_test.dart
- resume_point.dart
- downloads_provider_test.dart
- catalogue_write_path_test.dart
- series_offline_test.dart
- ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it
- entity_naming.dart
- page_backdrop.dart
- package:flutter/material.dart
- saved_copies_test.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- cover_placeholder.dart
- offline_reading_test.dart
- Compact three-blade frond variant (icons at or under 72px)
- _ProbeThumb
- 72px threshold: small icons render from the compact master
- dart:math
- A profile is exactly one Kavita account
- book_reader_test.dart
- dart:convert
- page_rail_test.dart
- Map
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- package:flutter_test/flutter_test.dart
- ADR-0008 — Kavita paginates a book; the app parses no EPUB
- Patra Frond Mark (five-blade master, 1024px)
- profile_avatar.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- offlineProvider
- ProfilePreferencesStore (profile_preferences.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- strip_geometry_test.dart
- package:flutter/foundation.dart
- Patra
- AsyncValue.isResolvedFailure
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- patra_mark.dart
- MainActivity.kt
- page_shape_test.dart
- connection_failure_test.dart
- login_screen.dart
- The graphify union merge driver (two halves)
- Issue tracker agent skill (GitHub issues via gh)
- Spread
- triage-labels.md
- downloads_screen.dart
- gen-l10n configuration (non-nullable getter)
- bool?
- ../../api/models.dart
- profile_files.dart
- Where a page stops being a page: the vertical threshold
- savedChapterProvider
- ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series
- State
- catalogue_overlay.dart
- reading_direction.dart
- keychain.dart
- AuthNotifier
- StripWidthController
- reader_settings_sheet_test.dart
- The Kavita API client
- routes.dart
- The catalogue
- The reader
- Preferences
- catalogue_reads.dart
- SKILL.md
- .github/CLAUDE.md
- cover.dart
- profile_picker_screen.dart
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- Widget
- reading_direction_test.dart
- ../../l10n/generated/app_localizations.dart
- ADR-0011 — A second theme is deferred, not rejected
- CLAUDE.md
- ADR-0009 — A saved copy keeps the pagination it was made with
- catalogue_provider.dart
- _ThumbStripState
- StatelessWidget
- ADR-0010 — A book's page is drawn by the app, not handed to a web view
- page_loading_test.dart
- BookPicture
- Credential
- UserDto.isAdmin (role read from the login response)
- gen_app_icons.sh
- entity_naming_test.dart
- DownloadsNotifier
- downloads_service_test.dart
- BookPageBody
- VoidCallback
- downloads_resume_strip_test.dart
- image_cache_store_test.dart
- ../../auth/session.dart
- package:flutter/widgets.dart
- ../theme.dart
- package:flutter_riverpod/flutter_riverpod.dart
- @immutable
- CustomPainter
- SignInExpired

## God Nodes (most connected - your core abstractions)
1. `_` - 67 edges
2. `_` - 32 edges
3. `downloadsProvider` - 21 edges
4. `_ReaderScreenState` - 16 edges
5. `kavitaClientProvider` - 16 edges
6. `DownloadsNotifier` - 15 edges
7. `authProvider` - 15 edges
8. `build` - 15 edges
9. `sessionProvider` - 15 edges
10. `Continuous vertical reader: zoom and navigation research` - 13 edges

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

## Communities (180 total, 19 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (221): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+213 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (208): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+200 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (208): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+200 more)

### Community 3 - "thumb_strip.dart"
Cohesion: 0.02
Nodes (86): Animation, Duration, _accordion, _backfillConcurrent, _baseShare, _baseWidth, build, _centre (+78 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.02
Nodes (113): book_contents.dart, book_page.dart, anchor, _anchorFor, _anchors, aspectRatios, barHeight, BookPageKey (+105 more)

### Community 5 - "models.dart"
Cohesion: 0.02
Nodes (90): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, BookInfo, bookScrollId (+82 more)

### Community 6 - "session.dart"
Cohesion: 0.04
Nodes (55): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+47 more)

### Community 7 - "theme.dart"
Cohesion: 0.03
Nodes (61): base, body, build, color, colors, _controller, controlMaxWidth, copyWith (+53 more)

### Community 8 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.16
Nodes (16): ConnectionFailureKind.blockedByBrowser, ChapterDto.sortOrder is the reading order, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), The Kavita client is deliberately hand-written, android.permission.INTERNET in the main manifest, KavitaClient (lib/src/api/kavita_client.dart), Kavita (self-hosted server) (+8 more)

### Community 9 - "package:patra/src/theme.dart"
Cohesion: 0.07
Nodes (25): ColoredBox, FractionallySizedBox, package:patra/src/features/settings/settings_screen.dart, package:patra/src/theme.dart, package:patra/src/widgets/read_mark.dart, _Adapter, client, close (+17 more)

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
Cohesion: 0.06
Nodes (43): ../../downloads/image_cache_store.dart, didChangeAppLifecycleState, serverReachableProvider, serverVersionProvider, imageCacheSizeProvider, imageCacheStoreProvider, actionLabel, _avatarSize (+35 more)

### Community 14 - "measure_page_shapes.dart"
Cohesion: 0.04
Nodes (45): HttpClient, _Api, apiKey, base, buffer, chapterInfo, chapters, _client (+37 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.06
Nodes (31): int? stoppedChapter,
  bool, LibraryType, build, cacheDir, _chapter, client, close, delegates (+23 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.04
Nodes (55): bool?, Chapter, boxInset, _Buckets, chapter, ChapterSort, child, clear (+47 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (40): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+32 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.07
Nodes (29): continue_hero.dart, ../downloads/resume_strip.dart, Library, _cardMaxWidth, _cardSpacing, _cardWidth, columns, continueHeroProvider (+21 more)

### Community 19 - "auth_test.dart"
Cohesion: 0.10
Nodes (19): DioException get, package:patra/src/keychain.dart, accountId, apiKey, call, calls, color, _container (+11 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.03
Nodes (64): abstract class, batchDownloadSizeFor, bookLineHeight, bookLineHeightFor, bookReadingFace, bookReadingFaceFor, bookTextSize, bookTextSizeFor (+56 more)

### Community 21 - "test_support.dart"
Cohesion: 0.04
Nodes (55): MangaFormat, MemoryKeychain? keychain,
  bool, required int chapterId,
  String, available, bytes, catalogueVolumesFixture, channel, chapter (+47 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.06
Nodes (35): appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey, deviceModel (+27 more)

### Community 23 - "static const"
Cohesion: 0.12
Nodes (14): ../keychain.dart, build, gapEm, PatraLockup, size, batchSizeHintProvider, BatchSizeHintStore, _key (+6 more)

### Community 24 - "series_list_views_test.dart"
Cohesion: 0.07
Nodes (29): LinearProgressIndicator, package:flutter/rendering.dart, RenderParagraph, ScaffoldMessengerState, above, cacheDir, _chapter, client (+21 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (31): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+23 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.02
Nodes (83): ChapterContent get, ../features/reader/book_page.dart, _adoptUncommittedPages, _ambiguousQueue, batchId, bookScrollId, bytes, _carryPicture (+75 more)

### Community 27 - "patra_launch.dart"
Cohesion: 0.06
Nodes (31): AnimationController, build, child, _controller, createState, didChangeDependencies, didUpdateWidget, dispose (+23 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.07
Nodes (27): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+19 more)

### Community 29 - "package:dio/dio.dart"
Cohesion: 0.06
Nodes (31): client_identity.dart, Finder get, IconButton, kavita_client.dart, announceDevice, identity, null, renameTarget (+23 more)

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

### Community 33 - "client_identity_test.dart"
Cohesion: 0.09
Nodes (21): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, delete, _device, _DeviceAdapter (+13 more)

### Community 34 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.05
Nodes (41): CachedNetworkImage, LibraryType? libraryType,
  Locale, package:cached_network_image/cached_network_image.dart, package:patra/src/api/kavita_client.dart, package:patra/src/resume_point.dart, package:patra/src/widgets/cover.dart, package:patra/src/widgets/cover_placeholder.dart, _channelGap (+33 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "home_hero_test.dart"
Cohesion: 0.06
Nodes (31): NavigatorState, _backdrop, _chapter, client, close, fetch, _finishedBookVolume, _iPad (+23 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "test_support.dart"
Cohesion: 0.06
Nodes (35): package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/library/library_screen.dart, package:patra/src/settings/locale_settings.dart, _Adapter, client, close, fetch, main (+27 more)

### Community 39 - "_ReaderScreenState"
Cohesion: 0.13
Nodes (24): libraryNameProvider, bookContentsProvider, _BookPage, bookPageProvider, build, _buildBookReader, _buildReader, chapterInfoProvider (+16 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.03
Nodes (71): downloads_service.dart, _answerLaunchPrompt, _asked, _asking, awaitingResume, batchSummary, bySeries, _bySeriesThenTitle (+63 more)

### Community 41 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.22
Nodes (13): ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), Credential (sealed password-or-authKey type), DeviceBiometrics (lib/src/lock/biometrics.dart), Domain docs (single-context CONTEXT.md and docs/adr/), imageCacheKey (one cover fetched once per household), The lock's copy refuses the sentence it would be easiest to write (+5 more)

### Community 42 - "page_rail.dart"
Cohesion: 0.06
Nodes (32): bottomGap, build, controller, createState, dispose, _documentAt, _dragging, _dragPage (+24 more)

### Community 43 - "app.dart"
Cohesion: 0.07
Nodes (33): ConsumerState, ConsumerStatefulWidget, features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart (+25 more)

### Community 44 - "reader_settings_sheet.dart"
Cohesion: 0.06
Nodes (39): direction_icon.dart, ../features/reader/reading_direction.dart, ../features/reader/strip_geometry.dart, _ActionRow, current, defaultValue, direction, DirectionPicked (+31 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.14
Nodes (14): package:patra/src/branding/patra_launch.dart, package:patra/src/features/launch/launch_animation.dart, static int, _app, build, createState, _Home, _HomeState (+6 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 47 - "download_pill.dart"
Cohesion: 0.07
Nodes (29): Color, download_stop.dart, ../downloads/downloads_service.dart, IconData, SavedChapter, color, paint, radius (+21 more)

### Community 48 - "catalogue_store.dart"
Cohesion: 0.05
Nodes (40): _catalogueRoot, _deleteSeries, dirNameFor, _file, fromJson, isEmpty, libraries, loadOnDeck (+32 more)

### Community 49 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "session_scope.dart"
Cohesion: 0.05
Nodes (43): catalogue/catalogue_provider.dart, ../features/launch/launch_animation.dart, int get, firstOf, indexOf, length, of, _slotOfPage (+35 more)

### Community 51 - "strip_geometry.dart"
Cohesion: 0.06
Nodes (30): double get, IndexedWidgetBuilder, anchorAt, build, childCount, decodeWidthFor, estimateMaxScrollOffset, fraction (+22 more)

### Community 52 - "main.dart"
Cohesion: 0.07
Nodes (26): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+18 more)

### Community 53 - "ConsumerWidget"
Cohesion: 0.11
Nodes (24): batchSizeHintProvider, ConsumerWidget, ../downloads/downloads_provider.dart, didUpdateWidget, downloadRecordProvider, downloadsProvider, _CopyRow, DownloadsScreen (+16 more)

### Community 54 - "The profile picker (/profiles)"
Cohesion: 0.17
Nodes (13): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation, LaunchSlot registry (LaunchLogoSlot, LaunchWordmarkSlot), The outro adapts to the screen it lands on, not to a flag, Blades are turned like pages, not grown in place (+5 more)

### Community 55 - "patra_logo_paths.dart"
Cohesion: 0.17
Nodes (11): dart:ui, leaf1, leaf2, markHeight, markWidth, PatraLogoPaths, splitX, wordmark (+3 more)

### Community 56 - "return"
Cohesion: 0.03
Nodes (64): dart:io, File, Locale, package:patra/src/catalogue/catalogue_provider.dart, package:patra/src/catalogue/catalogue_store.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/features/home/continue_hero.dart, package:patra/src/widgets/offline_indicator.dart (+56 more)

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "continue_hero.dart"
Cohesion: 0.11
Nodes (18): ../../catalogue/catalogue_reads.dart, ../../entity_naming.dart, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+10 more)

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
Nodes (54): DioException, HttpClientAdapter, package:patra/src/catalogue/catalogue_overlay.dart, _BookAdapter, adapter, _AnswersThenFails, _AnswersThenHangs, calls (+46 more)

### Community 63 - "_"
Cohesion: 0.10
Nodes (23): AsyncValue, FutureProvider, ResolvedFailure, _, CatalogueDeps, CatalogueRead, _deps, _fetch (+15 more)

### Community 64 - "strip_width_test.dart"
Cohesion: 0.04
Nodes (46): dart:typed_data, package:patra/src/features/reader/strip_width.dart, RenderBox, RenderSliverMultiBoxAdaptor?, required double to,
  int, _aspectRatioFor, bottom, _brokenImage (+38 more)

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

### Community 70 - "deep_link_test.dart"
Cohesion: 0.06
Nodes (32): AuthState, NavigationBar, package:patra/src/app.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/routes.dart, required Directory downloadsRoot,
  bool, _app (+24 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.10
Nodes (21): bySortOrder, entries, entryCoverUrl, entryPictured, entryUnderWay, inVolumes, isWholeVolume, loose (+13 more)

### Community 72 - "downloads_provider_test.dart"
Cohesion: 0.05
Nodes (40): package:patra/src/lifecycle.dart, Profile? session,
  bool, active, activeChapterRequests, adapter, _chapter, chapterGates, _chapterWithId (+32 more)

### Community 73 - "catalogue_write_path_test.dart"
Cohesion: 0.11
Nodes (18): package:patra/src/catalogue/catalogue_reads.dart, package:patra/src/session_scope.dart, asked, client, close, container, fetch, _lea (+10 more)

### Community 74 - "series_offline_test.dart"
Cohesion: 0.10
Nodes (19): FilledButton, InkWell, package:patra/src/widgets/download_pill.dart, _chapter, _fillAll, main, _metadata, _profileId (+11 more)

### Community 75 - "ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it"
Cohesion: 0.20
Nodes (9): ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it, Consequences, Considered options, and why not, Context, Cost, accepted, Decision, Prototype, Sources (+1 more)

### Community 76 - "entity_naming.dart"
Cohesion: 0.12
Nodes (16): LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel, numberedChapterRange (+8 more)

### Community 77 - "page_backdrop.dart"
Cohesion: 0.10
Nodes (24): catalogue, kavitaClientProvider, build, ContinueHero, _Details, build, _Shelf, _ShelfTile (+16 more)

### Community 78 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (41): Completer, dart:async, package:flutter/material.dart, package:patra/src/features/reader/thumb_strip.dart, PopupMenuItem, required bool admin,
  bool, client, close (+33 more)

### Community 79 - "saved_copies_test.dart"
Cohesion: 0.05
Nodes (39): CircularProgressIndicator, CoverImage, package:patra/src/features/downloads/downloads_screen.dart, RichText, _answer, build, chapter, _chapterId (+31 more)

### Community 80 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "cover_placeholder.dart"
Cohesion: 0.09
Nodes (21): _apart, _bandFor, _brighter, build, choice, CoverPlaceholder, coverPlaceholderTones, _dimmest (+13 more)

### Community 82 - "offline_reading_test.dart"
Cohesion: 0.11
Nodes (18): package:patra/src/features/reader/reader_screen.dart, _app, attempts, close, fetch, identity, _lea, main (+10 more)

### Community 83 - "Compact three-blade frond variant (icons at or under 72px)"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "dart:math"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "book_reader_test.dart"
Cohesion: 0.04
Nodes (45): CachedNetworkImageProvider, MemoryImage, package:patra/src/features/reader/book_page.dart, ScrollableState, String? html,
  int, adapter, _addressedPicture, _answer (+37 more)

### Community 89 - "dart:convert"
Cohesion: 0.07
Nodes (26): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, required Credential credential,
  ClientIdentity, _jwt, main (+18 more)

### Community 90 - "page_rail_test.dart"
Cohesion: 0.08
Nodes (23): package:patra/src/features/reader/page_rail.dart, package:patra/src/features/reader/strip_geometry.dart, ScrollController, 8, _bottomGap, geometry, _Harness, _heightAt (+15 more)

### Community 91 - "Map"
Cohesion: 0.20
Nodes (20): OfflineNotifier, sessionProvider, PageShapesNotifier, ReadOverridesNotifier, BatchDownloadSize, BatchDownloadSizeNotifier, BookLineHeightNotifier, BookReadingFaceNotifier (+12 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (56): CustomPaint, LoginResult, Opacity, package:flutter_test/flutter_test.dart, package:patra/src/api/client_identity.dart, package:patra/src/api/models.dart, package:patra/src/auth/session.dart, package:patra/src/branding/patra_mark.dart (+48 more)

### Community 95 - "ADR-0008 — Kavita paginates a book; the app parses no EPUB"
Cohesion: 0.25
Nodes (7): ADR-0008 — Kavita paginates a book; the app parses no EPUB, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 96 - "Patra Frond Mark (five-blade master, 1024px)"
Cohesion: 0.40
Nodes (5): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed)

### Community 97 - "profile_avatar.dart"
Cohesion: 0.14
Nodes (13): ../../api/kavita_client.dart, Profile, Session, build, dimmed, hex, _Initial, on (+5 more)

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

### Community 104 - "package:flutter/foundation.dart"
Cohesion: 0.40
Nodes (4): _registered, registerPatraFontLicenses, package:flutter/foundation.dart, package:flutter/services.dart

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

### Community 110 - "patra_mark.dart"
Cohesion: 0.20
Nodes (9): build, color, height, paint, PatraMark, shouldRepaint, _wordBounds, patra_logo_paths.dart (+1 more)

### Community 112 - "page_shape_test.dart"
Cohesion: 0.13
Nodes (14): package:patra/src/features/reader/page_shape.dart, Set, _chapter, container, libraryType, main, _measured, _page (+6 more)

### Community 113 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 114 - "login_screen.dart"
Cohesion: 0.07
Nodes (27): ../../api/connection_failure.dart, FormState, _askForServer, _buildForm, _busy, child, createState, didChangeDependencies (+19 more)

### Community 119 - "downloads_screen.dart"
Cohesion: 0.09
Nodes (22): ../../format.dart, savedChapterIdsProvider, bytes, chapter, chapterId, chapters, color, _confirmRemove (+14 more)

### Community 126 - "../../api/models.dart"
Cohesion: 0.15
Nodes (12): ../../api/models.dart, build, isVertical, libraryType, measuredPagesNeeded, _median, middle, of (+4 more)

### Community 128 - "Where a page stops being a page: the vertical threshold"
Cohesion: 0.15
Nodes (12): A second library, one anybody can re-run: Kavita's public demo, How to re-run it, Sources, The answer, The measurement — one real library, The question, What #57 implements, What is still thin (+4 more)

### Community 129 - "savedChapterProvider"
Cohesion: 0.12
Nodes (27): batchDownloadSizeProvider, kavitaClientProvider, batchSummaryProvider, chapterDirProvider, downloadMembershipProvider, _run, savedChapterProvider, syncPendingProgress (+19 more)

### Community 130 - "ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series"
Cohesion: 0.17
Nodes (11): A direction per library, shipped (#65), ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series, Amendment — 2026-09-13 (#56), Amendment — 2026-09-13 (#57), Amendment — 2026-09-13 (#58), Amendment — 2026-09-13 (#58, shipped), Amendment — 2026-09-13 (#65), Consequences (+3 more)

### Community 131 - "State"
Cohesion: 0.14
Nodes (20): PatraLaunch, _PatraLaunchState, PageImage, _PageImageState, _BookView, _BookViewState, _MagnifyPage, _MagnifyPageState (+12 more)

### Community 132 - "catalogue_overlay.dart"
Cohesion: 0.12
Nodes (17): catalogue_provider.dart, fetch, held, heldSpine, live, onDeckOverlay, _onDeckReadProvider, overlaid (+9 more)

### Community 133 - "reading_direction.dart"
Cohesion: 0.07
Nodes (29): bool get, canPromoteToLibrary, ChapterDirection, ChapterDirectionKey, detected, detectedDirectionProvider, direction, hasLibraryDirection (+21 more)

### Community 134 - "keychain.dart"
Cohesion: 0.18
Nodes (11): delete, Keychain, keychainProvider, read, readAll, SecureKeychain, _storage, write (+3 more)

### Community 135 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 137 - "reader_settings_sheet_test.dart"
Cohesion: 0.17
Nodes (11): package:patra/src/features/reader/reading_direction.dart, package:patra/src/widgets/reader_settings_sheet.dart, _builtIn, libraryName, main, _openBookSheet, _openSheet, outcomes (+3 more)

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

### Community 146 - "cover.dart"
Cohesion: 0.13
Nodes (14): cover_placeholder.dart, build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress (+6 more)

### Community 147 - "profile_picker_screen.dart"
Cohesion: 0.06
Nodes (38): authProvider, profileCatalogueProvider, profileDownloadsProvider, _ProfileFace, LibraryScanNotifier, scan, build, initState (+30 more)

### Community 151 - "Widget"
Cohesion: 0.27
Nodes (9): ../../branding/patra_launch.dart, build, child, createState, isLaunchProvider, LaunchAnimation, _LaunchAnimationState, play (+1 more)

### Community 152 - "reading_direction_test.dart"
Cohesion: 0.20
Nodes (9): package:patra/src/settings/profile_preferences.dart, package:patra/src/settings/reading_settings.dart, Profile? active,
  Map, container, detected, _lea, main, _romain (+1 more)

### Community 153 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.08
Nodes (22): ../../l10n/generated/app_localizations.dart, ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message (+14 more)

### Community 154 - "ADR-0011 — A second theme is deferred, not rejected"
Cohesion: 0.25
Nodes (7): ADR-0011 — A second theme is deferred, not rejected, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 155 - "CLAUDE.md"
Cohesion: 0.11
Nodes (17): Agent skills, Architecture, CLAUDE.md, Commands, Design system — the brand kit is the source of truth, Domain docs, graphify, Issue tracker (+9 more)

### Community 156 - "ADR-0009 — A saved copy keeps the pagination it was made with"
Cohesion: 0.29
Nodes (6): ADR-0009 — A saved copy keeps the pagination it was made with, Consequence, Context, Cost, accepted, Decision, Why

### Community 157 - "catalogue_provider.dart"
Cohesion: 0.13
Nodes (14): catalogue_store.dart, _storeOrNull, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, catalogueStoreProvider, _done, markStored (+6 more)

### Community 158 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 159 - "StatelessWidget"
Cohesion: 0.06
Nodes (36): BookContentsEntry, _LibraryGridSkeleton, BookContentsButton, build, _contentsIndent, _ContentsList, depth, entries (+28 more)

### Community 160 - "ADR-0010 — A book's page is drawn by the app, not handed to a web view"
Cohesion: 0.29
Nodes (6): ADR-0010 — A book's page is drawn by the app, not handed to a web view, Consequence, Context, Cost, accepted, Decision, Why

### Community 161 - "page_loading_test.dart"
Cohesion: 0.19
Nodes (12): Image, ImageInfo, ImageProvider, package:patra/src/features/reader/page_loading.dart, _Arrives, _drawn, loadImage, main (+4 more)

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

### Community 166 - "entity_naming_test.dart"
Cohesion: 0.25
Nodes (7): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main

### Community 167 - "DownloadsNotifier"
Cohesion: 0.18
Nodes (14): appLifecycleProvider, AsyncNotifier, isLaunchProvider, build, DownloadsNotifier, downloadsServiceProvider, DownloadsState, _resumePaused (+6 more)

### Community 168 - "downloads_service_test.dart"
Cohesion: 0.08
Nodes (24): int?, DownloadsService, SelectedLibraryNotifier, _book, _bookId, _bookPageHtml, _chapter, client (+16 more)

### Community 170 - "VoidCallback"
Cohesion: 0.18
Nodes (10): double?, EdgeInsetsGeometry, build, child, ChromePill, onTap, padding, tooltip (+2 more)

### Community 171 - "downloads_resume_strip_test.dart"
Cohesion: 0.12
Nodes (16): package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/downloads/resume_strip.dart, _chapter, client, close, container, fetch, _interruptedRoom (+8 more)

### Community 172 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 173 - "../../auth/session.dart"
Cohesion: 0.33
Nodes (6): ../../auth/session.dart, offlineProvider, _ErrorState, build, OfflineIndicator, pumpWidget

### Community 174 - "package:flutter/widgets.dart"
Cohesion: 0.33
Nodes (5): AppLifecycleState, AppLifecycleNotifier, build, report, package:flutter/widgets.dart

### Community 175 - "../theme.dart"
Cohesion: 0.13
Nodes (13): ../branding/patra_lockup.dart, build, _gateGapEm, PatraMasthead, showTagline, _size, build, dotScale (+5 more)

### Community 176 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.12
Nodes (17): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, _key, _keychain, languageEndonym (+9 more)

### Community 177 - "@immutable"
Cohesion: 0.50
Nodes (4): @immutable, BookAnchor, MagnifyGesture, MagnifyTransform

### Community 178 - "CustomPainter"
Cohesion: 0.33
Nodes (6): CustomPainter, _LaunchPainter, _MarkPainter, _Hatch, DashedBorderPainter, _DirectionPainter

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **3323 isolated node(s):** `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales`, `appTagline` (+3318 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3596 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `ProfilePreferencesStore (profile_preferences.dart)`, `patraAccent = progress/identity, patraOffline = downloads/offline`, `AsyncValue.isResolvedFailure`, `The profile picker (/profiles)`, `profile_lock_sheet.dart`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `UserDto.isAdmin (role read from the login response)`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `ProfilePreferencesStore (profile_preferences.dart)` connect `ProfilePreferencesStore (profile_preferences.dart)` to `Profile lock (lib/src/lock/profile_lock.dart)`, `AsyncValue.isResolvedFailure`, `DownloadsService (<documents>/downloads/<profile>/<chapterId>/)`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `localeName`, `delegate`, `localizationsDelegates` to the rest of the system?**
  _3323 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009009009009009009 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009569377990430622 - nodes in this community are weakly interconnected._