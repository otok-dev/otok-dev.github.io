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

## GitHub Actions on macOS

```yaml
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Install otok
        run: brew install otok-dev/tap/otok

      - name: otok's cache
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/otok
          key: otok-${{ runner.os }}-${{ hashFiles('otok.lock') }}
          restore-keys: otok-${{ runner.os }}-

      - name: Libraries
        run: otok install --locked

      - name: App
        run: xcodebuild -scheme App -destination 'generic/platform=iOS Simulator' build
```

The cache is keyed by the lock, with the newest older cache restored when the lock changed: libraries that did not
change come from it, and only the rest is built. A build is found in the cache only for the same toolchain, so a runner
with another Xcode builds again; that is correct, not a miss to fix.

## Windows

Download the release's zip and put `otok.exe` on the `PATH`; the runner's Visual Studio builds the libraries:

```yaml
    runs-on: windows-2025
    steps:
      - uses: actions/checkout@v4

      - name: Install otok
        shell: pwsh
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download --repo otok-dev/otok --pattern 'otok-*-windows-x64.zip' --dir $env:RUNNER_TEMP
          Expand-Archive "$env:RUNNER_TEMP\otok-*-windows-x64.zip" -DestinationPath "$env:RUNNER_TEMP\otok"
          "$env:RUNNER_TEMP\otok" >> $env:GITHUB_PATH

      - name: otok's cache
        uses: actions/cache@v4
        with:
          path: ~\AppData\Local\otok\cache
          key: otok-${{ runner.os }}-${{ hashFiles('otok.lock') }}
          restore-keys: otok-${{ runner.os }}-

      - name: Libraries
        run: otok install --locked
```

## Other systems

The same pattern works anywhere: the cache is one directory (`OTOK_CACHE_DIR` moves it), and nothing in it depends on
the path of the project. Inputs can be kept on your own servers too, see [Where inputs come from](/guides/fetch/).

When a build fails, otok prints the end of its log and keeps the whole log in the cache's `failed/` directory; with
`--keep-build-dirs` it keeps the work directory too. Upload `failed/` as an artifact of a failed job.
