# MuxCore iOS (Swift native)

Native SwiftUI client for the MuxCore consumer stack. Targets **parity with `media-ui-app`** against the same **mediauiprox** BFF.

## Feature parity (media-ui-app)

| Area | iOS |
|------|-----|
| Auth (web login + session cookie) | Yes |
| Forgot password request | Yes |
| Quick Connect approve | Yes |
| Home (continue watching, next up, favorites, recommended, in-progress banner) | Yes |
| Movies / TV browse + detail | Yes |
| Search (library + remote discover) | Yes |
| Discover detail + request | Yes |
| Favorites, Queue, Playlists | Yes |
| In progress (requests + non-watchable library) | Yes |
| Collections, Studios, Upcoming | Yes |
| Music, Books, Comics, Audiobooks | Yes |
| Home videos, Music videos, Mixed | Yes |
| Live TV (guide, recordings, timers) | Yes |
| Userdata sync (`/api/userdata` pull/push) | Yes |
| Settings (profile, display, home, playback, subtitles, controls) | Yes |
| Playback resolve + AVPlayer + resume position | Yes |
| Jellyfin deep-link on detail | Yes |

### Intentional gaps vs web

- Full custom **Video OSD** (keyboard shortcuts, skip intro UI, subtitle picker overlay) — iOS uses system `VideoPlayer` + prefs for resume/skip-intro seek
- Unified search **scope picker** (all/movies/tv/add) — library substring match + remote results
- **Theme** prefs stored/synced but iOS uses system light/dark (no custom CSS theme engine)
- Music **lyrics** panel on artist pages (inline with track playback)

## Open on Mac

```bash
cd muxcore-ios
nix-shell -p xcodegen --run 'xcodegen generate'
open MuxCore.xcodeproj
```

Default server: `https://mux.zem.systems`

## Linux tests (normalizers)

```bash
cd muxcore-ios
nix-shell -p swift --run 'swift test'
```

## Related

- Web client: `media-ui-app/`
- BFF: `_mvp/cmd/mediauiprox/`
