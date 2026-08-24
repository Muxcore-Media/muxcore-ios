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
| Search (library + remote discover + scope picker) | Yes |
| Discover detail + request | Yes |
| Favorites, Queue, Playlists | Yes |
| In progress (requests + non-watchable library) | Yes |
| Collections, Studios, Upcoming | Yes |
| Music, Books, Comics, Audiobooks (+ lyrics on artist tracks) | Yes |
| Home videos, Music videos, Mixed | Yes |
| Live TV (guide, recordings, timers) | Yes |
| Userdata sync (`/api/userdata` pull/push) | Yes |
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

## Linux tests (normalizers)

```bash
cd muxcore-ios
nix-shell -p swift --run 'swift test'
```

## Related

- Web client: `media-ui-app/`
- BFF: `_mvp/cmd/mediauiprox/`
