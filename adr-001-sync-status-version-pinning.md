# ADR: Add sync, status, and version pinning to skillsync

## Status
Accepted

## Context
The `skillsync` tool manages skill repositories as sparse-checkout git submodules. Once added, submodules could silently drift from upstream with no visibility or automated way to pull updates. Users had to manually `cd` into each submodule, fetch, and merge.

## Decision
Added three features to `skillsync`:

1. **`status` command** — Fetches each submodule's upstream and reports: current commit, commits behind/ahead, local modifications, and broken symlinks in `skills/`.

2. **`sync` command** — Fetches and fast-forward merges upstream changes for all or a specific submodule. Supports `--dry-run`. Stashes local changes if present, and reports repos that need manual merge.

3. **Version pinning** — `add_skill` now records the submodule's current commit hash in `active-skills.json` for auditability. User-sourced skills omit this field.

## Consequences
- Submodule drift is now detectable via `skillsync status`
- Upstream updates can be pulled with a single `skillsync sync` command
- `active-skills.json` now tracks which commit each skill was activated at
- The parent repo's submodule pointer still needs a manual `git add && git commit` after sync (by design, to avoid unreviewed changes)
