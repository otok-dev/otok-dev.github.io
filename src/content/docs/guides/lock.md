---
title: The lock and updates
description: What otok.lock records, when it changes, and how to move to newer versions.
sidebar:
  order: 2
---

`otok.lock` is written by otok and committed with your project. It records, for every library and every tool that
builds one:

- the version and the recipe's revision;
- the recipe: where it came from (the index, git, a directory) and the hash of its files;
- the source and every other input, by sha256 or git commit;
- the libraries and tools it depends on.

With it, every machine builds exactly the same libraries, and an input that changed upstream is an error rather than a
different build.

## install and update

`otok install` keeps what the lock has. It resolves again only what the lock cannot answer: a library you added, a
constraint the locked version no longer satisfies, an option or a platform you changed.

```text
$ otok install
otok.lock is up to date
```

After narrowing `version = "~> 1.10"` to `"~> 1.10.0"`:

```text
$ otok install
otok.lock updated:
  lz4: 1.11.0 (r1) -> 1.10.0 (r1)
```

Widening the constraint back changes nothing: 1.10.0 still satisfies it, and `install` keeps it. To move to the newest
versions the constraints allow, use `update`, for everything or for some libraries:

```text
$ otok update lz4
otok.lock updated:
  lz4: 1.10.0 (r1) -> 1.11.0 (r1)
```

`otok outdated` shows what `update` would choose and the newest version the recipe has, constraints aside:

```text
$ otok outdated
library              current       compatible    latest        recipe
lz4                  1.11.0 (r1)   1.11.0 (r1)   1.11.0 (r1)   apotocki/lz4
tool cmake@4.4.5     4.4.5 (r1)    4.4.5 (r1)    4.4.5 (r1)    apotocki/cmake
...
```

## Looking at the graph

`otok tree` prints what is resolved: libraries, their versions and recipes, the tools that build them, and the options
that differ from the defaults. `otok why <library>` says who asked for a library and for each of its option values:

```text
$ otok why lz4
lz4 1.11.0 (r1) apotocki/lz4
  required by:
    otok.toml: ~> 1.10
  platforms: windows
```

## In CI

```sh
otok install --locked
```

`--locked` fails when `otok.lock` is missing or would change, instead of writing it, so CI builds what was committed:

```text
error: otok.lock is out of date (--locked):
  lz4: 1.11.0 (r1) -> 1.10.0 (r1)
run 'otok install' to update it
```

`--offline` uses only the cache and fetches nothing; `--frozen` is both. See [Continuous integration](/guides/ci/)
for caching the builds between runs.

## Advisories

A version of a recipe in the index may carry an advisory: a security problem, a broken build, or a withdrawal.
`otok install` and `otok update` avoid such versions when they choose, and say so when the lock already has one.
`otok audit` checks the lock against the index's advisories and your license policy, and exits with 1 on a security
advisory, a withdrawn version or a refused license:

```text
$ otok audit
otok.lock: 4 packages, nothing to report
```

## Systems

A project may be built on several systems: the Apple target on a Mac, the Windows target on Windows, Android on any of
them. The lock holds the libraries and tools of the systems the project has been built on (`systems` at its top); the
first `otok install` on a new system adds that system's tools to it. Commit the change.
