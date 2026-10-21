# How to get started — the operator guide

This is the walkthrough for running the Landing Zone Factory once for one
customer, from "I have nothing set up" to "the customer's landing zone is
deployed". It is written for one person (an operator) who holds the customer's
credentials. You do not need anyone else to follow it.

> **First, a reality check.** The factory is marked *pre-release*. Generating a
> customer's repository is proven, but the first real deployment into a customer's
> tenant has not happened yet — so treat your first deployment as a practice run,
> not a go-live. What is still open is tracked in [TODO.md](../../TODO.md) and
> [REVIEW.md](../../REVIEW.md).

Read the four pages in order. Each one ends by telling you which page comes next.

| Step | Page | What you get from it |
| --- | --- | --- |
| 1 | [Getting started](01-getting-started.md) | What the factory is, the overall path (copy, set up, run the wizard, generate, deploy, clean up), and the accounts and tools you need before you begin. |
| 2 | [Credentials checklist](02-credentials-checklist.md) | Every account, permission and secret you will need — what it is for and where to get it. |
| 3 | [Bootstrap walkthrough](03-bootstrap-walkthrough.md) | Installing and signing in to the command-line tools, running the bootstrap (it creates the identities and GitHub settings), and filling in the configuration wizard. |
| 4 | [Generate and deploy](04-generate-and-deploy.md) | Generating the customer's repository, pushing it to GitHub, doing the first deployment, and tidying up afterwards. |

Two companion documents live elsewhere because the tests and tools read them
from disk: the [operator checklist](../USER-CHECKLIST.md) (the authoritative
list of sign-in, publishing and verification activities) and
[TODO.md](../../TODO.md) (known blockers and hardening work).

## Where to look if something is out of date

These pages describe the factory as it works today. If a page disagrees with
the code, the code wins — please open an issue or a pull request. For the
reasoning behind how things are built, read the
[decision records](../decisions/); for the design and its risk list, see
[the factory design record](../factory/factory-design.md).

*These pages used to live in the project wiki. They were moved into the
repository on 2026-10-21 so they are versioned and reviewed alongside the code
they describe.*
