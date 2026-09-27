# The device golden

One known book, opened on a phone, photographed, and compared by eye with a
picture of it that somebody looked at and accepted. **Run it before cutting a
release tag:**

```sh
./tool/device_golden.sh
```

CI does not run it and cannot. It has no phone, and a golden with no device
would only ever go green.

## Why it exists

Nothing paints under a test binding, so the book renderer that ships — the
platform's web engine (ADR-0013, #127) — is not the one the suite pins.
`test/book_reader_test.dart` checks what the engine is *handed*: the document,
its pictures, its language. `test/book_rewrite_test.dart` checks the rewrite
pass that makes that document. Neither can say what the engine *draws* from
it. That was accepted with one condition (#132): one golden, on a device, by
hand, before a tag. This is it.

It earned its keep on its first run. The first picture it took showed two
faults that every test was green over. Prose ran off the right edge of the
screen, because the grid that centres a short page let its column grow as wide
as the picture inside it. And none of the book's own stylesheet applied,
because Kavita scopes that stylesheet under `.book-content` and the document
had no such container. Both are fixed in `book_rewrite.dart` and pinned in
`test/book_rewrite_test.dart` as far as a test binding can pin them — that is,
as rules in the document, not as pixels.

## What is here

| File | What it is |
|---|---|
| `golden-book.epub` | The book: two pages, written and drawn for this, in English. Built by `tool/gen_golden_book.sh`, never edited by hand. |
| `kavita/` | What a real Kavita (0.9.1.4, in Docker) answered when the app read that book: `index.json` lists every request and the file holding its answer. `tool/golden_server.dart` replays it. |
| `reference/book-streamed.png` | The book's first page, read from the server. |
| `reference/book-offline.png` | The same page, read from a saved copy with the server gone. |
| `reference/device.txt` | The phone the two pictures were taken on: model, Android, screen size, density, WebView version. |

The page holds the three things a page of a book is made of. There is a
heading with a rule under it, from the book's stylesheet. There is prose,
which the engine justifies and hyphenates because the book declares it is
English (#130). And there is a picture between two paragraphs, with an italic
caption. The two references should be the same picture, because a saved copy
is handed the very document a streamed page is. The script compares them as
well.

**A reference is one phone's pixels.** Another screen size, density or font
makes a different picture that is no less right. When the phone differs from
`device.txt`, the script says so before it compares. The references were made
on a **CPH2663, Android 16, 1080x2414 at 480 dpi, WebView 153**. On another
phone, look at this run's pictures, then `--accept` them if they are right —
the commit then records whose phone the reference now is. **iOS is not
covered**: there is no Mac here, and `adb` is the whole of how the host
reaches the device.

## How a run works

`tool/device_golden.sh` does the following, in order:

1. It **uninstalls Patra from the phone**, so the run starts at the sign-in
   form. This is the same step, with the same cost, as
   `tool/store_screenshots.sh`: profiles and saved chapters on that phone are
   gone, and what comes back is a debug build. `--keep` skips it, and the app
   must then be signed out with no profile remembered.
2. It starts `tool/golden_server.dart`, which replays `kavita/` on port 5000,
   and a control port on 5001. The phone reaches both through `adb reverse`.
3. It puts the status bar in SystemUI demo mode where the phone honours it,
   so its clock is not a difference. The reader hides the status bar anyway
   where Android lets it.
4. It runs `integration_test/book_golden_test.dart` on the phone. The test
   signs in, forces English, opens the book, and asks the host for a
   screenshot. It then saves the book and asks the host to take the server
   away. The host closes the port together with its open connections and
   removes the `adb reverse`, so every request is refused, which is what
   offline is to the app. Finally the test opens the book again and asks for
   a second screenshot.
5. It writes `build/golden/<name>-compare.png` for each picture: the
   reference, this run, and their difference, side by side. It also prints how
   many pixels differ.

The screenshots are taken by the **host**, with `adb exec-out screencap`, and
not by the test's own binding: `screencap` reads what the display composed,
the web view included.

The script fails when the run fails. It does not fail on a difference. The
count is advice, and whether a difference is a regression is the judgement
this exists to hand a person. Two runs on the same phone differ by 0 pixels.

When a difference is meant, accept it:

```sh
./tool/device_golden.sh --accept
```

## Changing the book, or recording again

The recording must be made again when the book changes, or when a Kavita
release changes what it makes of a page. The replay then 404s whatever the
app asks that was never recorded, and names it in `build/golden/server.log`.
To record:

```sh
./tool/gen_golden_book.sh                 # only if the book changed

mkdir -p /tmp/golden/books/"The Lantern Keeper" /tmp/golden/config
cp integration_test/golden/golden-book.epub "/tmp/golden/books/The Lantern Keeper/"
docker run -d --name patra-golden-kavita -p 5055:5000 \
  -v /tmp/golden/books:/books -v /tmp/golden/config:/kavita/config \
  jvmilazz0/kavita:latest
```

Then create the account and the library. Either open `http://localhost:5055`,
or use the API as below: register `golden` as the first account (it becomes
the admin), create a **Book** library over `/books` for EPUB files, and scan
it.

```sh
K=http://localhost:5055
curl -s -X POST $K/api/Account/register -H 'Content-Type: application/json' \
  -d '{"username":"golden","password":"<a password>","email":"golden@example.invalid"}'
TOKEN=...   # the "token" field of that answer
curl -s -X POST $K/api/Library/create -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"id":0,"name":"Golden","type":2,
  "folders":["/books"],"fileGroupTypes":[2],"excludePatterns":[],
  "folderWatching":false,"includeInDashboard":true,"includeInSearch":true,
  "manageCollections":false,"manageReadingLists":false,"allowScrobbling":false,
  "allowMetadataMatching":false,"enableMetadata":true,
  "removePrefixForSortName":false,"inheritWebLinksFromFirstChapter":false,
  "metadataProvider":2}'
curl -s -X POST "$K/api/Library/scan?libraryId=1&force=true" -H "Authorization: Bearer $TOKEN"
```

`metadataProvider` is not in the OpenAPI this repository pins (0.9.0.0), but
0.9.1.4 refuses a library without it. `fileGroupTypes` is `2` for EPUB, not
`3`, which is PDF: a Book library that is only allowed PDFs finds no series
and says nothing.

Then record, and replay once to accept the reference:

```sh
GOLDEN_PASSWORD='<a password>' ./tool/device_golden.sh --record http://localhost:5055
docker rm -f patra-golden-kavita
./tool/device_golden.sh --accept
```

Recording is the test itself, run with the server as a proxy, so the
recording holds exactly what the app asks. Nothing here keeps a list of it in
step with the client. The server takes the recorded Kavita's credentials out
of every answer before writing it down: every key and token its login
answered with, and any `apiKey=` an address carries. So the recording holds
placeholders, never a key. Look at the diff of `kavita/` before committing it
all the same.
