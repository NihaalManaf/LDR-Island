---
name: joni
description: Make UI elements bigger, simpler, and more irresistible. Use when the user says "joni this", "/joni", "make it joni", or asks to simplify/enlarge/polish a page's copy and CTAs. Pure UI/UX — never touches backend, billing logic, or data accuracy.
---

# Joni

Make things big, simple, and irresistible. Like a ripe berry.

## What Joni Means

Joni = take any UI element and make it:

- **Bigger** — larger text, larger buttons, larger touch targets, more padding
- **Simpler** — fewer words, shorter sentences, one idea per element
- **Fifth-grade reading level** — no jargon, no acronyms, no industry terms
- **Clicky** — obvious CTAs, satisfying interactions, hover effects that feel alive
- **Visually generous** — more whitespace, fewer borders, less visual clutter

## Rules

1. **No backend changes.** Joni is purely UI/UX. Never modify API routes, server actions, database queries, or data models.
2. **Remove jargon.** Replace product-specific terms with plain language. "Magic Inbox" becomes "one place for all your replies." "Outreach campaigns" becomes "reach out to podcasts."
3. **Shorter always wins.** If a sentence can lose a word without losing meaning, lose the word.
4. **One idea per visual block.** If a card or section communicates two things, split them or cut one.
5. **Big buttons > small buttons.** Increase padding, font size, and border radius on CTAs. Always use `!font-bold` (with the Tailwind important modifier) on CTA buttons to override component defaults. The app uses GeneralSans font which maxes out at **Bold (700)**. Do NOT use `font-black` (900) or `font-extrabold` (800) — those weights don't exist in GeneralSans and will silently render as normal weight. The heaviest available class is `font-bold`.
6. **Outcomes over features.** "10 pitches/day" becomes "10 pitches sent for you every day." Features describe the tool. Outcomes describe what the user gets.
7. **Emojis are fine.** Use them as visual anchors for scanability, not decoration.
8. **Kill the fine print feel.** If text looks like a legal disclaimer, make it conversational or hide it behind an accordion.
9. **Hover effects should feel alive.** Scale transforms, color shifts, shadow depth changes — with smooth transitions (300ms, cubic-bezier).
10. **Numbers are juicy.** "$59" is juicier than "fifty-nine dollars." "14 days" is juicier than "two weeks." "97%" is juicier than "almost all."

## How to Joni a Page

1. **Read the current page** — understand what it communicates
2. **Identify the one action** the user should take — that becomes the biggest, most obvious element
3. **Cut copy by 40-60%** — rewrite what remains at a fifth-grade level
4. **Increase all text sizes by 10-20%** — especially headlines, CTAs, and value statements
5. **Add whitespace** — increase spacing between sections
6. **Make the CTA impossible to miss** — big, colorful, with hover animation
7. **Push secondary info below the fold** — billing details, legal text, plan comparisons go behind accordions or at the bottom
8. **Add social proof near the CTA** — star ratings, user counts, trust badges
9. **Test the 3-second rule** — if someone can't understand the page in 3 seconds, it's not joni enough

## Before/After Examples

### Headlines
- Before: "Your 14-day trial is $59 and renews at $686 on April 10 for 3 months of the Lite Plan"
- After: "Start your 14-day trial for just $59."

### Buttons
- Before: "Continue to payment — $59"
- After: "Start My $59 Trial" (with scale-110 hover, green bg, 2xl text)

### Billing Disclosure
- Before: Amber warning box with "What happens on April 10" heading
- After: Small muted text at the bottom: "$59 for 14 days. Then $229/mo billed quarterly. Cancel anytime."

### Features
- Before: "10 AI-written pitches sent daily, on autopilot"
- After: ":rocket: Launch your first campaign today"

### Trust
- Before: "Secure payment via Stripe."
- After: "Cancel anytime · Stripe secured · No surprise charges"

## Auto-Progression

When all required fields on a page are filled, auto-submit after a short delay (3-5 seconds) with a visible progress bar over the CTA. The user should feel momentum, not waiting. Rules:
- Show a progress bar filling left-to-right over the submit button
- Give users the full delay to click away or change something
- If the user interacts with any field during the countdown, cancel and reset
- All data must still persist correctly (same submission logic, just auto-triggered)
- Only do this when it won't harm UX (don't auto-submit payment forms or destructive actions)

## What NOT to Joni

- **Data accuracy** — never round prices, change dates, or alter billing amounts to sound simpler
- **Backend logic** — never change API calls, database operations, or server-side code
- **Legal requirements** — billing disclosure must remain complete and accurate, just styled differently
- **Accessibility** — maintain proper contrast, aria labels, and keyboard navigation
