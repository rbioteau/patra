# ADR-0004 — The auth key is the only secret a profile keeps

**Status:** accepted · **Date:** 2026-09-06

## Context

`ServerEntry` persists three credentials per remembered server: `token`,
`refreshToken` and `apiKey`. With [ADR-0003](./0003-a-profile-is-a-kavita-account.md)
a device holds several profiles, so that becomes three secrets per person in
the keychain, and switching between them has to be worth doing more than once a
day or the picker is furniture.

The OpenAPI spec exposes **no token lifetime at all** — no `expiresIn`, no
`expiresAt`, on `UserDto` or `TokenRequestDto` — so a client cannot schedule a
refresh and can only react to a 401. The real numbers are in Kavita's C#
source:

| | 0.9.0.x (the vendored spec's line) | 0.9.1.x |
| --- | --- | --- |
| JWT | 10 days | 3 days |
| Refresh token | ~1 day (ASP.NET Identity's default, never overridden) | 30 days |

## Decision

A profile persists **the auth key and nothing else**. Entering one calls
`POST /api/Account/login` with `{ username, apiKey }`; the JWT that comes back
is session state and is never written down.

## Why

**Persisting the pair adds two expiring secrets without removing the durable
one.** On 0.9.0.x a refresh token dies in about a day, so a family iPad picked
up each evening would land on "sign in again" nearly every time it was opened.
The auth key does not expire: the `opds` and `image-only` keys are created with
`ExpiresAtUtc = null`.

**The password-free path is documented rather than inferred.** `LoginDto`
states it: *"If ApiKey is passed, will ignore username/password for
validation"*, and `AccountController.Login` resolves the user from the key
(`GetUserByAuthKey`, which chains `.HasNotExpired()`) and skips
`CheckPasswordSignInAsync` entirely. It still checks `LoginRole`, it returns the
complete `UserDto`, and the credential travels in the body.
`KavitaClient.login` already posts `'apiKey': ''` — this decision is that field,
filled in.

**The two alternatives are worse in specific ways.**
`POST /api/Plugin/authenticate?apiKey=` mints the same token pair but checks no
role at all, takes the key in the **query string**, returns a partial `UserDto`
with no roles or preferences, and logs the raw key in cleartext on failure.
Using the auth key as the request scheme outright (Kavita's selector ranks it
above bearer) would drop the JWT and with it the only time-bounded credential in
the design.

## Cost, accepted

Entering a profile **online** needs one request before anything works. That
round trip is hidden: the launch animation runs 7.8s and the app is already
mounted from the first frame precisely so its first requests are made and
answered while the splash plays. Offline no request is made, because a profile
entered offline reads only what it has saved.

## Consequences

**An auth key is a whole account, and it is honest to say so.** It authenticates
essentially the entire API, the handler builds a principal carrying every one of
the user's role claims, and it is accepted from a query parameter, a header or a
route value. So N profiles on one device is N complete, non-expiring account
credentials sitting in one keychain. Worse for a shared device: **only the
owning user can rotate one** (`authKey.AppUserId != UserId → BadRequest`), and
an admin "invalidate" is cache eviction, not invalidation — a parent cannot
revoke a child's key, or their own from a device they have lost.

The PIN in front of a profile is therefore a speed bump **between family
members**, and the UI must say that and never imply it protects a lost device.

**`apiKey` is one row, not a separate concept.** `AppUser.ApiKey` is
`[Obsolete("Migrated to AuthKey in v0.8.9")]` and `ConstructUserDto` computes
`dto.ApiKey = user.GetOpdsAuthKey()` — the auth key literally named `opds`. If
its owner rotates it from Kavita's web UI, the stored copy starts answering 401
with no other signal, which is exactly the stale-profile state the picker
already draws (greyed, badged, asking for a password by name).

**Do not lean on `refresh-token` on the 0.9.0.x line.** It is
`[AllowAnonymous]`, it reads the supplied JWT with `ReadJwtToken` (no signature
check), and its rejection test is `!validated && expiring-within-1h`, so a token
carrying a far-future `exp` appears to pass with any refresh string. `develop`
rewrote it to validate the signature and reject hard. This is a reading of the
source rather than a confirmed exploit, and it is one more reason the durable
credential here is the key and not the pair.
