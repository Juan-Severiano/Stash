# Stash

A quieter clipboard manager for macOS. Stash keeps the snippets, links, images, screenshots, and files you copy close at hand, searchable, and entirely on your Mac.

[Download the latest release](https://github.com/Juan-Severiano/Stash/releases/latest/download/Stash.dmg) · Requires macOS 26.5 or later

## Features

- **Instant recall** — open your clipboard history from anywhere with `⌥ V`
- **Search and filter** — find past copies by text, links, images, files, code, or screenshots
- **Pin what matters** — keep recurring snippets and arrange them into collections
- **Local by design** — no accounts, ads, analytics, or cloud sync; your history never leaves your Mac

## Building from source

Requirements: Xcode with the macOS 26 SDK.

```bash
xcodebuild -project Stash.xcodeproj -scheme Stash -configuration Release -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

Or open `Stash.xcodeproj` in Xcode and run the `Stash` scheme.

## Releasing a signed, notarized build

See [docs/DMG_RELEASE.md](docs/DMG_RELEASE.md) for the full process: signing with a Developer ID certificate, notarizing with Apple, and publishing a `.dmg` as a GitHub release via the `Release DMG` workflow.

## Project structure

- `Stash/` — app source (SwiftUI), organized by feature: `Clipboard`, `History`, `Paste`, `Hotkeys`, `Settings`, `Privacy`, `Collections`, `Screenshots`, `UI`
- `scripts/build-dmg.sh` — builds, signs, notarizes, and packages the app into a `.dmg`
- `.github/workflows/` — CI build validation and the signed release pipeline
- `landing/` — marketing site source (published to GitHub Pages)

## Privacy

Stash stores all clipboard history locally in a SQLite database on your Mac. There are no accounts, no analytics, and no network requests. See the in-app Privacy settings for details on what is and isn't retained.
