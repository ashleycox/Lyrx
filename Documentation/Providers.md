# Lyric services

Reviewed on 27 October 2026. These adapters use public APIs without account credentials. The app does not scrape lyric websites. Service availability and rights to returned content are separate questions; no API is a guarantee of licensed redistribution.

## LRCLIB

Primary source: [official API documentation](https://lrclib.net/docs).

Lyrx calls `GET https://lrclib.net/api/search`, using `q`, `track_name`, `artist_name`, and `album_name` when supplied. The documented anonymous API does not require a key. An identifying User-Agent is sent. Search returns track records with `trackName`, `artistName`, `albumName`, `plainLyrics`, `syncedLyrics`, and `instrumental`. Plain text is preferred; if only LRC is present, timing and recognized metadata tags are removed while lyric headings remain.

LRCLIB is the default because it supports free-text and metadata searches and returns lyrics directly. It avoids another round trip for most selections. Empty, instrumental, and unavailable lyrics are handled separately. Community metadata and lyrics can be incomplete or incorrect.

## lyrics.ovh

Primary source: [maintainer's API README](https://github.com/NTag/lyrics.ovh).

Lyrx calls `GET https://api.lyrics.ovh/suggest/{query}` for song candidates, then `GET /v1/{artist}/{title}` for a chosen candidate's lyrics. The suggestion endpoint returns Deezer metadata. Supplying only exact artist and title filters allows direct lyric lookup without the suggestion endpoint. Provider filters are also checked locally.

This optional provider broadens lookup options without requiring an embedded secret. Its server aggregates other sources and may query LRCLIB itself. Disabling direct LRCLIB searches in Lyrx cannot prevent lyrics.ovh's own upstream requests. This is disclosed in Settings. A provider's code license should not be confused with rights to song lyrics.

## lrc.red

Primary source: [official API documentation](https://lrc.red/api).

This optional service needs no API key. It requires an identifying User-Agent containing an app name, link, and contact email, plus visible linked attribution wherever its data is shown. Enabling lrc.red reveals a contact field in Settings. Only an enabled service with a syntactically valid address receives requests. The email lives in local preferences, not source control, URLs, matches, or logs. It is sent only to lrc.red; contact-bearing redirects to any other origin, port, or insecure scheme are refused. The app does not verify ownership of the address.

Lyrx calls `GET https://lrc.red/search.json?q=…` for title/artist candidates. Results carry an ISRC used to fetch `/s/{isrc}.ttml`. The UTF-8 TTML reader keeps paragraph lines, stanza divisions, inline words and explicit breaks while removing timings and presentation markup. Adjacent syllable spans never receive invented spaces. Metadata elements are excluded; DTDs and custom entities are rejected, and parsing depth and text size are bounded. A missing or empty TTML document falls back to `/s/{isrc}.lrc`; malformed documents or service failures do not cause a second format lookup.

Opening Additional Info fetches `/s/{isrc}.json`, adding the available songwriter credits, featured artists, release date, language, genres, and other public fields. The `sync` status is excluded from search and detail metadata because playback synchronization is outside Lyrx's plain-text reading model. Metadata is reused in memory during that search. Its URLs are explicit links, never automatic cover-art or audio downloads. LRCLIB and lyrics.ovh expose their already-returned search metadata in the same view; no extra off-provider metadata requests are made.

Artist and album links search only the source service and reveal the active filters. lrc.red searches the artist and filters the returned candidates by album locally. There is no dedicated album catalog request or pagination yet, so an album link can return only part of an album or no results even when later pages contain a match. LRCLIB uses its artist/album query fields; lyrics.ovh uses suggestions plus local filters. Saved provider switches do not change.

The privacy manifest declares email and search information for app functionality, linked to the user because lrc.red receives both together. Lyrx performs no tracking and stores no search history. This declaration does not assert a provider's retention policy; release privacy disclosures should be checked against current service practices. See [Apple's privacy-manifest guidance](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests) and [data collection definitions](https://developer.apple.com/app-store/app-privacy-details/).

## Request and selection policy

- Only explicitly enabled, configured services receive direct requests, following search submission, result selection, artist/album navigation, or opening Additional Info. Empty or invalid lrc.red contact details block all three API paths.
- Requests use HTTPS and an ephemeral URLSession without persistent cookies or cache. Each request has a 12-second inactivity timeout and an 18-second resource timeout. Streaming responses are capped at 4 MiB.
- A GET that returns 429 or 503 with a numeric `Retry-After` of zero to two seconds is retried once after at least that delay (a minimum one-second pause). There is no retry for longer delays, date-form headers, absent/malformed headers, other errors, or non-GET requests. Cancellation interrupts the wait. A second failure is surfaced normally; disabled providers are never enabled as a fallback.
- Independent searches run as structured child tasks. One service's failure produces a service-specific notice while the others continue.
- Ranking favors matching title and artist, then usable text; ties are deterministic. Exact text and normalized token overlap are heuristics, not certainty.
- Automatic loading tries up to five non-instrumental candidates, stopping at the first usable lyric. If only instrumentals exist, one can be shown explicitly as instrumental. Manual selection can load any returned candidate.
- At most 200 LRCLIB records, 200 lrc.red records, and 50 lyrics.ovh suggestion records are retained from a response. Provider-side result limits still apply; pagination is not implemented.
- Cancellation and generation checks prevent older operations overwriting a later search or selection. Changing provider preferences cancels in-progress work.
- Songwriter credits are not supplied consistently, so no songwriter filter is presented. Local album/title/artist filters use case- and diacritic-insensitive matching.

## Checks

LRCLIB and lyrics.ovh live search endpoints returned the expected JSON structure during initial development. Deterministic tests cover fixtures, unavailable and malformed responses, path/query encoding, missing fields, LRC fallback, and disabled-provider behavior. The lrc.red adapter was verified against documented-contract fixtures, including TTML, credits, contact isolation, redirects, and disabled or unconfigured access. A full live lyric retrieval with a real configured contact address has not been tested. Public endpoints are not called by automated unit tests. No copyrighted lyric fixtures are committed.

LRCLIB subsequently returned HTTP 503 for a direct search during investigation on 27 October 2026. This is a service failure, not a no-match result. Keep another provider enabled for availability; a successful request at another time does not establish that an outage has been resolved. Lyrx displays the status code and retains successful results from other enabled providers.

A follow-up probe received a successful free-text search and a 503 metadata search with `Retry-After: 1` and `ServerOverloaded`. The [server architecture](https://github.com/tranxuanthang/lrclib/blob/main/ARCHITECTURE.md) documents this response when its work queue is saturated. Lyrx now honors that short backoff once. Fixture tests cover recovery, persistent overload, unsupported delays, non-GET requests, and cancellation without network calls or timed sleeps.

## Additional providers reviewed

These are research candidates, not enabled or integrated services.

- **[LrcShare](https://api.lrcshare.com/docs/guide/quickstart.html)** offers a free key-based API, a catalog/session step, and full lyric downloads. Its curated catalog focuses on Chinese rap and lyrics. The current quick-start instructions require an API key, even though older FAQ text still describes anonymous access. No key was requested or embedded, and authenticated lyric retrieval was not tested.
- **[ChartLyrics](https://www.chartlyrics.com/api.aspx)** has a legacy public API, but HTTPS checks of both its documentation host and API host failed certificate hostname validation during this review. It is not suitable for integration unless secure access is restored. Lyrx must not bypass certificate checks or add an insecure HTTP exception.
