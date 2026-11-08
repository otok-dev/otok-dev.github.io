---
title: Licenses
description: What otok's license means for your app, and who licenses what.
sidebar:
  order: 2
---

## What otok generates is yours

otok is licensed under the GNU General Public License, version 3, with an additional permission, the
[Otok Output Exception](https://github.com/otok-dev/otok/blob/main/LICENSE-EXCEPTION). The exception gives you a
perpetual, irrevocable, royalty-free permission to use, change and distribute everything otok generates when it runs,
under terms of your choice, proprietary software included, and free of the GPL's conditions:

- `Package.swift`, module maps, shims and wrappers, `otok-config.cmake` and other build files;
- generated headers, toolchain files, `Info.plist` files and privacy manifests;
- `Acknowledgements.md` and `.plist`, `otok.lock`, the output of `otok metadata`;
- the packaged libraries as otok packaged them.

Using otok to build your app, closed-source or not, puts no obligation of the GPL on your app.

## What keeps its own license

- **The libraries** keep their licenses: OpenSSL's Apache 2.0, Boost's BSL, and so on. otok collects their license
  files into the output and into `Acknowledgements.md` and `Acknowledgements.plist`, for the notices your app must
  show. `[policy] deny-licenses` or `allow-licenses` in `otok.toml` keeps licenses you cannot accept out of your
  project, and `otok audit` checks the lock against them.
- **Recipes** are licensed by their publishers. The recipes of `apotocki/…` are in
  [otok-dev/recipes](https://github.com/otok-dev/recipes).
- **The index's data** (the entries, library and publisher files) is public domain (CC0).
- **Your project's files**, and anything you put into the output yourself, are yours as before.

## otok itself

If you change otok and distribute your version, the GPL applies to it: its source must be available under the same
terms. The source of every release is at [otok-dev/otok](https://github.com/otok-dev/otok), and `otok licenses`
shows the licenses of the libraries built into otok.

This documentation is licensed under CC BY 4.0, and its examples are public domain (CC0): copy them into your projects.
