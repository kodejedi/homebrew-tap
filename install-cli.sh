#!/bin/sh
# Installs the attestbox CLI from the signed releases published to
# kodejedi/homebrew-tap (kodejedi/attestbox is private, so the artifacts live
# on the tap). This file is the canonical copy; the release workflow
# (.github/workflows/release-cli.yml) copies it to the tap's root on every
# release, where it is served as
#   curl -fsSL https://raw.githubusercontent.com/kodejedi/homebrew-tap/main/install-cli.sh | sh
set -eu

REPO="kodejedi/homebrew-tap"
BIN="attestbox"

say() { printf '%s\n' "$*"; }
die() { printf 'install-cli: %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "needs $1, which is not installed"; }

need curl
need tar
need uname

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
	darwin | linux) ;;
	*) die "unsupported operating system: $os (builds exist for darwin and linux)" ;;
esac

arch=$(uname -m)
case "$arch" in
	x86_64 | amd64) arch=amd64 ;;
	arm64 | aarch64) arch=arm64 ;;
	*) die "unsupported architecture: $arch (builds exist for amd64 and arm64)" ;;
esac

say "Resolving the latest $BIN release from $REPO"
tag=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
	sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
case "$tag" in
	v*) ;;
	*) die "no release found in $REPO yet" ;;
esac
version=${tag#v}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

tarball="${BIN}_${version}_${os}_${arch}.tar.gz"
base="https://github.com/$REPO/releases/download/$tag"
say "Downloading $tarball ($tag)"
curl -fsSL "$base/$tarball" -o "$tmp/$tarball"
curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt"
# Optional, only when cosign is on the machine: verify the keyless signature
# on the checksum file. Absence of cosign is not a failure; the checksum
# below still comes over TLS from the release.
if command -v cosign >/dev/null 2>&1; then
	curl -fsSL "$base/checksums.txt.sig" -o "$tmp/checksums.txt.sig"
	curl -fsSL "$base/checksums.txt.pem" -o "$tmp/checksums.txt.pem"
	cosign verify-blob \
		--signature "$tmp/checksums.txt.sig" \
		--certificate "$tmp/checksums.txt.pem" \
		--certificate-oidc-issuer https://token.actions.githubusercontent.com \
		--certificate-identity-regexp "https://github.com/kodejedi/attestbox/" \
		"$tmp/checksums.txt" >/dev/null
	say "Signature verified (cosign keyless)"
else
	say "cosign not installed; verifying the checksum only"
fi

(
	cd "$tmp"
	if command -v sha256sum >/dev/null 2>&1; then
		grep "  $tarball\$" checksums.txt | sha256sum -c - >/dev/null
	elif command -v shasum >/dev/null 2>&1; then
		grep "  $tarball\$" checksums.txt | shasum -a 256 -c - >/dev/null
	else
		die "neither sha256sum nor shasum is installed; cannot verify the download"
	fi
)
say "Checksum verified"

tar -xzf "$tmp/$tarball" -C "$tmp"
[ -f "$tmp/$BIN" ] || die "$tarball did not contain $BIN"

# Prefer /usr/local/bin when it is writable (or passwordless sudo can make it
# so); otherwise install for this user only. Never prompt for a sudo
# password: piped into sh, stdin is the script, not a terminal.
if [ -w /usr/local/bin ]; then
	dest=/usr/local/bin
	sudo=""
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
	dest=/usr/local/bin
	sudo="sudo -n"
else
	dest="$HOME/.local/bin"
	sudo=""
	mkdir -p "$dest"
fi
$sudo install -m 0755 "$tmp/$BIN" "$dest/$BIN"

say "Installed $dest/$BIN"
"$dest/$BIN" version 2>/dev/null || say "Run: $dest/$BIN version"
case ":$PATH:" in
	*":$dest:"*) ;;
	*) say "Note: $dest is not on your PATH; add it to use $BIN" ;;
esac
