/// Minimal DTOs for the Kavita API (v0.9).
/// Only the fields the app actually uses are mapped; parsing is defensive
/// because Kavita omits null fields in some responses.
library;

class UserDto {
  const UserDto({
    required this.username,
    required this.token,
    required this.refreshToken,
    required this.apiKey,
    this.roles = const [],
  });

  final String username;
  final String token;
  final String refreshToken;
  final String apiKey;

  /// Kavita's roles for this account, as `/api/Account/login` returns them.
  final List<String> roles;

  /// Kavita's `PolicyConstants.AdminRole`.
  ///
  /// Its `AdminPolicy` is `RequireRole("Admin")`, and that is what guards
  /// every scan endpoint — so this is what decides whether a scan can be
  /// asked for at all.
  static const adminRole = 'Admin';

  bool get isAdmin => roles.contains(adminRole);

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    username: json['username'] as String? ?? '',
    token: json['token'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    roles: [
      for (final role in json['roles'] as List<dynamic>? ?? const [])
        if (role is String) role,
    ],
  );
}

/// Kavita's `LibraryType`. The values are the wire format, so they are pinned.
///
/// The type decides what a series is made of and what those parts are called:
/// a comic has issues where a manga has chapters, and a book library has no
/// chapter level at all. Kavita words its whole series page from this.
enum LibraryType {
  manga(0),
  comic(1),
  book(2),
  image(3),
  lightNovel(4),
  comicVine(5);

  const LibraryType(this.id);

  final int id;

  static LibraryType fromId(int? id) =>
      LibraryType.values.firstWhere((t) => t.id == id, orElse: () => manga);

  /// Comics count issues, not chapters.
  bool get usesIssues => this == comic || this == comicVine;

  /// Book libraries have no chapter level: a volume *is* the book.
  bool get usesBooks => this == book || this == lightNovel;

  /// Whether volumes and chapters without a volume read as one story.
  ///
  /// Kavita hides its Storyline tab for both comic types (an issue run is not
  /// a storyline) and for book libraries, where volumes are the only unit.
  bool get hasStoryline => this == manga || this == image;
}

/// Kavita's `MangaFormat`: what the files behind a series actually are.
enum MangaFormat {
  image(0),
  archive(1),
  unknown(2),
  epub(3),
  pdf(4);

  const MangaFormat(this.id);

  final int id;

  static MangaFormat fromId(int? id) =>
      MangaFormat.values.firstWhere((f) => f.id == id, orElse: () => unknown);

  /// Whether our page reader can show it.
  ///
  /// A PDF can: Kavita rasterises it into one image per page on demand, and
  /// the reader-image query asks it to. An EPUB cannot — it is reflowable
  /// text, the server has no image path for it at all (`ReadingItemService
  /// .Extract` does nothing for Epub), and it needs the `/api/Book` endpoints
  /// and a reader of its own.
  bool get isImageReadable => this != epub;
}

class LibraryDto {
  const LibraryDto({required this.id, required this.name, required this.type});

  final int id;
  final String name;
  final LibraryType type;

  factory LibraryDto.fromJson(Map<String, dynamic> json) => LibraryDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    type: LibraryType.fromId(json['type'] as int?),
  );
}

class SeriesDto {
  const SeriesDto({
    required this.id,
    required this.name,
    required this.libraryId,
    required this.libraryName,
    required this.pages,
    required this.pagesRead,
  });

  final int id;
  final String name;
  final int libraryId;
  final String libraryName;
  final int pages;
  final int pagesRead;

  factory SeriesDto.fromJson(Map<String, dynamic> json) => SeriesDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    libraryId: json['libraryId'] as int? ?? 0,
    libraryName: json['libraryName'] as String? ?? '',
    pages: json['pages'] as int? ?? 0,
    pagesRead: json['pagesRead'] as int? ?? 0,
  );
}

/// The handful of metadata fields the series hero shows.
class SeriesMetadataDto {
  const SeriesMetadataDto({
    this.summary = '',
    this.writers = const [],
    this.genres = const [],
    this.releaseYear = 0,
  });

  final String summary;
  final List<String> writers;
  final List<String> genres;
  final int releaseYear;

  static List<String> _names(Object? list, String key) => [
    for (final entry in (list as List<dynamic>? ?? []))
      if (entry is Map &&
          entry[key] is String &&
          (entry[key] as String).isNotEmpty)
        entry[key] as String,
  ];

  factory SeriesMetadataDto.fromJson(Map<String, dynamic> json) =>
      SeriesMetadataDto(
        summary: json['summary'] as String? ?? '',
        writers: _names(json['writers'], 'name'),
        genres: _names(json['genres'], 'title'),
        releaseYear: json['releaseYear'] as int? ?? 0,
      );
}

class VolumeDto {
  const VolumeDto({
    required this.id,
    required this.name,
    required this.minNumber,
    required this.pages,
    required this.pagesRead,
    required this.chapters,
  });

  /// Kavita sentinel volume numbers, from `ParserConstants`: the pseudo-volumes
  /// holding chapters that belong to no volume, and specials.
  ///
  /// The **sign is what tells them apart** — same magnitude, opposite signs —
  /// so they must be compared exactly. No real volume comes near 100000.
  static const looseLeafNumber = -100000;
  static const specialsNumber = 100000;

  final int id;
  final String name;
  final num minNumber;
  final int pages;
  final int pagesRead;
  final List<ChapterDto> chapters;

  VolumeDto withChapters(List<ChapterDto> chapters) => VolumeDto(
    id: id,
    name: name,
    minNumber: minNumber,
    pages: pages,
    pagesRead: pagesRead,
    chapters: chapters,
  );

  bool get isLooseLeaf => minNumber == looseLeafNumber;
  bool get isSpecials => minNumber == specialsNumber;

  factory VolumeDto.fromJson(Map<String, dynamic> json) => VolumeDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    minNumber: json['minNumber'] as num? ?? 0,
    pages: json['pages'] as int? ?? 0,
    pagesRead: json['pagesRead'] as int? ?? 0,
    chapters: (json['chapters'] as List<dynamic>? ?? [])
        .map((c) => ChapterDto.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class ChapterDto {
  const ChapterDto({
    required this.id,
    required this.title,
    required this.titleName,
    required this.range,
    required this.minNumber,
    required this.pages,
    required this.pagesRead,
    required this.isSpecial,
    this.sortOrder = 0,
    this.format = MangaFormat.unknown,
  });

  /// Kavita sentinel for the placeholder chapter of a volume that has no
  /// chapter breakdown (`ParserConstants.DefaultChapterNumber`): such a chapter
  /// represents the whole volume.
  static const defaultNumber = -100000;

  final int id;

  /// Often just the chapter number as a string; [titleName] holds the real
  /// title from metadata when there is one.
  final String title;
  final String titleName;
  final String range;
  final num minNumber;
  final int pages;
  final int pagesRead;
  final bool isSpecial;

  /// Kavita's own reading order, which is not the order of the JSON array:
  /// the server sorts every list it builds on this.
  final num sortOrder;

  /// What the files are. Our reader only handles the image formats.
  final MangaFormat format;

  ChapterDto copyWith({int? pagesRead}) => ChapterDto(
    id: id,
    title: title,
    titleName: titleName,
    range: range,
    minNumber: minNumber,
    pages: pages,
    pagesRead: pagesRead ?? this.pagesRead,
    isSpecial: isSpecial,
    sortOrder: sortOrder,
    format: format,
  );

  /// True for the placeholder chapter Kavita creates inside a volume with no
  /// chapter breakdown.
  bool get isVolumePlaceholder => minNumber == defaultNumber && !isSpecial;

  factory ChapterDto.fromJson(Map<String, dynamic> json) => ChapterDto(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    titleName: json['titleName'] as String? ?? '',
    range: json['range'] as String? ?? '',
    minNumber: json['minNumber'] as num? ?? 0,
    pages: json['pages'] as int? ?? 0,
    pagesRead: json['pagesRead'] as int? ?? 0,
    isSpecial: json['isSpecial'] as bool? ?? false,
    sortOrder: json['sortOrder'] as num? ?? 0,
    format: MangaFormat.fromId(json['format'] as int?),
  );
}

/// Pixel size of one page, as measured by the server. Lets the webtoon view
/// lay pages out before their images have loaded.
class PageDimension {
  const PageDimension({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.isWide,
  });

  final int pageNumber;
  final int width;
  final int height;
  final bool isWide;

  double get aspectRatio => height == 0 ? defaultAspectRatio : width / height;

  /// Portrait comic page, used when the server reports no dimensions.
  static const defaultAspectRatio = 2 / 3;

  static PageDimension? fromJson(Object? json) {
    if (json is! Map) return null;
    final page = json['pageNumber'];
    if (page is! int) return null;
    return PageDimension(
      pageNumber: page,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      isWide: json['isWide'] as bool? ?? false,
    );
  }
}

class ChapterInfoDto {
  const ChapterInfoDto({
    required this.seriesId,
    required this.volumeId,
    required this.libraryId,
    required this.pages,
    required this.seriesName,
    required this.title,
    this.seriesFormat = MangaFormat.unknown,
    this.libraryType = LibraryType.manga,
    this.pageDimensions = const {},
  });

  final int seriesId;
  final int volumeId;
  final int libraryId;
  final int pages;
  final String seriesName;
  final String title;

  /// The format of the whole series: a series is one format in Kavita, and
  /// this is the only place the reader can learn it before opening a page.
  final MangaFormat seriesFormat;
  final LibraryType libraryType;

  /// Keyed by the page number the server reported, which may be 0- or
  /// 1-based depending on the source file — [aspectRatioFor] tries both.
  final Map<int, PageDimension> pageDimensions;

  double aspectRatioFor(int page) =>
      (pageDimensions[page] ?? pageDimensions[page + 1])?.aspectRatio ??
      PageDimension.defaultAspectRatio;

  /// Whether the scan on this page is itself a double page.
  ///
  /// Kavita answers that with `isWide`, but only says so for the files it has
  /// measured that way; a page that is plainly landscape is a spread whatever
  /// the flag says, and the dimensions are right there. Either is enough.
  bool isWide(int page) {
    final dimension = pageDimensions[page] ?? pageDimensions[page + 1];
    if (dimension == null) return false;
    return dimension.isWide || dimension.width > dimension.height;
  }

  factory ChapterInfoDto.fromJson(Map<String, dynamic> json) => ChapterInfoDto(
    seriesId: json['seriesId'] as int,
    volumeId: json['volumeId'] as int? ?? 0,
    libraryId: json['libraryId'] as int? ?? 0,
    pages: json['pages'] as int? ?? 0,
    seriesName: json['seriesName'] as String? ?? '',
    title: json['title'] as String? ?? '',
    seriesFormat: MangaFormat.fromId(json['seriesFormat'] as int?),
    libraryType: LibraryType.fromId(json['libraryType'] as int?),
    pageDimensions: {
      for (final dimension
          in (json['pageDimensions'] as List<dynamic>? ?? [])
              .map(PageDimension.fromJson)
              .nonNulls)
        dimension.pageNumber: dimension,
    },
  );
}

/// A device Kavita has registered for the current user, as returned by
/// `GET /api/Device/client/devices`. Only the three fields the rename flow
/// needs are mapped.
class ClientDeviceDto {
  const ClientDeviceDto({
    required this.id,
    required this.friendlyName,
    required this.uiFingerprint,
  });

  final int id;
  final String friendlyName;

  /// The `X-Device-Id` the device sent, or empty for clients that send none.
  final String uiFingerprint;

  factory ClientDeviceDto.fromJson(Map<String, dynamic> json) =>
      ClientDeviceDto(
        id: json['id'] as int? ?? 0,
        friendlyName: json['friendlyName'] as String? ?? '',
        uiFingerprint: json['uiFingerprint'] as String? ?? '',
      );
}

/// The members of Kavita's filter enums that `POST /api/Series/all-v2` is
/// actually sent. Only those: the four enums run to 34, 18, 2 and 11 members
/// and the rest would be dead code, by the same argument that keeps this
/// client hand-written.
///
/// What makes these more than a comment is that
/// `test/openapi_contract_test.dart` checks each value against the spec's
/// `x-enum-varnames`, **by value rather than by position** —
/// [SeriesSortField]'s enum is one-based where the other three are zero-based,
/// so they cannot be counted off by eye.
abstract final class SeriesFilterField {
  /// Filter on the libraries a series belongs to.
  static const libraries = 19;
}

/// See [SeriesFilterField].
abstract final class FilterComparison {
  /// The field contains the value — for `libraries`, the id is in the list.
  static const contains = 5;
}

/// See [SeriesFilterField].
abstract final class FilterCombination {
  /// Every statement must match. The enum has only `Or` and `And`.
  static const and = 1;
}

/// See [SeriesFilterField].
abstract final class SeriesSortField {
  /// Kavita's own sort name for a series, which is what its grids order on.
  static const sortName = 1;
}
