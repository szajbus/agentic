# Theme Building & Maintenance (`@theme`)

In v4 the theme **is** CSS. The `@theme` block defines design tokens as CSS
custom properties; each token simultaneously (1) generates utility classes and
(2) is exposed as a real `var(--token)` you can use anywhere. There is no JS
config and no `theme()` function — this is the single source of truth for your
design system.

## The core idea: token = utility + variable

```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.62 0.19 259);
}
```

This one line gives you:
- utilities: `bg-brand`, `text-brand`, `border-brand`, `fill-brand`, `ring-brand`, …
- a variable: `var(--color-brand)`, usable in hand-written CSS, inline styles,
  other tokens, JS via `getComputedStyle`.

So you never duplicate a color between "the config" and "my CSS variables" — they
are the same thing.

## Theme namespaces

The **prefix of the variable name** determines which utilities it powers. Know
these — using the wrong namespace means no utilities are generated:

| Namespace | Generates | Example |
|---|---|---|
| `--color-*` | color utilities (`bg-`, `text-`, `border-`, …) | `--color-brand` |
| `--font-*` | `font-*` family | `--font-display` |
| `--text-*` | `text-*` size (+ optional line-height) | `--text-tiny` |
| `--font-weight-*` | `font-*` weight | `--font-weight-extrablack` |
| `--spacing-*` | padding/margin/width/gap/… | `--spacing-18` |
| `--breakpoint-*` | responsive variants (`sm:`, `lg:`, …) | `--breakpoint-3xl` |
| `--container-*` | `max-w-*` and `@container` sizes | `--container-prose` |
| `--radius-*` | `rounded-*` | `--radius-card` |
| `--shadow-*`, `--inset-shadow-*` | `shadow-*` | `--shadow-card` |
| `--ease-*` | `ease-*` | `--ease-snappy` |
| `--animate-*` | `animate-*` | `--animate-wiggle` |
| `--aspect-*`, `--blur-*`, `--perspective-*`, … | the matching utilities | |

Full namespace list: <https://tailwindcss.com/docs/theme>.

## Extending vs. overriding the defaults

v4 ships a full default theme (colors, spacing scale, breakpoints, etc.). Your
`@theme` **adds to** it by default; defining a token with an existing name
overrides that one entry.

```css
@theme {
  --color-brand: oklch(0.62 0.19 259);  /* adds bg-brand */
  --color-blue-500: #2563eb;            /* overrides the built-in blue-500 */
}
```

To clear a whole namespace (e.g. drop all default colors and start clean) set it
to `initial`:

```css
@theme {
  --color-*: initial;          /* removes every default color utility */
  --color-bg: oklch(1 0 0);
  --color-fg: oklch(0.2 0 0);
  --color-brand: oklch(0.62 0.19 259);
}
```

`--*: initial` wipes every default token across all namespaces — useful for a
fully bespoke design system, but then you own defining everything you use.

## Token architecture: primitives → semantic (→ component)

The single most important theming best practice: **don't put raw palette colors
in your markup.** Layer your tokens so intent is separated from value.

1. **Primitives** — the raw scale, no meaning attached: `--color-blue-500`,
   `--color-zinc-900`, `--spacing-4`. (Tailwind's defaults already give you most
   of these.)
2. **Semantic tokens** — purpose-named, referencing primitives:
   `--color-surface`, `--color-fg`, `--color-muted`, `--color-border`,
   `--color-danger`. These are what components use.
3. **Component tokens** (optional, large design systems) — per-component values
   referencing semantic tokens: `--color-button-bg`.

```css
@theme {
  /* primitives */
  --color-zinc-50:  oklch(0.985 0 0);
  --color-zinc-900: oklch(0.21 0.01 286);
  --color-blue-600: oklch(0.55 0.22 263);

  /* semantic — reference the primitives */
  --color-surface: var(--color-zinc-50);
  --color-fg:      var(--color-zinc-900);
  --color-brand:   var(--color-blue-600);
}
```

In markup you write `bg-surface text-fg`, never `bg-zinc-50 text-zinc-900`. Why
this matters: a rebrand or a new theme becomes a handful of semantic-token edits
instead of a find-replace of `zinc-900` across hundreds of files, and theme
switching (below) only has to remap the semantic layer. **Skipping the semantic
layer is the antipattern** — it's what makes refactors and dark mode painful.

## `@theme` vs `@theme inline`

- `@theme { }` emits the variable into `:root` **and** uses it to build utilities.
  The generated utility references the variable, so changing the variable at
  runtime (e.g. under `.dark`) re-themes the utility. This is what you usually
  want.
- `@theme inline { }` inlines the **value** into the generated utilities instead
  of referencing the variable. Use it when a token's value is itself derived from
  another variable that changes per-scope, to avoid a double-indirection bug.
  Most theming uses plain `@theme`; reach for `inline` only when you see a token
  not updating as expected under a theme switch.

## Dark mode & multi-theme

The default `dark:` variant follows `prefers-color-scheme`. For a **toggle**, you
control, redefine the variant and flip CSS variables per theme:

```css
@import "tailwindcss";

/* Make dark: respond to a .dark class (or [data-theme="dark"]) anywhere up the tree */
@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --color-bg: oklch(1 0 0);
  --color-fg: oklch(0.21 0.01 286);
}

/* Re-point the SAME tokens under the dark scope.
   Use a normal CSS rule (NOT @theme) for scoped overrides. */
@layer base {
  .dark {
    --color-bg: oklch(0.21 0.01 286);
    --color-fg: oklch(0.98 0 0);
  }
}
```

Because `bg-bg`/`text-fg` reference `var(--color-bg)`/`var(--color-fg)`, toggling
`.dark` on `<html>` re-themes the whole app with no per-element `dark:` classes.
This token-swap approach scales to N themes (`[data-theme="..."]`) far better than
sprinkling `dark:` everywhere — it's the same mechanism themeable component
ecosystems use under the hood: named themes that just remap these variables.

Use per-element `dark:` utilities for one-off exceptions, not as the primary
strategy in a themed app.

## Referencing tokens from hand-written CSS

```css
.custom-card {
  background: var(--color-brand);
  padding: var(--spacing-6);
  border-radius: var(--radius-card);
}
```

No `theme()` call. In JS:
```js
const brand = getComputedStyle(document.documentElement)
  .getPropertyValue("--color-brand");
```
(`resolveConfig` no longer exists in v4 — read the CSS variables instead.)

## Keeping a theme maintainable as it grows

- **One source of truth.** All design tokens live in `@theme`. Don't mirror them
  into JS constants or a second `:root` block — read the variables when you need
  them in code.
- **Semantic tokens over raw scales for app-level decisions.** Define
  `--color-surface`, `--color-muted`, `--color-danger` and use those in markup, so
  a rebrand or new theme is a handful of token edits rather than a find-replace of
  `slate-700` across the codebase. Keep the raw palette (`--color-slate-*`)
  available for fine-tuning, but prefer semantic names in components.
- **Group and comment** the `@theme` block by namespace (colors, typography,
  spacing, radii, shadows) so it reads like a design spec.
- **OKLCH for color** is the v4 default and what you should author in — it gives
  perceptually even lightness steps and a wider gamut. Format:
  `oklch(L C H)` e.g. `oklch(0.62 0.19 259)`.
- **Promote repeated arbitrary values into tokens.** If `w-[72px]` or
  `text-[13px]` shows up more than a couple of times, add `--spacing-18` /
  `--text-tiny` and use the named utility. Arbitrary values are an escape hatch,
  not a theming strategy.
- **Split large themes** into separate files imported into the entrypoint, but
  keep them all `@theme` blocks so they merge into one system:
  ```css
  @import "tailwindcss";
  @import "./theme/colors.css";
  @import "./theme/typography.css";
  ```
  (Each file uses `@theme { }`.) If a framework manages the binary's CWD, confirm
  `@source`/import paths resolve from the entrypoint's location.
