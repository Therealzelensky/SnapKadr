# Cloud upload: low priority + 512 KB/s throttle

**Date:** 2026-09-14  
**Product:** SnapKadr Beta (`com.snapkadr.app.beta`)  
**Status:** Approved (approach A)

## Problem

Post-session / queue uploads to Yandex Disk (and other cloud destinations) use a default `URLSession` at full line speed. Large `.kadr` packages (tens–hundreds of MB) saturate the link and feel like they steal traffic from calls, VPN, and browsing.

## Goals

- Cap upload throughput at **~512 KB/s** (soft, best-effort).
- Run cloud transfers at **minimal system priority** (utility QoS).
- Keep resume-by-size and logging from v0.1.27.
- No new prefs UI in this change.

## Non-goals

- User-facing speed slider / prefs.
- Pausing uploads on Low Data Mode only (no hard dependency on Network.framework constrained flags alone).
- Parallel multi-file PUTs (stay sequential per package).
- Changing retry/backoff schedule in the queue.

## Approach (A)

Dedicated background `URLSession` + chunked PUT body with a token-bucket / sleep-based rate limiter at 512 000 bytes/s. Session configuration uses utility-class QoS so the system deprioritizes the work under load.

## Design

### Constants (`YandexDiskUploadPolicy` or shared `StenoCloudUploadPolicy`)

| Constant | Value | Notes |
|---|---|---|
| `maxBytesPerSecond` | `512_000` | Soft cap for PUT body bytes |
| `operationTimeout` | `600` | Unchanged (MOVE/DELETE wait) |
| Session QoS | `.utility` | Via `URLSessionConfiguration` / task priority |

Prefer a **shared** policy type used by Yandex (primary traffic). WebDAV/S3 can adopt the same session later if trivial; Yandex-first is enough for this ship.

### Session

- Replace `URLSession.shared` for package uploads with a long-lived session:
  - `networkServiceType = .background` is **not** required (app is LSUIElement; keep foreground-capable session).
  - `waitsForConnectivity = true`
  - Task/`URLSessionConfiguration` priority / QoS oriented to **utility**.
- Meta calls (mkdir, resources GET for size, operation poll) may share the same session; their volume is negligible. Throttle applies to **file PUT bodies** only.

### Throttled upload

Current path: `session.upload(for:fromFile:)` — full speed.

New path for files over a small threshold (e.g. > 64 KB):

1. Request upload `href` as today.
2. Stream local file in chunks (e.g. 64–256 KB).
3. After each chunk (or accumulated window), sleep so average ≤ `maxBytesPerSecond`.
4. Pure helper for tests:  
   `sleepNanos(bytesSent:windowStart:now:maxBytesPerSecond:) -> UInt64`

Small files can stay as a single PUT without sleeping.

### Logging

Append to `~/Library/Logs/SnapKadr.log` via `StenoCloudLog`:

- Session/throttle armed: `Yandex upload throttle 512KB/s utility`
- Unchanged: skip / PUT / MOVE / OK / fail lines

No tokens or full remote paths beyond existing style.

### Tests

Extend `scripts/steno_w4_yandex_tests.swift` (or a tiny pure-policy test):

- `maxBytesPerSecond == 512_000`
- Rate-limit sleep: sending 512_000 bytes in 0 elapsed → sleep ~1s; sending slowly → sleep 0
- Source contains utility session / throttle helper (string smoke, matching existing style)

### Rollout

Beta-only ship after implement + manual check: one pending package uploads while browsing; Activity Monitor / feel of network stays usable; logs show throttle line and eventual `upload OK`.

## Risks

| Risk | Mitigation |
|---|---|
| Some upload hosts reject chunked/streamed PUT | Keep Content-Length; use `httpBodyStream` or incremental write on an upload task that sets length upfront |
| Utility QoS starves uploads forever | Still progresses; user can leave Mac idle; queue retries remain |
| 512 KB/s too slow for huge backlog | Accept for v1; prefs out of scope |

## Success criteria

1. Sustained PUT rate stays near 512 KB/s (±20% over multi-second windows) on a quiet link.
2. Uploads do not use `.userInitiated` / default interactive priority.
3. Resume-by-size still skips complete remote files.
4. Unit tests for policy math pass; beta builds clean.
