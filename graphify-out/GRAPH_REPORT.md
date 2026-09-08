# Graph Report - patra  (2026-09-08)

## Corpus Check
- 149 files · ~255,728 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3264 nodes · 4583 edges · 153 communities (123 shown, 26 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 91 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c51bd45a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Generated Localization Bundle
- French Localization Strings
- English Localization Strings
- Reader Thumbnail Strip
- Reader Screen State
- models.dart
- session.dart
- Design Tokens And Theme
- launch_animation.dart
- profile_lock_ui_test.dart
- patra package manifest
- kavita_client.dart
- connection_failure_test.dart
- settings_screen.dart
- client_identity_test.dart
- series_sections_test.dart
- series_detail_screen.dart
- _
- home_screen.dart
- launch_composition.dart
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- profile_switch_test.dart
- profile_picker_screen.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_frond.dart
- profile_lock.dart
- save_pill.dart
- reader_test.dart
- authProvider
- magnify_gesture.dart
- home_hero_test.dart
- deep_link_test.dart
- analyze job (pub get, analyze, test)
- package:dio/dio.dart
- my_application.cc
- login_screen.dart
- package:patra/src/api/kavita_client.dart
- downloads_provider.dart
- KavitaClient (lib/src/api/kavita_client.dart)
- StatelessWidget
- app.dart
- patra_masthead.dart
- launch_animation_test.dart
- image_cache_store.dart
- auth_test.dart
- catalogue_store.dart
- AppDelegate
- continue_hero.dart
- server_version_test.dart
- main.dart
- session_scope.dart
- Profile lock (lib/src/lock/profile_lock.dart)
- SignInExpired
- StatefulWidget
- graphify_merge_driver_test.dart
- kavita_client_test.dart
- server_reachability_test.dart
- reading_settings.dart
- package:flutter_test/flutter_test.dart
- ConsumerWidget
- _
- reader_settings_sheet.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- The per-profile catalogue
- catalogue_reads.dart
- patraAccent = progress/identity, patraOffline = downloads/offline
- isTabletLayout(context)
- Notifier
- resume_point.dart
- build
- cache_settings.dart
- dart:convert
- profile_avatar.dart
- ../api/models.dart
- gen_app_icons.sh
- UserDto.isAdmin (role read from the login response)
- ../../theme.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- downloads_provider_test.dart
- page_backdrop.dart
- Compact three-blade frond variant (icons at or under 72px)
- catalogue_provider.dart
- 72px threshold: small icons render from the compact master
- ProfilePreferencesStore (profile_preferences.dart)
- A profile is exactly one Kavita account
- MemoryPreferencesVault? vault,
  ReadingDirection
- saved_chapters_per_profile_test.dart
- package:flutter/material.dart
- catalogue_overlay_test.dart
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- dart:math
- catalogue_write_path_test.dart
- Patra Frond Compact Mark (three-blade master, 1024px)
- library_scan_test.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- offlineProvider
- LibraryTypeNaming (lib/src/entity_naming.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- AuthNotifier
- package:flutter_riverpod/flutter_riverpod.dart
- Patra
- DownloadsService (<documents>/downloads/<profile>/<chapterId>/)
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- static const
- MainActivity.kt
- ConnectionFailure (connection_failure.dart)
- Credential
- Map
- The graphify union merge driver (two halves)
- Issue tracker agent skill (GitHub issues via gh)
- Spread
- triage-labels.md
- downloads_screen.dart
- gen-l10n configuration (non-nullable getter)
- bool?
- ../../l10n/generated/app_localizations.dart
- profile_files.dart
- catalogue_overlay.dart
- List
- CustomPainter
- routes.dart
- _ThumbStripState
- LibraryType
- ../../catalogue/catalogue_overlay.dart
- ../series/series_detail_screen.dart
- page_loading.dart
- connection_failure.dart
- The Kavita API client
- savedChapterProvider
- The catalogue
- The reader
- Preferences
- LockVault
- SKILL.md
- .github/CLAUDE.md
- LaunchScope
- Keychain
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- _PagedView
- _VerticalScrollView

## God Nodes (most connected - your core abstractions)
1. `_` - 66 edges
2. `_` - 32 edges
3. `build` - 15 edges
4. `The per-profile catalogue` - 13 edges
5. `authProvider` - 11 edges
6. `build` - 10 edges
7. `ADR-0003 — A profile is a Kavita account, and there are no local ones` - 10 edges
8. `KavitaClient (lib/src/api/kavita_client.dart)` - 10 edges
9. `ADR-0004 — The auth key is the only secret a profile keeps` - 9 edges
10. `profileLocksProvider` - 9 edges

## Surprising Connections (you probably didn't know these)
- `pubspec version is only a local fallback` --semantically_similar_to--> `Server version`  [INFERRED] [semantically similar]
  pubspec.yaml → CONTEXT.md
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/offline_indicator_test.dart → lib/src/auth/session.dart
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `patra package manifest` --conceptually_related_to--> `Registered device`  [INFERRED]
  pubspec.yaml → CONTEXT.md
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **The persistence shortlist weighed against files** — docs_adr_0005_the_catalogue_is_what_the_device_remembers_files_not_database, docs_adr_0005_the_catalogue_is_what_the_device_remembers_drift_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_sqflite_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_other_stores_rejected, docs_adr_0005_the_catalogue_is_what_the_device_remembers_hive_ce_rejected [EXTRACTED 1.00]
- **What the device remembers, and the lines between the three stores** — context_catalogue, context_spine, context_saved_chapter, context_image_cache, context_device_default, context_offline [EXTRACTED 1.00]
- **The identity gate: who is reading, asked before anything is read** — context_gate, context_picker, context_face, context_lock, context_pin, context_credential, context_session [EXTRACTED 1.00]
- **The 72px master-selection threshold, straddled by these renders** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_3x, ios_runner_assets_xcassets_appicon_appiconset_compact_master_size_rule [EXTRACTED 1.00]
- **Legacy and iPad icon slots declared by AppIcon.appiconset Contents.json** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_50x50_2x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_1x, ios_runner_assets_xcassets_appicon_appiconset_icon_app_57x57_2x [EXTRACTED 1.00]
- **iOS/iPadOS app icon size ladder (60-83.5pt slots)** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_3x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_2x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_83_5x83_5_2x_appicon [EXTRACTED 1.00]
- **The launch animation: ink, composition, measured slots, and the mark** — claude_launch_screen_ink, claude_launch_composition, claude_launchanimation, claude_launchslot, claude_outro_adapts_to_slot, claude_patrafrond, claude_patramasthead, claude_islaunchprovider [EXTRACTED 1.00]
- **The five legacy Android launcher densities rendered by one pipeline** — android_app_src_main_res_mipmap_mdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_icon [EXTRACTED 1.00]
- **The release pipeline: one tag, one run number, two signed platform paths** — claude_release_by_tag, claude_build_number_run_number, claude_ios_signing_paths, claude_android_signing_paths, claude_play_internal_track, claude_internet_permission, claude_clientidentity [EXTRACTED 1.00]
- **Resume point: two screens made to agree by construction** — docs_adr_0002_resume_point_computed_in_the_app_shared_resume_rule, docs_adr_0002_resume_point_computed_in_the_app_series_hero_target, docs_adr_0002_resume_point_computed_in_the_app_continue_hero, docs_adr_0002_resume_point_computed_in_the_app_read_overrides_provider, docs_adr_0002_resume_point_computed_in_the_app_continue_point_endpoint [EXTRACTED 1.00]
- **The parts of a series, named by library type** — context_library_type, context_volume, context_chapter, context_issue, context_special, context_loose_chapter, context_pseudo_volume, context_storyline [EXTRACTED 1.00]
- **Where the fan closes: the two icons at or under 72px against the rule and the mark** — android_app_src_main_res_mipmap_mdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_compact_master_size_rule [INFERRED 0.85]
- **iOS AppIcon size ladder rendered from two frond masters** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_1024x1024_1x_marketing_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_1x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_2x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_3x_notification_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_1x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_2x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_3x_settings_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_1x_compact_master_size_rule [INFERRED 0.85]
- **The per-profile device-owned stores and what dies with a profile** — docs_adr_0005_the_catalogue_is_what_the_device_remembers_catalogue, docs_adr_0005_the_catalogue_is_what_the_device_remembers_saved_chapter_meta_json, docs_adr_0005_the_catalogue_is_what_the_device_remembers_image_cache_invariant_erosion, docs_adr_0005_the_catalogue_is_what_the_device_remembers_dies_with_profile, docs_adr_0003_a_profile_is_a_kavita_account_profile_is_kavita_account, docs_adr_0004_the_auth_key_is_the_only_persisted_secret_auth_key_only_secret [INFERRED 0.85]
- **What the device owns and what a profile owns** — claude_profile_id, claude_downloads_service, claude_profile_preferences_store, claude_profile_lock, claude_sessionscope, claude_imagecachekey, claude_imagecachestore, claude_device_default_preferences [INFERRED 0.95]
- **Master selection by pixel size: compact frond at or below 72px, five-blade fan above** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_1x_appicon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_72x72_1x_compact_master_rule, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_3x_patra_frond_mark [INFERRED 0.95]

## Communities (153 total, 26 thin omitted)

### Community 0 - "Generated Localization Bundle"
Cohesion: 0.01
Nodes (152): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+144 more)

### Community 1 - "French Localization Strings"
Cohesion: 0.01
Nodes (139): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+131 more)

### Community 2 - "English Localization Strings"
Cohesion: 0.01
Nodes (139): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+131 more)

### Community 3 - "Reader Thumbnail Strip"
Cohesion: 0.02
Nodes (88): Animation, Duration, ImageProvider?, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth (+80 more)

### Community 4 - "Reader Screen State"
Cohesion: 0.03
Nodes (76): aspectRatios, chapter, chapterId, child, _client, _controller, createState, didUpdateWidget (+68 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (79): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, Chapter, ChapterInfo (+71 more)

### Community 6 - "session.dart"
Cohesion: 0.04
Nodes (56): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, KavitaClient?, accountId, activeId, _activeKey (+48 more)

### Community 7 - "Design Tokens And Theme"
Cohesion: 0.04
Nodes (54): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+46 more)

### Community 8 - "launch_animation.dart"
Cohesion: 0.04
Nodes (53): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+45 more)

### Community 9 - "profile_lock_ui_test.dart"
Cohesion: 0.06
Nodes (34): package:patra/src/auth/session.dart, package:patra/src/features/settings/settings_screen.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, _Adapter, client, close, fetch (+26 more)

### Community 10 - "patra package manifest"
Cohesion: 0.05
Nodes (50): Dependabot pub ecosystem (weekly), Administrator, Auth key, Avatar, Catalogue, Chapter, Continue (the promotion), Credential (+42 more)

### Community 11 - "kavita_client.dart"
Cohesion: 0.04
Nodes (48): Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient, baseUrl (+40 more)

### Community 12 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 13 - "settings_screen.dart"
Cohesion: 0.06
Nodes (32): ../../downloads/image_cache_store.dart, actionLabel, _avatarSize, child, children, confirmed, createState, didChangeAppLifecycleState (+24 more)

### Community 14 - "client_identity_test.dart"
Cohesion: 0.10
Nodes (20): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, delete, _device, fetch (+12 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.05
Nodes (43): FilledButton, InkWell, int? savedChapter,
  bool, package:patra/src/widgets/save_pill.dart, _chapter, _fillAll, main, _metadata (+35 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (42): Chapter, _Buckets, _buildSections, chapter, _ChapterRow, child, clear, _confirmRemove (+34 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (39): ConnectionFailure?, _, alreadyRunning, any, asked, _askForScan, available, build (+31 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.06
Nodes (32): AsyncValue, continue_hero.dart, ../launch/launch_animation.dart, ResolvedFailure, _cardMaxWidth, _cardSpacing, _cardWidth, columns (+24 more)

### Community 19 - "launch_composition.dart"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.06
Nodes (34): bool?, build, _byProfile, copyWith, deviceDirection, deviceLanguage, deviceMagnify, direction (+26 more)

### Community 21 - "test_support.dart"
Cohesion: 0.04
Nodes (46): Biometrics, MemoryKeychain? keychain,
  ReadingDirection, required int chapterId,
  String, available, bytes, catalogueVolumesFixture, channel, chapter (+38 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.05
Nodes (36): dart:ui, appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey (+28 more)

### Community 23 - "profile_switch_test.dart"
Cohesion: 0.12
Nodes (16): _app, close, fetch, identity, _lea, main, _nobody, profile (+8 more)

### Community 24 - "profile_picker_screen.dart"
Cohesion: 0.09
Nodes (21): ../../api/connection_failure.dart, _AddFace, _avatarSize, busy, createState, _entering, _error, _Face (+13 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (27): askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing, createState (+19 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.06
Nodes (33): bytes, chapterDir, chapterId, copyWith, _deleteQuietly, dirNameFor, download, _downloadsRoot (+25 more)

### Community 27 - "patra_frond.dart"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.07
Nodes (27): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+19 more)

### Community 29 - "save_pill.dart"
Cohesion: 0.14
Nodes (15): ../../downloads/downloads_provider.dart, ../../downloads/downloads_service.dart, IconData, downloadsProvider, SavedChapter, DownloadsScreen, build, color (+7 more)

### Community 30 - "reader_test.dart"
Cohesion: 0.06
Nodes (31): Image, NeverScrollableScrollPhysics, package:patra/src/settings/reading_settings.dart, PageView, required int initialPage,
  ReadingDirection, Scrollable, SliderComponentShape, SliderComponentShape? sliderThumb,
  Set (+23 more)

### Community 31 - "authProvider"
Cohesion: 0.11
Nodes (23): ConsumerState, ConsumerStatefulWidget, authProvider, profileCatalogueProvider, profileDownloadsProvider, build, initState, LoginScreen (+15 more)

### Community 32 - "magnify_gesture.dart"
Cohesion: 0.06
Nodes (32): @immutable, double get, anchor, _band, contain, content, _degenerate, drawnContent (+24 more)

### Community 33 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (27): NavigatorState, _backdrop, _chapter, client, close, fetch, _iPad, _json (+19 more)

### Community 34 - "deep_link_test.dart"
Cohesion: 0.04
Nodes (47): NavigationBar, package:patra/src/app.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/features/reader/reader_screen.dart, package:patra/src/routes.dart, ReaderScreen, required Credential credential,
  ClientIdentity (+39 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "package:dio/dio.dart"
Cohesion: 0.09
Nodes (20): client_identity.dart, Finder get, IconButton, kavita_client.dart, announceDevice, identity, null, renameTarget (+12 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "login_screen.dart"
Cohesion: 0.08
Nodes (25): FormState, _askForServer, _buildForm, _busy, child, createState, didChangeDependencies, dispose (+17 more)

### Community 39 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.06
Nodes (31): CachedNetworkImage, package:patra/src/api/kavita_client.dart, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/resume_point.dart, package:patra/src/widgets/cover.dart, _chapter, _looseLeaf, main (+23 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.10
Nodes (24): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+16 more)

### Community 41 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.13
Nodes (21): ADR-0001 reader magnify gesture, ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), KavitaClient._bearerIsIrrelevant, ChapterDto.sortOrder is the reading order, Credential (sealed password-or-authKey type), Domain docs (single-context CONTEXT.md and docs/adr/) (+13 more)

### Community 42 - "StatelessWidget"
Cohesion: 0.08
Nodes (25): _LibraryCard, _FlyingFrond, _SplashWordmark, _EmptyBody, _LibraryGridSkeleton, _LibraryPills, _BottomChrome, _ReaderError (+17 more)

### Community 43 - "app.dart"
Cohesion: 0.09
Nodes (24): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+16 more)

### Community 44 - "patra_masthead.dart"
Cohesion: 0.20
Nodes (9): ../features/launch/launch_animation.dart, build, _gap, _markHeight, PatraMasthead, showTagline, _size, patra_frond.dart (+1 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.09
Nodes (21): package:flutter/rendering.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size, _app, _appOpacity (+13 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 47 - "auth_test.dart"
Cohesion: 0.10
Nodes (19): DioException get, package:patra/src/keychain.dart, accountId, apiKey, call, calls, color, _container (+11 more)

### Community 48 - "catalogue_store.dart"
Cohesion: 0.05
Nodes (41): Series, SeriesMetadata, _catalogueRoot, _deleteSeries, dirNameFor, _file, fromJson, isEmpty (+33 more)

### Community 49 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "continue_hero.dart"
Cohesion: 0.11
Nodes (18): ../../catalogue/catalogue_reads.dart, ../../entity_naming.dart, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+10 more)

### Community 51 - "server_version_test.dart"
Cohesion: 0.05
Nodes (35): Completer, Container, CustomPaint, dart:async, LoginResult, Opacity, package:patra/src/features/launch/launch_animation.dart, package:patra/src/features/reader/thumb_strip.dart (+27 more)

### Community 52 - "main.dart"
Cohesion: 0.08
Nodes (25): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+17 more)

### Community 53 - "session_scope.dart"
Cohesion: 0.11
Nodes (17): catalogue/catalogue_provider.dart, auth, build, child, _container, createState, dispose, _entered (+9 more)

### Community 54 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.14
Nodes (18): AuthState.atLaunch, reading_settings.dart / locale_settings.dart as device defaults, DeviceBiometrics (lib/src/lock/biometrics.dart), isLaunchProvider, The language is the only preference written twice, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation (+10 more)

### Community 56 - "StatefulWidget"
Cohesion: 0.17
Nodes (17): LaunchAnimation, _LaunchAnimationState, LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, _MagnifyPage (+9 more)

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "kavita_client_test.dart"
Cohesion: 0.11
Nodes (18): DioException, apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch, loginReturnsGarbage (+10 more)

### Community 59 - "server_reachability_test.dart"
Cohesion: 0.11
Nodes (18): _Adapter, _announcement, card, client, close, dot, _dotColor, fetch (+10 more)

### Community 60 - "reading_settings.dart"
Cohesion: 0.11
Nodes (17): bool get, leftToRight,
  rightToLeft,, directionNamed, isRightToLeft, isVerticalScroll, _key, _keychain, label (+9 more)

### Community 61 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (54): dart:io, ImageCacheStore, package:flutter_test/flutter_test.dart, package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/api/models.dart, package:patra/src/catalogue/catalogue_provider.dart, package:patra/src/catalogue/catalogue_store.dart (+46 more)

### Community 62 - "ConsumerWidget"
Cohesion: 0.12
Nodes (31): authProvider, catalogue, ConsumerWidget, downloadsProvider, kavitaClientProvider, build, ContinueHero, _Details (+23 more)

### Community 63 - "_"
Cohesion: 0.11
Nodes (21): catalogue_overlay.dart, FutureProvider, _, CatalogueDeps, CatalogueRead, _deps, _fetch, into (+13 more)

### Community 64 - "reader_settings_sheet.dart"
Cohesion: 0.09
Nodes (21): Color, direction_icon.dart, ReadingDirection, build, color, direction, DirectionIcon, paint (+13 more)

### Community 65 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.13
Nodes (13): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, No invite flow is shipped, Why, ADR-0005 — The catalogue is what the device remembers, and it is files (+5 more)

### Community 66 - "The per-profile catalogue"
Cohesion: 0.15
Nodes (16): The entry round trip is hidden by the launch animation, Cache-first overlay precedence rule, The per-profile catalogue, A cover is never pinned; the answer is a real placeholder, drift (rejected, but not for the usual reason), Files, not a database, hive_ce (the near-free alternative, rejected), isResolvedFailure means something new (+8 more)

### Community 67 - "catalogue_reads.dart"
Cohesion: 0.17
Nodes (11): catalogue_read.dart, libraries, libraryTypeProvider, list, onDeck, series, seriesForLibrary, seriesMetadata (+3 more)

### Community 68 - "patraAccent = progress/identity, patraOffline = downloads/offline"
Cohesion: 0.20
Nodes (12): patraAccent = progress/identity, patraOffline = downloads/offline, /api/Series/currently-reading does not mean what it says, Claude Design handoff (.claude/design/HANDOFF.md), featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), markChapterRead (mark-multiple-read / -unread), POST /api/Series/on-deck, readOverridesProvider (optimistic progress writes) (+4 more)

### Community 69 - "isTabletLayout(context)"
Cohesion: 0.15
Nodes (15): A column of rows runs the full width at the app's gutter, A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, ImageCacheStore.trim (a capped image cache), isTabletLayout(context), A swipe pane and a button must never scale with the screen, The reader must never wrap itself in a LayoutBuilder, The system's chrome comes and goes with the reader's (+7 more)

### Community 70 - "Notifier"
Cohesion: 0.27
Nodes (11): OfflineNotifier, DefaultReadingDirectionNotifier, LocaleNotifier, MagnifyNotifier, profilePreferencesStoreProvider, Locale?, localeSettingsProvider, Notifier (+3 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 72 - "build"
Cohesion: 0.13
Nodes (21): serverReachableProvider, serverVersionProvider, sessionProvider, imageCacheSizeProvider, imageCacheStoreProvider, _buildReader, initState, ReaderScreen (+13 more)

### Community 73 - "cache_settings.dart"
Cohesion: 0.16
Nodes (14): ../keychain.dart, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheSettingsProvider, ImageCacheSettingsStore (+6 more)

### Community 74 - "dart:convert"
Cohesion: 0.08
Nodes (22): dart:convert, accountIdFrom, _padded, segments, DownloadsService, package:patra/src/api/account_id.dart, package:patra/src/downloads/downloads_service.dart, _jwt (+14 more)

### Community 75 - "profile_avatar.dart"
Cohesion: 0.14
Nodes (13): Profile, Session, build, dimmed, hex, _Initial, on, profile (+5 more)

### Community 76 - "../api/models.dart"
Cohesion: 0.17
Nodes (11): ../api/models.dart, chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, numberedChapterLabel, resumeTitle, specialsTitle (+3 more)

### Community 77 - "gen_app_icons.sh"
Cohesion: 0.27
Nodes (8): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, The header draws the five-blade fan at 24pt, The palm frond mark (five-blade and compact three-blade), PatraFrond (lib/src/widgets/patra_frond.dart), android_icon(), ios_icon(), gen_app_icons.sh script

### Community 78 - "UserDto.isAdmin (role read from the login response)"
Cohesion: 0.32
Nodes (8): Admin scan request from the Library tab's app-bar menu, AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, POST /api/Library/scan (admin only), LibraryScanNotifier, UserDto.isAdmin (role read from the login response)

### Community 79 - "../../theme.dart"
Cohesion: 0.10
Nodes (19): build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress, radius (+11 more)

### Community 80 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "downloads_provider_test.dart"
Cohesion: 0.12
Nodes (15): package:patra/src/downloads/downloads_provider.dart, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+7 more)

### Community 82 - "page_backdrop.dart"
Cohesion: 0.12
Nodes (18): int?, kavitaClientProvider, save, SelectedLibraryNotifier, didChangeDependencies, _artwork, build, chapterId (+10 more)

### Community 83 - "Compact three-blade frond variant (icons at or under 72px)"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 84 - "catalogue_provider.dart"
Cohesion: 0.12
Nodes (15): ../api/kavita_client.dart, catalogue_store.dart, _storeOrNull, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, catalogueStoreProvider, _done (+7 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "ProfilePreferencesStore (profile_preferences.dart)"
Cohesion: 0.25
Nodes (11): GET /api/Reader/chapter-info pageDimensions, localeProvider and languageEndonym, magnify_gesture.dart (one-finger drag magnifier), mockSecureStorage() in test_support.dart, ProfilePreferencesStore (profile_preferences.dart), Serialized progress posts and the last-page rule, The reader's cog and reader_settings_sheet.dart, ReadingDirection (verticalScroll is a direction, not a mode) (+3 more)

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 89 - "saved_chapters_per_profile_test.dart"
Cohesion: 0.11
Nodes (17): _catalogueRoot, client, close, fetch, _lea, locale, main, _profile (+9 more)

### Community 90 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (56): color, paint, radius, shouldRepaint, strokeWidth, package:flutter/material.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/home/home_screen.dart (+48 more)

### Community 91 - "catalogue_overlay_test.dart"
Cohesion: 0.06
Nodes (33): HttpClientAdapter, package:patra/src/catalogue/catalogue_overlay.dart, adapter, _AnswersThenFails, _AnswersThenHangs, calls, client, close (+25 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "dart:math"
Cohesion: 0.22
Nodes (8): dart:math, package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 95 - "catalogue_write_path_test.dart"
Cohesion: 0.05
Nodes (39): _key, _keychain, languageEndonym, load, localeSettingsProvider, LocaleSettingsStore, null, save (+31 more)

### Community 96 - "Patra Frond Compact Mark (three-blade master, 1024px)"
Cohesion: 0.39
Nodes (8): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed), Patra Frond Compact Mark (three-blade master, 1024px), Size rule: compact master at or below 72px, Widened blade spread of the compact fan

### Community 97 - "library_scan_test.dart"
Cohesion: 0.10
Nodes (19): PopupMenuItem, required bool admin,
  bool, client, close, _container, empty, fetch, _item (+11 more)

### Community 98 - "ADR-0001 — A one-finger drag magnifies the page, and the border wins"
Cohesion: 0.25
Nodes (7): ADR-0001 — A one-finger drag magnifies the page, and the border wins, Consequences, Context, Corrections after review, Decision, The prototype, What was tried

### Community 99 - "offlineProvider"
Cohesion: 0.18
Nodes (12): Android job: android/key.properties switch, Build number is github.run_number, ClientDevice headers (client_device.dart), ClientIdentity (app version read off the binary), iOS job: signed TestFlight path or unsigned IPA fallback, MangaFormat.isImageReadable (PDF reads, EPUB cannot), offlineProvider, PageLoading (page_loading.dart) (+4 more)

### Community 100 - "LibraryTypeNaming (lib/src/entity_naming.dart)"
Cohesion: 0.38
Nodes (7): LibraryTypeNaming (lib/src/entity_naming.dart), The fixed French glossary, LibraryType (Manga/Comic/Book/Image/LightNovel/ComicVine), Localization (app_en.arb template, app_fr.arb), Kavita sentinel numbers (ParserConstants ±100000), GET /api/Series/series-detail is deliberately not called, The storyline as a section header, not a tab

### Community 101 - "A profile persists the auth key and nothing else"
Cohesion: 0.33
Nodes (7): apiKey is the opds auth key, one row not a concept, A profile persists the auth key and nothing else, Using the auth key as the request scheme (rejected alternative), LoginDto ignores username/password when ApiKey is passed, POST /api/Plugin/authenticate (rejected alternative), refresh-token on 0.9.0.x must not be leaned on, Token lifetimes are absent from the spec

### Community 102 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 103 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 104 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.32
Nodes (7): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:flutter_riverpod/flutter_riverpod.dart, package:local_auth/local_auth.dart

### Community 105 - "Patra"
Cohesion: 0.29
Nodes (6): Architecture, Development, Install, Patra, Roadmap, Status

### Community 106 - "DownloadsService (<documents>/downloads/<profile>/<chapterId>/)"
Cohesion: 0.24
Nodes (11): DownloadsNotifier must re-read state.value after an await, DownloadsService (<documents>/downloads/<profile>/<chapterId>/), AsyncValue.isResolvedFailure, kavitaClientProvider, No migration into the profiles storage layout, _OfflineHome (an empty state, not the banner returning), OfflineIndicator (a status in the app bar, not a banner), Profile.id = (baseUrl, accountId) (+3 more)

### Community 107 - "ADR-0004 — The auth key is the only secret a profile keeps"
Cohesion: 0.33
Nodes (6): ADR-0004 — The auth key is the only secret a profile keeps, Consequences, Context, Cost, accepted, Decision, Why

### Community 108 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 109 - "AppLocalizations"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsFr, of, LocalizationsDelegate

### Community 110 - "static const"
Cohesion: 0.18
Nodes (11): delete, Keychain, keychainProvider, read, readAll, SecureKeychain, _storage, write (+3 more)

### Community 112 - "ConnectionFailure (connection_failure.dart)"
Cohesion: 0.22
Nodes (9): ConnectionFailureKind.blockedByBrowser, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), android.permission.INTERNET in the main manifest, Kavita (self-hosted server), _PatraShell._labelsFit (the bottom bar measures its labels), The login form validates the address itself, StatefulShellRoute.indexedStack (four tabs) (+1 more)

### Community 113 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 114 - "Map"
Cohesion: 0.20
Nodes (9): File, ReadOverridesNotifier, Map, main, resolve, schema, schemas, spec (+1 more)

### Community 119 - "downloads_screen.dart"
Cohesion: 0.14
Nodes (14): Directory, ../../format.dart, chapterDirProvider, build, bytes, chapter, chapters, _confirmRemove (+6 more)

### Community 126 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.18
Nodes (10): ../auth/session.dart, ../../l10n/generated/app_localizations.dart, offlineProvider, formatBytes, gb, mb, sizeBytes, build (+2 more)

### Community 128 - "catalogue_overlay.dart"
Cohesion: 0.12
Nodes (16): catalogue_provider.dart, fetch, held, live, onDeckOverlay, _onDeckReadProvider, overlaid, _rankingOrNothing (+8 more)

### Community 129 - "List"
Cohesion: 0.18
Nodes (10): int get, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+2 more)

### Community 130 - "CustomPainter"
Cohesion: 0.40
Nodes (5): CustomPainter, _UnfurlPainter, DashedBorderPainter, _DirectionPainter, _FrondPainter

### Community 131 - "routes.dart"
Cohesion: 0.13
Nodes (14): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+6 more)

### Community 132 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 136 - "page_loading.dart"
Cohesion: 0.17
Nodes (12): build, createState, dispose, explain, explainAfter, _explaining, initState, PageImageBuilder (+4 more)

### Community 137 - "connection_failure.dart"
Cohesion: 0.18
Nodes (10): ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message, status (+2 more)

### Community 138 - "The Kavita API client"
Cohesion: 0.50
Nodes (3): Kavita API client — deliberately hand-written, Reaching the server: cleartext, and saying what went wrong, The Kavita API client

### Community 139 - "savedChapterProvider"
Cohesion: 0.50
Nodes (4): savedChapterProvider, build, chapterInfoProvider, _saveProgress

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **2209 isolated node(s):** `Patra design decisions`, `Cutting a Patra release, and what CI does with it`, `Kavita API client — deliberately hand-written`, `Reaching the server: cleartext, and saying what went wrong`, `Auth: several profiles, one active session` (+2204 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2439 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `KavitaClient (lib/src/api/kavita_client.dart)`, `DownloadsService (<documents>/downloads/<profile>/<chapterId>/)`, `ProfilePreferencesStore (profile_preferences.dart)`, `profile_lock_sheet.dart`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `reader_settings_sheet.dart`, `List`, `package:flutter_riverpod/flutter_riverpod.dart`, `StatelessWidget`, `app.dart`, `../api/models.dart`, `static const`, `../../theme.dart`, `continue_hero.dart`, `server_version_test.dart`, `page_backdrop.dart`, `home_screen.dart`, `downloads_screen.dart`, `profile_picker_screen.dart`, `ConsumerWidget`, `package:flutter/material.dart`, `../../l10n/generated/app_localizations.dart`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `KavitaClient (lib/src/api/kavita_client.dart)` to `UserDto.isAdmin (role read from the login response)`, `Profile lock (lib/src/lock/profile_lock.dart)`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `Patra design decisions`, `Cutting a Patra release, and what CI does with it`, `Kavita API client — deliberately hand-written` to the rest of the system?**
  _2209 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Generated Localization Bundle` be split into smaller, more focused modules?**
  _Cohesion score 0.013071895424836602 - nodes in this community are weakly interconnected._
- **Should `French Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.014285714285714285 - nodes in this community are weakly interconnected._