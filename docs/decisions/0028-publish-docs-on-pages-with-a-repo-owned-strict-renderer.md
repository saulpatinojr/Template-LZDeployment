# Decision 0028 — Publish the docs on GitHub Pages with a repo-owned, strict renderer

- **Status**: **Accepted** — operator-directed 2026-10-21: make GitHub Pages the
  documentation home instead of the wiki, with the recommended, permanent
  solution and no temporary workaround.
- **Date**: 2026-10-21
- **Deciders**: operator
- **Technical depth**: L200 (build tooling, CI contract, supply chain)

## Context and Problem Statement

The operator guide and the factory design records used to live in the GitHub
wiki: a separate repository that is not reviewed with the code. A comparison
showed 59 of its 61 pages existed nowhere else. PR #133 moved the pages that are
still used into `docs/`, but GitHub Pages published only the wizard (`site/`)
and the legacy generator (`frontend/`). The moved docs were readable only as raw
Markdown in GitHub's file view — no navigation, no landing page.

The solution has to be permanent: built by the existing Pages workflow, covered
by CI, and unable to publish a broken site.

Constraints that come from the repository:

- Every GitHub Action is pinned to a commit SHA in one canonical registry
  (`factory/ci/Test-ActionPins.ps1`) that Dependabot bumps must keep in step
  across two trees. Each new action adds to that surface.
- Published pages are held to a no-network policy
  ([`Test-SiteNoNetwork.ps1`](../../factory/ci/Test-SiteNoNetwork.ps1)).
- Tooling is PowerShell 7: operators work on Windows, CI runs on Linux.
- The docs cross-link heavily — about 165 relative links across the published
  pages, 12 of them to ADR 0013 from the guide and factory records alone — and
  those links must keep working on GitHub, in a clone, and on the site.

## Decision

**Render the docs with a repo-owned PowerShell builder,
[`factory/docs-site/Build-DocsSite.ps1`](../../factory/docs-site/Build-DocsSite.ps1),
that uses only the Markdown converter built into PowerShell 7.** No new action,
package or download is introduced.

- **Strict.** The build fails — listing every problem at once — on a broken
  relative link, a link whose letter case would 404 on Linux, an anchor the
  target page does not have, script/iframe/object/embed/form/style/link/meta/base
  elements, inline event handlers, `javascript:` URLs, images (not supported yet),
  a page with no title, or two sources producing the same output.
- **Link policy.** A link to another published page becomes a relative link to
  its `.html`; a link to a section directory becomes that section's index; a link
  to any other file or directory in the repository becomes a link to that exact
  path at the deployed commit on GitHub; anything else is an error. Heading
  anchors follow GitHub's slug rules, so a link that works when the Markdown is
  read on GitHub keeps working on the site.
- **Self-contained output.** One local stylesheet, no scripts, a restrictive
  `Content-Security-Policy`, light and dark themes, a phone layout, and a print
  layout. Output is byte-for-byte deterministic.
- **Deployed by the existing workflow.** [`deploy-pages.yml`](../../.github/workflows/deploy-pages.yml)
  builds into `_pages/docs`, so the site is at `/docs/` next to the wizard, and
  redeploys when anything under the published docs or the builder changes. The
  build runs before the artifact is uploaded: a failing build deploys nothing, so
  a bad change cannot replace the good published site.
- **Guarded in CI on every pull request.**
  [`factory/tests/Test-DocsSite.ps1`](../../factory/tests/Test-DocsSite.ps1) is
  registered in Factory CI. It proves each strictness rule fails the build (against
  a throwaway repository) and builds the real docs, checking every generated page
  and every link.
- **Scope is configuration.** [`docs-site.json`](../../factory/docs-site/docs-site.json)
  publishes the operator guide and checklist, the runbooks, the decision records
  and the factory design records. Maintainer notes (`docs/refactor/`,
  `docs/plans/`, `docs/wiki-review/`, the contracts register, the orchestration
  history page) are not published; links to them become GitHub links. Adding a
  section is a config change, and the strict build keeps it from shipping a dead
  link.

## Consequences

- No new supply-chain surface: nothing to pin, no Dependabot entry, no registry
  row, no package install in the deploy job.
- Docs problems surface in the pull request that causes them, not after deploy.
- The repository now owns about 400 lines of build code (plus its tests). Markdown support is
  whatever PowerShell's built-in converter provides (tables, task lists, fenced
  code, raw HTML); there is no syntax highlighting or search (both would need
  JavaScript), and an image in a published page fails the build until image
  support is added.
- Links from published pages to files outside the site point at the deployed
  commit, so the text a reader sees always matches the files they can click
  through to. They are snapshots, not "latest".
- The two guide links that used to point at wiki pages now point at the frozen
  wiki archive ([decision 0029](0029-retire-the-wiki-and-keep-a-frozen-snapshot.md)),
  so switching the wiki off breaks nothing.
- A new published directory must also be added to the `paths:` filter in
  `deploy-pages.yml`, or edits to it will not trigger a redeploy. (The test checks
  the existing four.)

## Alternatives considered

- **Jekyll through GitHub's `actions/jekyll-build-pages`** (the platform's native
  path). Rejected as the primary mechanism: it adds a new pinned action to a
  registry that is deliberately small, it does not rewrite links to files outside
  its source directory (every link from the guide to an ADR, `TODO.md` or a
  script would 404 or render raw), and it cannot fail a build on a broken link —
  the property that matters most for pages this heavily cross-linked.
- **MkDocs (with a theme) or a similar Python generator.** Rejected: adds a
  Python toolchain and pinned packages fetched at build time to the deploy job,
  and link validation would still have to be written around it.
- **Docusaurus, VitePress or Starlight (Node).** Rejected: a large transitive
  dependency tree to render about fifty static pages, against a repository that
  keeps its supply chain small.
- **Leave the docs readable only on GitHub.** Rejected by the operator: no
  navigation or landing page, and the "temporary" state this decision exists to
  end.
- **Keep the wiki as the documentation home.** Rejected: it is a separate
  repository, outside pull-request review, and 59 of its 61 pages had drifted from
  the repository.

## Verification

- `factory/tests/Test-DocsSite.ps1`: 44 checks pass locally — the rules above,
  determinism, and a build of the real docs (52 pages) with every link and anchor
  on every page resolved. The suite also passes in Factory CI on Linux, the same
  platform that builds the deployed site.
- The generated site was opened in a real browser in light and dark themes and at
  a 390 px phone width.
- Not established by these checks: the live deployment. That is verified after
  merge by the Pages deploy run and by fetching the published pages.
