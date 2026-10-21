# Factory design and build records

These pages explain how the Landing Zone Factory was designed and built. You do
**not** need them to run the factory — the operator guide is
[docs/guide/](../guide/README.md). Read these if you are changing the factory, or
if a code comment mentions a risk ID (such as AR3, BR2 or GH1) and you want to
know what it means.

| Page | What it is |
| --- | --- |
| [Factory design](factory-design.md) | The architecture and the risk register. Risk IDs cited in code comments are defined here. Written before the generator-only refactor, so parts of it describe things that were later deleted; the banner at the top says which. |
| [Stage readiness records](#the-stage-records) | One short record per build stage (7 to 14), each written when that stage was finished. They are history, not instructions. |

## The stage records

| Stage | What was built |
| --- | --- |
| [7](stage-readiness/stage-07-workflow-corpus.md) | The workflow templates that go into each generated repository |
| [8](stage-readiness/stage-08-generated-documentation-corpus.md) | The documentation that goes into each generated repository |
| [9](stage-readiness/stage-09-bootstrap-broker.md) | The bootstrap broker (creates identities and GitHub settings) |
| [10](stage-readiness/stage-10-scaffold-builder.md) | The scaffold builder (creates the generated repository) |
| [11](stage-readiness/stage-11-brownfield-import-generation.md) | Import generation for existing ("brownfield") environments |
| [12](stage-readiness/stage-12-factory-ci.md) | The factory's own automated checks |
| [13](stage-readiness/stage-13-hcw-dogfood-instance.md) | A self-deploying demo instance — **deleted** by [ADR 0013](../decisions/0013-generator-only-avm-architecture.md) |
| [14](stage-readiness/stage-14-release-evidence-attestation.md) | Release evidence and attestation |

*These pages used to live in the project wiki and were moved here on 2026-10-21.
The older planning and architecture material from the pre-factory era stayed in
the wiki as history.*
