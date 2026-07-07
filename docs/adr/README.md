# Architecture Decision Records

This directory holds **Architecture Decision Records (ADRs)** — short documents
capturing an architecturally significant decision, its context, and its
consequences. See <https://adr.github.io> for background. (Same convention as
the phalanx repo's `docs/adr/`.)

## When to write one

Write an ADR when a change decides something that is costly to reverse or that
future contributors will need the *reasoning* for, not just the result — e.g.
swapping a core desktop component (locker, launcher, bar), adopting an external
package/tooling dependency, a deploy/installer structural change, or a
cross-repo coordination contract (with phalanx or the swaylock-plugin fork).
Skip it for routine config tweaks, theme changes, and local fixes.

One decision per record. Records are immutable once accepted: to change a
decision, add a **new** ADR that supersedes the old one rather than editing it.

## Convention

- **Template:** the [Michael Nygard template][nygard] — `Status`, `Context`,
  `Decision`, `Consequences` (add a short `Status` date line).
- **Filename:** a present-tense imperative verb-noun phrase, lowercase with
  dashes, `.md` — e.g. `adopt-swaylock-plugin-screensaver-lockscreen.md`. No
  number prefixes.
- **Status** progresses through: `Proposed` → `Accepted` → (later)
  `Deprecated` or `Superseded by <adr>`.

## Index

- [Adopt the swaylock-plugin xscreensaver screensaver lockscreen](adopt-swaylock-plugin-screensaver-lockscreen.md)

[nygard]: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
