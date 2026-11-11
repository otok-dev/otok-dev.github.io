---
title: Coming from CocoaPods
description: What a Podfile becomes in otok, and what works differently.
sidebar:
  order: 6
---

CocoaPods' central repository of podspecs, trunk, becomes read-only on December 2, 2026
([announcement](https://blog.cocoapods.org/CocoaPods-Specs-Repo/)). Existing builds keep working, but libraries
published through trunk get no more updates. For Swift and Objective-C libraries the way forward is Swift Package
Manager, which Xcode has built in. For native libraries, those written in C and C++ such as OpenSSL, Boost, ICU or
LZ4, the pods often shipped prebuilt binaries, and SwiftPM has no build system for them. That is the part otok
replaces, and it does more than give those libraries a new home: it builds each of them for your app, configured as
you ask, from one file ([Why otok](/why/)).

## The same ideas, other names

| CocoaPods | otok |
|---|---|
| `Podfile` | `otok.toml` |
| `Podfile.lock` | `otok.lock` |
| `pod install` | `otok install` |
| `pod update [POD]` | `otok update [LIBRARY]` |
| `pod outdated` | `otok outdated` |
| `pod search` | `otok search`, `otok info`, or the [catalog](https://otok-dev.github.io/index/) |
| podspec | recipe (`recipe.toml` with a `build.lua`) |
| trunk, the specs repository | the [public index](https://otok-dev.github.io/index/) |
| `Pods/` and the generated workspace | `Otok/`, a local Swift package |
| `platform :ios, '15.0'` | `[apple] platforms` and `deployment` |
| subspecs | products of a recipe, and its options |
| `use_frameworks!` | `linkage = "dynamic"`, where the recipe offers it |
| `:path =>` | `recipe = { path = "…" }`, or `source = { path = "…" }` to build a recipe from your checkout |
| `:git =>`, `:commit =>` | `recipe = { git = "…", rev = "<full commit>" }` |
| `post_install` hooks | none: `otok.toml` is data, and nothing in it runs |

Version constraints are written as CocoaPods writes them: `~> 3.5` is `>= 3.5, < 4`, `~> 1.1.1` is
`>= 1.1.1, < 1.2`. A bare version is an exact one. Several comparisons are separated by commas: `">= 3.0, < 3.6"`.

## A Podfile, translated

```ruby
platform :ios, '15.0'

target 'App' do
  pod 'OpenSSL-Universal', '~> 3.3'
  pod 'boost', '~> 1.84'
end

target 'AppTests' do
  inherit! :search_paths
end
```

```toml
[otok]
format = 1

[apple]
platforms = ["ios", "iossim"]
deployment = { ios = "15.0" }

[deps.openssl]
recipe = "apotocki/openssl"
version = "~> 4.1"

[deps.boost]
recipe = "apotocki/boost"
version = "~> 1.92"
options = { libraries = ["json", "program_options"] }
```

- **Platforms are explicit.** A Podfile names one platform per target, and the pods bring whatever slices their
  authors built. otok builds each library for every platform in `platforms`, simulators included, and the iOS
  simulator is a platform of its own (`iossim`). Add `macosx`, `catalyst`, `tvos`, `watchos` or `xros` and their
  simulators as you ship them, with a `deployment` version for each.
- **Options replace subspecs.** Boost's compiled libraries are chosen by its `libraries` option, and each becomes a
  product (`BoostJson`, `BoostProgramOptions`) beside the headers (`Boost`). `otok info apotocki/boost` lists a
  recipe's options; an option that does not exist, or a value of the wrong type, is an error before anything is built.
- **Targets of your app are Xcode's business.** `otok.toml` describes the libraries; the generated package has one
  product per library product, and each target of your app adds the products it uses in Xcode (*Frameworks,
  Libraries, and Embedded Content*). Narrow a library to some platforms with `platforms` in its `[deps]` table.

Then:

```sh
otok install
```

and add `Otok/` to your app as a local package: **File → Add Package Dependencies… → Add Local…**. See
[First project for Apple platforms](/start/apple/) for the whole walk-through.

## What works differently

**Nothing touches your Xcode project.** CocoaPods generates a workspace, an aggregate target and build phases, and
rewrites them on every `pod install`. otok writes only `Otok/`: a Swift package that Xcode reads like any other.
Removing otok means removing that package.

**Libraries are built from source, on your machine.** A pod is often a prebuilt binary someone uploaded. An otok
recipe says where the source is (pinned by its hash), how to build it and what comes out; otok builds it with your
Xcode for your platforms and deployment versions, in a sandbox without network access. The first build of a library
takes minutes; after that the build comes from a cache shared by all your projects, and a project with the same
lock gets the same build.

**The lock pins everything.** `otok.lock` records, for every library, the version, the recipe (by its hash), the
source (by its hash or commit) and the tools that build it. `otok install` on another machine, or in CI with
`otok install --locked`, builds exactly that. Commit `otok.toml` and `otok.lock`; ignore `Otok/`.

**What the App Store asks for comes with the library.** Recipes carry the privacy manifests of their libraries, and
otok checks every library for the APIs that need a declared reason and for symbols that would clash with Apple's
private libraries. `Otok/Acknowledgements.plist` is a Settings.bundle page of all the licenses; `Acknowledgements.md`
is the same as text.

**Swift and Objective-C libraries usually need no otok.** If a pod you use is published as a Swift package, depend on
it with SwiftPM directly. If that package is unmaintained or needs a fix, a recipe can patch it and deliver the patched
package in `Otok/`, as [`apotocki/updates`](/why/#fix-what-upstream-no-longer-fixes) does.

## When a library is missing

Search the [catalog](https://otok-dev.github.io/index/) or run `otok search <name>`. If no recipe builds the library
you need, you can write one: a `recipe.toml` that says where the source is and what it produces, and a short
`build.lua` that builds it, usually through the library's own CMake, Meson or autotools build. A recipe can be used
from a local directory or a git repository at once, and published to the index for others. See
[Recipes](/recipes/write/).
