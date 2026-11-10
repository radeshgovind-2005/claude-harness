# `dev-harness:designer` on a planted bad page

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `Use the dev-harness:designer agent on index.html and style.css (audience: shoppers on phones and keyboards)`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`. `claude -p` prints only Claude's final message, so text from earlier in the session is not shown (which is why a report can refer to something "above").
- Project: a toy HTML and CSS page with a `div` button, white text on yellow, a removed focus outline and fixed widths.

Source only: nothing was rendered, and the report says so. It computes the contrast ratios from the colour values (they recompute correctly). The agent was started by a parent Claude session that was told to return the report verbatim. What is shown is the parent's reply, so it can contain a line or two of the parent's own words (and it may retell the report); it is not the agent's raw output.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## The agent's report

```
STATUS: FIXES NEEDED
TARGET: index.html and style.css in <scratch>/live/ui (a storefront page with a heading, a "Buy now" button, an email field and a shipping note)
FOR: shoppers on phones and keyboards (from the task prompt, not from docs/intent.md)
SEEN: source only: nothing was rendered

FINDINGS (most severe first):
1. [severity: high] index.html:5 — "Buy now" is a `<div onclick>`, not a button.
   They see or cannot do: A keyboard user cannot Tab to it, and Enter or Space does nothing. Screen readers do not announce it as a control. The main action of the page is unreachable without a mouse or touch.
   Evidence: `<div class="btn" onclick="buy()">Buy now</div>`. There is no tabindex, no role and no key handler. style.css has no `.btn:focus` rule and no `cursor: pointer`.
   Fix idea: Use `<button type="button" class="btn">` and add a `:focus-visible` style.

2. [severity: high] style.css:3 — The button label is nearly invisible.
   They see or cannot do: White text on a yellow button is very hard to read. It is the page's key call to action.
   Evidence: `.btn { background: #ffcc00; color: #ffffff; ...}`. Computed contrast is 1.51:1, against 4.5:1 required (3:1 for large text). The hover colour #ffd633 is lighter still, so the text gets worse on hover.
   Fix idea: Use dark text such as #222 on the yellow. That gives roughly 12:1 (the ratio is not computed here), and it fixes hover too.

3. [severity: high] style.css:5 and index.html:6 — The email input has no visible focus, no label and a barely visible border.
   They see or cannot do: Keyboard users cannot see where focus is. Screen reader users get only a placeholder, which disappears when typing starts. The field's edge is almost invisible against the white page.
   Evidence: `input { outline: none; width: 420px; border: 1px solid #ddd; }`. The border contrast is 1.36:1, against 3:1 for UI components. The markup is `<input placeholder="Email">`, with no `<label>`, `type="email"`, `name` or `autocomplete`.
   Fix idea: Remove `outline: none` or add a `:focus-visible` ring. Add a `<label>`, `type="email"`, `autocomplete="email"`, and a border of at least 3:1.

4. [severity: high] style.css:3 and style.css:5 — Fixed pixel widths overflow on phones, and the viewport meta tag is missing.
   They see or cannot do: The button is 480px plus 14px of padding, about 494px wide. The input is 420px plus its default padding and border. Both are wider than a 320–414px phone screen, so the page scrolls sideways. Without the viewport meta tag, mobile browsers lay the page out at about 980px and shrink it, which makes the 10–11px text even smaller.
   Evidence: `.btn { width: 480px; ... }`, `input { width: 420px; ... }`. index.html:2 has no `<meta name="viewport">`.
   Fix idea: Add `<meta name="viewport" content="width=device-width, initial-scale=1">`. Use `width: 100%; max-width: 480px; box-sizing: border-box`.

5. [severity: medium] style.css:6 — The shipping note is unreadable.
   They see or cannot do: Light grey 10px text is easy to miss, and it carries the free-shipping incentive.
   Evidence: `.note { color: #bbb; font-size: 10px; }` on #ffffff. Computed contrast is 1.92:1, against 4.5:1 required.
   Fix idea: Use at least 14px in a colour of 4.5:1 or better, such as #595959 or darker.

6. [severity: medium] style.css:2 and index.html:4 — The page heading is weak and not a heading.
   They see or cannot do: "Shop" is the smallest text on the page and is not marked up as a heading. Its colour is borderline for a tiny size.
   Evidence: `.top { font-size: 11px; color: #777; }` on a plain `<div class="top">`. The computed contrast is 4.48:1, just under 4.5:1 for small text. The button and the heading are the same size scale. The note is smaller than the body text.
   Fix idea: Use an `<h1>` at a clearly larger size, in #333 or at least #767676. The #767676 value is a rule of thumb and was not computed here.

7. [severity: medium] style.css:3 — The tap target is small.
   They see or cannot do: Padding of 7px around the default 16px text gives a button about 30px tall, below the usual 44px minimum for thumbs.
   Evidence: `padding: 7px;`. The height is an estimate from the source, not a rendered measurement.
   Fix idea: Use `min-height: 44px` and larger padding.

8. [severity: low] style.css (whole file) — The spacing is arbitrary and several states are missing.
   They see or cannot do: The elements have no consistent rhythm. The note has `margin-top: 13px`, while the button, input and heading have no stated margins. Nothing is set for `:focus-visible`, `:active`, `:disabled` or loading on the button, or for an error state on the input. The button has only a hover state. Border radius is 3px on the button and default on the input. Font sizes are 11px, 10px and default, which is no scale.
   Evidence: 13px, 7px, 11px and 10px values appear only once each in style.css:2–6.
   Fix idea: Define a small spacing and type scale. Add focus, active, disabled and invalid styles.

9. [severity: low] index.html:2 — The document has no `lang` attribute and no charset meta.
   They see or cannot do: Screen readers may pronounce the text wrongly. Non-ASCII characters can render badly.
   Evidence: `<html><head><title>Shop</title>...`. There is no `lang`, no `<meta charset>` and no `<main>` landmark.
   Fix idea: Add `<html lang="en">` and `<meta charset="utf-8">`.

CHECKED, NOTHING FOUND: Body text colour (#333 on #fff computes to 12.63:1).

NOT SEEN: Real rendering, actual button height and wrap behaviour, and the page at any viewport. Hover on a touch device and any JS behaviour were also not seen. `buy()` is not defined in the target files, so clicking would throw an error (the code is skeptic's to check). Whether an email is needed before buying is a flow question for lens (UX).
```

