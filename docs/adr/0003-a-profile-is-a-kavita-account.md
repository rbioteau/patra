# ADR-0003 — A profile is a Kavita account, and there are no local ones

**Status:** accepted · **Date:** 2026-09-06

## Context

A family iPad has several readers on it. Each wants their own reading progress,
and each should see their own slice of the library — the nine-year-old's
account and the adult's are not meant to show the same shelves.

Patra remembers servers, not people. `AuthState.active` matches on
`server.baseUrl == activeUrl` and `_upsert` keeps entries unique by `baseUrl`,
so a second person signing into the *same* server does not get a second entry:
the first one is dropped, tokens and all. There was no room in the model for
two readers at one address.

The obvious shape, and the one every other family app on that device uses, is a
set of **local profiles**: one account on the server, several personas in the
app, each with its own progress and its own filtered view.

## Decision

A **profile is exactly one Kavita account**. The app invents no personas. A
device holds several profiles, keyed by `(normalized baseUrl, Kavita user id)`,
and every request is made as exactly one of them.

## Why

**Kavita cannot divide one account into two readers, and it is not close.**
`POST /api/Reader/progress` takes `ProgressDto { volumeId, chapterId, pageNum,
seriesId, libraryId, bookScrollId, lastModifiedUtc }` — there is no user field.
`GET /api/Reader/get-progress` is summarised "Returns Progress (page number)
for a chapter for the logged in user" and takes only `chapterId`.
`has-progress`, `continue-point`, `time-left` and all eight `mark-*read` /
`unread` endpoints are the same. Across the whole surface exactly one progress
endpoint takes a user id — `GET /api/Reader/first-progress-date?userId=` — and
it is a statistics read. Two personas over one account would therefore share one
progress row and fight over `pagesRead` the moment they read the same series.

**And a client-side library filter would be a lie rather than a rule.** Access
is carried by the user (`MemberDto.libraries`, written through
`UpdateUserDto.libraries`), and content is gated per account by
`AgeRestrictionDto { ageRating, includeUnknowns }`. A persona that merely hid
libraries would still be holding a session that can fetch them. Enforcement
that lives in the client is not enforcement.

Both requirements are met for free by signing in as the right account, and by
nothing else.

## Cost, accepted

Someone has to be Kavita admin on that server and create an account per person,
and Kavita's invite cannot be finished from here: `POST /api/Account/invite`
returns a setup link (it works without SMTP — `InviteUserResponse` carries
`emailLink` as well as `emailSent`), but `ConfirmEmailDto { email, token,
password, username }` needs the invitee to open that link and set their own
password in a browser. So family setup leaves the app, and we ship no part of an
invite flow rather than half of one.

## Consequences

**There is no kids mode to build, and no place to put one.** The protection a
child gets is their own account's age restriction, enforced by the server. It
protects the child's *account*, not the device — it does nothing at all if the
child is reading inside an adult's session. That asymmetry is why the lock in
front of the picker belongs on the **unrestricted** profiles rather than the
restricted ones, which is the opposite of where one would first think to put it.

**The key is derivable offline.** `accountIdFrom(token)` (`api/account_id.dart`)
reads Kavita's `nameid` claim straight out of the JWT, so the user id is
available on every path including a resume, and `LoginResult` needs no new
field. See [ADR-0004](./0004-the-auth-key-is-the-only-persisted-secret.md) for
what is stored per profile.
