# otok mark

Vector sources of otok's mark. The site's favicon (`public/favicon.svg`) is a copy of `otok-small.svg`; the
organization's avatar is `otok-avatar-500.png`, rendered from `otok-fullbleed.svg`. Edit the SVGs, then export again.

## Concept

The ring of the Otok family, kept from the Otok Hex icon (a gold "O"), with two light lines merging into one arrow
through it: the sources and a recipe become one build, handed to your project. Each product of the family has its
own line through the same ring and its own background; otok's is this arrow on dark blue.

## Colors

| Role       | Color     |
|------------|-----------|
| Background | `#1F3A5F` |
| Ring       | `#F2B33D` |
| Lines      | `#FFF8E7` |

## Geometry (100-unit frame)

- Ring: center (50, 50), radius 25, stroke 12.
- Lines: `M17 35 C 32 35, 38 50, 52 50 H80 M17 65 C 32 65, 38 50, 52 50 M68 38 L81 50 L68 62`, stroke 5.5, round
  caps and joins.
- Gap: the lines stroked at 12 are cut out of the ring.
- Rounded tile: corner radius 22.

## Files

| File | Frame | Use |
|---|---|---|
| `otok.svg` | 100, rounded tile | 48 px and up: pages, documents |
| `otok-small.svg` | 100, rounded tile (radius 18) | 16-32 px: the favicon; heavier ring and lines, wider gaps |
| `otok-fullbleed.svg` | 100, square | the GitHub organization's avatar (GitHub rounds it), listings that mask icons |
| `otok-avatar-500.png` | 500 × 500 | the avatar to upload |

## Export

`otok-avatar-500.png` was rendered with headless Microsoft Edge from a page showing `otok-fullbleed.svg` at 500 px:

```
msedge --headless=new --window-size=500,500 --screenshot=otok-avatar-500.png page.html
```

The mark and these files are licensed as the site's own code: CC0 1.0.
