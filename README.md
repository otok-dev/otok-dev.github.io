# otok documentation

The site of [otok](https://github.com/otok-dev/otok) at <https://otok-dev.github.io>, built with
[Starlight](https://starlight.astro.build). The catalog of libraries, <https://otok-dev.github.io/index/>, is made by
[otok-dev/index](https://github.com/otok-dev/index).

Fixes and improvements are welcome as pull requests.

The text is licensed under CC BY 4.0, the examples and the site's code under CC0 1.0 ([LICENSE](LICENSE)).

## Working on it

```sh
npm ci
npm run dev       # http://localhost:4321
npm run build     # the site in dist/
```

Pages are Markdown in `src/content/docs/`. English is the source. A translation goes into
`src/content/docs/<lang>/` under the same paths, with the language added to `locales` in `astro.config.mjs`; a page
not translated yet is shown in English.

Do not create a top-level `index/` directory: that path belongs to the catalog.
