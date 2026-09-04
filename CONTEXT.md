# Patra

Patra is a mobile reading client for **Kavita**, a self-hosted manga, comics and book server. Almost every noun below is Kavita's, because a client that renames the server's concepts ends up speaking a different language from the thing it browses. Where we had to choose a word, this file is the choice.

## Language

### The server and what it holds

**Kavita**:
The self-hosted server that owns the files, the metadata and the reading progress. It is the authority on all three.
_Avoid_: the backend, the API, the remote

**Server entry**:
A Kavita address the user has connected to at least once, remembered along with its tokens but never its password. Several can be remembered at once.
_Avoid_: account, connection, instance

**Session**:
A server entry that currently holds tokens, i.e. one that is signed in. Exactly one server entry can be the active session.
_Avoid_: login

**Login result**:
What a server answers a sign-in with: who you are, and the tokens to be you. It is not a session — a session is a server entry that holds tokens, and this is only what one is built from.
_Avoid_: user, session, credentials (those are what is sent, not what comes back)

**Registered device**:
Kavita's own record of a client that has talked to it. One per installation of the app, kept apart by an identifier this app generates and remembers; the server names it, and the app renames its own entry once per session to say which device it is. The app never touches a name a person typed in Kavita.
_Avoid_: session, client, install

**Library**:
A collection of series on the server, scanned from a folder and carrying a type. A library can be empty, which means the server has not scanned it yet.
_Avoid_: collection, folder, shelf

**Library type**:
Which of Kavita's six kinds a library is (Manga, Comic, Book, Image, Light Novel, ComicVine). It decides what a series is made of and what every part of it is called, so it is never cosmetic.
_Avoid_: format, genre, category

**Series**:
One work: a manga, a comic run, a book. The thing a cover in the grid stands for.
_Avoid_: title, book, entry

### The parts of a series

**Volume**:
A numbered collection of chapters within a series. In a book library a volume *is* the book and has no chapters under it.
_Avoid_: tome (English text), book (except in a book library)

**Chapter**:
The reading unit: the thing a row opens, and the thing reading progress attaches to. Called an **issue** in a comic library and a **book** in a book library — always name it in the library type's own vocabulary, never as a bare "chapter".
_Avoid_: episode, part, file

**Issue**:
What a chapter is called in a Comic or ComicVine library. Always written with the number sign — `Issue #12`.

**Special**:
A chapter Kavita has flagged as a special: an extra, a one-shot, something outside the numbered run. A special is known by its title alone and is never numbered.
_Avoid_: extra, bonus, one-shot

**Loose chapter**:
A chapter that belongs to no volume. Listed under the library type's own chapter heading, alongside the volumes.
_Avoid_: orphan chapter, standalone chapter, loose-leaf chapter (that names the container, not the chapter)

**Pseudo-volume**:
One of the two containers Kavita invents to hold what does not fit the numbering: the **loose-leaf** volume for chapters belonging to no volume, and the **specials** volume. Both carry a sentinel number and neither is ever shown as a volume.
_Avoid_: virtual volume, fake volume, bucket

**Storyline**:
The volumes and the loose chapters of a series read as one ordered story. It is only a storyline when the series actually has both, and only in a library type where it means something — an issue run is not a storyline.
_Avoid_: timeline, reading order

**Reading progress**:
How much has been read, counted in pages. It exists per chapter and per series, and the two answer different questions: finishing a volume leaves the next one untouched, so whether a *series* is under way is not what the chapter you would open next says.
_Avoid_: completion, status, read state

### Reading

**Reading direction**:
Which way the reader advances through a chapter: left-to-right, right-to-left, or vertical scrolling. One setting with three values — the third is a direction like the other two, not a separate mode sitting beside them.
_Avoid_: mode, layout, LTR/RTL (in anything a user reads)

**Vertical scrolling**:
The reading direction in which the pages run as one continuous strip and are scrolled rather than turned. Kavita calls it *webtoon*, after the genre it was built for, and separately offers a **paged** vertical direction we do not — which is why the word here is "scrolling" and not merely "vertical". On screen the one word "Vertical" is enough, since it is the only vertical direction in the picker.
_Avoid_: webtoon, vertical mode, continuous mode, long strip

**Magnifying**:
The reading gesture in which a one-finger drag enlarges the page around the point pressed, as an alternative to pinching, which needs a second hand. Held rather than switched on: the page returns when the finger lifts. Off unless asked for, because it takes the swipe that turns a page.
_Avoid_: loupe (a loupe is a lens over one region; this scales the whole page — the word named a rejected alternative and stuck to the accepted one), zoom mode, pinch, magnifier

**Spread**:
Two pages shown on one screen, in landscape. Which pages share a screen is a question about the pages, not arithmetic on the page number.
_Avoid_: double page (that is a wide page), pair

**Wide page**:
A single page that is itself a double-page image. It takes a screen of its own and shifts the pairing of everything after it.
_Avoid_: spread, landscape page

### Off the server

**Saved chapter**:
A chapter whose pages are stored on the device because the user asked for them. Chosen deliberately, never evicted, and readable with no server at all. This is what the Downloads tab counts.
_Avoid_: download (that is the act of fetching one), cached chapter, offline chapter

**Image cache**:
The covers and pages kept on disk merely because they were looked at online. It fills on its own, is capped, and the OS may reclaim it. It is not the offline library and must never be counted as one.
_Avoid_: downloads, offline storage

**Offline**:
The state of not being able to reach the server. A property of the app's last attempt, not of the device's radio.
_Avoid_: disconnected, no network

## French

The French vocabulary is fixed, and it is not a translator's choice: it matches what Kavita itself says in French, and `test/entity_naming_test.dart` fails if it drifts.

| English   | French       |
| --------- | ------------ |
| volume    | tome         |
| chapter   | chapitre     |
| issue     | numéro (with `#`) |
| book      | livre        |
| specials  | hors-série   |
| storyline | arc narratif |
