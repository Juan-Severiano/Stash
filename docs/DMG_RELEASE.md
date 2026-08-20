# Releasing Stash as a notarized DMG

The `Release DMG` GitHub Actions workflow archives the macOS app, signs it with a Developer ID certificate, notarizes it with Apple, staples the ticket, and attaches `Stash.dmg` to a GitHub Release. The landing page always links to the latest release asset.

## One-time GitHub configuration

In the repository's **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `DEVELOPER_ID_APPLICATION` | Exact certificate name, for example `Developer ID Application: Your Name (TEAMID)` |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` export of that Developer ID Application certificate |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_API_KEY_ID` | App Store Connect API key ID with Developer role or higher |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID |
| `APPLE_API_KEY_BASE64` | Base64-encoded contents of the API key `.p8` file |

Do not commit certificates, `.p12` files, API keys, or passwords.

## Publish a release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode.
2. Push the release commit and tag.
3. In GitHub, open **Actions → Release DMG → Run workflow**.
4. Enter the release tag, such as `v1.0.1`.
5. After the workflow succeeds, the release includes `Stash.dmg` and the landing-page download works automatically.

## Local verification build

To create an unsigned, non-notarized DMG for local testing only:

```sh
SKIP_SIGNING=1 SKIP_NOTARIZATION=1 bash scripts/build-dmg.sh
```

For distribution outside the Mac App Store, always use the signed and notarized release workflow. The Mac App Store submission itself continues through Xcode/App Store Connect.
