---
title: Continuous integration
description: Build with the committed lock in CI and keep otok's cache between runs.
sidebar:
  order: 4
---

In CI, install otok, restore its cache, and build what `otok.lock` says:

```sh
otok install --locked
```

`--locked` fails instead of changing the lock, so CI never builds anything that was not committed. The libraries come
from otok's cache when they were built before with the same inputs and toolchain; otherwise they are built.

The lock must already hold the runner's system: a lock made on a Mac fails `--locked` on a Windows runner until
`otok install` has run once on Windows and that change is committed
([the lock across machines](/guides/targets/#the-lock-across-machines)).

## The key of the cache

A library is found in otok's cache only when everything that went into its build is the same: the lock's versions and
recipes, but also the project's flags and options in `otok.toml`, which the lock does not hold, and the toolchain of the
runner. Key the CI cache by all three:

- `otok.toml` and `otok.lock` (`hashFiles('otok.toml', 'otok.lock')`);
- the toolchain's version: Xcode on macOS, MSVC on Windows, the compiler on Linux, read in a step before the cache.

`actions/cache` saves the cache only when no cache had the exact key. With a key of the lock alone, a changed flag or a
new Xcode of the runner's image restores the old cache under the same key: otok builds the libraries again, as it must,
and the cache is never saved with them, so every later run builds them again too. With the toolchain and `otok.toml` in
the key, such a run misses the key, restores the newest older cache through `restore-keys` (whatever did not change
comes from it), and saves the new one.

## GitHub Actions on macOS

```yaml
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Install otok
        run: brew install otok-dev/tap/otok

      - name: Toolchain
        id: toolchain
        run: echo "id=$(xcodebuild -version | tr -cs '[:alnum:].' '-')" >> "$GITHUB_OUTPUT"

      - name: otok's cache
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/otok
          key: otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-${{ hashFiles('otok.toml', 'otok.lock') }}
          restore-keys: |
            otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-
            otok-${{ runner.os }}-

      - name: Libraries
        run: otok install --locked

      - name: App
        run: xcodebuild -scheme App -destination 'generic/platform=iOS Simulator' build
```

## Windows

Download the release's zip, check it against the `.sha256` beside it, and put its directory on the `PATH`
(`otok-sandbox.dll` stays beside `otok.exe`); the runner's Visual Studio builds the libraries:

```yaml
    runs-on: windows-2025
    steps:
      - uses: actions/checkout@v4

      - name: Install otok
        shell: pwsh
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          # the latest release, never a release candidate; or name one: $version = '0.5.7'
          $version = (gh release view --repo otok-dev/otok --json tagName -q .tagName).TrimStart('v')
          $name = "otok-$version-windows-x64"
          $dir = Join-Path $env:RUNNER_TEMP otok
          $url = "https://github.com/otok-dev/otok/releases/download/v$version/$name.zip"
          Invoke-WebRequest $url -OutFile "$dir.zip"
          # into a file: GitHub serves the .sha256 as binary, whose .Content would be bytes
          Invoke-WebRequest "$url.sha256" -OutFile "$dir.zip.sha256"
          $expected = ((Get-Content -Raw "$dir.zip.sha256").Trim() -split '\s+')[0].ToLowerInvariant()
          if ((Get-FileHash -Algorithm SHA256 "$dir.zip").Hash.ToLowerInvariant() -ne $expected) { throw "otok: sha256 mismatch" }
          Expand-Archive "$dir.zip" -DestinationPath $dir
          (Get-ChildItem $dir -Recurse -Filter otok.exe | Select-Object -First 1).DirectoryName >> $env:GITHUB_PATH

      - name: Toolchain
        id: toolchain
        shell: pwsh
        run: |
          $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
          "id=msvc-$((Get-ChildItem "$vs\VC\Tools\MSVC" | Sort-Object Name -Descending | Select-Object -First 1).Name)" >> $env:GITHUB_OUTPUT

      - name: otok's cache
        uses: actions/cache@v4
        with:
          path: ~\AppData\Local\otok\cache
          key: otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-${{ hashFiles('otok.toml', 'otok.lock') }}
          restore-keys: |
            otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-
            otok-${{ runner.os }}-

      - name: Libraries
        run: otok install --locked
```

## Linux

The install script puts otok on the runner. Builds run in bubblewrap, and Ubuntu 24.04 lets `bwrap` make its
namespaces only once the restriction of unprivileged user namespaces is lifted (newer Ubuntu gives `bwrap` an
AppArmor profile of its own):

```yaml
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - name: Install otok
        run: |
          sudo apt-get install -y bubblewrap
          sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
          curl -fsSL https://otok-dev.github.io/install.sh | sh -s -- --dir "$RUNNER_TEMP/otok"
          echo "$RUNNER_TEMP/otok" >> "$GITHUB_PATH"

      - name: Toolchain
        id: toolchain
        run: echo "id=$(cc --version | head -n 1 | tr -cs '[:alnum:].' '-')" >> "$GITHUB_OUTPUT"

      - name: otok's cache
        uses: actions/cache@v4
        with:
          path: ~/.cache/otok
          key: otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-${{ hashFiles('otok.toml', 'otok.lock') }}
          restore-keys: |
            otok-${{ runner.os }}-${{ steps.toolchain.outputs.id }}-
            otok-${{ runner.os }}-

      - name: Libraries
        run: otok install --locked
```

Where `bwrap` cannot make its namespaces, inside most Docker containers, otok stops before the first build and says
so; there the container is the isolation, and `OTOK_SANDBOX=0` (or `--no-sandbox`) builds without the sandbox.

## When a build fails

otok prints the end of the build's log and keeps the whole log in the cache's `failed/` directory. With
`OTOK_KEEP_BUILD_DIRS=1` (or `--keep-build-dirs`) it keeps the build's work directory there too, which holds
`sandbox.log`: what the sandbox refused the build, often the cause when a build passes on your machine and fails on the
runner. Upload those files, not the whole work directory:

```yaml
      - name: Libraries
        env:
          OTOK_KEEP_BUILD_DIRS: 1
        run: otok install --locked

      - name: Logs of failed builds
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: otok-failed-builds
          path: |
            ~/AppData/Local/otok/cache/failed/*/build.log
            ~/AppData/Local/otok/cache/failed/*/key.txt
            ~/AppData/Local/otok/cache/failed/*/sandbox.log
          if-no-files-found: ignore
```

(The paths are those of the Windows cache; on macOS and Linux use the cache's directory of the examples above.)

## Other systems

The same pattern works anywhere: the cache is one directory (`OTOK_CACHE_DIR` moves it), and nothing in it depends on
the path of the project. Inputs can be kept on your own servers too, see [Where inputs come from](/guides/fetch/).
