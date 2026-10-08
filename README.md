# MuxCore iOS (Swift native)

Native SwiftUI client for the MuxCore consumer stack. Targets **parity with `media-ui-app`** against the same **mediauiprox** BFF.

## Feature parity (media-ui-app)

| Area | iOS |
|------|-----|
| Auth (mobile deep link + session token) | Yes |
| Forgot password request | Yes |
| Quick Connect approve | Yes |
| Home (continue watching, next up, favorites, recommended, in-progress banner) | Yes |
| Movies / TV browse + detail | Yes |
| Search (library + remote discover + scope picker) | Yes |
| Discover detail + request | Yes |
| Favorites, Queue, Playlists | Yes |
| In progress (requests + non-watchable library) | Yes |
| Collections, Studios, Upcoming | Yes |
| Music, Books, Comics, Audiobooks (+ lyrics on artist tracks) | Yes |
| Home videos, Music videos, Mixed | Yes |
| Live TV (guide, recordings, timers) | Yes |
| Userdata sync (`/api/userdata` pull/push) | Partial — native request and recovery fixtures; provider/device acceptance pending |
| Settings (profile, display, home, playback, subtitles, controls) | Yes |
| Playback resolve + AVPlayer + resume position | Yes |
| Custom Video OSD (skip intro, subtitle picker, scrubber) | Yes |
| Jellyfin deep-link on detail | Yes |

### Intentional gaps vs web

- External keyboard shortcuts on iOS (space/arrow) only when **Controls → keyboard shortcuts** is enabled and a hardware keyboard is attached

## Open on Mac

```bash
cd muxcore-ios
nix-shell -p xcodegen --run 'xcodegen generate'
open MuxCore.xcodeproj
```

Default server: `https://mux.zem.systems`

Native sign-in opens the server web login via `/api/mobile/auth/login` and returns through the `muxcore://auth/callback` deep link (no Associated Domains setup).

## Portable tests (normalizers, native requests, userdata sync)

```bash
cd muxcore-ios
swift test --jobs 2
# On a Nix workstation: nix-shell -p swift --run 'swift test --jobs 2'
```

### Userdata sync (T-M4-09; FR-PLAY-004 remains partial)

Native JSON calls use the BFF session token as `Authorization: Bearer`, with a
cookie-free URLSession and no redirects. API calls must remain on the configured
HTTP(S) origin (scheme, host and effective port). Mobile login exchanges a code at
`/api/mobile/session` and verifies stable user/tenant identity at `/api/session`.
The existing shared-cookie setup for AVPlayer remains separate; playback runtime
compatibility still needs an Apple device/simulator check. No provider dependency,
mesh certificate or direct userdata-local connection is used on the device.

Settings → Data sync shows pending changes, errors and a retry action. Edits are
saved in a UserDefaults record scoped to the verified server/user/tenant, then
retried after launch, foregrounding, another edit or manual retry. Failed writes
retain pending intent. Writes serialize even across logout/re-login; earlier GET
or PUT completions cannot replace newer edits or another account's data. Pulls
preserve dirty fields. Each write refreshes and carries the merged preferences,
playlists and queue because the provider defaults omitted sections. Progress and
favorites maps contain only entries edited locally; pending entry IDs survive relaunch. Unknown preference keys received from the
server are retained on the wire; the provider's typed model may still drop keys it
does not support. Unreadable scoped records pause syncing and remain preserved.

Upgrading from the unscoped cache requires a fresh sign-in. Legacy `v1` userdata
keys remain on the device, but are never assigned to a guessed owner or uploaded.
Signing out hides the current account's data and retains its pending record for a
later verified sign-in to the same server/user/tenant.

“Last sync acknowledged by your server” means the BFF accepted the request and
returned the expected fields. It does **not** prove userdata-local persistence:
the current BFF can acknowledge its own file fallback. Actual BFF/provider and
app restart, fresh-device, offline recovery and cross-device checks remain open.
The BFF's current favorites merge cannot represent deletions by omission; an
unconfirmed removal stays pending with an explicit error. Fixing that protocol
requires coordinated backend work. The API has no conditional revision contract,
so simultaneous writes from different devices can still replace each other's
preferences, playlists or queue between a GET and PUT. An absent session tenant can disagree with
userdata's `default` tenant when tenant mode is enabled; a nonempty session tenant
can disagree when tenant mode is disabled. These mismatched configurations fail
closed instead of relaxing account isolation. Quick Connect approval is present
in this app; bearerless Quick Connect sessions on other devices do not establish
upstream provider authority.

Validation on 2026-10-08: Swift 6.0.3 Linux `swift test --jobs 2` passes 45 tests
(31 new request/sync fixtures). These execute production API and synchronization
logic, including offline/relaunch, stale responses, account/tenant isolation,
corrupt storage and failed acknowledgement persistence. Redirect coverage is a
delegate contract fixture, not a real socket redirect integration test. SwiftPM
excludes Apple-only Keychain, browser authentication and SwiftUI wiring. The manual
`iOS IPA` workflow must compile the complete app; device/simulator authentication,
AVPlayer and durable provider roundtrips remain unverified here.

## Related

- Web client: `media-ui-app/`
- BFF: `_mvp/cmd/mediauiprox/`
