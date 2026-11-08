---
title: Working on a library
description: Build a library of your project from its working tree, incrementally, without changing the lock.
sidebar:
  order: 7
---

When you work on a library your project depends on, or on its recipe, you do not want to commit, push and update the
lock for every change. Name the working trees in `otok.dev.toml`, next to `otok.toml`, and keep that file out of git:

```toml
[deps.engine]
source = "../engine"
# the recipe's checkout too, with its uncommitted changes
recipe = "../recipes/engine"

[deps.engine.resources]
core = "../core"
```

- `source` replaces the library's source; `resources` replace resources of its recipe by their names; `recipe`
  replaces the recipe directory (`build.lua`, patches, products).
- `otok install` builds such a library in a work directory it keeps, copying only the files that changed, so the
  library's own build recompiles only those: a change of one file rebuilds one file. Libraries that depend on it are
  rebuilt when its result changes.
- The lock does not change. `otok install --locked` still passes, and a recipe from the file must give the same
  graph as the locked one: the same version and dependencies. A change of the graph is a change of the project, made in
  `otok.toml`.
- `otok tree` marks these libraries `(dev)`. `--no-dev` ignores the file and builds exactly what the lock says.

Of a working tree that is a git checkout, otok takes the files git does not ignore, as a commit would hold them, so
build directories inside the checkout do not get in the way.

To make the change permanent, commit and push the library or recipe, then point `otok.toml` at the new version or
commit and run `otok install`.
