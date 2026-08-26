# muxcore-ios

SwiftUI native client — **parity target: `media-ui-app`**. BFF is **mediauiprox**; keep `APIClient` aligned with `media-ui-app/src/api/client.ts`.

## Dev

- Xcode 15+, iOS 17+
- `xcodegen generate` then open `MuxCore.xcodeproj`
- Default server: `https://mux.zem.systems`

## Auth (native)

Login uses BFF mobile auth: `GET /api/mobile/auth/login` → auth-local → `muxcore://auth/callback?code=…` → `POST /api/mobile/session`. URL scheme `muxcore` is registered in `project.yml`; no Associated Domains / `webcredentials` entitlements required.

## Architecture

- `APIClient` + `APIClient+Extended` — all BFF endpoints
- `UserDataStore` — mirrors `media-ui-app/src/lib/userdata.ts` (local UserDefaults + `/api/userdata` sync)
- `NavCatalog` — mirrors `nav-catalog.ts` (capability-gated More menu)
- Views map 1:1 to `media-ui-app/src/pages/*`

## When changing APIs

1. Update API client extensions
2. Update `MediaNormalizer.swift`
3. Update web `media-ui-app` client if BFF changed
4. `nix-shell -p swift --run 'swift test'`

## Known iOS gaps vs web

- Custom video OSD (web `VideoPlayer.tsx`) — iOS uses `AVPlayer` + resume/skip-intro from prefs
- Display theme (dark/light/system) applied via `preferredColorScheme`
