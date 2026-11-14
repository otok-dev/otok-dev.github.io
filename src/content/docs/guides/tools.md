---
title: Tools for your own build
description: Programs your build runs, such as protoc, built by otok for your machine and put in Otok/tools.
sidebar:
  order: 8
---

otok builds libraries for your app. It can also build the programs your own build runs on the development machine:
code generators such as `protoc` or `flatc`, a compiler of your project's scripts, a CMake or Ninja of a fixed version.
Such a program comes from a recipe like a library does. It is pinned in the lock and built on each machine the same
way, so it does not have to be installed by hand on every developer's machine and in CI.

## protoc for a project that uses Protocol Buffers

The runtime of Protocol Buffers is a library of the app. `protoc`, which turns `.proto` files into C++, is a tool of
the build machine. Both come from the recipe `apotocki/protobuf`, so one entry asks for both:

```toml
[otok]
format = 1

[windows]
build-on = ["windows/msvc"]

[deps.protobuf]
recipe = "apotocki/protobuf"
version = "~> 36.2"
deliver = ["protoc"]   # and protoc of the same version, for this machine
```

`deliver` asks otok to build the library's recipe also as a tool for this machine, and to copy it into your project.
The tool has exactly the version the library got, so the generated code always matches the runtime it is compiled
against: `otok update` moves both together. `otok install` builds the runtime into `Otok/protobuf/`, as usual, and
`protoc` into `Otok/tools/protobuf/`:

```text
Otok/
├── protobuf/              the runtime, for the target
├── otok-config.cmake
└── tools/
    ├── protobuf/bin/protoc.exe
    ├── otok-tools.cmake   Otok_TOOL_protoc for CMake
    ├── otok-tools.props   $(OtokTool_protoc) for MSBuild
    └── otok-tools.toml    the same paths for scripts
```

`deliver` lists the programs your build runs. A recipe may build several (`otok info apotocki/protobuf` shows its
`[tool] programs`); `deliver = true` takes all of them. A name the recipe does not build is an error.

### Using it from CMake

`otok-tools.cmake` sets `Otok_TOOL_<program>` to the absolute path of each program:

```cmake
cmake_minimum_required(VERSION 3.28)
project(hello CXX)
set(CMAKE_CXX_STANDARD 17)

# the libraries of otok.toml, and the tools it delivers
find_package(Otok CONFIG REQUIRED PATHS "${CMAKE_SOURCE_DIR}/Otok" NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
include("${CMAKE_SOURCE_DIR}/Otok/tools/otok-tools.cmake")

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/hello.pb.cc" "${CMAKE_CURRENT_BINARY_DIR}/hello.pb.h"
    COMMAND "${Otok_TOOL_protoc}" --cpp_out "${CMAKE_CURRENT_BINARY_DIR}" -I "${CMAKE_SOURCE_DIR}/proto" hello.proto
    DEPENDS "${CMAKE_SOURCE_DIR}/proto/hello.proto" "${Otok_TOOL_protoc}")

add_executable(hello main.cpp "${CMAKE_CURRENT_BINARY_DIR}/hello.pb.cc")
target_include_directories(hello PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(hello PRIVATE otok::Protobuf)
```

The same project builds on Linux and macOS with `[linux]` or `[apple]` in place of `[windows]`. There the program is
`protoc-36.2.0` (`bin/protoc` is a link to it), which is why the build should take the path from the variable rather
than spell it out.

### Using it from MSBuild

Import `otok-tools.props` (from `Directory.Build.props`, beside `otok.props`) and use `$(OtokTool_protoc)` in a custom
build step:

```xml
<Import Project="$(MSBuildThisFileDirectory)Otok\tools\otok-tools.props"
        Condition="Exists('$(MSBuildThisFileDirectory)Otok\tools\otok-tools.props')" />
```

```xml
<CustomBuild Include="proto\hello.proto">
  <Command>"$(OtokTool_protoc)" --cpp_out="$(IntDir)." -I proto hello.proto</Command>
  <Outputs>$(IntDir)hello.pb.cc;$(IntDir)hello.pb.h</Outputs>
</CustomBuild>
```

A character of a program's name other than a letter, a digit or `_` becomes `_` in these names: the program
`annium-compile` is `Otok_TOOL_annium_compile` and `$(OtokTool_annium_compile)`.

### Using it from scripts

Gradle, Xcode build phases and shell scripts can read `Otok/tools/otok-tools.toml`. It gives each program's path
relative to the file:

```toml
format = 1

[programs."protobuf"]
"protoc" = "protobuf/bin/protoc.exe"
```

```sh
protoc=Otok/tools/$(sed -n 's/^"protoc" = "\(.*\)"$/\1/p' Otok/tools/otok-tools.toml)
"$protoc" --cpp_out=gen -I proto proto/hello.proto
```

## A tool on its own

A tool that is not a library of your app, such as a compiler of your project's scripts, is delivered from
`[tool-deps]`, with the same `deliver`:

```toml
[tool-deps.annium-compile]
recipe = { git = "https://example.com/recipes.git", rev = "<commit>", path = "annium-compile" }
deliver = true
```

A `[tool-deps.protobuf]` entry beside `[deps.protobuf]` is not needed. Add one only to choose the options, flags or
standard of the tool: the library and its tool are separate builds, and the options of `[deps.protobuf]` are the
library's alone. It names the same `recipe`, and its `version` must allow the one the library gets.

## How it behaves

- **The machine's own build.** A delivered tool is built for the machine `otok install` runs on: a Windows program on
  Windows, a macOS one on a Mac. A project built on several systems locks the tool for each of them, like the tools
  recipes build with.
- **Nothing beside it.** Tools are built static and in release, so `Otok/tools/<library>/` needs nothing but the
  system's libraries. It holds whatever the recipe installs, not only `bin/` and not only the programs listed in
  `deliver`; the files of the consumer name those listed.
- **Up to date.** A tool is copied again only when it changed. One that is no longer delivered is removed, and
  without any delivered tool `Otok/tools/` is removed too. Add `Otok/` to `.gitignore`: it is made by `otok install`.
- **In CI.** `otok install --locked` builds or fetches the same tool from the cache, so CI runs the `protoc` the
  developers run. See [Continuous integration](/guides/ci/).
- **From a working tree.** A tool of your own, such as a compiler of your project's scripts, can be built from its
  working tree with `otok.dev.toml` like any library ([Working on a library](/guides/dev-builds/)). Your build then
  always runs the compiler of the sources you have.
- **Another place.** `tools-output` in `[otok]` moves the tools elsewhere in the project (default `Otok/tools`).

A tool is a recipe with `[tool] programs`, built where `slice.is_tool` holds
([Writing a recipe](/recipes/write/#tools)). A program that is a script run by another tool (Meson, run by Python)
cannot be delivered, since its interpreter is not.
