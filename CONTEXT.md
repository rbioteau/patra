# Patra

Patra is a mobile reading client for **Kavita**, a self-hosted manga, comics and book server. Almost every noun below is Kavita's, because a client that renames the server's concepts ends up speaking a different language from the thing it browses. Where we had to choose a word, this file is the choice.

## Language

### The server and what it holds

**Kavita**:
The self-hosted server that owns the files, the metadata and the reading progress. It is the authority on all three.
_Avoid_: the backend, the API, the remote

**Server version**:
Which release of Kavita a server is running. It belongs to the server, not to the app or to the profile, and it is only ever true of a server we can reach right now — the moment we cannot, we have no version, rather than an old one.
_Avoid_: version (unqualified — the app has one of its own), build, release

**Server**:
A Kavita address the user has connected to at least once, remembered so it need not be typed again. Several can be remembered at once, and each holds one or more profiles.
_Avoid_: server entry, instance, connection, backend

**Profile**:
One person's Kavita account on a server, remembered along with its auth key and never its password. Reading progress, library access and age restriction all belong to a profile and to nothing else, because the server keeps them per account and offers no way to divide one. Which profile it is, is the server's address plus Kavita's own id for the account — never the name, which is a label the server lets its owner change.
_Avoid_: account, user, member, persona

**Administrator**:
A [[Profile]] Kavita grants its admin role. It is the server's fact about an account, carried on the sign-in response and remembered with the profile, so it is only as fresh as the last time that profile signed in — an offline resume keeps the previous answer. The app draws an administrator's controls and never draws them for anyone else, because every one of them would earn a refusal from the server.
_Avoid_: admin (in prose — the word is fine in code), owner, superuser

**Gate**:
The screen a device with no session lands on — the [[Picker]] or the sign-in form. Which one is a rule about the device rather than a screen's own decision, and the app has exactly one place that decides it.
_Avoid_: landing screen, splash (that is the launch animation), auth screen

**Picker**:
The screen a shared device opens on: every remembered profile, drawn as a face, asking who is reading before anything is read. It is drawn entirely from what the device remembers, so it appears with no network. A device holding one profile never sees it — being asked a question with one answer is a tap nobody agreed to.
_Avoid_: profile switcher, chooser, who's watching, account selector

**Face**:
One profile on the picker: its avatar or its initial, its name, and its server where more than one is remembered. What a person recognises themselves by, which is why it is not called a row.
_Avoid_: tile, card, profile row

**Avatar**:
The picture Kavita holds for an account. The app knows whether there is one and fetches it by account id, never by file name; where there is none, or no key left to fetch it with, the face is the profile's initial on its colour.
_Avoid_: profile picture, photo, icon

**Profile colour**:
The colour Kavita's own web UI paints an account in, carried on the sign-in response and remembered with the profile. It is what an initial is drawn on, and it is per person — never the app's accent as a design token, which stands for reading progress and the app's own identity. An account with none falls back to it all the same, because a face with no colour is one that fails to be told apart.
_Avoid_: theme colour, accent, brand colour

**Credential**:
What a sign-in is made with: a password the first time, an auth key every time after. Never both and never neither, which is why it is a sealed type in code rather than two optional fields — the wire format cannot express the choice, so the client does.
_Avoid_: credentials (plural), login, secret

**Auth key**:
The one secret a profile keeps: Kavita's non-expiring `opds` key, which signs a profile in with no password and authenticates image URLs. It is the durable credential — the JWT it mints is session state and is never written down — and it is a whole account, so a device holding four profiles holds four complete account credentials (ADR-0004).
_Avoid_: API key, token, password

**Session**:
The profile the app is currently reading as. Exactly one profile can be the active session, and every request the app makes is made as that one.
_Avoid_: login

**Switch**:
Handing the app to somebody else: it returns to the [[Picker]] and the profile keeps its auth key, so coming back to it is a tap and never a password. One of the two verbs a profile has, and the only one the face on the home bar offers.
_Avoid_: sign out, log out, change user

**Remove**:
Forgetting a profile: the device drops it and its key, and the others on its server stay. The other of the two verbs, and it lives in Settings — where somebody has had to enter *a* profile before they can remove *any* of them, which is the credential the [[Picker]] cannot ask for.
_Avoid_: delete, sign out, forget the server

**Lock**:
A PIN in front of a profile, asked before it is entered — on this device, so it is asked offline too. What it keeps out is the other people who share the device; it is not protection for a device that has been lost, and no copy about it may suggest it is. A profile has one or it does not, and the app suggests one to a profile the server restricts nothing about — an administrator among them whatever rating is set on it, since an admin can lift their own — and never to a restricted one.
_Avoid_: passcode, parental control, kids mode, password (that is the server's)

**PIN**:
The four digits a lock is made of, and the only thing that opens one. Where the device offers to recognise its owner that is asked first, and the PIN is what it falls back to — never the other way round, and never the device's own lock-screen code, which on a shared tablet everybody already knows.
_Avoid_: code (unqualified), passcode, password

**Handover**:
What a switch followed by somebody else's arrival amounts to: the app is built again on a container of its own, so nothing a provider was holding for the previous person can reach the next one. It is not a launch — the splash does not play — and it is not a resume either.
_Avoid_: restart, reload, refresh

**Link**:
A location arriving from outside the app that names something to read — a series or a chapter, and nothing else the app can be pointed at. It says what to open and not who is reading, so on a device with faces it waits for one; it is opened on top of the app rather than instead of it, and it is spent the first moment somebody is reading. Called a *deep link* where the point is where it came from; here it is simply a link.
_Avoid_: URL, route, destination

**Login result**:
What a server answers a sign-in with: who you are, the auth key to keep, and a JWT to spend. It is not a session — a session is a profile the app is currently reading as, and this is only what one is built from.
_Avoid_: user, session, credentials (those are what is sent, not what comes back)

**Registered device**:
Kavita's own record of a client that has talked to it. One per installation of the app, kept apart by an identifier this app generates and remembers; the server names it, and the app renames its own entry once per session to say which device it is. The app never touches a name a person typed in Kavita.
_Avoid_: session, client, install

**Library**:
A collection of series on the server, built from a folder and carrying a type. What is in it is whatever the last [[Scan]] found, so it drifts from the folder as the folder changes and is only ever as current as that scan. A library can also be empty, which means no scan has yet found anything there.
_Avoid_: collection, folder, shelf

**Library type**:
Which of Kavita's six kinds a library is (Manga, Comic, Book, Image, Light Novel, ComicVine). It decides what a series is made of and what every part of it is called, so it is never cosmetic.
_Avoid_: format, genre, category

**Scan**:
What the server does when it reads a [[Library]]'s folder again and takes in what changed. It is *asked for*, never finished, by the app: Kavita answers the request and does the work afterwards, so nothing the app can say about a scan is ever a report of its result. Only an [[Administrator]] can ask. Distinct from refreshing a screen, which asks Kavita what it already knows — a scan is what changes the answer, a refresh is what fetches it.
_Avoid_: sync, reindex, refresh, rescan

**Series**:
One work: a manga, a comic run, a book. The thing a cover in the grid stands for.
_Avoid_: title, book, entry

### The parts of a series

**Volume**:
A numbered collection of chapters within a series. In a book library a volume is *named after* the book, but the file, the format and the [[Reading progress]] sit on its chapters all the same — usually just one, and often the placeholder — because Kavita hangs a file on a chapter and never on a volume.
_Avoid_: tome (English text), book (except in a book library)

**Chapter**:
The reading unit: the thing a row opens, and the thing reading progress attaches to. Called an **issue** in a comic library and a **book** in a book library — always name it in the library type's own vocabulary, never as a bare "chapter". A chapter is made either of [[Fixed pages]] or of [[Reflowable content]], and which of the two it is decides how it can be read.
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

**Genre**:
A metadata label on one [[Series]] — Action, Science-Fiction — alongside its tags. It says what a work is *about* and nothing about how it is read: genres and tags carry no usable signal for the [[Detected direction]], which is inferred from the [[Library type]] and the shape of the pages instead.
_Avoid_: category, type, tag (for a genre), library type

**Reading progress**:
How much has been read, counted in pages. It exists per chapter and per series, and the two answer different questions: finishing a volume leaves the next one untouched, so whether a *series* is under way is not what the chapter you would open next says. For [[Reflowable content]] the pages are **the server's**: it counts them, and it can count them again differently, so a copy kept on the device keeps the count it was made with — and there is a second half a page count cannot hold, which is *where in the page* the reader had come to: a page longer than the screen is not a page reopened at its top. That place is **a fraction of the room there is to scroll**, not a distance down a screen of them: the words move under another reading size and another window, and an offset saved at one size opens at another place entirely at another.
_Avoid_: completion, status, read state

**Continue**:
The series read most recently that has been started and not finished — one series, not a set. It is what the home screen promotes above everything else, and the only thing that promotion is for is opening it again. It is picked **out of** [[On deck]] rather than fetched: one request answers both, so the card and the shelf beneath it can never disagree about what is being read.

Kavita has a route called *currently reading*, and it is **not** this concept — the name is the trap. It filters on `ReadLast GreaterThan OnDeckProgressDays`, a comparison `SeriesFilter.HasReadLast` deliberately inverts into `MaxDate < now - N`: the series you started and have *not* touched for over a month. That is On deck's complement, not a better name for it, so promoting from it meant anybody who reads regularly had no promotion at all while the shelf beneath listed the very series they were reading. Continue is one series and On deck is a list; both come from the same answer.
_Avoid_: currently reading, in progress, resume list, reading list (that is a Kavita feature of its own)

**On deck**:
The series with reading progress on them, as Kavita picks and orders them — started, unfinished, and still live (`PagesRead > 0 && PagesRead < Pages`, plus a recency clause). It is the home screen's one list *and* the pool the [[Continue]] promotion is chosen from, and the series that promotion has taken is removed from it, so no series is two things on the same screen. That removal is also what covers a promotion that fails to draw: it is keyed on the card being there, so a series whose chapter could not be fetched stays in the list rather than leaving the screen with it.
_Avoid_: next up, recommended, suggestions, up next

### Reading

**Reflowable content**:
What a [[Chapter]] is made of when it is words rather than pictures: **Kavita** lays the text out and hands the app one page at a time, so a page is a slice the server chose and not a picture with a size — change the text size or the screen and the same words break somewhere else. **The app draws that page itself**: the HTML Kavita scoped is taken apart into paragraphs, headings, quotations, list items and pictures, and those are set in this app's type on this app's background rather than handed to a browser (ADR-0010). Its [[Reading progress]] is therefore a page the server counted and may count again differently, and everything built on measuring pages — the [[Detected direction]], the [[Strip]], the [[Spread]], [[Magnifying]] — has nothing to measure and is never offered for it.
_Avoid_: epub (that is one file format, and a [[Library type]] is a different thing entirely), book (that is what a chapter is *called* in a book library, not what it is made of), text (a chapter of words carries pictures too), zoom (there is no page to magnify and nothing to measure one against — the knobs a page of words has are the ones the reader chooses)

**Fixed pages**:
What a [[Chapter]] is made of when every page is one picture, whether it was archived as one or rasterised out of a PDF by Kavita. Every page has a size the app can measure before the page itself has loaded, which is what the [[Detected direction]], the [[Strip]], the [[Spread]] and [[Magnifying]] are all built on.
_Avoid_: images (that is what they are, not the concept), paged (that is [[Reading direction]]'s business)

**Reading direction**:
Which way the reader advances through a chapter: left-to-right, right-to-left, or vertical scrolling. One setting with three values — the third is a direction like the other two, not a separate mode sitting beside them. Which one a chapter opens in is answered by a chain, each rung only asked when the one above it has no answer: the [[Series direction]], then the [[Library direction]], then the [[Detected direction]] — a guess never beats a choice — and last the left-to-right a chapter has always opened in. No rung in it belongs to a [[Profile]] or to a device: a direction is a property of the work, and a default held for every series at once is the wrong shape for one. The chain is not asked at all of [[Reflowable content]]: with no page sizes to measure, the detected rung could never speak, and there are no pictures to turn or to pair.
_Avoid_: mode, layout, LTR/RTL (in anything a user reads)

**Library direction**:
The [[Reading direction]] chosen for every [[Series]] shelved in one library, which outranks the guess and is outranked by a series' own. It is the rung that corrects a library the guess gets wrong wholesale — a library whose type is wrong is wrong for every work in it — and it is what replaces the profile's own default rather than an extra beside it. It belongs to the [[Profile]] that chose it and is never sent to the server, and a library nobody has set has none.
_Avoid_: library default, library setting, shelf direction

**Series direction**:
The [[Reading direction]] chosen for one [[Series]] alone, which outranks the library's and the person's own for that series and for nothing else. It belongs to the [[Profile]] that chose it and is never sent to the server. A series nobody has set has none, and opens at whatever stands below it — which is the whole of why it is not the same thing as setting a series to the value the person's choice happens to hold: a series that is merely *set* stops following a default that later changes, where one with no series direction follows it wherever it goes.
_Avoid_: per-series setting, override, book setting

**Detected direction**:
The [[Reading direction]] the app infers for a work it has been told nothing about, from what the server says about the series — its library type, and the shape of its pages — since Kavita exposes no direction of its own. The two answer different questions and do not compete: whether a work is vertical is the pages' (a median tallness of 1.8 and above, measured on the chapter being read, which is the only place page dimensions reach the app), and which way it goes when it is not is the library type's, a manga library reading right to left and every other one the way a chapter always has. Genres and tags carry no usable signal and are not consulted. It is a guess and never a choice: anything anybody actually chose outranks it, and the reader says where a direction came from rather than presenting a guess as one.
_Avoid_: automatic direction, smart default, heuristic (in prose)

**Vertical scrolling**:
The reading direction in which the pages run as one continuous strip and are scrolled rather than turned. Kavita calls it *webtoon*, after the genre it was built for, and separately offers a **paged** vertical direction we do not — which is why the word here is "scrolling" and not merely "vertical". On screen the one word "Vertical" is enough, since it is the only vertical direction in the picker.
_Avoid_: webtoon, vertical mode, continuous mode, long strip

**Strip**:
The pages of a chapter laid end to end as one continuous column, which is what the [[Vertical scrolling]] direction scrolls. It has no gaps and no page turns, so a boundary between two pages can fall anywhere on the screen and several pages are in view at once — which page one is "on" is a convention, the one under the upper third of the screen, and not an observation.
_Avoid_: webtoon, long strip, column, feed, list (that is the widget that draws it)

**Magnifying**:
The reading gesture in which a one-finger drag enlarges the page around the point pressed, as an alternative to pinching, which needs a second hand. Held rather than switched on: the page returns when the finger lifts. Off unless asked for, because it takes the swipe that turns a page.
_Avoid_: loupe (a loupe is a lens over one region; this scales the whole page — the word named a rejected alternative and stuck to the accepted one), zoom mode, pinch, magnifier

**Width factor**:
How wide the [[Strip]] is drawn, as a multiple of the screen's width: 1.0 is the whole width, which is where a chapter opens. Below it the strip is narrower than the screen, above it wider and pannable. It is a width the layout is built at rather than a scale painted over a finished one, which is why a page's height follows it and the scroll stays truthful; and it is set rather than held, unlike [[Magnifying]]. A [[Preference]]: it belongs to the [[Profile]], and the server is never told. The range is the strip's to hold, since a pinch moves the same number and the two must not clamp it differently.
_Avoid_: zoom, scale, échelle (a scale is a transform over a page already laid out, and naming it that makes the rejected implementation sound right), magnification (that is [[Magnifying]])

**Spread**:
Two pages shown on one screen, in landscape. Which pages share a screen is a question about the pages, not arithmetic on the page number.
_Avoid_: double page (that is a wide page), pair

**Wide page**:
A single page that is itself a double-page image. It takes a screen of its own and shifts the pairing of everything after it.
_Avoid_: spread, landscape page

**Reading face**:
The typeface a book's pages are set in. The choice is a **kind of type** rather than a font — the book's own, the app's serif, the app's sans — and the family behind one of the three is the book's business rather than the app's. The **book's own** is the default, and means the face the book's own stylesheet asks for, read out of the page Kavita hands over; a book that asks for nothing, or whose font cannot be had, is set in the app's sans, which is what every book was set in before there was anything to choose. A [[Preference]]: it belongs to the [[Profile]] and follows their eyes, like the text size and the line spacing, and the server is never told — though the server's own client answers the same question the same way, by leaving the book's stylesheet to win. It governs the whole page — prose, headings, quotations and list items — and not the page counter, which is the app's own furniture and stays in the serif whatever is chosen. It is the one deliberate hole in the serif rule: that rule keeps the wordmark and the titles of works distinct from everything else, and prose set in a serif puts neither at risk.
_Avoid_: font (that is one file of a family, and each of ours ships as a single variable file)

### Off the server

**Saved chapter**:
A chapter whose pages are stored on the device because a profile asked for them. Chosen deliberately, never evicted, and readable with no server at all. It belongs to the profile that saved it, so two people sharing a device do not share what each has saved. This is what the Downloads tab counts. For [[Reflowable content]] what is stored is the pages **as the server rendered them**, so a copy is a pagination frozen on the day it was made. Two things follow from that freeze: a copy is where progress made with no server waits to be sent, and a server that has recounted the book since leaves it **out of date** — named, offered for another go, and still readable.
_Avoid_: download (that is the act of fetching one), cached chapter, offline chapter

**Image cache**:
The covers and pages kept on disk merely because they were looked at online. It fills on its own, is capped, and the OS may reclaim it. It is not the offline library and must never be counted as one. It belongs to the **device** and is shared by every profile on it — one budget, and one copy of a cover however many people look at that series.
_Avoid_: downloads, offline storage

**Keychain**:
Where the device keeps what it must not keep in the open: one row per name, and every row the device's own rather than the server's. It holds each [[Profile]]'s [[Auth key]], the [[Lock]]s, what each person has chosen, the [[Device default]]s and the id that tells this installation apart from every other. Never a store of content — a page is a file and a shelf is the [[Catalogue]] — and never somewhere a thing is kept merely because it was convenient: an auth key is a whole Kavita account (ADR-0004), so what goes in here is worth naming.
_Avoid_: secure storage, keystore (that is Android's own, and one of two implementations), vault, preferences (those are one thing it holds)

**Catalogue**:
What the device remembers of a profile's shelves: its libraries, the series in them, and the parts of the series it has looked inside. It names what exists and never holds a page — that is the whole line between it and a [[Saved chapter]], which is content. It fills as a profile browses, and it belongs to that profile, because what a person may see is the server's answer to them alone. Every entry is refetchable, so a catalogue is discardable by design: the worst a wrong one costs is one refresh, which is why it is never migrated and never repaired.
_Avoid_: cache (that is the [[Image cache]], and the word is spoken for), offline library, index, snapshot, mirror

**Spine**:
The part of the [[Catalogue]] loaded whole: the libraries, and the series in each of them. Everything under it — a series' volumes, its chapters, its description — is loaded per series, when that series is opened. Ours to name rather than Kavita's, because the distinction is about this device's memory and the server has no word for it.
_Avoid_: index, manifest, tree, root

**Read**:
One question the [[Catalogue]] answers, with the request behind it: the device's memory laid under the server's word, and the only way to ask for either again. There are six — the libraries, one library's series, the [[On deck]] ranking, and a [[Series]]' volumes, its own row and its description. A screen can reach a read's answer and never the request behind it, which is what stops a screen stepping around the catalogue for itself alone; asking again is a read's own verb, so there is one way to do it and one place it is written down. Ours to name, as [[Spine]] is, because it is about this device's memory and the server has no word for it.
_Avoid_: fetch (that is the request, which is half of one), query, provider, answer (that is what a read carries, not what it is)

**Preference**:
A setting somebody chose. Magnifying, the width a chapter opens at, the [[Reading face]] and the interface language belong to a person and follow their [[Profile]]; the image cache budget belongs to the device, because it is disk. None is ever sent to the server. A preference nobody has chosen is not stored: what stands in for it is the [[Device default]]. **The [[Reading direction]] is the one reading preference that is not one of these** — it belongs to a work or to a [[Library]], never to a person, and it has no device default to fall back on.
_Avoid_: setting (that is the row it is changed on), option, config

**Device default**:
What a profile that has never chosen a preference reads in — the value under the flat key this device held before it had profiles. For the language it is also what the [[Gate]] is drawn in, since the picker stands in front of every session and has nobody to ask; choosing a language moves it, and that is the only preference it is true of. There is no device default for the [[Reading direction]] any more: the chain ends at the [[Detected direction]] and then at the left-to-right a chapter has always opened in.
_Avoid_: fallback, global setting, system default (that is the device's own language, which is a separate answer)

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

Five more are fixed by choice rather than by that test, because they name the app's own furniture rather than a part of a series:

| English | French   |
| ------- | -------- |
| profile | profil   |
| server  | serveur  |
| lock    | verrou   |
| PIN     | code     |
| reading face | police de lecture |

Two more name what a chapter is **made of** rather than a part of a series, and are ours because Kavita has no word for the pair:

| English     | French        |
| ----------- | ------------- |
| reflowable  | remis en page |
| fixed pages | pages fixes   |

*Profil* over *compte*, for the same reason the English term avoids "account": on a picker showing faces, the word has to name a person and not a credential. *Code* over *code PIN*, which is a pleonasm French does not need — and never *mot de passe*, which is what a server asks for and what this deliberately is not.
