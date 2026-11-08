---
title: Several targets in one project
description: Build the same libraries for Apple platforms, Android, Windows and Linux from one otok.toml.
sidebar:
  order: 3
---

A project builds for the targets whose tables its `otok.toml` has: `[apple]`, `[android]`, `[windows]`, `[linux]`.
An app with an iOS version and an Android version keeps one list of libraries:

```toml
[otok]
format = 1

[apple]
platforms = ["ios", "iossim"]
deployment = { ios = "16.0" }
output = "ios/Otok"

[android]
architectures = { android = ["arm64-v8a", "x86_64"] }
deployment = { android = "24" }
output = "android/Otok"

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

- Each target has its own output directory (`output`, `Otok` by default); two targets must not share one.
- A library has one version in all targets. The recipe of each target is a variant of the same recipe: the index keeps
  them side by side, and `otok info` lists them.
- A library listed once is built for every target. `platforms` in its `[deps]` table narrows it to some platforms of
  some targets.

## Where each target is built

A machine builds the targets it can:

| Target | Built on |
|---|---|
| `apple` | a Mac with Xcode (`macos/xcode`) |
| `android` | a Mac, Linux or Windows with the NDK (`*/ndk`) |
| `windows` | Windows with Visual Studio (`windows/msvc`, `windows/clang-cl`), or Linux with clang-cl and the Windows SDK (`linux/clang-cl`) |
| `linux` | Linux with GCC (`linux/gcc`) or Clang (`linux/clang`) |

`otok install` on a Mac builds the Apple and Android targets; on Windows the Windows and Android ones. A target the
machine cannot build is skipped with a note.

These pairs of system and compiler are *build environments*. `[windows]` and `[linux]` must say which they are built
in, because the libraries differ by compiler; `[apple]` and `[android]` have defaults:

```toml
[windows]
build-on = ["windows/msvc"]

[linux]
build-on = ["linux/gcc"]
```

With several environments in `build-on`, a machine uses the first it has. When a library's recipe does not build in
the project's environment but in another one with the same ABI, it is built there and linked with the rest: Skia, which
builds only with clang-cl, is built in `windows/clang-cl` for a project built in `windows/msvc`.

## The lock across machines

`otok.lock` holds the libraries and tools of the systems the project has been built on. The first `otok install` on a
Windows machine adds the tools of Windows to a lock made on a Mac; commit that change, and CI on Windows can then run
`otok install --locked`.
