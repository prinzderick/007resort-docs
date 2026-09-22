# Contributing to 007resort-docs

## Branching

- `main` is protected. All changes arrive through pull requests.
- Branch names: `docs/<topic>`, `adr/<number>-<slug>`, `chore/<topic>`.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`docs:`, `chore:`, `ci:`).

## Architecture Decision Records

1. Copy `adr/0000-template.md` to `adr/NNNN-short-title.md` using the next free number.
2. Start with status `Proposed`. Open a PR and request review.
3. After approval, set the status to `Accepted` and record the date and approver.
4. To change an accepted decision, write a **new** ADR that supersedes it and set the old one to `Superseded by NNNN`. Do not rewrite accepted ADRs.

## Status document

`STATUS.md` must be updated in the same PR as any milestone, blocker or decision change.

## Writing rules

- Prefer tables and Mermaid diagrams over long prose.
- Money is always described as fixed-point decimal. Never document float/double for amounts.
- Times are UTC in storage and APIs. Local time is a presentation concern only.
- Never include secrets, real credentials, customer personal data or production hostnames/IPs.

## Local checks

```bash
npx markdownlint-cli2 "**/*.md"
```

CI runs markdownlint and a gitleaks secret scan on every push and pull request.
