---
title: config.toml
description: The settings of a machine.
sidebar:
  order: 3
---

Settings that belong to the machine, not to a project. None of them changes what is built: they choose where things
are, which installed toolchain is used, and where inputs are fetched from. The complete description is the
[specification](https://github.com/otok-dev/otok/blob/main/docs/formats/config.md).

| System | File |
|---|---|
| macOS, Linux | `~/.config/otok/config.toml` (`$XDG_CONFIG_HOME/otok/config.toml`) |
| Windows | `%APPDATA%\otok\config.toml` |

The file is optional: without it every key has its default, which is enough on most machines. `OTOK_CONFIG` names
another file. Each key also has an environment variable, which wins over the file; a command-line flag wins over both.

## Examples

A Windows machine whose git is not on the `PATH`, with the NDK and LLVM in places of their own and the cache on another
drive:

```toml
# %APPDATA%\otok\config.toml
git = "C:/Program Files/Git/cmd/git.exe"
android-ndk = "D:/Android/ndk/30.0.14904198"
llvm = "C:/Program Files/LLVM"
visual-studio = "2026"
cache-dir = "D:/otok-cache"
```

A Mac that builds with a beta Xcode and keeps fewer cores for otok:

```toml
# ~/.config/otok/config.toml
xcode = "/Applications/Xcode-beta.app"
jobs = 8
```

A machine of a company network, fetching only from the company's mirror:

```toml
asset-mirror = ["https://artifacts.example.com/otok/{sha256}"]
mirrors-only = true

[[url-rewrite]]
from = "https://github.com/"
to = "https://git.example.com/github/"
```

Write paths with `/`, or as TOML literal strings in single quotes (`'C:\Program Files\LLVM'`): in double quotes a `\`
starts an escape.

## Keys

| Key | Variable | Meaning |
|---|---|---|
| `jobs` | `OTOK_JOBS` | How many compiler processes run at once; all logical CPUs by default. |
| `cache-dir` | `OTOK_CACHE_DIR` | The [cache](/guides/cache/). |
| `cache-max-age` | `OTOK_CACHE_MAX_AGE` | Days after which unused cache entries are removed, `30`; `0` never. |
| `index` | `OTOK_INDEX` | The recipe index, `view+https://otok-dev.github.io/index` by default; `""` for none. |
| `index-mirror` | `OTOK_INDEX_MIRROR` | Read the index from a copy. |
| `asset-mirror`, `url-rewrite`, `mirrors-only` | | [Where inputs come from](/guides/fetch/). |
| `proxy` | `OTOK_PROXY` | An HTTP(S) proxy, by default from `HTTPS_PROXY` and `HTTP_PROXY`. |
| `xcode` | `OTOK_XCODE` | The Xcode that builds for Apple platforms; `DEVELOPER_DIR` and `xcode-select` otherwise. |
| `visual-studio` | `OTOK_VISUAL_STUDIO` | The Visual Studio that builds for Windows: `"2026"`, `"18"` or a path; the newest by default. |
| `android-ndk` | `OTOK_ANDROID_NDK` | The NDK; by default `ANDROID_NDK_HOME`, or the newest of the Android SDK. |
| `llvm` | `OTOK_LLVM` | The LLVM whose clang-cl builds in `windows/clang-cl` and `linux/clang-cl`. |
| `windows-sdk` | `OTOK_WINDOWS_SDK` | For `linux/clang-cl`: the CRT and Windows SDK laid out by `xwin splat`. |
| `git` | `OTOK_GIT` | The git program, when it is not on the `PATH`. |
| `sandbox` | `OTOK_SANDBOX` | `false` to build without the sandbox (as `--no-sandbox`): on a machine that has none, or for a build it stops; every build warns. |
| `virtual-paths` | `OTOK_VIRTUAL_PATHS` | Windows: builds see the cache and their work directories through short drive letters, since Windows' build tools fail on paths over 260 characters; `false` (as `--no-virtual-paths`) gives them the real paths. |
| `keep-build-dirs` | `OTOK_KEEP_BUILD_DIRS` | Keep the work directories of failed builds, not only their logs. |
| `color` | `OTOK_COLOR` | `"auto"`, `"always"` or `"never"`. |

An unknown key is a warning, not an error, so one machine can run several versions of otok.
