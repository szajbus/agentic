# Setup & Installation (Tailwind CSS v4)

v4 is built around first-class build-tool integrations rather than a PostCSS
plugin you bolt on. Pick the one that matches the project. In all cases the CSS
entrypoint reduces to a single `@import "tailwindcss";` — there is **no**
`tailwind.config.js` and **no** `@tailwind base/components/utilities`.

## Vite (recommended whenever the project builds with Vite)

```bash
npm install tailwindcss @tailwindcss/vite
```

```js
// vite.config.js / vite.config.ts
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [tailwindcss()],
})
```

```css
/* src/styles.css (or app.css) */
@import "tailwindcss";
```

Import that CSS file once from your entry module. The dedicated Vite plugin is
faster and needs no PostCSS config.

## PostCSS (any PostCSS-based build pipeline)

```bash
npm install tailwindcss @tailwindcss/postcss
```

```js
// postcss.config.mjs
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
}
```

Note: in v4 you do **not** also add `autoprefixer` or `postcss-import` — the
Tailwind PostCSS plugin handles imports and vendor prefixing itself. Remove them
if migrating.

## CLI (no bundler)

```bash
npm install @tailwindcss/cli
npx @tailwindcss/cli -i ./src/input.css -o ./dist/output.css --watch
```

## Framework-managed (standalone binary)

Some backend frameworks vendor a **standalone Tailwind binary** through their own
installer instead of npm. You don't install the npm packages — you just edit the
CSS entrypoint, and the framework runs the binary during asset builds. These setups commonly use `source(none)` plus
explicit `@source` lines because the binary's working directory isn't the project
root:

```css
@import "tailwindcss" source(none);
@source "../js";
@source "../templates";   /* wherever your markup lives */
```

Add design tokens via `@theme` and plugins via `@plugin`, exactly as in any other
v4 project — only the way the binary is invoked differs.

## Content detection & `@source`

v4 **automatically** scans your project for class names — no `content: []` array.
It heuristically ignores `.gitignore`d paths, binary files, and `node_modules`.

Use `@source` only to cover what auto-detection misses:

```css
@import "tailwindcss";

/* Add a path outside the default scan (e.g. a sibling package, a UI library). */
@source "../node_modules/@my-org/ui";

/* Force-include classes that never appear literally in source (dynamic strings). */
@source inline("bg-red-500 bg-green-500 bg-blue-500");

/* Disable all automatic detection and list sources explicitly. */
@import "tailwindcss" source(none);
@source "../src";
```

`@source inline()` is the v4 replacement for the removed `safelist` config
option. It also supports brace expansion, e.g.
`@source inline("{hover:,}bg-{red,green,blue}-{100..900..100}")`.

## Prefixes

If you need a prefix (to avoid collisions), it's now written like a variant and
declared in the import:

```css
@import "tailwindcss" prefix(tw);
```

Usage becomes `tw:flex tw:bg-red-500 tw:hover:bg-red-600`. Theme variables are
emitted with the prefix too (`--tw-color-...`).

## Troubleshooting an unstyled / blank build

1. **Did you import correctly?** It must be `@import "tailwindcss";` — not the
   old `@tailwind` directives (those silently produce nothing in v4).
2. **Are classes being detected?** If using `source(none)` or building in an odd
   CWD, your markup directories may not be scanned. Add explicit `@source` lines.
3. **Dynamic class names** (`` `bg-${color}-500` ``) are never detected — use full
   literal strings or `@source inline()`.
4. **PostCSS project still has v3 plugins?** Remove `autoprefixer` and
   `postcss-import`; keep only `@tailwindcss/postcss`.
5. **Mixed v3/v4?** A leftover `tailwind.config.js` is ignored unless explicitly
   loaded with `@config`. Theme changes you put there won't apply — move them to
   `@theme`.
