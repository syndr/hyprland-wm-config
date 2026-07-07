# AGENTS.md

Canonical, tool-agnostic instructions for AI coding agents working in this
repository (Claude Code, Cursor, Copilot, Aider, etc.). Tool-specific
instruction files should defer to this file for working conventions.

For what the project *is*, see [`README.md`](README.md); commit style lives in
[`COMMIT_MESSAGE_GUIDELINES.md`](COMMIT_MESSAGE_GUIDELINES.md).

## Architecture Decision Records (ADRs)

This project records architecturally significant decisions as ADRs under
[`docs/adr/`](docs/adr/) (same convention as the phalanx repo).

- **Before** making an architecturally significant change — swapping a core
  desktop component (locker, launcher, bar), adopting an external
  package/tooling dependency, a deploy/installer structural change, or a
  cross-repo coordination contract (phalanx, the swaylock-plugin fork) — add
  or update an ADR in `docs/adr/`.
- Follow the convention in [`docs/adr/README.md`](docs/adr/README.md): the
  Michael Nygard template, and a present-tense verb-noun filename. Add the new
  record to that file's index.
- Don't edit an accepted ADR to reverse it — add a new ADR that supersedes it.
- Routine work (config tweaks, theme changes, local fixes) does not need an
  ADR.

When a change lands that implements a decision, reference the ADR in the
commit message.
