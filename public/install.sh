#!/bin/sh
# Otok (c) Alexander A Pototskiy
# SPDX-License-Identifier: CC0-1.0
#
# Installs otok on Linux from a release of https://github.com/otok-dev/otok: the static binary of the machine's
# architecture (x64 or arm64), which runs on every distribution, checked against the release's .sha256.
#
#   curl -fsSL https://otok-dev.github.io/install.sh | sh
#   curl -fsSL https://otok-dev.github.io/install.sh | sh -s -- --version 0.5.0 --dir /usr/local/bin
#
# --version (or OTOK_VERSION): a release, 0.5.0 or a tag v0.5.0-rc1 (default: the latest).
# --dir (or OTOK_INSTALL_DIR): where otok goes (default: ~/.local/bin). Running it again updates otok.
set -eu

repository=https://github.com/otok-dev/otok
version=${OTOK_VERSION:-}
dir=${OTOK_INSTALL_DIR:-$HOME/.local/bin}

say() { printf '%s\n' "otok-install: $*" >&2; }
fail() { say "error: $*"; exit 1; }

while [ $# -gt 0 ]; do
    case $1 in
        --version) [ $# -ge 2 ] || fail "--version needs a value"; version=$2; shift 2 ;;
        --dir) [ $# -ge 2 ] || fail "--dir needs a value"; dir=$2; shift 2 ;;
        -h | --help) printf '%s\n' "install.sh [--version VERSION] [--dir DIRECTORY]: installs otok on Linux" \
                         "(default: the latest release, in ~/.local/bin; also OTOK_VERSION and OTOK_INSTALL_DIR)"; exit 0 ;;
        *) fail "unknown argument '$1'" ;;
    esac
done

case $(uname -s) in
    Linux) ;;
    Darwin) fail "on macOS, install otok with Homebrew: brew install otok-dev/tap/otok" ;;
    *) fail "this script installs otok on Linux; see https://otok-dev.github.io/start/install/" ;;
esac
case $(uname -m) in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) fail "no release binary for $(uname -m); build otok from source: https://otok-dev.github.io/start/install/#build-from-source" ;;
esac

# fetch URL FILE / fetch URL - : with curl or wget, whichever the system has
if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL --proto '=https' -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -q -O "$2" "$1"; }
else
    fail "neither curl nor wget is installed"
fi

# latest_tag: the tag of the latest release; with curl from where releases/latest leads (no limit of requests, which
# the API has for shared addresses such as CI runners'), with wget from the API
latest_tag() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSLI --proto '=https' -o /dev/null -w '%{url_effective}' "$repository/releases/latest" | sed -n 's|.*/tag/\(v[^/]*\)$|\1|p'
    else
        fetch "https://api.github.com/repos/otok-dev/otok/releases/latest" - | sed -n 's/^ *"tag_name": *"\(v[^"]*\)".*/\1/p' | head -n 1
    fi
}

# the tag: the one asked for, or the latest release's
case $version in
    '') tag=$(latest_tag) || tag=
        [ -n "$tag" ] || fail "cannot find the latest release of $repository (set OTOK_VERSION)" ;;
    v*) tag=$version ;;
    *) tag=v$version ;;
esac
printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$' || fail "'$version' is not a version of otok"
# a prerelease's files carry the version it leads to: v0.5.0-rc1 has otok-0.5.0-…
number=$(printf '%s\n' "$tag" | sed 's/^v//; s/-rc[0-9]*$//')
name=otok-$number-linux-$arch

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
say "downloading $name.tar.gz ($tag)"
fetch "$repository/releases/download/$tag/$name.tar.gz" "$tmp/$name.tar.gz" || fail "no $name.tar.gz in the release $tag"
fetch "$repository/releases/download/$tag/$name.tar.gz.sha256" "$tmp/$name.tar.gz.sha256" ||
    fail "no $name.tar.gz.sha256 in the release $tag"

expected=$(cut -d' ' -f1 "$tmp/$name.tar.gz.sha256")
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$name.tar.gz" | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$tmp/$name.tar.gz" | cut -d' ' -f1)
else
    fail "neither sha256sum nor shasum is installed to check the download"
fi
[ "$actual" = "$expected" ] || fail "$name.tar.gz does not match its .sha256 (expected $expected, got $actual)"

tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
"$tmp/$name/otok" --version >/dev/null 2>&1 || fail "the downloaded otok does not run on this machine"

# beside the old one first, then renamed over it: a running otok keeps its file
mkdir -p "$dir" || fail "cannot create $dir"
cp "$tmp/$name/otok" "$dir/.otok.new" || fail "cannot write to $dir (choose another with --dir)"
chmod 755 "$dir/.otok.new"
mv -f "$dir/.otok.new" "$dir/otok"
say "installed $("$dir/otok" --version | head -n 1) in $dir"

case :$PATH: in
    *:"$dir":*) ;;
    *) say "$dir is not on your PATH; add it, for example: echo 'export PATH=\"$dir:\$PATH\"' >> ~/.profile" ;;
esac
command -v bwrap >/dev/null 2>&1 ||
    say "otok runs builds in bubblewrap: install it (apt install bubblewrap, dnf install bubblewrap, pacman -S bubblewrap)"
command -v git >/dev/null 2>&1 || say "otok fetches sources with git: install it"
