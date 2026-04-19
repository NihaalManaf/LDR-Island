---
name: standup
description: Use when the user asks for a standup summary, yesterday recap, daily update, or invokes /standup. Reviews the current branch plus all git worktrees for commits, merges, PR-related evidence, and local-only diverged commits by the requested author, then returns at most five deduplicated bullets suitable for speaking in standup.
---

# Standup

Prepare a concise standup-ready summary of what the user did yesterday.

## Trigger Phrases

Use this skill when the user says things like:
- `/standup`
- `standup`
- `what did I do yesterday`
- `summarize my work yesterday`
- `daily update`
- `review my commits / PRs / merges`

## Inputs To Infer

When not explicitly provided, infer:
- author from the user's request, then fall back to git author name/email
- time window as local `yesterday 00:00` to `today 00:00`
- scope as current worktree plus all repo worktrees

If the user names a specific author, only include work by that author.

## Required Investigation

Check all of these before summarizing:

1. Current branch status and upstream tracking
2. All git worktrees in the repo
3. Commits authored by the target author in the time window
4. Merge commits authored by the target author in the time window
5. Local-only diverged commits via `@{upstream}...HEAD` or equivalent per worktree
6. PR evidence when available locally or through `gh`
   - If `gh` is available, inspect PRs created, merged, or updated by the author yesterday
   - If `gh` is unavailable or not authenticated, say so implicitly by only reporting verifiable git evidence

## Suggested Command Pattern

Prefer bash-based git inspection. Use read only for files if needed.

Typical flow:
1. `git worktree list --porcelain`
2. `git status --short --branch`
3. `git config user.name && git config user.email`
4. Per worktree:
   - branch name
   - authored commits yesterday
   - merge commits yesterday
   - upstream divergence counts
   - local-only commits yesterday
5. For important commits, inspect `git show --stat --summary`
6. If `gh` works, inspect relevant PRs for the same time window

## GitHub CLI Requirement

Prefer `gh` for PR evidence whenever it is installed and authenticated.

Before summarizing, try:
- `gh auth status`
- `gh pr list --search "author:<author> updated:<YYYY-MM-DD>" --state all --limit 20`
- `gh search prs --author <author> --updated <YYYY-MM-DD> --limit 20`
- for important PRs: `gh pr view <number> --json title,state,createdAt,updatedAt,mergedAt,url,author,commits`

Use `gh` evidence to confirm whether PRs were created, updated, merged, or had notable activity in the time window.
If `gh` is unavailable or unauthenticated, silently fall back to git-only evidence.

## Output Rules

Return:
- maximum 5 top-level bullets
- each bullet = one feature or one meaningful non-feature bucket
- sub-bullets allowed under a feature
- do not repeat the same feature across bullets
- only include work attributable to the target author
- keep it concise and standup-ready
- use plain English with no jargon, no buzzwords, and no fluff
- prefer simple verbs like built, fixed, added, cleaned up, merged
- avoid internal implementation detail unless it helps explain the user-facing work
- mention local-only diverged work only if it exists
- if there is no PR evidence, do not invent PR activity

## Dedupe Rules

Combine these into one bullet when they refer to the same user-facing work:
- implementation commit + follow-up merge for same feature
- branch merge + fixups for same feature
- backend + frontend changes that together ship one feature

Keep separate only when they are clearly different deliverables.

## Preferred Structure

- Plain-English feature summary
  - key pieces in simple language
  - merge/PR note only if it adds useful context

Optional final bullet:
- Repo / workflow maintenance
- Local-only work not yet pushed

## Style

Write like something the user can say out loud in standup.

- short bullets
- no jargon when a simpler phrase exists
- no filler words
- no repeated context
- no commit-hash noise unless user asks

## Safety Rules

- Do not guess at PRs, deployment, or merged status
- Do not include another author's commits
- If evidence is ambiguous, say so briefly or omit it
- Favor correctness over completeness
