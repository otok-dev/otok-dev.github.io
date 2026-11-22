---
title: Coding agents
description: Let Claude Code, Codex, Cursor and other coding agents add, build and update libraries with otok.
sidebar:
  order: 10
---

A coding agent drives otok as you would, from the terminal: it finds a recipe, writes `otok.toml`, runs
`otok install` and reads what happened. Two things make that reliable: the commands print JSON for it, and a skill
tells it how otok is used.

## JSON output

The commands an agent reads take `--format json`:

```sh
otok search png --format json
otok info apotocki/libpng --format json
otok install --format json
```

- `search`, `info`, `outdated`, `audit`, `why` and `log --list` print one JSON document with the command's data and
  its `diagnostics`, the errors and warnings, each with its `severity`, `message` and, when it concerns a file, the
  file, line and column.
- `install`, `update` and `fetch` run for minutes, so they print JSON lines, one event per line as it happens: the
  lock written, the inputs fetched, each slice building, built or taken from the cache, each output written, each
  diagnostic, and last `{"event":"end","exit":0}`. The progress for people stays on standard error.

```text
{"command":"install","event":"start","format":1,"otok":"0.5.34"}
{"changes":["added lz4 1.11.1 (r1)"],"event":"lock","state":"created"}
{"event":"inputs","resources":0,"sources":1}
{"build-tools":false,"configuration":"release","dev":null,"event":"slice","id":"lz4","library":"lz4","revision":1,"seconds":null,"slice":"linux-x86_64","state":"building","tool":false,"version":"1.11.1"}
{"build-tools":false,"configuration":"release","dev":null,"event":"slice","id":"lz4","library":"lz4","revision":1,"seconds":9.8,"slice":"linux-x86_64","state":"built","tool":false,"version":"1.11.1"}
{"cached":0,"count":1,"event":"slices"}
{"copied":1,"dir":"Otok","event":"output","removed":0,"target":"linux","unchanged":0}
{"event":"end","exit":0}
```

The documents and events are specified in
[cli-json.md](https://github.com/otok-dev/otok/blob/main/docs/formats/cli-json.md): keys are added without notice, and
any other change raises the `format` they carry. `otok metadata` prints the whole project as JSON (always JSON): its
targets, outputs, packages, options and products. JSON output needs otok 0.5.34 or later (`search` and `info`:
0.5.33).

## The skill

[`SKILL.md`](/skills/otok/SKILL.md) is a skill in the Agent Skills format: the workflow of adding a library, the
`otok.toml` of each target, how the output is used from CMake, Xcode and Visual Studio, and what to do when a build
fails. An agent that supports skills loads it when the project has an `otok.toml` or you ask for a native library.

otok writes it, as the otok of your machine has it (otok 0.5.35 or later):

```sh
otok agent-skill            # .claude/skills/otok/SKILL.md of the project: commit it, and every agent there has it
otok agent-skill --user     # ~/.claude/skills/otok/SKILL.md, for every project of yours
otok agent-skill --dir DIR  # DIR/otok/SKILL.md, the skills directory of another agent
otok agent-skill --print    # on standard output
```

`.claude/skills/` is where Claude Code looks; other agents that support the format read skills from directories of
their own, and the file is the same. Run it again after updating otok: it says when the skill is up to date. With an
older otok, download it:

```sh
mkdir -p ~/.claude/skills/otok
curl -fsSL https://otok-dev.github.io/skills/otok/SKILL.md -o ~/.claude/skills/otok/SKILL.md
```

An agent that meets otok without the skill usually runs `otok --help` first, which tells it about `otok agent-skill`
and [`/llms.txt`](/llms.txt).

## AGENTS.md

An agent without skills reads `AGENTS.md` (or `CLAUDE.md`) at the root of the project. A few lines there are enough:

```markdown
## Native libraries

This project gets its native libraries from otok (https://otok-dev.github.io/llms.txt).

- Libraries are declared in `otok.toml`; `otok.lock` is written by otok, never by hand. `Otok/` is generated.
- Run otok commands with `--format json` and read `diagnostics` or the `diagnostic` events.
- Add a library: `otok search <name> --format json`, `otok info <recipe> --format json`, a `[deps.<library>]` table
  in `otok.toml`, then `otok install --format json`.
- A failed build: `otok log <library> --list --format json`, then read the newest failed log.
```

## For agents that read the web

[`/llms.txt`](/llms.txt) is an index of this site for language models: what otok is, the rules above, and the pages
to read for each task.
