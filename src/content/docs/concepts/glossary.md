---
title: Glossary
description: The words otok uses, what each means, with examples.
sidebar:
  order: 4
---

## Where libraries go

### Target

A kind of delivery: one output, one way of packaging, one way to reach your build. A project builds for the targets
whose tables its `otok.toml` has.

| Target | Table | Delivers |
|---|---|---|
| `apple` | `[apple]` | XCFrameworks in a local Swift package, and `otok-config.cmake` |
| `android` | `[android]` | headers and libraries per ABI, for Gradle's native build |
| `windows` | `[windows]` | headers, libraries and DLLs per architecture and configuration, for MSVC |
| `linux` | `[linux]` | headers and libraries for programs of the machine's Linux |

### Platform

What a binary runs on, inside a target. `apple` has ten: `ios`, `iossim` (the iOS Simulator), `macosx`, `catalyst`
(Mac Catalyst), `tvos`, `tvossim`, `watchos`, `watchossim`, `xros` (visionOS) and `xrossim`. Each of the other targets
has one platform of its own name: `android`, `windows`, `linux`. Simulators are platforms of their own: a library for
the iPhone is not a library for its simulator.

### Architecture

The processor a binary is built for, per platform: `arm64` and `x86_64` for macOS and the simulators, `arm64` for
iPhone, `arm64_32` and `arm64` for Apple Watch, the ABIs `arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86` for Android,
`x86_64` and `arm64` for Windows and Linux. `architectures` in a target table builds fewer than all.

### Slice

One build of a library: a platform and an architecture, written `<platform>-<arch>`, and a configuration.
`iossim-arm64`, `watchos-arm64_32`, `android-arm64-v8a`, `windows-x86_64` (debug). otok calls a recipe's `build`
function once per slice, each with a fresh copy of the source, and keeps each slice in the cache.

### Deployment version

The oldest system version a platform's binaries run on: `deployment = { ios = "16.0", macos = "13.0" }`, or the API
level for Android, `{ android = "24" }`. Required for every platform built: otok does not take Xcode's default, which
changes with Xcode.

### Configuration

`release` or `debug`: optimized, or built for debugging. On Windows a debug program needs libraries built against the
debug CRT, so a project builds both (`configurations = ["debug", "release"]`); Apple takes one.

### Linkage

`static` (an archive linked into your binary) or `dynamic` (a shared library, a DLL, or on Apple platforms a framework
embedded in your app). Per target or per library, where the recipe offers it.

### Output

The directory a target writes for your build, `Otok/` unless `output` says otherwise. otok owns it: it is rewritten by
every install, so it is not committed.

## Where libraries are built

### Build environment

Where and with what a slice is built: the system of the build machine and the compiler, written `<host>/<compiler>`.

| Environment | Builds | With |
|---|---|---|
| `macos/xcode` | `apple` | Xcode's clang and SDKs |
| `macos/ndk`, `linux/ndk`, `windows/ndk`, all of them `*/ndk` | `android` | the Android NDK |
| `windows/msvc` | `windows` | Visual Studio's `cl.exe` |
| `windows/clang-cl` | `windows` | clang-cl with Visual Studio's runtime and SDK |
| `linux/clang-cl` | `windows` | clang-cl with the runtime and SDK of `xwin`, across from Linux |
| `linux/gcc`, `linux/clang` | `linux` | GCC or Clang |

A project says in which environments it is built (`build-on`); a recipe says in which it builds. A machine builds a
target in the first environment of `build-on` it has.

### Substitute environment

Another compiler of the same system that builds libraries of the same ABI, so that they link together:
`windows/clang-cl` for `windows/msvc`, `linux/clang` for `linux/gcc`. A library whose recipe does not build in the
project's environment is built in a substitute: Skia, which builds only with clang-cl, in a project built with MSVC.

### System

The operating system of a build machine: `macos`, `linux`, `windows`. The lock records the systems a project has been
built on (`systems`), and holds the tools of each.

### Sandbox

The isolation every build runs in (Seatbelt on macOS, bubblewrap on Linux, an AppContainer on Windows): no network, no
access to your files, writes only into the build's own directories.

## What is built

### Library

What a project depends on, by its name: `lz4`, `openssl`, `boost`. The name of a `[deps.<library>]` table. One library
may produce several binaries (OpenSSL's `ssl` and `crypto`).

### Product

What consumers of a library use, declared by its recipe: a set of its binaries, with their headers, defines, system
libraries and, on Apple platforms, a module and a privacy manifest. `LZ4`; `OpenSSL`; Boost's `Boost` (the headers)
and `BoostJson`, `BoostFilesystem`, … In Xcode you add products; in CMake you link `otok::<product>`.

### Option

A choice a recipe offers, of a type it declares: a boolean (`no-deprecated`), a number, a string, one of some values
(`data = "file"`), a list (`libraries = ["json"]`) or a file of your project (`data-filter`). Set in `options` of a
`[deps]` table; the recipe's default otherwise.

### Profile

A named set of changes to the build, chosen with `--profile <name>`: other platforms, flags, configurations, options.
`[profile.ci]`, `[profile.asan]`.

### Tool

A program a recipe builds with, running on the build machine: CMake, Ninja, Python, Meson, Perl, make. Tools are built
or downloaded by recipes of their own and pinned in the lock like libraries; they never reach your app. A **tool
dependency** is a library or program a recipe needs on the build machine; `[tool-deps]` of `otok.toml` chooses their
versions. A tool your own build runs is **delivered** (`deliver = true`): copied into `Otok/tools/`, still not
into your app ([`[tool-deps]`](/reference/otok-toml/#tool-depslibrary)).

## Recipes and the index

### Recipe

The description of how to build one library for one target: `recipe.toml` (what) and `build.lua` (how), with
patches and other text files. Named in a project by its **id**, `<publisher>/<name>`: `apotocki/lz4`.

### Variant

One of the recipes of one id, each for its own target and environments: `apotocki/boost` has the variants `apple`,
`android`, `linux`, `windows-msvc` and `windows-clang-cl`. You name the id; otok takes the variant of the target and
environment it builds for.

### Version and revision

The **version** is the library's (`1.92.0`); the **revision** is the recipe's own, raised whenever the recipe changes
for the same version. `1.92.0 (r2)` is the second recipe of Boost 1.92.0.

### Publisher

The name recipes are published under, held by a GitHub account or organization: `apotocki`.

### Index

The registry of published recipes: [otok-dev/index](https://github.com/otok-dev/index), read through its HTTPS view
`https://otok-dev.github.io/index`, with the [catalog](https://otok-dev.github.io/index/) for people. It holds no
recipes, only entries naming where they are.

### Entry

A published version of a recipe variant in the index: its description, options and dependencies, and where its files
are (a git repository, a commit, a directory) with their hash. Never changed after it is merged.

### Advisory

A note in the index on a published version: `withdrawn`, `broken` or `security`. otok avoids such versions when it
chooses, and `otok audit` reports them in a lock.

## Lock and cache

### Lock

`otok.lock`: what the resolution chose, with every input pinned by its hash or commit. Written by otok, committed with
the project.

### Resolution

Choosing a version and a recipe of every library and tool, so that every constraint, option and platform holds. Done
by `otok install` for what the lock does not answer, and by `otok update`.

### Cache

The directory where otok keeps downloads, sources and builds, shared by every project of the machine. Any part of it can
be deleted.

### Slice key

The hash of everything that made a slice: recipe, source, options, flags, toolchain, the keys of its dependencies. A
slice is found in the cache by its key, so the same inputs are never built twice.

### Dev build

A library built from a working tree named in `otok.dev.toml`, incrementally, without changing the lock.
