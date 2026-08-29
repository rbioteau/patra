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
  });

  final String username;
  final String token;
  final String refreshToken;
  final String apiKey;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    username: json['username'] as String? ?? '',
    token: json['token'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
  );
}

class LibraryDto {
  const LibraryDto({required this.id, required this.name, required this.type});

  final int id;
  final String name;

  /// 0=Manga, 1=Comic, 2=Book, 3=Images, 4=LightNovel, 5=ComicVine
  final int type;

  factory LibraryDto.fromJson(Map<String, dynamic> json) => LibraryDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    type: json['type'] as int? ?? 0,
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

  /// Kavita sentinel volume numbers (Parser.LooseLeafVolumeNumber and
  /// SpecialVolumeNumber): the pseudo-volumes holding chapters that belong to
  /// no volume, and specials. Compared on the absolute value because the sign
  /// has differed between Kavita versions — no real volume comes near 100000.
  static const looseLeafNumber = 100000;
  static const specialsNumber = 100001;

  final int id;
  final String name;
  final num minNumber;
  final int pages;
  final int pagesRead;
  final List<ChapterDto> chapters;

  bool get isLooseLeaf => minNumber.abs() == looseLeafNumber;
  bool get isSpecials => minNumber.abs() == specialsNumber;

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
  });

  /// Kavita sentinel for the placeholder chapter of a volume that has no
  /// chapter breakdown (Parser.DefaultChapterNumber): such a chapter
  /// represents the whole volume. Sign-insensitive, as above.
  static const defaultNumber = 100000;

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

  /// True for the placeholder chapter Kavita creates inside a volume with no
  /// chapter breakdown.
  bool get isVolumePlaceholder =>
      minNumber.abs() == defaultNumber && !isSpecial;

  factory ChapterDto.fromJson(Map<String, dynamic> json) => ChapterDto(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    titleName: json['titleName'] as String? ?? '',
    range: json['range'] as String? ?? '',
    minNumber: json['minNumber'] as num? ?? 0,
    pages: json['pages'] as int? ?? 0,
    pagesRead: json['pagesRead'] as int? ?? 0,
    isSpecial: json['isSpecial'] as bool? ?? false,
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
    this.pageDimensions = const {},
  });

  final int seriesId;
  final int volumeId;
  final int libraryId;
  final int pages;
  final String seriesName;
  final String title;

  /// Keyed by the page number the server reported, which may be 0- or
  /// 1-based depending on the source file — [aspectRatioFor] tries both.
  final Map<int, PageDimension> pageDimensions;

  double aspectRatioFor(int page) =>
      (pageDimensions[page] ?? pageDimensions[page + 1])?.aspectRatio ??
      PageDimension.defaultAspectRatio;

  bool isWide(int page) =>
      (pageDimensions[page] ?? pageDimensions[page + 1])?.isWide ?? false;

  factory ChapterInfoDto.fromJson(Map<String, dynamic> json) => ChapterInfoDto(
    seriesId: json['seriesId'] as int,
    volumeId: json['volumeId'] as int? ?? 0,
    libraryId: json['libraryId'] as int? ?? 0,
    pages: json['pages'] as int? ?? 0,
    seriesName: json['seriesName'] as String? ?? '',
    title: json['title'] as String? ?? '',
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
