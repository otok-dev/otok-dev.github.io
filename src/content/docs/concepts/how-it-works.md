---
title: How otok works
description: From otok.toml to the libraries in your build, step by step.
sidebar:
  order: 1
---

`otok install` goes through the same steps every time.

## 1. Resolve

otok reads `otok.toml` and the lock, and looks the recipes up in the [index](https://otok-dev.github.io/index/) (or in
git and directories, for recipes named so). It chooses a version of every library, the ones they depend on included,
that satisfies every constraint, every option request, every platform and license policy, and keeps the versions the
lock already has. Tools the recipes build with (CMake, Ninja, Python, …) are resolved the same way, separately: a tool
runs on your machine and never reaches your app. A tool your own build runs, such as `protoc`, is resolved so too when
`otok.toml` delivers it ([Tools for your own build](/guides/tools/)).

Resolution happens before anything is downloaded: an unknown option, a platform a recipe does not support or two
libraries asking for different options of a third is an error at once, naming who asked for what.

The result is written to `otok.lock`.

## 2. Fetch

Every input the lock names is fetched into the cache and checked: the recipes by the hash of their files, sources and
resources by their sha256 or git commit. Nothing is built from an input that does not match.

## 3. Build

Each library is built in *slices*, one per platform, architecture and configuration, in an order where every library
comes after those it depends on, and as many at once as the machine's processors allow. Each slice:

- gets a fresh copy of the source, with the recipe's patches applied, and an empty directory to install into;
- runs the recipe's `build` function with a toolchain otok set up for the slice: the compilers and SDK of your
  Xcode, Visual Studio, NDK or Linux, the flags of the platform, architecture, deployment version and configuration,
  and your project's flags;
- runs in a sandbox, without network access, that lets it write only into its own directories;
- is checked: every library must be built for the slice's platform and architecture, and must not refer to otok's
  directories.

A slice is stored in the cache under a *key*: the hash of everything that made it, the recipe, the source, the
options, the flags, the toolchain's identity and the keys of its dependencies. A slice whose key is in the cache is not
built again, by this project or any other.

## 4. Package

The slices of a library are combined into what its target delivers:

- **Apple:** one XCFramework per library, the slices of each platform merged with `lipo`; checks of the privacy
  manifests, the APIs that need a declared reason, symbols of Apple's private libraries and symbols two libraries both
  define.
- **Android:** `include/` and `lib/<abi>/`, the shared objects named as Gradle packs them.
- **Windows:** `include/`, `lib/<arch>/`, `bin/<arch>/` for DLLs, `debug/` for debug builds.
- **Linux:** `include/`, `lib/`, shared objects that find each other through `$ORIGIN`.

## 5. Output

The packages are copied into the output directory, `Otok/` by default, with what your build reads: for Apple a
`Package.swift` with a product per recipe product and an `otok-config.cmake`. A package that did not change is not
copied again, so your build sees the same files. `Acknowledgements.md` lists every library with its license texts.
The tools the project delivers go to `Otok/tools/`, with `otok-tools.cmake`, `otok-tools.props` and `otok-tools.toml`
naming their programs for your build.

otok owns the output directory: it removes what the project no longer has, and writes only into a directory that is
empty or was made by otok.
