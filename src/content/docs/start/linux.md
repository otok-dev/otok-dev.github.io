---
title: First project for Linux
description: Build LZ4 for Linux with GCC and use it from CMake, linked statically or shipped as a shared object.
sidebar:
  order: 5
---

This page builds [LZ4](https://lz4.org) for Linux and links it into a small C program. You need otok
([installed](/start/install/#linux)), a compiler (GCC or Clang), git and bubblewrap, which isolates the builds:

```sh
sudo apt install git build-essential bubblewrap
```

## Describe the project

In an empty directory, create `otok.toml`:

```toml
[otok]
format = 1

[linux]
build-on = ["linux/gcc"]
configurations = ["debug", "release"]

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

- `[linux]` is the target: libraries for programs of this machine's Linux, built against its C library and C++
  runtime, for its architecture. `build-on` says which compiler builds them, `linux/gcc` or `linux/clang`.
- `configurations` builds both, so that a debug build of your program links libraries with debug information.
- `[deps.lz4]` asks for the library `lz4`, built by the recipe `apotocki/lz4` of the
  [public index](https://otok-dev.github.io/index/), at version 1.10 or a later 1.x.

## Install

```sh
otok install
```

```text
otok.lock created:
  added lz4 1.11.1 (r1)
  tool added cmake 4.4.5 (r2)
  tool added ninja 1.13.2 (r1)
  tool added python 3.14.10 (r2)
...
toolchain of 'linux': gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0
...
slices: 5 (0 from the cache)
packaging lz4 1.11.1 for linux
output 'Otok': 1 copied, 0 unchanged, 0 removed
```

otok chose the newest version the constraint allows, wrote it into `otok.lock`, fetched the sources, and built
LZ4 with the CMake and Ninja of their own recipes, which it built or downloaded first. Every build runs in a sandbox
without network, which sees the system read-only and writes only its own directory. The first run takes a while; the
next ones, in this project or any other, take the builds from the cache.

Commit `otok.toml` and `otok.lock`. The lock pins every version, recipe and source by its hash, so another machine
running `otok install` builds exactly the same libraries. `Otok/` is generated: add it to `.gitignore`.

The libraries are in `Otok/`:

```text
Otok/
  Acknowledgements.md       the licenses of everything built, for your about box or notice file
  lz4/
    include/                lz4.h, lz4frame.h, ...
    lib/liblz4.a            release
    debug/lib/liblz4.a
    licenses/
  otok-config.cmake         for CMake
```

## Use it from CMake

`Otok/otok-config.cmake` describes every library and product for CMake. `main.c`:

```c
#include <stdio.h>
#include <lz4.h>

int main(void)
{
    printf("LZ4 %s\n", LZ4_versionString());
    return 0;
}
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.28)
project(hello C)

find_package(Otok CONFIG REQUIRED PATHS "${CMAKE_SOURCE_DIR}/Otok" NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)

add_executable(hello main.c)
target_link_libraries(hello PRIVATE otok::LZ4)
```

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/hello
```

```text
LZ4 1.11.1
```

`otok::LZ4` brings the headers, the library of the configuration you build (the debug one for `Debug`, the release
one for the others) and the system libraries and defines the product needs. A configuration you did not build is
served by the other one. The file checks, when CMake configures, that the output has libraries for the architecture
you build for, and says what to do when it has not.

## Shared objects

Libraries are static unless the target asks otherwise:

```toml
[linux]
build-on = ["linux/gcc"]
configurations = ["debug", "release"]
linkage = "dynamic"
```

`Otok/lz4/lib/` then holds `liblz4.so.1.11.1` with its links `liblz4.so.1` and `liblz4.so`. The program built above
runs from the build directory as it is: CMake gives it the path of `Otok/lz4/lib/`. To ship it, put the shared
objects beside the program; otok builds every shared object with `$ORIGIN` in its `RUNPATH`, so the libraries find
each other there, and the program needs the same:

```cmake
set_target_properties(hello PROPERTIES INSTALL_RPATH "$ORIGIN")
install(TARGETS hello DESTINATION .)
install(IMPORTED_RUNTIME_ARTIFACTS otok::lz4_lz4 DESTINATION .)
```

```sh
cmake --install build --prefix dist
```

```text
dist/
  hello
  liblz4.so.1 -> liblz4.so.1.11.1
  liblz4.so.1.11.1
```

`otok::lz4_lz4` is the library itself, named `otok::<library>_<output name>`; a product such as `otok::LZ4` gathers
those it holds. `IMPORTED_RUNTIME_ARTIFACTS` installs a shared object with its link of the `SONAME`, which is what the
program loads.

## Which systems the libraries run on

The libraries are built against this machine's C library and C++ runtime, as your program is when you build it here.
A program meant for older distributions is built on an older one, or in its container image, and otok builds its
libraries there too; the lock is the same on every machine. On Alpine and other systems on musl, the libraries link
musl.

## Next

- [Several targets in one project](/guides/targets/): one `otok.toml` for Linux and the other targets.
- [Options, linkage and profiles](/guides/options/) of the libraries you build.
- [Continuous integration](/guides/ci/): otok's cache in GitHub Actions and elsewhere.
- [The lock and updates](/guides/lock/): `otok update` moves to newer versions and rewrites the lock.
- The [`otok.toml` reference](/reference/otok-toml/).
