# Graph Report - worktree-green-river-f243  (2026-09-13)

## Corpus Check
- 165 files · ~315,187 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3822 nodes · 5328 edges · 169 communities (143 shown, 22 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 91 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a1b85552`
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
- launch_animation.dart
- profile_picker_test.dart
- patra package manifest
- kavita_client.dart
- page_loading.dart
- settings_screen.dart
- measure_page_shapes.dart
- series_sections_test.dart
- series_detail_screen.dart
- _
- home_screen.dart
- launch_composition.dart
- profile_preferences.dart
- test_support.dart
- client_identity.dart
- StatelessWidget
- profile_picker_screen.dart
- profile_lock_sheet.dart
- downloads_service.dart
- patra_frond.dart
- profile_lock.dart
- downloads_screen.dart
- reader_test.dart
- Continuous vertical reader: zoom and navigation research
- magnify_gesture.dart
- home_hero_test.dart
- deep_link_test.dart
- analyze job (pub get, analyze, test)
- connection_failure_test.dart
- my_application.cc
- login_screen.dart
- test_support.dart
- downloads_provider.dart
- KavitaClient (lib/src/api/kavita_client.dart)
- page_rail.dart
- app.dart
- reader_settings_sheet.dart
- launch_animation_test.dart
- image_cache_store.dart
- client_identity_test.dart
- catalogue_store.dart
- AppDelegate
- _ReaderScreenState
- strip_geometry.dart
- main.dart
- session_scope.dart
- Profile lock (lib/src/lock/profile_lock.dart)
- auth_test.dart
- StatefulWidget
- graphify_merge_driver_test.dart
- kavita_client_test.dart
- dart:convert
- reading_settings.dart
- strip_width.dart
- profile_lock_ui_test.dart
- _
- strip_width_test.dart
- ADR-0003 — A profile is a Kavita account, and there are no local ones
- The per-profile catalogue
- package:flutter_riverpod/flutter_riverpod.dart
- patraAccent = progress/identity, patraOffline = downloads/offline
- isTabletLayout(context)
- profile_switch_test.dart
- resume_point.dart
- locale_settings.dart
- cache_settings.dart
- downloads_provider_test.dart
- ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it
- ../auth/session.dart
- gen_app_icons.sh
- UserDto.isAdmin (role read from the login response)
- cover.dart
- ADR-0002 — One rule decides where reading resumes, and it is ours
- cover_placeholder.dart
- ConsumerWidget
- Compact three-blade frond variant (icons at or under 72px)
- catalogue_overlay_test.dart
- 72px threshold: small icons render from the compact master
- ProfilePreferencesStore (profile_preferences.dart)
- A profile is exactly one Kavita account
- series_offline_test.dart
- saved_chapters_per_profile_test.dart
- page_rail_test.dart
- Map
- Patra palm frond mark (app icon rendering)
- Patra palm frond mark (rasterised launcher artwork)
- magnify_gesture_test.dart
- catalogue_write_path_test.dart
- Patra Frond Compact Mark (three-blade master, 1024px)
- package:flutter/material.dart
- ADR-0001 — A one-finger drag magnifies the page, and the border wins
- offlineProvider
- LibraryTypeNaming (lib/src/entity_naming.dart)
- A profile persists the auth key and nothing else
- Issue tracker: GitHub
- strip_geometry_test.dart
- dart:io
- Patra
- DownloadsService (<documents>/downloads/<profile>/<chapterId>/)
- ADR-0004 — The auth key is the only secret a profile keeps
- Domain Docs
- AppLocalizations
- package:patra/src/api/kavita_client.dart
- MainActivity.kt
- ConnectionFailure (connection_failure.dart)
- Credential
- static const
- The graphify union merge driver (two halves)
- Issue tracker agent skill (GitHub issues via gh)
- Spread
- triage-labels.md
- page_shape_test.dart
- gen-l10n configuration (non-nullable getter)
- bool?
- page_shape.dart
- profile_files.dart
- Where a page stops being a page: the vertical threshold
- api/models.dart
- ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series
- page_loading_test.dart
- catalogue_overlay.dart
- reading_direction.dart
- entity_naming.dart
- page_backdrop.dart
- AuthNotifier
- authProvider
- The Kavita API client
- routes.dart
- The catalogue
- The reader
- Preferences
- catalogue_reads.dart
- SKILL.md
- .github/CLAUDE.md
- continue_hero.dart
- dart:math
- auth/CLAUDE.md
- downloads/CLAUDE.md
- launch/CLAUDE.md
- StripWidthController
- _ProbeThumb
- profile_avatar.dart
- return
- package:flutter_test/flutter_test.dart
- direction_icon.dart
- biometrics.dart
- image_cache_store_test.dart
- entity_naming_test.dart
- reader_settings_sheet_test.dart
- _ThumbStripState
- SignInExpired
- _ServerCardState
- ../../l10n/generated/app_localizations.dart
- build
- _SlotState
- LaunchScope
- _StripChildDelegate

## God Nodes (most connected - your core abstractions)
1. `_` - 66 edges
2. `_` - 32 edges
3. `kavitaClientProvider` - 21 edges
4. `offlineProvider` - 17 edges
5. `authProvider` - 15 edges
6. `build` - 14 edges
7. `Continuous vertical reader: zoom and navigation research` - 13 edges
8. `The per-profile catalogue` - 13 edges
9. `sessionProvider` - 12 edges
10. `_ReaderScreenState` - 12 edges

## Surprising Connections (you probably didn't know these)
- `pubspec version is only a local fallback` --semantically_similar_to--> `Server version`  [INFERRED] [semantically similar]
  pubspec.yaml → CONTEXT.md
- `Dependabot pub ecosystem (weekly)` --references--> `patra package manifest`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `patra package manifest` --conceptually_related_to--> `Registered device`  [INFERRED]
  pubspec.yaml → CONTEXT.md
- `analyze job (pub get, analyze, test)` --conceptually_related_to--> `flutter_lints config with platform dirs excluded`  [INFERRED]
  .github/workflows/build.yml → analysis_options.yaml
- `pumpWidget` --references--> `offlineProvider`  [EXTRACTED]
  test/home_offline_test.dart → lib/src/auth/session.dart

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

## Communities (169 total, 22 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (166): app_localizations_en.dart, app_localizations_fr.dart, class, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem (+158 more)

### Community 1 - "app_localizations_fr.dart"
Cohesion: 0.01
Nodes (153): aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan, backToProfiles (+145 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (153): app_localizations.dart, aboutSectionLabel, aboutVersion, addProfile, appLanguage, appLanguageSystem, appTagline, askServerToScan (+145 more)

### Community 3 - "thumb_strip.dart"
Cohesion: 0.02
Nodes (87): Animation, Duration, Iterable, _accordion, _backfillConcurrent, _baseShare, _baseWidth, build (+79 more)

### Community 4 - "reader_screen.dart"
Cohesion: 0.02
Nodes (87): aspectRatios, barHeight, chapter, chapterId, child, _client, _controller, createState (+79 more)

### Community 5 - "models.dart"
Cohesion: 0.03
Nodes (77): adminRole, ageRestricted, and, apiKey, aspectRatio, aspectRatioFor, ChapterInfo, chapters (+69 more)

### Community 6 - "session.dart"
Cohesion: 0.04
Nodes (55): ../api/account_id.dart, ../api/client_device.dart, ../api/client_identity.dart, AuthState get, accountId, activeId, _activeKey, ageRestricted (+47 more)

### Community 7 - "theme.dart"
Cohesion: 0.04
Nodes (54): AnimationController, base, body, build, color, colors, _controller, controlMaxWidth (+46 more)

### Community 8 - "launch_animation.dart"
Cohesion: 0.04
Nodes (53): GlobalKey, launch_composition.dart, _add, build, _checkedMotion, child, _controller, createState (+45 more)

### Community 9 - "profile_picker_test.dart"
Cohesion: 0.12
Nodes (15): Container, CustomPaint, LoginResult, Opacity, package:patra/src/features/launch/launch_animation.dart, package:patra/src/widgets/dashed_border.dart, box, _dimming (+7 more)

### Community 10 - "patra package manifest"
Cohesion: 0.05
Nodes (50): Dependabot pub ecosystem (weekly), Administrator, Auth key, Avatar, Catalogue, Chapter, Continue (the promotion), Credential (+42 more)

### Community 11 - "kavita_client.dart"
Cohesion: 0.04
Nodes (48): Dio, Dio get, allSeriesForLibrary, apiKey, authKey, _bareDio, bareHttpClient, baseUrl (+40 more)

### Community 12 - "page_loading.dart"
Cohesion: 0.11
Nodes (18): AlignmentGeometry, BoxFit, alignment, build, createState, dispose, explain, explainAfter (+10 more)

### Community 13 - "settings_screen.dart"
Cohesion: 0.06
Nodes (42): ../../downloads/image_cache_store.dart, imageCacheSizeProvider, imageCacheStoreProvider, actionLabel, _avatarSize, build, child, children (+34 more)

### Community 14 - "measure_page_shapes.dart"
Cohesion: 0.04
Nodes (45): HttpClient, _Api, apiKey, base, buffer, chapterInfo, chapters, _client (+37 more)

### Community 15 - "series_sections_test.dart"
Cohesion: 0.08
Nodes (23): int? savedChapter,
  bool, build, cacheDir, _chapter, client, close, fetch, libraryType (+15 more)

### Community 16 - "series_detail_screen.dart"
Cohesion: 0.05
Nodes (40): Chapter, _Buckets, _buildSections, chapter, child, clear, _confirmRemove, copy (+32 more)

### Community 17 - "_"
Cohesion: 0.07
Nodes (39): _, alreadyRunning, any, asked, _askForScan, available, build, canScan (+31 more)

### Community 18 - "home_screen.dart"
Cohesion: 0.06
Nodes (34): AsyncValue, continue_hero.dart, ../launch/launch_animation.dart, Library, ResolvedFailure, _cardMaxWidth, _cardSpacing, _cardWidth (+26 more)

### Community 19 - "launch_composition.dart"
Cohesion: 0.05
Nodes (37): _appIn, appOpacity, appRise, _at, blade, bladeStagger, BladeTurn, dotScale (+29 more)

### Community 20 - "profile_preferences.dart"
Cohesion: 0.04
Nodes (56): abstract class, build, _byProfile, clearLibraryDirection, clearSeriesDirection, copyWith, defaultDirection, deviceDirection (+48 more)

### Community 21 - "test_support.dart"
Cohesion: 0.04
Nodes (44): ReadingDirection? deviceDirection,
  bool, required int chapterId,
  String, available, bytes, catalogueVolumesFixture, channel, chapter, close (+36 more)

### Community 22 - "client_identity.dart"
Cohesion: 0.06
Nodes (35): appName, appVersion, ClientIdentity, ClientPlatform, _describeDevice, deviceId, _deviceIdKey, deviceModel (+27 more)

### Community 23 - "StatelessWidget"
Cohesion: 0.08
Nodes (25): _FlyingFrond, _SplashWordmark, _EmptyBody, _LibraryGridSkeleton, _BottomChrome, _ReaderError, _SettingsCog, _SpineShadow (+17 more)

### Community 24 - "profile_picker_screen.dart"
Cohesion: 0.08
Nodes (23): Profile, Session, _AddFace, _avatarSize, busy, createState, _entering, _error (+15 more)

### Community 25 - "profile_lock_sheet.dart"
Cohesion: 0.07
Nodes (30): biometricsProvider, askProfilePin, _backspace, _biometrics, build, child, chooseProfilePin, choosing (+22 more)

### Community 26 - "downloads_service.dart"
Cohesion: 0.06
Nodes (33): bytes, chapterDir, chapterId, copyWith, _deleteQuietly, dirNameFor, download, _downloadsRoot (+25 more)

### Community 27 - "patra_frond.dart"
Cohesion: 0.06
Nodes (31): Color get, double?, alpha, bladeHalfWidth, bladesOf, boundsOf, build, color (+23 more)

### Community 28 - "profile_lock.dart"
Cohesion: 0.08
Nodes (25): accepts, build, clear, _digest, _flush, forPin, fromJson, hash (+17 more)

### Community 29 - "downloads_screen.dart"
Cohesion: 0.08
Nodes (29): ../downloads/downloads_provider.dart, ../downloads/downloads_service.dart, ../../format.dart, IconData, chapterDirProvider, downloadsProvider, SavedChapter, build (+21 more)

### Community 30 - "reader_test.dart"
Cohesion: 0.04
Nodes (46): CustomScrollView, Key? readerKey,
  int, NeverScrollableScrollPhysics, PageView, required int initialPage,
  ReadingDirection, required int pagesRead,
  int, Scrollable, Slider (+38 more)

### Community 31 - "Continuous vertical reader: zoom and navigation research"
Cohesion: 0.04
Nodes (46): 1. State model, 2. Layout, 3. Gestures and alternate controls, 4. Current-page and progress stability, 5. Navigation target, 6. Delivery sequence, Acceptance and test matrix, `/api/Reader/file-dimensions` and chapter info (+38 more)

### Community 32 - "magnify_gesture.dart"
Cohesion: 0.06
Nodes (31): @immutable, anchor, _band, contain, content, _degenerate, drawnContent, fromLTWH (+23 more)

### Community 33 - "home_hero_test.dart"
Cohesion: 0.07
Nodes (27): NavigatorState, _backdrop, _chapter, client, close, fetch, _iPad, _json (+19 more)

### Community 34 - "deep_link_test.dart"
Cohesion: 0.07
Nodes (28): NavigationBar, package:patra/src/app.dart, package:patra/src/features/login/login_screen.dart, package:patra/src/features/profiles/profile_picker_screen.dart, package:patra/src/features/reader/reader_screen.dart, package:patra/src/routes.dart, required Directory downloadsRoot,
  bool, _app (+20 more)

### Community 35 - "analyze job (pub get, analyze, test)"
Cohesion: 0.09
Nodes (29): Dependabot github-actions ecosystem (weekly), analyze job (pub get, analyze, test), Build the App Bundle, build-android job, build-ios job, Debug APK sideload fallback, Resolve the profile and write ExportOptions.plist, Forget the signing material (always) (+21 more)

### Community 36 - "connection_failure_test.dart"
Cohesion: 0.13
Nodes (14): DioExceptionType?, Object?, package:patra/src/api/connection_failure.dart, _Adapter, body, close, contentType, _failureOf (+6 more)

### Community 37 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 38 - "login_screen.dart"
Cohesion: 0.08
Nodes (25): ../../api/connection_failure.dart, FormState, _askForServer, _buildForm, _busy, child, createState, didChangeDependencies (+17 more)

### Community 39 - "test_support.dart"
Cohesion: 0.06
Nodes (33): CachedNetworkImage, package:patra/src/features/series/series_detail_screen.dart, package:patra/src/theme.dart, package:patra/src/widgets/cover.dart, package:patra/src/widgets/cover_placeholder.dart, _channelGap, client, main (+25 more)

### Community 40 - "downloads_provider.dart"
Cohesion: 0.10
Nodes (24): AsyncNotifier, downloads_service.dart, build, cancel, _cancelTokens, copyWith, _disposed, DownloadsNotifier (+16 more)

### Community 41 - "KavitaClient (lib/src/api/kavita_client.dart)"
Cohesion: 0.13
Nodes (21): ADR-0001 reader magnify gesture, ADR-0003 (a server is an address, a profile is a person), ADR-0004 (the refresh-token pair is gone), One credential, two mechanisms (the account auth key), KavitaClient._bearerIsIrrelevant, ChapterDto.sortOrder is the reading order, Credential (sealed password-or-authKey type), Domain docs (single-context CONTEXT.md and docs/adr/) (+13 more)

### Community 42 - "page_rail.dart"
Cohesion: 0.06
Nodes (32): bottomGap, build, controller, createState, dispose, _documentAt, _dragging, _dragPage (+24 more)

### Community 43 - "app.dart"
Cohesion: 0.10
Nodes (22): features/downloads/downloads_screen.dart, features/home/home_screen.dart, features/library/library_screen.dart, features/login/login_screen.dart, features/profiles/profile_picker_screen.dart, features/reader/reader_screen.dart, features/series/series_detail_screen.dart, features/settings/settings_screen.dart (+14 more)

### Community 44 - "reader_settings_sheet.dart"
Cohesion: 0.09
Nodes (21): direction_icon.dart, ../features/reader/reading_direction.dart, ../features/reader/strip_geometry.dart, _ActionRow, current, direction, _divisions, icon (+13 more)

### Community 45 - "launch_animation_test.dart"
Cohesion: 0.09
Nodes (21): package:flutter/rendering.dart, package:patra/src/features/launch/launch_composition.dart, package:patra/src/widgets/patra_frond.dart, package:patra/src/widgets/patra_wordmark.dart, RenderParagraph, Size, _app, _appOpacity (+13 more)

### Community 46 - "image_cache_store.dart"
Cohesion: 0.10
Nodes (19): dart:isolate, DateTime?, Future, _cacheKey, clear, dir, entries, _lastTrim (+11 more)

### Community 47 - "client_identity_test.dart"
Cohesion: 0.09
Nodes (21): package:patra/src/api/client_device.dart, _android, client, _clientWith, close, delete, _device, _DeviceAdapter (+13 more)

### Community 48 - "catalogue_store.dart"
Cohesion: 0.05
Nodes (39): _catalogueRoot, _deleteSeries, dirNameFor, _file, fromJson, isEmpty, libraries, loadOnDeck (+31 more)

### Community 49 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate, Bool (+6 more)

### Community 50 - "_ReaderScreenState"
Cohesion: 0.27
Nodes (11): libraryNameProvider, _buildReader, _ReaderScreenState, chapterDirectionProvider, _pickDirection, magnifyProvider, profileDirectionProvider, widthFactorProvider (+3 more)

### Community 51 - "strip_geometry.dart"
Cohesion: 0.07
Nodes (27): double get, IndexedWidgetBuilder, anchorAt, build, childCount, decodeWidthFor, estimateMaxScrollOffset, fraction (+19 more)

### Community 52 - "main.dart"
Cohesion: 0.08
Nodes (25): auth, cacheLimit, catalogue, identity, imageCache, keychain, launchingInto, load (+17 more)

### Community 53 - "session_scope.dart"
Cohesion: 0.11
Nodes (19): catalogue/catalogue_provider.dart, auth, build, child, _container, createState, dispose, _entered (+11 more)

### Community 54 - "Profile lock (lib/src/lock/profile_lock.dart)"
Cohesion: 0.14
Nodes (18): AuthState.atLaunch, reading_settings.dart / locale_settings.dart as device defaults, DeviceBiometrics (lib/src/lock/biometrics.dart), isLaunchProvider, The language is the only preference written twice, LaunchStage / launch_composition.dart, The OS launch screen is the ink and nothing else, LaunchAnimation (+10 more)

### Community 55 - "auth_test.dart"
Cohesion: 0.10
Nodes (19): DioException get, package:patra/src/keychain.dart, accountId, apiKey, call, calls, color, _container (+11 more)

### Community 56 - "StatefulWidget"
Cohesion: 0.20
Nodes (15): LaunchAnimation, _LaunchAnimationState, PageImage, _PageImageState, _MagnifyPage, _MagnifyPageState, _PagedView, _PagedViewState (+7 more)

### Community 57 - "graphify_merge_driver_test.dart"
Cohesion: 0.11
Nodes (17): _command, _config, driver, false, _git, graph, inRepo, installed (+9 more)

### Community 58 - "kavita_client_test.dart"
Cohesion: 0.10
Nodes (19): int?, SelectedLibraryNotifier, apiKey, authenticatedStatus, client, close, _FakeKavitaAdapter, fetch (+11 more)

### Community 59 - "dart:convert"
Cohesion: 0.06
Nodes (32): dart:convert, accountIdFrom, _padded, segments, package:patra/src/features/settings/settings_screen.dart, _Adapter, client, close (+24 more)

### Community 60 - "reading_settings.dart"
Cohesion: 0.12
Nodes (16): bool get, leftToRight,
  rightToLeft,, directionNamed, isRightToLeft, isVerticalScroll, _key, _keychain, label (+8 more)

### Community 61 - "strip_width.dart"
Cohesion: 0.04
Nodes (50): Drag?, _anchor, build, _capture, child, _clampedBy, clampWidthFactor, controller (+42 more)

### Community 62 - "profile_lock_ui_test.dart"
Cohesion: 0.08
Nodes (23): package:patra/src/auth/session.dart, package:patra/src/lock/biometrics.dart, package:patra/src/lock/profile_lock.dart, lea, main, _profile, romain, call (+15 more)

### Community 63 - "_"
Cohesion: 0.11
Nodes (21): FutureProvider, _, CatalogueDeps, CatalogueRead, _deps, _fetch, into, invalidatable (+13 more)

### Community 64 - "strip_width_test.dart"
Cohesion: 0.04
Nodes (48): dart:typed_data, package:patra/src/features/reader/strip_width.dart, RenderBox, RenderSliverMultiBoxAdaptor?, required double to,
  int, _aspectRatioFor, bottom, _brokenImage (+40 more)

### Community 65 - "ADR-0003 — A profile is a Kavita account, and there are no local ones"
Cohesion: 0.13
Nodes (13): ADR-0003 — A profile is a Kavita account, and there are no local ones, Consequences, Context, Cost, accepted, Decision, No invite flow is shipped, Why, ADR-0005 — The catalogue is what the device remembers, and it is files (+5 more)

### Community 66 - "The per-profile catalogue"
Cohesion: 0.15
Nodes (16): The entry round trip is hidden by the launch animation, Cache-first overlay precedence rule, The per-profile catalogue, A cover is never pinned; the answer is a real placeholder, drift (rejected, but not for the usual reason), Files, not a database, hive_ce (the near-free alternative, rejected), isResolvedFailure means something new (+8 more)

### Community 67 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (26): delete, keychainProvider, read, readAll, _storage, write, package:flutter_riverpod/flutter_riverpod.dart, package:flutter_secure_storage/flutter_secure_storage.dart (+18 more)

### Community 68 - "patraAccent = progress/identity, patraOffline = downloads/offline"
Cohesion: 0.20
Nodes (12): patraAccent = progress/identity, patraOffline = downloads/offline, /api/Series/currently-reading does not mean what it says, Claude Design handoff (.claude/design/HANDOFF.md), featuredSeries (continue_hero.dart), hasReadingProgress (the hero asks about the series), markChapterRead (mark-multiple-read / -unread), POST /api/Series/on-deck, readOverridesProvider (optimistic progress writes) (+4 more)

### Community 69 - "isTabletLayout(context)"
Cohesion: 0.15
Nodes (15): A column of rows runs the full width at the app's gutter, A shelf and the reader canvas run edge to edge, A grid of cards takes another column, not a bigger card, ImageCacheStore.trim (a capped image cache), isTabletLayout(context), A swipe pane and a button must never scale with the screen, The reader must never wrap itself in a LayoutBuilder, The system's chrome comes and goes with the reader's (+7 more)

### Community 70 - "profile_switch_test.dart"
Cohesion: 0.06
Nodes (34): package:patra/src/session_scope.dart, required Credential credential,
  ClientIdentity, _app, attempts, close, fetch, identity, _lea (+26 more)

### Community 71 - "resume_point.dart"
Cohesion: 0.13
Nodes (14): bySortOrder, entries, entryCoverUrl, entryUnderWay, inVolumes, loose, orderedChapters, ResumeEntry (+6 more)

### Community 72 - "locale_settings.dart"
Cohesion: 0.13
Nodes (14): Keychain, SecureKeychain, _key, _keychain, languageEndonym, load, localeSettingsProvider, LocaleSettingsStore (+6 more)

### Community 73 - "cache_settings.dart"
Cohesion: 0.15
Nodes (15): int get, ../keychain.dart, build, bytes, defaultLimit, ImageCacheLimit, ImageCacheLimitNotifier, imageCacheSettingsProvider (+7 more)

### Community 74 - "downloads_provider_test.dart"
Cohesion: 0.12
Nodes (15): package:patra/src/downloads/downloads_provider.dart, ProviderContainer, adapter, _chapter, close, container, fetch, gate (+7 more)

### Community 75 - "ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it"
Cohesion: 0.20
Nodes (9): ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it, Consequences, Considered options, and why not, Context, Cost, accepted, Decision, Prototype, Sources (+1 more)

### Community 76 - "../auth/session.dart"
Cohesion: 0.12
Nodes (15): ../auth/session.dart, catalogue_store.dart, _storeOrNull, CataloguePrefetch, cataloguePrefetchProvider, catalogueRootProvider, catalogueStoreProvider, _done (+7 more)

### Community 77 - "gen_app_icons.sh"
Cohesion: 0.27
Nodes (8): Android adaptive icon (drawable/patra_mark.xml), FrondGeometry.boundsOf, The header draws the five-blade fan at 24pt, The palm frond mark (five-blade and compact three-blade), PatraFrond (lib/src/widgets/patra_frond.dart), android_icon(), ios_icon(), gen_app_icons.sh script

### Community 78 - "UserDto.isAdmin (role read from the login response)"
Cohesion: 0.32
Nodes (8): Admin scan request from the Library tab's app-bar menu, AuthNotifier.clearAdmin (a 403 clears the flag), currentLibraryProvider, DashedBorderPainter (the mark for a place to fill), An empty library is a state, not a blank screen, POST /api/Library/scan (admin only), LibraryScanNotifier, UserDto.isAdmin (role read from the login response)

### Community 79 - "cover.dart"
Cohesion: 0.12
Nodes (16): cover_placeholder.dart, build, CoverImage, CoverTile, headers, memCacheWidth, onTap, progress (+8 more)

### Community 80 - "ADR-0002 — One rule decides where reading resumes, and it is ours"
Cohesion: 0.18
Nodes (11): ADR-0002 — One rule decides where reading resumes, and it is ours, Consequence, Context, Home screen Continue hero, GET /api/Reader/continue-point (deliberately uncalled), Cost, accepted, Decision, readOverridesProvider (optimistic write) (+3 more)

### Community 81 - "cover_placeholder.dart"
Cohesion: 0.09
Nodes (21): _apart, _bandFor, _brighter, build, choice, CoverPlaceholder, coverPlaceholderTones, _dimmest (+13 more)

### Community 82 - "ConsumerWidget"
Cohesion: 0.11
Nodes (33): catalogue, ConsumerWidget, kavitaClientProvider, offlineProvider, save, savedChapterProvider, build, ContinueHero (+25 more)

### Community 83 - "Compact three-blade frond variant (icons at or under 72px)"
Cohesion: 0.19
Nodes (13): Accent-coloured centre blade and stem, 72px master-selection rule for icon rasterisation, Compact three-blade frond variant (icons at or under 72px), Five-blade fan frond variant (icons above 72px), iOS App Icon 40x40@1x (40px, iPad notification/spotlight), iOS App Icon 40x40@2x (80px, iPhone/iPad spotlight), iOS App Icon 40x40@3x (120px, iPhone spotlight), iOS App Icon 50x50@1x (50px, legacy iPad spotlight) (+5 more)

### Community 84 - "catalogue_overlay_test.dart"
Cohesion: 0.06
Nodes (33): HttpClientAdapter, package:patra/src/catalogue/catalogue_overlay.dart, adapter, _AnswersThenFails, _AnswersThenHangs, calls, client, close (+25 more)

### Community 85 - "72px threshold: small icons render from the compact master"
Cohesion: 0.20
Nodes (12): Accent-purple centre blade and stem carry identity, iOS Marketing Icon 1024px (five-blade frond), App icons are opaque RGB with no alpha channel, Patra palm frond mark (five capsule blades on ink), 72px threshold: small icons render from the compact master, iOS Notification Icon 20px (compact frond), iOS Notification Icon 40px (compact frond), iOS Notification Icon 60px (compact frond) (+4 more)

### Community 86 - "ProfilePreferencesStore (profile_preferences.dart)"
Cohesion: 0.25
Nodes (11): GET /api/Reader/chapter-info pageDimensions, localeProvider and languageEndonym, magnify_gesture.dart (one-finger drag magnifier), mockSecureStorage() in test_support.dart, ProfilePreferencesStore (profile_preferences.dart), Serialized progress posts and the last-page rule, The reader's cog and reader_settings_sheet.dart, ReadingDirection (verticalScroll is a direction, not a mode) (+3 more)

### Community 87 - "A profile is exactly one Kavita account"
Cohesion: 0.22
Nodes (11): accountIdFrom(token) — the key is derivable offline, Local profiles / personas (rejected), The lock belongs on unrestricted profiles, There is no kids mode to build, A profile is exactly one Kavita account, ProgressDto has no user field, Server-side access gating (MemberDto.libraries, AgeRestrictionDto), An auth key is a whole account (+3 more)

### Community 88 - "series_offline_test.dart"
Cohesion: 0.06
Nodes (34): DioException, FilledButton, InkWell, package:patra/src/downloads/downloads_service.dart, package:patra/src/widgets/save_pill.dart, _chapter, client, close (+26 more)

### Community 89 - "saved_chapters_per_profile_test.dart"
Cohesion: 0.11
Nodes (18): Locale, _catalogueRoot, client, close, fetch, _lea, locale, main (+10 more)

### Community 90 - "page_rail_test.dart"
Cohesion: 0.08
Nodes (23): , package:patra/src/features/reader/page_rail.dart, ScrollController, 8, _bottomGap, geometry, _Harness, _heightAt (+15 more)

### Community 91 - "Map"
Cohesion: 0.19
Nodes (19): OfflineNotifier, sessionProvider, PageShapesNotifier, ReadOverridesNotifier, ProfileLocksNotifier, profileLockStoreProvider, clear, DirectionMapNotifier (+11 more)

### Community 92 - "Patra palm frond mark (app icon rendering)"
Cohesion: 0.36
Nodes (10): iOS App Icon 60x60@2x (120px) — five-blade frond, iOS App Icon 60x60@3x (180px) — five-blade frond, Patra palm frond mark (app icon rendering), iOS App Icon 72x72@1x (72px) — compact three-blade frond, Compact master below 72px (icon size rule), iOS App Icon 72x72@2x (144px) — five-blade frond, iOS App Icon 76x76@1x (76px) — five-blade frond, just above the compact threshold, iOS icons carry no alpha channel (opaque RGB, 8-bit truecolor) (+2 more)

### Community 93 - "Patra palm frond mark (rasterised launcher artwork)"
Cohesion: 0.31
Nodes (9): Compact-master size rule at 72px, Legacy Android launcher icon, hdpi (72px), Platform 22.7% corner baked into the bitmap, Legacy Android launcher icon, mdpi (48px), Patra palm frond mark (rasterised launcher artwork), Legacy Android launcher icon, xhdpi (96px), Legacy Android launcher icon, xxhdpi (144px), Accent centre blade on the ink ground (+1 more)

### Community 94 - "magnify_gesture_test.dart"
Cohesion: 0.25
Nodes (7): package:flutter/painting.dart, package:patra/src/features/reader/magnify_gesture.dart, _content, _from, main, _under, _viewport

### Community 95 - "catalogue_write_path_test.dart"
Cohesion: 0.11
Nodes (17): package:patra/src/catalogue/catalogue_reads.dart, asked, client, close, container, fetch, _lea, libraries (+9 more)

### Community 96 - "Patra Frond Compact Mark (three-blade master, 1024px)"
Cohesion: 0.39
Nodes (8): Accent centre blade and stem, Five-blade fan geometry, Parchment alpha ladder on the outer blades, Patra Frond Mark (five-blade master, 1024px), Patra ink ground (#16141C full-bleed), Patra Frond Compact Mark (three-blade master, 1024px), Size rule: compact master at or below 72px, Widened blade spread of the compact fan

### Community 97 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (43): Completer, dart:async, package:flutter/material.dart, package:patra/l10n/generated/app_localizations.dart, package:patra/src/features/reader/thumb_strip.dart, package:patra/src/settings/locale_settings.dart, PopupMenuItem, required bool admin,
  bool (+35 more)

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

### Community 103 - "strip_geometry_test.dart"
Cohesion: 0.08
Nodes (24): package:patra/src/features/reader/strip_geometry.dart, 8, controller, fraction, geometry, _heightAt, images, main (+16 more)

### Community 104 - "dart:io"
Cohesion: 0.05
Nodes (42): dart:io, ConnectionFailure, ConnectionFailureKind, detail, from, _fromStatus, kind, message (+34 more)

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

### Community 110 - "package:patra/src/api/kavita_client.dart"
Cohesion: 0.06
Nodes (29): Finder get, IconButton, package:patra/src/api/kavita_client.dart, package:patra/src/features/home/home_screen.dart, package:patra/src/resume_point.dart, _Adapter, close, _cloud (+21 more)

### Community 112 - "ConnectionFailure (connection_failure.dart)"
Cohesion: 0.22
Nodes (9): ConnectionFailureKind.blockedByBrowser, Cleartext HTTP permitted on both platforms, ConnectionFailure (connection_failure.dart), android.permission.INTERNET in the main manifest, Kavita (self-hosted server), _PatraShell._labelsFit (the bottom bar measures its labels), The login form validates the address itself, StatefulShellRoute.indexedStack (four tabs) (+1 more)

### Community 113 - "Credential"
Cohesion: 0.67
Nodes (3): AuthKeyCredential, Credential, PasswordCredential

### Community 114 - "static const"
Cohesion: 0.12
Nodes (16): ../features/launch/launch_animation.dart, build, _gap, _markHeight, PatraMasthead, showTagline, _size, build (+8 more)

### Community 119 - "page_shape_test.dart"
Cohesion: 0.13
Nodes (14): package:patra/src/features/reader/page_shape.dart, Set, _chapter, container, libraryType, main, _measured, _page (+6 more)

### Community 126 - "page_shape.dart"
Cohesion: 0.14
Nodes (13): LibraryType, LibraryTypeNaming, build, isVertical, libraryType, measuredPagesNeeded, _median, middle (+5 more)

### Community 128 - "Where a page stops being a page: the vertical threshold"
Cohesion: 0.15
Nodes (12): A second library, one anybody can re-run: Kavita's public demo, How to re-run it, Sources, The answer, The measurement — one real library, The question, What #57 implements, What is still thin (+4 more)

### Community 129 - "api/models.dart"
Cohesion: 0.18
Nodes (10): api/models.dart, firstOf, indexOf, length, of, _slotOfPage, slots, spanOf (+2 more)

### Community 130 - "ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series"
Cohesion: 0.18
Nodes (10): A direction per library, shipped (#65), ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series, Amendment — 2026-09-13 (#56), Amendment — 2026-09-13 (#57), Amendment — 2026-09-13 (#58), Amendment — 2026-09-13 (#65), Consequences, Considered options (+2 more)

### Community 131 - "page_loading_test.dart"
Cohesion: 0.16
Nodes (14): dart:ui, Image, ImageInfo, ImageProvider, package:flutter/foundation.dart, package:patra/src/features/reader/page_loading.dart, _Arrives, _drawn (+6 more)

### Community 132 - "catalogue_overlay.dart"
Cohesion: 0.12
Nodes (17): catalogue_provider.dart, fetch, held, heldSpine, live, onDeckOverlay, _onDeckReadProvider, overlaid (+9 more)

### Community 133 - "reading_direction.dart"
Cohesion: 0.09
Nodes (22): canPromoteToLibrary, canPromoteToProfile, ChapterDirection, ChapterDirectionKey, detected, detectedDirectionProvider, device, direction (+14 more)

### Community 134 - "entity_naming.dart"
Cohesion: 0.18
Nodes (10): chaptersTitle, chapterTitle, continueChapterLabel, continueVolumeLabel, numberedChapterLabel, resumeTitle, specialsTitle, storylineTitle (+2 more)

### Community 135 - "page_backdrop.dart"
Cohesion: 0.18
Nodes (10): _artwork, chapterId, _fade, _hidden, _maxAspect, page, _scrim, seriesId (+2 more)

### Community 136 - "AuthNotifier"
Cohesion: 0.25
Nodes (9): AuthNotifier, AuthState, clientIdentityProvider, _commit, initialAuthStateProvider, resume, sessionStorageProvider, signInProvider (+1 more)

### Community 137 - "authProvider"
Cohesion: 0.15
Nodes (15): authProvider, profileCatalogueProvider, profileDownloadsProvider, _ProfileFace, LibraryScanNotifier, scan, build, initState (+7 more)

### Community 138 - "The Kavita API client"
Cohesion: 0.50
Nodes (3): Kavita API client — deliberately hand-written, Reaching the server: cleartext, and saying what went wrong, The Kavita API client

### Community 139 - "routes.dart"
Cohesion: 0.12
Nodes (15): _held, linksToContent, loginLocation, only, PendingLink, profiles, profilesLocation, query (+7 more)

### Community 143 - "catalogue_reads.dart"
Cohesion: 0.14
Nodes (13): catalogue_overlay.dart, catalogue_read.dart, Series, SeriesMetadata, libraries, libraryTypeProvider, list, onDeck (+5 more)

### Community 146 - "continue_hero.dart"
Cohesion: 0.11
Nodes (18): ../../catalogue/catalogue_reads.dart, ../../entity_naming.dart, best, ContinueHeroData, _coverWidth, _coverWidthTablet, data, date (+10 more)

### Community 147 - "dart:math"
Cohesion: 0.15
Nodes (12): CustomPainter, dart:math, _UnfurlPainter, _Hatch, color, DashedBorderPainter, paint, radius (+4 more)

### Community 153 - "profile_avatar.dart"
Cohesion: 0.15
Nodes (12): ../api/kavita_client.dart, build, dimmed, hex, _Initial, on, profile, ProfileAvatar (+4 more)

### Community 154 - "return"
Cohesion: 0.05
Nodes (40): client_identity.dart, kavita_client.dart, announceDevice, identity, null, renameTarget, models.dart, package:dio/dio.dart (+32 more)

### Community 155 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.10
Nodes (18): File, package:flutter_test/flutter_test.dart, package:patra/src/api/account_id.dart, package:patra/src/api/models.dart, package:patra/src/features/reader/spread_layout.dart, _jwt, main, seg (+10 more)

### Community 156 - "direction_icon.dart"
Cohesion: 0.18
Nodes (10): Color, ReadingDirection, build, color, direction, DirectionIcon, paint, shouldRepaint (+2 more)

### Community 157 - "biometrics.dart"
Cohesion: 0.32
Nodes (7): available, Biometrics, DeviceBiometrics, NoBiometrics, prompt, package:local_auth/local_auth.dart, FakeBiometrics

### Community 158 - "image_cache_store_test.dart"
Cohesion: 0.25
Nodes (7): Directory, ImageCacheStore, package:patra/src/downloads/image_cache_store.dart, dir, main, store, write

### Community 159 - "entity_naming_test.dart"
Cohesion: 0.25
Nodes (7): package:patra/l10n/generated/app_localizations_en.dart, package:patra/l10n/generated/app_localizations_fr.dart, package:patra/src/entity_naming.dart, chapter, en, fr, main

### Community 160 - "reader_settings_sheet_test.dart"
Cohesion: 0.15
Nodes (16): DirectionPicked, DirectionPromoted, DirectionPromotedToLibrary, LibraryDirectionCleared, ReaderSettingsOutcome, SeriesDirectionCleared, package:patra/src/settings/reading_settings.dart, package:patra/src/widgets/reader_settings_sheet.dart (+8 more)

### Community 161 - "_ThumbStripState"
Cohesion: 0.67
Nodes (3): ThumbStrip, _ThumbStripState, TickerProviderStateMixin

### Community 163 - "_ServerCardState"
Cohesion: 0.20
Nodes (12): ConsumerState, ConsumerStatefulWidget, serverReachableProvider, serverVersionProvider, LoginScreen, _LoginScreenState, ProfilePickerScreen, _ProfilePickerScreenState (+4 more)

### Community 164 - "../../l10n/generated/app_localizations.dart"
Cohesion: 0.22
Nodes (7): ../../l10n/generated/app_localizations.dart, formatBytes, gb, mb, sizeBytes, build, OfflineIndicator

### Community 166 - "_SlotState"
Cohesion: 0.33
Nodes (6): LaunchLogoSlot, _LaunchLogoSlotState, LaunchWordmarkSlot, _LaunchWordmarkSlotState, _SlotState, W

## Ambiguous Edges - Review These
- `Dependabot github-actions ecosystem (weekly)` → `Upload to the internal test track`  [AMBIGUOUS]
  .github/dependabot.yml · relation: conceptually_related_to

## Knowledge Gaps
- **2676 isolated node(s):** `XCTest`, `localeName`, `delegate`, `localizationsDelegates`, `supportedLocales` (+2671 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2922 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Dependabot github-actions ecosystem (weekly)` and `Upload to the internal test track`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Profile lock (lib/src/lock/profile_lock.dart)` connect `Profile lock (lib/src/lock/profile_lock.dart)` to `KavitaClient (lib/src/api/kavita_client.dart)`, `DownloadsService (<documents>/downloads/<profile>/<chapterId>/)`, `ProfilePreferencesStore (profile_preferences.dart)`, `profile_lock_sheet.dart`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `api/models.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `catalogue_overlay.dart`, `resume_point.dart`, `../auth/session.dart`, `catalogue_reads.dart`, `home_screen.dart`, `profile_avatar.dart`, `return`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `suggestsLock (the suggestion goes to the unrestricted profile)` connect `KavitaClient (lib/src/api/kavita_client.dart)` to `UserDto.isAdmin (role read from the login response)`, `Profile lock (lib/src/lock/profile_lock.dart)`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **What connects `XCTest`, `localeName`, `delegate` to the rest of the system?**
  _2676 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.011976047904191617 - nodes in this community are weakly interconnected._
- **Should `app_localizations_fr.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.012987012987012988 - nodes in this community are weakly interconnected._