---
title: First project for Apple platforms
description: Build LZ4 for macOS and iOS and use it from Swift through a local Swift package.
sidebar:
  order: 2
---

This page builds [LZ4](https://lz4.org) for macOS, iOS and the iOS simulator and calls it from Swift. You need otok
([installed](/start/install/)) and Xcode.

## Describe the project

In your app's directory (or an empty one), create `otok.toml`:

```toml
[otok]
format = 1

[apple]
platforms = ["macosx", "ios", "iossim"]
deployment = { macos = "14.0", ios = "17.0" }

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

- `[apple]` is the target. `platforms` lists what you ship: `ios`, `iossim`, `macosx`, `catalyst`, `tvos`,
  `tvossim`, `watchos`, `watchossim`, `xros`, `xrossim`. Each is built for all its architectures (`arm64` and
  `x86_64` for the simulators and macOS) unless `architectures` narrows it.
- `deployment` gives the minimum OS versions. They are required: otok does not take Xcode's default, which changes
  with every Xcode.
- `[deps.lz4]` asks for the library `lz4`, built by the recipe `apotocki/lz4` of the
  [public index](https://otok-dev.github.io/index/), at version 1.10 or a later 1.x.

## Install

```sh
otok install
```

```text
otok.lock created:
  added lz4 1.11.0 (r1)
  tool added cmake 4.4.5 (r1)
  tool added ninja 1.13.2 (r1)
  tool added python 3.14.10 (r1)
...
built lz4 1.11.0 for ios-arm64 (3.9 s), 3 of 5 slices
...
packaging lz4 1.11.0 for apple
output 'Otok': 1 copied, 0 unchanged, 0 removed
```

otok chose the newest version the constraint allows, wrote it into `otok.lock`, fetched the sources and built LZ4
for every platform and architecture (a *slice* each) with the CMake and Ninja of their own recipes. The first run
takes a while; the next ones, in this project or any other, take the builds from the cache.

Commit `otok.toml` and `otok.lock`: the lock pins every version, recipe and source by its hash, so another machine
running `otok install` builds the same libraries. `Otok/` is generated: add it to `.gitignore`.

`Otok/` is a Swift package:

```text
Otok/
  Package.swift             the products of all libraries: here LZ4
  Packages/lz4/
    lz4_lz4.xcframework     every platform's slices
    shims/LZ4/              the product's privacy manifest and link settings
  Acknowledgements.md       the licenses of everything built, for your about screen
  Acknowledgements.plist    the same as a Settings.bundle page
  otok-config.cmake         the same products for CMake
```

## Use it in Xcode

1. **File → Add Package Dependencies…**, then **Add Local…**, and choose the `Otok` directory.
2. Add the product **LZ4** to your app target.
3. Import the module:

```swift
import LZ4

print("LZ4 \(String(cString: LZ4_versionString()))")
```

The library's privacy manifest comes with the product; App Store finds it in your app.

## Use it from a Swift package

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hello",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "Otok")],
    targets: [
        .executableTarget(name: "Hello", dependencies: [.product(name: "LZ4", package: "Otok")]),
    ]
)
```

```sh
swift run
```

```text
LZ4 1.11.0
```

## Use it from CMake

For a CMake project (3.28 or later, any generator, Xcode's included):

```cmake
find_package(Otok CONFIG REQUIRED PATHS "${CMAKE_SOURCE_DIR}/Otok" NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
target_link_libraries(app PRIVATE otok::LZ4)
```

`otok::LZ4` brings the XCFramework's slice for the platform you build for, its headers and its link settings.

## Next

- [Coming from CocoaPods](/start/from-cocoapods/): what a Podfile becomes.
- [Options, profiles and configurations](/guides/options/) of the libraries you build.
- [Updating](/guides/lock/): `otok update` moves to newer versions and rewrites the lock.
- The [`otok.toml` reference](/reference/otok-toml/).
