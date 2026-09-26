import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_page.dart';

/// Where a reader is in a page of a book, as it travels to the server and
/// comes back (#128): the string is ours to write, and it is ours to read.
void main() {
  test('a place in a block goes to the server and comes back as itself', () {
    const here = BookAnchor.inBlock(12, .375);
    expect(BookAnchor.from(here.id), here);
  });

  test('what travels is a string no reader could mistake for a fraction', () {
    const here = BookAnchor.inBlock(12, .375);
    expect(double.tryParse(here.id), isNull);
    expect(here.id, 'patra:12@0.3750');
  });

  test('a bare fraction, written before blocks were, is still read as one', () {
    // Already on servers and already in copies: a place down the page as a
    // whole, which is what it meant when it was written.
    expect(BookAnchor.from('0.5000'), const BookAnchor(.5));
    expect(BookAnchor.from('0.5000')!.block, isNull);
  });

  test('a fraction out of range is held inside its block', () {
    expect(BookAnchor.from('patra:3@1.5'), const BookAnchor.inBlock(3, 1));
    expect(BookAnchor.from('1.5'), const BookAnchor(1));
  });

  test("a marker this app did not write is not a place", () {
    for (final id in [
      null,
      '',
      'body-h2-17',
      '//html[1]/BODY/APP-ROOT[1]/DIV[2]/P[3]',
      'patra:@0.5',
      'patra:x@0.5',
      'patra:-1@0.5',
      'patra:3@',
      'patra:3@nan',
      'patra:3',
      'NaN',
      'Infinity',
    ]) {
      expect(BookAnchor.from(id), isNull, reason: '$id');
    }
  });

  test('the top of a page is where every page opens', () {
    expect(BookAnchor.top.isTop, isTrue);
    expect(const BookAnchor(.1).isTop, isFalse);
    // The first words of the first block are a place, and not the top: the
    // block may be anywhere at another size.
    expect(const BookAnchor.inBlock(0, 0).isTop, isFalse);
  });

  test("what the page's script is told is what it tells back", () {
    for (final here in const [BookAnchor.inBlock(4, .5), BookAnchor(.25)]) {
      expect(BookAnchor.fromJson(here.toJson()), here);
    }
    expect(BookAnchor.fromJson({'block': -1, 'at': .5}), isNull);
    expect(BookAnchor.fromJson({'block': 'x', 'at': .5}), isNull);
    expect(BookAnchor.fromJson({'block': 2}), isNull);
    expect(BookAnchor.fromJson('0.5'), isNull);
  });
}
