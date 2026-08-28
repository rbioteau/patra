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
    required this.pages,
    required this.pagesRead,
  });

  final int id;
  final String name;
  final int libraryId;
  final int pages;
  final int pagesRead;

  factory SeriesDto.fromJson(Map<String, dynamic> json) => SeriesDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    libraryId: json['libraryId'] as int? ?? 0,
    pages: json['pages'] as int? ?? 0,
    pagesRead: json['pagesRead'] as int? ?? 0,
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

  /// Kavita sentinel volume numbers (see Parser in the Kavita codebase):
  /// chapters not belonging to any volume, and specials.
  static const looseLeafNumber = -100000;
  static const specialsNumber = -100001;

  final int id;
  final String name;
  final num minNumber;
  final int pages;
  final int pagesRead;
  final List<ChapterDto> chapters;

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
  });

  /// Kavita sentinel for the placeholder chapter of a volume that has no
  /// chapter breakdown: such a chapter represents the whole volume.
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
  );
}

class ChapterInfoDto {
  const ChapterInfoDto({
    required this.seriesId,
    required this.volumeId,
    required this.libraryId,
    required this.pages,
    required this.seriesName,
    required this.title,
  });

  final int seriesId;
  final int volumeId;
  final int libraryId;
  final int pages;
  final String seriesName;
  final String title;

  factory ChapterInfoDto.fromJson(Map<String, dynamic> json) => ChapterInfoDto(
    seriesId: json['seriesId'] as int,
    volumeId: json['volumeId'] as int? ?? 0,
    libraryId: json['libraryId'] as int? ?? 0,
    pages: json['pages'] as int? ?? 0,
    seriesName: json['seriesName'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );
}
