---
title: First project for Windows
description: Build LZ4 for Windows with MSVC and use it from CMake or a Visual Studio project.
sidebar:
  order: 4
---

This page builds [LZ4](https://lz4.org) for Windows and links it into a small C program. You need otok
([installed](/start/install/)), Visual Studio with the C++ workload and git.

## Describe the project

In an empty directory, create `otok.toml`:

```toml
[otok]
format = 1

[windows]
build-on = ["windows/msvc"]
architectures = { windows = ["x86_64"] }
configurations = ["debug", "release"]

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
```

- `[windows]` is the target: libraries for programs built with MSVC. `build-on` says in which environment they
  are built, here Visual Studio's own compiler (`windows/clang-cl` would use clang-cl with Visual Studio's runtime).
- `configurations` builds both: a debug program must link libraries built against the debug CRT (`/MDd`).
- `[deps.lz4]` asks for the library `lz4`, built by the recipe `apotocki/lz4` of the
  [public index](https://otok-dev.github.io/index/), at version 1.10 or a later 1.x.

## Install

```powershell
otok install
```

```text
otok.lock created:
  added lz4 1.11.0 (r1)
  tool added cmake 4.4.5 (r1)
  tool added ninja 1.13.2 (r1)
  tool added python 3.14.10 (r1)
toolchain of 'windows': Visual Studio 18.0 at 'C:\Program Files\Microsoft Visual Studio\18\Community' (MSVC 14.51.36231, Windows SDK 10.0.26100.0)
...
output 'Otok': 1 copied, 0 unchanged, 0 removed
```

otok chose the newest version the constraint allows, wrote it into `otok.lock`, fetched the sources, and built
LZ4 with the CMake and Ninja of their own recipes, which it built first. The first run takes a while; the next
ones, in this project or any other, take the builds from the cache.

Commit `otok.toml` and `otok.lock`. The lock pins every version, recipe and source by its hash, so another machine
running `otok install` builds exactly the same libraries. `Otok/` is generated: add it to `.gitignore`.

The libraries are in `Otok/`:

```text
Otok/
  Acknowledgements.md       the licenses of everything built, for your about box or notice file
  lz4/
    include/                lz4.h, lz4frame.h, ...
    lib/x86_64/lz4.lib      release
    debug/lib/x86_64/lz4.lib
    licenses/
  otok-config.cmake         for CMake
  otok.props, otok.targets  for Visual Studio projects
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
otok_copy_runtime_dlls(hello)
```

```powershell
cmake -S . -B build -A x64
cmake --build build --config Debug
build\Debug\hello.exe
```

```text
LZ4 1.11.0
```

`otok::LZ4` brings the headers, the library of the configuration you build (the debug one for Debug) and of your
architecture, the system libraries the product needs and its defines. `otok_copy_runtime_dlls` copies the DLLs of
dynamic libraries beside the program after it is built; with static libraries it does nothing, so it does no harm to
call it always.

The file also checks what would otherwise fail at link time, and says what to do: an architecture or a configuration
the output was not built for, or an MSVC older than the one that built the libraries.

## Use it from a Visual Studio project

On Windows the output also has `otok.props` and `otok.targets`. Import the first before the project's settings and the
second at the end, and name the products the project links in `OtokProducts`:

```xml
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="..\Otok\otok.props" />
  <!-- the project's configurations, Microsoft.Cpp.Default.props, Microsoft.Cpp.props -->
  <PropertyGroup>
    <OtokProducts>LZ4</OtokProducts>
  </PropertyGroup>
  <!-- the project's sources, Microsoft.Cpp.targets -->
  <Import Project="..\Otok\otok.targets" />
</Project>
```

Every project gets the include directories, and the library directories of its platform (`x64`, `ARM64`) and
configuration; the products of `OtokProducts` (separated by `;`) are linked, with their system libraries and defines,
and their DLLs are copied beside an application after it is built. For every project of a solution, import the two
files from `Directory.Build.props` and `Directory.Build.targets` instead.

## Next

- [Options, profiles and configurations](/guides/options/) of the libraries you build.
- [Updating](/guides/lock/): `otok update` moves to newer versions and rewrites the lock.
- The [`otok.toml` reference](/reference/otok-toml/).
