---
title: CMake projects with find_package
description: Keep find_package(ZLIB) and ZLIB::ZLIB in a CMake project that moves to otok, on every target.
sidebar:
  order: 9
---

A CMake project that took its libraries from vcpkg, Conan, Homebrew or the system already says how it finds them:

```cmake
find_package(ZLIB REQUIRED)
find_package(lz4 CONFIG REQUIRED)
target_link_libraries(app PRIVATE ZLIB::ZLIB LZ4::lz4)
```

It can keep these lines. otok's output has, beside `otok-config.cmake`, the CMake packages of its libraries under their
usual names, and a *dependency provider* that answers `find_package` with them. The project is configured with one
setting more:

```sh
cmake -S . -B build -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=Otok/otok-provider.cmake
```

Nothing else changes: the project's own files, its toolchain file (the NDK's, an iOS one) and its subdirectories and
FetchContent dependencies stay as they are. It needs CMake 3.28 or later.

## An example

```toml
[otok]
format = 1

[linux]
build-on = ["linux/gcc"]

[deps.zlib]
recipe = "apotocki/zlib"
version = "~> 1.3"

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

```cmake
cmake_minimum_required(VERSION 3.28)
project(hello C)

find_package(ZLIB REQUIRED)
find_package(lz4 CONFIG REQUIRED)

add_executable(hello main.c)
target_link_libraries(hello PRIVATE ZLIB::ZLIB LZ4::lz4)
```

```sh
otok install
cmake -S . -B build -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=Otok/otok-provider.cmake
cmake --build build
```

`ZLIB::ZLIB` and `LZ4::lz4` are thin targets over otok's own `otok::ZLIB` and `otok::LZ4`: they bring the same
headers, libraries of the configuration you build, system libraries and defines, and the same checks of the
architecture and the runtime. So they work the same on every target, the XCFrameworks of Apple platforms included.
The calls written as `find_package(Otok …)` in the [first project pages](/start/linux/) keep working beside them.

Gradle passes the setting with the other CMake arguments of the app's module, as an absolute path:

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake { arguments += "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${file("Otok/otok-provider.cmake").absolutePath}" }
        }
    }
}
```

In a CMake preset it is a cache variable, `"CMAKE_PROJECT_TOP_LEVEL_INCLUDES": "${sourceDir}/Otok/otok-provider.cmake"`.

## What the provider does

The provider sees every `find_package` of the project after its first `project()`:

- **A package of the output** is taken from `Otok/cmake.d/<package>/` alone, whatever the call says of where to look.
  `MODULE`, `PATHS`, `HINTS` and the like are dropped, so CMake's own `FindZLIB.cmake` does not run and find the
  system's zlib, and the package is found when building for a device, where CMake looks only in the SDK or the NDK.
  The name is matched without regard to case: `find_package(zlib)` finds `ZLIB`.
- **The version** is the one otok chose, and the call only checks it: `find_package(OpenSSL 3.0)` finds OpenSSL 4.1,
  `EXACT` finds only the same version. A package whose version does not fit is not found, and CMake does not go on to
  find another one on the machine.
- **Components** are found when the products they need are in the output: `find_package(Boost REQUIRED COMPONENTS
  json filesystem)` fails, naming the components there are, when the project did not ask the Boost recipe for them.
- **Variables** of the usual kind are set too: `ZLIB_FOUND`, `ZLIB_VERSION`, `ZLIB_LIBRARIES`, `ZLIB_INCLUDE_DIRS`,
  under the name as the recipe writes it, in upper case and as the call wrote it, and those a recipe adds, such as
  `OPENSSL_INCLUDE_DIR`. On Apple platforms the headers are inside the XCFrameworks, so the include variables are empty
  there: use the targets.
- **Any other name** is left to CMake's own search. When it is the name of a library of the output whose recipe gives
  no CMake package, CMake warns once that its own search may find another copy of that library on the machine, and
  names the cure, below.

## Which names a library has

The names come from the library's recipe, from its `[cmake]` tables: the names of CMake's find module (`ZLIB::ZLIB`,
`OpenSSL::SSL`) and those the library's own installed package defines (`LZ4::lz4`, `absl::strings`). The
[catalog](https://otok-dev.github.io/index/) shows the recipe's files; after `otok install`, `Otok/cmake.d/` has a
directory per package of the output.

## Other names, or none

`cmake` in `[deps.<library>]` replaces the recipe's tables, for a recipe that gives none or not the names your project
uses:

```toml
[deps.libsodium]
recipe = "apotocki/libsodium"
version = "~> 1.0"
cmake = { unofficial-sodium = { targets = { "unofficial-sodium::sodium" = "Sodium" } } }
```

Each target links the products named, here `otok::Sodium` (the `[[product]]` names of the recipe); the
[recipe page](/recipes/write/#cmake-names) describes the keys. A target name may hold one group of braces,
`"ZLIB::{ZLIB,ZLIBSTATIC}"`, for several targets at once, or a star, `"absl::*"`, for every target of that namespace
the library's own build exports.

`cmake = false` gives no package for the library: for two libraries whose recipes give the same package name, which is
an error when the output is written, or for a project that finds that library its own way.

## Without the provider

`Otok/cmake.d/<package>` as `<package>_DIR` finds the same package for a call in config mode (`CONFIG`, or
`CMAKE_FIND_PACKAGE_PREFER_CONFIG` on). A call asking for `MODULE` still runs CMake's find module, and when the package
is not found CMake may take the system's library. The provider is the way that leaves nothing to chance.

## What stays the project's

The names move the project's linking, not what it ships. Dynamic frameworks are still embedded with
`otok_embed_frameworks` and DLLs copied with `otok_copy_runtime_dlls` (or the project's own
`$<TARGET_RUNTIME_DLLS>`, which finds them through the targets), as on the [first project pages](/start/windows/).
