# homebrew-tap

Homebrew tap and CLI release artifacts for [Attestbox](https://github.com/kodejedi/attestbox), the agent runtime with provable containment.

## Install the CLI

```sh
brew install kodejedi/tap/attestbox
```

or with the one-line installer:

```sh
curl -fsSL https://raw.githubusercontent.com/kodejedi/homebrew-tap/main/install-cli.sh | sh
```

## What lives here

- `Formula/attestbox.rb` — the Homebrew formula, written by GoReleaser on each release. Do not edit it by hand.
- `install-cli.sh` — the installer above. The canonical copy is `hack/install-cli.sh` in kodejedi/attestbox; the release workflow copies it here on every release. Do not edit it here.
- Releases — the signed CLI tarballs (`attestbox_<version>_<os>_<arch>.tar.gz`), `checksums.txt`, and the cosign keyless signature and certificate on it, because kodejedi/attestbox is private and cannot serve public downloads.
