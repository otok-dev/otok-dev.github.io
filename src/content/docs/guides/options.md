---
title: Options, linkage and profiles
description: Choose what each library is built with, and keep variants of the build in profiles.
sidebar:
  order: 1
---

Everything that changes what is built is in `otok.toml`: the options of each library, static or dynamic linkage,
configurations, compiler flags and language standards. Machine settings never change the output, so the same
`otok.toml` and `otok.lock` build the same libraries everywhere.

## Options

A recipe declares options: booleans, integers, strings, lists, files. `otok info` shows them:

```sh
otok info apotocki/boost
```

```text
options of 1.92.0 (r1):
  icu        bool   default false
  libraries  list (atomic|charconv|chrono|...|url|wave)  default []
```

Set them in the library's table:

```toml
[deps.boost]
recipe = "apotocki/boost"
version = "~> 1.92"
options = { libraries = ["json", "program_options"], icu = true }
```

or, when there are many, as a table of its own:

```toml
[deps.boost.options]
libraries = ["json", "program_options"]
icu = true
```

An unknown option or a value of the wrong type is an error before anything is fetched. An option you do not set takes
the recipe's default, unless another library that depends on it asks for a value. Two libraries asking for different
values is an error that names both; `otok why <library>` shows who asked for what.

An option of type `file` takes a file of your project, whose contents become part of the build (ICU's data filter):

```toml
[deps.icu4c]
recipe = "apotocki/icu4c"
version = "~> 79.1"
options = { data = "file", data-filter = "icu-filter.json" }
```

## Static or dynamic

Libraries are static unless you say otherwise. A target table sets the default for its libraries, and a library's
table overrides it:

```toml
[windows]
build-on = ["windows/msvc"]
linkage = "dynamic"

[deps.lz4]
recipe = "apotocki/lz4"
version = "~> 1.10"
linkage = "static"
```

The recipe must offer the linkage (`[recipe] linkage`); otherwise resolution fails. On Apple platforms a dynamic
library is a framework inside its XCFramework, which Xcode embeds and signs in your app.

## Configurations

Apple, Android and Linux builds are `release` unless you ask for more. On Windows a program built in Debug links the
debug CRT, and the libraries must match it, so a Windows project usually builds both:

```toml
[windows]
build-on = ["windows/msvc"]
configurations = ["debug", "release"]
```

The `release` libraries go to `lib/`, the `debug` ones to `debug/lib/`. `[apple]` takes one configuration: SwiftPM
binary targets cannot vary by configuration, and apps link release libraries in their debug builds.

## Platforms and architectures

A target table lists the platforms and, when you want fewer than all, the architectures:

```toml
[apple]
platforms = ["ios", "iossim", "macosx"]
architectures = { iossim = ["arm64"], macosx = ["arm64"] }
deployment = { ios = "16.0", macos = "13.0" }

[android]
architectures = { android = ["arm64-v8a", "x86_64"] }
deployment = { android = "24" }
```

A library can be narrowed to some of the platforms, with everything only it depends on:

```toml
[deps.libssh2]
recipe = "apotocki/libssh2"
version = "~> 1.11"
platforms = ["macosx"]
```

## Compiler flags

`cflags`, `cxxflags` and `ldflags` pass flags to the builds of the libraries, for every library of a target or for
one library:

```toml
[apple]
cflags = ["-fno-omit-frame-pointer"]

[deps.openssl]
cflags = ["-DOPENSSL_SMALL_FOOTPRINT"]
```

They come after otok's own flags, so a flag where the last one wins (`-O2`, `-D` of the same macro) is yours. Flags
that choose the platform (`-target`, `-arch`, `-isysroot`, `--sysroot`, `-m…-version-min`) are otok's and are refused.
Flags change the build, not the resolution: they are not in `otok.lock`.

## Language standards

To build every library of a target with the C++ standard of your code:

```toml
[android]
cxx-standard = 23
```

`c-standard` does the same for C. Without them, each target gets the lowest standard every recipe allows, which
`otok install` prints. A recipe that cannot build with the standard you ask for is an error before anything is built.
`-std=` in flags is refused: the standard is a key of its own.

## Profiles

A profile is a named set of changes, chosen with `--profile`:

```toml
[profile.ci]
apple = { platforms = ["iossim"] }

[profile.asan.apple]
cflags = ["-fsanitize=address"]

[profile.dll.deps.lz4]
linkage = "dynamic"
```

```sh
otok install --profile ci
```

A profile may change the platforms, architectures, deployment versions, configurations, linkage, flags, standards and
options. It cannot add or remove libraries or change their versions or recipes: one `otok.lock` serves every profile,
and `otok fetch` fetches the inputs of all of them at once. A profile's flags are added to the base flags; anything
else it sets replaces the base value.
