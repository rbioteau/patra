# Graph Report - patra  (2026-09-20)

## Corpus Check
- 203 files · ~453,411 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4958 nodes · 6926 edges · 194 communities (168 shown, 22 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7c98183e`
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
- book_face.dart
- patra package manifest
- kavita_client.dart
- page_loading.dart
- app.dart
- measure_page_shapes.dart
- series_sections_test.dart
- series_detail_screen.dart
- _
- home_screen.dart
- client_identity_test.dart
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- package:flutter_test/flutter_test.dart
- series_list_views_test.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_launch.dart
- profile_lock.dart
- profile_switch_test.dart
- reader_test.dart
- Continuous vertical reader: zoom and navigation research
- magnify_gesture.dart
- auth_test.dart
- home_hero_test.dart
- analyze job (pub get, analyze, test)
- saved_chapters_per_profile_test.dart
- my_application.cc
- test_support.dart
- _ReaderScreenState
- downloads_provider.dart
- Profile lock (lib/src/lock/profile_lock.dart)
- page_rail.dart
- package:flutter/material.dart
- reader_settings_sheet.dart
- launch_animation_test.dart
- image_cache_store.dart
- download_pill.dart
- catalogue_store.dart
- AppDelegate
- session_scope.dart
- strip_geometry.dart
- main.dart
- settings_screen.dart
- The profile picker (/profiles)
- patra_logo_paths.dart
- package:flutter/widgets.dart
- graphify_merge_driver_test.dart
- series_offline_test.dart
- Map
- reading_settings.dart
- strip_width.dart
- dart:convert
- _
- strip_width_test.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- The per-profile catalogue
- book_page.dart
- patraAccent = progress/identity, patraOffline = downloads/offline
- DownloadsService (<documents>/downloads/<profile>/<chapterId>/)
- page_shape.dart
- resume_point.dart
- downloads_provider_test.dart
- store_screenshots_test.dart
- ConsumerWidget
- ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it
- Hyphenating a book's prose: where the breaks come from, and who draws the mark
- package:flutter_riverpod/flutter_riverpod.dart
- demo_server.dart
- saved_copies_test.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- cover_placeholder.dart
- gen_web_mark.dart
- Compact three-blade frond variant (icons at or under 72px)
- profile_picker_screen.dart
- 72px threshold: small icons render from the compact master
- magnify_gesture_test.dart
- A profile is exactly one Kavita account
- book_reader_test.dart
- patra_mark.dart
- page_rail_test.dart
- sessionProvider
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- package:patra/src/auth/session.dart
- ADR-0008 — Kavita paginates a book; the app parses no EPUB
- Patra Frond Mark (five-blade master, 1024px)
- ../../../l10n/generated/app_localizations.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- offlineProvider
- ProfilePreferencesStore (profile_preferences.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- strip_geometry_test.dart
- patra_signature.dart
- Patra
- offline_reading_test.dart
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- connection_failure_test.dart
- MainActivity.kt
- page_shape_test.dart
- library_scan_test.dart
- ConsumerState
- The graphify union merge driver (two halves)
- Issue tracker agent skill (GitHub issues via gh)
- Spread
- triage-labels.md
- downloads_screen.dart
- gen-l10n configuration (non-nullable getter)
- bool?
- package:patra/src/api/kavita_client.dart
- profile_files.dart
- Where a page stops being a page: the vertical threshold
- deep_link_test.dart
- ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series
- State
- catalogue_overlay.dart
- reading_direction.dart
- HttpClientAdapter
- keychain.dart
- direction_icon.dart
- login_screen.dart
- The Kavita API client
- routes.dart
- The catalogue
- book-hyphenation.md
- Preferences
- catalogue_reads.dart
- SKILL.md
- .github/CLAUDE.md
- home_offline_test.dart
- AuthNotifier
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- AsyncValue.isResolvedFailure
- ../api/models.dart
- CustomPainter
- ADR-0011 — A second theme is deferred, not rejected
- CLAUDE.md
- ADR-0009 — A saved copy keeps the pagination it was made with
- catalogue_provider.dart
- reader_settings_sheet_test.dart
- package:dio/dio.dart
- ADR-0010 — A book's page is drawn by the app, not handed to a web view
- package:flutter/foundation.dart
- BookPicture
- ../theme.dart
- external_links.dart
- gen_app_icons.sh
- cover.dart
- cache_settings.dart
- downloads_service_test.dart
- dart:math
- List
- DownloadsNotifier
- image_cache_store_test.dart
- launch_animation.dart
- @immutable
- openapi_contract_test.dart
- The three routes, judged
- package:patra/src/settings/reading_settings.dart
- static const
- UserDto.isAdmin (role read from the login response)
- page_loading_test.dart
- _ReaderSettings
- StripWidthController
- int?
- _ProbeThumb
- locale_settings.dart
- What the two store listings take
- ADR-0012 — A book is set in the face the book asks for
- store_screenshots.sh
- Credential
- ProfilePreferencesStore
- _StripState
- gen_demo_library.sh
- _ThumbStripState

## God Nodes (most connected - your core abstractions)
1. `_` - 67 edges
2. `_` - 32 edges
3. `kavitaClientProvider` - 24 edges
4. `offlineProvider` - 23 edges
5. `downloadsProvider` - 21 edges
6. `sessionProvider` - 18 edges
7. `_ReaderScreenState` - 16 edges
8. `authProvider` - 15 edges
9. `DownloadsNotifier` - 15 edges
10. `build` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Server version` --semantically_similar_to--> `pubspec version is only a local fallback`  [INFERRED] [semantically similar]
  CONTEXT.md → pubspec.yaml
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/home_offline_test.dart → lib/src/auth/session.dart
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/series_offline_test.dart → lib/src/auth/session.dart
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml

## Import Cycles
- None detected.

## Communities (194 total, 22 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (218): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+210 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (205): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+197 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (205): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+197 more)

### Community 3 - "thumb_strip.dart"
Cohesion: 0.02
Nodes (86): Animation, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth, build, _centre (+78 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.02
Nodes (115): book_contents.dart, anchor, _anchorFor, _anchors, aspectRatios, barHeight, bookFamily, BookPageKey (+107 more)

### Community 5 - "models.dart"
Cohesion: 0.02
Nodes (91): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, BookInfo, bookScrollId (+83 more)

### Community 6 - "session.dart"
Cohesion: 0.04
Nodes (54): ../api/account_id.dart, ../api/client_device.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted, apiKey (+46 more)

### Community 7 - "theme.dart"
Cohesion: 0.03
Nodes (60): base, body, build, color, colors, _controller, controlMaxWidth, copyWith (+52 more)

### Community 8 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.16
Nodes (16): ConnectionFailureKind.blockedByBrowser, ChapterDto.sortOrder is the reading order, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), The Kavita client is deliberately hand-written, android.permission.INTERNET in the main manifest, KavitaClient (lib/src/api/kavita_client.dart), Kavita (self-hosted server) (+8 more)

### Community 9 - "book_face.dart"
Cohesion: 0.03
Nodes (67): book_page.dart, _atRule, BookFont, BookFontFile, BookFontsKey, bookStyleSheets, build, cache (+59 more)

### Community 10 - "patra package manifest"
Cohesion: 0.05
Nodes (50): Dependabot pub ecosystem (weekly), Administrator, Auth key, Avatar, Catalogue, Chapter, Continue (the promotion), Credential (+42 more)

### Community 11 - "kavita_client.dart"
Cohesion: 0.04
Nodes (56): Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient, baseUrl (+48 more)

### Community 12 - "page_loading.dart"
Cohesion: 0.10
Nodes (21): AlignmentGeometry, BoxFit, alignment, build, createState, dispose, explain, explainAfter (+13 more)

### Community 13 - "app.dart"
Cohesion: 0.08
Nodes (27): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+19 more)

### Community 14 - "measure_page_shapes.dart"
Cohesion: 0.04
Nodes (45): HttpClient, _Api, apiKey, base, buffer, chapterInfo, chapters, _client (+37 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.06
Nodes (30): int? stoppedChapter,
  bool, build, cacheDir, _chapter, client, close, delegates, fetch (+22 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.04
Nodes (51): Chapter, ../../entity_naming.dart, _BatchCard, boxInset, _Buckets, chapter, ChapterSort, child (+43 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (38): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+30 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.04
Nodes (52): AsyncValue, ../catalogue/catalogue_reads.dart, continue_hero.dart, cover.dart, ../downloads/resume_strip.dart, Library, ResolvedFailure, best (+44 more)

### Community 19 - "client_identity_test.dart"
Cohesion: 0.09
Nodes (21): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, delete, _device, _DeviceAdapter (+13 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.03
Nodes (62): abstract class, batchDownloadSizeFor, bookLineHeight, bookLineHeightFor, bookReadingFace, bookReadingFaceFor, bookTextSize, bookTextSizeFor (+54 more)

### Community 21 - "test_support.dart"
Cohesion: 0.03
Nodes (59): MemoryKeychain? keychain,
  bool, required int chapterId,
  String, available, bytes, card, catalogueVolumesFixture, channel, chapter (+51 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.05
Nodes (36): appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey, deviceModel (+28 more)

### Community 23 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.03
Nodes (69): dart:io, package:flutter_test/flutter_test.dart, package:integration_test/integration_test_driver_extended.dart, package:patra/src/api/models.dart, package:patra/src/catalogue/catalogue_overlay.dart, package:patra/src/catalogue/catalogue_provider.dart, package:patra/src/catalogue/catalogue_reads.dart, package:patra/src/catalogue/catalogue_store.dart (+61 more)

### Community 24 - "series_list_views_test.dart"
Cohesion: 0.06
Nodes (34): ColoredBox, FractionallySizedBox, LinearProgressIndicator, package:flutter/rendering.dart, package:patra/src/theme.dart, package:patra/src/widgets/read_mark.dart, RenderParagraph, ScaffoldMessengerState (+26 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (31): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+23 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.02
Nodes (84): ChapterContent get, ../features/reader/book_face.dart, ../features/reader/book_page.dart, _adoptUncommittedPages, _ambiguousQueue, batchId, bookScrollId, bytes (+76 more)

### Community 27 - "patra_launch.dart"
Cohesion: 0.07
Nodes (28): AnimationController, build, child, _controller, createState, didChangeDependencies, didUpdateWidget, dispose (+20 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.07
Nodes (26): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+18 more)

### Community 29 - "profile_switch_test.dart"
Cohesion: 0.06
Nodes (30): package:patra/src/features/login/login_screen.dart, required Credential credential,
  ClientIdentity, String? profileId,
  double, _field, identity, keyboard, main, profiles (+22 more)

### Community 30 - "reader_test.dart"
Cohesion: 0.04
Nodes (48): CustomScrollView, Key? readerKey,
  int, LibraryType? libraryType,
  Size, NeverScrollableScrollPhysics, PageView, required int initialPage,
  
  
  
  ReadingDirection?, required int pagesRead,
  int, Scrollable (+40 more)

### Community 31 - "Continuous vertical reader: zoom and navigation research"
Cohesion: 0.04
Nodes (46): 1. State model, 2. Layout, 3. Gestures and alternate controls, 4. Current-page and progress stability, 5. Navigation target, 6. Delivery sequence, Acceptance and test matrix, `/api/Reader/file-dimensions` and chapter info (+38 more)

### Community 32 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (29): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+21 more)

### Community 33 - "auth_test.dart"
Cohesion: 0.09
Nodes (21): DioException get, Exception, SignInExpired, package:patra/src/keychain.dart, accountId, apiKey, call, calls (+13 more)

### Community 34 - "home_hero_test.dart"
Cohesion: 0.06
Nodes (34): LibraryType, LibraryTypeNaming, NavigatorState, _backdrop, _chapter, client, close, fetch (+26 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "saved_chapters_per_profile_test.dart"
Cohesion: 0.11
Nodes (18): _Adapter, _catalogueRoot, client, close, fetch, _lea, locale, main (+10 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "test_support.dart"
Cohesion: 0.06
Nodes (35): package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/library/library_screen.dart, package:patra/src/settings/locale_settings.dart, _Adapter, client, close, fetch, main (+27 more)

### Community 39 - "_ReaderScreenState"
Cohesion: 0.11
Nodes (27): libraryNameProvider, bookFontProvider, bookFontsCacheProvider, bookContentsProvider, _BookPage, bookPageProvider, build, _buildBookReader (+19 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.03
Nodes (73): downloads_service.dart, _answerLaunchPrompt, _asked, _asking, awaitingResume, batchSummary, bySeries, _bySeriesThenTitle (+65 more)

### Community 41 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.22
Nodes (13): ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), Credential (sealed password-or-authKey type), DeviceBiometrics (lib/src/lock/biometrics.dart), Domain docs (single-context CONTEXT.md and docs/adr/), imageCacheKey (one cover fetched once per household), The lock's copy refuses the sentence it would be easiest to write (+5 more)

### Community 42 - "page_rail.dart"
Cohesion: 0.06
Nodes (32): bottomGap, build, controller, createState, dispose, _documentAt, _dragging, _dragPage (+24 more)

### Community 43 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (40): ../branding/patra_signature.dart, Container, CustomPaint, dart:async, LoginResult, build, dotScale, markEm (+32 more)

### Community 44 - "reader_settings_sheet.dart"
Cohesion: 0.06
Nodes (35): direction_icon.dart, ../features/reader/reading_direction.dart, ../features/reader/strip_geometry.dart, _ActionRow, bookFamily, current, defaultValue, direction (+27 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.14
Nodes (14): package:patra/src/branding/patra_launch.dart, package:patra/src/features/launch/launch_animation.dart, static int, _app, build, createState, _Home, _HomeState (+6 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 47 - "download_pill.dart"
Cohesion: 0.06
Nodes (33): double?, download_stop.dart, ../downloads/downloads_service.dart, EdgeInsetsGeometry, IconData, SavedChapter, build, child (+25 more)

### Community 48 - "catalogue_store.dart"
Cohesion: 0.05
Nodes (43): _catalogueRoot, _deleteSeries, dirNameFor, _file, fromJson, isEmpty, libraries, _librariesRevision (+35 more)

### Community 49 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "session_scope.dart"
Cohesion: 0.10
Nodes (20): catalogue/catalogue_provider.dart, features/launch/launch_animation.dart, auth, build, child, _container, createState, dispose (+12 more)

### Community 51 - "strip_geometry.dart"
Cohesion: 0.07
Nodes (29): IndexedWidgetBuilder, anchorAt, build, childCount, decodeWidthFor, estimateMaxScrollOffset, fraction, geometry (+21 more)

### Community 52 - "main.dart"
Cohesion: 0.07
Nodes (26): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+18 more)

### Community 53 - "settings_screen.dart"
Cohesion: 0.04
Nodes (53): ../../api/client_identity.dart, ../../downloads/image_cache_store.dart, ../../external_links.dart, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, BookPageUnavailable, _BottomChrome (+45 more)

### Community 54 - "The profile picker (/profiles)"
Cohesion: 0.17
Nodes (13): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation, LaunchSlot registry (LaunchLogoSlot, LaunchWordmarkSlot), The outro adapts to the screen it lands on, not to a flag, Blades are turned like pages, not grown in place (+5 more)

### Community 55 - "patra_logo_paths.dart"
Cohesion: 0.17
Nodes (11): dart:ui, leaf1, leaf2, markHeight, markWidth, PatraLogoPaths, splitX, wordmark (+3 more)

### Community 56 - "package:flutter/widgets.dart"
Cohesion: 0.33
Nodes (5): AppLifecycleState, AppLifecycleNotifier, build, report, package:flutter/widgets.dart

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "series_offline_test.dart"
Cohesion: 0.10
Nodes (20): FilledButton, InkWell, package:patra/src/widgets/download_pill.dart, _chapter, _fillAll, main, _metadata, _profileId (+12 more)

### Community 59 - "Map"
Cohesion: 0.22
Nodes (13): OfflineNotifier, LibraryScanNotifier, BookFontsCache, PageShapesNotifier, DeclaredDirectionsNotifier, ReadOverridesNotifier, ProfileLocksNotifier, profileLockStoreProvider (+5 more)

### Community 60 - "reading_settings.dart"
Cohesion: 0.08
Nodes (24): book,

  
  
  serif,, leftToRight,
  rightToLeft,, BookType, defaultBookLineHeight, defaultBookReadingFace, defaultBookTextSize, directionNamed, isRightToLeft (+16 more)

### Community 61 - "strip_width.dart"
Cohesion: 0.04
Nodes (50): Drag?, _anchor, build, _capture, child, _clampedBy, clampWidthFactor, controller (+42 more)

### Community 62 - "dart:convert"
Cohesion: 0.05
Nodes (34): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, package:patra/src/branding/patra_font_licenses.dart, package:patra/src/features/settings/settings_screen.dart, _Adapter (+26 more)

### Community 63 - "_"
Cohesion: 0.11
Nodes (21): FutureProvider, _, CatalogueDeps, CatalogueRead, _deps, _fetch, into, invalidatable (+13 more)

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
Cohesion: 0.02
Nodes (80): book_face.dart, BookPage, EdgeInsets, anchor, at, _attribute, _attributeMatch, _attributeValue (+72 more)

### Community 68 - "patraAccent = progress/identity, patraOffline = downloads/offline"
Cohesion: 0.16
Nodes (14): patraAccent = progress/identity, patraOffline = downloads/offline, /api/Series/currently-reading does not mean what it says, Claude Design handoff (.claude/design/HANDOFF.md), featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), markChapterRead (mark-multiple-read / -unread), POST /api/Series/on-deck, ProfileAvatar and _FaceBadge (+6 more)

### Community 69 - "DownloadsService (<documents>/downloads/<profile>/<chapterId>/)"
Cohesion: 0.10
Nodes (24): ADR-0001 reader magnify gesture, GET /api/Reader/chapter-info pageDimensions, A column of rows runs the full width at the app's gutter, DownloadsNotifier must re-read state.value after an await, DownloadsService (<documents>/downloads/<profile>/<chapterId>/), A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, ImageCacheStore.trim (a capped image cache) (+16 more)

### Community 70 - "page_shape.dart"
Cohesion: 0.18
Nodes (10): build, isVertical, measuredPagesNeeded, _median, middle, of, PageShape, pageShapesProvider (+2 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.10
Nodes (21): bool get, bySortOrder, entries, entryCoverUrl, entryPictured, entryUnderWay, inVolumes, isWholeVolume (+13 more)

### Community 72 - "downloads_provider_test.dart"
Cohesion: 0.05
Nodes (40): package:patra/src/lifecycle.dart, Profile? session,
  bool, active, activeChapterRequests, adapter, _chapter, chapterGates, _chapterWithId (+32 more)

### Community 73 - "store_screenshots_test.dart"
Cohesion: 0.04
Nodes (44): Duration, back, bar, _beat, binding, centre, cover, _deadline (+36 more)

### Community 74 - "ConsumerWidget"
Cohesion: 0.06
Nodes (64): catalogue, ConsumerWidget, didUpdateWidget, authProvider, kavitaClientProvider, offlineProvider, chapterDirProvider, downloadRecordProvider (+56 more)

### Community 75 - "ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it"
Cohesion: 0.20
Nodes (9): ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it, Consequences, Considered options, and why not, Context, Cost, accepted, Decision, Prototype, Sources (+1 more)

### Community 76 - "Hyphenating a book's prose: where the breaks come from, and who draws the mark"
Cohesion: 0.17
Nodes (12): 1. Where the break points come from, 2. Which languages, and what they cost, 3. Which language a book is in — and how that answers #118 consistently, 4. Who draws the hyphen — the question with no cheap answer, 5. What our own line breaker would cost what is already built, 6. Does justification come back, Executive recommendation, How to re-run it (+4 more)

### Community 77 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.05
Nodes (39): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart, package:patra/src/api/client_identity.dart (+31 more)

### Community 78 - "demo_server.dart"
Cohesion: 0.04
Nodes (51): _arg, _body, _Chapter, chapterById, chapterInfoJson, chapterJson, chapters, coverDrawing (+43 more)

### Community 79 - "saved_copies_test.dart"
Cohesion: 0.05
Nodes (38): CircularProgressIndicator, package:patra/src/features/downloads/downloads_screen.dart, RichText, _answer, build, chapter, _chapterId, client (+30 more)

### Community 80 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "cover_placeholder.dart"
Cohesion: 0.09
Nodes (21): _apart, _bandFor, _brighter, build, choice, CoverPlaceholder, coverPlaceholderTones, _dimmest (+13 more)

### Community 82 - "gen_web_mark.dart"
Cohesion: 0.03
Nodes (62): accent, add, addQuadratic, argb, baseline, _bottom, _Bounds, box (+54 more)

### Community 83 - "Compact three-blade frond variant (icons at or under 72px)"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 84 - "profile_picker_screen.dart"
Cohesion: 0.07
Nodes (31): profileCatalogueProvider, profileDownloadsProvider, _AddFace, _avatarSize, build, busy, createState, _enter (+23 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "magnify_gesture_test.dart"
Cohesion: 0.25
Nodes (7): package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "book_reader_test.dart"
Cohesion: 0.04
Nodes (45): CachedNetworkImageProvider, MemoryImage, package:patra/src/features/reader/book_page.dart, ScrollableState, String? html,
  int, adapter, _addressedPicture, _answer (+37 more)

### Community 89 - "patra_mark.dart"
Cohesion: 0.20
Nodes (9): build, color, height, paint, PatraMark, shouldRepaint, _wordBounds, patra_logo_paths.dart (+1 more)

### Community 90 - "page_rail_test.dart"
Cohesion: 0.08
Nodes (23): , package:patra/src/features/reader/page_rail.dart, ScrollController, 8, _bottomGap, geometry, _Harness, _heightAt (+15 more)

### Community 91 - "sessionProvider"
Cohesion: 0.18
Nodes (17): sessionProvider, _resumePaused, localeSettingsProvider, BatchDownloadSize, BatchDownloadSizeNotifier, BookLineHeightNotifier, BookReadingFaceNotifier, BookTextSizeNotifier (+9 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "package:patra/src/auth/session.dart"
Cohesion: 0.05
Nodes (40): package:patra/src/auth/session.dart, package:patra/src/external_links.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, package:patra/src/widgets/profile_avatar.dart, lea, main, _profile (+32 more)

### Community 95 - "ADR-0008 — Kavita paginates a book; the app parses no EPUB"
Cohesion: 0.29
Nodes (7): ADR-0008 — Kavita paginates a book; the app parses no EPUB, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 96 - "Patra Frond Mark (five-blade master, 1024px)"
Cohesion: 0.40
Nodes (5): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed)

### Community 97 - "../../../l10n/generated/app_localizations.dart"
Cohesion: 0.07
Nodes (27): ../downloads/downloads_provider.dart, ../../../l10n/generated/app_localizations.dart, ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind (+19 more)

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
Nodes (24): package:patra/src/features/reader/strip_geometry.dart, 8, controller, fraction, geometry, _heightAt, images, main (+16 more)

### Community 104 - "patra_signature.dart"
Cohesion: 0.11
Nodes (18): _baseline, build, _dotCentre, _dotGap, _dotRadius, dotScale, _em, heightFor (+10 more)

### Community 105 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 106 - "offline_reading_test.dart"
Cohesion: 0.11
Nodes (18): package:patra/src/features/reader/reader_screen.dart, _app, attempts, close, fetch, identity, _lea, main (+10 more)

### Community 107 - "ADR-0004 — The auth key is the only secret a profile keeps"
Cohesion: 0.33
Nodes (6): ADR-0004 — The auth key is the only secret a profile keeps, Consequences, Context, Cost, accepted, Decision, Why

### Community 108 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 109 - "AppLocalizations"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 110 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 112 - "page_shape_test.dart"
Cohesion: 0.09
Nodes (22): MangaFormat, package:patra/src/features/reader/page_shape.dart, catalogue, _chapter, container, declared, format, libraryId (+14 more)

### Community 113 - "library_scan_test.dart"
Cohesion: 0.05
Nodes (36): Completer, DioException, PopupMenuItem, required bool admin,
  bool, _Adapter, client, close, _container (+28 more)

### Community 114 - "ConsumerState"
Cohesion: 0.20
Nodes (12): ConsumerState, ConsumerStatefulWidget, PatraApp, _PatraShell, _PatraShellState, serverReachableProvider, serverVersionProvider, LoginScreen (+4 more)

### Community 119 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (29): ../../format.dart, batchSummaryProvider, downloadMembershipProvider, savedChapterIdsProvider, build, bytes, chapter, chapterId (+21 more)

### Community 126 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.05
Nodes (41): CachedNetworkImage, LibraryType? libraryType,
  Locale, package:cached_network_image/cached_network_image.dart, package:patra/src/api/kavita_client.dart, package:patra/src/resume_point.dart, package:patra/src/widgets/cover.dart, package:patra/src/widgets/cover_placeholder.dart, _channelGap (+33 more)

### Community 128 - "Where a page stops being a page: the vertical threshold"
Cohesion: 0.17
Nodes (12): A second library, one anybody can re-run: Kavita's public demo, How to re-run it, Sources, The answer, The measurement — one real library, The question, What #57 implements, What is still thin (+4 more)

### Community 129 - "deep_link_test.dart"
Cohesion: 0.11
Nodes (17): package:patra/src/features/series/series_detail_screen.dart, package:patra/src/routes.dart, required Directory downloadsRoot,
  bool, _app, client, close, fetch, launching (+9 more)

### Community 130 - "ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series"
Cohesion: 0.14
Nodes (13): A direction per library, shipped (#65), ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series, Amendment — 2026-09-13 (#56), Amendment — 2026-09-13 (#57), Amendment — 2026-09-13 (#58), Amendment — 2026-09-13 (#58, shipped), Amendment — 2026-09-13 (#65), Amendment — 2026-09-20 (#118) (+5 more)

### Community 131 - "State"
Cohesion: 0.16
Nodes (18): PatraLaunch, _PatraLaunchState, BookPageBody, _BookPageBodyState, _BookView, _BookViewState, _MagnifyPage, _MagnifyPageState (+10 more)

### Community 132 - "catalogue_overlay.dart"
Cohesion: 0.11
Nodes (19): catalogue_provider.dart, fetch, held, heldSpine, librariesRevisionProvider, live, onDeckOverlay, _onDeckReadProvider (+11 more)

### Community 133 - "reading_direction.dart"
Cohesion: 0.09
Nodes (21): build, canPromoteToLibrary, ChapterDirection, ChapterDirectionKey, declaredDirectionsProvider, detected, detectedDirectionProvider, direction (+13 more)

### Community 134 - "HttpClientAdapter"
Cohesion: 0.06
Nodes (34): HttpClientAdapter, _BookAdapter, _AnswersThenHangs, _Adapter, _KavitaLikeAdapter, _PageServer, _BookAdapter, _BookWithFontAdapter (+26 more)

### Community 135 - "keychain.dart"
Cohesion: 0.18
Nodes (11): delete, Keychain, keychainProvider, read, readAll, SecureKeychain, _storage, write (+3 more)

### Community 136 - "direction_icon.dart"
Cohesion: 0.20
Nodes (9): ReadingDirection, build, color, direction, DirectionIcon, paint, shouldRepaint, size (+1 more)

### Community 137 - "login_screen.dart"
Cohesion: 0.07
Nodes (29): ../../api/connection_failure.dart, FormState, Profile, Session, _askForServer, build, _buildForm, _busy (+21 more)

### Community 138 - "The Kavita API client"
Cohesion: 0.50
Nodes (3): Kavita API client — deliberately hand-written, Reaching the server: cleartext, and saying what went wrong, The Kavita API client

### Community 139 - "routes.dart"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 141 - "book-hyphenation.md"
Cohesion: 0.29
Nodes (3): A book, Reader, The reader

### Community 143 - "catalogue_reads.dart"
Cohesion: 0.12
Nodes (15): catalogue_overlay.dart, catalogue_read.dart, SeriesMetadata, heldLibraryTypeProvider, libraries, libraryTypeProvider, list, null (+7 more)

### Community 146 - "home_offline_test.dart"
Cohesion: 0.06
Nodes (30): package:patra/src/downloads/downloads_provider.dart, package:patra/src/downloads/downloads_service.dart, package:patra/src/features/downloads/resume_strip.dart, package:patra/src/features/home/continue_hero.dart, _chapter, client, close, container (+22 more)

### Community 147 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 151 - "AsyncValue.isResolvedFailure"
Cohesion: 0.21
Nodes (12): AuthState.atLaunch, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, isLaunchProvider, AsyncValue.isResolvedFailure, kavitaClientProvider, _OfflineHome (an empty state, not the banner returning), OfflineIndicator (a status in the app bar, not a banner) (+4 more)

### Community 152 - "../api/models.dart"
Cohesion: 0.08
Nodes (24): ../api/models.dart, BookContentsEntry, chaptersTitle, chapterTitle, numberedChapterLabel, numberedChapterRange, specialsTitle, storylineTitle (+16 more)

### Community 153 - "CustomPainter"
Cohesion: 0.29
Nodes (7): CustomPainter, _LaunchPainter, _MarkPainter, _SignaturePainter, _Hatch, DashedBorderPainter, _DirectionPainter

### Community 154 - "ADR-0011 — A second theme is deferred, not rejected"
Cohesion: 0.25
Nodes (7): ADR-0011 — A second theme is deferred, not rejected, Consequence, Considered options, Context, Cost, accepted, Decision, Why

### Community 155 - "CLAUDE.md"
Cohesion: 0.11
Nodes (18): Agent skills, Architecture, CLAUDE.md, Commands, Design system — the brand kit is the source of truth, Domain docs, graphify, Issue tracker (+10 more)

### Community 156 - "ADR-0009 — A saved copy keeps the pagination it was made with"
Cohesion: 0.29
Nodes (6): ADR-0009 — A saved copy keeps the pagination it was made with, Consequence, Context, Cost, accepted, Decision, Why

### Community 157 - "catalogue_provider.dart"
Cohesion: 0.13
Nodes (14): catalogue_store.dart, _storeOrNull, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, catalogueStoreProvider, _done, markStored (+6 more)

### Community 158 - "reader_settings_sheet_test.dart"
Cohesion: 0.14
Nodes (16): DirectionPicked, DirectionPromotedToLibrary, LibraryDirectionCleared, ReaderSettingsOutcome, SeriesDirectionCleared, package:patra/src/features/reader/reading_direction.dart, package:patra/src/widgets/reader_settings_sheet.dart, _builtIn (+8 more)

### Community 159 - "package:dio/dio.dart"
Cohesion: 0.06
Nodes (31): client_identity.dart, Finder get, IconButton, kavita_client.dart, announceDevice, identity, null, renameTarget (+23 more)

### Community 160 - "ADR-0010 — A book's page is drawn by the app, not handed to a web view"
Cohesion: 0.29
Nodes (6): ADR-0010 — A book's page is drawn by the app, not handed to a web view, Consequence, Context, Cost, accepted, Decision, Why

### Community 161 - "package:flutter/foundation.dart"
Cohesion: 0.33
Nodes (5): _families, _registered, registerPatraFontLicenses, package:flutter/foundation.dart, package:flutter/services.dart

### Community 162 - "BookPicture"
Cohesion: 0.50
Nodes (5): BookBlock, BookPicture, BookWords, endBlock, parseBookPage

### Community 163 - "../theme.dart"
Cohesion: 0.06
Nodes (31): ../api/kavita_client.dart, ../auth/session.dart, ../branding/patra_lockup.dart, build, _artwork, build, chapterId, _CoverBackdrop (+23 more)

### Community 164 - "external_links.dart"
Cohesion: 0.18
Nodes (11): copyright, ExternalLinks, externalLinksProvider, legalese, open, privacy, source, SystemLinks (+3 more)

### Community 165 - "gen_app_icons.sh"
Cohesion: 0.47
Nodes (5): The header draws the five-blade fan at 24pt, The palm frond mark (five-blade and compact three-blade), android_icon(), ios_icon(), gen_app_icons.sh script

### Community 166 - "cover.dart"
Cohesion: 0.13
Nodes (14): cover_placeholder.dart, build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress (+6 more)

### Community 167 - "cache_settings.dart"
Cohesion: 0.18
Nodes (13): build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheSettingsProvider, ImageCacheSettingsStore, initialImageCacheLimitProvider (+5 more)

### Community 168 - "downloads_service_test.dart"
Cohesion: 0.08
Nodes (25): DownloadsService, _book, _bookId, _bookPageHtml, _bookWithFontPageHtml, _chapter, client, close (+17 more)

### Community 169 - "dart:math"
Cohesion: 0.25
Nodes (7): Color, dart:math, color, paint, radius, shouldRepaint, strokeWidth

### Community 170 - "List"
Cohesion: 0.18
Nodes (10): int get, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+2 more)

### Community 171 - "DownloadsNotifier"
Cohesion: 0.18
Nodes (12): AsyncNotifier, didChangeAppLifecycleState, build, DownloadsNotifier, downloadsServiceProvider, DownloadsState, appLifecycleProvider, _PausedScreenNotifier (+4 more)

### Community 172 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 173 - "launch_animation.dart"
Cohesion: 0.31
Nodes (8): ../../branding/patra_launch.dart, build, child, createState, isLaunchProvider, LaunchAnimation, _LaunchAnimationState, play

### Community 174 - "@immutable"
Cohesion: 0.40
Nodes (5): @immutable, BookFace, BookAnchor, MagnifyGesture, MagnifyTransform

### Community 175 - "openapi_contract_test.dart"
Cohesion: 0.25
Nodes (7): File, main, resolve, schema, schemas, spec, specName

### Community 176 - "The three routes, judged"
Cohesion: 0.50
Nodes (4): `custom_text_engine` 0.1.5 — not a candidate, `hyphen` 0.4.0 — good code, no patterns, Liang here — the recommendation, The three routes, judged

### Community 177 - "package:patra/src/settings/reading_settings.dart"
Cohesion: 0.50
Nodes (3): package:patra/src/features/reader/book_face.dart, package:patra/src/settings/reading_settings.dart, main

### Community 178 - "static const"
Cohesion: 0.25
Nodes (7): build, gapEm, PatraLockup, size, patra_mark.dart, static const, ../widgets/patra_wordmark.dart

### Community 179 - "UserDto.isAdmin (role read from the login response)"
Cohesion: 0.47
Nodes (6): Admin scan request from the Library tab's app-bar menu, AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, POST /api/Library/scan (admin only), LibraryScanNotifier, UserDto.isAdmin (role read from the login response)

### Community 180 - "page_loading_test.dart"
Cohesion: 0.19
Nodes (12): Image, ImageInfo, ImageProvider, package:patra/src/features/reader/page_loading.dart, _Arrives, _drawn, loadImage, main (+4 more)

### Community 181 - "_ReaderSettings"
Cohesion: 0.67
Nodes (3): _BookSettings, _PictureSettings, _ReaderSettings

### Community 185 - "locale_settings.dart"
Cohesion: 0.12
Nodes (14): ../keychain.dart, BatchSizeHintStore, _key, _keychain, markShown, wasShown, _key, _keychain (+6 more)

### Community 186 - "What the two store listings take"
Cohesion: 0.40
Nodes (4): The check a run has to pass, What the two store listings take, Where the run stands, Where the screenshots' content comes from

### Community 187 - "ADR-0012 — A book is set in the face the book asks for"
Cohesion: 0.29
Nodes (6): ADR-0012 — A book is set in the face the book asks for, Consequence, Context, Cost, accepted, Decision, Why

### Community 189 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 193 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **3615 isolated node(s):** `_server`, `_user`, `_password`, `_locale`, `_deadline` (+3610 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3887 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `ProfilePreferencesStore (profile_preferences.dart)`, `patraAccent = progress/identity, patraOffline = downloads/offline`, `The profile picker (/profiles)`, `AsyncValue.isResolvedFailure`, `profile_lock_sheet.dart`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `UserDto.isAdmin (role read from the login response)`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `ProfilePreferencesStore (profile_preferences.dart)` connect `ProfilePreferencesStore (profile_preferences.dart)` to `Profile lock (lib/src/lock/profile_lock.dart)`, `DownloadsService (<documents>/downloads/<profile>/<chapterId>/)`, `AsyncValue.isResolvedFailure`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `_server`, `_user`, `_password` to the rest of the system?**
  _3615 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0091324200913242 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009708737864077669 - nodes in this community are weakly interconnected._