---
title: Why otok
description: Each native library built from source for your app, on every platform you ship, configured as you ask, from one file.
---

The native libraries an app depends on, OpenSSL, ICU, Boost, FFmpeg and the like, usually reach it in one of two ways:
as binaries someone else built (a pod, an AAR, a NuGet package, the system's package), or through build scripts of
your own, one set per platform. otok changes who builds a library, and for whom: not a package's author, once, with the
choices that author made, but otok on your machine, for your app, with yours, for Apple platforms, Android, Windows
and Linux alike. Libraries come from recipes, published in a public [index](https://otok-dev.github.io/index/) or kept
in a repository of your own.

## Your build of every library

A binary package of a library with a build system of its own fixes what its author chose: the platforms, the minimum
OS versions, the options, static or dynamic. What the author did not foresee, you cannot have; variants are the few the
author chose to prepare.

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

- **Platforms, architectures and minimum versions:** exactly the ones you ship: Apple's platforms and their
  simulators at your deployment versions, the Android ABIs and API level of your app, Windows on x64 and ARM64.
- **Static or dynamic,** for every library on its own, where its recipe offers both.
- **The C++ standard** of your code, so every library is compiled with the same `__cplusplus` as the code that calls
  it.
- **Compiler flags,** for one library or all: a macro of a library's own configuration, frame pointers for profiling,
  address sanitizer in a profile (`otok install --profile asan`).
- **Your compilers.** Libraries are built by the toolchain that builds your app: your Xcode and its SDKs, your
  Android NDK, your Visual Studio (MSVC or clang-cl), GCC or Clang on Linux.

Before anything is built, otok checks your choices against what each recipe declares, and against what every other
library asks for: an unknown option, a platform a recipe cannot build or two libraries wanting different options of a
third are errors naming who asked for what, not a link failure an hour later.

## One file says everything

Everything that changes what is built is in `otok.toml`, in one place: the libraries and their versions, options,
linkage, targets, platforms, minimum versions, flags, standards, and the variants of all of it in profiles. Nothing
else does.

Other tools spread it over levels. With vcpkg, which libraries and features are in `vcpkg.json`; the registries and
the baseline in `vcpkg-configuration.json`; static or dynamic, the runtime, the flags and the platform in triplet
files, chosen by a CMake variable or an environment variable; changed recipes in overlay directories. To know what a
project builds, you read all of them, and the machine's environment too.

otok has machine settings as well (`config.toml`: where the cache is, which Xcode or NDK, a mirror), under one rule:
**they never change what is built.** The same `otok.toml` and `otok.lock` give the same libraries on your machine,
your colleague's and CI.

## One list for every platform

An app with an iOS version, an Android version and a desktop one keeps one list of its native libraries, at the same
versions everywhere:

```toml
[apple]
platforms = ["ios", "iossim", "macosx"]
deployment = { ios = "17.0", macos = "14.0" }
output = "apple/Otok"

[android]
architectures = { android = ["arm64-v8a", "x86_64"] }
deployment = { android = "24" }
output = "android/Otok"

[windows]
build-on = ["windows/msvc"]
output = "windows/Otok"

[linux]
build-on = ["linux/gcc"]
output = "linux/Otok"
```

Each machine builds the targets it can, a Mac the Apple and Android ones, a Windows machine the Windows and Android
ones, and says why it skips the others. The lock is shared: a library updated once is updated for every platform. See
[Several targets in one project](/guides/targets/).

## Native to each build

otok writes one directory per target, in the form that target's build expects, and never touches your project files:

- **Apple:** XCFrameworks in a Swift package you add to Xcode once, or depend on from your own `Package.swift`.
- **Android:** the libraries of every ABI for the CMake of your Gradle build; the shared objects your native library
  links are packed into the APK by Gradle itself.
- **Windows:** `otok.props` and `otok.targets` for Visual Studio projects, with the DLLs copied beside your program.
- **Every target:** `otok-config.cmake` with `otok::` targets, which checks at configure time what would otherwise
  fail at link time: an architecture that was not built, or a compiler or NDK older than the one that built the
  libraries.

A CMake project that already finds a library as `find_package(ZLIB)` keeps doing so: otok answers it with its own
build ([CMake projects](/guides/cmake/)). Every output also lists the licenses of everything built, for your about
screen or notice file.

## Every input pinned

`otok.lock` records every library's version, the recipe by the hash of its files, the source by its hash or commit,
and the same for the tools that build it, CMake and Ninja included: they come from recipes too, not from whatever is
installed. The same goes for the programs your own build runs, such as `protoc`: otok builds them for each machine
from recipes and puts them beside the libraries ([Tools for your own build](/guides/tools/)). Another machine
running `otok install --locked` builds exactly that, or stops and says what differs.

## Recipes you can read

A recipe is a few text files: where the source is, which platforms, how to build. No binaries can hide in one. Every
recipe of the index is shown on its [catalog](https://otok-dev.github.io/index/) page with the differences between its
versions. You know what you link, and you can check it.

## Fix what upstream no longer fixes

Many libraries apps depend on are no longer maintained, and some need a change that their authors never made. A
recipe carries patches: they are applied to the pinned source before every build, are part of the recipe's hash, and
are shown with it on the catalog. No fork to keep, and every project using the recipe gets the fix.

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
by people you do not know. Package managers usually run them with all the access your account has: a pod's
`prepare_command` and script phases, a vcpkg port, a Conan recipe.

otok runs every build in a sandbox, on macOS, Linux and Windows:

- **no network:** everything a build needs is downloaded before it starts and checked against its hash, so a build
  cannot fetch anything else, or send anything away;
- **no access to your files:** a build cannot read your home directory, only its own source, the recipe and the
  builds it depends on, and it writes only into its own directories.

A build that tries anything else fails. The sandbox needs no administrator rights: Seatbelt on macOS, bubblewrap on
Linux, an AppContainer on Windows. Where it cannot be made (Linux without `bwrap`), otok does not build unisolated on its
own: it stops and says so, and `--no-sandbox` builds without it when you ask. [The build sandbox](/concepts/sandbox/)
explains how it works, and why on Windows otok puts a DLL of its own into the processes of a build.

## otok and other tools

otok is young; the tools below are not, and for some projects each of them is the better choice. Here is where they
differ, as fairly as we can put it. If something here is wrong or out of date, please say so in an
[issue](https://github.com/otok-dev/otok/issues).

**vcpkg.** Microsoft's package manager for C and C++ builds libraries from source too, and its catalog is far larger:
thousands of ports, where otok's [index](https://otok-dev.github.io/index/) has some seventy libraries. It is mature,
integrates with CMake and MSBuild, and its binary caching serves teams and CI. otok differs in where a build is
described and in what it delivers. Everything that changes a build is in `otok.toml`, where vcpkg spreads it over its
manifest, its configuration, triplets and overlays ([above](#one-file-says-everything)). For Apple platforms otok
delivers XCFrameworks in a Swift package with privacy manifests and App Store checks, where vcpkg's community triplets
give static libraries per platform, to be assembled by you. And otok runs every build in a sandbox, where a vcpkg port
runs with the access of your account.

**Conan.** Conan's recipes are Python programs; ConanCenter has well over a thousand of them, with prebuilt binaries
for common configurations and source builds for the rest. Profiles hold the settings, lockfiles pin the graph,
generators serve CMake, MSBuild and Xcode, and teams keep their binaries in a server of their own. It is very
flexible, and widely used in companies. otok's recipes are declarative files with a short build
script in a restricted Lua, and its builds run in a sandbox, where a Conan recipe runs with the access of your
account; for Apple platforms otok delivers XCFrameworks in a Swift package. otok has no public binaries: every library
is built on your machines once, and then comes from the cache, which a team can [share](/guides/cache/).

**CocoaPods.** CocoaPods serves Apple platforms only. Many pods of native libraries ship binaries their authors built
once, with the platforms, versions and options they chose. CocoaPods is in
[maintenance mode](https://blog.cocoapods.org/CocoaPods-Support-Plans), and its trunk accepts no new pods or versions
from [December 2026](https://blog.cocoapods.org/CocoaPods-Specs-Repo/); the pods published before keep installing.
[Coming from CocoaPods](/start/from-cocoapods/) shows what a Podfile becomes.

**Swift Package Manager.** SwiftPM is built into Xcode and is the right tool for Swift packages; otok's output for
Apple platforms is itself a Swift package. But SwiftPM compiles C and C++ only with its own build, not with a library's
CMake, Meson or autotools, so libraries such as OpenSSL or FFmpeg come to it as binary XCFrameworks someone else
built. otok builds them for you and hands them to SwiftPM. SwiftPM has no part in the Gradle build of an Android app,
where otok serves the same libraries.

**Build scripts of your own.** Many teams build their native libraries with scripts of their own, one per platform.
They work and they are yours, but each new platform, library or Xcode version is more of them to keep, and nothing
checks that two machines build the same thing. otok's recipes are shared, and its lock makes every machine build the
same libraries.

What otok does not have yet: the size of their catalogs, their years of use, and prebuilt binaries for download. Its
formats may still change before 1.0.

## For Apple apps

### Ready for the App Store

- Every library is an XCFramework with the slices of every platform you ship, simulators on Apple silicon included.
- Privacy manifests come with the libraries, and otok checks every library for the APIs that need a declared reason.
- Symbols that would clash with Apple's private libraries, the cause of the rejection ITMS-90338, are found before you
  submit, and so are symbols two libraries both define.
- `Acknowledgements.plist` is a Settings.bundle page of all the licenses; `[policy]` keeps licenses you cannot accept
  out of your app.

### Nothing touches your Xcode project

otok writes one directory, a Swift package you add to your project once. No generated workspace, no build phases, no
project rewritten on every install.

### Swift packages that need a fix

Patches work for Swift packages too. [Updates](https://github.com/rwbutler/Updates), which prompts users to install a
newer version of an app, is unmaintained: it asks the App Store over `http://`, which App Transport Security blocks,
and its Swift package left out the user interface its pod had. The recipe `apotocki/updates` fixes both with two
patches and delivers the patched Swift package in `Otok/`, built by Xcode with your app as any Swift package is:

```toml
[deps.updates]
recipe = "apotocki/updates"
version = "~> 2.0"
```

A Swift package that is maintained needs none of this: depend on it with SwiftPM directly.

Coming from CocoaPods? See [what a Podfile becomes](/start/from-cocoapods/).

## And when a library is missing

A recipe is a `recipe.toml` and a short `build.lua` that runs the library's own CMake, Meson or autotools build. Use it
from a directory of your project at once; [publish it](/recipes/publish/) when it is ready.
