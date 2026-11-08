---
title: Publish a recipe
description: Put a recipe into the public index, so that projects can use it by its id.
sidebar:
  order: 3
---

Published, a recipe is used as `recipe = "you/cjson"` with a version constraint, shows on the
[catalog](https://otok-dev.github.io/index/), and is updated by `otok update`. Publishing adds an *entry* to the
[index](https://github.com/otok-dev/index): the recipe's description, options and dependencies, and where its tree is
(a git repository, a commit, a directory) with the hash of its files. The recipe itself stays in your repository,
under your license.

## Before you publish

1. **Put the recipe into a git repository** that others can fetch over HTTPS, such as a public repository on GitHub.
   One repository may hold many recipes, each in a directory of its own (`recipes/<library>/<line>/<variant>/` is the
   layout of [otok-dev/recipes](https://github.com/otok-dev/recipes)). Commit and push it: an entry names the commit.
2. **Make it complete.** Publishing checks more than a build from a directory:
   - every toolchain has a `default-recipe` in the index;
   - the source, the resources and the mirrors are `https`, and download with their hashes;
   - for Apple platforms, every library that calls an API needing a declared reason has a product with a privacy
     manifest declaring it, and no library defines symbols of Apple's private system libraries.
3. **Use a machine that builds the target.** `otok publish` builds the recipe as a project of its own, for every
   platform and architecture it supports, in each of its environments that the machine has: a Mac for Apple, Windows
   (or Linux with clang-cl) for Windows, any of them with the NDK for Android.

## Publish

Sign in to GitHub with [GitHub CLI](https://cli.github.com) (`gh auth login`), or set `GITHUB_TOKEN`. Then, in the
checkout of your recipes:

```sh
otok publish --dry-run recipes/cjson/1.7/apple   # build and check, publish nothing
otok publish recipes/cjson/1.7/apple
```

otok builds the recipe from its pushed commit, checks it, and opens a pull request to the index from your fork of it,
adding the entry. The publisher is your GitHub account's name unless `--publisher` names another (an organization you
are a public member of). `--all` publishes every recipe of the checkout that is not published yet.

## Review

The index's CI checks every pull request without running anything of it: the files hash to the entry, the entry says
what `recipe.toml` says, the inputs download and match. Then:

- **Your first publication** also registers your publisher name, and waits for an index maintainer.
- **Until your publisher is established**, every pull request waits for a maintainer's review. A maintainer makes a
  publisher established once its recipes have shown themselves; from then on, CI merges its pull requests itself.
- Your GitHub account must be at least 30 days old, and the entries per day are limited (the numbers are in the
  index's [`index.toml`](https://github.com/otok-dev/index/blob/main/index.toml)).

A merged entry appears on the catalog and in `otok search` within minutes.

## After publishing

**Entries are permanent.** A published version is never edited or removed, so that every lock that names it keeps
working. To change a recipe, publish it again with its `revision` raised: `otok update` moves projects to it. To stop
projects from choosing a version, add an *advisory* to the index for it (withdrawn, broken or security), by a pull
request as for an entry; `otok install` then avoids the version, and `otok audit` reports it in locks that have it.

**Each variant is published on its own**, from a machine that builds its target, with revisions of its own.

By publishing you agree to the index's [terms](https://github.com/otok-dev/index/blob/main/CONTRIBUTING.md): the
entries are public domain (CC0), and the index may fetch, keep and show your recipe's files.
