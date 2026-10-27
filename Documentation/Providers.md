# Lyric services

Reviewed on 27 October 2026. These adapters use public APIs without account credentials. The app does not scrape lyric websites. Service availability and rights to returned content are separate questions; neither API is a guarantee of licensed redistribution.

## LRCLIB

Primary source: [official API documentation](https://lrclib.net/docs).

Lyrx calls `GET https://lrclib.net/api/search`, using `q`, `track_name`, `artist_name`, and `album_name` when supplied. The documented anonymous API does not require a key. An identifying User-Agent is sent. Search returns track records with `trackName`, `artistName`, `albumName`, `plainLyrics`, `syncedLyrics`, and `instrumental`. Plain text is preferred; if only LRC is present, timing and recognized metadata tags are removed while lyric headings remain.

LRCLIB is the default because it supports free-text and metadata searches and returns lyrics directly. It avoids another round trip for most selections. Empty, instrumental, and unavailable lyrics are handled separately. Community metadata and lyrics can be incomplete or incorrect.

## lyrics.ovh

Primary source: [maintainer's API README](https://github.com/NTag/lyrics.ovh).

Lyrx calls `GET https://api.lyrics.ovh/suggest/{query}` for song candidates, then `GET /v1/{artist}/{title}` for a chosen candidate's lyrics. The suggestion endpoint returns Deezer metadata. Supplying only exact artist and title filters allows direct lyric lookup without the suggestion endpoint. Provider filters are also checked locally.

This optional provider broadens lookup options without requiring an embedded secret. Its server aggregates other sources and may query LRCLIB itself. Disabling direct LRCLIB searches in Lyrx cannot prevent lyrics.ovh's own upstream requests. This is disclosed in Settings. Neither provider's code license should be confused with rights to song lyrics.

## Request and selection policy

- Only explicitly enabled services receive direct requests, and only on search submission or result selection.
- Requests use HTTPS and an ephemeral URLSession without persistent cookies or cache. Each request has a 12-second inactivity timeout and an 18-second resource timeout. Streaming responses are capped at 4 MiB.
- Independent searches run as structured child tasks. One service's failure produces a service-specific notice while the others continue.
- Ranking favors matching title and artist, then usable text; ties are deterministic. Exact text and normalized token overlap are heuristics, not certainty.
- Automatic loading tries up to five non-instrumental candidates, stopping at the first usable lyric. If only instrumentals exist, one can be shown explicitly as instrumental. Manual selection can load any returned candidate.
- At most 200 LRCLIB records and 50 suggestion records are retained from a response. Provider-side result limits still apply; pagination is not implemented.
- Cancellation and generation checks prevent older operations overwriting a later search or selection. Changing provider preferences cancels in-progress work.
- Songwriter credits are not supplied consistently, so no songwriter filter is presented. Local album/title/artist filters use case- and diacritic-insensitive matching.

## Checks

Both live search endpoints returned the expected JSON structure during development. Deterministic tests cover fixtures, unavailable and malformed responses, path/query encoding, missing fields, LRC fallback, and disabled-provider behavior. Public endpoints are not called by automated unit tests. No copyrighted lyric fixtures are committed.

LRCLIB subsequently returned HTTP 503 for a direct search during investigation on 27 October 2026. This is a service failure, not a no-match result. Keep another provider enabled for availability; a successful request at another time does not establish that an outage has been resolved. Lyrx displays the status code and retains successful results from other enabled providers.

## Additional providers reviewed

These are research candidates, not enabled or integrated services.

- **[lrc.red](https://lrc.red/api)** documents a free public API with title/artist search, track metadata, TTML, and timed LRC downloads. Its search endpoint returned JSON results during this review. Its terms require an identifying User-Agent with an app link and contact email, plus visible linked attribution wherever its data appears. Integration needs a designated public app contact, attribution links, and a TTML parser for tracks without LRC. A successful search alone does not verify lyric coverage or reliability; the service also reports recent capacity problems.
- **[LrcShare](https://api.lrcshare.com/docs/guide/quickstart.html)** offers a free key-based API, a catalog/session step, and full lyric downloads. Its curated catalog focuses on Chinese rap and lyrics. The current quick-start instructions require an API key, even though older FAQ text still describes anonymous access. No key was requested or embedded, and authenticated lyric retrieval was not tested.
- **[ChartLyrics](https://www.chartlyrics.com/api.aspx)** has a legacy public API, but HTTPS checks of both its documentation host and API host failed certificate hostname validation during this review. It is not suitable for integration unless secure access is restored. Lyrx must not bypass certificate checks or add an insecure HTTP exception.
