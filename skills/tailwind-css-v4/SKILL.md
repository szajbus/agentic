---
name: tailwind-css-v4
description: >-
  Authoritative guidance for writing Tailwind CSS v4 (v4.0+). Use this whenever
  the work involves Tailwind — setting it up, configuring a theme, writing
  utility classes, building components, migrating from v3, or debugging styles —
  even if the user doesn't say "v4". Tailwind v4 made breaking changes to setup,
  configuration, and dozens of class names, and its config is CSS-first (no
  tailwind.config.js, no @tailwind directives). Reach for this skill before
  scaffolding Tailwind, editing app.css/the theme, or suggesting class names, so
  the output is v4-correct and doesn't fall back to outdated v3 habits.
---

# Tailwind CSS v4

Tailwind v4 (released January 2025, current line v4.1) is a ground-up rewrite. It
is **not** v3 with a new version number — setup, configuration, and many class
names changed. Most Tailwind knowledge baked into models predates v4, so the
default failure mode is silently writing v3 and producing config that doesn't
load or classes that no longer exist.

## The one rule that prevents most mistakes

**Write v4. Treat v3 idioms as antipatterns**, not as a fallback. If you catch
yourself reaching for any of these, stop — they are v3 and are wrong in a v4
project:

| v3 habit (antipattern) | v4 way |
|---|---|
| `tailwind.config.js` for theme/colors | `@theme { }` in your CSS |
| `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` |
| `content: [...]` glob array in config | automatic detection + `@source` for extras |
| `@layer utilities { .foo {} }` for a custom utility | `@utility foo { }` |
| `@layer components` + `theme()` function | `@theme`, `@apply`, and `var(--token)` |
| `!flex` (leading important) | `flex!` (trailing important) |
| `bg-[--var]` | `bg-(--var)` (parentheses) |
| `bg-opacity-50`, `text-opacity-*` | opacity modifier `bg-black/50` |
| `shadow-sm` / `shadow` | `shadow-xs` / `shadow-sm` (the scale shifted — see below) |
| installing `@tailwindcss/container-queries`, line-clamp, aspect-ratio plugins | built in to core, no plugin |

Before suggesting a class name you're unsure about, assume the scale may have
shifted in v4 (shadows, blur, radius, ring, outline all changed) and check
`references/v3-vs-v4.md`.

## Detecting the version in an existing project

Look at the main CSS entrypoint (e.g. `app.css`, `globals.css`, `styles.css`):
- `@import "tailwindcss";` → **v4**. Proceed with this skill.
- `@tailwind base;` etc. and a `tailwind.config.js` with a `content` array → **v3**.
  Don't silently "fix" it to v4; tell the user it's v3 and offer to migrate
  (`npx @tailwindcss/upgrade`, Node 20+) — see `references/v3-vs-v4.md`.

When unsure, check the installed version: `npx tailwindcss --help` shows it, or
look at `package.json` for `tailwindcss@^4`.

## Setup (new project)

v4 ships as a dedicated build tool, not a PostCSS-first design. Pick the
integration that matches the project:

- **Vite** (preferred whenever the project builds with Vite):
  ```bash
  npm install tailwindcss @tailwindcss/vite
  ```
  ```js
  // vite.config.js
  import tailwindcss from '@tailwindcss/vite'
  export default { plugins: [tailwindcss()] }
  ```
- **PostCSS** (any PostCSS-based pipeline): install `@tailwindcss/postcss` and add
  it to `postcss.config.mjs`.
- **CLI** (no bundler): `@tailwindcss/cli`, run with `npx @tailwindcss/cli -i in.css -o out.css --watch`.
- **Standalone / framework-managed**: some frameworks' installers fetch a
  standalone binary; you just edit the CSS.

Then your CSS entrypoint is simply:
```css
@import "tailwindcss";
```
That single line replaces the three `@tailwind` directives **and** the config
file. Full per-integration steps, including `@source` for content detection and
prefixes, are in `references/setup.md`.

## Core v4 directives (CSS-first config)

These live in your CSS file, not in JS. This is the heart of v4 — read
`references/theming.md` for the full treatment.

```css
@import "tailwindcss";

/* Define design tokens. Each token auto-generates utilities AND a CSS variable. */
@theme {
  --color-brand: oklch(0.62 0.19 259);   /* enables bg-brand, text-brand, ... */
  --font-display: "Satoshi", sans-serif; /* enables font-display */
  --breakpoint-3xl: 120rem;              /* enables 3xl: variant */
}

/* Tell Tailwind where to scan for classes beyond the defaults. */
@source "../components";

/* Custom utility — replaces v3's @layer utilities { } */
@utility content-auto {
  content-visibility: auto;
}

/* Custom variant — e.g. a theme or state selector */
@custom-variant dark (&:where(.dark, .dark *));

/* Load a third-party plugin */
@plugin "@tailwindcss/typography";

/* Only if you MUST keep a legacy JS config — not the default path */
@config "../tailwind.config.js";
```

Key mental model: **a theme token and the utility/variable it powers are the same
thing.** `--color-brand` simultaneously creates the `bg-brand`/`text-brand`
utilities and the `var(--color-brand)` variable you can use in hand-written CSS.
There is no `theme()` function call needed anymore — use the variable directly.

## What changed from v3 (most impactful, must-know)

These bite immediately if you assume v3. Full list with exact mappings in
`references/v3-vs-v4.md`.

- **Renamed scales** (the bare name became `-sm`, old `-sm` became `-xs`):
  `shadow→shadow-sm`, `shadow-sm→shadow-xs`; same shift for `blur`, `drop-shadow`,
  `backdrop-blur`, `rounded`.
- **Ring**: `ring` was 3px, now `ring` is **1px**. For the old look use `ring-3`.
  Default ring color is now `currentColor`, not `blue-500`.
- **Outline**: `outline-none` → `outline-hidden` (the old `outline-none` name now
  means `outline-style: none`).
- **Default border/divide color is `currentColor`**, not `gray-200`. Always set a
  color explicitly (`border border-gray-200`).
- **Removed**: all `*-opacity-*` utilities (use `/50` modifiers), `flex-shrink-*`
  →`shrink-*`, `flex-grow-*`→`grow-*`, `overflow-ellipsis`→`text-ellipsis`.
- **`hover:` only fires on devices that actually hover** (`@media (hover:hover)`).
- **`space-x/space-y` selector changed** and is discouraged — prefer `flex`/`grid`
  + `gap-*`.
- Syntax: important is trailing (`flex!`), CSS-var arbitrary values use parens
  (`bg-(--x)`), arbitrary values with spaces use underscores
  (`grid-cols-[max-content_auto]`).

## Best practices & common patterns

See `references/patterns.md` for the full set, and `references/theming.md` for
token architecture. Highlights:

- **Layer your tokens: primitives → semantic.** Define the raw palette/scales in
  `@theme`, then semantic tokens (`--color-surface`, `--color-fg`,
  `--color-brand`) that reference them — and use the *semantic* names in markup
  (`bg-surface`, not `bg-zinc-50`). This is what makes theming, dark mode, and
  rebrands cheap; skipping the semantic layer is the central theming antipattern.
- **Components via composition, not class soup.** Build reuse with your view
  layer's components/templates (or class-string constants / a small "variants"
  helper), not by minting a `.btn` for everything. Reach for `@apply` sparingly — mainly for
  unstyleable third-party markup or `@reference`'d scoped styles. But don't
  over-correct into a wrapper component for every primitive; abstract only on
  real, repeated patterns.
- **Arbitrary values are an escape hatch.** One-off is fine; repeated `pl-[17px]`
  is drift — promote it to a token. Enforce with `prettier-plugin-tailwindcss`
  (ordering) and a Tailwind ESLint rule (flag arbitrary/unknown classes).
- **Dark mode / multi-theme by token swap.** Define a `dark` custom variant
  (class- or `data-`-based) and remap the semantic tokens under that scope, rather
  than sprinkling `dark:` on every element.
- **Component-scoped styles (single-file-component `<style>` blocks, CSS
  Modules)**: you must `@reference` your main stylesheet before `@apply`/`theme`
  work in that scope.
- **Container queries are core**: `@container` on a parent, `@sm:`/`@lg:` on
  children. No plugin.
- **Arbitrary values are an escape hatch, not the default** — if you use the same
  arbitrary value repeatedly, promote it to a `@theme` token.

## Reference files

Read the relevant one when you go deep — don't dump them all into context:

- `references/setup.md` — per-integration install (Vite, PostCSS, CLI,
  framework-managed), `@source` content detection, prefixes, troubleshooting a
  blank/unstyled build.
- `references/v3-vs-v4.md` — complete breaking-changes table, every renamed
  utility, default-value changes with preservation snippets, and migration steps.
- `references/theming.md` — `@theme` in depth: namespaces, overriding vs
  extending defaults, `@theme inline`, referencing tokens, multi-theme/dark-mode
  setups, and how to keep a theme maintainable as it grows.
- `references/patterns.md` — component composition, `@apply`/`@utility` guidance,
  dark mode, container queries, responsive/state variants, and idioms to prefer
  or avoid.
