---
title: The cache
description: Where otok keeps downloads and builds, how to clean it, and how a team shares its builds.
sidebar:
  order: 5
---

Everything otok downloads and builds is kept in one cache, shared by every project of the machine:

| System | Default location |
|---|---|
| macOS | `~/Library/Caches/otok` |
| Linux | `$XDG_CACHE_HOME/otok`, or `~/.cache/otok` |
| Windows | `%LOCALAPPDATA%\otok\cache` |

`cache-dir` in [`config.toml`](/reference/config/) or `OTOK_CACHE_DIR` puts it elsewhere.

Every entry is found by the hash of everything that made it: a download by its sha256, a build by the recipe, the
source, the options, the flags, the toolchain and the builds of its dependencies. Two projects asking for the same
library with the same options share one build. Nothing in the cache is an input of its own, so it can be deleted at
any time: otok fetches and builds again what is missing. It is marked with a `CACHEDIR.TAG`, which backup tools skip.

## Cleaning

Entries not used for 30 days are removed automatically, at most once a day, by a later `otok install`.
`cache-max-age` in `config.toml` changes the number of days; `0` turns it off.

```sh
otok clean --unused              # entries unused for cache-max-age days, now
otok clean --unused --days 7
otok clean --builds              # built libraries, dev builds and the logs of failed builds
otok clean --downloads
otok clean --sources             # unpacked sources and git repositories
otok clean                       # everything
otok clean --dry-run             # what would be removed
```

## Sharing builds between machines

A team can share what its machines build through a store of its own, so that CI and every developer do not build the
same libraries again. There is no public store: built libraries reach only the machines you give them to. A store is
a directory (a network share) or an HTTP server: nginx with WebDAV, [bazel-remote](https://github.com/buchgr/bazel-remote),
a generic repository of Artifactory, anything that answers `GET` and `PUT` of files.

Stores are named in the [`config.toml`](/reference/config/) of each machine, never in a project, so cloning a project
never makes otok take binaries from a place you did not choose:

```toml
# a developer's machine: takes what is there
[[build-cache]]
url = "https://otok-cache.example.com/team"
token-file = "~/.config/example/otok-cache-read-token"

# CI: puts there what it builds
[[build-cache]]
url = "https://otok-cache.example.com/team"
push = true
token-file = "~/.config/example/otok-cache-write-token"
```

`otok install` looks for each library in the local cache first, then in the stores in their order, and builds only
what none has; it fetches the sources of those alone. A library found in a store is checked (its hash, the key it was
built for, its binaries) before it enters the local cache. A store that cannot be reached is a warning, and the
libraries are built. `otok install --no-build-cache` uses the local cache alone.

```sh
otok cache status                # where each library would come from: the local cache, a store, a build
otok cache push                  # put what the local cache holds into the stores that take pushes
otok cache push zlib --store URL # the builds of one library, into one store
```

Libraries built from a source or recipe of a path on your machine (a `path` of `otok.toml`) are not pushed unless the
store has `push-local = true`; those of [dev builds](/guides/dev-builds/) never are. [`otok publish`](/recipes/publish/)
takes the dependencies of the recipes it publishes from the stores and pushes what it builds, but builds those recipes
on the machine.

A library is found in a store only when everything that went into its build is the same, the toolchain included: pin
the versions of Xcode, Visual Studio, the NDK and the compilers on the machines that share a store. Whoever reads a
store trusts everyone who may write to it: give the write token to CI and to the people who build releases, a read
token to the others.

otok removes nothing from a store; prune it on the server, by the access time of its files (`ac/` holds a small file
per build, `cas/` the archives they name). The layout and the protocol are in the
[specification](https://github.com/otok-dev/otok/blob/main/docs/formats/cache.md#12-shared-build-cache).

## Logs

`otok log <library>` shows the log of the latest build of a library kept in the cache, a failed one too;
`otok log <library> --list` lists them.
