# Graph Report - patra  (2026-09-08)

## Corpus Check
- 114 files · ~227,960 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2999 nodes · 4181 edges · 126 communities (114 shown, 8 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 91 edges (avg confidence: 0.87)
- Token cost: 777,235 input · 0 output

## Community Hubs (Navigation)
- Generated Localization Bundle
- French Localization Strings
- English Localization Strings
- Reader Thumbnail Strip
- Reader Screen State
- Kavita DTO Models
- Auth Session And Profiles
- Design Tokens And Theme
- Launch Animation Widget
- Profile Lock Test Harness
- Domain Glossary
- Kavita HTTP Client
- Test Dio Adapters
- Settings Screen
- Model And Contract Tests
- Downloads Provider Tests
- Series Detail Sections
- Library Grid And Scan
- Home Screen Shelves
- Launch Composition Timeline
- Per-Profile Preferences
- Shared Test Support
- Client Identity Headers
- Session Handover Tests
- Profile Picker Screen
- Profile Lock Sheet
- Downloads Storage Service
- Palm Frond Widget
- Profile Lock Vault
- Downloads Tab And Save Pill
- Reader Widget Tests
- Widget Test Scaffolding
- Magnify Gesture Geometry
- Continue Hero Tests
- Deep Link Routing Tests
- CI Build And Release Jobs
- Riverpod Screen Providers
- Linux GTK Runner
- Login Form Screen
- Shared Image Cache Tests
- Downloads Notifier
- API Client Rationale
- Stateless UI Fragments
- App Shell And Router
- Custom Painters And Icons
- Launch Animation Tests
- Image Cache Store
- Auth Notifier Tests
- Offline Indicator Tests
- iOS Runner AppDelegate
- Continue Hero Widget
- Library Scan Tests
- App Startup Wiring
- Session Scope Container
- Navigation And Offline Rules
- Server Version Tests
- Stateful Widget States
- Graphify Merge Driver Test
- Kavita Client Tests
- Server Reachability Tests
- Reading Direction Setting
- Profile Picker Tests
- Downloads Service Tests
- Connection Failure Tests
- Reader Settings Sheet
- ADR Document Structure
- The Per-Profile Catalogue
- Masthead And Formatting
- Design System Rules
- Tablet And Reader Layout Rules
- Riverpod Notifiers
- Resume Point Rules
- Route Locations And Links
- Image Cache Budget Setting
- Per-Profile Downloads Tests
- Profile Avatar Widget
- Entity Naming By Library Type
- Frond Mark And Icon Pipeline
- Admin Role And Profile Identity
- Cover Image Widgets
- ADR-0002 Resume Point
- Fake HTTP Adapters
- Page Backdrop Widget
- iOS Icon Size Rule
- PDF Page Loading
- iOS Icon Compact Threshold
- Reader Preferences Rationale
- ADR-0003 Profile Identity
- Landscape Spread Layout
- Connection Failure Classifier
- Consumer Stateful Screens
- Account Id From Token
- iOS Icon Master Crossover
- Android Legacy Mipmaps
- Magnify Gesture Tests
- Device Biometrics
- Frond Icon Masters
- Image Cache Store Tests
- ADR-0001 Magnify Gesture
- Release Signing And Tags
- Library Type Vocabulary
- ADR-0004 Auth Key
- Issue Tracker Skill
- Auth Providers
- Patra Wordmark
- README Project Overview
- On Deck And Hero Source
- ADR-0004 Structure
- Domain Docs Skill
- Localization Delegates
- Launch Slot Registry
- Android MainActivity
- Magnify Gesture Types
- Credential Sealed Type
- Preferences Vault Types
- Graphify Tracked Graph
- Agent Skills
- Spread Vocabulary
- Triage Labels Doc
- Launch Scope Widget
- Gen-l10n Configuration
- Nullable Bool Type

## God Nodes (most connected - your core abstractions)
1. `_` - 67 edges
2. `kavitaClientProvider` - 21 edges
3. `authProvider` - 15 edges
4. `build` - 15 edges
5. `offlineProvider` - 14 edges
6. `The per-profile catalogue` - 13 edges
7. `build` - 11 edges
8. `ADR-0003 — A profile is a Kavita account, and there are no local ones` - 10 edges
9. `downloadsProvider` - 10 edges
10. `KavitaClient (lib/src/api/kavita_client.dart)` - 10 edges

## Surprising Connections (you probably didn't know these)
- `pubspec version is only a local fallback` --semantically_similar_to--> `Server version`  [INFERRED] [semantically similar]
  pubspec.yaml → CONTEXT.md
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart
- `patra package manifest` --conceptually_related_to--> `Registered device`  [INFERRED]
  pubspec.yaml → CONTEXT.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **The release pipeline: one tag, one run number, two signed platform paths** — claude_release_by_tag, claude_build_number_run_number, claude_ios_signing_paths, claude_android_signing_paths, claude_play_internal_track, claude_internet_permission, claude_clientidentity [EXTRACTED 1.00]
- **The launch animation: ink, composition, measured slots, and the mark** — claude_launch_screen_ink, claude_launch_composition, claude_launchanimation, claude_launchslot, claude_outro_adapts_to_slot, claude_patrafrond, claude_patramasthead, claude_islaunchprovider [EXTRACTED 1.00]
- **What the device owns and what a profile owns** — claude_profile_id, claude_downloads_service, claude_profile_preferences_store, claude_profile_lock, claude_sessionscope, claude_imagecachekey, claude_imagecachestore, claude_device_default_preferences [INFERRED 0.95]
- **The identity gate: who is reading, asked before anything is read** — context_gate, context_picker, context_face, context_lock, context_pin, context_credential, context_session [EXTRACTED 1.00]
- **What the device remembers, and the lines between the three stores** — context_catalogue, context_spine, context_saved_chapter, context_image_cache, context_device_default, context_offline [EXTRACTED 1.00]
- **The parts of a series, named by library type** — context_library_type, context_volume, context_chapter, context_issue, context_special, context_loose_chapter, context_pseudo_volume, context_storyline [EXTRACTED 1.00]
- **Resume point: two screens made to agree by construction** — docs_adr_0002_resume_point_computed_in_the_app_shared_resume_rule, docs_adr_0002_resume_point_computed_in_the_app_series_hero_target, docs_adr_0002_resume_point_computed_in_the_app_continue_hero, docs_adr_0002_resume_point_computed_in_the_app_read_overrides_provider, docs_adr_0002_resume_point_computed_in_the_app_continue_point_endpoint [EXTRACTED 1.00]
- **The per-profile device-owned stores and what dies with a profile** — docs_adr_0005_the_catalogue_is_what_the_device_remembers_catalogue, docs_adr_0005_the_catalogue_is_what_the_device_remembers_saved_chapter_meta_json, docs_adr_0005_the_catalogue_is_what_the_device_remembers_image_cache_invariant_erosion, docs_adr_0005_the_catalogue_is_what_the_device_remembers_dies_with_profile, docs_adr_0003_a_profile_is_a_kavita_account_profile_is_kavita_account, docs_adr_0004_the_auth_key_is_the_only_persisted_secret_auth_key_only_secret [INFERRED 0.85]
- **The persistence shortlist weighed against files** — docs_adr_0005_the_catalogue_is_what_the_device_remembers_files_not_database, docs_adr_0005_the_catalogue_is_what_the_device_remembers_drift_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_sqflite_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_other_stores_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_hive_ce_rejected [EXTRACTED 1.00]
- **The five legacy Android launcher densities rendered by one pipeline** — android_app_src_main_res_mipmap_mdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_icon [EXTRACTED 1.00]
- **Where the fan closes: the two icons at or under 72px against the rule and the mark** — android_app_src_main_res_mipmap_mdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_compact_master_size_rule [INFERRED 0.85]
- **iOS AppIcon size ladder rendered from two frond masters** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_1024x1024_1x_marketing_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_1x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_2x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_3x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_1x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_2x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_3x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_1x_compact_master_size_rule [INFERRED 0.85]
- **The 72px master-selection threshold, straddled by these renders** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_3x, ios_runner_assets_xcassets_appicon_appiconset_compact_master_size_rule [EXTRACTED 1.00]
- **Legacy and iPad icon slots declared by AppIcon.appiconset Contents.json** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_2x [EXTRACTED 1.00]
- **iOS/iPadOS app icon size ladder (60-83.5pt slots)** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_3x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_83_5x83_5_2x_appicon [EXTRACTED 1.00]
- **Master selection by pixel size: compact frond at or below 72px, five-blade fan above** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_compact_master_rule, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_3x_patra_frond_mark [INFERRED 0.95]

## Communities (126 total, 8 thin omitted)

### Community 0 - "Generated Localization Bundle"
Cohesion: 0.01
Nodes (152): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+144 more)

### Community 1 - "French Localization Strings"
Cohesion: 0.01
Nodes (139): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+131 more)

### Community 2 - "English Localization Strings"
Cohesion: 0.01
Nodes (139): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+131 more)

### Community 3 - "Reader Thumbnail Strip"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.02
Nodes (84): savedChapterProvider, aspectRatios, build, chapter, chapterId, chapterInfoProvider, child, _client (+76 more)

### Community 5 - "Kavita DTO Models"
Cohesion: 0.03
Nodes (77): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters (+69 more)

### Community 6 - "Auth Session And Profiles"
Cohesion: 0.04
Nodes (56): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+48 more)

### Community 7 - "Design Tokens And Theme"
Cohesion: 0.04
Nodes (54): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+46 more)

### Community 8 - "Launch Animation Widget"
Cohesion: 0.04
Nodes (54): GlobalKey, launch_composition.dart, LaunchStage, _add, build, _checkedMotion, child, _controller (+46 more)

### Community 9 - "Profile Lock Test Harness"
Cohesion: 0.04
Nodes (47): package:patra/src/api/client_identity.dart, package:patra/src/auth/session.dart, package:patra/src/features/settings/settings_screen.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, package:patra/src/settings/cache_settings.dart, package:patra/src/settings/profile_preferences.dart, package:patra/src/settings/reading_settings.dart (+39 more)

### Community 10 - "Domain Glossary"
Cohesion: 0.05
Nodes (50): Dependabot pub ecosystem (weekly), Administrator, Auth key, Avatar, Catalogue, Chapter, Continue (the promotion), Credential (+42 more)

### Community 11 - "Kavita HTTP Client"
Cohesion: 0.04
Nodes (49): ClientIdentity, Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient (+41 more)

### Community 12 - "Test Dio Adapters"
Cohesion: 0.05
Nodes (43): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, _key, languageEndonym (+35 more)

### Community 13 - "Settings Screen"
Cohesion: 0.05
Nodes (45): ../../downloads/image_cache_store.dart, ImageCacheLimit, imageCacheLimitProvider, imageCacheSizeProvider, imageCacheStoreProvider, initState, actionLabel, _avatarSize (+37 more)

### Community 14 - "Model And Contract Tests"
Cohesion: 0.05
Nodes (39): dart:io, File, package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/api/client_device.dart, package:patra/src/api/models.dart, package:patra/src/entity_naming.dart (+31 more)

### Community 15 - "Downloads Provider Tests"
Cohesion: 0.05
Nodes (40): Future, InkWell, int? savedChapter,
  bool, package:patra/src/downloads/downloads_provider.dart, package:patra/src/widgets/save_pill.dart, ProviderContainer, adapter, _chapter (+32 more)

### Community 16 - "Series Detail Sections"
Cohesion: 0.05
Nodes (40): AsyncValue, Chapter, ResolvedFailure, _Buckets, _buildSections, chapter, _ChapterRow, child (+32 more)

### Community 17 - "Library Grid And Scan"
Cohesion: 0.07
Nodes (40): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+32 more)

### Community 18 - "Home Screen Shelves"
Cohesion: 0.06
Nodes (38): continue_hero.dart, ../launch/launch_animation.dart, Library, build, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+30 more)

### Community 19 - "Launch Composition Timeline"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 20 - "Per-Profile Preferences"
Cohesion: 0.05
Nodes (37): build, _byProfile, clear, copyWith, deviceDirection, deviceLanguage, deviceMagnify, direction (+29 more)

### Community 21 - "Shared Test Support"
Cohesion: 0.05
Nodes (37): MemoryPreferencesVault? vault,
  ReadingDirection, required int chapterId,
  String, available, bytes, channel, chapter, clear, clears (+29 more)

### Community 22 - "Client Identity Headers"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 23 - "Session Handover Tests"
Cohesion: 0.06
Nodes (35): package:patra/src/session_scope.dart, package:patra/src/widgets/offline_indicator.dart, required Credential credential,
  ClientIdentity, _app, attempts, close, fetch, identity (+27 more)

### Community 24 - "Profile Picker Screen"
Cohesion: 0.07
Nodes (35): authProvider, profileDownloadsProvider, scan, build, initState, _AddFace, _avatarSize, build (+27 more)

### Community 25 - "Profile Lock Sheet"
Cohesion: 0.06
Nodes (34): bool?, DeviceBiometrics (lib/src/lock/biometrics.dart), Profile lock (lib/src/lock/profile_lock.dart), biometricsProvider, askProfilePin, _backspace, _biometrics, build (+26 more)

### Community 26 - "Downloads Storage Service"
Cohesion: 0.06
Nodes (32): bytes, chapterDir, chapterId, copyWith, _deleteQuietly, dirNameFor, download, _downloadsRoot (+24 more)

### Community 27 - "Palm Frond Widget"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 28 - "Profile Lock Vault"
Cohesion: 0.06
Nodes (31): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+23 more)

### Community 29 - "Downloads Tab And Save Pill"
Cohesion: 0.08
Nodes (29): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter, build (+21 more)

### Community 30 - "Reader Widget Tests"
Cohesion: 0.06
Nodes (30): Image, NeverScrollableScrollPhysics, package:flutter/services.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set (+22 more)

### Community 31 - "Widget Test Scaffolding"
Cohesion: 0.08
Nodes (26): package:flutter/material.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/library/library_screen.dart, package:patra/src/features/reader/page_loading.dart, package:patra/src/features/reader/thumb_strip.dart, package:patra/src/settings/locale_settings.dart, package:patra/src/theme.dart, _Adapter (+18 more)

### Community 32 - "Magnify Gesture Geometry"
Cohesion: 0.07
Nodes (29): double get, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+21 more)

### Community 33 - "Continue Hero Tests"
Cohesion: 0.07
Nodes (29): FilledButton, NavigatorState, package:patra/src/features/home/continue_hero.dart, _backdrop, _chapter, client, close, fetch (+21 more)

### Community 34 - "Deep Link Routing Tests"
Cohesion: 0.07
Nodes (28): NavigationBar, package:patra/src/app.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/features/reader/reader_screen.dart, package:patra/src/routes.dart, required Directory downloadsRoot,
  bool, _app (+20 more)

### Community 35 - "CI Build And Release Jobs"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "Riverpod Screen Providers"
Cohesion: 0.12
Nodes (26): auth/session.dart, ConsumerWidget, kavitaClientProvider, offlineProvider, save, build, ContinueHero, _Details (+18 more)

### Community 37 - "Linux GTK Runner"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "Login Form Screen"
Cohesion: 0.08
Nodes (25): ../../api/connection_failure.dart, FormState, _askForServer, _buildForm, _busy, child, createState, didChangeDependencies (+17 more)

### Community 39 - "Shared Image Cache Tests"
Cohesion: 0.08
Nodes (24): CachedNetworkImage, package:cached_network_image/cached_network_image.dart, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/widgets/cover.dart, cacheDir, _chapter, client, close (+16 more)

### Community 40 - "Downloads Notifier"
Cohesion: 0.10
Nodes (24): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+16 more)

### Community 41 - "API Client Rationale"
Cohesion: 0.11
Nodes (25): One credential, two mechanisms (the account auth key), KavitaClient._bearerIsIrrelevant, ConnectionFailureKind.blockedByBrowser, ChapterDto.sortOrder is the reading order, Cleartext HTTP permitted on both platforms, ClientDevice headers (client_device.dart), ConnectionFailure (connection_failure.dart), Credential (sealed password-or-authKey type) (+17 more)

### Community 42 - "Stateless UI Fragments"
Cohesion: 0.08
Nodes (24): _Wordmark, _FlyingFrond, _SplashWordmark, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, _BottomChrome, _ReaderError (+16 more)

### Community 43 - "App Shell And Router"
Cohesion: 0.10
Nodes (22): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+14 more)

### Community 44 - "Custom Painters And Icons"
Cohesion: 0.10
Nodes (20): Color, CustomPainter, _UnfurlPainter, color, DashedBorderPainter, paint, radius, shouldRepaint (+12 more)

### Community 45 - "Launch Animation Tests"
Cohesion: 0.09
Nodes (21): package:flutter/rendering.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size, _app, _appOpacity (+13 more)

### Community 46 - "Image Cache Store"
Cohesion: 0.10
Nodes (20): dart:isolate, DateTime?, _cacheKey, clear, dir, entries, imageCacheSizeProvider, imageCacheStoreProvider (+12 more)

### Community 47 - "Auth Notifier Tests"
Cohesion: 0.10
Nodes (20): DioException get, Exception, SignInExpired, accountId, apiKey, call, calls, color (+12 more)

### Community 48 - "Offline Indicator Tests"
Cohesion: 0.10
Nodes (19): Finder get, IconButton, package:patra/src/api/kavita_client.dart, package:patra/src/resume_point.dart, _Adapter, close, _cloud, _explanation (+11 more)

### Community 49 - "iOS Runner AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "Continue Hero Widget"
Cohesion: 0.10
Nodes (19): ../../entity_naming.dart, Series, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+11 more)

### Community 51 - "Library Scan Tests"
Cohesion: 0.10
Nodes (19): PopupMenuItem, required bool admin,
  bool, client, close, _container, empty, fetch, _item (+11 more)

### Community 52 - "App Startup Wiring"
Cohesion: 0.11
Nodes (18): auth, cacheLimit, identity, imageCache, load, locks, main, preferences (+10 more)

### Community 53 - "Session Scope Container"
Cohesion: 0.11
Nodes (18): auth, build, child, _container, createState, dispose, _entered, initState (+10 more)

### Community 54 - "Navigation And Offline Rules"
Cohesion: 0.13
Nodes (18): AuthState.atLaunch, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, isLaunchProvider, AsyncValue.isResolvedFailure, kavitaClientProvider, _PatraShell._labelsFit (the bottom bar measures its labels), LaunchStage / launch_composition.dart (+10 more)

### Community 55 - "Server Version Tests"
Cohesion: 0.11
Nodes (17): Completer, card, client, close, dot, _dotColor, fetch, held (+9 more)

### Community 56 - "Stateful Widget States"
Cohesion: 0.16
Nodes (18): LaunchAnimation, _LaunchAnimationState, PageLoading, _PageLoadingState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState (+10 more)

### Community 57 - "Graphify Merge Driver Test"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "Kavita Client Tests"
Cohesion: 0.11
Nodes (17): apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch, loginReturnsGarbage, logins (+9 more)

### Community 59 - "Server Reachability Tests"
Cohesion: 0.11
Nodes (17): _announcement, card, client, close, dot, _dotColor, fetch, handle (+9 more)

### Community 60 - "Reading Direction Setting"
Cohesion: 0.12
Nodes (16): bool get, leftToRight,
  rightToLeft,, directionNamed, isRightToLeft, isVerticalScroll, _key, label, _legacyNames (+8 more)

### Community 61 - "Profile Picker Tests"
Cohesion: 0.12
Nodes (15): Container, CustomPaint, LoginResult, Opacity, package:patra/src/features/launch/launch_animation.dart, package:patra/src/widgets/dashed_border.dart, box, _dimming (+7 more)

### Community 62 - "Downloads Service Tests"
Cohesion: 0.12
Nodes (15): DioException, DownloadsService, package:patra/src/downloads/downloads_service.dart, _chapter, client, close, failOnPage, fetch (+7 more)

### Community 63 - "Connection Failure Tests"
Cohesion: 0.12
Nodes (15): DioExceptionType?, Object?, package:flutter/widgets.dart, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType (+7 more)

### Community 64 - "Reader Settings Sheet"
Cohesion: 0.13
Nodes (15): direction_icon.dart, _buildReader, magnifyProvider, build, current, direction, _MagnifyRow, onPicked (+7 more)

### Community 65 - "ADR Document Structure"
Cohesion: 0.13
Nodes (13): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, No invite flow is shipped, Why, ADR-0005 — The catalogue is what the device remembers, and it is files (+5 more)

### Community 66 - "The Per-Profile Catalogue"
Cohesion: 0.15
Nodes (16): The entry round trip is hidden by the launch animation, Cache-first overlay precedence rule, The per-profile catalogue, A cover is never pinned; the answer is a real placeholder, drift (rejected, but not for the usual reason), Files, not a database, hive_ce (the near-free alternative, rejected), isResolvedFailure means something new (+8 more)

### Community 67 - "Masthead And Formatting"
Cohesion: 0.12
Nodes (14): features/launch/launch_animation.dart, ../l10n/generated/app_localizations.dart, formatBytes, gb, mb, sizeBytes, build, _gap (+6 more)

### Community 68 - "Design System Rules"
Cohesion: 0.15
Nodes (15): patraAccent = progress/identity, patraOffline = downloads/offline, Claude Design handoff (.claude/design/HANDOFF.md), reading_settings.dart / locale_settings.dart as device defaults, DownloadsNotifier must re-read state.value after an await, DownloadsService (<documents>/downloads/<profile>/<chapterId>/), The language is the only preference written twice, markChapterRead (mark-multiple-read / -unread), The profile picker (/profiles) (+7 more)

### Community 69 - "Tablet And Reader Layout Rules"
Cohesion: 0.15
Nodes (15): A column of rows runs the full width at the app's gutter, A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, ImageCacheStore.trim (a capped image cache), isTabletLayout(context), A swipe pane and a button must never scale with the screen, The reader must never wrap itself in a LayoutBuilder, The system's chrome comes and goes with the reader's (+7 more)

### Community 70 - "Riverpod Notifiers"
Cohesion: 0.18
Nodes (15): OfflineNotifier, sessionProvider, _ProfileFace, LibraryScanNotifier, ReadOverridesNotifier, ProfileLocksNotifier, profileLockStoreProvider, DefaultReadingDirectionNotifier (+7 more)

### Community 71 - "Resume Point Rules"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 72 - "Route Locations And Links"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 73 - "Image Cache Budget Setting"
Cohesion: 0.15
Nodes (14): build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheLimitProvider, ImageCacheSettingsStore, initialImageCacheLimitProvider (+6 more)

### Community 74 - "Per-Profile Downloads Tests"
Cohesion: 0.13
Nodes (14): _Adapter, client, close, fetch, _lea, locale, main, _profile (+6 more)

### Community 75 - "Profile Avatar Widget"
Cohesion: 0.14
Nodes (13): api/kavita_client.dart, Profile, Session, build, dimmed, hex, _Initial, on (+5 more)

### Community 76 - "Entity Naming By Library Type"
Cohesion: 0.14
Nodes (13): api/models.dart, LibraryType, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, LibraryTypeNaming, numberedChapterLabel (+5 more)

### Community 77 - "Frond Mark And Icon Pipeline"
Cohesion: 0.18
Nodes (12): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, The header draws the five-blade fan at 24pt, LaunchSlot registry (LaunchLogoSlot, LaunchWordmarkSlot), The outro adapts to the screen it lands on, not to a flag, The palm frond mark (five-blade and compact three-blade), PatraFrond (lib/src/widgets/patra_frond.dart), PatraMasthead (the gate-screen lockup) (+4 more)

### Community 78 - "Admin Role And Profile Identity"
Cohesion: 0.19
Nodes (14): Admin scan request from the Library tab's app-bar menu, ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, Domain docs (single-context CONTEXT.md and docs/adr/), POST /api/Library/scan (admin only), LibraryScanNotifier (+6 more)

### Community 79 - "Cover Image Widgets"
Cohesion: 0.14
Nodes (13): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+5 more)

### Community 80 - "ADR-0002 Resume Point"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "Fake HTTP Adapters"
Cohesion: 0.15
Nodes (13): HttpClientAdapter, _StubAdapter, _KavitaLikeAdapter, _HomeAdapter, _Adapter, _UnreachableAdapter, _Adapter, _Adapter (+5 more)

### Community 82 - "Page Backdrop Widget"
Cohesion: 0.15
Nodes (12): int?, SelectedLibraryNotifier, _artwork, chapterId, _fade, _hidden, _maxAspect, page (+4 more)

### Community 83 - "iOS Icon Size Rule"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 84 - "PDF Page Loading"
Cohesion: 0.17
Nodes (11): dart:async, build, createState, dispose, explain, explainAfter, _explaining, initState (+3 more)

### Community 85 - "iOS Icon Compact Threshold"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "Reader Preferences Rationale"
Cohesion: 0.24
Nodes (11): ADR-0001 reader magnify gesture, GET /api/Reader/chapter-info pageDimensions, localeProvider and languageEndonym, magnify_gesture.dart (one-finger drag magnifier), mockSecureStorage() in test_support.dart, ProfilePreferencesStore (profile_preferences.dart), Serialized progress posts and the last-page rule, ReadingDirection (verticalScroll is a direction, not a mode) (+3 more)

### Community 87 - "ADR-0003 Profile Identity"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "Landscape Spread Layout"
Cohesion: 0.18
Nodes (10): int get, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+2 more)

### Community 89 - "Connection Failure Classifier"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 90 - "Consumer Stateful Screens"
Cohesion: 0.22
Nodes (10): ConsumerState, ConsumerStatefulWidget, serverReachableProvider, serverVersionProvider, LoginScreen, _LoginScreenState, ReaderScreen, _ServerCard (+2 more)

### Community 91 - "Account Id From Token"
Cohesion: 0.20
Nodes (8): dart:convert, accountIdFrom, _padded, segments, package:patra/src/api/account_id.dart, _jwt, main, seg

### Community 92 - "iOS Icon Master Crossover"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Android Legacy Mipmaps"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "Magnify Gesture Tests"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 95 - "Device Biometrics"
Cohesion: 0.28
Nodes (8): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart, FakeBiometrics

### Community 96 - "Frond Icon Masters"
Cohesion: 0.39
Nodes (8): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed), Patra Frond Compact Mark (three-blade master, 1024px), Size rule: compact master at or below 72px, Widened blade spread of the compact fan

### Community 97 - "Image Cache Store Tests"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 98 - "ADR-0001 Magnify Gesture"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 99 - "Release Signing And Tags"
Cohesion: 0.33
Nodes (7): Android job: android/key.properties switch, Build number is github.run_number, ClientIdentity (app version read off the binary), iOS job: signed TestFlight path or unsigned IPA fallback, Play upload to the internal track, Releases are cut by a tag, not by a push, ios/Flutter/Release.xcconfig (Runner-target signing scope)

### Community 100 - "Library Type Vocabulary"
Cohesion: 0.38
Nodes (7): LibraryTypeNaming (lib/src/entity_naming.dart), The fixed French glossary, LibraryType (Manga/Comic/Book/Image/LightNovel/ComicVine), Localization (app_en.arb template, app_fr.arb), Kavita sentinel numbers (ParserConstants ±100000), GET /api/Series/series-detail is deliberately not called, The storyline as a section header, not a tab

### Community 101 - "ADR-0004 Auth Key"
Cohesion: 0.33
Nodes (7): apiKey is the opds auth key, one row not a concept, A profile persists the auth key and nothing else, Using the auth key as the request scheme (rejected alternative), LoginDto ignores username/password when ApiKey is passed, POST /api/Plugin/authenticate (rejected alternative), refresh-token on 0.9.0.x must not be leaned on, Token lifetimes are absent from the spec

### Community 102 - "Issue Tracker Skill"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 103 - "Auth Providers"
Cohesion: 0.33
Nodes (7): AuthNotifier, AuthState, clientIdentityProvider, initialAuthStateProvider, resume, signInProvider, _AppVersion

### Community 104 - "Patra Wordmark"
Cohesion: 0.29
Nodes (6): build, dotScale, PatraWordmark, size, _tracking, static const

### Community 105 - "README Project Overview"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 106 - "On Deck And Hero Source"
Cohesion: 0.40
Nodes (6): /api/Series/currently-reading does not mean what it says, featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), imageCacheKey (one cover fetched once per household), POST /api/Series/on-deck, entryUnderWay / resume_point.dart

### Community 107 - "ADR-0004 Structure"
Cohesion: 0.33
Nodes (6): ADR-0004 — The auth key is the only secret a profile keeps, Consequences, Context, Cost, accepted, Decision, Why

### Community 108 - "Domain Docs Skill"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 109 - "Localization Delegates"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 110 - "Launch Slot Registry"
Cohesion: 0.33
Nodes (6): LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, W

### Community 112 - "Magnify Gesture Types"
Cohesion: 0.67
Nodes (3): @immutable, MagnifyGesture, MagnifyTransform

### Community 113 - "Credential Sealed Type"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 114 - "Preferences Vault Types"
Cohesion: 0.67
Nodes (3): PreferencesVault, SecurePreferencesVault, MemoryPreferencesVault

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **2025 isolated node(s):** `_appIn`, `appOpacity`, `appRise`, `_at`, `blade` (+2020 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2227 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile Lock Sheet` to `Admin Role And Profile Identity`, `Design System Rules`, `Navigation And Offline Rules`, `Reader Preferences Rationale`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `ProfilePreferencesStore (profile_preferences.dart)` connect `Reader Preferences Rationale` to `Profile Lock Sheet`, `Design System Rules`, `Navigation And Offline Rules`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `Admin Role And Profile Identity` to `Profile Lock Sheet`, `On Deck And Hero Source`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **What connects `_appIn`, `appOpacity`, `appRise` to the rest of the system?**
  _2025 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Generated Localization Bundle` be split into smaller, more focused modules?**
  _Cohesion score 0.013071895424836602 - nodes in this community are weakly interconnected._
- **Should `French Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.014285714285714285 - nodes in this community are weakly interconnected._