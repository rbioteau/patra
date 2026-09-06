# Graph Report - feat-10-server-holds-profiles  (2026-09-06)

## Corpus Check
- 106 files · ~181,987 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2295 nodes · 3111 edges · 103 communities (93 shown, 6 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7c239658`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_fr.dart
- app_localizations_en.dart
- Thumbnail Strip Accordion
- Reader Screen State
- models.dart
- launch_animation.dart
- theme.dart
- series_detail_screen.dart
- kavita_client.dart
- Launch Composition Timeline
- library_screen.dart
- Client Identity Headers
- session.dart
- package:flutter_riverpod/flutter_riverpod.dart
- reader_test.dart
- magnify_gesture.dart
- home_screen.dart
- patra_frond.dart
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
- offline_indicator_test.dart
- continue_hero.dart
- app.dart
- launch_animation_test.dart
- downloads_provider.dart
- iOS Runner App Delegate
- reading_settings.dart
- _ReaderScreenState
- server_reachability_test.dart
- Image Cache Trimming
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- page_backdrop.dart
- connection_failure.dart
- dart:io
- main.dart
- resume_point.dart
- reader_settings_sheet.dart
- auth_test.dart
- StatefulWidget
- cover.dart
- series_hero_test.dart
- tablet_layout_test.dart
- Hand-Written Client Rationale
- cache_settings.dart
- page_loading.dart
- PDF Page Loading Delay
- downloads_service_test.dart
- home_hero_test.dart
- widget_test.dart
- about_version_test.dart
- Progress and Storage Invariants
- package:flutter/material.dart
- ../../l10n/generated/app_localizations.dart
- image_cache_store_test.dart
- magnify_gesture_test.dart
- direction_icon.dart
- Icon Master Artwork
- Launch Screen and Mark Assets
- Network Permissions and Scan
- Locale, Offline and Navigation
- locale_settings.dart
- Domain Docs
- Auth State and Retry Policy
- Reader Direction and Magnify
- dart:convert
- Profile
- ConsumerWidget
- Handoff and Tablet Rules
- Localization Delegate
- Tag-Driven Release Rules
- Reader Layout Safety Rules
- client_identity_test.dart
- AuthNotifier
- App Icon Generation Script
- Map
- Dependency and Icon Tooling
- Android Main Activity
- package:dio/dio.dart
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
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- Credential

## God Nodes (most connected - your core abstractions)
1. `kavitaClientProvider` - 21 edges
2. `build` - 14 edges
3. `offlineProvider` - 11 edges
4. `_ReaderScreenState` - 9 edges
5. `downloadsProvider` - 8 edges
6. `build` - 8 edges
7. `AppLocalizations` - 7 edges
8. `authProvider` - 7 edges
9. `build` - 7 edges
10. `build` - 7 edges

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

## Communities (103 total, 6 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.02
Nodes (132): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+124 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.02
Nodes (119): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+111 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.02
Nodes (119): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+111 more)

### Community 3 - "Thumbnail Strip Accordion"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (73): adminRole, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters, ClientDeviceDto (+65 more)

### Community 6 - "launch_animation.dart"
Cohesion: 0.04
Nodes (51): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+43 more)

### Community 7 - "theme.dart"
Cohesion: 0.04
Nodes (53): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+45 more)

### Community 8 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (38): Chapter, _Buckets, _buildSections, chapter, _ChapterRow, child, clear, _confirmRemove (+30 more)

### Community 9 - "kavita_client.dart"
Cohesion: 0.04
Nodes (47): account_id.dart, Dio, Dio get, accountId, allSeriesForLibrary, apiKey, authKey, _bareDio (+39 more)

### Community 10 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 11 - "library_screen.dart"
Cohesion: 0.08
Nodes (29): ../../api/connection_failure.dart, available, build, createState, _EmptyBody, _EmptyLibrary, _EmptyLibraryState, _gridColumns (+21 more)

### Community 12 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 13 - "session.dart"
Cohesion: 0.04
Nodes (44): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, accountId, activeId, _activeKey, apiKey, baseUrl (+36 more)

### Community 14 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.08
Nodes (29): package:flutter_riverpod/flutter_riverpod.dart, package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/auth/session.dart, package:patra/src/features/library/library_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/settings/locale_settings.dart, package:patra/src/settings/reading_settings.dart (+21 more)

### Community 15 - "reader_test.dart"
Cohesion: 0.06
Nodes (30): Image, NeverScrollableScrollPhysics, package:patra/src/features/reader/reader_screen.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set (+22 more)

### Community 16 - "magnify_gesture.dart"
Cohesion: 0.07
Nodes (28): anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH, half (+20 more)

### Community 17 - "home_screen.dart"
Cohesion: 0.07
Nodes (36): AsyncValue, continue_hero.dart, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth (+28 more)

### Community 18 - "patra_frond.dart"
Cohesion: 0.05
Nodes (36): Color get, CustomPainter, double?, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, alpha, bladeHalfWidth (+28 more)

### Community 19 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (29): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter, build (+21 more)

### Community 20 - "login_screen.dart"
Cohesion: 0.06
Nodes (36): FormState, authProvider, build, _buildForm, _buildProfileList, _busy, child, _connect (+28 more)

### Community 21 - "CI Build and Release Workflow"
Cohesion: 0.09
Nodes (30): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+22 more)

### Community 22 - "downloads_service.dart"
Cohesion: 0.07
Nodes (28): double get, bytes, chapterDir, chapterId, copyWith, _deleteQuietly, download, fromJson (+20 more)

### Community 23 - "Linux GTK Runner"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "downloads_provider_test.dart"
Cohesion: 0.14
Nodes (13): Future, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+5 more)

### Community 25 - "kavita_client_test.dart"
Cohesion: 0.07
Nodes (27): HttpClientAdapter, _KavitaLikeAdapter, _HomeAdapter, apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter (+19 more)

### Community 26 - "Series Sections Tests"
Cohesion: 0.08
Nodes (24): InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, build, cacheDir, _chapter, client, close (+16 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.06
Nodes (39): ../../downloads/image_cache_store.dart, sessionProvider, imageCacheSizeProvider, imageCacheStoreProvider, _scan, initState, actionLabel, build (+31 more)

### Community 28 - "StatelessWidget"
Cohesion: 0.08
Nodes (25): _Wordmark, _FlyingFrond, _SplashWordmark, _AddProfileButton, _ErrorLine, _Field, _Masthead, _ProfileRow (+17 more)

### Community 29 - "offline_indicator_test.dart"
Cohesion: 0.09
Nodes (22): Finder get, IconButton, package:patra/src/api/kavita_client.dart, package:patra/src/features/home/home_screen.dart, _Adapter, close, _cloud, _explanation (+14 more)

### Community 30 - "continue_hero.dart"
Cohesion: 0.10
Nodes (20): ../../entity_naming.dart, Series, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+12 more)

### Community 31 - "app.dart"
Cohesion: 0.12
Nodes (18): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/launch/launch_animation.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+10 more)

### Community 32 - "launch_animation_test.dart"
Cohesion: 0.08
Nodes (23): Opacity, package:flutter/rendering.dart, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size (+15 more)

### Community 33 - "downloads_provider.dart"
Cohesion: 0.07
Nodes (30): AsyncNotifier, downloads_service.dart, int get, build, cancel, _cancelTokens, copyWith, _disposed (+22 more)

### Community 34 - "iOS Runner App Delegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 35 - "reading_settings.dart"
Cohesion: 0.11
Nodes (18): bool get, leftToRight,
  rightToLeft,, build, initialMagnifyProvider, isRightToLeft, isVerticalScroll, _key, label (+10 more)

### Community 36 - "_ReaderScreenState"
Cohesion: 0.16
Nodes (15): ConsumerState, ConsumerStatefulWidget, serverReachableProvider, serverVersionProvider, savedChapterProvider, LoginScreen, _LoginScreenState, build (+7 more)

### Community 37 - "server_reachability_test.dart"
Cohesion: 0.11
Nodes (18): Container, _announcement, card, client, close, dot, _dotColor, fetch (+10 more)

### Community 38 - "Image Cache Trimming"
Cohesion: 0.11
Nodes (18): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, _lastTrim, _measure (+10 more)

### Community 39 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 40 - "page_backdrop.dart"
Cohesion: 0.08
Nodes (23): ../api/kavita_client.dart, color, paint, radius, shouldRepaint, strokeWidth, _artwork, chapterId (+15 more)

### Community 41 - "connection_failure.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 42 - "dart:io"
Cohesion: 0.22
Nodes (8): dart:io, File, main, resolve, schema, schemas, spec, specName

### Community 43 - "main.dart"
Cohesion: 0.12
Nodes (15): auth, cacheLimit, identity, imageCache, locale, magnify, main, readingDirection (+7 more)

### Community 44 - "resume_point.dart"
Cohesion: 0.12
Nodes (15): api/models.dart, bySortOrder, entries, inVolumes, loose, orderedChapters, ResumeEntry, ResumePoint (+7 more)

### Community 45 - "reader_settings_sheet.dart"
Cohesion: 0.14
Nodes (14): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+6 more)

### Community 46 - "auth_test.dart"
Cohesion: 0.04
Nodes (46): DioException get, DioExceptionType?, Exception, LibraryType, SignInExpired, chaptersTitle, chapterTitle, continueChapterLabel (+38 more)

### Community 47 - "StatefulWidget"
Cohesion: 0.23
Nodes (13): LaunchAnimation, _LaunchAnimationState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState, _VerticalScrollView, _VerticalScrollViewState (+5 more)

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

### Community 52 - "cache_settings.dart"
Cohesion: 0.18
Nodes (12): build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, ImageCacheSettingsStore, initialImageCacheLimitProvider, _key (+4 more)

### Community 53 - "page_loading.dart"
Cohesion: 0.17
Nodes (12): build, createState, dispose, explain, explainAfter, _explaining, initState, PageImageBuilder (+4 more)

### Community 54 - "PDF Page Loading Delay"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 55 - "downloads_service_test.dart"
Cohesion: 0.14
Nodes (13): DioException, DownloadsService, package:patra/src/downloads/downloads_service.dart, _chapter, client, close, failOnPage, fetch (+5 more)

### Community 56 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (27): FilledButton, NavigatorState, package:patra/src/features/home/continue_hero.dart, _backdrop, _chapter, client, close, continueReading (+19 more)

### Community 57 - "widget_test.dart"
Cohesion: 0.15
Nodes (12): NavigationBar, package:patra/src/app.dart, package:patra/src/downloads/downloads_provider.dart, package:patra/src/features/login/login_screen.dart, _app, auth, client, close (+4 more)

### Community 58 - "about_version_test.dart"
Cohesion: 0.17
Nodes (11): package:patra/src/api/client_identity.dart, package:patra/src/features/settings/settings_screen.dart, _Adapter, client, close, fetch, main, _profile (+3 more)

### Community 59 - "Progress and Storage Invariants"
Cohesion: 0.22
Nodes (11): Chapter row swipes: leading = progress, trailing = destruction, DownloadsService and the meta.json-last invariant, hasReadingProgress — the hero asks about the series, ImageCacheStore and its byte cap, Serialized progress posts and the last-page rule, readOverridesProvider — optimistic progress writes, _SqueezedByPane — a pane squeezes the row, ThumbLoadQueue (+3 more)

### Community 60 - "package:flutter/material.dart"
Cohesion: 0.09
Nodes (21): Completer, dart:async, package:flutter/material.dart, package:patra/src/features/reader/thumb_strip.dart, card, client, close, dot (+13 more)

### Community 61 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.17
Nodes (11): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, offlineProvider, _ErrorState, formatBytes, gb, mb, sizeBytes (+3 more)

### Community 62 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 63 - "magnify_gesture_test.dart"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 64 - "direction_icon.dart"
Cohesion: 0.15
Nodes (12): Color, DefaultReadingDirectionNotifier, initialReadingDirectionProvider, ReadingDirection, build, color, direction, DirectionIcon (+4 more)

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

### Community 69 - "locale_settings.dart"
Cohesion: 0.15
Nodes (13): build, initialLocaleProvider, _key, languageEndonym, load, LocaleNotifier, LocaleSettingsStore, save (+5 more)

### Community 70 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 71 - "Auth State and Retry Policy"
Cohesion: 0.33
Nodes (7): AuthState / ServerEntry (several servers, one session), kavitaClientProvider, mockSecureStorage() in test_support.dart, serverRetry on every networked provider, Login result, Server entry, Session

### Community 72 - "Reader Direction and Magnify"
Cohesion: 0.33
Nodes (7): magnify_gesture.dart (one-finger magnify), Reader settings sheet (one cog, not a control per setting), ReadingDirection (one setting, three values), _VerticalScrollViewState placement guard, Magnifying, Reading direction, Vertical scrolling

### Community 73 - "dart:convert"
Cohesion: 0.20
Nodes (8): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, _jwt, main, seg

### Community 75 - "ConsumerWidget"
Cohesion: 0.17
Nodes (19): ConsumerWidget, kavitaClientProvider, save, build, ContinueHero, _Details, _LibrariesSection, _Shelf (+11 more)

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

### Community 81 - "client_identity_test.dart"
Cohesion: 0.05
Nodes (35): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/api/client_device.dart, package:patra/src/api/models.dart, package:patra/src/entity_naming.dart, package:patra/src/features/reader/spread_layout.dart, package:patra/src/resume_point.dart, _android (+27 more)

### Community 82 - "AuthNotifier"
Cohesion: 0.33
Nodes (7): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, resume, signInProvider, _AppVersion

### Community 83 - "App Icon Generation Script"
Cohesion: 0.60
Nodes (3): android_icon(), ios_icon(), gen_app_icons.sh script

### Community 84 - "Map"
Cohesion: 0.33
Nodes (6): int?, OfflineNotifier, SelectedLibraryNotifier, ReadOverridesNotifier, Map, Notifier

### Community 85 - "Dependency and Icon Tooling"
Cohesion: 0.67
Nodes (3): Dependabot pub ecosystem (weekly), Icons come from gen_app_icons.sh, not flutter_launcher_icons, patra package manifest

### Community 87 - "package:dio/dio.dart"
Cohesion: 0.12
Nodes (15): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+7 more)

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

### Community 103 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.14
Nodes (12): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, Why, ADR-0004 — The auth key is the only secret a profile keeps, Consequences (+4 more)

### Community 105 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **1589 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+1584 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1749 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `authProvider` connect `login_screen.dart` to `settings_screen.dart`, `_ReaderScreenState`, `session.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `kavitaClientProvider` connect `ConsumerWidget` to `downloads_provider.dart`, `_ReaderScreenState`, `series_detail_screen.dart`, `library_screen.dart`, `session.dart`, `home_screen.dart`, `settings_screen.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **Why does `KavitaClient` connect `kavita_client.dart` to `Reader Screen State`, `session.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _1589 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.015037593984962405 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.016666666666666666 - nodes in this community are weakly interconnected._