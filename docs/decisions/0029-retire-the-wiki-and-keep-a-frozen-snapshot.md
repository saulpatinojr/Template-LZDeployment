# Decision 0029 — Retire the wiki, and keep a frozen snapshot of it as a tag

- **Status**: **Accepted** — operator-directed 2026-10-21: use GitHub Pages and
  `docs/` as the documentation home from now on, and finish retiring the wiki.
- **Date**: 2026-10-21
- **Deciders**: operator
- **Technical depth**: L100 (documentation hosting; no product behaviour changes)

## Context and Problem Statement

The project's GitHub wiki was a second git repository
(`Template-LZDeployment.wiki`) that sat outside pull-request review. Two earlier
changes made it redundant as a home for current documentation:

- [PR #133](https://github.com/saulpatinojr/Template-LZDeployment/pull/133) moved
  the 13 pages still in use into `docs/guide/` and `docs/factory/`.
- [Decision 0028](0028-publish-docs-on-pages-with-a-repo-owned-strict-renderer.md)
  publishes `docs/` as a website on GitHub Pages.

What remained in the wiki was 44 pages of history: the pre-factory plan,
architecture and standards, and the webapp/static-generator docs, reviewed and
labelled historical in [`docs/wiki-review/`](../wiki-review/README.md). A line-by-line
comparison had shown that 59 of the wiki's 61 pages existed nowhere else, so the
retirement had to preserve them, not just switch the wiki off.

Two facts shaped how:

- **GitHub keeps the content when a wiki is turned off.** Its documentation says
  the content "is hidden, but not erased" and that re-enabling the wiki restores
  the previous pages
  ([Disabling wikis](https://docs.github.com/en/communities/documenting-your-project-with-wikis/disabling-wikis)).
  Hidden content, though, cannot be linked to or read.
- **The wiki's full history cannot be pushed into this repository.** Nine of its
  twelve commits carry the operator's private email address, and GitHub's push
  protection rejects commits that expose it. Rewriting the authors would falsify
  the history.

## Decision

1. **Turn the wiki feature off** (Settings → General → Features → Wikis), as the
   last step, after the change that adds this record is merged, so that no
   maintained link is left pointing at it.
2. **Keep a frozen snapshot as the tag
   [`archive/wiki-2026-10-21`](https://github.com/saulpatinojr/Template-LZDeployment/tree/archive/wiki-2026-10-21).**
   It is one parentless commit holding all 61 pages exactly as at wiki commit
   `42c7c5a`, plus a `README.md` that says what the snapshot is. Every page was
   checked against the original by its content fingerprint (61 of 61 identical)
   before the tag was published. A tag rather than a branch: it cannot move, it
   does not appear in the branch list, and it is not checked out by default.
3. **Point everything that still linked to the wiki at the snapshot** (the guide,
   the README, `TODO.md`, the factory records), using its permanent URLs.
4. **Stop naming the wiki as a home for documentation** in `CLAUDE.md`. Documentation
   lives in `docs/` and the four root files. (Decision 0008 named the wiki too; it
   stays as written, as a record.)
5. The wiki's own commit history (12 commits) was also saved as a verified `git
   bundle` on the operator's machine. That backup is not part of this repository.

## Consequences

- One source of truth for documentation: reviewed with the code and published on
  Pages by a build that fails on a broken link.
- Old wiki URLs, including the earlier `HybridCloudWorks` ones, stop working. Nothing
  maintained links to them.
- Reversible: turning the wiki back on restores its pages.
- The snapshot is about 1 MB of text (roughly 370 KB compressed) carried by every
  clone, because clones fetch tags. It is not in any working tree.
- `docs/wiki-review/` stays: it is the evidence of the reviews done while the wiki
  was live.

## Alternatives considered

- **Leave the wiki enabled, as history.** Rejected: two documentation homes, one of
  them unreviewed, is the drift this change exists to end.
- **Copy the 44 historical pages into `docs/`.** Rejected: about 30,000 lines of
  known-stale text inside a template that clients copy, which would then need link
  maintenance, review and a place in the published site, for pages nobody follows.
- **Push the wiki's history as a branch or tag.** Rejected: push protection rejects
  it (see above), and rewriting the authors to get past that would falsify the
  record.
- **Switch the wiki off and rely on GitHub's hidden copy.** Rejected: hidden pages
  cannot be linked from the guide or the README, and nobody can read them.
- **Delete the wiki.** Rejected: irreversible, and nothing is gained over keeping
  it hidden.

## Verification

- All 61 pages in the snapshot have the same content fingerprint as the original
  wiki; the snapshot adds only its `README.md`.
- The tag's pages return HTTP 200 at their permanent URLs.
- The backup bundle passes `git bundle verify`.
- Not established by these checks: that the wiki is switched off. That is the final
  step and is confirmed afterwards by requesting the old wiki URL.
