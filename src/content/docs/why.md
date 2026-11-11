---
title: Why otok
description: More than a new place to publish libraries — each one built for your app, configured as you ask, from one file.
---

Like trunk for pods, otok has a public [index](https://otok-dev.github.io/index/) where libraries are published, as
recipes rather than pods. But it is more than a new place to publish them: it changes who builds a library, and for
whom. Not a pod's author, once, with the choices that author made, but otok on your machine, for your app, with yours.

## Your build of every library

A pod of a library with a build system of its own (OpenSSL, Boost, ICU, FFmpeg) usually ships binaries its author
built once: the platforms, the deployment version, the options, static or dynamic, all fixed. What the author did not
foresee, you cannot have; subspecs are the few variants the author chose to prepare.

otok builds each library from its source, with the options *you* ask for:

```toml
[deps.icu4c]
recipe = "apotocki/icu4c"
version = "~> 79.1"
# ICU's data with only the locales and services your app uses, in a file instead of the binary
options = { data = "file", data-filter = "icu-filter.json" }

[deps.boost]
recipe = "apotocki/boost"
version = "~> 1.92"
# only the compiled libraries you use, with ICU as Boost.Locale's backend
options = { libraries = ["json", "locale"], icu = true }

[deps.openssl]
recipe = "apotocki/openssl"
version = "~> 4.1"
options = { no-deprecated = true }
```

ICU's data alone is around 30 MB; built from its sources with your filter, it holds what your app needs. And what you
choose is not limited to options:

- **Platforms and deployment versions:** exactly the ones you ship, visionOS, watchOS and Mac Catalyst included,
  each with its simulator, at your minimum OS versions, not the pod author's.
- **Static or dynamic,** for every library on its own, where its recipe offers both: a framework embedded in the app, or linked in.
- **The C++ standard** of your code, so every library is compiled with the same `__cplusplus` as the code that calls
  it.
- **Compiler flags,** for one library or all: a macro of a library's own configuration, frame pointers for profiling,
  address sanitizer in a profile (`otok install --profile asan`).
- **Your Xcode.** Libraries are built by the Xcode that builds your app, with its SDKs.

Before anything is built, otok checks your choices against what each recipe declares, and against what every other
library asks for: an unknown option, a platform a recipe cannot build or two libraries wanting different options of a
third are errors naming who asked for what, not a link failure an hour later.

## One file says everything

Everything that changes what is built is in `otok.toml`, in one place: the libraries and their versions, options,
linkage, platforms, deployment versions, flags, standards, and the variants of all of it in profiles. Nothing else
does.

Other tools spread it over levels. With vcpkg, which libraries and features are in `vcpkg.json`; the registries and
the baseline in `vcpkg-configuration.json`; static or dynamic, the runtime, the flags and the platform in triplet
files, chosen by a CMake variable or an environment variable; changed recipes in overlay directories. To know what a
project builds, you read all of them, and the machine's environment too.

otok has machine settings as well (`config.toml`: where the cache is, which Xcode, a mirror), under one rule: **they
never change what is built.** The same `otok.toml` and `otok.lock` give the same libraries on your Mac, your
colleague's and CI.

## Every input pinned

`otok.lock` records every library's version, the recipe by the hash of its files, the source by its hash or commit,
and the same for the tools that build it, CMake and Ninja included: they come from recipes too, not from whatever is
installed. Another machine running `otok install --locked` builds exactly that, or stops and says what differs.

## Recipes you can read

A recipe is a few text files: where the source is, which platforms, how to build. No binaries can hide in one. Every
recipe of the index is shown on its [catalog](https://otok-dev.github.io/index/) page with the differences between its
versions. You know what you link, and you can check it.

## Fix what upstream no longer fixes

Many libraries apps depend on are no longer maintained, and some need a change that their authors never made. A
recipe carries patches: they are applied to the pinned source before every build, are part of the recipe's hash, and
are shown with it on the catalog. No fork to keep, and every project using the recipe gets the fix.

This works for Swift packages too. [Updates](https://github.com/rwbutler/Updates), which prompts users to install a
newer version of an app, is unmaintained: it asks the App Store over `http://`, which App Transport Security blocks,
and its Swift package left out the user interface its pod had. The recipe `apotocki/updates` fixes both with two
patches and delivers the patched Swift package in `Otok/`, built by Xcode with your app as any Swift package is:

```toml
[deps.updates]
recipe = "apotocki/updates"
version = "~> 2.0"
```

A Swift package that is maintained needs none of this: depend on it with SwiftPM directly.

## Your own libraries, the same way

The native code of your team, a shared engine or a codec of your own, is a dependency like any other. Its recipe lives
in a repository of yours, private if you like, and its source is fetched over ssh with your keys:

```toml
[deps.engine]
recipe = { git = "git@git.example.com:team/recipes.git", rev = "<commit>", path = "engine" }
```

It is built for every platform of the app, with the same options, flags and standards as the rest, and pinned in the
lock: every developer and CI builds the same commit. Nothing is published.

While you work on it, `otok.dev.toml` (kept out of git) points otok at your working trees:

```toml
[deps.engine]
source = "../engine"
recipe = "../recipes/engine"
```

`otok install` then builds the library from the working tree as it is, uncommitted changes included, and incrementally:
it keeps the build directory, copies only the files you changed, and the library's own build recompiles only those.
The libraries that depend on it are rebuilt when its result changes. The lock does not change, and without the file,
or with `--no-dev`, the project builds exactly what the lock says. See [Working on a library](/guides/dev-builds/).

## Builds that cannot reach your files

Building a library runs its build scripts on your machine: configure scripts, CMake files, code generators, written
by people you do not know. With CocoaPods a pod's `prepare_command` runs on `pod install`, and its script phases in
every Xcode build, with all the access your account has.

otok runs every build in a sandbox, on macOS, Linux and Windows:

- **no network:** everything a build needs is downloaded before it starts and checked against its hash, so a build
  cannot fetch anything else, or send anything away;
- **no access to your files:** a build cannot read your home directory, only its own source, the recipe and the
  builds it depends on, and it writes only into its own directories.

A build that tries anything else fails. The sandbox needs no administrator rights: Seatbelt on macOS, bubblewrap on
Linux, an AppContainer on Windows. Where it cannot be made (Linux without `bwrap`), otok does not build unisolated on its
own: it stops and says so, and `--no-sandbox` builds without it when you ask. [The build sandbox](/concepts/sandbox/)
explains how it works, and why on Windows otok puts a DLL of its own into the processes of a build.

## Ready for the App Store

- Every library is an XCFramework with the slices of every platform you ship, simulators on Apple silicon included.
- Privacy manifests come with the libraries, and otok checks every library for the APIs that need a declared reason.
- Symbols that would clash with Apple's private libraries, the cause of the rejection ITMS-90338, are found before you
  submit, and so are symbols two libraries both define.
- `Acknowledgements.plist` is a Settings.bundle page of all the licenses; `[policy]` keeps licenses you cannot accept
  out of your app.

## Nothing touches your Xcode project

otok writes one directory, `Otok/`, a Swift package you add to your project once. No generated workspace, no build
phases, no project rewritten on every install. The same directory has an `otok-config.cmake` for CMake.

## Beyond Apple

The same `otok.toml` builds the same libraries, at the same versions, for Android with the NDK, for Windows with
Visual Studio and for Linux. An app with an iOS and an Android version keeps one list of its native libraries.

## And when a library is missing

A recipe is a `recipe.toml` and a short `build.lua` that runs the library's own CMake, Meson or autotools build. Use it
from a directory of your project at once; [publish it](/recipes/publish/) when it is ready.

---

Coming from CocoaPods? See [what a Podfile becomes](/start/from-cocoapods/).
