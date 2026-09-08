/// The six questions the catalogue answers, and the one thing derived from
/// them.
///
/// These used to be declared at the top of the three screens that draw them —
/// the Library tab, the series screen and Home — which is how the fetch behind
/// each came to be public: pull-to-refresh had to reach it from the screen,
/// and there was nowhere else for it to live. It also meant Home imported a
/// 1194-line series screen to reach one provider, and that the module holding
/// the overlay rule held none of the reads that apply it.
///
/// They live here now, and each is **what it asks for and what it writes** —
/// `catalogue_read.dart` owns the order those two happen in, and why. What a
/// screen imports is this file; what it can reach is [CatalogueRead]'s three
/// handles.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import 'catalogue_read.dart';

/// The libraries this profile can see.
///
/// **One question both tabs ask**, deliberately, so they cannot disagree
/// about which libraries exist — which is also why Home's own offline gate
/// consults the catalogue from the moment this read exists.
///
/// The write **replaces**: a library this profile has lost access to has to
/// disappear, and merging would keep it for good. It then starts the eager
/// fill over every library named, so one never opened is still navigable
/// offline — hung off this answer rather than off a tab, because Home asks
/// for this list too and one trigger is what keeps the two from being two
/// rules.
///
/// An empty stored library list counts as nothing stored rather than as an
/// answer: a profile with no libraries at all has nothing to navigate
/// offline, and the screen it lands on is the same one either way.
final libraries = CatalogueRead.spine<List<Library>>(
  request: (client) => client.libraries(),
  write: (into, libraries) async {
    await into.store.putLibraries(libraries);
    unawaited(
      into.prefetch.run(
        client: into.client,
        store: into.store,
        libraries: libraries,
      ),
    );
  },
  held: (spine) => spine.libraries.isEmpty ? null : spine.libraries,
);

/// The type of one library, which decides what its series are made of and what
/// those parts are called. Falls back to manga while the list is in flight —
/// the wording settles as soon as it lands, and no screen has to wait on it.
///
/// Derived rather than fetched, so it is a plain provider and has no request
/// of its own to refresh. It reads [libraries] and not its fetch, or offline
/// a comic library would say "chapitre".
final libraryTypeProvider = Provider.autoDispose.family<LibraryType, int>((
  ref,
  libraryId,
) {
  final list = ref.watch(libraries.provider).value;
  if (list == null) return LibraryType.manga;
  for (final library in list) {
    if (library.id == libraryId) return library.type;
  }
  return LibraryType.manga;
});

/// Every series in one library, and the catalogue's copy of that list.
///
/// The write tells the eager fill this library is done, because opening the
/// tab asks for the library list and for the selected library at once — and
/// the fill has no reason to page a library the tab has just paged itself.
/// That is the whole of the bookkeeping between the two, and it is why a
/// write is handed the prefetch as well as the store.
///
/// A library stored as **empty** is an answer here and not an absence: an
/// empty library is a state the grid has copy for, and falling through to the
/// failure would replace that copy with a retry button.
final seriesForLibrary = CatalogueRead.spinePerKey<List<Series>, int>(
  request: (client, libraryId) => client.allSeriesForLibrary(libraryId),
  write: (into, libraryId, series) async {
    await into.store.putSeriesList(libraryId, series);
    into.prefetch.markStored(libraryId);
  },
  held: (spine, libraryId) => spine.series[libraryId],
);

/// The next thing to read in each series — the "On deck" shelf, and the
/// candidates the Continue hero is promoted from.
///
/// **One request answers both, because it is one question.** Kavita builds
/// this from `PagesRead > 0 && PagesRead < Pages` plus a recency clause
/// (`LatestReadDate >= now - OnDeckProgressDays`, or a chapter added inside
/// `OnDeckUpdateDays`), which is exactly "started, unfinished, and still
/// live". The hero used to come from `/api/Series/currently-reading`
/// instead, on the reading that its name is the question — and it is not:
/// Kavita builds *that* from `ReadLast GreaterThan OnDeckProgressDays`, a
/// comparison `SeriesFilter.HasReadLast` deliberately inverts into
/// `MaxDate < now - N`. It is the pile you started and have not touched in
/// over a month, the **complement** of this one, so anybody reading
/// regularly had no hero at all while this very shelf listed what they were
/// reading.
///
/// What is stored is the server's own ranking rather than structure, and it is
/// drawn with no decoration: the app bar's struck-through cloud already says
/// the answer may be old, and per ADR-0005 an individual row never carries a
/// mark of its own.
final onDeck = CatalogueRead.onDeck(
  request: (client) => client.onDeck(),
  write: (into, series) => into.store.putOnDeck(series),
);

/// A series' volumes and their chapters, and the catalogue's copy of them.
///
/// Volumes stay a **trace of what was actually opened**: nothing prefetches
/// them, because a device that browsed a 2000-series library would otherwise
/// hold every chapter of all of it.
///
/// A [StoredRead], because the series screen's rows need the second fact —
/// what is laid over a row depends on whether the server answered for it. Its
/// `overlaid` handle is the only one anything asks for; Home's Continue card
/// takes the value.
///
/// That card is why this is shared rather than duplicated: it is picked out of
/// the On deck answer and resumes from these volumes, so a card offline draws
/// exactly where the featured series happens to have been opened before. Where
/// it has not, the overlay resolves into the fetch's failure and the shelf
/// keeps its series.
final volumes = CatalogueRead.storedPerSeries<List<Volume>>(
  request: (client, seriesId) => client.volumes(seriesId),
  write: (into, seriesId, volumes) => into.store.putVolumes(seriesId, volumes),
  held: (stored) => stored.volumes,
);

/// The series' own row — its library name, and the series-level tally the
/// hero's ring is drawn from.
final series = CatalogueRead.storedPerSeries<Series>(
  request: (client, seriesId) => client.series(seriesId),
  write: (into, _, series) => into.store.putSeries(series),
  held: (stored) => stored.series,
);

/// Who made the series and what it is about.
final seriesMetadata = CatalogueRead.storedPerSeries<SeriesMetadata>(
  request: (client, seriesId) => client.seriesMetadata(seriesId),
  write: (into, seriesId, metadata) =>
      into.store.putSeriesMetadata(seriesId, metadata),
  held: (stored) => stored.metadata,
);
