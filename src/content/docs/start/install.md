---
title: Install otok
description: Install otok with Homebrew, Scoop or the release archive.
sidebar:
  order: 1
---

otok is one program with no dependencies of its own. The tools the recipes need to build (CMake, Ninja,
Python, Meson, make and others) are built or downloaded by their own recipes, so you install only what builds
for your target: Xcode, Visual Studio, the Android NDK or a Linux compiler.

## macOS

With [Homebrew](https://brew.sh):

```sh
brew install otok-dev/tap/otok
```

The Apple target builds with the Xcode that `xcode-select -p` shows; install Xcode from the App Store and open it
once to accept its license. otok fetches sources with `git`, which Xcode's command line tools provide.

## Windows

With [Scoop](https://scoop.sh):

```powershell
scoop bucket add otok https://github.com/otok-dev/scoop-bucket
scoop install otok
```

The Windows target builds with Visual Studio 2022 or 2026 and its *Desktop development with C++* workload
(otok finds the newest installation by itself). otok needs `git` on the `PATH` (`scoop install git`).

Builds run in an AppContainer, the sandbox of Windows, which needs no administrator rights. Keep `otok-sandbox.dll`
beside `otok.exe` (Scoop and the release archive have both): otok puts it in every process of a build.

## Linux

Download `otok-<version>-linux-x64.tar.gz` from the [latest release](https://github.com/otok-dev/otok/releases/latest)
and put `otok` on your `PATH`:

```sh
tar -xzf otok-0.4.0-linux-x64.tar.gz
install -m 755 otok-0.4.0-linux-x64/otok ~/.local/bin/otok
```

The binary needs only glibc and the GNU C++ runtime. The Linux target builds with GCC or Clang, and otok runs every
build in [bubblewrap](https://github.com/containers/bubblewrap), so `bwrap` must be on the `PATH`:

```sh
sudo apt install git build-essential bubblewrap
```

Without it otok stops before the first build; `--no-sandbox` (or `sandbox = false` in
[`config.toml`](/reference/config/)) builds unisolated, in a container that is itself the isolation, for example.

## Android

The Android target needs the [NDK](https://developer.android.com/ndk/downloads) on any of the three systems. otok
takes the newest NDK of the Android SDK (as Android Studio installs it), or the one `ANDROID_NDK_HOME` names, or
`android-ndk` of [`config.toml`](/reference/config/).

## Build from source

On macOS, Homebrew already does: the formula builds otok from the release's source archive on your Mac. Elsewhere,
or to check a release binary, build it yourself.

**The source.** Every [release](https://github.com/otok-dev/otok/releases) has `otok-<version>.tar.gz` with its
`.sha256`, the complete source with its submodule; or clone the tag:

```sh
git clone --recurse-submodules --branch v0.4.0 https://github.com/otok-dev/otok
```

**What it needs.** A C++23 compiler (Visual Studio 2026, or the GCC and Clang of a current Linux, or Xcode's Clang),
CMake 3.25 or later with Ninja, and a checkout of [vcpkg](https://github.com/microsoft/vcpkg), from which otok's
dependencies (libcurl, libarchive, toml++ and others) are built and linked statically. The versions of the
dependencies are pinned by the baseline in `vcpkg-configuration.json`.

### As the releases are built

The scripts that build the release binaries are in the source, `tools/release/`; GitHub Actions runs them at every
release tag (`.github/workflows/release.yml`). Run the one of your system, with `VCPKG_ROOT` naming your vcpkg:

```sh
VCPKG_ROOT=~/vcpkg tools/release/linux-x64.sh        # Linux: build/release-linux/
VCPKG_ROOT=~/vcpkg tools/release/macos-universal.sh  # macOS: build/release-macos/
```

```powershell
$env:VCPKG_ROOT = "C:\vcpkg"; tools\release\windows-x64.ps1   # Windows: build\release-windows\
```

Each builds otok without its tests, checks that it loads only the system's own libraries, and packs it as the release
does.

### With CMake

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build
ctest --test-dir build
```

The tests need no network. `-DOTOK_BUILD_TESTS=OFF` builds otok alone. On Windows, add
`-DVCPKG_OVERLAY_TRIPLETS=triplets -DVCPKG_TARGET_TRIPLET=x64-windows-otok`, the triplet of static libraries with the
dynamic CRT that the solution uses too (vcpkg's default on Windows builds DLLs). vcpkg needs its own prerequisites to
build the dependencies: on Linux `git curl zip unzip tar pkg-config` and a Perl.

### With Visual Studio

The solution `otok.slnx` builds otok and its tests with MSBuild. With vcpkg checked out beside the source (`..\vcpkg`,
or `VCPKG_ROOT` naming it), install the dependencies once, then open the solution or build it from a developer prompt:

```bat
vcpkg-install.cmd
msbuild otok.slnx /p:Configuration=Release /p:Platform=x64
build\vs\x64\Release\otok-tests.exe
```

`otok.exe` is in `build\vs\x64\Release\`.

## Check

```sh
otok --version
otok search zlib
```

`otok search` reads the [public index](https://otok-dev.github.io/index/) of recipes: if it answers, otok is ready.
