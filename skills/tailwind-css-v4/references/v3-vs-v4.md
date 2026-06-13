# v3 → v4: Complete Breaking Changes & Migration

Use this when migrating a v3 project, or when you need the exact v4 equivalent of
a v3 class/idiom. **In a v4 project, the v3 forms are wrong — not deprecated-but-
working, but in many cases silently broken.**

## Table of contents
1. Config & directive changes
2. Renamed utilities (exact mappings)
3. Removed utilities
4. Default-value changes (and how to preserve v3 behavior)
5. Selector & behavior changes
6. Syntax changes
7. Migration procedure

---

## 1. Config & directive changes

| v3 | v4 |
|---|---|
| `@tailwind base;` `@tailwind components;` `@tailwind utilities;` | `@import "tailwindcss";` |
| `tailwind.config.js` with `theme.extend` | `@theme { }` in CSS |
| `content: ["./src/**/*.{html,js}"]` | automatic detection; `@source` for extras |
| `@layer utilities { .foo {} }` | `@utility foo { }` |
| `@layer components { .btn { @apply ... } }` | `@utility btn { @apply ... }` or a framework component |
| `plugins: [require('x')]` in JS | `@plugin "x";` in CSS |
| `theme('colors.red.500')` function | `var(--color-red-500)` |
| `safelist: [...]` | `@source inline("...")` |
| `prefix: 'tw-'` | `@import "tailwindcss" prefix(tw);` |
| `darkMode: 'class'` | `@custom-variant dark (&:where(.dark, .dark *));` |
| `corePlugins`, `separator` | removed, no replacement |

JS config still works **only** if explicitly loaded: `@config "../tailwind.config.js";`.
Treat that as a temporary migration crutch, not a destination. `corePlugins`,
`safelist`, and `separator` are ignored even via `@config`.

---

## 2. Renamed utilities (exact mappings)

The recurring pattern: the **bare name gained a `-sm` suffix**, and the **old
`-sm` became `-xs`**. So values got "one step smaller in name" for the same
visual size.

| v3 | v4 |
|---|---|
| `shadow-sm` | `shadow-xs` |
| `shadow` | `shadow-sm` |
| `drop-shadow-sm` | `drop-shadow-xs` |
| `drop-shadow` | `drop-shadow-sm` |
| `blur-sm` | `blur-xs` |
| `blur` | `blur-sm` |
| `backdrop-blur-sm` | `backdrop-blur-xs` |
| `backdrop-blur` | `backdrop-blur-sm` |
| `rounded-sm` | `rounded-xs` |
| `rounded` | `rounded-sm` |
| `outline-none` | `outline-hidden` |
| `ring` (3px) | `ring-3` |

Notes:
- `outline-none` still exists in v4 but now means `outline-style: none`. For the
  old "remove the visible outline but keep accessibility" behavior, use
  `outline-hidden`.
- Outline utilities now default `outline-style: solid`, so `outline-2` is enough
  (no separate `outline` needed alongside it).

---

## 3. Removed utilities

| Removed (v3) | Use instead (v4) |
|---|---|
| `bg-opacity-*` | opacity modifier: `bg-black/50` |
| `text-opacity-*` | `text-black/50` |
| `border-opacity-*` | `border-black/50` |
| `divide-opacity-*` | `divide-black/50` |
| `ring-opacity-*` | `ring-black/50` |
| `placeholder-opacity-*` | `placeholder-black/50` |
| `flex-shrink-*` | `shrink-*` |
| `flex-grow-*` | `grow-*` |
| `overflow-ellipsis` | `text-ellipsis` |
| `decoration-slice` | `box-decoration-slice` |
| `decoration-clone` | `box-decoration-clone` |

---

## 4. Default-value changes (preserve v3 behavior if needed)

### Border & divide color → `currentColor` (was `gray-200`)
Always set a color explicitly: `border border-gray-200`. To restore the global
default project-wide:
```css
@layer base {
  *, ::after, ::before, ::backdrop, ::file-selector-button {
    border-color: var(--color-gray-200, currentColor);
  }
}
```

### Ring → 1px / `currentColor` (was 3px / `blue-500`)
Use `ring-3 ring-blue-500` for the v3 look, or restore defaults:
```css
@theme {
  --default-ring-width: 3px;       /* (v4.0 supported; prefer explicit ring-3 going forward) */
  --default-ring-color: var(--color-blue-500);
}
```
Preferred: just write `ring-3 ring-blue-500` explicitly at call sites.

### Placeholder color → current text @ 50% (was `gray-400`)
```css
@layer base {
  input::placeholder, textarea::placeholder { color: var(--color-gray-400); }
}
```

### Button cursor → `default` (was `pointer`)
```css
@layer base {
  button:not(:disabled), [role="button"]:not(:disabled) { cursor: pointer; }
}
```

### `<dialog>` margins removed (centering no longer automatic)
```css
@layer base { dialog { margin: auto; } }
```

---

## 5. Selector & behavior changes

- **`hover:` only applies where the device supports hover** (wrapped in
  `@media (hover: hover)`). This is usually what you want on touch devices. To
  force the old always-on behavior: `@custom-variant hover (&:hover);`.
- **`space-x-*` / `space-y-*` selector changed** from
  `> :not([hidden]) ~ :not([hidden])` to `> :not(:last-child)` (faster, but
  different edge behavior). Prefer `flex`/`grid` + `gap-*` instead of `space-*`.
- **Gradients preserve values across variants.** A `dark:from-blue-500` no longer
  resets the `via`/`to` stops. To explicitly drop a middle stop in a variant, use
  `dark:via-none`.
- **Variant stacking order is left-to-right** (was right-to-left). v3
  `first:*:pt-0` becomes v4 `*:first:pt-0`.
- **Transforms reset individually.** `transform-none` → reset the specific
  property, e.g. `scale-none`, `rotate-none`. Transition transforms by listing
  the real animated properties (`transition-[opacity,scale]`).

---

## 6. Syntax changes

| Concept | v3 | v4 |
|---|---|---|
| Important modifier | `!flex` | `flex!` |
| CSS variable in arbitrary value | `bg-[--brand]` | `bg-(--brand)` |
| Spaces in arbitrary values | `grid-cols-[max-content,auto]` | `grid-cols-[max-content_auto]` (underscores) |
| Prefix | `tw-flex` | `tw:flex` |

---

## 7. Migration procedure

1. **Run the automated upgrader** (needs Node 20+, ideally on a clean git branch):
   ```bash
   npx @tailwindcss/upgrade
   ```
   It rewrites the import, migrates most `tailwind.config.js` into `@theme`,
   renames utilities in your templates, and updates package deps.
2. **Review the diff.** It can't catch dynamic/concatenated class names
   (`` `shadow-${size}` ``) — grep for those and fix by hand using the tables
   above.
3. **Remove dead PostCSS deps** (`autoprefixer`, `postcss-import`) — v4 handles
   both.
4. **Re-check defaults** that changed silently: borders, rings, placeholders,
   button cursors. Add the `@layer base` preservation snippets only where the new
   default actually breaks your design.
5. **Verify browser targets.** v4 needs Safari 16.4+, Chrome 111+, Firefox 128+
   (uses `@property`, `color-mix()`). If you must support older browsers, stay on
   v3.4 — there is no v4 fallback for those engines.
6. **Delete `tailwind.config.js`** once the theme lives in `@theme`. If you kept
   it via `@config`, plan to retire it.
