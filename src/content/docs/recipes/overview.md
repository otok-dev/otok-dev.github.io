---
title: How recipes work
description: What a recipe is, where it lives, and how otok finds it.
sidebar:
  order: 1
---

A recipe tells otok how to build one library for one target: where the source is, which platforms it supports, what
tools it needs, how to build it and what comes out. It is a small directory of text files:

```text
lz4/1.11/apple/
├── recipe.toml           what: version, license, source, platforms, toolchains, products
├── build.lua             how: a function that builds one slice
└── PrivacyInfo.xcprivacy the library's privacy manifest
```

`recipe.toml` of LZ4 for Apple platforms:

```toml
[recipe]
api = 1
library = "lz4"
name = "lz4"
version = "1.11.0"
revision = 1
license = "BSD-2-Clause"
license-files = ["lib/LICENSE"]
homepage = "https://lz4.org"
description = "LZ4, an extremely fast lossless compression library."
keywords = ["compression", "lz4"]
linkage = ["static"]

[source]
git = "https://github.com/lz4/lz4"
commit = "c72c7c0ec132ad2ce2fe9fad7b0c728d9faee2fc"
tag = "v1.11.0"

[platforms]
supported = ["ios", "iossim", "macosx", "catalyst", "tvos", "tvossim", "watchos", "watchossim", "xros", "xrossim"]
build-on = ["macos/xcode"]

[toolchains]
cmake = { version = ">= 3.20", default-recipe = "apotocki/cmake" }
ninja = { version = ">= 1.10", default-recipe = "apotocki/ninja" }

[[product]]
name = "LZ4"
libraries = ["lz4"]
apple = { privacy-manifest = "PrivacyInfo.xcprivacy" }
```

and its `build.lua`:

```lua
-- The CMake project in build/cmake, the static library only.
function build(slice, options, deps)
    otok.cmake{
        source = slice.source .. "/build/cmake",
        defines = { BUILD_STATIC_LIBS = true, LZ4_BUILD_CLI = false, LZ4_BUILD_LEGACY_LZ4C = false },
    }
    local p = slice.prefix
    -- lz4file.h includes lz4frame_static.h, which the CMake project does not install
    otok.copy(slice.source .. "/lib/lz4frame_static.h", p .. "/include/lz4frame_static.h")
    return { libraries = { lz4 = p .. "/lib/liblz4.a" }, headers = p .. "/include" }
end
```

## Slices

otok calls `build` once per *slice*: one platform, architecture and configuration, such as `iossim-arm64`. Each call
gets a fresh copy of the source, an empty `slice.prefix` to install into, and a toolchain set up for that slice
(compilers, flags, SDK, a CMake toolchain file). The function returns what it built: the libraries by name and the
headers. otok then checks every library (that it is built for the slice's platform and architecture, that it does not
refer to the build's own directories), and packages the slices: XCFrameworks for Apple, directories per ABI for
Android, per architecture and configuration for Windows.

Builds run in a sandbox, without network access and writing only into their own directories. Everything a
build needs is fetched before it starts and checked against its hash: the source, the recipe's resources, the
dependencies' builds, the tools.

## Variants

A recipe is for one target. The same library for several targets is several recipes with one id, *variants*, side by
side in the index: `apotocki/lz4` has `apple`, `android`, `linux` and `windows`. A user names the id; otok takes the
variant of the target it builds for. Variants of one version may differ in their revisions, since each is published
from a machine that can build it.

## Where recipes come from

| In `otok.toml` | The recipe |
|---|---|
| `recipe = "apotocki/lz4"` | from the [index](https://otok-dev.github.io/index/), which records where each version's recipe tree is and its hash |
| `recipe = { git = "https://…", rev = "<commit>", path = "lz4" }` | from a git repository at a commit |
| `recipe = { path = "recipes/lz4" }` | from a directory, as it is on disk: for writing and testing a recipe |

The index does not hold recipes: an entry names a commit and a directory of the publisher's repository, and its hash.
The recipes of `apotocki/…` are in [otok-dev/recipes](https://github.com/otok-dev/recipes); every one is shown on its
[catalog](https://otok-dev.github.io/index/) page, with the differences between its versions.

## The rules a recipe follows

- **Text only.** A recipe directory holds UTF-8 text (at most 256 files, 1 MiB). Anything binary comes with the source
  or as a resource with a URL and a hash; a prebuilt library cannot hide in a recipe.
- **Pinned inputs.** The source is a git commit or an archive with its sha256; so is every resource.
- **Declared tools.** Every program that shapes the output (CMake, Ninja, Perl, make…) is declared in `[toolchains]`,
  with a recipe that builds it, so it is part of the build's identity.
- **Permanent versions.** A published version is never changed: a changed recipe is a new revision.
