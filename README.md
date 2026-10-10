# Spark Hub releases

Binaries, checksums and install scripts for the Spark Hub command line: a free launcher for audio games that finds a game in the catalog and, with one command, downloads, verifies, installs and runs it. Built for blind and low-vision players: every message is one line a screen reader can speak.

## Install

macOS (Apple Silicon):

```sh
curl -fsSL https://raw.githubusercontent.com/unlocked-spark/sparkhub-releases/main/install.sh | sh
```

Windows (64-bit), in PowerShell:

```powershell
irm https://raw.githubusercontent.com/unlocked-spark/sparkhub-releases/main/install.ps1 | iex
```

The scripts download the binary for your system from the latest release, verify its SHA-256 checksum against the published `.sha256` file, place it in a folder of your user profile (no administrator rights) and add that folder to your PATH. Then:

```
sparkhub search swamp
sparkhub install swamp
sparkhub run swamp
```

### Channels and versions

- Latest release: the default.
- Nightly, the newest build from the main branch: `curl -fsSL … | SPARKHUB_CHANNEL=nightly sh` or `$env:SPARKHUB_CHANNEL="nightly"; irm … | iex`.
- A specific version: `SPARKHUB_VERSION=v0.1.0`.
- Uninstall: `sh install.sh --uninstall` or `.\install.ps1 -Uninstall` after saving the script.

Windows SmartScreen and macOS Gatekeeper may show their own warning the first time, because the binaries are not code-signed yet; signing is on the roadmap.

## What is in a release

| File | Purpose |
|---|---|
| `sparkhub-windows-x64.exe`, `sparkhub-macos-arm64` | single-file binaries, no Node.js needed |
| `*.sha256` | checksums the install scripts verify |
| `LICENSE-THIRD-PARTY.txt` | notices for the embedded Node.js runtime |

Source code is not published; see [LICENSE](LICENSE) for what you may do with the binaries. Questions, ideas and stories about how you play are welcome at the Unlocked Spark Foundation: https://unlockedspark.org
