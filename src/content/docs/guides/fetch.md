---
title: Where inputs come from
description: Mirrors, rewritten URLs, offline builds and networks that reach only approved hosts.
sidebar:
  order: 6
---

Recipes name where their sources are: an archive URL with its sha256, or a git repository at a commit. otok checks
every input against that hash or commit, so you may fetch the bytes from anywhere you like without changing what is
built. Locations of your own go into the machine's [`config.toml`](/reference/config/), or into `[fetch]` of a
project's `otok.toml` when everyone building the project should use them.

## A mirror of archives

An *asset mirror* is a plain directory of files named by their sha256, served over HTTPS or read from disk:

```toml
asset-mirror = ["https://artifacts.example.com/otok/{sha256}", "file:///Volumes/mirror/{sha256}"]
```

It is tried before the recipe's own URL. To fill one, copy otok's own downloads: `downloads/sha256/` of the
[cache](/guides/cache/) has exactly that layout.

## Other locations of a URL

`url-rewrite` gives URLs another location: a proxy of GitHub, a fork, an internal git server. It applies to archives,
git repositories (sources, resources, recipes) and submodules:

```toml
[[url-rewrite]]
from = "https://github.com/{owner}/{repo}"
to = "https://git.example.com/{owner}-{repo}"

[[url-rewrite]]
from = "https://archives.boost.io/release/{version}/source/{file}"
to = "https://artifacts.example.com/boost/{version}/{file}"
exact = true
```

`{name}` matches one path segment, `{name*}` several. Rules are tried in order and the first that matches applies.

## Only approved hosts

```toml
mirrors-only = true
```

otok then fetches only from the machine's asset mirrors and rewritten URLs, never from the places recipes or projects
name, and an input they do not cover is an error that names it. Use it on networks where only some hosts may be
reached, or to make sure a mirror really holds everything. `mirrors-only = ["boost"]` does the same for some libraries.

## Offline

```sh
otok fetch             # every input of the lock, for every profile
otok install --offline # later: only the cache, no network
```

`otok fetch` downloads everything `otok.lock` needs and builds nothing; `--offline` then uses only the cache. With
`--frozen` (`--locked` and `--offline`) a build machine without network builds exactly the lock.

## The index

otok reads the recipes of the public index from `https://otok-dev.github.io/index`. `index-mirror` reads the same
index from a copy: an HTTPS copy of its view, a directory holding one, or a checkout of the index repository. To use
another index instead, set `index`; to add an index of your organization to a project, see `[indexes]` in the
[`otok.toml` reference](/reference/otok-toml/).
