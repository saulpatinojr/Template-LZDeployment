# Decision 0032 — Retire the legacy `frontend/` generator

- **Status**: **Accepted** — operator-directed 2026-10-21: "validate first, then
  retire if it is not used."
- **Date**: 2026-10-21
- **Deciders**: operator
- **Technical depth**: L100 (a retired static page; no product behaviour changes)

## Context and Problem Statement

`frontend/` is a small static page (`index.html`, `app.js`, `styles.css`, a README) that
turned a form into two Terraform variable files, `terraform.auto.tfvars` and
`connectivity.auto.tfvars`. It was written for this repository's old self-deploying
Terraform stacks. Those stacks were deleted by
[decision 0013](0013-generator-only-avm-architecture.md), and on 2026-08-15 the page was
marked **DEPRECATED, historical only**. Its own README says the files it produces "have
nothing to consume them".

It was still shipped, though. It was published on GitHub Pages under `/frontend/`, it was
scanned by a CI check, and it still printed the old `management_ip_ranges` placeholder text
that the connectivity loop-back clean-up (pull request #143) removed everywhere else. A page
that looks supported but generates files for nothing is a trap for a new administrator.

## Validation (done before deciding)

Retire only if nothing uses it. What was checked on 2026-10-21, all against the repository:

- **Its targets are gone.** There is no `terraform/` folder, so there is nowhere to copy the
  two files it produces.
- **The wizard does everything it did, and more.** `site/` exports the same two `.tfvars`
  files (`tfvarsGlobal`, `tfvarsConnectivity` in `site/app.js`) plus `lz-config.json`, which
  the whole factory runs on.
- **Nothing links to it.** No page in `site/`, `docs/guide/` or `docs/factory/` points at
  it. The only mentions were the README (describing it as deprecated), the deprecated
  page's own README, and history documents.
- **Code touchpoints were three, all removable:** the Pages workflow copied it to
  `/frontend/` and watched `frontend/**`; `Test-SiteNoNetwork.ps1` scanned it; and the
  end-to-end proof checks that a *generated* repository never contains a folder named
  `frontend`. The last one is a guard against leaked generator files and stays.
- **Not measurable:** whether anyone still opens the published page. The site is
  network-free by design, so it has no analytics. The page was live (HTTP 200) on
  2026-10-21, so this decision removes a public URL.

## Decision

Delete `frontend/`. Stop publishing `/frontend/`. Remove it from the Pages workflow and
from the no-network scan. Remove the README's "Optional Static Configuration Generator
(deprecated)" section and its tree entry.

The code is not lost: it stays in git history. To read it,
`git show b9dbf68:frontend/index.html` (and `app.js`, `styles.css`, `README.md`) shows the
last version.

## Consequences

- `https://saulpatinojr.github.io/Template-LZDeployment/frontend/` returns 404 after the next
  Pages deploy. The page was deprecated for two months and generated files for stacks that
  do not exist.
- `Test-SiteNoNetwork.ps1` now scans `site/` only.
- [`docs/refactor/CLASSIFICATION.md`](../refactor/CLASSIFICATION.md) records `frontend/` as
  **KEEP** (refactor-time operator direction). That is history and is left as written; this
  decision supersedes it.
- One fewer thing to explain to a newcomer: the wizard in `site/` is the only way to produce
  the configuration.

## Alternatives considered

- **Keep it, deprecated.** Rejected: it has been deprecated since 2026-08-15 and still cost a
  published URL, a CI scan and, most recently, stale placeholder text that misled readers.
- **Replace it with a redirect page at `/frontend/`.** Rejected: another page to maintain, to
  soften the loss of a page that generated files for nothing.
- **Move it to an archive branch or tag.** Rejected: git history already keeps it, and a tag
  adds a ref to explain for no extra safety.

## Verification

Run locally on 2026-10-21, before the pull request:

- `Test-SiteNoNetwork.ps1` passes with `site/` as the only scan root.
- `Test-DocsSite.ps1`: 44 passed, 0 failed. The docs build produces 54 pages with every link
  and anchor resolving (this record is one of them).
- The Pages workflow's staging commands, run by hand, produce a site with no `frontend`
  folder.
- The full Factory CI, in a clone with LF line endings (which mirrors GitHub's Linux
  runners): everything passes except two checks that also fail on an unchanged `main` in
  that clone ("Test-Bootstrap.ps1", the byte-for-byte plan comparison, and "ALZ policy
  catalog"). Neither involves this change.

Not verified: any external use of the published page, for the reason given above; and that
the next Pages deploy actually drops `/frontend/` (check that URL returns 404 after the
merge).
