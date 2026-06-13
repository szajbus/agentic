# Best Practices & Common Patterns (Tailwind CSS v4)

## Composition over component classes

Tailwind's model is: style in markup by composing utilities, and reuse by
extracting a **component or template** in whatever your view layer is (a UI
component, a server-rendered partial/template, a macro), not by minting a CSS
class per UI element. A v3 reflex is to write
`@layer components { .btn { @apply ... } }` for everything — in v4 prefer:

- **A component/template** that bundles the classes once, so a change propagates
  to every instance. The exact mechanism depends on your stack; conceptually:
  ```
  Button(label) =>
    <button class="inline-flex items-center rounded-md bg-brand px-4 py-2
      text-sm font-medium text-white hover:bg-brand/90"> {label} </button>
  ```
- **`@utility`** when you genuinely need a reusable class (e.g. you don't control
  the markup, or it's used in plain HTML/email/markdown output):
  ```css
  @utility btn {
    @apply inline-flex items-center rounded-md px-4 py-2 text-sm font-medium;
  }
  ```
  `@utility` (not `@layer components`) is correct in v4 — it participates in
  variants, so `hover:btn`, `md:btn` work, and it lands in the right cascade
  layer.
- **Class-string constants / a variants helper** for conditional styling, instead
  of string-concatenating utilities by hand. A shared constant
  (`card = "rounded-2xl border border-border p-6 shadow-sm"`) builds an
  app-specific vocabulary while staying composable. For multi-variant components
  (`size`, `intent`, …), a small "variants" helper that maps props to class
  strings keeps the matrix readable; pair it with a class-merge step so a
  caller-supplied class can override base styles rather than leaving two
  conflicting utilities in the output. Small community libraries exist for both,
  but the pattern matters more than any specific one.

## Don't over-abstract

The opposite failure of utility sprawl is **component explosion** — wrapping every
primitive in a bespoke component or minting a `@utility` for every one-off. Both
add indirection without reuse. Heuristic: start with raw utilities inline; extract
a component or class only once you see the *same* pattern repeated across multiple
files. Premature abstraction is harder to undo than a little duplication.

## `@apply` — use sparingly, and know the scoped-styles gotcha

`@apply` is fine in small doses (a `@utility`, a base reset, unstyleable
third-party markup). Avoid rebuilding your whole UI in `@apply` — you lose
co-location and gain a second place to maintain styles.

In **component-scoped styles** (single-file-component `<style>` blocks, CSS
Modules, any scoped-CSS context) the Tailwind context isn't present, so `@apply`,
`theme`, and custom utilities don't resolve until you reference your main
stylesheet:

```css
/* inside a scoped/SFC <style> block */
@reference "../app.css";   /* required, or @apply errors / no-ops */
h1 { @apply text-2xl font-bold text-brand; }
```
For just colors/tokens you can also use the CSS variable directly
(`color: var(--color-brand)`), which needs no `@reference`.

## Custom utilities & variants

```css
/* Functional utility with a value, using the spacing/theme scales */
@utility tab-* {
  tab-size: --value(integer);
}

/* Custom variant (state/structural selector) */
@custom-variant aria-current (&[aria-current="page"]);
@custom-variant supports-grid (@supports (display: grid));
```
Use `@custom-variant` for v3's `darkMode: 'class'`, `group-*` extensions, ARIA/
data-attribute states, and feature queries.

## Dark mode

See `theming.md` for the token-swap approach (preferred for themed apps). For
incidental dark tweaks, per-element `dark:` utilities are fine:
```html
<div class="bg-white text-gray-900 dark:bg-gray-900 dark:text-gray-100">
```
Define the variant once if you toggle via class:
`@custom-variant dark (&:where(.dark, .dark *));`.

## Container queries (built in — no plugin)

Style children based on a container's width, not the viewport:
```html
<div class="@container">
  <div class="grid grid-cols-1 @md:grid-cols-2 @xl:grid-cols-3 gap-4">…</div>
</div>
```
- `@container` marks the query container.
- `@sm:`/`@md:`/`@lg:`/… are container variants; sizes come from the
  `--container-*` theme namespace.
- Named containers: `@container/sidebar` + `@lg/sidebar:…`.
- `@max-md:` for max-width container queries.

Prefer container queries for genuinely reusable components (cards, widgets) that
should adapt to whatever slot they're dropped into; use viewport breakpoints
(`md:` etc.) for page-level layout.

## Responsive & state variants

- Mobile-first: bare utility = all sizes, `md:` = `md` and up. Don't write
  `sm:` expecting "small screens only" — use `max-sm:` for that.
- Stack variants left-to-right in v4: `dark:md:hover:bg-brand/90`,
  `*:first:pt-0`.
- Group/peer: `group-hover:`, `peer-checked:`, and arbitrary variants
  `group-[.is-open]:` / `has-[:checked]:` for relational styling.
- `has-*`, `not-*`, `in-*`, `nth-*` are first-class — reach for them before
  custom CSS.

## Arbitrary values: escape hatch, not default

```html
<div class="top-[117px] bg-[#1da1f2] grid-cols-[200px_1fr]">
```
Valid, but each one is a design decision that lives outside your system. Rules of
thumb:
- One-off, truly unique value → arbitrary value is fine.
- Used 2+ times, or conceptually part of the design system → add a `@theme`
  token and use the named utility.
- CSS variables in arbitrary values use **parentheses** in v4: `bg-(--brand)`,
  and `w-(--sidebar-width)`. Spaces become underscores: `[max-content_auto]`.

## Tooling that enforces these practices

- **Class ordering**: install `prettier-plugin-tailwindcss` (the official
  Prettier plugin) and let it sort utilities automatically. Consistent order
  improves diffs and readability — don't hand-bikeshed class order.
- **Lint against drift**: a Tailwind ESLint plugin can flag arbitrary values,
  unknown classes, and contradicting utilities — useful as a CI gate on larger
  teams to keep `pl-[17px]` one-offs out of the codebase.
- These tools read your CSS-first `@theme`, so custom tokens/utilities are
  recognized without extra config.

## Things to actively avoid in v4

- **Raw palette colors in markup** (`bg-zinc-900`, `text-blue-600`) — use semantic
  tokens (`bg-surface`, `text-brand`) so themes/dark mode and rebrands stay cheap.
  See `theming.md`.
- **Arbitrary-value drift** (`pl-[17px]`, `text-[13px]`, `bg-[#1da1f2]`) as a habit
  — fine once, an antipattern when repeated; promote to a token.
- **Rebuilding everything in `@apply`** — it re-creates the maintenance problem
  Tailwind removes; prefer framework components, reserve `@apply` for unstyleable
  third-party markup.
- **Component explosion** — abstracting before you see real repetition.
- Recreating `tailwind.config.js` — there is none; theme goes in `@theme`.
- `@tailwind base/components/utilities` — silently produces nothing; use
  `@import "tailwindcss"`.
- `@layer components { }` for custom classes — use `@utility`.
- `theme('…')` function calls — use `var(--token)`.
- `*-opacity-*` utilities and leading `!important` (`!flex`) — use `/opacity`
  modifiers and trailing `flex!`.
- `space-x/space-y` for new layouts — use `flex`/`grid` + `gap-*`.
- Assuming v3 class names: re-check shadow/blur/rounded/ring/outline (see
  `v3-vs-v4.md`) before emitting them.

## Quick sanity checklist before finishing Tailwind work

- [ ] CSS entrypoint uses `@import "tailwindcss";` (not `@tailwind …`).
- [ ] No new `tailwind.config.js`; tokens are in `@theme`.
- [ ] Class names use v4 scales (`shadow-sm` not v3 `shadow`, `ring-3` for the
      thick ring, `outline-hidden` not `outline-none`).
- [ ] Borders/rings have explicit colors (v4 default is `currentColor`).
- [ ] Custom classes use `@utility`; scoped styles `@reference` the main sheet.
- [ ] Repeated arbitrary values promoted to theme tokens.
