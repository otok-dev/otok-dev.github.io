---
title: First project for Android
description: Build LZ4 for Android with the NDK and link it into your app's native library with Gradle and CMake.
sidebar:
  order: 3
---

This page builds [LZ4](https://lz4.org) for two Android ABIs and links it into an app's native library. You need otok
([installed](/start/install/)) and the Android NDK; otok finds the newest NDK of the Android SDK that Android Studio
installs, or the one `ANDROID_NDK_HOME` names. It works the same on macOS, Windows and Linux.

## Describe the project

Put `otok.toml` in your app module's directory (`app/`):

```toml
[otok]
format = 1

[android]
architectures = { android = ["arm64-v8a", "x86_64"] }
deployment = { android = "24" }

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

- `[android]` is the target. Its architectures are the ABIs you ship, as Gradle's `abiFilters` names them;
  `arm64-v8a` alone when you omit them.
- `deployment` is the API level, your app's `minSdk` or lower.

## Install

```sh
otok install
```

```text
otok.lock created:
  added lz4 1.11.0 (r1)
  ...
toolchain of 'android': Android NDK 30.0.16248370 at '…/ndk/30.0.16248370'
...
packaging lz4 1.11.0 for android
output 'Otok': 1 copied, 0 unchanged, 0 removed
```

```text
app/Otok/
  otok-config.cmake         for CMake: Gradle's externalNativeBuild
  cmake.d/lz4/              LZ4 under its usual CMake names
  otok-provider.cmake       answers find_package(lz4) with them
  Acknowledgements.md       the licenses of everything built
  lz4/
    include/                lz4.h, lz4frame.h, ...
    lib/arm64-v8a/liblz4.a
    lib/x86_64/liblz4.a
```

Commit `otok.toml` and `otok.lock`; add `Otok/` to `.gitignore`.
Run `otok install` before Gradle builds the app, and again after changing `otok.toml`.

## Link it into your native library

`app/src/main/cpp/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.28)
project(hello C)

find_package(Otok CONFIG REQUIRED PATHS "${CMAKE_CURRENT_SOURCE_DIR}/../../../Otok" NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)

add_library(hello SHARED hello.c)
target_link_libraries(hello PRIVATE otok::LZ4)
```

`app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 24
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }
    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }
}
```

`otok::LZ4` brings the headers and the library of the ABI Gradle builds. An ABI the output was not built for is an
error when CMake configures, with the cure:

```text
otok: …/Otok has no libraries for the architecture 'x86': add it to 'architectures' of [android] in otok.toml and
run otok install
```

A native library that already finds LZ4 as `find_package(lz4 CONFIG)` and links `LZ4::lz4` keeps those lines: pass
the provider instead of calling `find_package(Otok …)`. See [CMake projects with find_package](/guides/cmake/).

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake { arguments += "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${file("Otok/otok-provider.cmake").absolutePath}" }
        }
    }
}
```

## Dynamic libraries and the C++ runtime

With `linkage = "dynamic"` the libraries are shared objects; Gradle packs those your native library links into the
APK by itself. Dynamic libraries in C++ use the shared C++ runtime by default (`stl = "shared"` in `[android]`), and
so must your app: pass `-DANDROID_STL=c++_shared`:

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake { arguments += "-DANDROID_STL=c++_shared" }
        }
    }
}
```

`otok-config.cmake` refuses an app whose runtime does not match its libraries'. Static libraries link into your
native library and need neither.

## The NDK of your app

The libraries are compiled against the C++ headers of the NDK otok built them with, and link with that NDK or a newer
one. `otok-config.cmake` refuses an app whose NDK is older, naming it:

```text
otok: the libraries of …/Otok were built with NDK 30.0.16248370 and link with it or a newer one, not with NDK
29.0.14206865 at '…/ndk/29.0.14206865': build with that NDK or a newer one, or install the libraries with this one
('android-ndk' in otok's config.toml or ANDROID_NDK_HOME) and run otok install
```

Gradle takes the NDK of `ndkVersion` in `build.gradle.kts`. Scripts can ask otok which NDK it uses: `otok metadata`
gives its path and version in `toolchain` of the `android` target.

## Next

- [Several targets in one project](/guides/targets/): the same `otok.toml` for your iOS app.
- [Options, profiles and configurations](/guides/options/).
- The [`otok.toml` reference](/reference/otok-toml/).
