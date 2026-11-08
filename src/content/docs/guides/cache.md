---
title: The cache
description: Where otok keeps downloads and builds, and how to clean it.
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

## Logs

`otok log <library>` shows the log of the latest build of a library kept in the cache, a failed one too;
`otok log <library> --list` lists them.
