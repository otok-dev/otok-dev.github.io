---
title: Write a recipe
description: A recipe for a library the index does not have, built and tested from a directory of your project.
sidebar:
  order: 2
---

This page writes a recipe for [cJSON](https://github.com/DaveGamble/cJSON), a small JSON parser in C with a CMake
build, for Apple platforms, and uses it from Swift before publishing anything.

## The project

Keep the recipe in a directory of a project that uses it:

```text
hello/
├── otok.toml
└── recipes/cjson/
    ├── recipe.toml
    └── build.lua
```

```toml
# otok.toml
[otok]
format = 1

[apple]
platforms = ["macosx", "iossim"]
deployment = { macos = "14.0", ios = "17.0" }

[deps.cjson]
recipe = { path = "recipes/cjson" }
```

A `path` recipe is read as it is on disk, every time: change it and run `otok install` again.

## recipe.toml

```toml
[recipe]
api = 1
library = "cjson"
name = "cjson"
version = "1.7.19"
revision = 1
license = "MIT"
license-files = ["LICENSE"]
homepage = "https://github.com/DaveGamble/cJSON"
description = "cJSON, an ultralightweight JSON parser in ANSI C."
keywords = ["json"]
linkage = ["static", "dynamic"]

[source]
git = "https://github.com/DaveGamble/cJSON"
commit = "c859b25da02955fef659d658b8f324b5cde87be3"
tag = "v1.7.19"

[platforms]
supported = ["ios", "iossim", "macosx", "catalyst", "tvos", "tvossim", "watchos", "watchossim", "xros", "xrossim"]
build-on = ["macos/xcode"]

[toolchains]
cmake = { version = ">= 3.20", default-recipe = "apotocki/cmake" }
ninja = { version = ">= 1.10", default-recipe = "apotocki/ninja" }

[[product]]
name = "cJSON"
libraries = ["cjson"]
```

- `[recipe]`: `library` is the library's name, as projects write it in `[deps.cjson]`; `name` the recipe's, which with
  the publisher makes its id (`you/cjson`). `version` is the library's, `revision` the recipe's own: 1 for the first
  recipe of a version, raised whenever the recipe changes. `license` is an SPDX expression, and `license-files` are
  copied into the output and listed in the acknowledgements.
- `[source]`: a git repository at a full commit (the `tag` is a help, checked against it), or an archive:
  `url = "…"` with its `sha256`. A private repository can be reached over ssh (`git@host:team/engine.git`), with your
  keys; such a recipe is for your projects, not for the public index. `patches = ["patches/0001-fix.patch"]` applies patches of the recipe directory.
- `[platforms]`: the platforms the recipe builds, and the environments it builds in.
- `[toolchains]`: the programs the build runs, with the recipes that build them. `otok.cmake` needs `cmake` and the
  generator's `ninja`, and refuses to run without them declared.
- `[[product]]`: what consumers get. Here one product, `cJSON`, holding the library `cjson`: on Apple platforms a
  module `cJSON` with all headers of the library. A recipe may have several products, and `defines`, system
  libraries to link (`link = { libraries = ["z"] }`) and Apple frameworks (`apple = { frameworks = ["Security"] }`).

## build.lua

```lua
function build(slice, options, deps)
    otok.cmake{
        defines = {
            ENABLE_CJSON_TEST = false,
            ENABLE_TARGET_EXPORT = false,
            -- cJSON asks for CMake 3.0, which CMake 4 no longer accepts
            CMAKE_POLICY_VERSION_MINIMUM = "3.5",
        },
    }
    local p = slice.prefix
    local lib = slice.linkage == "dynamic" and "/lib/libcjson.dylib" or "/lib/libcjson.a"
    return { libraries = { cjson = p .. lib }, headers = p .. "/include" }
end
```

`otok.cmake` configures the source with the slice's toolchain file (compilers, SDK, architecture, deployment version),
installs into `slice.prefix` with Ninja, and passes `BUILD_SHARED_LIBS` from the linkage the project asked for. The
other helpers are `otok.meson`, `otok.autotools`, `otok.make` and `otok.b2`; `otok.run` runs any program, and
`otok.copy`, `otok.write` and friends work on files inside the build's directories.

The function returns the libraries by the names products use, and the headers.

## Build it

```text
$ otok install
...
built cjson 1.7.19 for macosx-arm64 (1.1 s), 3 of 4 slices
built cjson 1.7.19 for iossim-arm64 (1.2 s), 4 of 4 slices
packaging cjson 1.7.19 for apple
output 'Otok': 1 copied, 0 unchanged, 0 removed
```

```swift
import cJSON

print("cJSON \(String(cString: cJSON_Version()))")
```

When a build fails, otok prints the end of its log and keeps the whole log: `otok log cjson` shows it. `-v` shows the
commands each slice runs, `-vv` their output, and `--keep-build-dirs` keeps the work directory of a failed build for
you to look into.

On Windows the paths `build.lua` gets (`slice.source`, `slice.prefix`, the dependencies' prefixes, toolchains) are on
short drive letters that only otok and the build's processes see ([Install otok](/start/install/#windows)): use them
as they are, and do not hand them to a program outside the build.

## Options and dependencies

Options are declared in the recipe and read in `build.lua`:

```toml
[options.utils]
type = "bool"
default = false
doc = "Also build cJSON_Utils (JSON Pointer, Patch and Merge Patch)."
```

```lua
otok.cmake{ defines = { ENABLE_CJSON_UTILS = options.utils, ... } }
```

A dependency on another library is a `[deps]` table of the recipe, with the recipe projects get by default; its build
is found through `CMAKE_PREFIX_PATH`, `pkg-config` and the other helpers' means, and is in `deps.<library>` of
`build.lua`:

```toml
[deps.zlib]
version = "~> 1.3"
default-recipe = "apotocki/zlib"
when = { option = "zlib" }
```

## Header-only libraries

A library that is only headers has a product without libraries, `libraries = []`, and a `build` that copies the
headers into `slice.prefix`:

```toml
[[product]]
name = "TomlPlusPlus"
libraries = []
link = { runtime = "c++" }
```

```lua
function build(slice, options, deps)
    otok.copy(slice.source .. "/include/toml++", slice.prefix .. "/include/toml++")
    return { libraries = {}, headers = slice.prefix .. "/include" }
end
```

Such headers are the same for every platform, architecture and configuration, so otok builds a package whose products
are all header-only once per target, in one slice named `headers`, and gives it to every platform:

```text
$ otok install
...
built tomlplusplus 3.4.0 for headers (0.1 s)
```

That slice has no compiler: `slice.headers` is true, `slice.platform`, `slice.arch`, `slice.configuration` and
`slice.linkage` are nil, `slice.toolchain` has only `env`, and `otok.cmake`, `otok.meson`, `otok.autotools`,
`otok.make` and `otok.b2` refuse to run. `otok.run`, the file functions and the programs of `[toolchains]` work, and
`build_tools` is not run. Its cache entry is shared by projects of every configuration, linkage and environment of
the target.

A library whose headers need a compiler to be made (a configure test that writes `config.h`) builds every slice as
usual with `headers-slice = false` in `[recipe]`; `headers-slice = true` says the recipe expects one slice, and makes it
an error when a product holding libraries is chosen.

A library that can be header-only or compiled offers both, with an option and a product of headers only that the
compiled product depends on, as [Boost's recipe](https://github.com/otok-dev/recipes/tree/main/recipes/boost/1.92) does:

```toml
[options.compiled]
type = "bool"
default = false
doc = "Compile the implementation into a library, linked through TomlPlusPlusLib."

[[product]]
name = "TomlPlusPlus"
libraries = []
link = { runtime = "c++" }

[[product]]
name = "TomlPlusPlusLib"
libraries = ["tomlplusplus"]
headers = false              # its headers are those of TomlPlusPlus
depends = ["TomlPlusPlus"]
when = { option = "compiled" }
```

Without the option only `TomlPlusPlus` is chosen, and the package is built in one slice; with it, every slice is
built. When the compiled library needs a definition in its consumers (`TOML_HEADER_ONLY=0`), write it into the
installed headers in `build.lua`, so that every consumer sees it: a product's `defines` reach C++ consumers on Apple
platforms only through Clang modules.

## Tools

A recipe can also build programs that run on the build machine: a code generator, a compiler. Other recipes then
run them during their builds, and projects can deliver them to their own builds
([Tools for your own build](/guides/tools/)). Name the programs in `[tool]`:

```toml
[tool]
programs = ["protoc"]
```

A tool is built in the *tool slice*: for the build machine, static, in release, with `slice.is_tool` true. A recipe
that is both a library and a tool builds its programs there only, and returns them beside its libraries:

```lua
local out = { libraries = libraries, headers = slice.prefix .. "/include" }
if slice.is_tool then
    out.programs = { protoc = slice.prefix .. "/bin/protoc" .. (slice.os == "windows" and ".exe" or "") }
end
return out
```

Tool slices are built by the target of the machine's system (`macosx` of `apple` on a Mac, `linux`, `windows`), so a
tool for every machine needs a variant for each of these three. `apotocki/protobuf` is an example of a library that is
also a tool.

## Other targets

This recipe is for Apple platforms. The same library for Windows is a second recipe of the same name, its variant
for that target, usually with the same `build.lua`: copy the directory, set `supported = ["windows"]` and
`build-on = ["windows/msvc"]`, and return the `.lib` (and, when dynamic, the DLL with `{ link = …, runtime = … }`).
Look at how the [recipes of the index](https://github.com/otok-dev/recipes) do it for each target.

## The full description

The [recipe.toml](https://github.com/otok-dev/otok/blob/main/docs/formats/recipe-toml.md) and
[build.lua](https://github.com/otok-dev/otok/blob/main/docs/formats/build-lua-api.md) specifications describe every
key and function.
