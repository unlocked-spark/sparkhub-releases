#!/bin/sh
# Spark Hub installer for macOS (Apple Silicon). Linux and Intel Macs follow later.
#
#   curl -fsSL https://raw.githubusercontent.com/unlocked-spark/sparkhub-releases/main/install.sh | sh
#
# Options (after `sh -s --` when piping, or as plain arguments when run from a file):
#   --version vX.Y.Z   install that release instead of the latest one
#   --channel nightly  install the newest build from the main branch
#   --dir <dir>        install directory (default: ~/.local/bin)
#   --uninstall        remove the binary and the PATH line this script added
# The same can be set with SPARKHUB_VERSION, SPARKHUB_CHANNEL and SPARKHUB_INSTALL_DIR.
set -eu

REPO="unlocked-spark/sparkhub-releases"
VERSION="${SPARKHUB_VERSION:-}"
CHANNEL="${SPARKHUB_CHANNEL:-latest}"
DIR="${SPARKHUB_INSTALL_DIR:-$HOME/.local/bin}"
UNINSTALL=0
MARKER="# Spark Hub installer"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$1"; }
fail() { printf 'sparkhub installer: %s\n' "$1" >&2; exit 1; }

profile_file() {
  case "${SHELL:-}" in
    */zsh) echo "$HOME/.zshrc" ;;
    */bash) if [ "$(uname -s)" = "Darwin" ]; then echo "$HOME/.bash_profile"; else echo "$HOME/.bashrc"; fi ;;
    *) echo "$HOME/.profile" ;;
  esac
}

if [ "$UNINSTALL" -eq 1 ]; then
  rm -f "$DIR/sparkhub"
  profile="$(profile_file)"
  if [ -f "$profile" ] && grep -q "$MARKER" "$profile"; then
    tmp="$(mktemp)"
    grep -v "$MARKER" "$profile" > "$tmp" || true
    cat "$tmp" > "$profile"
    rm -f "$tmp"
  fi
  say "Spark Hub was removed from $DIR. Installed games and settings stay in your data directory (sparkhub config path showed where)."
  exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"
case "$os/$arch" in
  Darwin/arm64) asset="sparkhub-macos-arm64" ;;
  Darwin/*) fail "Spark Hub ships for Apple Silicon Macs for now; an Intel Mac build is planned." ;;
  Linux/*) fail "Spark Hub for Linux is planned; for now the command line runs on macOS and Windows." ;;
  *) fail "Unsupported system: $os $arch." ;;
esac

if [ -n "$VERSION" ]; then
  base="https://github.com/$REPO/releases/download/$VERSION"
elif [ "$CHANNEL" = "nightly" ]; then
  base="https://github.com/$REPO/releases/download/nightly"
elif [ "$CHANNEL" = "latest" ]; then
  base="https://github.com/$REPO/releases/latest/download"
else
  fail "Unknown channel $CHANNEL; use latest or nightly."
fi

command -v curl >/dev/null 2>&1 || fail "curl is required."
if command -v shasum >/dev/null 2>&1; then
  sha_cmd="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  sha_cmd="sha256sum"
else
  fail "shasum or sha256sum is required to verify the download."
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
say "Downloading $asset from $base"
curl -fsSL --retry 3 -o "$work/$asset" "$base/$asset" || fail "Download failed. If no release exists yet, try: curl ... | SPARKHUB_CHANNEL=nightly sh"
curl -fsSL --retry 3 -o "$work/$asset.sha256" "$base/$asset.sha256" || fail "The checksum file is missing from the release."
expected="$(cut -d ' ' -f 1 "$work/$asset.sha256")"
actual="$(cd "$work" && $sha_cmd "$asset" | cut -d ' ' -f 1)"
[ "$expected" = "$actual" ] || fail "Checksum mismatch: expected $expected, got $actual. The download was discarded."
say "Checksum verified."

mkdir -p "$DIR"
chmod 755 "$work/$asset"
mv -f "$work/$asset" "$DIR/sparkhub"
say "Installed $DIR/sparkhub"

case ":$PATH:" in
  *":$DIR:"*) ;;
  *)
    profile="$(profile_file)"
    if ! { [ -f "$profile" ] && grep -q "$MARKER" "$profile"; }; then
      printf '\nexport PATH="%s:$PATH" %s\n' "$DIR" "$MARKER" >> "$profile"
    fi
    say "Added $DIR to PATH in $profile. Open a new terminal, or run: export PATH=\"$DIR:\$PATH\""
    ;;
esac

say "Spark Hub $("$DIR/sparkhub" --version) is ready. Try: sparkhub search swamp"
